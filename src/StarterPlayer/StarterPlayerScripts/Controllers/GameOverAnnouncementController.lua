-- GameOverAnnouncementController.lua (ModuleScript)
-- Quản lý banner thông báo kết thúc trận đấu (GameOverAnnouncement) ở phase GameOver
-- Đặt tại StarterGui/Special/GameOverAnnouncement
--
-- Cấu trúc GUI:
--   GameOverAnnouncement (Frame)
--     Background       (ImageLabel / Frame)
--     AnnouncementText (TextLabel)
--
-- Luồng hoạt ảnh:
--   - Khi vào phase GameOver:
--       1. Background mở rộng ngang (Split) từ tâm sang 2 bên
--       2. AnnouncementText bay vút (Fly In) từ Y scale = 2.0 lên vị trí mặc định
--       3. Dòng chữ định dạng RichText:
--            + Team-based: Mình thắng (Xanh dương), Mình thua (Đỏ), Khán giả (Trắng)
--            + FFA: Tên DisplayName cắt ngắn tối đa 15 ký tự, màu Vàng Kim (#FFD700)
--       4. Giữ hiển thị trong DisplayDuration (3.2s), sau đó thu nhỏ/đóng êm dịu

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- GUI REFERENCES (Truy xuất động tránh mất reference khi Respawn)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _DefaultBgSize   = nil
local _DefaultTextPos  = nil
local _ActiveTweens    = {}
local _HideTask        = nil
local _IsShowing       = false

--- Truy xuất an toàn các phần tử trong ScreenGui Special
--- @return Frame?, GuiObject?, TextLabel?
local function ResolveElements()
	local SpecialGuiName = GuiConfig.ScreenGuis.Special or "Special"
	local SpecialGui     = PlayerGui:FindFirstChild(SpecialGuiName) or PlayerGui:WaitForChild(SpecialGuiName, 5)
	if not SpecialGui then return nil, nil, nil end

	SpecialGui.ResetOnSpawn = false
	SpecialGui.Enabled = true

	local FrameName = (GuiConfig.SpecialFrames and GuiConfig.SpecialFrames.GameOverAnnouncement) or "GameOverAnnouncement"
	local Frame     = SpecialGui:FindFirstChild(FrameName)
	if not Frame then return nil, nil, nil end

	local ElementNames = GuiConfig.GameOverAnnouncementElements or {
		Background       = "Background",
		AnnouncementText = "AnnouncementText",
	}

	local Bg   = Frame:FindFirstChild(ElementNames.Background) or Frame
	local Text = Frame:FindFirstChild(ElementNames.AnnouncementText)

	-- Lưu vị trí mặc định thiết kế từ Studio lần đầu tiên
	if Bg and not _DefaultBgSize then
		_DefaultBgSize = Bg.Size
	end
	if Text and not _DefaultTextPos then
		_DefaultTextPos = Text.Position
	end

	return Frame, Bg, Text
end

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Hủy toàn bộ tween và timer đang chờ
local function CancelPending()
	for _, Tween in ipairs(_ActiveTweens) do
		Tween:Cancel()
	end
	_ActiveTweens = {}

	if _HideTask then
		task.cancel(_HideTask)
		_HideTask = nil
	end
end

--- Ẩn khẩn cấp banner thông báo và dọn dẹp
local function ForceHide()
	CancelPending()
	_IsShowing = false

	local Frame, Bg, Text = ResolveElements()
	if Frame then
		Frame.Visible = false
	end
	if Bg and _DefaultBgSize then
		Bg.Size = _DefaultBgSize
	end
	if Text and _DefaultTextPos then
		Text.Position = _DefaultTextPos
	end
end

--- Định dạng chuỗi văn bản thông báo và mã màu RichText
--- @param WinnerInfo table? { WinTeam: string?, WinPlayer: { Name: string, UserId: number }? }
--- @return string
local function FormatAnnouncementText(WinnerInfo)
	if not WinnerInfo then
		return "Game over, Draw!"
	end

	local AllyHex      = GuiConfig.PlayerStatus.AllyColor:ToHex()
	local EnemyHex     = GuiConfig.PlayerStatus.EnemyColor:ToHex()
	local FFAWinnerHex = (GuiConfig.GameOver and GuiConfig.GameOver.FFAWinnerColor and GuiConfig.GameOver.FFAWinnerColor:ToHex()) or "FFD700"
	local SpectatorHex = (GuiConfig.GameOver and GuiConfig.GameOver.SpectatorColor and GuiConfig.GameOver.SpectatorColor:ToHex()) or "FFFFFF"

	if WinnerInfo.WinTeam then
		local WinTeam         = WinnerInfo.WinTeam
		local MyTeam          = PlayerStateHelper.GetTeam(LocalPlayer)
		local TeamDisplayName = (WinTeam == "Team1") and "Team 1" or ((WinTeam == "Team2") and "Team 2" or tostring(WinTeam))

		local ColorHex = SpectatorHex
		if MyTeam and MyTeam ~= "" then
			if MyTeam == WinTeam then
				ColorHex = AllyHex
			else
				ColorHex = EnemyHex
			end
		end

		return string.format('Game over, <font color="#%s">%s</font> wins!', ColorHex, TeamDisplayName)

	elseif WinnerInfo.WinPlayer then
		local RawName   = WinnerInfo.WinPlayer.Name or "Player"
		local MaxLen    = (GuiConfig.GameOver and GuiConfig.GameOver.MaxNameLength) or 15
		local SafeName  = GuiHelper.TruncateText(RawName, MaxLen)

		return string.format('Game over, <font color="#%s">%s</font> wins!', FFAWinnerHex, SafeName)
	else
		return "Game over, Draw!"
	end
end

--- Kích hoạt chuỗi hoạt ảnh hiển thị GameOverAnnouncement
--- @param WinnerInfo table?
local function ShowAnnouncement(WinnerInfo)
	local Frame, Bg, Text = ResolveElements()
	if not Frame or not Bg or not Text then
		return
	end

	CancelPending()

	local AnimCfg = GuiHelper.GetGameOverAnnouncementAnimConfig()
	local FormattedString = FormatAnnouncementText(WinnerInfo)

	Text.RichText = true
	Text.Text     = FormattedString

	local BaseBgSize   = _DefaultBgSize or Bg.Size
	local BaseTextPos  = _DefaultTextPos or Text.Position

	-- 1. Chuẩn bị trạng thái ban đầu
	Bg.AnchorPoint   = Vector2.new(0.5, 0.5)
	Bg.Size          = UDim2.new(0, 0, BaseBgSize.Y.Scale, BaseBgSize.Y.Offset)

	Text.AnchorPoint = Vector2.new(0.5, 0.5)
	Text.Position    = UDim2.new(BaseTextPos.X.Scale, BaseTextPos.X.Offset, AnimCfg.FlyInStartPosYScale or 2.0, 0)

	Frame.Visible = true

	-- 2. Tween Split Background (mở rộng ngang từ tâm sang 2 bên)
	local SplitTweenInfo = TweenInfo.new(
		AnimCfg.SplitDuration or 0.4,
		AnimCfg.SplitEasingStyle or Enum.EasingStyle.Back,
		AnimCfg.SplitEasingDir or Enum.EasingDirection.Out
	)
	local SplitTween = TweenService:Create(Bg, SplitTweenInfo, { Size = BaseBgSize })
	table.insert(_ActiveTweens, SplitTween)
	SplitTween:Play()

	-- 3. Tween Fly In AnnouncementText (bay từ dưới lên vị trí mặc định)
	local FlyInTweenInfo = TweenInfo.new(
		AnimCfg.FlyInDuration or 0.35,
		AnimCfg.FlyInEasingStyle or Enum.EasingStyle.Back,
		AnimCfg.FlyInEasingDir or Enum.EasingDirection.Out
	)
	local FlyInTween = TweenService:Create(Text, FlyInTweenInfo, { Position = BaseTextPos })
	table.insert(_ActiveTweens, FlyInTween)
	FlyInTween:Play()

	-- 4. Hẹn giờ DisplayDuration sau đó Fly Out AnnouncementText trước rồi thu nhỏ Background
	local DisplayDuration = AnimCfg.DisplayDuration or 3.2
	_HideTask = task.delay(DisplayDuration, function()
		_HideTask = nil

		-- Pha 4.1: AnnouncementText Fly Out ra khỏi màn hình
		local FlyOutTweenInfo = TweenInfo.new(
			AnimCfg.FlyOutDuration or 0.25,
			AnimCfg.FlyOutEasingStyle or Enum.EasingStyle.Quad,
			AnimCfg.FlyOutEasingDir or Enum.EasingDirection.In
		)
		local FlyOutTargetPos = UDim2.new(BaseTextPos.X.Scale, BaseTextPos.X.Offset, AnimCfg.FlyOutTargetPosYScale or -1.0, 0)
		local FlyOutTween = TweenService:Create(Text, FlyOutTweenInfo, { Position = FlyOutTargetPos })
		table.insert(_ActiveTweens, FlyOutTween)
		FlyOutTween:Play()

		-- Pha 4.2: Ngay khi Text bay xong, Background bắt đầu co lại về 0
		FlyOutTween.Completed:Connect(function(PlaybackState)
			if PlaybackState ~= Enum.PlaybackState.Completed then return end

			local CloseTweenInfo = TweenInfo.new(
				AnimCfg.CloseDuration or 0.3,
				AnimCfg.CloseEasingStyle or Enum.EasingStyle.Quad,
				AnimCfg.CloseEasingDir or Enum.EasingDirection.In
			)

			local CloseBgTween = TweenService:Create(Bg, CloseTweenInfo, {
				Size = UDim2.new(0, 0, BaseBgSize.Y.Scale, BaseBgSize.Y.Offset)
			})
			table.insert(_ActiveTweens, CloseBgTween)
			CloseBgTween:Play()

			CloseBgTween.Completed:Connect(function(BgPlaybackState)
				if BgPlaybackState == Enum.PlaybackState.Completed then
					Frame.Visible = false
					Bg.Size = BaseBgSize
					Text.Position = BaseTextPos
				end
			end)
		end)
	end)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameOverAnnouncementController = {}

--- Ẩn khẩn cấp thông báo
function GameOverAnnouncementController.ForceHide()
	ForceHide()
end

function GameOverAnnouncementController:Init()
	ForceHide()

	-- Khôi phục và dọn dẹp khi nhân vật respawn
	LocalPlayer.CharacterAdded:Connect(function()
		ForceHide()
	end)

	-- Lắng nghe GameState để kích hoạt khi chuyển sang GameOver
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		local Phase = Data.Phase or "Intermission"

		if Phase == "GameOver" then
			if not _IsShowing then
				_IsShowing = true
				ShowAnnouncement(Data.WinnerInfo)
			end
		else
			if _IsShowing then
				_IsShowing = false
			end
			ForceHide()
		end
	end)

	print("[GameOverAnnouncementController] Đã khởi tạo thành công.")
end

return GameOverAnnouncementController
