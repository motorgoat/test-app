--!strict
-- ProjectileServer: serverautoritative, KINEMATISCHE Projektil-Simulation.
-- Kein unanchored Physik-Part für die Logik — die Flugbahn wird schrittweise per
-- Heartbeat mit Ballistics.step berechnet und zwischen den Schritten geraycastet.
-- Dadurch ist die Server-Flugbahn mathematisch identisch mit der Client-Vorschau.
--
-- Terrainänderung (Krater) passiert AUSSCHLIESSLICH hier, ausschließlich serverseitig.
--
-- Optionales Referenz-Part: anchored + unsichtbar, folgt der Simulation.
-- Guardrail "Network Ownership auf Server" ist damit konstruktiv erfüllt:
-- anchored Parts gehören automatisch dem Server; SetNetworkOwner ist auf
-- anchored Parts gar nicht anwendbar (und hier auch nicht nötig).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ballistics = require(Shared:WaitForChild("Ballistics"))

local ProjectileServer = {}

type Remotes = {
	ProjectileFired: RemoteEvent,
	ProjectileImpact: RemoteEvent,
}

local remotes: Remotes? = nil
local nextShotId = 0

function ProjectileServer.init(remoteTable: Remotes)
	remotes = remoteTable
end

local function createReferencePart(origin: Vector3): BasePart?
	local cfg = Config.Projectile.ServerReference
	if not cfg.Enabled then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "ServerProjectileRef"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * (cfg.Radius * 2)
	part.CFrame = CFrame.new(origin)
	part.Anchored = true -- anchored ⇒ Server ist automatisch Network Owner
	part.Transparency = 1 -- Client rendert sein eigenes Visual; das hier ist nur Referenz
	part.CanCollide = false
	part.CanQuery = false -- eigene Raycasts dürfen es nicht treffen
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	return part
end

local function fireImpact(shotId: number, position: Vector3, craterRadius: number)
	local r = remotes
	if r ~= nil then
		r.ProjectileImpact:FireAllClients(shotId, position, craterRadius)
	end
end

local function simulate(shooter: Player, shotId: number, origin: Vector3, velocity: Vector3)
	local cfg = Config.Projectile

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = {}
	if shooter.Character ~= nil then
		table.insert(filter, shooter.Character)
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = false -- Wassertreffer sollen erkannt werden (verpuffen ohne Krater)

	local refPart = createReferencePart(origin)

	local position = origin
	local currentVelocity = velocity
	local elapsed = 0

	while elapsed < cfg.MaxFlightTime do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt

		local nextPosition, nextVelocity = Ballistics.step(position, currentVelocity, dt)

		-- Raycast zwischen den Simulationsschritten — kein Tunneln.
		local result = workspace:Raycast(position, nextPosition - position, params)
		if result ~= nil then
			local craterRadius = Config.Crater.Radius
			if result.Instance == workspace.Terrain and result.Material == Enum.Material.Water then
				-- Ins Meer: kein Krater, nur Verpuffen.
				craterRadius = 0
			else
				-- EINZIGE Terrainänderung im Spiel: Krater sprengen.
				workspace.Terrain:FillBall(result.Position, craterRadius, Enum.Material.Air)
			end
			fireImpact(shotId, result.Position, craterRadius)
			if refPart ~= nil then
				refPart:Destroy()
			end
			return
		end

		position = nextPosition
		currentVelocity = nextVelocity
		if refPart ~= nil then
			refPart.CFrame = CFrame.new(position)
		end

		if position.Y < cfg.KillY then
			break
		end
	end

	-- Nichts getroffen (Flugzeit abgelaufen oder aus der Welt gefallen): Verpuffen.
	fireImpact(shotId, position, 0)
	if refPart ~= nil then
		refPart:Destroy()
	end
end

-- Startet einen serverautoritativen Schuss. origin/velocity sind bereits
-- serverseitig validiert und berechnet (FireHandler).
function ProjectileServer.fire(shooter: Player, origin: Vector3, velocity: Vector3)
	local r = remotes
	assert(r ~= nil, "ProjectileServer.init muss vor fire() aufgerufen werden")

	nextShotId += 1
	local shotId = nextShotId

	-- Clients rendern das Projektil sofort selbst (kein Input-Lag).
	r.ProjectileFired:FireAllClients(shotId, origin, velocity)
	task.spawn(simulate, shooter, shotId, origin, velocity)
end

return ProjectileServer
