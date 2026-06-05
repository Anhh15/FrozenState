-- GameStateController.lua (ModuleScript)
-- Điều khiển GUI GameState: cập nhật tên phase và thời gian đếm ngược
-- Đồng thời quản lý visibility của các lobby GUI (Menu, NavigationButton)
-- theo phase: ẩn khi Ready/InGame, hiện lại khi Intermission/GameOver
-- GUI cần có: Frame/TimeText, Frame/StateText, Frame/TimeShadowText, Frame/StateShadowText

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- GameState HUD (luôn hiện)
local GameStateGui    = PlayerGui:WaitForChild("GameState")
local Frame           = GameStateGui:WaitForChild("Frame")
local TimeText        = Frame:WaitForChild("TimeText")
local StateText       = Frame:WaitForChild("StateText")
local TimeShadowText  = Frame:WaitForChild("TimeShadowText")
local StateShadowText = Frame:WaitForChild("StateShadowText")

-- Lobby GUIs (ẩn khi Ready/InGame)
local MenuGui = PlayerGui:WaitForChild("Menu", 10)
local NavGui  = PlayerGui:WaitForChild("NavigationButton", 10)

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

-- Phase mà lobby GUI phải bị ẩn
local GAMEPLAY_PHASES = {
	Ready  = true,
	InGame = true,
}

-- =========================================================
-- HELPERS
-- =========================================================

local function FormatTime(Seconds)
	local M = math.floor(Seconds / 60)
	local S = Seconds % 60
	return string.format("%02d:%02d", M, S)
end

--- Ẩn/hiện các lobby GUI theo phase hiện tại
local function SetLobbyGuisVisible(Visible)
	if MenuGui then MenuGui.Enabled = Visible end
	if NavGui  then NavGui.Enabled  = Visible end
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

	-- Ẩn lobby GUI khi đang gameplay, hiện lại khi ở lobby/intermission
	SetLobbyGuisVisible(not GAMEPLAY_PHASES[Phase])
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameStateController = {}

function GameStateController:Init()
	-- Ngăn GUI reset khi player chết (respawn)
	GameStateGui.ResetOnSpawn = false

	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")

	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		UpdateDisplay(
			Data.Phase         or "Intermission",
			Data.TimeRemaining or 0,
			Data.IsFrozenState or false
		)
	end)

	-- Đặt trạng thái ban đầu (lobby)
	UpdateDisplay("Intermission", 0, false)

	print("[GameStateController] Đã khởi tạo.")
end

return GameStateController
