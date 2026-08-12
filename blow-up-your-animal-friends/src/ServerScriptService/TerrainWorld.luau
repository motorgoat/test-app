--!strict
-- TerrainWorld: alleiniger Eigentuemer des Terrains (ersetzt TerrainIsland).
-- AKTUELLER STAND (Skelett): v11-Insel, damit das Live-Spiel funktionsfaehig
-- bleibt. Das Element "Zerstoerbares Voxel-Terrain" ersetzt die Generierung
-- durch den 2.5D-Spielstreifen (siehe ARCHITECTURE.md und auftraege/01-terrain.md)
-- und gibt carveCrater seinen Charakter (unregelmaessige Form, verkohlter Rand).
--
-- API-VERTRAG (stabil fuer alle anderen Elemente):
--   generate()                       einmalig beim Serverstart
--   resetTerrain()                   idempotente Neubefuellung (KEIN CopyRegion!)
--   carveCrater(position, radius)    EINZIGE Terrainaenderung im Spiel
--   getSpawnPoints(count): {Vector3} verteilte Standorte fuer MatchServer
--   CraterCarved: BindableEvent-Signal (position, radius) fuer Server-Hoerer
--
-- resetTerrain fuellt einfach neu: identische Fills sind idempotent, Krater
-- (= Luftloecher innerhalb der Kugeln) werden dadurch geschlossen.
-- Terrain:CopyRegion ist VERBOTEN — crashte den Live-Server hart (v3–v7).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TerrainWorld = {}

local terrain = workspace.Terrain

local craterCarved = Instance.new("BindableEvent")
TerrainWorld.CraterCarved = craterCarved.Event

local function mark(step: string)
	ReplicatedStorage:SetAttribute("ServerBootStep", step)
	print("[BUYAF] Server-Schritt: " .. step)
end

local function createSpawn()
	local cfg = Config.Terrain
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	params.IgnoreWater = true

	local result = workspace:Raycast(
		cfg.SpawnProbePosition,
		Vector3.new(0, -cfg.SpawnProbeDepth, 0),
		params
	)
	local surfaceY = if result then result.Position.Y else cfg.SpawnFallbackY

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "IslandSpawn"
	spawnLocation.Size = cfg.SpawnSize
	spawnLocation.Position = Vector3.new(
		cfg.SpawnProbePosition.X,
		surfaceY + cfg.SpawnHeightOffset,
		cfg.SpawnProbePosition.Z
	)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0 -- kein ForceField
	spawnLocation.Material = Config.Terrain.SpawnMaterial
	spawnLocation.Color = Config.Terrain.SpawnColor
	spawnLocation.Parent = workspace
end

local function fillWorld()
	local cfg = Config.Terrain

	mark("terrain: wasser")
	terrain:FillBlock(CFrame.new(cfg.WaterCenter), cfg.WaterSize, Enum.Material.Water)

	for i, fill in cfg.CoreFills do
		mark("terrain: kern " .. i .. "/" .. #cfg.CoreFills)
		terrain:FillBall(fill.Center, fill.Radius, fill.Material)
	end
	mark("terrain: huegel")
	for _, hill in cfg.Hills do
		terrain:FillBall(hill.Center, hill.Radius, hill.Material)
	end
end

function TerrainWorld.generate()
	mark("terrain: start (vorhandene Zellen: " .. tostring(terrain:CountCells()) .. ")")
	fillWorld()
	mark("terrain: spawn")
	createSpawn()
	mark("insel fertig")
end

function TerrainWorld.resetTerrain()
	fillWorld()
end

-- EINZIGE Terrainaenderung im Spiel. Skelett-Fassung: eine Luftkugel.
-- Das Terrain-Element ersetzt das Innere durch einen Krater mit Charakter —
-- Signatur und CraterCarved-Signal bleiben stabil.
function TerrainWorld.carveCrater(position: Vector3, radius: number)
	terrain:FillBall(position, radius, Enum.Material.Air)
	craterCarved:Fire(position, radius)
end

-- Verteilte Spawn-Standorte fuer den MatchServer. Skelett-Fassung: rastert
-- die Flaeche um den Ursprung ab und nimmt die Oberflaechenpunkte.
function TerrainWorld.getSpawnPoints(count: number): { Vector3 }
	local cfg = Config.Terrain
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	params.IgnoreWater = true

	local points = {}
	for i = 1, count do
		-- Symmetrisch um den Ursprung verteilte Proben entlang X (Spielstreifen).
		local alpha = (i - (count + 1) * 0.5) / math.max(count, 1)
		local x = alpha * cfg.WaterSize.X * 0.5
		local result = workspace:Raycast(
			Vector3.new(x, cfg.SpawnProbePosition.Y, 0),
			Vector3.new(0, -cfg.SpawnProbeDepth, 0),
			params
		)
		if result ~= nil then
			table.insert(points, result.Position + Vector3.new(0, cfg.SpawnHeightOffset, 0))
		end
	end
	return points
end

return TerrainWorld
