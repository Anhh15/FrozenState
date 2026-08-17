-- GuiHelper.lua
-- Công cụ hỗ trợ truy xuất và quản lý giao diện (GUI) an toàn cho Client
-- Sử dụng GuiConfig làm Single Source of Truth

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local GuiConfig   = require(ReplicatedStorage.Shared.Config.GuiConfig)
local AudioHelper = require(ReplicatedStorage.Shared.Tools.AudioHelper)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _activeTweens = {}

local GuiHelper = {}

--- Lấy PlayerGui của LocalPlayer
--- @return PlayerGui
function GuiHelper.GetPlayerGui()
	return PlayerGui
end

--- Lấy ScreenGui từ PlayerGui theo Key trong GuiConfig hoặc tên trực tiếp
--- @param GuiKey string Key trong GuiConfig.ScreenGuis (ví dụ: "NavigationButtons", "Menu")
--- @param Timeout number? Thời gian timeout tùy chọn (mặc định từ GuiConfig.Timeouts)
--- @return ScreenGui?
function GuiHelper.GetScreenGui(GuiKey, Timeout)
	local GuiName = GuiConfig.ScreenGuis[GuiKey] or GuiKey
	local WaitTime = Timeout or GuiConfig.Timeouts.DefaultWaitForGui
	if WaitTime <= 0 then
		return PlayerGui:FindFirstChild(GuiName)
	end
	return PlayerGui:WaitForChild(GuiName, WaitTime)
end

--- Lấy ScreenGui NavigationButtons
--- @param Timeout number?
--- @return ScreenGui?
function GuiHelper.GetNavigationGui(Timeout)
	return GuiHelper.GetScreenGui("NavigationButtons", Timeout)
end

--- Lấy Frame chứa danh sách các nút điều hướng trong NavigationButtons
--- @param Timeout number?
--- @return Frame?
function GuiHelper.GetNavButtonsContainer(Timeout)
	local WaitTime = Timeout or GuiConfig.Timeouts.ShortWait
	local NavGui   = GuiHelper.GetNavigationGui(WaitTime)
	if not NavGui then return nil end

	local ContainerName = GuiConfig.NavContainers.Buttons
	-- Hỗ trợ tìm "Buttons" hoặc fallback "Button" nếu studio chưa đổi kịp
	local Container = NavGui:FindFirstChild(ContainerName) or NavGui:FindFirstChild("Button")
	if not Container and WaitTime and WaitTime > 0 then
		Container = NavGui:WaitForChild(ContainerName, WaitTime) or NavGui:WaitForChild("Button", WaitTime)
	end
	return Container
end

--- Tìm nút điều hướng (NavButton) trong NavigationButtons theo tên đệ quy
--- @param ButtonName string Tên nút (ví dụ: "Profile", "Shop", "Inventory", "Quest", "Spectate", "Setting")
--- @param Timeout number?
--- @return GuiButton?
function GuiHelper.GetNavButton(ButtonName, Timeout)
	local WaitTime = Timeout or GuiConfig.Timeouts.ShortWait
	local NavGui   = GuiHelper.GetNavigationGui(WaitTime)
	if not NavGui then return nil end

	local Button = NavGui:FindFirstChild(ButtonName, true)
	if not Button and WaitTime and WaitTime > 0 then
		local Container = GuiHelper.GetNavButtonsContainer(WaitTime)
		if Container then
			Button = Container:FindFirstChild(ButtonName, true)
		end
	end

	if not Button then
		warn(string.format("[GuiHelper] Không tìm thấy nút điều hướng '%s' trong NavigationButtons.", tostring(ButtonName)))
	end
	return Button
end

