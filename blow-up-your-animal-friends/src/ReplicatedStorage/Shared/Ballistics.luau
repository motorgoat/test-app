--!strict
-- Ballistics: pure, deterministische Flugbahn-Mathematik.
-- Wird von Client (TrajectoryPreview, ProjectileVisual) UND Server (ProjectileServer,
-- FireHandler) benutzt, damit Vorschau und echte Flugbahn EXAKT übereinstimmen.
--
-- Gravitation kommt ausschließlich aus Config.Ballistics.Gravity — hier ist die
-- EINZIGE Stelle, an der sie in einen Vektor übersetzt wird. workspace.Gravity
-- wird bewusst nirgends gelesen.
--
-- Da die Beschleunigung konstant ist, ist step() eine EXAKTE Integration:
-- beliebig zerhackte Heartbeat-Schritte auf dem Server ergeben dieselben Punkte
-- wie das geschlossene positionAtTime() der Client-Vorschau.

local Config = require(script.Parent.Config)

local GRAVITY: Vector3 = Vector3.new(0, -Config.Ballistics.Gravity, 0)

local Ballistics = {}

-- Startgeschwindigkeit aus Einheitsrichtung + Stärke (0..1).
function Ballistics.initialVelocity(direction: Vector3, power: number): Vector3
	local speed = Config.Ballistics.MinSpeed
		+ power * (Config.Ballistics.MaxSpeed - Config.Ballistics.MinSpeed)
	return direction * speed
end

-- Normalisiert eine Richtung und klemmt den Elevationswinkel auf die Config-Grenzen.
-- Client (Vorschau) und Server (Validierung) benutzen dieselbe Funktion — dadurch
-- zeigt die Vorschau exakt das, was der Server akzeptiert.
-- Gibt nil zurück, wenn die Richtung unbrauchbar ist (Nullvektor, NaN, exakt senkrecht).
function Ballistics.clampDirection(direction: Vector3): Vector3?
	local magnitude = direction.Magnitude
	-- NaN, Nullvektor ODER Unendlich: inf.Unit ergäbe NaN und schlüpfte sonst
	-- durch die Winkelklemmung (Audit-Befund: inf-Vektor vom Client).
	if magnitude ~= magnitude or magnitude == 0 or magnitude == math.huge then
		return nil
	end
	local unit = direction.Unit
	local horizontal = Vector3.new(unit.X, 0, unit.Z)
	local elevationDeg = math.deg(math.atan2(unit.Y, horizontal.Magnitude))
	local clampedDeg = math.clamp(
		elevationDeg,
		Config.Ballistics.MinElevationDeg,
		Config.Ballistics.MaxElevationDeg
	)
	if clampedDeg == elevationDeg then
		return unit
	end
	if horizontal.Magnitude == 0 then
		-- Exakt senkrecht: horizontale Richtung unbestimmt, nicht rekonstruierbar.
		return nil
	end
	local clampedRad = math.rad(clampedDeg)
	return horizontal.Unit * math.cos(clampedRad) + Vector3.yAxis * math.sin(clampedRad)
end

-- Geschlossene Form: Position nach t Sekunden Flugzeit.
function Ballistics.positionAtTime(origin: Vector3, initialVelocity: Vector3, t: number): Vector3
	return origin + initialVelocity * t + GRAVITY * (0.5 * t * t)
end

-- Geschlossene Form: Geschwindigkeit nach t Sekunden Flugzeit.
function Ballistics.velocityAtTime(initialVelocity: Vector3, t: number): Vector3
	return initialVelocity + GRAVITY * t
end

-- Schrittfunktion für die Server-Simulation. Exakte Integration bei konstanter
-- Beschleunigung — Komposition beliebiger Schritte entspricht positionAtTime().
function Ballistics.step(position: Vector3, velocity: Vector3, dt: number): (Vector3, Vector3)
	local newPosition = position + velocity * dt + GRAVITY * (0.5 * dt * dt)
	local newVelocity = velocity + GRAVITY * dt
	return newPosition, newVelocity
end

-- Punkte für die Flugbahn-Vorschau: Positionen bei t = timeStep, 2*timeStep, ...
-- (Der Punktabstand wächst mit der Geschwindigkeit — das liest sich wie in
-- ShellShock Live: dichte Punkte = langsam, weite Punkte = schnell.)
function Ballistics.trajectoryPoints(
	origin: Vector3,
	initialVelocity: Vector3,
	pointCount: number,
	timeStep: number
): { Vector3 }
	local points = table.create(pointCount)
	for i = 1, pointCount do
		points[i] = Ballistics.positionAtTime(origin, initialVelocity, i * timeStep)
	end
	return points
end

-- Feuer-Ursprung: leicht über dem Kopf des Charakters (Config-Offset).
-- Bewusst hier im geteilten Modul, damit Client-Vorschau und Server-Simulation
-- vom selben Punkt aus rechnen.
function Ballistics.muzzleOrigin(character: Model?): Vector3?
	if character == nil then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return nil
	end
	return head.Position + Config.Firing.MuzzleOffset
end

return Ballistics
