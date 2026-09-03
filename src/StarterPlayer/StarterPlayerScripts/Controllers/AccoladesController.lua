-- AccoladesController.lua (ModuleScript)
-- Hiển thị thông báo danh hiệu (First Blood, Freezing Spree, Thawing Spree) cho LocalPlayer
-- Khi đạt danh hiệu, server fire NotifyAccolade → controller play Pop animation + SFX
-- Ẩn với Spectator (server chỉ FireClient đến đúng người đạt danh hiệu)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

-- =========================================================
-- CONFIG
-- =========================================================

-- Text hiển thị thuần tuý, không dùng emoji theo yêu cầu
local ACCOLADE_TEXT = {
	FirstBlood    = "FIRST BLOOD!",
	FreezingSpree = "FREEZING SPREE!",
	ThawingSpree  = "THAWING SPREE!",
}

-- =========================================================
-- GUI REFERENCES (lazy-init trong Init)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = nil

local _InGameGui    = nil
local _Announcement = nil  -- AccoladesAnnouncement TextLabel

-- Hide thread đang chạy (để cancel nếu accolade mới đến trước khi cái cũ kết thúc)
local _HideThread = nil

-- =========================================================
-- PRIVATE
-- =========================================================

--- Phát SFX Accolade qua Sound Pool trong GuiHelper (zero-latency, không rác bộ nhớ)
local function PlayAccoladeSound()
	GuiHelper.PlayGuiSound(AudioConfig.Accolades.Announcement)
end

--- Hiển thị Announcement với animation Pop nảy nhẹ (UIScale)
--- Nếu đang có animation cũ thì cancel và bắt đầu lại ngay
--- @param AccoladeType string -- "FirstBlood" | "FreezingSpree" | "ThawingSpree"
local function ShowAnnouncement(AccoladeType)
	if not _Announcement then return end

	local Text = ACCOLADE_TEXT[AccoladeType]
	if not Text then return end

	local AnimCfg = GuiHelper.GetAccoladesAnimConfig(AccoladeType)

	-- Cancel hide thread cũ (nếu có)
	if _HideThread then
		task.cancel(_HideThread)
		_HideThread = nil
	end

	-- Cancel tween cũ nếu đang chạy trên UIScale
	local UiScale = GuiHelper.GetOrCreateScale(_Announcement)
	if UiScale then
		GuiHelper.CancelTween(UiScale)
	end

	-- Set text
	_Announcement.Text = Text

	-- Phát SFX qua Sound Pool
	PlayAccoladeSound()

	-- Pop mở TextLabel
	GuiHelper.PopOpen(_Announcement, {
		Duration     = AnimCfg.OpenDuration,
		EasingStyle  = AnimCfg.OpenEasingStyle,
		EasingDir    = AnimCfg.OpenEasingDir,
		InitialScale = AnimCfg.InitialScale,
		TargetScale  = AnimCfg.TargetScale,
	})

	-- Sau DisplayDuration giây, tự động PopClose thu nhỏ lại
	local DisplayDuration = AnimCfg.DisplayDuration or 1.5
	_HideThread = task.delay(DisplayDuration, function()
		if _Announcement then
			GuiHelper.PopClose(_Announcement, {
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

local AccoladesController = {}

function AccoladesController:Init()
	local Timeout = (GuiConfig.Timeouts and GuiConfig.Timeouts.DefaultWaitForGui) or 10

	PlayerGui = LocalPlayer:WaitForChild("PlayerGui", Timeout)
	if not PlayerGui then return end

	_InGameGui    = PlayerGui:WaitForChild("InGameGui", Timeout)
	if not _InGameGui then return end

	_Announcement = _InGameGui:WaitForChild("AccoladesAnnouncement", Timeout)
	if not _Announcement then return end

	-- Khởi tạo UIScale và ẩn mặc định
	local UiScale = GuiHelper.GetOrCreateScale(_Announcement)
	if UiScale then
		UiScale.Scale = 0
	end
	_Announcement.Visible = false

	-- Lắng nghe NotifyAccolade từ server (chỉ LocalPlayer nhận được vì server dùng FireClient)
	local NotifyAccoladeEvent = RemoteDefinitions.GetEvent("NotifyAccolade")
	NotifyAccoladeEvent.OnClientEvent:Connect(function(Data)
		if not Data or not Data.Type then return end
		ShowAnnouncement(Data.Type)
	end)

	print("[AccoladesController] Đã khởi tạo.")
end

return AccoladesController
