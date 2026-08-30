-- SettingController.lua (ModuleScript)
-- Điều khiển giao diện Menu Setting (Cài đặt Gameplay: AFK Toggle)
-- Tích hợp cơ chế điều phối qua MenuController, hiệu ứng tween chuyển màu và SFX toggle

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiAnimConfig     = require(ReplicatedStorage.Shared.Config.GuiAnimConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- STATE & REFS
-- =========================================================

local SettingFrame = nil
local OnButton     = nil
local OffButton    = nil
local CloseButton  = nil
local ConfigFrame  = nil

local _IsAfk = false
local _ActiveTweens = {}

-- Lazy-require MenuController để điều phối mở/đóng cửa sổ
local _MenuController = nil
local function GetMenuController()
	if not _MenuController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("MenuController")
		if Module then
			_MenuController = require(Module)
		end
	end
	return _MenuController
end

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Hủy tween đang chạy trên một Instance (nếu có)
--- @param TargetInstance Instance
local function CancelInstanceTween(TargetInstance)
	if _ActiveTweens[TargetInstance] then
		_ActiveTweens[TargetInstance]:Cancel()
		_ActiveTweens[TargetInstance] = nil
	end
end

--- Áp dụng trạng thái màu sắc cho nút (Active / Inactive)
--- @param Button GuiObject? Nút cha (OnButton hoặc OffButton)
--- @param IsActive boolean Trạng thái nút có đang được chọn hay không
--- @param Animate boolean Có chạy hiệu ứng tween hay đổi màu ngay lập tức
local function UpdateSingleButtonStyle(Button, IsActive, Animate)
	if not Button then return end

	local SettingAnimCfg = GuiAnimConfig.GetSettingAnimConfig()
	local TargetBgColor   = IsActive and SettingAnimCfg.ActiveBackgroundColor or SettingAnimCfg.InactiveBackgroundColor
	local TargetTextColor = IsActive and SettingAnimCfg.ActiveTextColor or SettingAnimCfg.InactiveTextColor

	local BackgroundFrame = Button:FindFirstChild(GuiConfig.SettingElements.Background) or Button:FindFirstChildWhichIsA("Frame")
	local TextLabel       = Button:FindFirstChild(GuiConfig.SettingElements.Text) or Button:FindFirstChildWhichIsA("TextLabel")

	if BackgroundFrame then
		CancelInstanceTween(BackgroundFrame)
		if Animate then
			local TweenInfoObj = TweenInfo.new(
				SettingAnimCfg.Duration,
				SettingAnimCfg.EasingStyle,
				SettingAnimCfg.EasingDir
			)
			local Tween = TweenService:Create(BackgroundFrame, TweenInfoObj, { BackgroundColor3 = TargetBgColor })
			_ActiveTweens[BackgroundFrame] = Tween
			Tween:Play()
		else
			BackgroundFrame.BackgroundColor3 = TargetBgColor
		end
	end

	if TextLabel then
		CancelInstanceTween(TextLabel)
		if Animate then
			local TweenInfoObj = TweenInfo.new(
				SettingAnimCfg.Duration,
				SettingAnimCfg.EasingStyle,
				SettingAnimCfg.EasingDir
			)
			local Tween = TweenService:Create(TextLabel, TweenInfoObj, { TextColor3 = TargetTextColor })
			_ActiveTweens[TextLabel] = Tween
			Tween:Play()
		else
			TextLabel.TextColor3 = TargetTextColor
		end
	end
end

--- Đồng bộ giao diện cả 2 nút OnButton và OffButton theo trạng thái AFK
--- @param IsAfk boolean
--- @param Animate boolean
local function SyncVisualState(IsAfk, Animate)
	UpdateSingleButtonStyle(OnButton, IsAfk, Animate)
	UpdateSingleButtonStyle(OffButton, not IsAfk, Animate)
end

--- Phát âm thanh toggle chuyển trạng thái
local function PlayToggleSound()
	local AudioEntry = AudioConfig.Setting and AudioConfig.Setting.Toggle
	if AudioEntry then
		AudioHelper.PlayGuiSound(AudioEntry)
	end
end

--- Gửi trạng thái AFK lên Server
--- @param IsAfk boolean
local function SendAfkStateToServer(IsAfk)
	local SetAfkStateEvent = RemoteDefinitions.GetEvent("SetAfkState")
	if SetAfkStateEvent then
		SetAfkStateEvent:FireServer({ IsAfk = IsAfk })
	end
end

--- Xử lý khi bấm chuyển sang một trạng thái AFK mới
--- @param NewState boolean
local function HandleToggleRequest(NewState)
	if _IsAfk == NewState then
		-- Đang ở đúng trạng thái này rồi -> không làm gì, không phát SFX, không chạy animation
		return
	end

	_IsAfk = NewState
	PlayToggleSound()
	SyncVisualState(_IsAfk, true)
	SendAfkStateToServer(_IsAfk)
end

-- =========================================================
-- TAB LIFECYCLE
-- =========================================================

local function OpenSetting()
	if not SettingFrame then return end
	SyncVisualState(_IsAfk, false)
end

local function CloseSetting()
	-- Không cần dọn dẹp đặc biệt khi đóng
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local SettingController = {}

--- Lấy trạng thái AFK hiện tại phía Client
--- @return boolean
function SettingController.IsAfk()
	return _IsAfk
end

--- Khởi tạo SettingController
function SettingController:Init()
	local MenuGui = GuiHelper.GetScreenGui("Menu")
	if not MenuGui then
		warn("[SettingController] Không tìm thấy ScreenGui 'Menu'.")
		return
	end

	SettingFrame = MenuGui:FindFirstChild(GuiConfig.MenuFrames.Setting, true)
	if not SettingFrame then
		warn("[SettingController] Không tìm thấy Frame 'Setting' trong ScreenGui 'Menu'.")
		return
	end

	-- Ẩn mặc định ban đầu
	SettingFrame.Visible = false

	-- Tìm các phần tử con bên trong Setting
	ConfigFrame = SettingFrame:FindFirstChild(GuiConfig.SettingElements.Config, true)
	OnButton    = SettingFrame:FindFirstChild(GuiConfig.SettingElements.OnButton, true)
	OffButton   = SettingFrame:FindFirstChild(GuiConfig.SettingElements.OffButton, true)
	CloseButton = SettingFrame:FindFirstChild(GuiConfig.SettingElements.CloseButton, true)

	-- Tắt AutoBind toàn cục trên cụm nút Setting để tránh phát SFX click & hover mặc định
	if ConfigFrame then
		GuiHelper.SetIgnoreAutoBind(ConfigFrame, true)
	end
	if OnButton then
		GuiHelper.SetIgnoreAutoBind(OnButton, true)
	end
	if OffButton then
		GuiHelper.SetIgnoreAutoBind(OffButton, true)
	end

	-- Gán trạng thái hiển thị ban đầu (Mặc định: AFK = false -> OffButton Active, OnButton Inactive)
	_IsAfk = PlayerStateHelper.IsAfk(LocalPlayer)
	SyncVisualState(_IsAfk, false)

	-- Kết nối sự kiện click nút On / Off
	if OnButton and (OnButton:IsA("GuiButton") or OnButton:IsA("ImageButton") or OnButton:IsA("TextButton")) then
		OnButton.MouseButton1Click:Connect(function()
			HandleToggleRequest(true)
		end)
	end

	if OffButton and (OffButton:IsA("GuiButton") or OffButton:IsA("ImageButton") or OffButton:IsA("TextButton")) then
		OffButton.MouseButton1Click:Connect(function()
			HandleToggleRequest(false)
		end)
	end

	-- Kết nối nút đóng nếu có
	if CloseButton and CloseButton:IsA("GuiButton") then
		CloseButton.MouseButton1Click:Connect(function()
			local MenuCtrl = GetMenuController()
			if MenuCtrl then
				MenuCtrl.CloseCurrentTab()
			end
		end)
	end

	-- Tự động gắn AutoBind SFX cho các nút còn lại trong SettingFrame (ngoại trừ cụm Config/On/Off đã Ignore)
	GuiHelper.AutoBindButtons(SettingFrame, { MenuName = "Setting" })

	-- Đăng ký tab Setting với MenuController
	local MenuCtrl = GetMenuController()
	if MenuCtrl then
		MenuCtrl.RegisterTab("Setting", {
			Open  = OpenSetting,
			Close = CloseSetting,
			Frame = SettingFrame,
		})
	end

	print("[SettingController] Đã khởi tạo.")
end

return SettingController
