-- GuiHelper.lua
-- Công cụ hỗ trợ truy xuất và quản lý giao diện (GUI) an toàn cho Client
-- Sử dụng GuiConfig (tên phần tử) và GuiAnimConfig (thông số animation) làm Single Source of Truth

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local GuiConfig     = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiAnimConfig = require(ReplicatedStorage.Shared.Config.GuiAnimConfig)
local AudioConfig   = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AudioHelper   = require(ReplicatedStorage.Shared.Tools.AudioHelper)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _ActiveTweens = {}
local _BoundButtons = {}

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
--- @param AudioEntryOrId table | number | string
--- @param VolumeOverride number?
function GuiHelper.PlayGuiSound(AudioEntryOrId, VolumeOverride)
	return AudioHelper.PlayGuiSound(AudioEntryOrId, VolumeOverride)
end

--- Đánh dấu một GuiObject / GuiButton đã được xử lý bind để AutoBindButtons bỏ qua
--- @param GuiObject GuiObject
function GuiHelper.MarkBound(GuiObject)
	if not GuiObject then return end
	_BoundButtons[GuiObject] = true
end

--- Gán cờ bỏ qua AutoBindButtons cho một Instance hoặc Container (kể cả toàn bộ con cháu)
--- @param Target Instance
--- @param Ignored boolean? -- Mặc định là true
function GuiHelper.SetIgnoreAutoBind(Target, Ignored)
	if not Target then return end
	local Value = (Ignored ~= false)
	local AttrName = (GuiConfig.Attributes and GuiConfig.Attributes.IgnoreAutoBind) or "IgnoreAutoBind"
	Target:SetAttribute(AttrName, Value)
end

--- Kiểm tra xem một GuiButton hoặc tổ tiên của nó có bị loại trừ khỏi AutoBindButtons hay không
--- @param Button Instance
--- @param Container Instance?
--- @return boolean
local function ShouldIgnoreAutoBind(Button, Container)
	if not Button then return true end
	if _BoundButtons[Button] then return true end

	local IgnoreAttr = (GuiConfig.Attributes and GuiConfig.Attributes.IgnoreAutoBind) or "IgnoreAutoBind"
	local AutoBindAttr = (GuiConfig.Attributes and GuiConfig.Attributes.AutoBind) or "AutoBind"

	if Button:GetAttribute(IgnoreAttr) == true or Button:GetAttribute(AutoBindAttr) == false then
		return true
	end

	local Curr = Button.Parent
	while Curr and Curr ~= game and (not Container or Curr ~= Container.Parent) do
		if Curr.Name == "Templates" then
			return true
		end
		if Curr:GetAttribute(IgnoreAttr) == true or Curr:GetAttribute(AutoBindAttr) == false then
			return true
		end
		if Container and Curr == Container then
			break
		end
		Curr = Curr.Parent
	end

	return false
end

--- Gắn hiệu ứng âm thanh (Hover/Click) cho một GuiButton
--- @param Button GuiButton
--- @param ClickEntryOrId (table | number | string)?
--- @param HoverEntryOrId (table | number | string)?
function GuiHelper.BindButtonSound(Button, ClickEntryOrId, HoverEntryOrId)
	if not Button or not Button:IsA("GuiButton") then return end
	_BoundButtons[Button] = true

	local ClickAudio = ClickEntryOrId or AudioConfig.GetGuiAudio("ButtonClick")
	local HoverAudio = HoverEntryOrId or AudioConfig.GetGuiAudio("MouseEnter")

	if HoverAudio then
		Button.MouseEnter:Connect(function()
			GuiHelper.PlayGuiSound(HoverAudio)
		end)
	end

	if ClickAudio then
		Button.MouseButton1Click:Connect(function()
			GuiHelper.PlayGuiSound(ClickAudio)
		end)
	end
end

