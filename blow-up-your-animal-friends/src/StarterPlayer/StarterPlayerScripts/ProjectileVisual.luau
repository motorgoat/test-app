--!strict
-- ProjectileVisual: kosmetisches Projektil, komplett clientseitig gerendert.
-- Auf ProjectileFired (Ursprung, Startgeschwindigkeit) berechnet der Client die
-- Position jeden Frame selbst mit denselben Ballistics-Schritten wie der Server —
-- flüssig mit Framerate, ohne auf Replikation zu warten (kein Input-Lag).
-- Der Server bleibt autoritativ: bei ProjectileImpact wird das Visual auf die
-- Server-Einschlagsposition gesnappt und entfernt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ballistics = require(Shared:WaitForChild("Ballistics"))

local ProjectileVisual = {}

type ActiveShot = {
	part: BasePart,
	origin: Vector3,
	velocity: Vector3,
	startClock: number,
}

local activeShots: { [number]: ActiveShot } = {}

local function createProjectilePart(origin: Vector3): BasePart
	local cfg = Config.Projectile.Visual

	local part = Instance.new("Part")
	part.Name = "ProjectileVisual"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * (cfg.Radius * 2)
	part.CFrame = CFrame.new(origin)
	part.Material = Enum.Material.Neon
	part.Color = cfg.Color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false -- darf Ziel-/Preview-Raycasts nicht stören
	part.CanTouch = false
	part.CastShadow = false

	-- Tracer: Trail zwischen zwei Attachments quer durch die Kugel.
	local attachment0 = Instance.new("Attachment")
	attachment0.Position = Vector3.new(0, cfg.Radius, 0)
	attachment0.Parent = part

	local attachment1 = Instance.new("Attachment")
	attachment1.Position = Vector3.new(0, -cfg.Radius, 0)
	attachment1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Lifetime = cfg.TrailLifetime
	trail.Color = ColorSequence.new(cfg.TrailColorStart, cfg.TrailColorEnd)
	trail.Transparency = NumberSequence.new(cfg.TrailStartTransparency, cfg.TrailEndTransparency)
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.Parent = part

	part.Parent = workspace
	return part
end

-- Part unsichtbar machen, Trail ausklingen lassen, dann aufräumen.
local function retireShot(shotId: number, finalPosition: Vector3?)
	local shot = activeShots[shotId]
	if shot == nil then
		return
	end
	activeShots[shotId] = nil

	if finalPosition ~= nil then
		shot.part.CFrame = CFrame.new(finalPosition)
	end
	shot.part.Transparency = 1
	task.delay(Config.Projectile.Visual.RemoveDelay, function()
		shot.part:Destroy()
	end)
end

local function onFired(shotId: number, origin: Vector3, velocity: Vector3)
	activeShots[shotId] = {
		part = createProjectilePart(origin),
		origin = origin,
		velocity = velocity,
		startClock = os.clock(),
	}
end

local function onImpact(shotId: number, position: Vector3, _craterRadius: number)
	retireShot(shotId, position)
end

local function onRenderStep()
	local maxLifetime = Config.Projectile.MaxFlightTime + Config.Projectile.Visual.RemoveDelay
	for shotId, shot in activeShots do
		local t = os.clock() - shot.startClock
		if t > maxLifetime then
			-- Sicherheitsnetz, falls das Impact-Event verloren ging.
			retireShot(shotId, nil)
		else
			shot.part.CFrame = CFrame.new(Ballistics.positionAtTime(shot.origin, shot.velocity, t))
		end
	end
end

function ProjectileVisual.init(remotes: { ProjectileFired: RemoteEvent, ProjectileImpact: RemoteEvent })
	remotes.ProjectileFired.OnClientEvent:Connect(onFired)
	remotes.ProjectileImpact.OnClientEvent:Connect(onImpact)
	RunService.RenderStepped:Connect(onRenderStep)
end

return ProjectileVisual
