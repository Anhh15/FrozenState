-- ModeAnnouncementController.lua (ModuleScript)
-- Quản lý màn hình thông báo chế độ chơi đặc biệt (Special Round) ở phase Setup
-- Đặt tại StarterGui/Special/ModeAnnouncement
--
-- Cấu trúc GUI:
--   ModeAnnouncement (Frame)
--     Background      (Frame / ImageLabel)
--     ModeNameText    (TextLabel)
--     DescriptionText (TextLabel)
--
-- Luồng:
--   - Normal Round: Bỏ qua hoàn toàn
--   - Special Round (Chaos, EternalFreeze...):
--       + Xuất hiện ở phase Setup
--       + ModeNameText fade in (1 -> 0) trong 0.5s kèm SFX
--       + DescriptionText fade in (1 -> 0) trong 0.5s ngay sau khi ModeNameText hoàn tất
--       + Giữ trong DisplayDuration (4.0s) để người chơi đọc, sau đó callback kích hoạt RoundLoadingScreen
--       + Vào phase Ready hoặc các phase khác: ForceHide() dọn dẹp tức thì

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameModeHelper    = require(ReplicatedStorage.Shared.Tools.GameModeHelper)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- CONFIG
-- =========================================================

local DISPLAY_DURATION = (GameConfig.GUI.ModeAnnouncement and GameConfig.GUI.ModeAnnouncement.DisplayDuration) or 4.0
local FADE_IN_DURATION = (GameConfig.GUI.ModeAnnouncement and GameConfig.GUI.ModeAnnouncement.FadeInDuration) or 0.5