--- Lấy TextLabel hiển thị tiền (Cash) trong NavigationButtons
--- @param Timeout number?
--- @return TextLabel?
function GuiHelper.GetMoneyLabel(Timeout)
	local WaitTime = Timeout or GuiConfig.Timeouts.ShortWait
	local NavGui   = GuiHelper.GetNavigationGui(WaitTime)
	if not NavGui then
		warn("[GuiHelper] Không tìm thấy NavigationButtons GUI để lấy MoneyLabel.")
		return nil
	end

	local MoneyTextName      = GuiConfig.Stats.MoneyText
	local StatsContainerName = GuiConfig.NavContainers.Stats
	local MoneyStatsName     = GuiConfig.Stats.MoneyStats

	-- 1. Tìm đệ quy trực tiếp theo tên MoneyText trong toàn bộ cây NavigationButtons
	local MoneyText = NavGui:FindFirstChild(MoneyTextName, true)

	-- 2. Nếu chưa tìm thấy và có Timeout, tìm kiếm có chờ đợi
	if not MoneyText and WaitTime and WaitTime > 0 then
		local Stats = NavGui:FindFirstChild(StatsContainerName, true)
			or NavGui:WaitForChild(StatsContainerName, WaitTime)

		local MoneyStats = Stats and (
			Stats:FindFirstChild(MoneyStatsName, true)
			or Stats:WaitForChild(MoneyStatsName, WaitTime)
		)

		MoneyText = MoneyStats and (
			MoneyStats:FindFirstChild(MoneyTextName, true)
			or MoneyStats:WaitForChild(MoneyTextName, WaitTime)
		)

		if not MoneyText then
			MoneyText = NavGui:WaitForChild(MoneyTextName, WaitTime)
		end
	end

	if not MoneyText then
		warn(string.format("[GuiHelper] Không tìm thấy TextLabel '%s' trong NavigationButtons.", tostring(MoneyTextName)))
	end

	return MoneyText
end

--- Phát âm thanh GUI cục bộ
--- @param SoundId number | string
--- @param Volume number?
function GuiHelper.PlayGuiSound(SoundId, Volume)
	return AudioHelper.PlayGuiSound(SoundId, Volume)
end

--- Gắn hiệu ứng âm thanh (Hover/Click) cho một GuiButton
--- @param Button GuiButton
--- @param ClickSoundId number?
--- @param HoverSoundId number?
function GuiHelper.BindButtonSound(Button, ClickSoundId, HoverSoundId)
	if not Button or not Button:IsA("GuiButton") then return end

	if HoverSoundId then
		Button.MouseEnter:Connect(function()
			GuiHelper.PlayGuiSound(HoverSoundId)
		end)
	end

	if ClickSoundId then
		Button.MouseButton1Click:Connect(function()
			GuiHelper.PlayGuiSound(ClickSoundId)
		end)
	end
end


-- =========================================================
-- ANIMATION / TWEEN UTILITIES (UIScale BASED)
-- =========================================================

--- Lấy hoặc khởi tạo instance UIScale bên trong GuiObject
--- @param GuiObject GuiObject
--- @return UIScale?
function GuiHelper.GetOrCreateScale(GuiObject)
	if not GuiObject or not GuiObject:IsA("GuiObject") then return nil end

	local Scale = GuiObject:FindFirstChildOfClass("UIScale")
	if not Scale then
		Scale = Instance.new("UIScale")
		Scale.Scale = 1
		Scale.Parent = GuiObject
	end
	return Scale
end

--- Hủy bỏ Tween đang chạy trên một Instance (nếu có)
--- @param Target Instance
function GuiHelper.CancelTween(Target)
	if not Target then return end
	local CurrentTween = _activeTweens[Target]
	if CurrentTween then
		CurrentTween:Cancel()
		_activeTweens[Target] = nil
	end
end

--- Lấy cấu hình Scale của Button dựa theo tên nút (kết hợp Default và Overrides)
--- @param ButtonName string?
--- @return table
function GuiHelper.GetButtonScaleConfig(ButtonName)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.ButtonScale
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or AnimConfig or {}
	local OverrideCfg = (ButtonName and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[ButtonName]) or {}

	return {
		Duration     = OverrideCfg.Duration     or DefaultCfg.Duration     or 0.15,
		EasingStyle  = OverrideCfg.EasingStyle  or DefaultCfg.EasingStyle  or Enum.EasingStyle.Back,
		EasingDir    = OverrideCfg.EasingDir    or DefaultCfg.EasingDir    or Enum.EasingDirection.Out,
		DefaultScale = OverrideCfg.DefaultScale or DefaultCfg.DefaultScale or 1.0,
		HoverScale   = OverrideCfg.HoverScale   or DefaultCfg.HoverScale   or 1.15,
		PressScale   = OverrideCfg.PressScale   or DefaultCfg.PressScale   or 0.92,
	}
end

