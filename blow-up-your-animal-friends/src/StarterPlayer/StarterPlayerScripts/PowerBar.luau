--!strict
-- PowerBar: minimaler Ladebalken (ScreenGui + Frame). Sichtbar nur während des
-- Ladens; Füllstand und Farbe (grün → rot) folgen der Stärke 0..1.
-- Kein Menü, keine Extras.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PowerBar = {}

local gui: ScreenGui? = nil
local fill: Frame? = nil

function PowerBar.init()
	local cfg = Config.PowerBar
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PowerBar"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.AnchorPoint = Vector2.new(0.5, 1)
	background.Position = UDim2.new(0.5, 0, 1, -cfg.BottomMarginPx)
	background.Size = UDim2.fromOffset(cfg.WidthPx, cfg.HeightPx)
	background.BackgroundColor3 = cfg.BackgroundColor
	background.BackgroundTransparency = cfg.BackgroundTransparency
	background.BorderSizePixel = 0

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, cfg.CornerRadiusPx)
	backgroundCorner.Parent = background

	local fillFrame = Instance.new("Frame")
	fillFrame.Name = "Fill"
	fillFrame.AnchorPoint = Vector2.new(0, 0.5)
	fillFrame.Position = UDim2.fromScale(0, 0.5)
	fillFrame.Size = UDim2.fromScale(0, 1)
	fillFrame.BackgroundColor3 = cfg.LowColor
	fillFrame.BorderSizePixel = 0

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, cfg.CornerRadiusPx)
	fillCorner.Parent = fillFrame

	fillFrame.Parent = background
	background.Parent = screenGui
	screenGui.Parent = playerGui

	gui = screenGui
	fill = fillFrame
end

function PowerBar.setPower(power: number)
	local cfg = Config.PowerBar
	local fillFrame = fill
	if fillFrame == nil then
		return
	end
	local clamped = math.clamp(power, 0, 1)
	fillFrame.Size = UDim2.fromScale(clamped, 1)
	fillFrame.BackgroundColor3 = cfg.LowColor:Lerp(cfg.HighColor, clamped)
end

function PowerBar.show()
	if gui ~= nil then
		gui.Enabled = true
	end
end

function PowerBar.hide()
	if gui ~= nil then
		gui.Enabled = false
	end
end

return PowerBar
