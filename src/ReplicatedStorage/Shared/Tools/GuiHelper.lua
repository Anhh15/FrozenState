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

local _ActiveTweens = {}

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
	local CurrentTween = _ActiveTweens[Target]
	if CurrentTween then
		CurrentTween:Cancel()
		_ActiveTweens[Target] = nil
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
	_ActiveTweens[UiScale] = Tween

	Tween.Completed:Connect(function(PlaybackState)
		if _ActiveTweens[UiScale] == Tween then
			_ActiveTweens[UiScale] = nil
		end
		if PlaybackState == Enum.PlaybackState.Completed and OnComplete then
			OnComplete()
		end
	end)

	Tween:Play()
	return Tween
end

--- Lấy cấu hình Pop của Frame dựa theo tên (kết hợp Default và Overrides)
--- @param FrameName string?
--- @return table
function GuiHelper.GetPopConfig(FrameName)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.Pop
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or AnimConfig or {}
	local OverrideCfg = (FrameName and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[FrameName]) or {}

	return {
		OpenDuration     = OverrideCfg.OpenDuration     or DefaultCfg.OpenDuration     or 0.25,
		CloseDuration    = OverrideCfg.CloseDuration    or DefaultCfg.CloseDuration    or 0.2,
		OpenEasingStyle  = OverrideCfg.OpenEasingStyle  or DefaultCfg.OpenEasingStyle  or Enum.EasingStyle.Back,
		OpenEasingDir    = OverrideCfg.OpenEasingDir    or DefaultCfg.OpenEasingDir    or Enum.EasingDirection.Out,
		CloseEasingStyle = OverrideCfg.CloseEasingStyle or DefaultCfg.CloseEasingStyle or Enum.EasingStyle.Quad,
		CloseEasingDir   = OverrideCfg.CloseEasingDir   or DefaultCfg.CloseEasingDir   or Enum.EasingDirection.In,
		InitialScale     = OverrideCfg.InitialScale     or DefaultCfg.InitialScale     or 0,
		TargetScale      = OverrideCfg.TargetScale      or DefaultCfg.TargetScale      or 1,
	}
end