--- Tự động quét và gắn Scale Animation cùng SFX (Hover & Click) cho toàn bộ GuiButton trong Container
--- Lắng nghe DescendantAdded để tự động hỗ trợ các phần tử sinh ra động
--- @param Container Instance
--- @param Options table? -- { MenuName: string?, EnableScale: boolean?, EnableSound: boolean?, CustomClickEntry: any, CustomHoverEntry: any }
function GuiHelper.AutoBindButtons(Container, Options)
	if not Container then return end

	local Opts = Options or {}
	local MenuName = Opts.MenuName
	local EnableScale = (Opts.EnableScale ~= false)
	local EnableSound = (Opts.EnableSound ~= false)

	local function BindSingleButton(Button)
		if not Button or not Button:IsA("GuiButton") then return end
		if ShouldIgnoreAutoBind(Button, Container) then return end
		_BoundButtons[Button] = true

		-- 1. Gắn Scale Animation nếu được bật
		if EnableScale then
			GuiHelper.BindButtonScale(Button)
		end

		-- 2. Gắn SFX nếu được bật
		if EnableSound then
			local ButtonNameLower = string.lower(Button.Name)
			local ClickEntry = Opts.CustomClickEntry

			if not ClickEntry then
				if string.find(ButtonNameLower, "close") then
					ClickEntry = AudioConfig.GetGuiAudio("CloseButtonClick", MenuName)
				else
					ClickEntry = AudioConfig.GetGuiAudio("ButtonClick", MenuName)
				end
			end

			local HoverEntry = Opts.CustomHoverEntry or AudioConfig.GetGuiAudio("MouseEnter", MenuName)
			GuiHelper.BindButtonSound(Button, ClickEntry, HoverEntry)
		end
	end

	-- Quét các nút hiện có
	if Container:IsA("GuiButton") then
		BindSingleButton(Container)
	end

	for _, Descendant in ipairs(Container:GetDescendants()) do
		if Descendant:IsA("GuiButton") then
			BindSingleButton(Descendant)
		end
	end

	-- Lắng nghe các nút sinh ra động
	Container.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("GuiButton") then
			BindSingleButton(Descendant)
		end
	end)
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

-- =========================================================
-- CONFIG GETTERS (proxy sang GuiAnimConfig)
-- =========================================================

--- Lấy cấu hình Scale của Button dựa theo tên (kết hợp Default và Overrides)
--- @param ButtonName string?
--- @return table
function GuiHelper.GetButtonScaleConfig(ButtonName)
	return GuiAnimConfig.GetButtonScaleConfig(ButtonName)
end

--- Lấy cấu hình Pop của Frame dựa theo tên (kết hợp Default và Overrides)
--- @param FrameName string?
--- @return table
function GuiHelper.GetPopConfig(FrameName)
	return GuiAnimConfig.GetPopConfig(FrameName)
end

--- Lấy cấu hình Stagger của danh sách (kết hợp Default và Overrides)
--- @param Identifier string?
--- @return table
function GuiHelper.GetStaggerConfig(Identifier)
	return GuiAnimConfig.GetStaggerConfig(Identifier)
end

--- Lấy cấu hình Animation ItemReward (kết hợp Default và Overrides theo ChestId)
--- @param ChestId string?
--- @return table
function GuiHelper.GetItemRewardAnimConfig(ChestId)
	return GuiAnimConfig.GetItemRewardAnimConfig(ChestId)
end

--- Lấy cấu hình Animation ModeAnnouncement (kết hợp Default và Overrides theo ModeKey)
--- @param ModeKey string?
--- @return table
function GuiHelper.GetModeAnnouncementAnimConfig(ModeKey)
	return GuiAnimConfig.GetModeAnnouncementAnimConfig(ModeKey)
end

--- Lấy cấu hình Animation RoundLoadingScreen (kết hợp Default và Overrides theo ModeKey)
--- @param ModeKey string?
--- @return table
function GuiHelper.GetRoundLoadingAnimConfig(ModeKey)
	return GuiAnimConfig.GetRoundLoadingAnimConfig(ModeKey)
end

