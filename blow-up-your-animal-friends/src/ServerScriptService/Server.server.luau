--!strict
-- Server-Bootstrap: holt die statischen RemoteEvents, verdrahtet die
-- Server-Module und generiert danach die Welt.
--
-- Die RemoteEvents liegen STATISCH im Place-File (default.project.json →
-- ReplicatedStorage/Remotes): Teil des Join-Snapshots, den jeder Client
-- garantiert bekommt — zur Laufzeit erstellte Instanzen kamen beim Client
-- dieser Experience nachweislich nicht zuverlaessig an (Gauntlet, v3–v8).
--
-- Boot-Fortschritt wird als repliziertes Attribut "ServerBootStep" gemeldet;
-- das BootHud des Clients spiegelt es (stirbt der Server, steht sein letzter
-- Schritt auf dem Bildschirm des Spielers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function mark(step: string)
	ReplicatedStorage:SetAttribute("ServerBootStep", step)
	print("[BUYAF] Server-Schritt: " .. step)
end

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local function getRemote(name: string): RemoteEvent
	return remotesFolder:WaitForChild(name) :: RemoteEvent
end

local remotes = {
	FireRequest = getRemote("FireRequest"), -- Client → Server: (Richtung, Stärke)
	ProjectileFired = getRemote("ProjectileFired"), -- Server → Clients: (shotId, Ursprung, Startgeschwindigkeit)
	ProjectileImpact = getRemote("ProjectileImpact"), -- Server → Clients: (shotId, Position, Kraterradius)
	WeaponSelect = getRemote("WeaponSelect"), -- Client → Server: (weaponId)
	MatchEvent = getRemote("MatchEvent"), -- Server → Clients: (phase, daten) — Rundenzustand
	QuipEvent = getRemote("QuipEvent"), -- Server → Clients: (situation, wurmName)
	CameraCue = getRemote("CameraCue"), -- Server → Clients: (cue, daten) — Kamera-Regieanweisung
	DamageEvent = getRemote("DamageEvent"), -- Server → Clients: (wurm, schaden, istKritisch, position)
}

mark("remotes aktiv (Place v" .. tostring(game.PlaceVersion) .. ")")

local TerrainWorld = require(script.Parent.TerrainWorld)
local ProjectileServer = require(script.Parent.ProjectileServer)
local FireHandler = require(script.Parent.FireHandler)
local WeaponServer = require(script.Parent.WeaponServer)
local MatchServer = require(script.Parent.MatchServer)
mark("module geladen")

ProjectileServer.init(remotes)
FireHandler.init(remotes)
WeaponServer.init({
	remotes = remotes,
	projectileServer = ProjectileServer,
	terrainWorld = TerrainWorld,
})
MatchServer.init({
	remotes = remotes,
	terrainWorld = TerrainWorld,
	fireHandler = FireHandler,
	weaponServer = WeaponServer,
	projectileServer = ProjectileServer,
})
mark("handler verbunden")

-- Weltgenerierung abgesichert: ein Fehler hier wird benannt statt den
-- Bootstrap zu toeten (der Fehlertext repliziert als ServerBootError).
local ok, err = pcall(TerrainWorld.generate)
if ok then
	mark("server bereit")
else
	local message = tostring(err)
	warn("[BUYAF] TerrainWorld.generate fehlgeschlagen: " .. message)
	local marker = Instance.new("StringValue")
	marker.Name = "ServerBootError"
	marker.Value = "TerrainWorld.generate: " .. message
	marker.Parent = ReplicatedStorage
end
