-- AccoladesController.lua (ModuleScript)
-- Hiển thị thông báo danh hiệu (First Blood, Freezing Spree, Thawing Spree) cho LocalPlayer
-- Khi đạt danh hiệu, server fire NotifyAccolade → controller play animation + SFX
-- Ẩn với Spectator (server chỉ FireClient đến đúng người đạt danh hiệu)

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
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
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _InGameGui    = nil
local _Announcement = nil  -- AccoladesAnnouncement TextLabel

-- UDim2 kích thước mặc định của TextLabel (lấy từ GUI sau khi load)
local _DefaultSize = nil

-- Tween đang chạy (để cancel nếu accolade mới đến trước khi cái cũ kết thúc)
local _ActiveRealTween  = nil
local _ActiveGhostTween = nil
local _HideThread       = nil

-- =========================================================
-- PRIVATE
-- =========================================================

--- Phát SFX Accolade qua AudioHelper
local function PlayAccoladeSound()
	local Volume = (AudioConfig.Accolades and AudioConfig.Accolades.AnnouncementVolume) or 3
	AudioHelper.Play2DSound(AudioConfig.Accolades.Announcement, Volume, PlayerGui)
end

--- Hiển thị Announcement với animation zoom-in
--- Nếu đang có animation cũ thì cancel và bắt đầu lại ngay
--- @param AccoladeType string -- "FirstBlood" | "FreezingSpree" | "ThawingSpree"
local function ShowAnnouncement(AccoladeType)
	if not _Announcement then return end

	local Text = ACCOLADE_TEXT[AccoladeType]
	if not Text then return end

	local AnimCfg = GuiHelper.GetAccoladesAnimConfig(AccoladeType)

	-- Cancel animation và hide thread cũ (nếu có)
	if _ActiveRealTween  then _ActiveRealTween:Cancel()  end
	if _ActiveGhostTween then _ActiveGhostTween:Cancel() end
	if _HideThread then task.cancel(_HideThread) end

	-- Set text
	_Announcement.Text = Text

	-- Phát SFX
	PlayAccoladeSound()

	-- Đặt trạng thái ban đầu: nhỏ xíu, fully visible
	local StartScale = AnimCfg.StartScale or 0.05
	local StartSize = UDim2.new(
		_DefaultSize.X.Scale * StartScale, _DefaultSize.X.Offset * StartScale,
		_DefaultSize.Y.Scale * StartScale, _DefaultSize.Y.Offset * StartScale
	)
	_Announcement.Size        = StartSize
	_Announcement.TextTransparency = 0
	_Announcement.Visible     = true

	-- ── Animation Thực: zoom từ nhỏ → kích thước mặc định ──
	local RealTweenInfo = TweenInfo.new(
		AnimCfg.RealDuration    or 0.5,
		AnimCfg.RealEasingStyle or Enum.EasingStyle.Back,
		AnimCfg.RealEasingDir   or Enum.EasingDirection.Out
	)
	local RealTween = TweenService:Create(_Announcement, RealTweenInfo, {
		Size = _DefaultSize,
	})
	_ActiveRealTween = RealTween
	RealTween:Play()

	-- ── Animation Ảo: clone TextLabel zoom → lớn hơn + fade out song song ──
	local Ghost = _Announcement:Clone()
	Ghost.Name   = "AnnouncementGhost"
	Ghost.Parent = _Announcement.Parent
	Ghost.Size   = _DefaultSize  -- bắt đầu từ kích thước mặc định (cùng lúc)
	Ghost.TextTransparency = 0
	Ghost.Visible = true
	Ghost.ZIndex  = _Announcement.ZIndex - 1  -- phía sau label thực

	local GhostScale = AnimCfg.GhostScale or 1.8
	local GhostTargetSize = UDim2.new(
		_DefaultSize.X.Scale * GhostScale, _DefaultSize.X.Offset,
		_DefaultSize.Y.Scale * GhostScale, _DefaultSize.Y.Offset
	)
	local GhostTweenInfo = TweenInfo.new(
		AnimCfg.GhostDuration    or 0.7,
		AnimCfg.GhostEasingStyle or Enum.EasingStyle.Quad,
		AnimCfg.GhostEasingDir   or Enum.EasingDirection.Out
	)
	local GhostTween = TweenService:Create(Ghost, GhostTweenInfo, {
		Size              = GhostTargetSize,
		TextTransparency  = 1,
	})
	_ActiveGhostTween = GhostTween
	GhostTween:Play()
	GhostTween.Completed:Connect(function()
		Ghost:Destroy()
	end)

	-- ── Ẩn label thực sau DisplayDuration giây ──
	local DisplayDuration = AnimCfg.DisplayDuration or 3.0
	_HideThread = task.delay(DisplayDuration, function()
		if _Announcement then
			_Announcement.Visible = false
		end
	end)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local AccoladesController = {}

function AccoladesController:Init()
	-- Lấy GUI references
	_InGameGui    = PlayerGui:WaitForChild("InGameGui")
	_Announcement = _InGameGui:WaitForChild("AccoladesAnnouncement")

	-- Cache kích thước mặc định từ Studio để animation đúng tỉ lệ
	_DefaultSize = _Announcement.Size

	-- Ẩn mặc định
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
