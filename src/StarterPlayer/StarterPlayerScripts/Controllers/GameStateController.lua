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

-- Phase mà lobby GUI phải bị ẩn (chỉ áp dụng khi player đang trong trận, tức là có Team)
local GAMEPLAY_PHASES = {
	Ready    = true,
	InGame   = true,
	GameOver = true,  -- Ẩn GUI trong 6s đếm ngược sau trận, trước khi về Lobby
}

-- Cache phase hiện tại để re-evaluate GUI khi Attribute Team thay đổi
local _lastPhase          = "Intermission"
local _lastTimeRemaining  = 0
local _lastIsFrozenState  = false

-- =========================================================
-- HELPERS
-- =========================================================

local function FormatTime(Seconds)
	local M = math.floor(Seconds / 60)
	local S = Seconds % 60
	return string.format("%02d:%02d", M, S)
end

--- Ẩn/hiện các lobby GUI theo phase và trạng thái team của LocalPlayer
--- Spectator (chưa có team) luôn thấy GUI dù ở phase nào
local function SetLobbyGuisVisible(Visible)
	if MenuGui then MenuGui.Enabled = Visible end
	if NavGui  then NavGui.Enabled  = Visible end
end

local function UpdateDisplay(Phase, TimeRemaining, IsFrozenState)
	-- Cập nhật cache để re-evaluate khi Attribute Team thay đổi
	_lastPhase         = Phase
	_lastTimeRemaining = TimeRemaining
	_lastIsFrozenState = IsFrozenState

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

	-- Kiểm tra xem LocalPlayer có đang trong trận (có team) hay không
	local MyTeam = LocalPlayer:GetAttribute("Team")
	if MyTeam then
		-- Player trong trận: ẩn/hiện theo phase
		SetLobbyGuisVisible(not GAMEPLAY_PHASES[Phase])
	else
		-- Spectator (chưa có team): luôn hiện GUI để đổi skin
		SetLobbyGuisVisible(true)
	end
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

	-- Re-evaluate GUI ngay khi Attribute Team thay đổi
	-- (ví dụ: Spectator được phân team khi trận mới bắt đầu, hoặc về Lobby sau GameOver)
	LocalPlayer:GetAttributeChangedSignal("Team"):Connect(function()
		UpdateDisplay(_lastPhase, _lastTimeRemaining, _lastIsFrozenState)
	end)

	-- Đặt trạng thái ban đầu (lobby)
	UpdateDisplay("Intermission", 0, false)

	print("[GameStateController] Đã khởi tạo.")
end

return GameStateController
