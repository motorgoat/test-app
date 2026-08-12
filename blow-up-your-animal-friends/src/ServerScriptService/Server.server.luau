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

-- Die RemoteEvents liegen STATISCH im Place-File (default.project.json →
-- ReplicatedStorage/Remotes). Sie sind damit Teil des Join-Snapshots, den jeder
-- Client garantiert bekommt — zur Laufzeit erstellte Instanzen kamen beim
-- Client dieser Experience nachweislich nicht an (Gauntlet-Diagnose, v3–v8).
-- Der Server erstellt hier also nichts mehr, er greift nur noch zu.
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local remotes = {
	FireRequest = remotesFolder:WaitForChild("FireRequest") :: RemoteEvent, -- Client → Server: (Richtung, Stärke)
	ProjectileFired = remotesFolder:WaitForChild("ProjectileFired") :: RemoteEvent, -- Server → Clients: (shotId, Ursprung, Startgeschwindigkeit)
	ProjectileImpact = remotesFolder:WaitForChild("ProjectileImpact") :: RemoteEvent, -- Server → Clients: (shotId, Position, Kraterradius)
}

-- Boot-Fortschritt als repliziertes Attribut: das BootHud des Clients spiegelt
-- es live. Stirbt der Server, steht sein letzter Schritt auf dem Bildschirm.
local function mark(step: string)
	ReplicatedStorage:SetAttribute("ServerBootStep", step)
	print("[BUYAF] Server-Schritt: " .. step)
end

mark("remotes aktiv (Place v" .. tostring(game.PlaceVersion) .. ")")

local TerrainIsland = require(script.Parent.TerrainIsland)
local ProjectileServer = require(script.Parent.ProjectileServer)
local FireHandler = require(script.Parent.FireHandler)
mark("module geladen")

ProjectileServer.init(remotes)
FireHandler.init(remotes)
mark("handler verbunden")

-- Weltgenerierung (legt intern den Terrain-Snapshot für resetTerrain() an).
-- Abgesichert: ein Fehler hier wird benannt statt den Bootstrap zu töten.
local ok, err = pcall(TerrainIsland.generate)
if ok then
	mark("server bereit")
else
	local message = tostring(err)
	warn("[BUYAF] TerrainIsland.generate fehlgeschlagen: " .. message)
	local marker = Instance.new("StringValue")
	marker.Name = "ServerBootError"
	marker.Value = "TerrainIsland.generate: " .. message
	marker.Parent = ReplicatedStorage
end
