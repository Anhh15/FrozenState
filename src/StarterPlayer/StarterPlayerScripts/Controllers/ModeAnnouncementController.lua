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
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- GUI REFERENCES (Truy xuất động để không bị mất reference khi Character spawn/respawn)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

--- Lấy tham chiếu GUI động và đảm bảo ScreenGui hợp lệ trong PlayerGui
--- @return Frame?, GuiObject?, TextLabel?, TextLabel?
local function ResolveElements()
	local SpecialGuiName = GuiConfig.ScreenGuis.Special or "Special"
	local SpecialGui     = PlayerGui:FindFirstChild(SpecialGuiName) or PlayerGui:WaitForChild(SpecialGuiName, 5)
	if not SpecialGui then return nil, nil, nil, nil end

	SpecialGui.ResetOnSpawn = false
	SpecialGui.Enabled = true

	local FrameName = (GuiConfig.SpecialFrames and GuiConfig.SpecialFrames.ModeAnnouncement) or "ModeAnnouncement"
	local Frame     = SpecialGui:FindFirstChild(FrameName)
	if not Frame then return nil, nil, nil, nil end

	local ElementNames = GuiConfig.ModeAnnouncementElements or {
		Background      = "Background",
		ModeNameText    = "ModeNameText",
		DescriptionText = "DescriptionText",
	}

	local Bg   = Frame:FindFirstChild(ElementNames.Background) or Frame
	local Name = Frame:FindFirstChild(ElementNames.ModeNameText)
	local Desc = Frame:FindFirstChild(ElementNames.DescriptionText)

	return Frame, Bg, Name, Desc
end

-- =========================================================
-- STATE
-- =========================================================

local _ActiveTweens   = {}
local _CompleteTask   = nil
local _CurrentModeKey = "Normal"

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Hủy toàn bộ tween và timer đang chờ
local function CancelPending()
	for _, Tween in ipairs(_ActiveTweens) do
		Tween:Cancel()
	end
	_ActiveTweens = {}

	if _CompleteTask then
		task.cancel(_CompleteTask)
		_CompleteTask = nil
	end
end

--- Đặt lại độ trong suốt của các TextLabel về 1 (ẩn)
local function ResetTextTransparency(ModeNameText, DescriptionText)
	if ModeNameText then
		ModeNameText.TextTransparency = 1
		ModeNameText.TextStrokeTransparency = 1
	end
	if DescriptionText then
		DescriptionText.TextTransparency = 1
		DescriptionText.TextStrokeTransparency = 1
	end
end

--- Ẩn ModeAnnouncement ngay lập tức và dọn dẹp
local function ForceHide()
	CancelPending()
	local Frame, _, ModeNameText, DescriptionText = ResolveElements()
	ResetTextTransparency(ModeNameText, DescriptionText)
	if Frame then
		Frame.Visible = false
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
	local TargetModeKey = ModeKey or _CurrentModeKey

	-- Nếu không phải Special Round: bỏ qua hoàn toàn và gọi OnComplete ngay
	if not GameModeHelper.IsSpecialRound(TargetModeKey) then
		if OnComplete then
			OnComplete()
		end
		return
	end

	local Frame, _, ModeNameText, DescriptionText = ResolveElements()
	if not Frame or not ModeNameText or not DescriptionText then
		if OnComplete then
			OnComplete()
		end
		return
	end

	CancelPending()

	local AnimCfg = GuiHelper.GetModeAnnouncementAnimConfig(TargetModeKey)
	local TweenInfoText = TweenInfo.new(
		AnimCfg.FadeInDuration or 0.5,
		AnimCfg.EasingStyle    or Enum.EasingStyle.Quad,
		AnimCfg.EasingDir      or Enum.EasingDirection.Out
	)

	-- Cập nhật nội dung
	local DisplayName = GameModeHelper.GetDisplayName(TargetModeKey)
	local Description = GameModeHelper.GetDescription(TargetModeKey)

	ModeNameText.Text    = string.upper(DisplayName)
	DescriptionText.Text = Description

	-- Reset trạng thái hiển thị
	ResetTextTransparency(ModeNameText, DescriptionText)
	Frame.Visible = true

	-- Phát âm thanh thông báo
	local ModeSoundEntry = AudioConfig.Special and AudioConfig.Special.ModeAnnouncement
	if ModeSoundEntry then
		AudioHelper.PlayGuiSound(ModeSoundEntry)
	end

	-- 1. Tween Fade In cho ModeNameText
	local ModeNameTween = TweenService:Create(ModeNameText, TweenInfoText, {
		TextTransparency       = 0,
		TextStrokeTransparency = 0,
	})
	table.insert(_ActiveTweens, ModeNameTween)
	ModeNameTween:Play()

	ModeNameTween.Completed:Connect(function(PlaybackState)
		if PlaybackState ~= Enum.PlaybackState.Completed then return end
		if not Frame.Visible then return end

		-- 2. Tween Fade In cho DescriptionText ngay khi ModeNameText hoàn tất
		local DescTween = TweenService:Create(DescriptionText, TweenInfoText, {
			TextTransparency       = 0,
			TextStrokeTransparency = 0,
		})
		table.insert(_ActiveTweens, DescTween)
		DescTween:Play()
	end)

	-- 3. Hẹn giờ DisplayDuration rồi kích hoạt callback hoàn tất
	local DisplayDuration = AnimCfg.DisplayDuration or 4.0
	_CompleteTask = task.delay(DisplayDuration, function()
		_CompleteTask = nil
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
	return _CurrentModeKey
end

function ModeAnnouncementController:Init()
	-- Trạng thái ban đầu: ẩn
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

	print("[ModeAnnouncementController] Đã khởi tạo.")
end

return ModeAnnouncementController
