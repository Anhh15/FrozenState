-- GameStateController.lua (ModuleScript)
-- Điều khiển GUI GameState HUD: cập nhật tên phase, thời gian đếm ngược và Frozen State indicator
-- Đồng bộ trạng thái vào trận / về sảnh với MenuController, NavigationController và InGameGui

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = nil

-- GameState HUD (luôn hiện)
local GameStateGui    = nil
local Frame           = nil
local TimeText        = nil
local StateText       = nil
local TimeShadowText  = nil
local StateShadowText = nil

-- InGameGui (chỉ bật khi Ready, InGame, GameOver)
local InGameGui        = nil
local PlayerStatus     = nil
local ScoreBoard       = nil
local ButtonsFrame     = nil
local ScoreBoardButton = nil

-- ObserverGui (ẩn khi Intermission/Setup, hiện khi InGame phases — giống InGameGui)
local ObserverGui      = nil

-- Lazy-require MenuController để điều phối đóng/mở menu khi chuyển phase
local _menuController = nil
local function GetMenuController()
	if not _menuController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("MenuController")
		if Module then
			_menuController = require(Module)
		end
	end
	return _menuController
end

-- Lazy-require NavigationController để quản lý thanh nút điều hướng khi chuyển phase
local _navigationController = nil
local function GetNavigationController()
	if not _navigationController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("NavigationController")
		if Module then
			_navigationController = require(Module)
		end
	end
	return _navigationController
end

-- Lazy-require HotbarController để quản lý hiển thị Hotbar khi chuyển phase
local _hotbarController = nil
local function GetHotbarController()
	if not _hotbarController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("HotbarController")
		if Module then
			_hotbarController = require(Module)
		end
	end
	return _hotbarController
end

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

-- Phase mà lobby GUI phải bị ẩn (chỉ áp dụng khi player đang trong trận, tức là có Team hoặc InMatch)
local GAMEPLAY_PHASES = {
	Ready    = true,
	InGame   = true,
	GameOver = true,  -- Ẩn GUI trong 6s đếm ngược sau trận, trước khi về Lobby
}

-- Cache phase hiện tại để re-evaluate GUI khi trạng thái player thay đổi
local _lastPhase          = "Intermission"
local _lastTimeRemaining  = 0
local _lastIsFrozenState  = false
local _playerStatusType   = "TwoTeams"
local _scoreboardType     = "TwoTeams"

-- =========================================================
-- HELPERS
-- =========================================================

local function FormatTime(Seconds)
	local M = math.floor(Seconds / 60)
	local S = Seconds % 60
	return string.format("%02d:%02d", M, S)
end

--- Ẩn/hiện các lobby GUI theo phase và trạng thái team của LocalPlayer
--- Spectator (chưa có team / không trong trận) luôn thấy GUI dù ở phase nào
local function UpdateLobbyGuisVisibility(IsLobbyVisible)
	local MenuCtrl = GetMenuController()
	if MenuCtrl and MenuCtrl.SetVisible then
		MenuCtrl.SetVisible(IsLobbyVisible)
	end

	local NavCtrl = GetNavigationController()
	if NavCtrl and NavCtrl.SetVisible then
		NavCtrl.SetVisible(IsLobbyVisible)
	end
end

