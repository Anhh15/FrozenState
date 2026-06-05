-- GameStateController.lua (ModuleScript)
-- Điều khiển GUI GameState: cập nhật tên phase và thời gian đếm ngược
-- GUI cần có: Frame/TimeText, Frame/StateText, Frame/TimeShadowText, Frame/StateShadowText

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local GameStateGui = PlayerGui:WaitForChild("GameState")
local Frame        = GameStateGui:WaitForChild("Frame")
local TimeText        = Frame:WaitForChild("TimeText")
local StateText       = Frame:WaitForChild("StateText")
local TimeShadowText  = Frame:WaitForChild("TimeShadowText")
local StateShadowText = Frame:WaitForChild("StateShadowText")

-- =========================================================
-- CONFIG
-- =========================================================

-- Tên hiển thị cho từng phase (Setup ẩn sau "Intermission")
local PHASE_DISPLAY = {
	Intermission = "INTERMISSION",
	Setup        = "INTERMISSION",
	Ready        = "READY",
	InGame       = "IN GAME",
	GameOver     = "GAME OVER",
}

-- =========================================================
-- HELPERS
-- =========================================================

local function FormatTime(Seconds)
	local M = math.floor(Seconds / 60)
	local S = Seconds % 60
	return string.format("%02d:%02d", M, S)
end

local function UpdateDisplay(Phase, TimeRemaining, IsFrozenState)
	local DisplayPhase = PHASE_DISPLAY[Phase] or Phase

	-- Thêm indicator khi FrozenState đang active
	if IsFrozenState and Phase == "InGame" then
		DisplayPhase = "❄  FROZEN STATE"
	end

	local TimeStr = FormatTime(TimeRemaining)

	StateText.Text       = DisplayPhase
	StateShadowText.Text = DisplayPhase
	TimeText.Text        = TimeStr
	TimeShadowText.Text  = TimeStr
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameStateController = {}

function GameStateController:Init()
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")

	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		UpdateDisplay(
			Data.Phase         or "Intermission",
			Data.TimeRemaining or 0,
			Data.IsFrozenState or false
		)
	end)

	-- Đặt trạng thái ban đầu
	UpdateDisplay("Intermission", 0, false)

	print("[GameStateController] Đã khởi tạo.")
end

return GameStateController
