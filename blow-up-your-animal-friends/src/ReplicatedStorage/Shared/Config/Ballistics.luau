--!strict
-- Config-Bereich: Projektilphysik (Element "Projektilphysik" besitzt diese Datei).
-- Ballistics: geteilte Kinematik (Client-Vorschau UND Server-Simulation).
-- WICHTIG: Gravitation wird NUR hier definiert, nie workspace.Gravity lesen.

return {
	Ballistics = {
		Gravity = 196.2, -- studs/s², wirkt nach unten (Roblox-Standardwert, fest verdrahtet)
		MinSpeed = 55, -- Startgeschwindigkeit bei Stärke 0
		MaxSpeed = 185, -- Startgeschwindigkeit bei Stärke 1
		MinElevationDeg = -75, -- steilster erlaubter Schuss nach unten
		MaxElevationDeg = 85, -- steilster erlaubter Schuss nach oben
		-- Vom Element "Projektilphysik" zu fuellen: Wind-Bereich (MaxWindAccel,
		-- pro Runde vom MatchServer gewuerfelt), Abpraller (Restitution-Grenzen,
		-- Mindestgeschwindigkeit), Gewichtsklassen.
	},

	Firing = {
		ChargeTime = 1.1, -- Sekunden Halten von Stärke 0 bis 1
		CooldownSeconds = 1.0, -- serverseitiger Cooldown pro Spieler
		MuzzleOffset = Vector3.new(0, 2.5, 0), -- Feuer-Ursprung über dem Kopf
	},

	Projectile = {
		MaxFlightTime = 12, -- Sekunden, danach gilt der Schuss als verpufft
		KillY = -80, -- unterhalb dieser Höhe wird die Simulation abgebrochen
		Visual = {
			Radius = 0.5,
			Color = Color3.fromRGB(255, 120, 40),
			TrailLifetime = 0.3,
			TrailColorStart = Color3.fromRGB(255, 190, 80),
			TrailColorEnd = Color3.fromRGB(255, 70, 20),
			TrailStartTransparency = 0.1,
			TrailEndTransparency = 1,
			RemoveDelay = 0.35,
		},
		ServerReference = {
			Enabled = true, -- unsichtbares anchored Server-Part folgt der Simulation
			Radius = 0.4,
		},
	},
}
