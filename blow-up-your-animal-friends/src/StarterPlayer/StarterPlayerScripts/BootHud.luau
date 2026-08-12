--!strict
-- BootHud: Status-/Diagnosezeile für den Client-Bootstrap plus Steuerungs-Hinweis.
-- Im Live-Spiel gibt es keine sichtbare Konsole — dieses Overlay macht sichtbar,
-- WO der Bootstrap steht bzw. woran er scheitert (gelb = läuft, rot = Fehler,
-- weiß = bereit mit Steuerungs-Hinweis).
--
-- BEWUSST abhängigkeitsfrei (kein Config-Require, kein WaitForChild auf Shared):
-- dieses Modul muss auch dann noch anzeigen können, wenn ReplicatedStorage
-- unvollständig repliziert oder der restliche Bootstrap kaputt ist. Die wenigen
-- Pixel-/Farbwerte hier sind eine dokumentierte Ausnahme von der
-- "alle Zahlen in Config"-Regel.

local Players = game:GetService("Players")

local BootHud = {}

local label: TextLabel? = nil

local COLOR_STATUS = Color3.fromRGB(255, 235, 130)
local COLOR_ERROR = Color3.fromRGB(255, 95, 80)
local COLOR_READY = Color3.fromRGB(240, 240, 240)

local READY_TEXT =
	"Maus bewegen: zielen  •  Linke Maustaste HALTEN: Kraft laden  •  LOSLASSEN: Feuer!"

function BootHud.init()
	if label ~= nil then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BootHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000

	local text = Instance.new("TextLabel")
	text.Name = "Status"
	text.AnchorPoint = Vector2.new(0.5, 1)
	text.Position = UDim2.new(0.5, 0, 1, -36)
	text.Size = UDim2.new(1, -48, 0, 32)
	text.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	text.BackgroundTransparency = 0.35
	text.TextColor3 = COLOR_STATUS
	text.TextSize = 18
	text.TextWrapped = true
	text.Text = ""

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text

	text.Parent = gui
	gui.Parent = playerGui
	label = text
end

function BootHud.setStatus(message: string)
	print("[BUYAF] " .. message)
	if label ~= nil then
		label.TextColor3 = COLOR_STATUS
		label.Text = message
	end
end

function BootHud.setError(message: string)
	warn("[BUYAF] FEHLER: " .. message)
	if label ~= nil then
		label.TextColor3 = COLOR_ERROR
		label.Text = "FEHLER: " .. message
	end
end

function BootHud.setReady()
	print("[BUYAF] Client bereit.")
	if label ~= nil then
		label.TextColor3 = COLOR_READY
		label.Text = READY_TEXT
	end
end

return BootHud
