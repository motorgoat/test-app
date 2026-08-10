--!strict
-- ImpactEffects: das GEWICHT des Einschlags — Explosions-Partikel (ParticleEmitter,
-- kein Explosion-Instance-Schaden), kurzer Kamera-Shake mit Distanz-Falloff,
-- Explosions-Sound, aufsteigender Staub, kurzes Licht. Beim Abfeuern ein kleiner
-- Mündungs-Kick (Sound + Rauch-Puff + Mini-Shake), lokal und sofort.
--
-- Shake-Modell: "Trauma" 0..1, das linear abklingt; die Amplitude ist Trauma²
-- (kleine Treffer wackeln kaum, nahe Treffer ordentlich). Angewandt als
-- Rotations-Offset NACH dem Kamera-Update (RenderPriority.Camera + 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ImpactEffects = {}

local rng = Random.new()
local trauma = 0

local function addTrauma(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

local function bindShake()
	local cfg = Config.Effects.Shake
	RunService:BindToRenderStep("ImpactShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if trauma <= 0 then
			return
		end
		trauma = math.max(trauma - dt / cfg.Duration, 0)
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local intensity = trauma * trauma
		local maxAngle = math.rad(cfg.RotationAmplitudeDeg) * intensity
		camera.CFrame = camera.CFrame * CFrame.Angles(
			rng:NextNumber(-maxAngle, maxAngle),
			rng:NextNumber(-maxAngle, maxAngle),
			rng:NextNumber(-maxAngle, maxAngle)
		)
	end)
end

-- Unsichtbarer, verankerter Träger für Emitter/Sound/Licht an einer Weltposition.
local function createEffectAnchor(position: Vector3, lifetime: number): BasePart
	local part = Instance.new("Part")
	part.Name = "EffectAnchor"
	part.Size = Vector3.one
	part.CFrame = CFrame.new(position)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	task.delay(lifetime, function()
		part:Destroy()
	end)
	return part
end

local function playSound(parent: Instance, soundId: string, volume: number, pitchMin: number, pitchMax: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = rng:NextNumber(pitchMin, pitchMax)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = parent
	sound:Play()
end

-- Distanz-Falloff 1 (nah) .. 0 (weiter als MaxDistance entfernt).
local function distanceScale(position: Vector3): number
	local camera = workspace.CurrentCamera
	if camera == nil then
		return 0
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	return math.clamp(1 - distance / Config.Effects.Shake.MaxDistance, 0, 1)
end

local function emitExplosion(anchor: BasePart, scale: number)
	local cfg = Config.Effects.Explosion

	local blast = Instance.new("ParticleEmitter")
	blast.Enabled = false
	blast.Color = ColorSequence.new(cfg.BlastColor)
	blast.LightEmission = 1
	blast.Lifetime = NumberRange.new(cfg.BlastLifetimeMin, cfg.BlastLifetimeMax)
	blast.Speed = NumberRange.new(cfg.BlastSpeedMin, cfg.BlastSpeedMax)
	blast.SpreadAngle = Vector2.new(cfg.SpreadDeg, cfg.SpreadDeg)
	blast.Size = NumberSequence.new(cfg.BlastSizeStart, cfg.BlastSizeEnd)
	blast.Parent = anchor
	blast:Emit(math.floor(cfg.BlastCount * scale))

	-- Kurzer Lichtblitz — verkauft den Knall auch im Augenwinkel.
	local flash = Instance.new("PointLight")
	flash.Brightness = cfg.FlashBrightness * scale
	flash.Range = cfg.FlashRange
	flash.Parent = anchor
	TweenService:Create(flash, TweenInfo.new(cfg.FlashFadeTime), { Brightness = 0 }):Play()
end

local function emitDust(anchor: BasePart, scale: number)
	local cfg = Config.Effects.Dust

	local dust = Instance.new("ParticleEmitter")
	dust.Enabled = false
	dust.Color = ColorSequence.new(cfg.Color)
	dust.Lifetime = NumberRange.new(cfg.LifetimeMin, cfg.LifetimeMax)
	dust.Speed = NumberRange.new(cfg.SpeedMin, cfg.SpeedMax)
	dust.Acceleration = Vector3.new(0, cfg.RiseAcceleration, 0) -- Staub steigt auf
	dust.Size = NumberSequence.new(cfg.SizeStart, cfg.SizeEnd)
	dust.Transparency = NumberSequence.new(cfg.TransparencyStart, cfg.TransparencyEnd)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Parent = anchor
	dust:Emit(math.floor(cfg.Count * scale))
end

local function onImpact(_shotId: number, position: Vector3, craterRadius: number)
	local effects = Config.Effects
	-- Verpuffer (Wasser/Void, craterRadius 0) bekommen nur abgeschwächte Effekte.
	local scale = if craterRadius > 0 then 1 else effects.FizzleScale

	local anchor = createEffectAnchor(position, effects.Explosion.CleanupTime)
	emitExplosion(anchor, scale)
	emitDust(anchor, scale)
	playSound(
		anchor,
		effects.Explosion.SoundId,
		effects.Explosion.SoundVolume * scale,
		effects.Explosion.PitchMin,
		effects.Explosion.PitchMax
	)
	addTrauma(effects.Shake.ImpactTrauma * scale * distanceScale(position))
end

-- Vom AimController direkt beim Loslassen aufgerufen — sofortiges Feedback,
-- ohne auf das ProjectileFired-Event des Servers zu warten.
function ImpactEffects.muzzleKick(origin: Vector3)
	local cfg = Config.Effects.Muzzle

	local anchor = createEffectAnchor(origin, cfg.CleanupTime)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Enabled = false
	smoke.Color = ColorSequence.new(cfg.SmokeColor)
	smoke.Lifetime = NumberRange.new(cfg.SmokeLifetime)
	smoke.Speed = NumberRange.new(cfg.SmokeSpeed)
	smoke.Parent = anchor
	smoke:Emit(cfg.SmokeCount)

	playSound(anchor, cfg.SoundId, cfg.SoundVolume, 1, 1)
	addTrauma(Config.Effects.Shake.MuzzleTrauma)
end

function ImpactEffects.init(remotes: { ProjectileImpact: RemoteEvent })
	bindShake()
	remotes.ProjectileImpact.OnClientEvent:Connect(onImpact)
end

return ImpactEffects