--- Mở một cửa sổ GUI kèm hiệu ứng Zoom Pop nảy nhẹ
--- @param GuiObject GuiObject Frame hoặc container cần mở
--- @param CustomConfig table? { Duration: number?, EasingStyle: Enum.EasingStyle?, EasingDir: Enum.EasingDirection?, TargetScale: number?, InitialScale: number? }
--- @param OnComplete ( () -> () )? Callback chạy khi animation mở hoàn tất
--- @return Tween?
function GuiHelper.PopOpen(GuiObject, CustomConfig, OnComplete)
	if not GuiObject or not GuiObject:IsA("GuiObject") then return nil end

	local PopConfig = GuiHelper.GetPopConfig(GuiObject.Name)
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
	_ActiveTweens[UiScale] = Tween

	Tween.Completed:Connect(function(PlaybackState)
		if _ActiveTweens[UiScale] == Tween then
			_ActiveTweens[UiScale] = nil
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

	local PopConfig = GuiHelper.GetPopConfig(GuiObject.Name)
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
	_ActiveTweens[UiScale] = Tween

	Tween.Completed:Connect(function(PlaybackState)
		if _ActiveTweens[UiScale] == Tween then
			_ActiveTweens[UiScale] = nil
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

--- Tìm tên menu/container từ cây phân cấp tổ tiên (Ancestor) của GuiObject
--- @param Object Instance
--- @return string?
local function ResolveAncestorMenuName(Object)
	if not Object then return nil end
	local Overrides  = GuiConfig.Animations and GuiConfig.Animations.Stagger and GuiConfig.Animations.Stagger.Overrides
	local MenuFrames = GuiConfig.MenuFrames or {}
	local Curr       = Object.Parent
	while Curr and Curr.Parent and not Curr:IsA("ScreenGui") do
		-- 1. Ưu tiên nếu tên trùng với MenuFrames ("Inventory", "Shop", "Quest", "Profile", "Spectate")
		if MenuFrames[Curr.Name] then
			return Curr.Name
		end
		-- 2. Hoặc trùng với bất kỳ key nào đã đăng ký trong Overrides
		if Overrides and Overrides[Curr.Name] then
			return Curr.Name
		end
		Curr = Curr.Parent
	end
	return nil
end

--- Lấy cấu hình Stagger của danh sách (kết hợp Default và Overrides)
--- @param Identifier string? Tên menu hoặc container (vd: "Inventory", "Shop", "Quest")
--- @return table
function GuiHelper.GetStaggerConfig(Identifier)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.Stagger
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or AnimConfig or {}
	local OverrideCfg = (Identifier and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[Identifier]) or {}

	return {
		DelayStep    = OverrideCfg.DelayStep    or DefaultCfg.DelayStep    or 0.03,
		Duration     = OverrideCfg.Duration     or DefaultCfg.Duration     or 0.2,
		EasingStyle  = OverrideCfg.EasingStyle  or DefaultCfg.EasingStyle  or Enum.EasingStyle.Back,
		EasingDir    = OverrideCfg.EasingDir    or DefaultCfg.EasingDir    or Enum.EasingDirection.Out,
		InitialScale = OverrideCfg.InitialScale or DefaultCfg.InitialScale or 0.0,
		TargetScale  = OverrideCfg.TargetScale  or DefaultCfg.TargetScale  or 1.0,
		ItemSoundId  = OverrideCfg.ItemSoundId  or DefaultCfg.ItemSoundId,
	}
end

--- Hiển thị danh sách phần tử (Template cards/items) xuất hiện lần lượt với hiệu ứng Pop nảy nhẹ
--- Hỗ trợ overload tham số linh hoạt:
---   StaggerPopOpen(ItemsList)
---   StaggerPopOpen(ItemsList, "Inventory")
---   StaggerPopOpen(ItemsList, CustomConfig)
---   StaggerPopOpen(ItemsList, OnComplete)
---   StaggerPopOpen(ItemsList, CustomConfig, OnComplete, Identifier)
--- @param ItemsList table Danh sách GuiObject cần hiển thị
--- @param CustomConfig (table | string | (() -> ()))? Cấu hình tùy chỉnh, hoặc Identifier (string), hoặc Callback (function)
--- @param OnComplete ( (() -> ()) | string )? Callback khi toàn bộ sequence hoàn thành hoặc Identifier (string)
--- @param Identifier string? Tùy chọn tên menu/danh sách để tra cứu Overrides (vd: "Inventory", "Shop", "Quest")
--- @return thread? Thread điều phối animation
function GuiHelper.StaggerPopOpen(ItemsList, CustomConfig, OnComplete, Identifier)
	if not ItemsList or #ItemsList == 0 then
		if typeof(CustomConfig) == "function" then
			CustomConfig()
		elseif typeof(OnComplete) == "function" then
			OnComplete()
		end
		return nil
	end

	-- Xử lý Overload tham số
	local ResolvedConfig   = nil
	local ResolvedCallback = nil
	local ResolvedId       = Identifier

	if typeof(CustomConfig) == "string" then
		ResolvedId = CustomConfig
	elseif typeof(CustomConfig) == "function" then
		ResolvedCallback = CustomConfig
	elseif typeof(CustomConfig) == "table" then
		ResolvedConfig = CustomConfig
	end

	if typeof(OnComplete) == "string" then
		ResolvedId = OnComplete
	elseif typeof(OnComplete) == "function" then
		ResolvedCallback = OnComplete
	end

	-- Dò ngược cây phân cấp tổ tiên nếu chưa có Identifier
	if not ResolvedId and ItemsList[1] then
		ResolvedId = ResolveAncestorMenuName(ItemsList[1]) or (ItemsList[1].Parent and ItemsList[1].Parent.Name)
	end

	local StaggerConfig = GuiHelper.GetStaggerConfig(ResolvedId)
	local Cfg           = ResolvedConfig or {}
	local DelayStep     = Cfg.DelayStep    or StaggerConfig.DelayStep    or 0.03
	local Duration      = Cfg.Duration     or StaggerConfig.Duration     or 0.2
	local Style         = Cfg.EasingStyle  or StaggerConfig.EasingStyle  or Enum.EasingStyle.Back
	local Direction     = Cfg.EasingDir    or StaggerConfig.EasingDir    or Enum.EasingDirection.Out
	local TargetVal     = Cfg.TargetScale  or StaggerConfig.TargetScale  or 1.0
	local InitVal       = Cfg.InitialScale or StaggerConfig.InitialScale or 0.0
	local ItemSoundId   = Cfg.ItemSoundId  or StaggerConfig.ItemSoundId

	-- Khởi tạo UIScale ban đầu về InitVal cho tất cả phần tử
	for _, Item in ipairs(ItemsList) do
		if Item and Item:IsA("GuiObject") then
			local Scale = GuiHelper.GetOrCreateScale(Item)
			if Scale then
				GuiHelper.CancelTween(Scale)
				Scale.Scale = InitVal
				Item.Visible = true
			end
		end
	end

	local TotalItems     = #ItemsList
	local CompletedCount = 0

	local StaggerThread = task.spawn(function()
		for Index, Item in ipairs(ItemsList) do
			if not Item or not Item.Parent or not Item:IsA("GuiObject") then
				CompletedCount += 1
				if CompletedCount >= TotalItems and ResolvedCallback then
					ResolvedCallback()
				end
				continue
			end

			local UiScale = GuiHelper.GetOrCreateScale(Item)
			if UiScale then
				GuiHelper.CancelTween(UiScale)

				if ItemSoundId then
					AudioHelper.PlayGuiSound(ItemSoundId)
				end

				local TweenInfoObj = TweenInfo.new(Duration, Style, Direction)
				local Tween = TweenService:Create(UiScale, TweenInfoObj, { Scale = TargetVal })
				_ActiveTweens[UiScale] = Tween

				Tween.Completed:Connect(function(PlaybackState)
					if _ActiveTweens[UiScale] == Tween then
						_ActiveTweens[UiScale] = nil
					end
					CompletedCount += 1
					if CompletedCount >= TotalItems and ResolvedCallback then
						ResolvedCallback()
					end
				end)

				Tween:Play()
			else
				CompletedCount += 1
				if CompletedCount >= TotalItems and ResolvedCallback then
					ResolvedCallback()
				end
			end

			if Index < TotalItems and DelayStep > 0 then
				task.wait(DelayStep)
			end
		end
	end)

	return StaggerThread
end

--- Lấy cấu hình Animation ItemReward (kết hợp Default và Overrides theo ChestId)
--- @param ChestId string?
--- @return table
function GuiHelper.GetItemRewardAnimConfig(ChestId)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.ItemReward
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or {}
	local OverrideCfg = (ChestId and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[ChestId]) or {}

	return {
		ChestZoomDuration   = OverrideCfg.ChestZoomDuration   or DefaultCfg.ChestZoomDuration   or 0.4,
		RotationSpeed       = OverrideCfg.RotationSpeed       or DefaultCfg.RotationSpeed       or 36,
		ChestShrinkDuration = OverrideCfg.ChestShrinkDuration or DefaultCfg.ChestShrinkDuration or 0.15,
		ChestExpandDuration = OverrideCfg.ChestExpandDuration or DefaultCfg.ChestExpandDuration or 0.25,
		FlashDuration       = OverrideCfg.FlashDuration       or DefaultCfg.FlashDuration       or 0.4,
		FadeDuration        = OverrideCfg.FadeDuration        or DefaultCfg.FadeDuration        or 0.4,
		ZoomEasingStyle     = OverrideCfg.ZoomEasingStyle     or DefaultCfg.ZoomEasingStyle     or Enum.EasingStyle.Back,
		ZoomEasingDir       = OverrideCfg.ZoomEasingDir       or DefaultCfg.ZoomEasingDir       or Enum.EasingDirection.Out,
		ShrinkEasingStyle   = OverrideCfg.ShrinkEasingStyle   or DefaultCfg.ShrinkEasingStyle   or Enum.EasingStyle.Quad,
		ShrinkEasingDir     = OverrideCfg.ShrinkEasingDir     or DefaultCfg.ShrinkEasingDir     or Enum.EasingDirection.Out,
		ExpandEasingStyle   = OverrideCfg.ExpandEasingStyle   or DefaultCfg.ExpandEasingStyle   or Enum.EasingStyle.Back,
		ExpandEasingDir     = OverrideCfg.ExpandEasingDir     or DefaultCfg.ExpandEasingDir     or Enum.EasingDirection.Out,
	}
end

--- Lấy cấu hình Animation ModeAnnouncement (kết hợp Default và Overrides theo ModeKey)
--- @param ModeKey string?
--- @return table
function GuiHelper.GetModeAnnouncementAnimConfig(ModeKey)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.ModeAnnouncement
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or {}
	local OverrideCfg = (ModeKey and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[ModeKey]) or {}

	return {
		DisplayDuration = OverrideCfg.DisplayDuration or DefaultCfg.DisplayDuration or 4.0,
		FadeInDuration  = OverrideCfg.FadeInDuration  or DefaultCfg.FadeInDuration  or 0.5,
		EasingStyle     = OverrideCfg.EasingStyle     or DefaultCfg.EasingStyle     or Enum.EasingStyle.Quad,
		EasingDir       = OverrideCfg.EasingDir       or DefaultCfg.EasingDir       or Enum.EasingDirection.Out,
	}
end

--- Lấy cấu hình Animation RoundLoadingScreen (kết hợp Default và Overrides theo ModeKey)
--- @param ModeKey string?
--- @return table
function GuiHelper.GetRoundLoadingAnimConfig(ModeKey)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.RoundLoadingScreen
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or {}
	local OverrideCfg = (ModeKey and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[ModeKey]) or {}

	return {
		FadeInDuration     = OverrideCfg.FadeInDuration     or DefaultCfg.FadeInDuration     or 1.0,
		HoldDuration       = OverrideCfg.HoldDuration       or DefaultCfg.HoldDuration       or 1.0,
		FadeOutDuration    = OverrideCfg.FadeOutDuration    or DefaultCfg.FadeOutDuration    or 0.5,
		FadeInEasingStyle  = OverrideCfg.FadeInEasingStyle  or DefaultCfg.FadeInEasingStyle  or Enum.EasingStyle.Quad,
		FadeInEasingDir    = OverrideCfg.FadeInEasingDir    or DefaultCfg.FadeInEasingDir    or Enum.EasingDirection.Out,
		FadeOutEasingStyle = OverrideCfg.FadeOutEasingStyle or DefaultCfg.FadeOutEasingStyle or Enum.EasingStyle.Quad,
		FadeOutEasingDir   = OverrideCfg.FadeOutEasingDir   or DefaultCfg.FadeOutEasingDir   or Enum.EasingDirection.In,
	}
end

--- Lấy cấu hình Animation Accolades (kết hợp Default và Overrides theo AccoladeType)
--- @param AccoladeType string?
--- @return table
function GuiHelper.GetAccoladesAnimConfig(AccoladeType)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.Accolades
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or {}
	local OverrideCfg = (AccoladeType and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[AccoladeType]) or {}

	return {
		OpenDuration     = OverrideCfg.OpenDuration     or DefaultCfg.OpenDuration     or 0.25,
		CloseDuration    = OverrideCfg.CloseDuration    or DefaultCfg.CloseDuration    or 0.2,
		DisplayDuration  = OverrideCfg.DisplayDuration  or DefaultCfg.DisplayDuration  or 1.5,
		OpenEasingStyle  = OverrideCfg.OpenEasingStyle  or DefaultCfg.OpenEasingStyle  or Enum.EasingStyle.Back,
		OpenEasingDir    = OverrideCfg.OpenEasingDir    or DefaultCfg.OpenEasingDir    or Enum.EasingDirection.Out,
		CloseEasingStyle = OverrideCfg.CloseEasingStyle or DefaultCfg.CloseEasingStyle or Enum.EasingStyle.Quad,
		CloseEasingDir   = OverrideCfg.CloseEasingDir   or DefaultCfg.CloseEasingDir   or Enum.EasingDirection.In,
		InitialScale     = OverrideCfg.InitialScale     or DefaultCfg.InitialScale     or 0,
		TargetScale      = OverrideCfg.TargetScale      or DefaultCfg.TargetScale      or 1,
	}
end

--- Lấy cấu hình Animation GameLoadingScreen
--- @return table
function GuiHelper.GetGameLoadingAnimConfig()
	local AnimConfig = GuiConfig.Animations and GuiConfig.Animations.GameLoadingScreen
	local DefaultCfg = (AnimConfig and AnimConfig.Default) or {}

	return {
		DotWaveDuration     = DefaultCfg.DotWaveDuration     or 0.5,
		DotMinScale         = DefaultCfg.DotMinScale         or 1.0,
		DotMaxScale         = DefaultCfg.DotMaxScale         or 1.5,
		DotEasingStyle      = DefaultCfg.DotEasingStyle      or Enum.EasingStyle.Sine,
		DotEasingDir        = DefaultCfg.DotEasingDir        or Enum.EasingDirection.InOut,
		TitleMinScale       = DefaultCfg.TitleMinScale       or 1.0,
		TitleLoadMaxScale   = DefaultCfg.TitleLoadMaxScale   or 1.4,
		TitlePopScale       = DefaultCfg.TitlePopScale       or 1.6,
		Phase1PopDuration   = DefaultCfg.Phase1PopDuration   or 0.35,
		Phase1DotBlinkCount = DefaultCfg.Phase1DotBlinkCount or 2,
		Phase1DotBlinkTime  = DefaultCfg.Phase1DotBlinkTime  or 0.12,
		Phase2Duration      = DefaultCfg.Phase2Duration      or 0.65,
		Phase2EasingStyle   = DefaultCfg.Phase2EasingStyle   or Enum.EasingStyle.Quad,
		Phase2EasingDir     = DefaultCfg.Phase2EasingDir     or Enum.EasingDirection.InOut,
		MinLoadingDuration  = DefaultCfg.MinLoadingDuration  or 2.5,
		SafetyTimeout       = DefaultCfg.SafetyTimeout       or 10,
		ProgressLerpSpeed   = DefaultCfg.ProgressLerpSpeed   or 8,
	}
end

--- Lấy cấu hình Animation GameOverAnnouncement (kết hợp Default và Overrides)
--- @return table
function GuiHelper.GetGameOverAnnouncementAnimConfig()
	local AnimConfig = GuiConfig.Animations and GuiConfig.Animations.GameOverAnnouncement
	local DefaultCfg = (AnimConfig and AnimConfig.Default) or {}

	return {
		DisplayDuration       = DefaultCfg.DisplayDuration       or 3.2,
		SplitDuration         = DefaultCfg.SplitDuration         or 0.4,
		FlyInDuration         = DefaultCfg.FlyInDuration         or 0.35,
		FlyOutDuration        = DefaultCfg.FlyOutDuration        or 0.25,
		CloseDuration         = DefaultCfg.CloseDuration         or 0.3,
		FlyInStartPosYScale   = DefaultCfg.FlyInStartPosYScale   or 2.0,
		FlyOutTargetPosYScale = DefaultCfg.FlyOutTargetPosYScale or -1.0,
		SplitEasingStyle      = DefaultCfg.SplitEasingStyle      or Enum.EasingStyle.Back,
		SplitEasingDir        = DefaultCfg.SplitEasingDir        or Enum.EasingDirection.Out,
		FlyInEasingStyle      = DefaultCfg.FlyInEasingStyle      or Enum.EasingStyle.Back,
		FlyInEasingDir        = DefaultCfg.FlyInEasingDir        or Enum.EasingDirection.Out,
		FlyOutEasingStyle     = DefaultCfg.FlyOutEasingStyle     or Enum.EasingStyle.Quad,
		FlyOutEasingDir       = DefaultCfg.FlyOutEasingDir       or Enum.EasingDirection.In,
		CloseEasingStyle      = DefaultCfg.CloseEasingStyle      or Enum.EasingStyle.Quad,
		CloseEasingDir        = DefaultCfg.CloseEasingDir        or Enum.EasingDirection.In,
	}
end

--- Cắt ngắn chuỗi văn bản nếu vượt quá MaxLength (an toàn với UTF-8), thêm dấu "..."
--- @param Text string
--- @param MaxLength number?
--- @return string
function GuiHelper.TruncateText(Text, MaxLength)
	if not Text or type(Text) ~= "string" then return "" end
	local Limit = MaxLength or (GuiConfig.GameOver and GuiConfig.GameOver.MaxNameLength) or 15

	local CharCount = utf8.len(Text)
	if not CharCount then
		-- Fallback nếu chuỗi không phải UTF-8 hợp lệ
		if #Text > Limit then
			return string.sub(Text, 1, Limit) .. "..."
		end
		return Text
	end

	if CharCount > Limit then
		local ByteEnd = utf8.offset(Text, Limit + 1)
		if ByteEnd then
			return string.sub(Text, 1, ByteEnd - 1) .. "..."
		else
			return string.sub(Text, 1, Limit) .. "..."
		end
	end

	return Text
end

--- Lấy cấu hình hoạt ảnh cho Hotbar (kết hợp Default và Overrides)
--- @param SlotName string? Tùy chọn định danh slot (vd: "Icicle", "Slot1")
--- @return table
function GuiHelper.GetHotbarConfig(SlotName)
	local AnimConfig  = GuiConfig.Animations and GuiConfig.Animations.Hotbar
	local DefaultCfg  = (AnimConfig and AnimConfig.Default) or AnimConfig or {}
	local OverrideCfg = (SlotName and AnimConfig and AnimConfig.Overrides and AnimConfig.Overrides[SlotName]) or {}

	return {
		InactiveScale           = OverrideCfg.InactiveScale           or DefaultCfg.InactiveScale           or 1.0,
		ActiveScale             = OverrideCfg.ActiveScale             or DefaultCfg.ActiveScale             or 1.3,
		ScaleDuration           = OverrideCfg.ScaleDuration           or DefaultCfg.ScaleDuration           or 0.15,
		ScaleEasingStyle        = OverrideCfg.ScaleEasingStyle        or DefaultCfg.ScaleEasingStyle        or Enum.EasingStyle.Back,
		ScaleEasingDir          = OverrideCfg.ScaleEasingDir          or DefaultCfg.ScaleEasingDir          or Enum.EasingDirection.Out,
		InactiveBackgroundTrans = OverrideCfg.InactiveBackgroundTrans or DefaultCfg.InactiveBackgroundTrans or 0.8,
		ActiveBackgroundTrans   = OverrideCfg.ActiveBackgroundTrans   or DefaultCfg.ActiveBackgroundTrans   or 0.4,
		CooldownEasingStyle     = OverrideCfg.CooldownEasingStyle     or DefaultCfg.CooldownEasingStyle     or Enum.EasingStyle.Linear,
		CooldownEasingDir       = OverrideCfg.CooldownEasingDir       or DefaultCfg.CooldownEasingDir       or Enum.EasingDirection.InOut,
	}
end

return GuiHelper
