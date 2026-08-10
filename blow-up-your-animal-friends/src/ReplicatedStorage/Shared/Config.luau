--!strict
-- Config: ALLE Zahlenwerte des Spiels, gruppiert und kommentiert.
-- Regel: Logikmodule enthalten keine Zahlenliterale (außer 0/1 und Formelkonstanten) —
-- jede Stellschraube fürs Game Feel liegt hier.

local Config = {
	-------------------------------------------------------------------
	-- Ballistik (geteilt zwischen Client-Preview und Server-Simulation).
	-- WICHTIG: Gravitation wird NUR hier definiert, nie workspace.Gravity
	-- lesen — sonst driften Vorschau und echte Flugbahn auseinander.
	-------------------------------------------------------------------
	Ballistics = {
		Gravity = 196.2, -- studs/s², wirkt nach unten (Roblox-Standardwert, aber fest verdrahtet)
		MinSpeed = 55, -- Startgeschwindigkeit bei Stärke 0 (kurzer Lob direkt vor die Füße... fast)
		MaxSpeed = 185, -- Startgeschwindigkeit bei Stärke 1 (Reichweite ~ MaxSpeed²/Gravity ≈ 174 studs bei 45°)
		MinElevationDeg = -75, -- steilster erlaubter Schuss nach unten
		MaxElevationDeg = 85, -- steilster erlaubter Schuss nach oben (nicht exakt senkrecht — Richtung bleibt eindeutig)
	},

	-------------------------------------------------------------------
	-- Feuern / Eingabe
	-------------------------------------------------------------------
	Firing = {
		ChargeTime = 1.1, -- Sekunden Halten von Stärke 0 bis 1 (danach bleibt sie auf 1 stehen)
		CooldownSeconds = 1.0, -- serverseitiger Cooldown pro Spieler (Client spiegelt ihn für die UX)
		MuzzleOffset = Vector3.new(0, 2.5, 0), -- Feuer-Ursprung: leicht über dem Kopf des Charakters
	},

	-------------------------------------------------------------------
	-- Zielen (Client)
	-------------------------------------------------------------------
	Aiming = {
		MaxAimDistance = 2000, -- Länge des Kamera-Raycasts zur Bestimmung des Zielpunkts unter der Maus
	},

	-------------------------------------------------------------------
	-- Projektil-Simulation (Server) und -Visual (Client)
	-------------------------------------------------------------------
	Projectile = {
		MaxFlightTime = 12, -- Sekunden, danach gilt der Schuss als verpufft
		KillY = -80, -- unterhalb dieser Höhe wird die Simulation abgebrochen (ins Meer/Void gefallen)
		Visual = {
			Radius = 0.5, -- Kugelradius des kosmetischen Projektils
			Color = Color3.fromRGB(255, 120, 40),
			TrailLifetime = 0.3, -- Sekunden, die der Tracer nachzieht
			TrailColorStart = Color3.fromRGB(255, 190, 80),
			TrailColorEnd = Color3.fromRGB(255, 70, 20),
			TrailStartTransparency = 0.1,
			TrailEndTransparency = 1,
			RemoveDelay = 0.35, -- Sekunden nach Einschlag, bis das (unsichtbare) Part entfernt wird — lässt den Trail ausblenden
		},
		ServerReference = {
			Enabled = true, -- unsichtbares anchored Server-Part, das der Simulation folgt (Debug/Referenz)
			Radius = 0.4,
		},
	},

	-------------------------------------------------------------------
	-- Krater (einzige Terrainänderung; NUR ProjectileServer, NUR Server)
	-------------------------------------------------------------------
	Crater = {
		Radius = 7, -- studs; FillBall mit Enum.Material.Air
	},

	-------------------------------------------------------------------
	-- Flugbahn-Vorschau (das zentrale Lesbarkeits-Element)
	-------------------------------------------------------------------
	Preview = {
		PointCount = 60, -- maximale Anzahl Vorschau-Punkte
		TimeStep = 0.06, -- Sekunden Flugzeit zwischen zwei Punkten (Punktabstand wächst mit der Geschwindigkeit)
		DotDiameter = 0.6, -- Durchmesser der Neon-Punkte
		DotColor = Color3.fromRGB(255, 235, 130),
		DotTransparencyNear = 0.05, -- Punkte nahe der Mündung
		DotTransparencyFar = 0.55, -- Punkte am Ende der Vorschau (leichtes Ausblenden = Leserichtung)
		EndMarkerDiameter = 1.6, -- größerer Punkt am voraussichtlichen Einschlagsort
		EndMarkerColor = Color3.fromRGB(255, 90, 60),
		EndMarkerTransparency = 0.15,
	},

	-------------------------------------------------------------------
	-- Ladebalken (minimale UI)
	-------------------------------------------------------------------
	PowerBar = {
		WidthPx = 320,
		HeightPx = 20,
		BottomMarginPx = 90, -- Abstand vom unteren Bildschirmrand
		CornerRadiusPx = 6,
		BackgroundColor = Color3.fromRGB(20, 20, 24),
		BackgroundTransparency = 0.35,
		LowColor = Color3.fromRGB(90, 220, 90), -- Stärke 0
		HighColor = Color3.fromRGB(235, 60, 45), -- Stärke 1 (linear interpoliert)
	},

	-------------------------------------------------------------------
	-- Einschlags- und Abschuss-Effekte (Gewicht!)
	-------------------------------------------------------------------
	Effects = {
		Shake = {
			Duration = 0.5, -- Sekunden, bis ein voller Shake abgeklungen ist
			RotationAmplitudeDeg = 2.2, -- maximale Kamerarotation pro Achse bei vollem Trauma
			ImpactTrauma = 0.9, -- Trauma-Zugabe bei Einschlag in Kameranähe (0..1, quadratisches Falloff über Zeit)
			MuzzleTrauma = 0.2, -- kleiner Kick beim Abfeuern
			MaxDistance = 220, -- studs; ab dieser Entfernung schüttelt ein Einschlag gar nicht mehr
		},
		Explosion = {
			SoundId = "rbxassetid://165969964", -- Roblox-Standard-Explosion (Marketplace-Klassiker)
			SoundVolume = 0.9,
			PitchMin = 0.9, -- zufällige PlaybackSpeed-Variation gegen Monotonie
			PitchMax = 1.1,
			FlashBrightness = 8, -- kurzes PointLight beim Einschlag
			FlashRange = 26,
			FlashFadeTime = 0.25,
			BlastCount = 28, -- Partikel-Burst (Feuer)
			BlastColor = Color3.fromRGB(255, 140, 40),
			BlastLifetimeMin = 0.25,
			BlastLifetimeMax = 0.6,
			BlastSpeedMin = 25,
			BlastSpeedMax = 60,
			BlastSizeStart = 3,
			BlastSizeEnd = 0.5,
			SpreadDeg = 180, -- kugelförmiger Burst
			CleanupTime = 5, -- Sekunden, bis das Effekt-Part entfernt wird
		},
		Dust = {
			Count = 18, -- aufsteigender Staub nach dem Blast
			Color = Color3.fromRGB(120, 100, 80),
			LifetimeMin = 1.2,
			LifetimeMax = 2.2,
			SpeedMin = 4,
			SpeedMax = 10,
			RiseAcceleration = 6, -- studs/s² nach oben — Staub steigt
			SizeStart = 2.5,
			SizeEnd = 7,
			TransparencyStart = 0.35,
			TransparencyEnd = 1,
		},
		Muzzle = {
			SoundId = "rbxasset://sounds/Rocket shot.wav", -- eingebauter Roblox-Sound, existiert garantiert
			SoundVolume = 0.55,
			SmokeCount = 8, -- kleiner Rauch-Puff an der Mündung
			SmokeColor = Color3.fromRGB(200, 200, 200),
			SmokeLifetime = 0.5,
			SmokeSpeed = 8,
			CleanupTime = 2,
		},
		FizzleScale = 0.25, -- Effektstärke, wenn ein Schuss ohne Krater endet (Wasser/Void)
	},

	-------------------------------------------------------------------
	-- Insel-Generierung (Server, einmalig beim Start)
	-- Geometrie: große Kugeln mit Zentrum unter y=0 — der herausragende
	-- Kugelabschnitt ist die Insel. Reihenfolge = Überschreib-Reihenfolge:
	-- Grass außen, dann Ground/Rock tiefer → Krater legen Schichten frei.
	-------------------------------------------------------------------
	Terrain = {
		VoxelSize = 4, -- Roblox-Terrain-Rastergröße (fix, von der Engine vorgegeben)
		WaterCenter = Vector3.new(0, -4, 0), -- flaches Meer rund um die Insel (nur Optik)
		WaterSize = Vector3.new(480, 8, 480),
		CoreFills = { -- { Material, Kugelzentrum, Radius } — in dieser Reihenfolge gefüllt
			{ Material = Enum.Material.Grass, Center = Vector3.new(0, -80, 0), Radius = 100 }, -- Inselkuppe, Gipfel bei y=20
			{ Material = Enum.Material.Ground, Center = Vector3.new(0, -84, 0), Radius = 100 }, -- lässt ~4 studs Grass-Schicht
			{ Material = Enum.Material.Rock, Center = Vector3.new(0, -90, 0), Radius = 100 }, -- Kern; Krater erreichen ihn
		},
		Hills = { -- kleine Grass-Kugeln auf der Kuppe → Höhenvariation für interessante Flugbahnen
			{ Material = Enum.Material.Grass, Center = Vector3.new(34, 14, 12), Radius = 14 },
			{ Material = Enum.Material.Grass, Center = Vector3.new(-30, 12, -26), Radius = 12 },
			{ Material = Enum.Material.Grass, Center = Vector3.new(-8, 16, 30), Radius = 10 },
			{ Material = Enum.Material.Ground, Center = Vector3.new(20, 10, -34), Radius = 9 },
		},
		SpawnProbePosition = Vector3.new(0, 100, 0), -- von hier wird nach unten geraycastet, um die Spawn-Höhe zu finden
		SpawnProbeDepth = 200,
		SpawnFallbackY = 24, -- falls der Raycast nichts trifft
		SpawnHeightOffset = 2, -- SpawnLocation sitzt so weit über der Terrain-Oberfläche
		SpawnSize = Vector3.new(8, 1, 8),
		-- Reset-Region für CopyRegion/PasteRegion (muss Vielfache von VoxelSize sein):
		ResetRegionMin = Vector3.new(-160, -60, -160),
		ResetRegionMax = Vector3.new(160, 60, 160),
	},
}

return Config
