--!strict
-- Client-Bootstrap: wartet auf die statischen Remotes und Shared-Module aus dem
-- Place-File und initialisiert die Client-Module in Abhängigkeitsreihenfolge.
--
-- Diagnose-Erkenntnis aus dem Gauntlet: Der Client hing wiederholt in einem
-- Modul-Require (dessen WaitForChild auf "Shared" hat keinen Timeout), während
-- die Statuszeile noch einen ÄLTEREN Schritt anzeigte. Deshalb gilt hier:
--   1. JEDER Wartepunkt hat einen Timeout und eine eigene Statusmeldung —
--      auch jedes einzelne require meldet sich vorher an. Friert die Anzeige
--      ein, benennt sie exakt die hängende Stelle.
--   2. Eine unabhängige Diagnosezeile schreibt sich jede Sekunde selbst neu
--      (Zeit, game:IsLoaded(), Live-Inhalt von ReplicatedStorage) und kann
--      damit nie veralten.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- WICHTIG: PlayerScripts-Nachbarn IMMER per WaitForChild holen. Die Klone aus
-- StarterPlayerScripts treffen beim Join nach und nach ein; dieses Skript kann
-- laufen, BEVOR seine Nachbarn existieren. Direkter Punktzugriff
-- (script.Parent.PowerBar) warf dann "not a valid member" und tötete den
-- gesamten Bootstrap — DER Root-Cause der stillen Client-Ausfälle im Live-Spiel.
local BootHud = require(script.Parent:WaitForChild("BootHud"))
BootHud.init()

local WAIT_TIMEOUT = 8 -- Sekunden pro Wartepunkt; danach roter Fehler statt stilles Hängen

-- Unabhängige Live-Diagnosezeile: läuft für immer, unabhängig vom Bootstrap.
task.spawn(function()
	local startClock = os.clock()
	while true do
		local names = {}
		for _, child in ReplicatedStorage:GetChildren() do
			table.insert(names, child.Name)
		end
		BootHud.setDiagnostics(string.format(
			"t=%ds  geladen=%s  RS[%d]: %s",
			math.floor(os.clock() - startClock),
			tostring(game:IsLoaded()),
			#names,
			table.concat(names, ", ")
		))
		task.wait(1)
	end
end)

-- Server-Boot-Fortschritt live spiegeln (repliziertes Attribut).
local function updateServerStep()
	local step = ReplicatedStorage:GetAttribute("ServerBootStep")
	BootHud.setServerStep(if step ~= nil then tostring(step) else "(noch keine Meldung)")
end
updateServerStep()
ReplicatedStorage:GetAttributeChangedSignal("ServerBootStep"):Connect(updateServerStep)

-- Der Server repliziert Fehler seiner Weltgenerierung als StringValue
-- "ServerBootError" — das BootHud zeigt sie an, sonst blieben sie unsichtbar.
local function watchServerBootError()
	local existing = ReplicatedStorage:FindFirstChild("ServerBootError")
	if existing ~= nil and existing:IsA("StringValue") then
		BootHud.setError("Server: " .. existing.Value)
		return
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "ServerBootError" and child:IsA("StringValue") then
			BootHud.setError("Server: " .. child.Value)
		end
	end)
end

-- Benannter Wartepunkt: Timeout + Fehlermeldung statt stilles Hängen.
local function waitForNamed(parent: Instance, name: string): Instance?
	BootHud.setStatus("Warte auf " .. parent.Name .. "." .. name .. " …")
	local found = parent:WaitForChild(name, WAIT_TIMEOUT)
	if found == nil then
		BootHud.setError(
			parent.Name .. "." .. name .. " ist nach " .. WAIT_TIMEOUT
				.. "s nicht angekommen — Screenshot bitte."
		)
	end
	return found
end

local remotesFolder = waitForNamed(ReplicatedStorage, "Remotes")
if remotesFolder == nil then
	watchServerBootError()
	return
end

local REMOTE_NAMES = {
	"FireRequest",
	"ProjectileFired",
	"ProjectileImpact",
	"WeaponSelect",
	"MatchEvent",
	"QuipEvent",
	"CameraCue",
	"DamageEvent",
}
local remoteEvents: { [string]: RemoteEvent } = {}
for _, name in REMOTE_NAMES do
	local remote = waitForNamed(remotesFolder, name)
	if remote == nil or not remote:IsA("RemoteEvent") then
		BootHud.setError("Remotes unvollständig oder falscher Typ (" .. name .. ") — Screenshot bitte.")
		return
	end
	remoteEvents[name] = remote