local function UpdateDisplay(Phase, TimeRemaining, IsFrozenState)
	-- Cập nhật cache để re-evaluate khi Attribute thay đổi
	_lastPhase         = Phase
	_lastTimeRemaining = TimeRemaining
	_lastIsFrozenState = IsFrozenState

	local DisplayPhase = PHASE_DISPLAY[Phase] or Phase

	-- Thêm indicator khi FrozenState đang active
	if IsFrozenState and Phase == "InGame" then
		DisplayPhase = "FROZEN STATE"
	end

	local TimeStr = FormatTime(TimeRemaining)

	if StateText then StateText.Text = DisplayPhase end
	if StateShadowText then StateShadowText.Text = DisplayPhase end
	if TimeText then TimeText.Text = TimeStr end
	if TimeShadowText then TimeShadowText.Text = TimeStr end

	-- Kiểm tra xem LocalPlayer có đang trong trận không (hỗ trợ cả mode có team và FFA)
	local IsInMatch = PlayerStateHelper.IsInMatch(LocalPlayer)
	if IsInMatch then
		-- Player trong trận: ẩn khi vào gameplay phases (Ready, InGame, GameOver)
		UpdateLobbyGuisVisibility(not GAMEPLAY_PHASES[Phase])
	else
		-- Spectator (chưa trong trận): luôn hiện GUI để đổi skin / xem shop
		UpdateLobbyGuisVisibility(true)
	end

	-- Quản lý hiển thị InGameGui, ObserverGui và các gameplay HUD con
	local IsInGamePhase = (Phase == "Ready" or Phase == "InGame" or Phase == "GameOver")
	if InGameGui then
		InGameGui.Enabled = IsInGamePhase
	end
	-- ObserverGui theo cùng lifecycle với InGameGui: ẩn khi không có trận
	if ObserverGui then
		ObserverGui.Enabled = IsInGamePhase
	end

	local ShowGameplayHud = IsInGamePhase
	if PlayerStatus then
		PlayerStatus.Visible = ShowGameplayHud and (_playerStatusType ~= "Disabled")
	end
	if ScoreBoard then
		if not ShowGameplayHud or not IsInMatch or _scoreboardType == "Disabled" then
			ScoreBoard.Visible = false
		end
	end
	if ButtonsFrame then
		ButtonsFrame.Visible = ShowGameplayHud and IsInMatch
	end
	if ScoreBoardButton then
		ScoreBoardButton.Visible = ShowGameplayHud and IsInMatch and (_scoreboardType ~= "Disabled")
	end

	-- Đồng bộ hiển thị Custom Hotbar
	local HotbarCtrl = GetHotbarController()
	if HotbarCtrl and HotbarCtrl.SetVisible then
		HotbarCtrl.SetVisible(ShowGameplayHud and IsInMatch)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameStateController = {}

function GameStateController:Init()
	local Timeout = (GuiConfig.Timeouts and GuiConfig.Timeouts.DefaultWaitForGui) or 10

	GameStateGui = GuiHelper.GetScreenGui("GameState")
	if GameStateGui then
		GameStateGui.ResetOnSpawn = false
		Frame = GameStateGui:WaitForChild("Frame", Timeout)
		if Frame then
			TimeText        = Frame:WaitForChild("TimeText", Timeout)
			StateText       = Frame:WaitForChild("StateText", Timeout)
			TimeShadowText  = Frame:WaitForChild("TimeShadowText", Timeout)
			StateShadowText = Frame:WaitForChild("StateShadowText", Timeout)
		end
	end

	InGameGui = GuiHelper.GetScreenGui("InGameGui")
	if InGameGui then
		PlayerStatus = InGameGui:WaitForChild("PlayerStatus", Timeout)
		ScoreBoard   = InGameGui:WaitForChild("ScoreBoard", Timeout)
		local InGameBtnCfg = GuiConfig.InGameButtons
		ButtonsFrame     = InGameGui:FindFirstChild(InGameBtnCfg.Buttons)
		ScoreBoardButton = ButtonsFrame and ButtonsFrame:FindFirstChild(InGameBtnCfg.ScoreBoardButton)
	end

	ObserverGui = GuiHelper.GetScreenGui(GuiConfig.ScreenGuis.ObserverGui)

	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	local SetGameModeEvent     = RemoteDefinitions.GetEvent("SetGameMode")

	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if Data then
			_playerStatusType = Data.PlayerStatusType or "TwoTeams"
			_scoreboardType   = Data.ScoreboardType   or "TwoTeams"
			UpdateDisplay(_lastPhase, _lastTimeRemaining, _lastIsFrozenState)
		end
	end)

	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		local Phase = Data.Phase or "Intermission"
		if Phase == "Intermission" then
			_playerStatusType = "TwoTeams"
			_scoreboardType   = "TwoTeams"
		end
		UpdateDisplay(
			Phase,
			Data.TimeRemaining or 0,
			Data.IsFrozenState or false
		)
	end)

	-- Re-evaluate GUI ngay khi trạng thái tham gia trận thay đổi (InMatch hoặc Team)
	PlayerStateHelper.ObserveMatchState(LocalPlayer, function()
		UpdateDisplay(_lastPhase, _lastTimeRemaining, _lastIsFrozenState)
	end)

	-- Đặt trạng thái ban đầu (lobby)
	UpdateDisplay("Intermission", 0, false)

	print("[GameStateController] Đã khởi tạo.")
end

return GameStateController
