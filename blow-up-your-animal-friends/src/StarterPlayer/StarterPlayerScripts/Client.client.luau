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

local BootHud = require(script.Parent.BootHud)
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

local fireRequest = waitForNamed(remotesFolder, "FireRequest")
local projectileFired = waitForNamed(remotesFolder, "ProjectileFired")
local projectileImpact = waitForNamed(remotesFolder, "ProjectileImpact")
if fireRequest == nil
	or not fireRequest:IsA("RemoteEvent")
	or projectileFired == nil
	or not projectileFired:IsA("RemoteEvent")
	or projectileImpact == nil
	or not projectileImpact:IsA("RemoteEvent")
then
	BootHud.setError("Remotes unvollständig oder falscher Typ — Screenshot bitte.")
	return
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

local remotes = {
	FireRequest = fireRequest :: RemoteEvent,
	ProjectileFired = projectileFired :: RemoteEvent,
	ProjectileImpact = projectileImpact :: RemoteEvent,
}

-- Requires einzeln anmelden: hängt eines, friert die Statuszeile auf seinem
-- Namen ein — genau die Information, die bisher fehlte.
BootHud.setStatus("Lade Modul: PowerBar …")
local PowerBar = require(script.Parent.PowerBar)
BootHud.setStatus("Lade Modul: TrajectoryPreview …")
local TrajectoryPreview = require(script.Parent.TrajectoryPreview)
BootHud.setStatus("Lade Modul: ImpactEffects …")
local ImpactEffects = require(script.Parent.ImpactEffects)
BootHud.setStatus("Lade Modul: ProjectileVisual …")
local ProjectileVisual = require(script.Parent.ProjectileVisual)
BootHud.setStatus("Lade Modul: AimController …")
local AimController = require(script.Parent.AimController)

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
	-- Seam für die spätere Zustandsmaschine: enable()/disable() steuern das Zielen.
	AimController.enable()
end) then
	return
end

BootHud.setReady()
-- Nach dem Ready-Text darf ein Server-Fehler ihn überschreiben — die Fehlermeldung
-- ist in dieser Diagnose-Phase wichtiger als der Steuerungs-Hinweis.
watchServerBootError()