--- Tween thuộc tính UIScale của một GuiObject đến giá trị chỉ định
--- @param TargetObject GuiObject
--- @param TargetScale number
--- @param Duration number?
--- @param Style Enum.EasingStyle?
--- @param Direction Enum.EasingDirection?
--- @param OnComplete ( () -> () )?
--- @return Tween?
function GuiHelper.TweenScale(TargetObject, TargetScale, Duration, Style, Direction, OnComplete)
	if not TargetObject or not TargetObject:IsA("GuiObject") then return nil end

	local UiScale = GuiHelper.GetOrCreateScale(TargetObject)
	if not UiScale then return nil end

	GuiHelper.CancelTween(UiScale)

	local Cfg           = GuiHelper.GetButtonScaleConfig(TargetObject.Name)
	local TweenDuration = Duration  or Cfg.Duration
	local EasingStyle   = Style     or Cfg.EasingStyle
	local EasingDir     = Direction or Cfg.EasingDir

	local TweenInfoObj = TweenInfo.new(TweenDuration, EasingStyle, EasingDir)
	local Tween = TweenService:Create(UiScale, TweenInfoObj, { Scale = TargetScale })
	_activeTweens[UiScale] = Tween

	Tween.Completed:Connect(function(PlaybackState)
		if _activeTweens[UiScale] == Tween then
			_activeTweens[UiScale] = nil
		end
		if PlaybackState == Enum.PlaybackState.Completed and OnComplete then
			OnComplete()
		end
	end)

	Tween:Play()
	return Tween
end

--- Mở một cửa sổ GUI kèm hiệu ứng Zoom Pop nảy nhẹ
--- @param GuiObject GuiObject Frame hoặc container cần mở
--- @param CustomConfig table? { Duration: number?, EasingStyle: Enum.EasingStyle?, EasingDir: Enum.EasingDirection?, TargetScale: number?, InitialScale: number? }
--- @param OnComplete ( () -> () )? Callback chạy khi animation mở hoàn tất
--- @return Tween?
function GuiHelper.PopOpen(GuiObject, CustomConfig, OnComplete)
	if not GuiObject or not GuiObject:IsA("GuiObject") then return nil end

	local PopConfig = GuiConfig.Animations and GuiConfig.Animations.Pop
	local Duration  = (CustomConfig and CustomConfig.Duration) or (PopConfig and PopConfig.OpenDuration) or 0.25
	local Style     = (CustomConfig and CustomConfig.EasingStyle) or (PopConfig and PopConfig.OpenEasingStyle) or Enum.EasingStyle.Back
	local Direction = (CustomConfig and CustomConfig.EasingDir) or (PopConfig and PopConfig.OpenEasingDir) or Enum.EasingDirection.Out
	local TargetVal = (CustomConfig and CustomConfig.TargetScale) or (PopConfig and PopConfig.TargetScale) or 1
	local InitVal   = (CustomConfig and CustomConfig.InitialScale) or (PopConfig and PopConfig.InitialScale) or 0

	local UiScale = GuiHelper.GetOrCreateScale(GuiObject)
	if not UiScale then return nil end

	GuiHelper.CancelTween(UiScale)

	-- Nếu GUI đang bị ẩn, reset về scale ban đầu trước khi bung ra
	if not GuiObject.Visible then
		UiScale.Scale = InitVal
		GuiObject.Visible = true
	end

	local TweenInfoObj = TweenInfo.new(Duration, Style, Direction)
	local Tween = TweenService:Create(UiScale, TweenInfoObj, { Scale = TargetVal })
	_activeTweens[UiScale] = Tween

	Tween.Completed:Connect(function(PlaybackState)
		if _activeTweens[UiScale] == Tween then
			_activeTweens[UiScale] = nil
		end
		if PlaybackState == Enum.PlaybackState.Completed and OnComplete then
			OnComplete()
		end
	end)

	Tween:Play()
	return Tween
end

