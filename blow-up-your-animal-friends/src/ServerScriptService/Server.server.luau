--!strict
-- Server-Bootstrap: erstellt die RemoteEvents, verdrahtet die Server-Module und
-- generiert danach die Insel.
--
-- Reihenfolge bewusst Remotes ZUERST: Der Client-Bootstrap hängt ausschließlich
-- an den Remotes — ein Fehler in der Weltgenerierung darf ihn nicht mehr in ein
-- stilles "warte auf Server" reißen. Die Handler sind verbunden, bevor der
-- Ordner sichtbar wird; die Weltgenerierung läuft abgesichert danach, und ihr
-- Fehlertext wird als StringValue "ServerBootError" repliziert, damit das
-- BootHud des Clients ihn anzeigen kann (Live-Server haben keine lesbare Konsole).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TerrainIsland = require(script.Parent.TerrainIsland)
local ProjectileServer = require(script.Parent.ProjectileServer)
local FireHandler = require(script.Parent.FireHandler)

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
print("[BUYAF] Server: Remotes aktiv.")

-- Weltgenerierung (legt intern den Terrain-Snapshot für resetTerrain() an).
-- Abgesichert: ein Fehler hier wird benannt statt den Bootstrap zu töten.
local ok, err = pcall(TerrainIsland.generate)
if ok then
	print("[BUYAF] Server: Insel generiert.")
else
	local message = tostring(err)
	warn("[BUYAF] TerrainIsland.generate fehlgeschlagen: " .. message)
	local marker = Instance.new("StringValue")
	marker.Name = "ServerBootError"
	marker.Value = "TerrainIsland.generate: " .. message
	marker.Parent = ReplicatedStorage
end
