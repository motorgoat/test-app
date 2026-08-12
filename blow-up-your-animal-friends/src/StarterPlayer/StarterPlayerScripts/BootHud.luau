--!strict
-- BootHud: Status-/Diagnose-Panel für den Client-Bootstrap plus Steuerungs-Hinweis.
-- Im Live-Spiel gibt es keine sichtbare Konsole — dieses Overlay macht sichtbar,
-- WO der Bootstrap steht bzw. woran er scheitert (gelb = läuft, rot = Fehler,
-- weiß = bereit mit Steuerungs-Hinweis).
--
-- Drei Zeilen:
--   1. Client-Status (letzter gemeldeter Schritt des Client-Bootstraps)
--   2. Live-Diagnose (vom Client jede Sekunde neu geschrieben: verstrichene
--      Zeit, game:IsLoaded(), tatsächlicher Inhalt von ReplicatedStorage) —
--      diese Zeile kann konstruktionsbedingt nie veralten
--   3. letzter vom SERVER gemeldeter Boot-Schritt (repliziertes Attribut
--      "ServerBootStep"); crasht der Server, friert sie auf seinem letzten
--      Lebenszeichen ein
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

-- Place-Version in jeder Meldung: macht auf Screenshots sofort sichtbar, ob der
-- Spieler wirklich die zuletzt veröffentlichte Version spielt.
local versionTag = "v" .. tostring(game.PlaceVersion)

local clientText = ""
local clientColor = COLOR_STATUS
local diagnosticsText = ""
local serverStep = "(noch keine Meldung)"

local function render()
	if label == nil then
		return
	end
	label.TextColor3 = clientColor
	label.Text = "[" .. versionTag .. "] " .. clientText
		.. "\n" .. diagnosticsText
		.. "\nServer-Schritt: " .. serverStep
end

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
	text.Size = UDim2.new(1, -48, 0, 88)
	text.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	text.BackgroundTransparency = 0.35
	text.TextColor3 = COLOR_STATUS
	text.TextSize = 16
	text.TextWrapped = true
	text.Text = ""

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text

	text.Parent = gui
	gui.Parent = playerGui
	label = text
	render()
end

function BootHud.setStatus(message: string)
	print("[BUYAF] " .. message)
	clientColor = COLOR_STATUS
	clientText = message
	render()
end

function BootHud.setError(message: string)
	warn("[BUYAF] FEHLER: " .. message)
	clientColor = COLOR_ERROR
	clientText = "FEHLER: " .. message
	render()
end

function BootHud.setReady()
	print("[BUYAF] Client bereit.")
	clientColor = COLOR_READY
	clientText = READY_TEXT
	render()
end

function BootHud.setDiagnostics(message: string)
	diagnosticsText = message
	render()
end

function BootHud.setServerStep(step: string)
	serverStep = step
	render()
end

return BootHud
