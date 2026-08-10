--!strict
-- TerrainIsland: generiert beim Start eine kompakte Insel aus Smooth Terrain.
-- Geometrie: große Kugeln mit Zentrum unter y=0 — der herausragende Kugelabschnitt
-- ist die Insel. Füll-Reihenfolge Grass → Ground → Rock lässt Schichten übrig,
-- die Krater später freilegen (sichtbares Feedback!).
--
-- Nach der Generierung wird die Spielzone per Terrain:CopyRegion gesichert;
-- resetTerrain() stellt sie per PasteRegion wieder her. Bewusst nur eine
-- Funktion, kein System — Seam für den späteren Rundenablauf.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local TerrainIsland = {}

local terrain = workspace.Terrain
local savedRegion: TerrainRegion? = nil
local savedCorner: Vector3int16? = nil

-- Weltkoordinaten → Terrain-Rasterkoordinaten (Region muss auf dem 4er-Raster liegen).
local function toGridRegion(minWorld: Vector3, maxWorld: Vector3): (Region3int16, Vector3int16)
	local voxel = Config.Terrain.VoxelSize
	local min = Vector3int16.new(minWorld.X / voxel, minWorld.Y / voxel, minWorld.Z / voxel)
	local max = Vector3int16.new(maxWorld.X / voxel, maxWorld.Y / voxel, maxWorld.Z / voxel)
	return Region3int16.new(min, max), min
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
	spawnLocation.Material = Enum.Material.WoodPlanks
	spawnLocation.Color = Color3.fromRGB(160, 120, 80)
	spawnLocation.Parent = workspace
end

function TerrainIsland.generate()
	local cfg = Config.Terrain

	-- Meer zuerst (nur Optik) — die Insel-Fills überschreiben es.
	terrain:FillBlock(CFrame.new(cfg.WaterCenter), cfg.WaterSize, Enum.Material.Water)

	for _, fill in cfg.CoreFills do
		terrain:FillBall(fill.Center, fill.Radius, fill.Material)
	end
	for _, hill in cfg.Hills do
		terrain:FillBall(hill.Center, hill.Radius, hill.Material)
	end

	createSpawn()

	-- Snapshot der Spielzone für resetTerrain().
	local gridRegion, corner = toGridRegion(cfg.ResetRegionMin, cfg.ResetRegionMax)
	savedRegion = terrain:CopyRegion(gridRegion)
	savedCorner = corner
end

-- Stellt das Terrain der Spielzone auf den Zustand direkt nach generate() zurück.
-- (pasteEmptyCells = true, damit auch Krater wieder aufgefüllt werden.)
function TerrainIsland.resetTerrain()
	if savedRegion == nil or savedCorner == nil then
		return
	end
	terrain:PasteRegion(savedRegion, savedCorner, true)
end

return TerrainIsland
