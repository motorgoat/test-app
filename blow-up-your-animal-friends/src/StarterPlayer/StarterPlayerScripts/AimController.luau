--!strict
-- AimController: Zielen mit der Maus, Stärke durch Halten der linken Maustaste,
-- Loslassen feuert. Touch funktioniert analog: Finger halten = laden, heben = feuern,
-- gezielt wird auf die letzte Touch-Position. Sendet AUSSCHLIESSLICH
-- (Richtung, Stärke) an den Server — Ursprung und Wirkung berechnet der Server selbst.
--
-- Seam für die spätere Zustandsmaschine: enable()/disable().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ballistics = require(Shared:WaitForChild("Ballistics"))

local TrajectoryPreview = require(script.Parent.TrajectoryPreview)
local PowerBar = require(script.Parent.PowerBar)
local ImpactEffects = require(script.Parent.ImpactEffects)

local AimController = {}

local localPlayer = Players.LocalPlayer

local fireRequest: RemoteEvent? = nil
local enabled = false
local chargeStartClock: number? = nil -- nil = nicht am Laden
local lastFireClock = -math.huge -- Client-Spiegel des Server-Cooldowns (nur UX)

local renderConnection: RBXScriptConnection? = nil
local inputBeganConnection: RBXScriptConnection? = nil
local inputEndedConnection: RBXScriptConnection? = nil
local inputChangedConnection: RBXScriptConnection? = nil

-- Auf Touch-Geräten liefert GetMouseLocation keine verlässliche Position —
-- dort zielt die zuletzt gesehene Touch-Position (bleibt nach dem Heben stehen,
-- damit die Vorschau nicht springt). Desktop: nil → Mausposition.
local lastTouchPosition: Vector2? = nil

local function isFireInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local aimRaycastParams = RaycastParams.new()
aimRaycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- Aktuelle Stärke 0..1 aus der Haltedauer (linear, bleibt bei 1 stehen).
local function currentPower(): number
	if chargeStartClock == nil then
		return 0
	end
	return math.clamp((os.clock() - chargeStartClock) / Config.Firing.ChargeTime, 0, 1)
end

-- Zielrichtung: vom Mündungspunkt zu dem Weltpunkt, auf den die Maus zeigt.
-- (Kamera-Ray durch die Mausposition, gegen die Welt geraycastet.)
local function computeAimDirection(origin: Vector3): Vector3?
	local camera = workspace.CurrentCamera
	if camera == nil then
		return nil
	end
	local pointer = lastTouchPosition or UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pointer.X, pointer.Y)

	local character = localPlayer.Character
	aimRaycastParams.FilterDescendantsInstances = if character then { character } else {}

	local result = workspace:Raycast(ray.Origin, ray.Direction * Config.Aiming.MaxAimDistance, aimRaycastParams)
	local targetPoint = if result
		then result.Position
		else ray.Origin + ray.Direction * Config.Aiming.MaxAimDistance

	-- Dieselbe Klemmung wie auf dem Server → Vorschau zeigt exakt den akzeptierten Schuss.
	return Ballistics.clampDirection(targetPoint - origin)
end

local function onRenderStep()
	local origin = Ballistics.muzzleOrigin(localPlayer.Character)
	if origin == nil then
		TrajectoryPreview.hide()
		PowerBar.hide()
		return
	end

	local direction = computeAimDirection(origin)
	if direction == nil then
		TrajectoryPreview.hide()
		return
	end

	local power = currentPower()
	local velocity = Ballistics.initialVelocity(direction, power)
	TrajectoryPreview.update(origin, velocity)

	if chargeStartClock ~= nil then
		PowerBar.setPower(power)
	end
end

local function beginCharge()
	if chargeStartClock ~= nil then
		return
	end
	-- Cooldown-Spiegel: während des Server-Cooldowns gar nicht erst laden lassen.
	if os.clock() - lastFireClock < Config.Firing.CooldownSeconds then
		return
	end
	chargeStartClock = os.clock()
	PowerBar.setPower(0)
	PowerBar.show()
end

local function releaseAndFire()
	if chargeStartClock == nil then
		return
	end
	local power = currentPower()
	chargeStartClock = nil
	PowerBar.hide()

	local origin = Ballistics.muzzleOrigin(localPlayer.Character)
	if origin == nil then
		return
	end
	local direction = computeAimDirection(origin)
	if direction == nil then
		return
	end

	lastFireClock = os.clock()
	local remote = fireRequest
	if remote ~= nil then
		remote:FireServer(direction, power)
	end
	-- Sofortiges lokales Feedback (kein Warten auf Server-Replikation):
	ImpactEffects.muzzleKick(origin)
end

function AimController.init(remotes: { FireRequest: RemoteEvent })
	fireRequest = remotes.FireRequest
end

function AimController.enable()
	if enabled then
		return
	end
	enabled = true

	inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if isFireInput(input) then
			if input.UserInputType == Enum.UserInputType.Touch then
				lastTouchPosition = Vector2.new(input.Position.X, input.Position.Y)
			end
			beginCharge()
		end
	end)

	inputChangedConnection = UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			lastTouchPosition = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	inputEndedConnection = UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		-- Loslassen feuert auch dann, wenn die Maus inzwischen über UI steht.
		if isFireInput(input) then
			if input.UserInputType == Enum.UserInputType.Touch then
				lastTouchPosition = Vector2.new(input.Position.X, input.Position.Y)
			end
			releaseAndFire()
		end
	end)

	renderConnection = RunService.RenderStepped:Connect(onRenderStep)
end

function AimController.disable()
	if not enabled then
		return
	end
	enabled = false
	chargeStartClock = nil

	if inputBeganConnection ~= nil then
		inputBeganConnection:Disconnect()
		inputBeganConnection = nil
	end
	if inputEndedConnection ~= nil then
		inputEndedConnection:Disconnect()
		inputEndedConnection = nil
	end
	if inputChangedConnection ~= nil then
		inputChangedConnection:Disconnect()
		inputChangedConnection = nil
	end
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	TrajectoryPreview.hide()
	PowerBar.hide()
end

return AimController
