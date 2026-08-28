-- GameLoadingController.lua (ModuleScript)
-- Quản lý màn hình khởi động game ban đầu (GameLoadingScreen)
-- Bao gồm:
--   1. Dots: Sóng gối đầu tuần hoàn (Staggered Wave) bằng UIScale
--   2. Title: Nạp tiến độ rót nước bằng UIGradient + Scale động 1.0 -> 1.4
--   3. Preload Engine: Nạp trước toàn diện Audio, Animation, 3D Assets, GUI Templates, Core Textures
--   4. Pha 1 & Pha 2 Hoàn tất: Pop scale 1.6, nhấp nháy Dots, trượt rèm đôi (Split Curtain) mở Lobby
--   5. Safety Handshake: Nút SkipButton + Timeout 10s + Gửi RemoteEvent FinishGameLoading

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ContentProvider   = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AnimationConfig   = require(ReplicatedStorage.Shared.Config.AnimationConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- STATE
-- =========================================================

local _IsLoadingCompleted = false  -- Cờ hoàn thành toàn bộ loading
local _IsPhase1Triggered  = false  -- Cờ tránh trigger pha 1 lặp lại
local _AssetProgress      = 0.0    -- Tiến độ nạp asset thực tế từ PreloadAsync (0.0 -> 1.0)
local _ActualProgress     = 0.0    -- Tiến độ tổng hợp kết hợp cổng thời gian MinLoadingDuration (0.0 -> 1.0)
local _VisualProgress     = 0.0    -- Tiến độ hiển thị mượt mà trên UI (0.0 -> 1.0)

local _RenderConnection   = nil    -- RenderStepped connection cho UI update & Wave
local _WaveStartTime      = 0.0    -- Thời điểm bắt đầu hoạt ảnh Wave
local _LoadStartTime      = 0.0    -- Thời điểm bắt đầu nạp (dùng cho cổng thời gian tối thiểu)
local _IsWaveActive       = true   -- Cờ kiểm soát vòng lặp sóng Dot

local _FinishEvent        = nil    -- RemoteEvent "FinishGameLoading"

-- =========================================================
-- RESOLVER GUI DYNAMIC
-- =========================================================

--- Lấy tham chiếu an toàn đến toàn bộ phần tử trong GameLoadingScreen
--- @return table?
local function ResolveElements()
	local GuiName = GuiConfig.ScreenGuis.GameLoadingScreen or "GameLoadingScreen"
	local ScreenGui = PlayerGui:FindFirstChild(GuiName) or PlayerGui:WaitForChild(GuiName, 5)
	if not ScreenGui then return nil end

	ScreenGui.ResetOnSpawn = false
	ScreenGui.Enabled = true

	local Elements = GuiConfig.GameLoadingScreenElements
	local ScreenFrameName = (Elements and Elements.ScreenFrame) or "GameLoadingScreen"
	local ScreenFrame = ScreenGui:FindFirstChild(ScreenFrameName) or ScreenGui:FindFirstChildOfClass("Frame")
	if not ScreenFrame then return nil end

	ScreenFrame.Visible = true

	-- Upper Container & Children (Hỗ trợ fallback nếu có typo tên)
	local UpperName = (Elements and Elements.UpperContainer) or "UpperContainer"
	local UpperContainer = ScreenFrame:FindFirstChild(UpperName) or ScreenFrame:FindFirstChild("UpperContaier")

	local TitleContainer = UpperContainer and UpperContainer:FindFirstChild("TitleContainer")
	local Title = TitleContainer and (TitleContainer:FindFirstChild("Title") or TitleContainer:FindFirstChildOfClass("ImageLabel"))
	local TitleBackground = TitleContainer and TitleContainer:FindFirstChild("TitleBackground")
	local TitleGradient = Title and Title:FindFirstChildOfClass("UIGradient")

	-- Tự động tạo UIGradient nếu Studio chưa gắn sẵn
	if Title and not TitleGradient then
		TitleGradient = Instance.new("UIGradient")
		TitleGradient.Rotation = -90 -- Dưới lên trên
		TitleGradient.Parent = Title
	end

	-- Lower Container & Children
	local LowerName = (Elements and Elements.LowerContainer) or "LowerContainer"
	local LowerContainer = ScreenFrame:FindFirstChild(LowerName)

	local DotsFrame = LowerContainer and LowerContainer:FindFirstChild("Dots")
	local DotList = {}
	if DotsFrame then
		for i = 1, 3 do
			local Dot = DotsFrame:FindFirstChild("Dot" .. i) or DotsFrame:FindFirstChild("Dot[" .. i .. "]")
			if Dot then
				table.insert(DotList, Dot)
			end
		end
		-- Nếu không tìm thấy theo tên Dot1..3, lấy danh sách GuiObject con
		if #DotList == 0 then
			for _, Child in ipairs(DotsFrame:GetChildren()) do
				if Child:IsA("GuiObject") and not Child:IsA("UIListLayout") then
					table.insert(DotList, Child)
				end
			end
		end
	end

	-- Skip Button
	local SkipButton = LowerContainer and LowerContainer:FindFirstChild("SkipButton", true)

	return {
		ScreenGui       = ScreenGui,
		ScreenFrame     = ScreenFrame,
		UpperContainer  = UpperContainer,
		LowerContainer  = LowerContainer,
		TitleContainer  = TitleContainer,
		Title           = Title,
		TitleBackground = TitleBackground,
		TitleGradient   = TitleGradient,
		DotsFrame       = DotsFrame,
		DotList         = DotList,
		SkipButton      = SkipButton,
	}
end

-- =========================================================
-- PRELOAD ASSET COLLECTOR
-- =========================================================

--- Gom toàn bộ asset trong game thành một mảng phẳng (Flat Array)
--- @return table
local function CollectAllAssets()
	local AssetSet  = {}
	local AssetList = {}

	local function AddAsset(Item)
		if not Item then return end
		if type(Item) == "number" then
			local AssetUri = "rbxassetid://" .. tostring(Item)
			if not AssetSet[AssetUri] then
				AssetSet[AssetUri] = true
				table.insert(AssetList, AssetUri)
			end
		elseif type(Item) == "string" and Item ~= "" then
			if not AssetSet[Item] then
				AssetSet[Item] = true
				table.insert(AssetList, Item)
			end
		elseif typeof(Item) == "Instance" then
			if not AssetSet[Item] then
				AssetSet[Item] = true
				table.insert(AssetList, Item)
			end
		end
	end

	-- 1. Âm thanh cốt lõi & BGM từ AudioConfig
	local AudioIds = AudioConfig.GetAllAudioIds()
	for _, Id in ipairs(AudioIds) do
		AddAsset(Id)
	end

	-- 2. Hoạt ảnh từ AnimationConfig
	local AnimIds = AnimationConfig.GetAllAnimationIds()
	for _, Id in ipairs(AnimIds) do
		AddAsset(Id)
	end

	-- 3. Visual Assets & 3D Models trong ReplicatedStorage/Assets
	local AssetsFolder = ReplicatedStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Asset")
	if AssetsFolder then
		for _, Child in ipairs(AssetsFolder:GetDescendants()) do
			if Child:IsA("Model") or Child:IsA("BasePart") or Child:IsA("MeshPart") or Child:IsA("SpecialMesh") or Child:IsA("Decal") or Child:IsA("Texture") then
				AddAsset(Child)
			end
		end
	end

	-- 4. GUI Textures & Core Images trong PlayerGui
	for _, Gui in ipairs(PlayerGui:GetChildren()) do
		if Gui:IsA("ScreenGui") and Gui.Name ~= (GuiConfig.ScreenGuis.GameLoadingScreen or "GameLoadingScreen") then
			for _, Element in ipairs(Gui:GetDescendants()) do
				if Element:IsA("ImageLabel") or Element:IsA("ImageButton") then
					if Element.Image and Element.Image ~= "" then
						AddAsset(Element.Image)
					end
				end
			end
		end
	end

	return AssetList
end

-- =========================================================
-- ANIMATION LOGIC: DOT WAVE & TITLE WATER-FILL
-- =========================================================

--- Cập nhật độ dâng của Title (Water-Fill bằng UIGradient) và UIScale
--- @param Elements table
--- @param Progress number (0.0 -> 1.0)
local function UpdateTitleDisplay(Elements, Progress)
	local Title = Elements.Title
	local TitleGradient = Elements.TitleGradient
	local TitleContainer = Elements.TitleContainer or Title
	if not Title then return end

	local AnimCfg = GuiHelper.GetGameLoadingAnimConfig()
	local ClampedProgress = math.clamp(Progress, 0, 1)

	-- 1. Điều khiển UIGradient Transparency để dâng nước từ dưới lên
	if TitleGradient then
		TitleGradient.Rotation = -90 -- Hướng dâng từ dưới lên trên

		if ClampedProgress <= 0.005 then
			TitleGradient.Transparency = NumberSequence.new(1)
		elseif ClampedProgress >= 0.995 then
			TitleGradient.Transparency = NumberSequence.new(0)
		else
			local Edge = ClampedProgress
			TitleGradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(math.clamp(Edge - 0.002, 0, 1), 0),
				NumberSequenceKeypoint.new(math.clamp(Edge + 0.002, 0, 1), 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
	end

	-- 2. Scale động của Title từ MinScale (1.0) -> LoadMaxScale (1.4) trong lúc nạp
	if TitleContainer and not _IsPhase1Triggered then
		local TargetScale = AnimCfg.TitleMinScale + (AnimCfg.TitleLoadMaxScale - AnimCfg.TitleMinScale) * ClampedProgress
		local UiScale = GuiHelper.GetOrCreateScale(TitleContainer)
		if UiScale then
			UiScale.Scale = TargetScale
		end
	end
end

--- Cập nhật hoạt ảnh sóng gối đầu liên tục cho 3 Dot (Staggered Wave)
--- @param DotList table
--- @param ElapsedTime number
local function UpdateDotWave(DotList, ElapsedTime)
	if not _IsWaveActive or #DotList == 0 then return end

	local AnimCfg = GuiHelper.GetGameLoadingAnimConfig()
	local WaveDuration = AnimCfg.DotWaveDuration or 0.5
	local MinScale = AnimCfg.DotMinScale or 1.0
	local MaxScale = AnimCfg.DotMaxScale or 1.5

	local TotalCycle = WaveDuration * #DotList -- Chu kỳ hoàn chỉnh của cả cụm 3 dot
	local CurrentTime = ElapsedTime % TotalCycle

	for Index, Dot in ipairs(DotList) do
		local UiScale = GuiHelper.GetOrCreateScale(Dot)
		if UiScale then
			-- Khoảng thời gian bắt đầu của Dot[Index]
			local StartOffset = (Index - 1) * WaveDuration
			local LocalTime = (CurrentTime - StartOffset) % TotalCycle

			local ScaleVal = MinScale
			if LocalTime >= 0 and LocalTime <= WaveDuration then
				-- Tính sóng hình sin mượt mà từ 0 -> pi -> 0
				local SineFactor = math.sin((LocalTime / WaveDuration) * math.pi)
				ScaleVal = MinScale + (MaxScale - MinScale) * SineFactor
			end

			UiScale.Scale = ScaleVal
		end
	end
end

-- =========================================================
-- PHA KẾT THÚC (PHASE 1 & PHASE 2)
-- =========================================================

--- Khởi chạy Pha 2: Mở rèm đôi (Curtain Split) và hoàn tất
--- @param Elements table
local function TriggerPhase2(Elements)
	local AnimCfg = GuiHelper.GetGameLoadingAnimConfig()
	local UpperContainer = Elements.UpperContainer
	local LowerContainer = Elements.LowerContainer
	local ScreenFrame    = Elements.ScreenFrame
	local ScreenGui      = Elements.ScreenGui

	local Duration = AnimCfg.Phase2Duration or 0.65
	local Style    = AnimCfg.Phase2EasingStyle or Enum.EasingStyle.Quad
	local Dir      = AnimCfg.Phase2EasingDir or Enum.EasingDirection.InOut

	local TweenInfoObj = TweenInfo.new(Duration, Style, Dir)
	local CompletedTweens = 0
	local RequiredTweens = 0

	local function OnTweenDone()
		CompletedTweens += 1
		if CompletedTweens >= RequiredTweens then
			_IsLoadingCompleted = true

			-- Ngắt kết nối RenderStepped loop
			if _RenderConnection then
				_RenderConnection:Disconnect()
				_RenderConnection = nil
			end

			-- Báo hiệu Server: Player đã hoàn tất nạp game, sẵn sàng tham chiến
			if _FinishEvent then
				_FinishEvent:FireServer()
			end

			-- Ẩn GUI hoàn toàn
			if ScreenFrame then
				ScreenFrame.Visible = false
			end
			if ScreenGui then
				ScreenGui.Enabled = false
			end

			print("[GameLoadingController] ✅ GameLoadingScreen đã hoàn tất. Lobby đã sẵn sàng.")
		end
	end

	if UpperContainer then
		RequiredTweens += 1
		local OrigPos = UpperContainer.Position
		local TargetUpperPos = UDim2.new(OrigPos.X.Scale, OrigPos.X.Offset, OrigPos.Y.Scale - 0.65, OrigPos.Y.Offset)
		local UpperTween = TweenService:Create(UpperContainer, TweenInfoObj, { Position = TargetUpperPos })
		UpperTween.Completed:Connect(OnTweenDone)
		UpperTween:Play()
	end

	if LowerContainer then
		RequiredTweens += 1
		local OrigPos = LowerContainer.Position
		local TargetLowerPos = UDim2.new(OrigPos.X.Scale, OrigPos.X.Offset, OrigPos.Y.Scale + 0.65, OrigPos.Y.Offset)
		local LowerTween = TweenService:Create(LowerContainer, TweenInfoObj, { Position = TargetLowerPos })
		LowerTween.Completed:Connect(OnTweenDone)
		LowerTween:Play()
	end

	if RequiredTweens == 0 then
		OnTweenDone()
	end
end

--- Khởi chạy Pha 1: Pop scale Title lên 1.6 và nhấp nháy Dots
--- @param Elements table
local function TriggerPhase1(Elements)
	if _IsPhase1Triggered then return end
	_IsPhase1Triggered = true
	_IsWaveActive = false -- Dừng sóng wave bình thường

	local AnimCfg = GuiHelper.GetGameLoadingAnimConfig()
	local TitleContainer = Elements.TitleContainer or Elements.Title
	local DotList = Elements.DotList or {}

	-- 1. Pop Scale Title lên 1.6 với EasingStyle.Back
	if TitleContainer then
		local PopDuration = AnimCfg.Phase1PopDuration or 0.35
		local PopScale = AnimCfg.TitlePopScale or 1.6
		GuiHelper.TweenScale(TitleContainer, PopScale, PopDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	-- 2. Hiệu ứng nhấp nháy 3 Dots đồng thời (1.6 -> 1.3 -> 1.6 -> 0)
	task.spawn(function()
		local BlinkCount = AnimCfg.Phase1DotBlinkCount or 2
		local BlinkTime  = AnimCfg.Phase1DotBlinkTime or 0.12

		for _ = 1, BlinkCount do
			-- Phóng to 1.6
			for _, Dot in ipairs(DotList) do
				GuiHelper.TweenScale(Dot, 1.6, BlinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
			task.wait(BlinkTime)

			-- Thu nhỏ 1.3
			for _, Dot in ipairs(DotList) do
				GuiHelper.TweenScale(Dot, 1.3, BlinkTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
			task.wait(BlinkTime)
		end

		-- Co Dot về 0 để chuẩn bị mở rèm
		for _, Dot in ipairs(DotList) do
			GuiHelper.TweenScale(Dot, 0, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(0.15)

		-- Chuyển sang Pha 2
		TriggerPhase2(Elements)
	end)
end

-- =========================================================
-- SKIP & PRELOAD CONTROLLER
-- =========================================================

--- Bỏ qua tiến trình nạp tài nguyên và tiến thẳng đến 100%
--- @param Elements table
local function SkipLoading(Elements)
	if _IsPhase1Triggered or _IsLoadingCompleted then return end

	-- Khóa nút Skip tránh spam click
	if Elements.SkipButton then
		Elements.SkipButton.Active = false
		if Elements.SkipButton:IsA("GuiButton") then
			Elements.SkipButton.AutoButtonColor = false
		end
	end

	-- Phát âm thanh click nút
	local ClickSFX = AudioConfig.GetGuiAudio("ButtonClick")
	if ClickSFX then
		GuiHelper.PlayGuiSound(ClickSFX)
	end

	-- Ép tiến độ lên 100%
	_AssetProgress  = 1.0
	_ActualProgress = 1.0
	_VisualProgress = 1.0
	UpdateTitleDisplay(Elements, 1.0)

	TriggerPhase1(Elements)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameLoadingController = {}

function GameLoadingController:Init()
	_FinishEvent = RemoteDefinitions.GetEvent("FinishGameLoading")

	local Elements = ResolveElements()
	if not Elements then
		warn("[GameLoadingController] Không tìm thấy cấu trúc GUI GameLoadingScreen.")
		if _FinishEvent then
			_FinishEvent:FireServer()
		end
		return
	end

	local AnimCfg = GuiHelper.GetGameLoadingAnimConfig()

	-- 1. Thiết lập trạng thái ban đầu
	_WaveStartTime      = os.clock()
	_LoadStartTime      = os.clock()
	_AssetProgress      = 0.0
	_ActualProgress     = 0.0
	_VisualProgress     = 0.0
	_IsWaveActive       = true
	_IsPhase1Triggered  = false
	_IsLoadingCompleted = false

	UpdateTitleDisplay(Elements, 0.0)

	-- 2. Gắn sự kiện cho nút SkipButton
	if Elements.SkipButton then
		Elements.SkipButton.Active = true
		Elements.SkipButton.Visible = true

		if Elements.SkipButton:IsA("GuiButton") then
			GuiHelper.BindButtonScale(Elements.SkipButton)
			Elements.SkipButton.MouseButton1Click:Connect(function()
				SkipLoading(Elements)
			end)
		end
	end

	-- 3. Vòng lặp RenderStepped cập nhật Dot Wave & Lerp Progress mượt mà
	_RenderConnection = RunService.RenderStepped:Connect(function(DeltaTime)
		if _IsLoadingCompleted then return end

		-- Cập nhật sóng Dot
		if _IsWaveActive then
			local Elapsed = os.clock() - _WaveStartTime
			UpdateDotWave(Elements.DotList, Elapsed)
		end

		-- Tính toán tiến độ kép: kết hợp giữa AssetProgress thực tế và Cổng thời gian tối thiểu (MinLoadingDuration)
		if not _IsPhase1Triggered then
			local MinDuration = AnimCfg.MinLoadingDuration or 2.5
			local TimeProgress = (MinDuration > 0) and math.clamp((os.clock() - _LoadStartTime) / MinDuration, 0, 1) or 1.0
			_ActualProgress = math.min(_AssetProgress, TimeProgress)

			local LerpSpeed = AnimCfg.ProgressLerpSpeed or 8
			_VisualProgress = _VisualProgress + (_ActualProgress - _VisualProgress) * math.clamp(DeltaTime * LerpSpeed, 0, 1)

			UpdateTitleDisplay(Elements, _VisualProgress)

			-- Khi visual progress đạt >= 99% VÀ actual progress đạt >= 99%, kích hoạt Pha 1
			if _VisualProgress >= 0.99 and _ActualProgress >= 0.99 then
				_VisualProgress = 1.0
				UpdateTitleDisplay(Elements, 1.0)
				TriggerPhase1(Elements)
			end
		end
	end)

	-- 4. Bắt đầu thu thập và nạp trước tài nguyên (PreloadAsync)
	task.spawn(function()
		local AllAssets = CollectAllAssets()
		local TotalCount = #AllAssets

		if TotalCount == 0 then
			_AssetProgress = 1.0
			return
		end

		local LoadedCount = 0

		-- Safety Timeout 10s tự động hoàn tất nếu mạng lag / asset 404
		local SafetyTimeout = AnimCfg.SafetyTimeout or 10
		local TimeoutTask = task.delay(SafetyTimeout, function()
			if not _IsPhase1Triggered then
				warn(string.format("[GameLoadingController] ⚠️ Safety Timeout %ds đạt giới hạn. Ép hoàn tất tải (%d/%d assets).", SafetyTimeout, LoadedCount, TotalCount))
				_AssetProgress = 1.0
			end
		end)

		-- Chạy nạp bất đồng bộ kèm callback đếm từng item
		pcall(function()
			ContentProvider:PreloadAsync(AllAssets, function(ContentId, Status)
				LoadedCount += 1
				_AssetProgress = math.clamp(LoadedCount / TotalCount, 0, 1)
			end)
		end)

		-- Sau khi PreloadAsync tự hoàn tất
		if TimeoutTask then
			task.cancel(TimeoutTask)
		end
		_AssetProgress = 1.0
	end)

	print("[GameLoadingController] Đã khởi tạo màn hình tải game ban đầu.")
end

return GameLoadingController
