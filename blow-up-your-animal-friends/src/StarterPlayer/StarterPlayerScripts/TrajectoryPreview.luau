--!strict
-- TrajectoryPreview: gepunktete Flugbahn-Vorschau aus Ballistics-Punkten.
-- DAS zentrale Lesbarkeits-Element — wird jeden Frame vom AimController mit
-- (Ursprung, Startgeschwindigkeit) aktualisiert und rechnet mit exakt derselben
-- Mathematik wie die Server-Simulation.
--
-- Die Vorschau wird am ersten Welt-Treffer abgeschnitten und dort mit einem
-- größeren roten End-Marker versehen: "hier schlägst du ein".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Ballistics = require(Shared:WaitForChild("Ballistics"))

local TrajectoryPreview = {}

local localPlayer = Players.LocalPlayer

local folder: Folder? = nil
local dots: { BasePart } = {}
local endMarker: BasePart? = nil

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = false

local function createDot(diameter: number, color: Color3): BasePart
	local dot = Instance.new("Part")
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.one * diameter
	dot.Material = Enum.Material.Neon
	dot.Color = color
	dot.Anchored = true
	dot.CanCollide = false
	dot.CanQuery = false -- darf weder Ziel-Raycast noch die eigene Abschneide-Logik treffen
	dot.CanTouch = false
	dot.CastShadow = false
	dot.Parent = folder
	return dot
end

function TrajectoryPreview.init()
	local cfg = Config.Preview
	folder = Instance.new("Folder")
	folder.Name = "TrajectoryPreview" -- rein lokal (Client-seitig erstellt, repliziert nicht)
	folder.Parent = workspace

	for i = 1, cfg.PointCount do
		local dot = createDot(cfg.DotDiameter, cfg.DotColor)
		-- Transparenz-Rampe entlang der Bahn: nah = kräftig, fern = ausgeblendet.
		local alpha = (i - 1) / math.max(cfg.PointCount - 1, 1)
		dot.Transparency = 1 -- unsichtbar bis zum ersten update()
		dot:SetAttribute("BaseTransparency",
			cfg.DotTransparencyNear + alpha * (cfg.DotTransparencyFar - cfg.DotTransparencyNear))
		dots[i] = dot
	end

	local marker = createDot(cfg.EndMarkerDiameter, cfg.EndMarkerColor)
	marker.Transparency = 1
	endMarker = marker
end

function TrajectoryPreview.update(origin: Vector3, initialVelocity: Vector3)
	local cfg = Config.Preview
	local points = Ballistics.trajectoryPoints(origin, initialVelocity, cfg.PointCount, cfg.TimeStep)

	local character = localPlayer.Character
	raycastParams.FilterDescendantsInstances = if character then { character } else {}

	local hitPosition: Vector3? = nil
	local visibleCount = cfg.PointCount

	local previous = origin
	for i, point in points do
		local result = workspace:Raycast(previous, point - previous, raycastParams)
		if result ~= nil then
			hitPosition = result.Position
			visibleCount = i - 1
			break
		end
		previous = point
	end

	for i, dot in dots do
		if i <= visibleCount then
			dot.Position = points[i]
			dot.Transparency = dot:GetAttribute("BaseTransparency") :: number
		else
			dot.Transparency = 1
		end
	end

	local marker = endMarker
	if marker ~= nil then
		if hitPosition ~= nil then
			marker.Position = hitPosition
			marker.Transparency = cfg.EndMarkerTransparency
		else
			marker.Transparency = 1
		end
	end
end

function TrajectoryPreview.hide()
	for _, dot in dots do
		dot.Transparency = 1
	end
	if endMarker ~= nil then
		endMarker.Transparency = 1
	end
end

return TrajectoryPreview
