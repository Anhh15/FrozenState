-- SettingController.lua (ModuleScript)
-- Điều khiển giao diện Menu Setting (Cài đặt Gameplay: AFK Toggle & Cài đặt Sound: Master, Music, SFX, UI Sliders)
-- Tích hợp cơ chế điều phối qua MenuController, SliderHelper 11 ticks, SoundGroup và đồng bộ DataStore

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiAnimConfig     = require(ReplicatedStorage.Shared.Config.GuiAnimConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local SliderHelper      = require(ReplicatedStorage.Shared.Tools.SliderHelper)
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

-- Tham chiếu 4 Sliders
local _MasterSlider = nil
local _MusicSlider  = nil
local _SfxSlider    = nil
local _UiSlider     = nil

local _IsAfk = false
local _ActiveTweens = {}
local _HasUserModifiedSettings = false
local _IsSettingsApplied = false

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

-- Lazy-require PlayerDataController để lấy Settings từ DataStore
local _PlayerDataController = nil
local function GetPlayerDataController()
	if not _PlayerDataController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("PlayerDataController")
		if Module then
			_PlayerDataController = require(Module)
		end
	end
	return _PlayerDataController
end

-- =========================================================
-- PRIVATE HELPERS: TWEEN & TOGGLE
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

--- Gửi cài đặt âm lượng lên Server khi thả tay khỏi Slider
--- @param Key string
--- @param Value number
local function SaveSettingToServer(Key, Value)
	local SaveSettingEvent = RemoteDefinitions.GetEvent("SaveSetting")
	if SaveSettingEvent then
		SaveSettingEvent:FireServer({ Key = Key, Value = Value })
	end
end

--- Xử lý khi bấm chuyển sang một trạng thái AFK mới
--- @param NewState boolean
local function HandleToggleRequest(NewState)
	if _IsAfk == NewState then
		return
	end

	_IsAfk = NewState
	PlayToggleSound()
	SyncVisualState(_IsAfk, true)
	SendAfkStateToServer(_IsAfk)
end

-- =========================================================
-- PRIVATE HELPERS: SLIDERS & SOUND
-- =========================================================

--- Khởi tạo 1 hàng Slider cho kênh âm thanh tương ứng
--- @param RowFrame Frame?
--- @param SoundGroupName string -- "Master" | "Music" | "SFX" | "UI"
--- @param SettingKey string -- "MasterVolume" | "MusicVolume" | "SFXVolume" | "UIVolume"
--- @return table? -- Slider object
local function SetupSliderRow(RowFrame, SoundGroupName, SettingKey)
	if not RowFrame then return nil end

	local SlideBar = RowFrame:FindFirstChild(GuiConfig.SettingElements.SlideBar, true)
	if not SlideBar then return nil end

	local Slider = SliderHelper.Create(SlideBar, {
		InitialValue   = 100,
		StepCount      = 10,
		PlayTickSound  = true,
		OnValueChanged = function(NewPercent)
			_HasUserModifiedSettings = true
			AudioHelper.SetVolume(SoundGroupName, NewPercent)
		end,
		OnDragEnded    = function(FinalPercent)
			_HasUserModifiedSettings = true
			SaveSettingToServer(SettingKey, FinalPercent)
		end,
	})

	return Slider
end

--- Áp dụng bảng Settings nhận được từ DataStore
--- @param Settings table
local function ApplyLoadedSettings(Settings)
	if not Settings then return end

	if _MasterSlider and Settings.MasterVolume ~= nil then
		_MasterSlider:SetValue(Settings.MasterVolume, false)
		AudioHelper.SetVolume("Master", Settings.MasterVolume)
	end
	if _MusicSlider and Settings.MusicVolume ~= nil then
		_MusicSlider:SetValue(Settings.MusicVolume, false)
		AudioHelper.SetVolume("Music", Settings.MusicVolume)
	end
	if _SfxSlider and Settings.SFXVolume ~= nil then
		_SfxSlider:SetValue(Settings.SFXVolume, false)
		AudioHelper.SetVolume("SFX", Settings.SFXVolume)
	end
	if _UiSlider and Settings.UIVolume ~= nil then
		_UiSlider:SetValue(Settings.UIVolume, false)
		AudioHelper.SetVolume("UI", Settings.UIVolume)
	end
	_IsSettingsApplied = true
end

-- =========================================================
-- TAB LIFECYCLE
-- =========================================================

local function OpenSetting()
	if not SettingFrame then return end
	SyncVisualState(_IsAfk, false)

	-- Nếu người chơi chưa từng tự chỉnh và có dữ liệu settings từ DataStore
	if not _HasUserModifiedSettings then
		local PlayerDataCtrl = GetPlayerDataController()
		local Data = PlayerDataCtrl and PlayerDataCtrl.GetData()
		if Data and Data.Settings then
			ApplyLoadedSettings(Data.Settings)
		end
	end

	-- Làm mới vị trí núm Knob khi mở giao diện
	if _MasterSlider then _MasterSlider:SetValue(_MasterSlider:GetValue(), false) end
	if _MusicSlider  then _MusicSlider:SetValue(_MusicSlider:GetValue(), false)   end
	if _SfxSlider    then _SfxSlider:SetValue(_SfxSlider:GetValue(), false)       end
	if _UiSlider     then _UiSlider:SetValue(_UiSlider:GetValue(), false)         end
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

	-- 1. Tìm các phần tử con Gameplay (AFK Toggle)
	ConfigFrame = SettingFrame:FindFirstChild(GuiConfig.SettingElements.Config, true)
	OnButton    = SettingFrame:FindFirstChild(GuiConfig.SettingElements.OnButton, true)
	OffButton   = SettingFrame:FindFirstChild(GuiConfig.SettingElements.OffButton, true)
	CloseButton = SettingFrame:FindFirstChild(GuiConfig.SettingElements.CloseButton, true)

	-- Gán trạng thái hiển thị ban đầu của AFK
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

	-- 2. Tìm và khởi tạo 4 hàng Sliders trong SoundSection
	local MasterRow = SettingFrame:FindFirstChild(GuiConfig.SettingElements.MasterRow, true)
	local MusicRow  = SettingFrame:FindFirstChild(GuiConfig.SettingElements.MusicRow, true)
	local SfxRow    = SettingFrame:FindFirstChild(GuiConfig.SettingElements.SFXRow, true)
	local UiRow     = SettingFrame:FindFirstChild(GuiConfig.SettingElements.UIRow, true)

	_MasterSlider = SetupSliderRow(MasterRow, "Master", "MasterVolume")
	_MusicSlider  = SetupSliderRow(MusicRow,  "Music",  "MusicVolume")
	_SfxSlider    = SetupSliderRow(SfxRow,    "SFX",    "SFXVolume")
	_UiSlider     = SetupSliderRow(UiRow,     "UI",     "UIVolume")

	-- 3. Nạp Settings từ DataStore thông qua OnDataLoaded Signal
	local PlayerDataCtrl = GetPlayerDataController()
	if PlayerDataCtrl and PlayerDataCtrl.OnDataLoaded then
		PlayerDataCtrl.OnDataLoaded(function(Data)
			if Data and Data.Settings and not _HasUserModifiedSettings then
				ApplyLoadedSettings(Data.Settings)
			end
		end)
	end

	-- 4. Kết nối nút đóng nếu có
	if CloseButton and CloseButton:IsA("GuiButton") then
		CloseButton.MouseButton1Click:Connect(function()
			local MenuCtrl = GetMenuController()
			if MenuCtrl then
				MenuCtrl.CloseCurrentTab()
			end
		end)
	end

	-- Đăng ký tab Setting với MenuController
	local MenuCtrl = GetMenuController()
	if MenuCtrl then
		MenuCtrl.RegisterTab("Setting", {
			Open  = OpenSetting,
			Close = CloseSetting,
			Frame = SettingFrame,
		})
	end

	print("[SettingController] Đã khởi tạo đầy đủ Gameplay & Sound Sections.")
end

function SettingController:Start()
	local Controllers = script.Parent
	local MenuModule = Controllers:FindFirstChild("MenuController")
	if MenuModule then _MenuController = require(MenuModule) end

	local PlayerDataModule = Controllers:FindFirstChild("PlayerDataController")
	if PlayerDataModule then _PlayerDataController = require(PlayerDataModule) end
end

return SettingController