end

-- Shared VOR den Requires prüfen: die Module warten intern ohne Timeout darauf.
local shared = waitForNamed(ReplicatedStorage, "Shared")
if shared == nil then
	watchServerBootError()
	return
end
if waitForNamed(shared, "Config") == nil or waitForNamed(shared, "Ballistics") == nil then
	return
end

local remotes = remoteEvents

-- Requires einzeln anmelden UND per WaitForChild auflösen: Nachbar-Module
-- können später eintreffen als dieses Skript. Hängt eines, friert die
-- Statuszeile auf seinem Namen ein; fehlt es dauerhaft, gibt es einen
-- benannten roten Fehler statt eines stillen Skript-Todes.
local function requireSibling(name: string): any?
	BootHud.setStatus("Lade Modul: " .. name .. " …")
	local moduleScript = script.Parent:WaitForChild(name, WAIT_TIMEOUT)
	if moduleScript == nil or not moduleScript:IsA("ModuleScript") then
		BootHud.setError(
			"Modul '" .. name .. "' ist nicht in PlayerScripts angekommen — Screenshot bitte."
		)
		return nil
	end
	return require(moduleScript)
end

local PowerBar = requireSibling("PowerBar")
local TrajectoryPreview = requireSibling("TrajectoryPreview")
local ImpactEffects = requireSibling("ImpactEffects")
local ProjectileVisual = requireSibling("ProjectileVisual")
local AimController = requireSibling("AimController")
-- Vollausbau-Module (aktuell Stubs — je ein Element fuellt sie, s. auftraege/):
local CameraDirector = requireSibling("CameraDirector")
local SoundDirector = requireSibling("SoundDirector")
local QuipSystem = requireSibling("QuipSystem")
local DamageNumbers = requireSibling("DamageNumbers")
local HudController = requireSibling("HudController")
local WeaponWheel = requireSibling("WeaponWheel")
if PowerBar == nil
	or TrajectoryPreview == nil
	or ImpactEffects == nil
	or ProjectileVisual == nil
	or AimController == nil
	or CameraDirector == nil
	or SoundDirector == nil
	or QuipSystem == nil
	or DamageNumbers == nil
	or HudController == nil
	or WeaponWheel == nil
then
	return
end

-- Init-Schritte einzeln absichern: ein Crash in einem Modul soll benannt auf dem
-- Bildschirm stehen, nicht den restlichen Bootstrap still mitreißen.
local function step(name: string, fn: () -> ()): boolean
	BootHud.setStatus("Starte " .. name .. " …")
	local ok, err = pcall(fn)
	if not ok then
		BootHud.setError(name .. ": " .. tostring(err))
		return false
	end
	return true
end

if not step("PowerBar", PowerBar.init) then
	return
end
if not step("TrajectoryPreview", TrajectoryPreview.init) then
	return
end
if not step("ImpactEffects", function()
	ImpactEffects.init(remotes) -- Einschlags-Gewicht: Shake, Partikel, Sound
end) then
	return
end
if not step("ProjectileVisual", function()
	ProjectileVisual.init(remotes) -- kosmetisches Projektil, client-gerendert (kein Input-Lag)
end) then
	return
end
if not step("AimController", function()
	AimController.init(remotes)
	-- Seam für die Zustandsmaschine: enable()/disable() steuern das Zielen.
	AimController.enable()
end) then
	return
end
if not step("CameraDirector", function()
	CameraDirector.init(remotes)
end) then
	return
end
if not step("SoundDirector", function()
	SoundDirector.init(remotes)
end) then
	return
end
if not step("QuipSystem", function()
	QuipSystem.init(remotes)
end) then
	return
end
if not step("DamageNumbers", function()
	DamageNumbers.init(remotes)
end) then
	return
end
if not step("HudController", function()
	HudController.init(remotes)
end) then
	return
end
if not step("WeaponWheel", function()
	WeaponWheel.init(remotes)
end) then
	return
end

BootHud.setReady()
-- Nach dem Ready-Text darf ein Server-Fehler ihn überschreiben — die Fehlermeldung
-- ist in dieser Diagnose-Phase wichtiger als der Steuerungs-Hinweis.
watchServerBootError()
