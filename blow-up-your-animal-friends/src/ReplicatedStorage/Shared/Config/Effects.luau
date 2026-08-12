--!strict
-- Config-Bereich: Trefferfeedback (Element "Trefferfeedback" besitzt diese Datei).

return {
	Effects = {
		Shake = {
			Duration = 0.5,
			RotationAmplitudeDeg = 2.2,
			ImpactTrauma = 0.9,
			MuzzleTrauma = 0.2,
			MaxDistance = 220, -- studs; ab dieser Entfernung kein Shake mehr
		},
		Explosion = {
			SoundId = "rbxasset://sounds/collide.wav", -- Builtin: garantiert hörbar (Audio-Privacy!)
			SoundVolume = 0.9,
			PitchMin = 0.9,
			PitchMax = 1.1,
			FlashBrightness = 8,
			FlashRange = 26,
			FlashFadeTime = 0.25,
			BlastCount = 28,
			BlastColor = Color3.fromRGB(255, 140, 40),
			BlastLifetimeMin = 0.25,
			BlastLifetimeMax = 0.6,
			BlastSpeedMin = 25,
			BlastSpeedMax = 60,
			BlastSizeStart = 3,
			BlastSizeEnd = 0.5,
			SpreadDeg = 180,
			CleanupTime = 5,
		},
		Dust = {
			Count = 18,
			Color = Color3.fromRGB(120, 100, 80),
			LifetimeMin = 1.2,
			LifetimeMax = 2.2,
			SpeedMin = 4,
			SpeedMax = 10,
			RiseAcceleration = 6,
			SizeStart = 2.5,
			SizeEnd = 7,
			TransparencyStart = 0.35,
			TransparencyEnd = 1,
		},
		Muzzle = {
			SoundId = "rbxasset://sounds/Rocket shot.wav", -- Builtin, existiert garantiert
			SoundVolume = 0.55,
			SmokeCount = 8,
			SmokeColor = Color3.fromRGB(200, 200, 200),
			SmokeLifetime = 0.5,
			SmokeSpeed = 8,
			CleanupTime = 2,
		},
		FizzleScale = 0.25, -- Effektstärke, wenn ein Schuss ohne Krater endet
	},
}
