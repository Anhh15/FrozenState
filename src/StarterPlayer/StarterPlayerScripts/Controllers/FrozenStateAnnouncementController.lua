-- FrozenStateAnnouncementController.lua (ModuleScript)
-- Quản lý hiệu ứng Pop và SFX thông báo khi trận đấu chuyển sang Frozen State
-- Đặt tại StarterGui/InGameGui/FrozenStateAnnouncement (TextLabel)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _InGameGui           = nil
local _Announcement        = nil -- FrozenStateAnnouncement TextLabel
local _HideThread          = nil
local _LastIsFrozenState   = false
local _LastPhase           = "Intermission"

-- =========================================================
-- GUI RESOLVER
-- =========================================================

--- Truy xuất động TextLabel FrozenStateAnnouncement từ PlayerGui
--- @return TextLabel?
local function ResolveElements()
	local InGameGuiName = (GuiConfig.ScreenGuis and GuiConfig.ScreenGuis.InGameGui) or "InGameGui"
	_InGameGui = PlayerGui:FindFirstChild(InGameGuiName) or PlayerGui:WaitForChild(InGameGuiName, GuiConfig.Timeouts.DefaultWaitForGui or 10)
	if not _InGameGui then return nil end

	local AnnouncementName = (GuiConfig.InGameAnnouncements and GuiConfig.InGameAnnouncements.FrozenStateAnnouncement) or "FrozenStateAnnouncement"
	_Announcement = _InGameGui:FindFirstChild(AnnouncementName) or _InGameGui:WaitForChild(AnnouncementName, GuiConfig.Timeouts.ShortWait or 5)

	return _Announcement
end

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Phát SFX Frozen State Announcement qua Sound Pool
local function PlayAnnouncementSound()
	local SoundEntry = AudioConfig.Special and AudioConfig.Special.FrozenStateAnnouncement
	if SoundEntry then
		GuiHelper.PlayGuiSound(SoundEntry)
	end
end

--- Hủy toàn bộ tween và task ẩn đang chờ
local function CancelPending()
	if _HideThread then
		task.cancel(_HideThread)
		_HideThread = nil
	end

	if _Announcement then
		local UiScale = GuiHelper.GetOrCreateScale(_Announcement)
		if UiScale then
			GuiHelper.CancelTween(UiScale)
		end
	end
end

--- Ẩn khẩn cấp TextLabel và reset scale
local function ForceHide()
	CancelPending()
	local Announcement = ResolveElements()
	if Announcement then
		local UiScale = GuiHelper.GetOrCreateScale(Announcement)
		if UiScale then
			UiScale.Scale = 0
		end
		Announcement.Visible = false
	end
end

--- Hiển thị thông báo Frozen State với hiệu ứng Pop (UIScale)
local function ShowAnnouncement()
	local Announcement = ResolveElements()
	if not Announcement then return end

	CancelPending()

	local AnimCfg = GuiHelper.GetFrozenStateAnnouncementAnimConfig()

	-- Phát âm thanh thông báo
	PlayAnnouncementSound()

	-- Pop mở TextLabel
	GuiHelper.PopOpen(Announcement, {
		Duration     = AnimCfg.OpenDuration,
		EasingStyle  = AnimCfg.OpenEasingStyle,
		EasingDir    = AnimCfg.OpenEasingDir,
		InitialScale = AnimCfg.InitialScale,
		TargetScale  = AnimCfg.TargetScale,
	})

	-- Sau DisplayDuration giây, tự động PopClose thu nhỏ lại
	local DisplayDuration = AnimCfg.DisplayDuration or 1.5
	_HideThread = task.delay(DisplayDuration, function()
		if Announcement then
			GuiHelper.PopClose(Announcement, {
				Duration     = AnimCfg.CloseDuration,
				EasingStyle  = AnimCfg.CloseEasingStyle,
				EasingDir    = AnimCfg.CloseEasingDir,
				TargetScale  = AnimCfg.InitialScale,
			})
		end
		_HideThread = nil
	end)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local FrozenStateAnnouncementController = {}

--- Ẩn khẩn cấp thông báo
function FrozenStateAnnouncementController.ForceHide()
	ForceHide()
end

function FrozenStateAnnouncementController:Init()
	-- Khởi tạo ban đầu: ẩn TextLabel và scale về 0
	ForceHide()

	-- Dọn dẹp khi nhân vật respawn
	LocalPlayer.CharacterAdded:Connect(function()
		ForceHide()
	end)

	-- Lắng nghe GameState từ server
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end

		local CurrentPhase        = Data.Phase or "Intermission"
		local CurrentIsFrozenState = Data.IsFrozenState or false

		-- Nếu không còn ở phase InGame -> dọn dẹp và reset cờ
		if CurrentPhase ~= "InGame" then
			if _LastPhase == "InGame" or _LastIsFrozenState then
				ForceHide()
			end
			_LastIsFrozenState = false
			_LastPhase         = CurrentPhase
			return
		end

		-- Ở phase InGame: kiểm tra bước chuyển trạng thái (State Transition false -> true)
		if CurrentIsFrozenState and not _LastIsFrozenState then
			_LastIsFrozenState = true
			-- Chỉ phát khi game đã tải xong (không phát đè lên màn hình loading)
			if PlayerStateHelper.IsGameLoaded(LocalPlayer) then
				ShowAnnouncement()
			end
		elseif not CurrentIsFrozenState then
			_LastIsFrozenState = false
		end

		_LastPhase = CurrentPhase
	end)

	print("[FrozenStateAnnouncementController] Đã khởi tạo.")
end

return FrozenStateAnnouncementController
