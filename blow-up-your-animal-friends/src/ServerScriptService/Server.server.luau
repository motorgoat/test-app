--!strict
-- Server-Bootstrap: erstellt die RemoteEvents, generiert die Insel und
-- verdrahtet die Server-Module. Reihenfolge: erst Welt, dann Remotes parenten,
-- damit Clients beim WaitForChild eine fertige Welt vorfinden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrainIsland = require(script.Parent.TerrainIsland)
local ProjectileServer = require(script.Parent.ProjectileServer)
local FireHandler = require(script.Parent.FireHandler)

-- Insel generieren (legt intern den Terrain-Snapshot für resetTerrain() an).
TerrainIsland.generate()

-- RemoteEvents: Server erstellt sie, Clients warten mit WaitForChild.
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"

local function createRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local remotes = {
	FireRequest = createRemote("FireRequest"), -- Client → Server: (Richtung, Stärke)
	ProjectileFired = createRemote("ProjectileFired"), -- Server → Clients: (shotId, Ursprung, Startgeschwindigkeit)
	ProjectileImpact = createRemote("ProjectileImpact"), -- Server → Clients: (shotId, Position, Kraterradius)
}

ProjectileServer.init(remotes)
FireHandler.init(remotes)

-- Erst jetzt sichtbar machen — alle Handler hängen bereits.
remotesFolder.Parent = ReplicatedStorage

print("[BUYAF] Server bereit — Insel generiert, Remotes aktiv.")