local TWEEN_INFO_TEXT = TweenInfo.new(FADE_IN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _ModeAnnouncement = nil  -- Frame: Special/ModeAnnouncement
local _Background       = nil  -- Frame/ImageLabel: con của ModeAnnouncement
local _ModeNameText     = nil  -- TextLabel
local _DescriptionText  = nil  -- TextLabel

-- =========================================================
-- STATE
-- =========================================================

local _activeTweens   = {}
local _completeTask   = nil
local _currentModeKey = "Normal"

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Hủy toàn bộ tween và timer đang chờ
local function CancelPending()
	for _, Tween in ipairs(_activeTweens) do
		Tween:Cancel()
	end
	_activeTweens = {}

	if _completeTask then
		task.cancel(_completeTask)
		_completeTask = nil
	end
end

--- Đặt lại độ trong suốt của các TextLabel về 1 (ẩn)
local function ResetTextTransparency()
	if _ModeNameText then
		_ModeNameText.TextTransparency = 1
		_ModeNameText.TextStrokeTransparency = 1
	end
	if _DescriptionText then
		_DescriptionText.TextTransparency = 1
		_DescriptionText.TextStrokeTransparency = 1
	end
end

--- Ẩn ModeAnnouncement ngay lập tức và dọn dẹp
local function ForceHide()
	CancelPending()
	ResetTextTransparency()
	if _ModeAnnouncement then
		_ModeAnnouncement.Visible = false
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local ModeAnnouncementController = {}

--- Hiển thị thông báo chế độ chơi
--- @param ModeKey string? Tên chế độ chơi
--- @param OnComplete ( () -> () )? Callback gọi khi hoàn thành thông báo
function ModeAnnouncementController.ShowAnnouncement(ModeKey, OnComplete)
	local TargetModeKey = ModeKey or _currentModeKey

	-- Nếu không phải Special Round: bỏ qua hoàn toàn và gọi OnComplete ngay
	if not GameModeHelper.IsSpecialRound(TargetModeKey) then
		if OnComplete then
			OnComplete()
		end
		return
	end

	-- Chỉ hiển thị cho người chơi đang tham gia trận đấu (InMatch = true)
	if not PlayerStateHelper.IsInMatch(LocalPlayer) then
		if OnComplete then
			OnComplete()
		end
		return
	end

	if not _ModeAnnouncement or not _ModeNameText or not _DescriptionText then
		if OnComplete then
			OnComplete()
		end
		return
	end

	CancelPending()

	-- Cập nhật nội dung
	local DisplayName = GameModeHelper.GetDisplayName(TargetModeKey)
	local Description = GameModeHelper.GetDescription(TargetModeKey)

	_ModeNameText.Text    = string.upper(DisplayName)
	_DescriptionText.Text = Description

	-- Reset trạng thái hiển thị
	ResetTextTransparency()
	_ModeAnnouncement.Visible = true

	-- Phát âm thanh thông báo
	local SoundId = AudioConfig.Special and AudioConfig.Special.ModeAnnouncement
	if SoundId then
		AudioHelper.PlayGuiSound(SoundId)
	end

	-- 1. Tween Fade In cho ModeNameText (0.5s)
	local ModeNameTween = TweenService:Create(_ModeNameText, TWEEN_INFO_TEXT, {
		TextTransparency       = 0,
		TextStrokeTransparency = 0,
	})
	table.insert(_activeTweens, ModeNameTween)
	ModeNameTween:Play()

	ModeNameTween.Completed:Connect(function(PlaybackState)
		if PlaybackState ~= Enum.PlaybackState.Completed then return end
		if not _ModeAnnouncement.Visible then return end

		-- 2. Tween Fade In cho DescriptionText (0.5s) ngay khi ModeNameText hoàn tất
		local DescTween = TweenService:Create(_DescriptionText, TWEEN_INFO_TEXT, {
			TextTransparency       = 0,
			TextStrokeTransparency = 0,
		})
		table.insert(_activeTweens, DescTween)
		DescTween:Play()
	end)

	-- 3. Hẹn giờ DisplayDuration (4.0s) rồi kích hoạt callback hoàn tất
	_completeTask = task.delay(DISPLAY_DURATION, function()
		_completeTask = nil
		if OnComplete then
			OnComplete()
		end
	end)
end

--- Ẩn khẩn cấp / Reset
function ModeAnnouncementController.ForceHide()
	ForceHide()
end

--- Lấy Mode hiện tại
--- @return string
function ModeAnnouncementController.GetCurrentModeKey()
	return _currentModeKey
end

function ModeAnnouncementController:Init()
	local SpecialGuiName = GuiConfig.ScreenGuis.Special or "Special"
	local SpecialGui     = PlayerGui:WaitForChild(SpecialGuiName)
	SpecialGui.ResetOnSpawn = false

	local FrameName = (GuiConfig.SpecialFrames and GuiConfig.SpecialFrames.ModeAnnouncement) or "ModeAnnouncement"
	_ModeAnnouncement = SpecialGui:WaitForChild(FrameName)

	local ElementNames = GuiConfig.ModeAnnouncementElements or {
		Background      = "Background",
		ModeNameText    = "ModeNameText",
		DescriptionText = "DescriptionText",
	}

	_Background      = _ModeAnnouncement:FindFirstChild(ElementNames.Background) or _ModeAnnouncement:WaitForChild("Background", 5)
	_ModeNameText    = _ModeAnnouncement:FindFirstChild(ElementNames.ModeNameText) or _ModeAnnouncement:WaitForChild("ModeNameText", 5)
	_DescriptionText = _ModeAnnouncement:FindFirstChild(ElementNames.DescriptionText) or _ModeAnnouncement:WaitForChild("DescriptionText", 5)

	-- Trạng thái ban đầu: ẩn
	ForceHide()

	-- Lắng nghe GameMode cập nhật từ Server
	local SetGameModeEvent = RemoteDefinitions.GetEvent("SetGameMode")
	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.ModeKey then
			_currentModeKey = Data.ModeKey
		end
	end)

	-- Lắng nghe UpdateGameState để dọn dẹp khi chuyển phase
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		local Phase = Data.Phase or "Intermission"

		-- Khi chuyển sang Ready, InGame, GameOver, Intermission -> ForceHide
		if Phase ~= "Setup" then
			ForceHide()
		end
	end)

	print("[ModeAnnouncementController] Da khoi tao.")
end

return ModeAnnouncementController
