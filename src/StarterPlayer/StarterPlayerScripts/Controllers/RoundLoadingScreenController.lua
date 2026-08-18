-- RoundLoadingScreenController.lua (ModuleScript)
-- Quản lý màn hình chuyển cảnh RoundLoadingScreen khi bắt đầu trận đấu
-- Đặt tại StarterGui/Special/RoundLoadingScreen
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
-- GUI REFERENCES (Truy xuất động để không bị mất reference khi Character spawn/respawn)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

--- Lấy tham chiếu GUI động và đảm bảo ScreenGui hợp lệ trong PlayerGui
--- @return Frame?, GuiObject?
local function ResolveScreenElements()
	local SpecialGuiName = GuiConfig.ScreenGuis.Special or "Special"
	local SpecialGui     = PlayerGui:FindFirstChild(SpecialGuiName) or PlayerGui:WaitForChild(SpecialGuiName, 5)
	if not SpecialGui then return nil, nil end

	SpecialGui.ResetOnSpawn = false
	SpecialGui.Enabled = true

	local FrameName = (GuiConfig.SpecialFrames and GuiConfig.SpecialFrames.RoundLoadingScreen) or "RoundLoadingScreen"
	local ScreenFrame = SpecialGui:FindFirstChild(FrameName)
	if not ScreenFrame then return nil, nil end

	local Background = ScreenFrame:FindFirstChild("Background") or ScreenFrame
	return ScreenFrame, Background
end

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

local _activeTween          = nil   -- Tween đang chạy (để cancel khi cần)
local _fadeOutTask          = nil   -- task.delay handle cho fade-out sau hold
local _lastPhase            = ""    -- Phase nhận được lần cuối
local _currentModeKey       = "Normal"
local _setupTriggered       = false -- Cờ đánh dấu đã kích hoạt setup của vòng hiện tại

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
	local ScreenFrame, Background = ResolveScreenElements()
	if Background then
		Background.BackgroundTransparency = 1
	end
	if ScreenFrame then
		ScreenFrame.BackgroundTransparency = 1
		ScreenFrame.Visible = false
	end
end

--- Bắt đầu fade-in: hiện màn hình rồi tween transparency Background từ 1 -> 0
local function StartFadeIn()
	local ScreenFrame, Background = ResolveScreenElements()
	if not ScreenFrame or not Background then return end

	CancelPending()

	ScreenFrame.BackgroundTransparency = 1
	ScreenFrame.Visible = true
	Background.BackgroundTransparency = 1

	local Tween = TweenService:Create(Background, TWEEN_FADE_IN, {
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

--- Kích hoạt luồng Setup (ModeAnnouncement nếu là Special Round, ngược lại StartFadeIn)
local function TriggerSetupSequence()
	if _setupTriggered then return end
	_setupTriggered = true

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
end

--- Bắt đầu fade-out sau HoldDuration giây (dành cho Ready state)
local function StartFadeOutSequence()
	local ScreenFrame, Background = ResolveScreenElements()
	if not ScreenFrame or not Background then return end
	if not ScreenFrame.Visible then return end

	CancelPending()

	-- Hold HoldDuration giây rồi fade-out
	_fadeOutTask = task.delay(HOLD_DURATION, function()
		_fadeOutTask = nil

		local CurrentScreen, CurrentBg = ResolveScreenElements()
		if not CurrentScreen or not CurrentBg then return end
		if not CurrentScreen.Visible then return end

		local Tween = TweenService:Create(CurrentBg, TWEEN_FADE_OUT, {
			BackgroundTransparency = 1,
		})
		_activeTween = Tween
		Tween:Play()
		Tween.Completed:Connect(function()
			if _activeTween == Tween then
				_activeTween = nil
				CurrentScreen.Visible = false
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
		TriggerSetupSequence()

	elseif Phase == "Ready" then
		_setupTriggered = false
		StartFadeOutSequence()

	else
		-- InGame, GameOver, Intermission -> ẩn ngay (safety net)
		_setupTriggered = false
		ForceHide()
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local RoundLoadingScreenController = {}

function RoundLoadingScreenController:Init()
	-- Đảm bảo GUI ở trạng thái ban đầu ẩn
	ForceHide()

	-- Lắng nghe nhân vật spawn lần đầu hoặc respawn để chuẩn hóa lại ScreenGui
	LocalPlayer.CharacterAdded:Connect(function()
		ForceHide()
	end)

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

	-- Lắng nghe thay đổi trạng thái tham gia trận để kích hoạt Setup nếu replicate sau remote event
	PlayerStateHelper.ObserveMatchState(LocalPlayer, function(IsInMatch)
		if IsInMatch and _lastPhase == "Setup" and not _setupTriggered then
			TriggerSetupSequence()
		end
	end)

	print("[RoundLoadingScreenController] Da khoi tao.")
end

return RoundLoadingScreenController
