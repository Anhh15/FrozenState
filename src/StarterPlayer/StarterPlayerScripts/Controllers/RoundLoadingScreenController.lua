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
local GuiHelper                  = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local GameModeHelper             = require(ReplicatedStorage.Shared.Tools.GameModeHelper)
local PlayerStateHelper          = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

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
local _ModeAnnouncementController = nil
local function GetModeAnnouncementController()
	if not _ModeAnnouncementController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("ModeAnnouncementController")
		if Module then
			_ModeAnnouncementController = require(Module)
		end
	end
	return _ModeAnnouncementController
end

-- =========================================================
-- STATE
-- =========================================================

local _ActiveTween          = nil   -- Tween đang chạy (để cancel khi cần)
local _FadeOutTask          = nil   -- task.delay handle cho fade-out sau hold
local _LastPhase            = ""    -- Phase nhận được lần cuối
local _CurrentModeKey       = "Normal"
local _SetupTriggered       = false -- Cờ đánh dấu đã kích hoạt setup của vòng hiện tại

-- =========================================================
-- PRIVATE
-- =========================================================

--- Cancel tween và task đang chạy (dọn dẹp trước khi bắt đầu animation mới)
local function CancelPending()
	if _ActiveTween then
		_ActiveTween:Cancel()
		_ActiveTween = nil
	end
	if _FadeOutTask then
		task.cancel(_FadeOutTask)
		_FadeOutTask = nil
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

	local AnimCfg = GuiHelper.GetRoundLoadingAnimConfig(_CurrentModeKey)
	local TweenFadeIn = TweenInfo.new(
		AnimCfg.FadeInDuration     or 1.0,
		AnimCfg.FadeInEasingStyle  or Enum.EasingStyle.Quad,
		AnimCfg.FadeInEasingDir    or Enum.EasingDirection.Out
	)

	local Tween = TweenService:Create(Background, TweenFadeIn, {
		BackgroundTransparency = 0,
	})
	_ActiveTween = Tween
	Tween:Play()
	Tween.Completed:Connect(function()
		if _ActiveTween == Tween then
			_ActiveTween = nil
		end
	end)
end

--- Kích hoạt luồng Setup (ModeAnnouncement nếu là Special Round, ngược lại StartFadeIn)
local function TriggerSetupSequence()
	if _SetupTriggered then return end
	_SetupTriggered = true

	if GameModeHelper.IsSpecialRound(_CurrentModeKey) then
		local ModeAnnouncementCtrl = GetModeAnnouncementController()
		if ModeAnnouncementCtrl and ModeAnnouncementCtrl.ShowAnnouncement then
			ModeAnnouncementCtrl.ShowAnnouncement(_CurrentModeKey, function()
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

	local AnimCfg = GuiHelper.GetRoundLoadingAnimConfig(_CurrentModeKey)
	local HoldDuration = AnimCfg.HoldDuration or 1.0

	-- Hold HoldDuration giây rồi fade-out
	_FadeOutTask = task.delay(HoldDuration, function()
		_FadeOutTask = nil

		local CurrentScreen, CurrentBg = ResolveScreenElements()
		if not CurrentScreen or not CurrentBg then return end
		if not CurrentScreen.Visible then return end

		local TweenFadeOut = TweenInfo.new(
			AnimCfg.FadeOutDuration    or 0.5,
			AnimCfg.FadeOutEasingStyle or Enum.EasingStyle.Quad,
			AnimCfg.FadeOutEasingDir   or Enum.EasingDirection.In
		)

		local Tween = TweenService:Create(CurrentBg, TweenFadeOut, {
			BackgroundTransparency = 1,
		})
		_ActiveTween = Tween
		Tween:Play()
		Tween.Completed:Connect(function()
			if _ActiveTween == Tween then
				_ActiveTween = nil
				CurrentScreen.Visible = false
			end
		end)
	end)
end

--- Xử lý khi nhận UpdateGameState từ server
--- @param Phase string
local function OnPhaseChanged(Phase)
	-- Tránh xử lý lặp cùng phase
	if Phase == _LastPhase then return end
	_LastPhase = Phase

	if Phase == "Setup" then
		TriggerSetupSequence()

	elseif Phase == "Ready" then
		_SetupTriggered = false
		StartFadeOutSequence()

	else
		-- InGame, GameOver, Intermission -> ẩn ngay (safety net)
		_SetupTriggered = false
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
			_CurrentModeKey = Data.ModeKey
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
		if IsInMatch and _LastPhase == "Setup" and not _SetupTriggered then
			TriggerSetupSequence()
		end
	end)

	print("[RoundLoadingScreenController] Đã khởi tạo.")
end

return RoundLoadingScreenController
