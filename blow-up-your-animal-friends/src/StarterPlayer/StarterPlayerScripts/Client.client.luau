--!strict
-- Client-Bootstrap: wartet auf die Remotes des Servers und initialisiert
-- die Client-Module in Abhängigkeitsreihenfolge. Danach ist Zielen aktiv.
--
-- Jeder Schritt meldet seinen Status ans BootHud — im Live-Spiel gibt es keine
-- sichtbare Konsole, deshalb müssen Hänger und Fehler auf dem Bildschirm landen.
-- WaitForChild läuft mit Timeout statt endlos: ein toter Server-Bootstrap
-- (keine Remotes) wird so als Fehlermeldung sichtbar statt als stilles Nichts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BootHud = require(script.Parent.BootHud)
BootHud.init()

local REMOTES_TIMEOUT = 15 -- Sekunden; danach gilt der Server-Bootstrap als tot
local REMOTE_TIMEOUT = 5

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

BootHud.setStatus("Lade… warte auf Server (Remotes)")
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", REMOTES_TIMEOUT)
if remotesFolder == nil then
	-- Diagnose: Was sieht der Client tatsächlich in ReplicatedStorage?
	-- Unterscheidet "Server-Skript tot" von "Replikation kaputt".
	local childNames = {}
	for _, child in ReplicatedStorage:GetChildren() do
		table.insert(childNames, child.Name)
	end
	BootHud.setError(
		"Server-Remotes nicht gefunden — Server-Skript vermutlich abgestürzt. "
			.. "ReplicatedStorage enthält: ["
			.. table.concat(childNames, ", ")
			.. "]. Bitte Screenshot dieser Meldung schicken."
	)
	watchServerBootError()
	return
end

local function waitForRemote(name: string): RemoteEvent?
	local remote = remotesFolder:WaitForChild(name, REMOTE_TIMEOUT)
	if remote == nil or not remote:IsA("RemoteEvent") then
		BootHud.setError("RemoteEvent '" .. name .. "' fehlt oder hat den falschen Typ.")
		return nil
	end
	return remote
end

local fireRequest = waitForRemote("FireRequest")
local projectileFired = waitForRemote("ProjectileFired")
local projectileImpact = waitForRemote("ProjectileImpact")
if fireRequest == nil or projectileFired == nil or projectileImpact == nil then
	return
end

local remotes = {
	FireRequest = fireRequest,
	ProjectileFired = projectileFired,
	ProjectileImpact = projectileImpact,
}

-- Init-Schritte einzeln absichern: ein Crash in einem Modul soll benannt auf dem
-- Bildschirm stehen, nicht den restlichen Bootstrap still mitreißen.
local function step(name: string, fn: () -> ()): boolean
	BootHud.setStatus("Lade… " .. name)
	local ok, err = pcall(fn)
	if not ok then
		BootHud.setError(name .. ": " .. tostring(err))
		return false
	end
	return true
end

local PowerBar = require(script.Parent.PowerBar)
local TrajectoryPreview = require(script.Parent.TrajectoryPreview)
local ImpactEffects = require(script.Parent.ImpactEffects)
local ProjectileVisual = require(script.Parent.ProjectileVisual)
local AimController = require(script.Parent.AimController)

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
