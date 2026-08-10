--!strict
-- FireHandler: empfängt Fire-Requests vom Client und validiert sie serverseitig.
-- Der Client sendet NUR (Richtung als Einheitsvektor, Stärke 0..1) — alles andere
-- (Ursprung, Geschwindigkeit, Terrainwirkung) berechnet der Server selbst.
--
-- Seam für die spätere Zustandsmaschine: setCanFire(fn) — default immer true.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ballistics = require(Shared:WaitForChild("Ballistics"))

local ProjectileServer = require(script.Parent.ProjectileServer)

local FireHandler = {}

-- CanFire-Hook: die spätere Zustandsmaschine hängt sich hier ein
-- (z. B. "nur in der Zielphase"). Default: immer feuern dürfen.
local canFire: (Player) -> boolean = function(_player)
	return true
end

function FireHandler.setCanFire(fn: (Player) -> boolean)
	canFire = fn
end

local lastFireClock: { [Player]: number } = {}

local function onFireRequest(player: Player, direction: unknown, power: unknown)
	-- Typprüfung (Remotes können beliebige Werte liefern).
	if typeof(direction) ~= "Vector3" then
		return
	end
	if type(power) ~= "number" or power ~= power then -- NaN-Check
		return
	end

	if not canFire(player) then
		return
	end

	-- Cooldown pro Spieler.
	local now = os.clock()
	local last = lastFireClock[player]
	if last ~= nil and now - last < Config.Firing.CooldownSeconds then
		return
	end

	-- Charakter muss existieren; Ursprung berechnet der Server selbst.
	local origin = Ballistics.muzzleOrigin(player.Character)
	if origin == nil then
		return
	end

	-- Richtung normalisieren + Elevationswinkel auf Config-Grenzen klemmen
	-- (dieselbe Funktion, die der Client für die Vorschau benutzt).
	local clampedDirection = Ballistics.clampDirection(direction)
	if clampedDirection == nil then
		return
	end

	local clampedPower = math.clamp(power, 0, 1)

	lastFireClock[player] = now
	ProjectileServer.fire(player, origin, Ballistics.initialVelocity(clampedDirection, clampedPower))
end

function FireHandler.init(remotes: { FireRequest: RemoteEvent })
	remotes.FireRequest.OnServerEvent:Connect(onFireRequest)
	Players.PlayerRemoving:Connect(function(player)
		lastFireClock[player] = nil
	end)
end

return FireHandler
