--!strict
-- TerrainIsland: generiert beim Start eine kompakte Insel aus Smooth Terrain.
-- Geometrie: große Kugeln mit Zentrum unter y=0 — der herausragende Kugelabschnitt
-- ist die Insel. Füll-Reihenfolge Grass → Ground → Rock lässt Schichten übrig,
-- die Krater später freilegen (sichtbares Feedback!).
--
-- resetTerrain() führt einfach dieselben Fills erneut aus: identische Fills sind
-- idempotent, und Krater (= Luftlöcher innerhalb der Kugeln) werden dadurch wieder
-- geschlossen. Der frühere CopyRegion/PasteRegion-Snapshot ist ausgebaut —
-- Verdacht auf harten Server-Absturz während des Snapshots (Gauntlet-Diagnose;
-- der Server starb reproduzierbar zwischen Spawn-Erstellung und Remote-Parenting).
--
-- Jeder Schritt meldet sich über das replizierte Attribut "ServerBootStep" —
-- das BootHud des Clients spiegelt es, damit ein Server-Crash mitten in der
-- Generierung auf dem Bildschirm des Spielers benannt ist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local TerrainIsland = {}

local terrain = workspace.Terrain

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
	spawnLocation.Material = Enum.Material.WoodPlanks
	spawnLocation.Color = Color3.fromRGB(160, 120, 80)
	spawnLocation.Parent = workspace
end

local function fillWorld()
	local cfg = Config.Terrain

	-- Meer zuerst (nur Optik) — die Insel-Fills überschreiben es.
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

function TerrainIsland.generate()
	-- Zellen VOR dem Füllen: >0 hieße, dass altes Terrain den Place-Upload
	-- überlebt hat (Merge-Verdacht) — wichtiger Diagnosewert.
	mark("terrain: start (vorhandene Zellen: " .. tostring(terrain:CountCells()) .. ")")
	fillWorld()
	mark("terrain: spawn")
	createSpawn()
	mark("insel fertig")
end

-- Stellt das Terrain der Spielzone auf den Zustand direkt nach generate() zurück.
-- Seam für den späteren Rundenablauf.
function TerrainIsland.resetTerrain()
	fillWorld()
end

return TerrainIsland
