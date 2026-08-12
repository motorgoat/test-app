--!strict
-- Config-Bereich: Weltgenerierung (Element "Zerstoerbares Voxel-Terrain" besitzt
-- diese Datei). Aktuell: die v11-Insel. Das Element ersetzt sie durch den
-- 2.5D-Spielstreifen (Huegel, Ueberhaenge, Materialschichten) zwischen den
-- statischen Waenden bei z=±14 (default.project.json).

return {
	Terrain = {
		VoxelSize = 4, -- Roblox-Terrain-Rastergröße (von der Engine vorgegeben)
		WaterCenter = Vector3.new(0, -4, 0),
		WaterSize = Vector3.new(480, 8, 480),
		CoreFills = { -- { Material, Kugelzentrum, Radius } — in dieser Reihenfolge gefüllt
			{ Material = Enum.Material.Grass, Center = Vector3.new(0, -80, 0), Radius = 100 },
			{ Material = Enum.Material.Ground, Center = Vector3.new(0, -84, 0), Radius = 100 },
			{ Material = Enum.Material.Rock, Center = Vector3.new(0, -90, 0), Radius = 100 },
		},
		Hills = {
			{ Material = Enum.Material.Grass, Center = Vector3.new(34, 14, 12), Radius = 14 },
			{ Material = Enum.Material.Grass, Center = Vector3.new(-30, 12, -26), Radius = 12 },
			{ Material = Enum.Material.Grass, Center = Vector3.new(-8, 16, 30), Radius = 10 },
			{ Material = Enum.Material.Ground, Center = Vector3.new(20, 10, -34), Radius = 9 },
		},
		SpawnProbePosition = Vector3.new(0, 100, 0),
		SpawnProbeDepth = 200,
		SpawnFallbackY = 24,
		SpawnHeightOffset = 2,
		SpawnSize = Vector3.new(8, 1, 8),
		SpawnMaterial = Enum.Material.WoodPlanks,
		SpawnColor = Color3.fromRGB(160, 120, 80),
	},
}