--- Lấy cấu hình Animation Accolades (kết hợp Default và Overrides theo AccoladeType)
--- @param AccoladeType string?
--- @return table
function GuiHelper.GetAccoladesAnimConfig(AccoladeType)
	return GuiAnimConfig.GetAccoladesAnimConfig(AccoladeType)
end

--- Lấy cấu hình Animation GameLoadingScreen (kết hợp Default và Overrides theo VariantKey)
--- @param VariantKey string?
--- @return table
function GuiHelper.GetGameLoadingAnimConfig(VariantKey)
	return GuiAnimConfig.GetGameLoadingAnimConfig(VariantKey)
end

--- Lấy cấu hình Animation GameOverAnnouncement (kết hợp Default và Overrides theo VariantKey)
--- @param VariantKey string?
--- @return table
function GuiHelper.GetGameOverAnnouncementAnimConfig(VariantKey)
	return GuiAnimConfig.GetGameOverAnnouncementAnimConfig(VariantKey)
end

--- Lấy cấu hình hoạt ảnh cho Hotbar (kết hợp Default và Overrides)
--- @param SlotName string?
--- @return table
function GuiHelper.GetHotbarConfig(SlotName)
	return GuiAnimConfig.GetHotbarConfig(SlotName)
end

-- =========================================================
-- TWEEN HELPERS
-- =========================================================

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

	local Cfg           = GuiAnimConfig.GetButtonScaleConfig(TargetObject.Name)
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

--- Mở một cửa sổ GUI kèm hiệu ứng Zoom Pop nảy nhẹ
--- @param GuiObject GuiObject Frame hoặc container cần mở
--- @param CustomConfig table? { Duration: number?, EasingStyle: Enum.EasingStyle?, EasingDir: Enum.EasingDirection?, TargetScale: number?, InitialScale: number? }
--- @param OnComplete ( () -> () )? Callback chạy khi animation mở hoàn tất
--- @return Tween?
function GuiHelper.PopOpen(GuiObject, CustomConfig, OnComplete)
	if not GuiObject or not GuiObject:IsA("GuiObject") then return nil end

	local PopConfig = GuiAnimConfig.GetPopConfig(GuiObject.Name)
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

	local PopConfig = GuiAnimConfig.GetPopConfig(GuiObject.Name)
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
	_BoundButtons[Button] = true

	local Target = TargetElement or Button
	if not Target or not Target:IsA("GuiObject") then return end

	local ButtonName   = (Target.Name ~= "" and Target.Name) or Button.Name
	local ButtonConfig = GuiAnimConfig.GetButtonScaleConfig(ButtonName)

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
	local StaggerOverrides = GuiAnimConfig.Animations and GuiAnimConfig.Animations.Stagger and GuiAnimConfig.Animations.Stagger.Overrides
	local MenuFrames       = GuiConfig.MenuFrames or {}
	local Curr             = Object.Parent
	while Curr and Curr.Parent and not Curr:IsA("ScreenGui") do
		-- 1. Ưu tiên nếu tên trùng với MenuFrames ("Inventory", "Shop", "Quest", "Profile", "Spectate")
		if MenuFrames[Curr.Name] then
			return Curr.Name
		end
		-- 2. Hoặc trùng với bất kỳ key nào đã đăng ký trong Overrides
		if StaggerOverrides and StaggerOverrides[Curr.Name] then
			return Curr.Name
		end
		Curr = Curr.Parent
	end
	return nil
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

	local StaggerConfig = GuiAnimConfig.GetStaggerConfig(ResolvedId)
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

--- Cắt ngắn chuỗi văn bản nếu vượt quá MaxLength (an toàn với UTF-8), thêm dấu "..."
--- @param Text string
--- @param MaxLength number?
--- @return string
function GuiHelper.TruncateText(Text, MaxLength)
	if not Text or type(Text) ~= "string" then return "" end
	local Limit = MaxLength or GuiAnimConfig.GameOver.MaxNameLength or 15

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

return GuiHelper