--- Đóng một cửa sổ GUI kèm hiệu ứng thu nhỏ về 0
--- @param GuiObject GuiObject Frame hoặc container cần đóng
--- @param CustomConfig table? { Duration: number?, EasingStyle: Enum.EasingStyle?, EasingDir: Enum.EasingDirection?, TargetScale: number? }
--- @param OnComplete ( () -> () )? Callback chạy khi animation đóng hoàn tất
--- @return Tween?
function GuiHelper.PopClose(GuiObject, CustomConfig, OnComplete)
	if not GuiObject or not GuiObject:IsA("GuiObject") then return nil end
	if not GuiObject.Visible then
		if OnComplete then OnComplete() end
		return nil
	end

	local PopConfig = GuiConfig.Animations and GuiConfig.Animations.Pop
	local Duration  = (CustomConfig and CustomConfig.Duration) or (PopConfig and PopConfig.CloseDuration) or 0.2
	local Style     = (CustomConfig and CustomConfig.EasingStyle) or (PopConfig and PopConfig.CloseEasingStyle) or Enum.EasingStyle.Quad
	local Direction = (CustomConfig and CustomConfig.EasingDir) or (PopConfig and PopConfig.CloseEasingDir) or Enum.EasingDirection.In
	local TargetVal = (CustomConfig and CustomConfig.TargetScale) or (PopConfig and PopConfig.InitialScale) or 0

	local UiScale = GuiHelper.GetOrCreateScale(GuiObject)
	if not UiScale then
		GuiObject.Visible = false
		if OnComplete then OnComplete() end
		return nil
	end

	GuiHelper.CancelTween(UiScale)

	local TweenInfoObj = TweenInfo.new(Duration, Style, Direction)
	local Tween = TweenService:Create(UiScale, TweenInfoObj, { Scale = TargetVal })
	_activeTweens[UiScale] = Tween

	Tween.Completed:Connect(function(PlaybackState)
		if _activeTweens[UiScale] == Tween then
			_activeTweens[UiScale] = nil
		end
		if PlaybackState == Enum.PlaybackState.Completed then
			GuiObject.Visible = false
			-- Đặt lại scale về 1 cho trường hợp mở trực tiếp không qua animation
			UiScale.Scale = 1
			if OnComplete then
				OnComplete()
			end
		end
	end)

	Tween:Play()
	return Tween
end

--- Gắn hiệu ứng phóng to/thu nhỏ (Hover & Press) cho toàn bộ Button hoặc phần tử chỉ định
--- @param Button GuiButton Nút nhận sự kiện chuột/bấm
--- @param TargetElement GuiObject? Phần tử sẽ được scale (mặc định là chính Button)
--- @param CustomScaleConfig table? { Duration: number?, HoverScale: number?, PressScale: number?, DefaultScale: number? }
function GuiHelper.BindButtonScale(Button, TargetElement, CustomScaleConfig)
	if not Button or not Button:IsA("GuiButton") then return end

	local Target = TargetElement or Button
	if not Target or not Target:IsA("GuiObject") then return end

	local ButtonName   = (Target.Name ~= "" and Target.Name) or Button.Name
	local ButtonConfig = GuiHelper.GetButtonScaleConfig(ButtonName)

	local Duration     = (CustomScaleConfig and CustomScaleConfig.Duration) or ButtonConfig.Duration
	local Style        = (CustomScaleConfig and CustomScaleConfig.EasingStyle) or ButtonConfig.EasingStyle
	local Direction    = (CustomScaleConfig and CustomScaleConfig.EasingDir) or ButtonConfig.EasingDir
	local DefaultScale = (CustomScaleConfig and CustomScaleConfig.DefaultScale) or ButtonConfig.DefaultScale
	local HoverScale   = (CustomScaleConfig and CustomScaleConfig.HoverScale) or ButtonConfig.HoverScale
	local PressScale   = (CustomScaleConfig and CustomScaleConfig.PressScale) or ButtonConfig.PressScale

	local IsHovered = false

	Button.MouseEnter:Connect(function()
		IsHovered = true
		GuiHelper.TweenScale(Target, HoverScale, Duration, Style, Direction)
	end)

	Button.MouseLeave:Connect(function()
		IsHovered = false
		GuiHelper.TweenScale(Target, DefaultScale, Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	Button.MouseButton1Down:Connect(function()
		GuiHelper.TweenScale(Target, PressScale, Duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	Button.MouseButton1Up:Connect(function()
		local NextScale = IsHovered and HoverScale or DefaultScale
		GuiHelper.TweenScale(Target, NextScale, Duration, Style, Direction)
	end)

	-- Hỗ trợ cho Gamepad / Keyboard selection
	Button.SelectionGained:Connect(function()
		IsHovered = true
		GuiHelper.TweenScale(Target, HoverScale, Duration, Style, Direction)
	end)

	Button.SelectionLost:Connect(function()
		IsHovered = false
		GuiHelper.TweenScale(Target, DefaultScale, Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)
end


return GuiHelper
