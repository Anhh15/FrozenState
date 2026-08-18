-- RoundLoadingScreenController.lua (ModuleScript)
-- Quản lý màn hình chuyển cảnh RoundLoadingScreen khi bắt đầu trận đấu
-- Đặt tại StarterGui/Special/RoundLoadingScreen
-- Chỉ hiện với player tham gia trận (InMatch = true), Spectator không thấy
--
-- Cấu trúc GUI:
--   RoundLoadingScreen (Frame, BackgroundTransparency = 1)
--     Background       (Frame / ImageLabel) -- element con thực hiện fade in / out
--
-- Luồng:
--   - Setup (Normal Round):  Fade-in Background (1 -> 0 trong FadeInDuration)
--   - Setup (Special Round): Chờ ModeAnnouncementController hoàn tất (4.0s) rồi mới Fade-in Background
--   - Ready:                 Giữ HoldDuration -> Fade-out Background (0 -> 1) -> Visible = false
--   - InGame / Intermission: Safety net ẩn ngay lập tức

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions          = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig                 = require(ReplicatedStorage.Shared.Config.GameConfig)
local GuiConfig                  = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GameModeHelper             = require(ReplicatedStorage.Shared.Tools.GameModeHelper)
local PlayerStateHelper          = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- CONFIG
-- =========================================================

local FADE_IN_DURATION  = GameConfig.GUI.RoundLoadingScreen.FadeInDuration
local HOLD_DURATION     = GameConfig.GUI.RoundLoadingScreen.HoldDuration
local FADE_OUT_DURATION = GameConfig.GUI.RoundLoadingScreen.FadeOutDuration

local TWEEN_FADE_IN  = TweenInfo.new(FADE_IN_DURATION,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_FADE_OUT = TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- =========================================================
-- GUI REFERENCES (lazy-init trong Init để tránh race condition)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _RoundLoadingScreen = nil  -- Frame: Special/RoundLoadingScreen
local _Background         = nil  -- Frame/ImageLabel: con của RoundLoadingScreen

-- Lazy-require ModeAnnouncementController
local _modeAnnouncementController = nil
local function GetModeAnnouncementController()
	if not _modeAnnouncementController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("ModeAnnouncementController")
		if Module then
			_modeAnnouncementController = require(Module)
		end
	end
	return _modeAnnouncementController
end

-- =========================================================
-- STATE
-- =========================================================

local _activeTween    = nil   -- Tween đang chạy (để cancel khi cần)
local _fadeOutTask    = nil   -- task.delay handle cho fade-out sau hold
local _lastPhase      = ""    -- Phase nhận được lần cuối
local _currentModeKey = "Normal"

-- =========================================================
-- PRIVATE
-- =========================================================

--- Cancel tween và task đang chạy (dọn dẹp trước khi bắt đầu animation mới)
local function CancelPending()
	if _activeTween then
		_activeTween:Cancel()
		_activeTween = nil
	end
	if _fadeOutTask then
		task.cancel(_fadeOutTask)
		_fadeOutTask = nil
	end
end

--- Ẩn RoundLoadingScreen ngay lập tức (safety net hoặc reset)
local function ForceHide()
	CancelPending()
	if _Background then
		_Background.BackgroundTransparency = 1
	end
	if _RoundLoadingScreen then
		_RoundLoadingScreen.BackgroundTransparency = 1
		_RoundLoadingScreen.Visible = false
	end
end

--- Bắt đầu fade-in: hiện màn hình rồi tween transparency Background từ 1 -> 0
local function StartFadeIn()
	if not _RoundLoadingScreen or not _Background then return end

	-- Chỉ hiện với player tham gia trận
	local IsInMatch = PlayerStateHelper.IsInMatch(LocalPlayer)
	if not IsInMatch then return end

	CancelPending()

	_RoundLoadingScreen.BackgroundTransparency = 1
	_RoundLoadingScreen.Visible = true
	_Background.BackgroundTransparency = 1

	local Tween = TweenService:Create(_Background, TWEEN_FADE_IN, {
		BackgroundTransparency = 0,
	})
	_activeTween = Tween
	Tween:Play()
	Tween.Completed:Connect(function()
		if _activeTween == Tween then
			_activeTween = nil
		end
	end)
end

--- Bắt đầu fade-out sau HoldDuration giây (dành cho Ready state)
local function StartFadeOutSequence()
	if not _RoundLoadingScreen or not _Background then return end
	if not _RoundLoadingScreen.Visible then return end

	CancelPending()

	-- Hold HoldDuration giây rồi fade-out
	_fadeOutTask = task.delay(HOLD_DURATION, function()
		_fadeOutTask = nil

		-- Nếu đã bị force-hide (phase nhảy sang InGame) thì bỏ qua
		if not _RoundLoadingScreen.Visible then return end

		local Tween = TweenService:Create(_Background, TWEEN_FADE_OUT, {
			BackgroundTransparency = 1,
		})
		_activeTween = Tween
		Tween:Play()
		Tween.Completed:Connect(function()
			if _activeTween == Tween then
				_activeTween = nil
				_RoundLoadingScreen.Visible = false
			end
		end)
	end)
end

--- Xử lý khi nhận UpdateGameState từ server
--- @param Phase string
local function OnPhaseChanged(Phase)
	-- Tránh xử lý lặp cùng phase
	if Phase == _lastPhase then return end
	_lastPhase = Phase

	if Phase == "Setup" then
		if GameModeHelper.IsSpecialRound(_currentModeKey) then
			local ModeAnnouncementCtrl = GetModeAnnouncementController()
			if ModeAnnouncementCtrl and ModeAnnouncementCtrl.ShowAnnouncement then
				ModeAnnouncementCtrl.ShowAnnouncement(_currentModeKey, function()
					StartFadeIn()
				end)
			else
				StartFadeIn()
			end
		else
			StartFadeIn()
		end

	elseif Phase == "Ready" then
		StartFadeOutSequence()

	else
		-- InGame, GameOver, Intermission -> ẩn ngay (safety net)
		ForceHide()
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local RoundLoadingScreenController = {}

function RoundLoadingScreenController:Init()
	local SpecialGuiName    = GuiConfig.ScreenGuis.Special or "Special"
	local SpecialGui        = PlayerGui:WaitForChild(SpecialGuiName)
	SpecialGui.ResetOnSpawn = false

	local FrameName     = (GuiConfig.SpecialFrames and GuiConfig.SpecialFrames.RoundLoadingScreen) or "RoundLoadingScreen"
	_RoundLoadingScreen = SpecialGui:WaitForChild(FrameName)

	-- Tìm phần tử Background con bên trong Frame
	_Background = _RoundLoadingScreen:FindFirstChild("Background") or _RoundLoadingScreen:WaitForChild("Background", 5)

	-- Đảm bảo trạng thái ban đầu là ẩn
	_RoundLoadingScreen.BackgroundTransparency = 1
	if _Background then
		_Background.BackgroundTransparency = 1
	end
	_RoundLoadingScreen.Visible = false

	-- Lắng nghe GameMode cập nhật từ Server
	local SetGameModeEvent = RemoteDefinitions.GetEvent("SetGameMode")
	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.ModeKey then
			_currentModeKey = Data.ModeKey
		end
	end)

	-- Lắng nghe UpdateGameState (cùng remote với GameStateController)
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		OnPhaseChanged(Data.Phase or "Intermission")
	end)

	print("[RoundLoadingScreenController] Da khoi tao.")
end

return RoundLoadingScreenController
