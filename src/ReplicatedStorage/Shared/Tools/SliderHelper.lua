-- SliderHelper.lua
-- Module tiện ích điều khiển thanh trượt (Stepped Slider Component)
-- Quản lý tương tác chuột / cảm ứng (Drag & Click), snap vào 11 vạch Ticks (0% - 100%)
-- Tự động tối ưu toạ độ, phát SFX Tick và tách biệt callback Real-time vs OnDragEnded

local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiConfig     = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiAnimConfig = require(ReplicatedStorage.Shared.Config.GuiAnimConfig)
local AudioConfig   = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiHelper     = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local AudioHelper   = require(ReplicatedStorage.Shared.Tools.AudioHelper)

local SliderHelper = {}
SliderHelper.__index = SliderHelper

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Phát âm thanh tick khi núm trượt nhảy sang nấc mới
local function PlayTickSound()
	local TickEntry = AudioConfig.Setting and AudioConfig.Setting.SliderTick
	if TickEntry then
		AudioHelper.PlayGuiSound(TickEntry)
	end
end

-- =========================================================
-- CONSTRUCTOR & METHODS
-- =========================================================

--- Tạo một đối tượng điều khiển Slider
--- @param SlideBar Frame -- Khung chứa thanh trượt (chứa Track, TicksContainer, Knob, SlideButton)
--- @param Options table? -- { InitialValue = 100, StepCount = 10, OnValueChanged = fn, OnDragEnded = fn }
--- @return table
function SliderHelper.Create(SlideBar, Options)
	if not SlideBar then return nil end

	Options = Options or {}

	local Self = setmetatable({}, SliderHelper)

	Self.SlideBar        = SlideBar
	Self.StepCount       = Options.StepCount or 10 -- 10 khoảng = 11 ticks (0% -> 100%)
	Self.TickCount       = Self.StepCount + 1
	Self.OnValueChanged = Options.OnValueChanged
	Self.OnDragEnded    = Options.OnDragEnded
	Self.PlaySound       = (Options.PlayTickSound ~= false)

	-- Tìm các phần tử con theo cấu hình GuiConfig
	Self.Track          = SlideBar:FindFirstChild(GuiConfig.SettingElements.Track)
	Self.TicksContainer = SlideBar:FindFirstChild(GuiConfig.SettingElements.TicksContainer)
	Self.Knob           = SlideBar:FindFirstChild(GuiConfig.SettingElements.Knob)
	Self.SlideButton    = SlideBar:FindFirstChild(GuiConfig.SettingElements.SlideButton) or SlideBar:FindFirstChildWhichIsA("GuiButton")

	-- Cấu hình hoạt ảnh
	Self.AnimConfig = GuiAnimConfig.GetSliderAnimConfig()

	-- Trạng thái runtime
	Self.CurrentStep  = Self.StepCount -- Mặc định là 10 (100%)
	Self.CurrentValue = 100
	Self.IsDragging   = false
	Self.ActiveTween  = nil
	Self.Connections  = {}

	-- Khởi tạo vị trí ban đầu
	local InitialValue = Options.InitialValue
	if InitialValue == nil then InitialValue = 100 end
	Self:SetValue(InitialValue, false)

	-- Defer thêm 1 lần phòng trường hợp GUI vừa mở chưa render layout frame 0
	task.defer(function()
		Self:SetValue(Self.CurrentValue, false)
	end)

	-- Gắn kết nối sự kiện tương tác
	Self:_BindInputEvents()

	return Self
end

--- Tính toán vị trí X tương đối (UDim2) của núm Knob dựa theo StepIndex (0 -> 10)
--- Luôn sử dụng tỷ lệ toán học tuyến tính (0.0 -> 1.0) kết hợp AnchorPoint (0.5, 0.5)
--- để núm luôn căn tâm chính xác 100% vào vạch chia Ticks tương ứng
--- @param StepIndex number
--- @return UDim2
function SliderHelper:CalculateKnobPosition(StepIndex)
	local Ratio = math.clamp(StepIndex / self.StepCount, 0, 1)
	return UDim2.new(Ratio, 0, 0.5, 0)
end

--- Cập nhật giao diện vị trí của núm Knob
--- @param StepIndex number
--- @param Animate boolean
function SliderHelper:_UpdateKnobVisual(StepIndex, Animate)
	if not self.Knob then return end

	-- Đảm bảo AnchorPoint là tâm (0.5, 0.5) để núm khớp chính xác giữa vạch Tick
	self.Knob.AnchorPoint = Vector2.new(0.5, 0.5)

	local TargetPos = self:CalculateKnobPosition(StepIndex)

	if self.ActiveTween then
		self.ActiveTween:Cancel()
		self.ActiveTween = nil
	end

	if Animate and self.AnimConfig.Duration > 0 then
		local TweenInfoObj = TweenInfo.new(
			self.AnimConfig.Duration,
			self.AnimConfig.EasingStyle,
			self.AnimConfig.EasingDir
		)
		self.ActiveTween = TweenService:Create(self.Knob, TweenInfoObj, { Position = TargetPos })
		self.ActiveTween:Play()
	else
		self.Knob.Position = TargetPos
	end
end

