-- AccoladesController.lua (ModuleScript)
-- Hiển thị thông báo danh hiệu (First Blood, Freezing Spree, Thawing Spree) cho LocalPlayer
-- Khi đạt danh hiệu, server fire NotifyAccolade → controller play animation + SFX
-- Ẩn với Spectator (server chỉ FireClient đến đúng người đạt danh hiệu)

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- CONFIG
-- =========================================================

-- Text hiển thị thuần tuý, không dùng emoji theo yêu cầu
local ACCOLADE_TEXT = {
	FirstBlood    = "FIRST BLOOD!",
	FreezingSpree = "FREEZING SPREE!",
	ThawingSpree  = "THAWING SPREE!",
}

local SFX_ACCOLADE = 96102213526905

-- Thời lượng animation (giây)
local ANIM_REAL_DURATION    = 0.5   -- Thực: zoom vào kích thước mặc định
local ANIM_GHOST_DURATION   = 0.7   -- Ảo: zoom lớn + fade out (chạy song song)
local DISPLAY_HOLD_DURATION = 3.0   -- Tổng thời gian hiển thị tính từ đầu animation

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

--- Phát SFX Accolade (tự hủy sau khi phát)
local function PlayAccoladeSound()
	local S = Instance.new("Sound")
	S.SoundId = "rbxassetid://" .. tostring(SFX_ACCOLADE)
	S.Volume  = 1
	S.Parent  = PlayerGui
	S:Play()
	game:GetService("Debris"):AddItem(S, 5)
end

--- Hiển thị Announcement với animation zoom-in
--- Nếu đang có animation cũ thì cancel và bắt đầu lại ngay
--- @param AccoladeType string -- "FirstBlood" | "FreezingSpree" | "ThawingSpree"
local function ShowAnnouncement(AccoladeType)
	if not _Announcement then return end

	local Text = ACCOLADE_TEXT[AccoladeType]
	if not Text then return end

	-- Cancel animation và hide thread cũ (nếu có)
	if _ActiveRealTween  then _ActiveRealTween:Cancel()  end
	if _ActiveGhostTween then _ActiveGhostTween:Cancel() end
	if _HideThread then task.cancel(_HideThread) end

	-- Set text
	_Announcement.Text = Text

	-- Phát SFX
	PlayAccoladeSound()

	-- Đặt trạng thái ban đầu: nhỏ xíu, fully visible
	local StartSize = UDim2.new(
		_DefaultSize.X.Scale * 0.05, _DefaultSize.X.Offset * 0.05,
		_DefaultSize.Y.Scale * 0.05, _DefaultSize.Y.Offset * 0.05
	)
	_Announcement.Size        = StartSize
	_Announcement.TextTransparency = 0
	_Announcement.Visible     = true

	-- ── Animation Thực: zoom từ nhỏ → kích thước mặc định (0.5s, Back easing) ──
	local RealTweenInfo = TweenInfo.new(
		ANIM_REAL_DURATION,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	local RealTween = TweenService:Create(_Announcement, RealTweenInfo, {
		Size = _DefaultSize,
	})
	_ActiveRealTween = RealTween
	RealTween:Play()

	-- ── Animation Ảo: clone TextLabel zoom → lớn hơn + fade out song song ──
	-- Tạo một bản clone để chạy hiệu ứng ảo (ghost), không ảnh hưởng đến label thực
	local Ghost = _Announcement:Clone()
	Ghost.Name   = "AnnouncementGhost"
	Ghost.Parent = _Announcement.Parent
	Ghost.Size   = _DefaultSize  -- bắt đầu từ kích thước mặc định (cùng lúc)
	Ghost.TextTransparency = 0
	Ghost.Visible = true
	Ghost.ZIndex  = _Announcement.ZIndex - 1  -- phía sau label thực

	local GhostTargetSize = UDim2.new(
		_DefaultSize.X.Scale * 1.8, _DefaultSize.X.Offset,
		_DefaultSize.Y.Scale * 1.8, _DefaultSize.Y.Offset
	)
	local GhostTweenInfo = TweenInfo.new(
		ANIM_GHOST_DURATION,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
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

	-- ── Ẩn label thực sau DISPLAY_HOLD_DURATION giây ──
	_HideThread = task.delay(DISPLAY_HOLD_DURATION, function()
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