--- Chuyển đổi toạ độ chuột / chạm màn hình sang StepIndex (0 -> 10)
--- @param InputPosition Vector3 | Vector2
--- @return number
function SliderHelper:_ResolveStepFromInput(InputPosition)
	local TargetObject = self.SlideButton or self.SlideBar
	if not TargetObject then return self.CurrentStep end

	local BarPos  = TargetObject.AbsolutePosition.X
	local BarSize = TargetObject.AbsoluteSize.X

	if BarSize <= 0 then return self.CurrentStep end

	-- Tính toán tỷ lệ vị trí chuột trên thanh
	local RelativeX = InputPosition.X - BarPos
	local Ratio = math.clamp(RelativeX / BarSize, 0, 1)

	-- Làm tròn đến bước gần nhất (0 -> StepCount)
	local StepIndex = math.clamp(math.round(Ratio * self.StepCount), 0, self.StepCount)
	return StepIndex
end

--- Áp dụng bước mới khi người chơi tương tác
--- @param StepIndex number
--- @param IsUserInput boolean
function SliderHelper:_ApplyStep(StepIndex, IsUserInput)
	if StepIndex == self.CurrentStep and IsUserInput then
		return
	end

	local OldStep = self.CurrentStep
	self.CurrentStep = StepIndex
	self.CurrentValue = math.clamp(math.round((StepIndex / self.StepCount) * 100), 0, 100)

	self:_UpdateKnobVisual(StepIndex, IsUserInput)

	if IsUserInput and self.PlaySound and OldStep ~= StepIndex then
		PlayTickSound()
	end

	if self.OnValueChanged then
		self.OnValueChanged(self.CurrentValue)
	end
end

--- Gắn các sự kiện chuột và cảm ứng toàn diện
function SliderHelper:_BindInputEvents()
	local SlideButton = self.SlideButton
	local Knob        = self.Knob
	local SlideBar    = self.SlideBar

	local function StartInteraction(Input)
		self.IsDragging = true
		local StepIndex = self:_ResolveStepFromInput(Input.Position)
		self:_ApplyStep(StepIndex, true)
	end

	local function EndInteraction()
		if not self.IsDragging then return end
		self.IsDragging = false
		if self.OnDragEnded then
			self.OnDragEnded(self.CurrentValue)
		end
	end

	-- 1. Bắt đầu tương tác trên SlideButton
	if SlideButton then
		table.insert(self.Connections, SlideButton.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				StartInteraction(Input)
			end
		end))
		table.insert(self.Connections, SlideButton.MouseButton1Down:Connect(function()
			self.IsDragging = true
			local MouseLoc = UserInputService:GetMouseLocation()
			local StepIndex = self:_ResolveStepFromInput(MouseLoc)
			self:_ApplyStep(StepIndex, true)
		end))
	end

	-- 2. Hỗ trợ bắt tương tác nếu click trực tiếp lên Knob hoặc SlideBar
	if Knob and Knob:IsA("GuiObject") then
		table.insert(self.Connections, Knob.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				StartInteraction(Input)
			end
		end))
	end

	if SlideBar and SlideBar:IsA("GuiObject") then
		table.insert(self.Connections, SlideBar.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				StartInteraction(Input)
			end
		end))
	end

	-- 3. Di chuyển chuột / ngón tay trên toàn màn hình khi đang Drag
	table.insert(self.Connections, UserInputService.InputChanged:Connect(function(Input)
		if not self.IsDragging then return end

		if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
			local StepIndex = self:_ResolveStepFromInput(Input.Position)
			self:_ApplyStep(StepIndex, true)
		end
	end))

	-- 4. Kết thúc tương tác (thả chuột hoặc nhấc ngón tay)
	table.insert(self.Connections, UserInputService.InputEnded:Connect(function(Input)
		if not self.IsDragging then return end

		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			EndInteraction()
		end
	end))

	if SlideButton then
		table.insert(self.Connections, SlideButton.MouseButton1Up:Connect(function()
			EndInteraction()
		end))
	end
end

--- Gán giá trị cụ thể cho Slider (0 -> 100)
--- @param Value number -- Giá trị từ 0 đến 100
--- @param Animate boolean? -- Có chạy tween núm không
function SliderHelper:SetValue(Value, Animate)
	if type(Value) ~= "number" then Value = 100 end
	Value = math.clamp(Value, 0, 100)

	local StepIndex = math.clamp(math.round((Value / 100) * self.StepCount), 0, self.StepCount)
	self.CurrentStep = StepIndex
	self.CurrentValue = math.clamp(math.round((StepIndex / self.StepCount) * 100), 0, 100)

	self:_UpdateKnobVisual(StepIndex, Animate == true)
end

--- Lấy giá trị hiện tại của Slider (0 -> 100)
--- @return number
function SliderHelper:GetValue()
	return self.CurrentValue
end

--- Dọn dẹp và hủy binding của Slider
function SliderHelper:Destroy()
	self.IsDragging = false

	if self.ActiveTween then
		self.ActiveTween:Cancel()
		self.ActiveTween = nil
	end

	for _, Connection in ipairs(self.Connections) do
		if Connection and Connection.Connected then
			Connection:Disconnect()
		end
	end
	table.clear(self.Connections)
end

return SliderHelper
