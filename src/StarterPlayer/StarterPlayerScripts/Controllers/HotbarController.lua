-- HotbarController.lua (ModuleScript)
-- Điều khiển Custom Hotbar trong ScreenGui InGameGui
-- Thay thế hoàn toàn Hotbar và Backpack mặc định của Roblox
-- Quản lý trang bị/cất vũ khí, render 3D ViewportFrame, hoạt ảnh Active Zoom và Cooldown

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local ViewportManager   = require(ReplicatedStorage.Shared.Tools.ViewportManager)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

-- =========================================================
-- CONSTANTS & KEY BINDINGS
-- =========================================================

local SLOT_KEY_CODES = {
	[1] = Enum.KeyCode.One,
	[2] = Enum.KeyCode.Two,
	[3] = Enum.KeyCode.Three,
	[4] = Enum.KeyCode.Four,
	[5] = Enum.KeyCode.Five,
	[6] = Enum.KeyCode.Six,
	[7] = Enum.KeyCode.Seven,
	[8] = Enum.KeyCode.Eight,
	[9] = Enum.KeyCode.Nine,
}

-- =========================================================
-- LOCAL STATE
-- =========================================================

local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

local _InGameGui       = nil
local _HotbarFrame     = nil
local _TemplateSlot    = nil
local _ActiveSlots     = {}  -- [Tool] = { SlotFrame = Frame, Connections = {}, CooldownThread = thread? }
local _KeySlotMap      = {}  -- [KeyCode] = Tool
local _IsFrozen        = false
local _IsDead          = false
local _HotbarConfig         = nil
local _InputConnection      = nil
local _isVisible            = false
local _lastPhase            = nil
local _characterConnections = {}

-- =========================================================
-- PRIVATE HELPERS: CoreGui & Hierarchy
-- =========================================================

--- Tắt CoreGui Backpack một cách an toàn với cơ chế retry
local function DisableRobloxBackpack()
	task.spawn(function()
		local Success = false
		for _ = 1, 10 do
			local Ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if Ok then
				Success = true
				break
			end
			task.wait(0.5)
		end
		if not Success then
			warn("[HotbarController] Không thể tắt CoreGuiType.Backpack sau nhiều lần thử.")
		end
	end)
end

--- Tìm kiếm và khởi tạo các reference GUI của Hotbar trong InGameGui
local function ResolveGuiReferences()
	_InGameGui = GuiHelper.GetScreenGui(GuiConfig.ScreenGuis.InGameGui)
	if not _InGameGui then
		warn("[HotbarController] Không tìm thấy ScreenGui InGameGui.")
		return false
	end
	_InGameGui.ResetOnSpawn = false

	local Elements = GuiConfig.HotbarElements or {
		Hotbar       = "Hotbar",
		Templates    = "Templates",
		ItemSlot     = "ItemSlot",
		ItemViewport = "ItemViewport",
	}

	_HotbarFrame = _InGameGui:FindFirstChild(Elements.Hotbar, true)
	if not _HotbarFrame then
		warn("[HotbarController] Không tìm thấy Frame Hotbar trong InGameGui.")
		return false
	end

	-- Tìm folder Templates (hoặc Template)
	local TemplatesFolder = _HotbarFrame:FindFirstChild(Elements.Templates)
		or _HotbarFrame:FindFirstChild("Template")
		or _HotbarFrame:FindFirstChild("Templates")

	if TemplatesFolder then
		_TemplateSlot = TemplatesFolder:FindFirstChild(Elements.ItemSlot)
			or TemplatesFolder:FindFirstChildWhichIsA("Frame")
	else
		-- Fallback: tìm trực tiếp trong Hotbar nếu không có folder Templates
		_TemplateSlot = _HotbarFrame:FindFirstChild(Elements.ItemSlot)
	end

	if _TemplateSlot then
		_TemplateSlot.Visible = false
	else
		warn("[HotbarController] Không tìm thấy ItemSlot template trong Hotbar.")
	end

	_HotbarConfig = GuiHelper.GetHotbarConfig()
	return true
end

-- =========================================================
-- PRIVATE HELPERS: Tool Equip & Toggle Logic
-- =========================================================

--- Rút hoặc cất vũ khí (Toggle Equip)
--- @param Tool Tool
local function ToggleEquipTool(Tool)
	if not Tool or not Tool:IsDescendantOf(game) then return end

	-- Chặn tương tác nếu người chơi bị đóng băng hoặc đã chết
	if _IsFrozen or _IsDead then return end

	local Character = LocalPlayer.Character
	if not Character then return end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end

	local Backpack = LocalPlayer:FindFirstChild("Backpack")

	if Tool.Parent == Character then
		-- Đang cầm trên tay -> Cất vào Balo
		Humanoid:UnequipTools()
	elseif Backpack and Tool.Parent == Backpack then
		-- Đang trong Balo -> Rút ra tay
		Humanoid:EquipTool(Tool)
	end
end

-- =========================================================
-- PRIVATE HELPERS: Visual & Animation
-- =========================================================

--- Clone model preview 3D vào ViewportFrame của ItemSlot
--- @param Viewport ViewportFrame
--- @param Tool Tool
local function LoadToolViewport(Viewport, Tool)
	if not Viewport or not Tool then return end
	ViewportManager.CleanViewport(Viewport)

	local SkinId = PlayerStateHelper.GetEquippedIcicleSkinId(LocalPlayer)
	if Tool:GetAttribute("SkinId") then
		SkinId = Tool:GetAttribute("SkinId")
	end

	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	local ItemPreview = Assets and Assets:FindFirstChild("ItemPreview")
	local IciclesFolder = ItemPreview and ItemPreview:FindFirstChild("Icicles")
	local ModelTemplate = IciclesFolder and IciclesFolder:FindFirstChild(SkinId)

	-- Fallback về Default skin nếu không tìm thấy skin cụ thể
	if not ModelTemplate and IciclesFolder then
		ModelTemplate = IciclesFolder:FindFirstChild("Default")
	end

	if ModelTemplate then
		local ModelClone = ModelTemplate:Clone()
		ModelClone.Parent = Viewport
		ViewportManager.RenderItem(Viewport, ModelClone, "Icicle", SkinId)
	else
		-- Fallback dự phòng: Clone các Part hiển thị từ chính Tool
		local Handle = Tool:FindFirstChild("Handle")
		if Handle then
			local FallbackModel = Instance.new("Model")
			FallbackModel.Name = Tool.Name
			local HandleClone = Handle:Clone()
			HandleClone.Parent = FallbackModel
			FallbackModel.PrimaryPart = HandleClone
			FallbackModel.Parent = Viewport
			ViewportManager.RenderItem(Viewport, FallbackModel, "Icicle", SkinId)
		end
	end
end

--- Cập nhật trạng thái Active / Inactive trực quan của Slot
--- @param SlotData table
--- @param IsEquipped boolean
local function UpdateSlotActiveVisual(SlotData, IsEquipped)
	local SlotFrame = SlotData and SlotData.SlotFrame
	if not SlotFrame or not _HotbarConfig then return end

	local TargetScale = IsEquipped and _HotbarConfig.ActiveScale or _HotbarConfig.InactiveScale
	local TargetTrans = IsEquipped and _HotbarConfig.ActiveBackgroundTrans or _HotbarConfig.InactiveBackgroundTrans
	local TargetZIndex = IsEquipped and 10 or 1

	local UiScale = GuiHelper.GetOrCreateScale(SlotFrame)

	-- Nếu trạng thái Equip không đổi và Scale đã khớp TargetScale, không chạy lại animation
	if SlotData.LastIsEquipped == IsEquipped and UiScale and math.abs(UiScale.Scale - TargetScale) < 0.01 then
		return
	end
	SlotData.LastIsEquipped = IsEquipped

	SlotFrame.ZIndex = TargetZIndex

	local Duration = _HotbarConfig.ScaleDuration or 0.15
	local Style    = _HotbarConfig.ScaleEasingStyle or Enum.EasingStyle.Back
	local Dir      = _HotbarConfig.ScaleEasingDir or Enum.EasingDirection.Out

	-- Tween UIScale qua GuiHelper
	if UiScale then
		GuiHelper.CancelTween(UiScale)
		local ScaleTween = TweenService:Create(UiScale, TweenInfo.new(Duration, Style, Dir), { Scale = TargetScale })
		ScaleTween:Play()
	end

	-- Tìm Frame con Background bên trong ItemSlot (nếu có) để tween độ mờ, giữ nguyên thuộc tính của ItemSlot cha
	local Elements = GuiConfig.HotbarElements
	local BackgroundName = Elements and Elements.Background or "Background"
	local BgFrame = SlotFrame:FindFirstChild(BackgroundName, true)
	if BgFrame and BgFrame:IsA("GuiObject") then
		local BgTween = TweenService:Create(BgFrame, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = TargetTrans,
		})
		BgTween:Play()
	end
end

--- Kích hoạt hiệu ứng rèm Cooldown trắng rút dần và chữ đếm ngược số giây
--- @param SlotData table
--- @param Tool Tool
local function PlayCooldownAnimation(SlotData, Tool)
	local SlotFrame = SlotData.SlotFrame
	if not SlotFrame then return end

	local Elements = GuiConfig.HotbarElements
	local CurtainName = Elements and Elements.CooldownCurtain or "CooldownCurtain"
	local TextName    = Elements and Elements.CooldownText or "CooldownText"

	local CooldownCurtain = SlotFrame:FindFirstChild(CurtainName, true)
	local CooldownText    = SlotFrame:FindFirstChild(TextName, true)

	if not CooldownCurtain then return end

	-- Hủy thread countdown cũ nếu có
	if SlotData.CooldownThread then
		task.cancel(SlotData.CooldownThread)
		SlotData.CooldownThread = nil
	end

	local CooldownDuration = Tool:GetAttribute("CooldownDuration")
		or (GameConfig.Tool and GameConfig.Tool.IcicleCooldown)
		or 0.8

	local CooldownEndTime = Tool:GetAttribute("CooldownEndTime")
		or (os.clock() + CooldownDuration)

	local Remaining = CooldownEndTime - os.clock()
	if Remaining <= 0 then
		CooldownCurtain.Visible = false
		CooldownCurtain.Size = UDim2.new(1, 0, 0, 0)
		if CooldownText then
			CooldownText.Visible = false
			CooldownText.Text = ""
		end
		return
	end

	local CurrentScaleY = math.clamp(Remaining / math.max(0.01, CooldownDuration), 0, 1)

	-- Thiết lập thuộc tính ban đầu cho CooldownCurtain (neo đáy và tỉ lệ chiều cao hiện tại)
	CooldownCurtain.Visible = true
	CooldownCurtain.AnchorPoint = Vector2.new(0, 1)
	CooldownCurtain.Position = UDim2.new(0, 0, 1, 0)
	CooldownCurtain.Size = UDim2.new(1, 0, CurrentScaleY, 0)

	if CooldownText then
		CooldownText.Visible = true
		CooldownText.Text = string.format("%.2f", Remaining)
	end

	-- Tween thu nhỏ rèm từ CurrentScaleY về 0.0 theo chiều cao Y
	local EasingStyle = _HotbarConfig and _HotbarConfig.CooldownEasingStyle or Enum.EasingStyle.Linear
	local EasingDir   = _HotbarConfig and _HotbarConfig.CooldownEasingDir or Enum.EasingDirection.InOut

	local CurtainTween = TweenService:Create(
		CooldownCurtain,
		TweenInfo.new(Remaining, EasingStyle, EasingDir),
		{ Size = UDim2.new(1, 0, 0, 0) }
	)
	CurtainTween:Play()

	-- Thread cập nhật số giây đếm ngược
	SlotData.CooldownThread = task.spawn(function()
		while true do
			local TimeLeft = CooldownEndTime - os.clock()
			if TimeLeft <= 0 then
				break
			end
			if CooldownText then
				CooldownText.Text = string.format("%.2f", TimeLeft)
			end
			RunService.Heartbeat:Wait()
		end

		-- Hoàn tất Cooldown
		CooldownCurtain.Visible = false
		CooldownCurtain.Size = UDim2.new(1, 0, 0, 0)
		if CooldownText then
			CooldownText.Visible = false
			CooldownText.Text = ""
		end
		SlotData.CooldownThread = nil
	end)
end

-- =========================================================
-- PRIVATE HELPERS: Slot Lifecycle Management
-- =========================================================

--- Tạo và gắn ItemSlot cho một Tool cụ thể
--- @param Tool Tool
--- @param SlotIndex number
local function CreateSlotForTool(Tool, SlotIndex)
	if not _HotbarFrame or not _TemplateSlot or not Tool then return end

	-- Dọn dẹp slot cũ của Tool này nếu đã tồn tại
	if _ActiveSlots[Tool] then
		local OldData = _ActiveSlots[Tool]
		for _, Conn in ipairs(OldData.Connections) do
			Conn:Disconnect()
		end
		if OldData.CooldownThread then
			task.cancel(OldData.CooldownThread)
		end
		if OldData.SlotFrame then
			OldData.SlotFrame:Destroy()
		end
		_ActiveSlots[Tool] = nil
	end

	local SlotFrame = _TemplateSlot:Clone()
	SlotFrame.Name = ("Slot_%d_%s"):format(SlotIndex, Tool.Name)
	SlotFrame.LayoutOrder = SlotIndex
	SlotFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	SlotFrame.Visible = true

	local Elements = GuiConfig.HotbarElements
	local ViewportName = Elements and Elements.ItemViewport or "ItemViewport"
	local IndexTextName = Elements and Elements.IndexText or "IndexText"
	local CurtainName   = Elements and Elements.CooldownCurtain or "CooldownCurtain"
	local TextName      = Elements and Elements.CooldownText or "CooldownText"

	local ItemViewport    = SlotFrame:FindFirstChild(ViewportName, true)
	local IndexLabel      = SlotFrame:FindFirstChild(IndexTextName, true)
	local CooldownCurtain = SlotFrame:FindFirstChild(CurtainName, true)
	local CooldownText    = SlotFrame:FindFirstChild(TextName, true)

	if IndexLabel and IndexLabel:IsA("TextLabel") then
		IndexLabel.Text = tostring(SlotIndex)
	end

	-- Khởi tạo ẩn ban đầu cho rèm Cooldown và Text đếm ngược
	if CooldownCurtain then
		CooldownCurtain.Visible = false
		CooldownCurtain.AnchorPoint = Vector2.new(0, 1)
		CooldownCurtain.Position = UDim2.new(0, 0, 1, 0)
		CooldownCurtain.Size = UDim2.new(1, 0, 0, 0)
	end

	if CooldownText then
		CooldownText.Visible = false
		CooldownText.Text = ""
	end

	-- Render 3D Model
	if ItemViewport and ItemViewport:IsA("ViewportFrame") then
		LoadToolViewport(ItemViewport, Tool)
	end

	local SlotData = {
		SlotFrame      = SlotFrame,
		Connections    = {},
		CooldownThread = nil,
		LastIsEquipped = nil,
	}

	-- 1. Bắt sự kiện Click / Touch trên SlotFrame
	local ClickTarget = SlotFrame:IsA("GuiButton") and SlotFrame or SlotFrame:FindFirstChildWhichIsA("GuiButton")
	if ClickTarget then
		local ClickConn = ClickTarget.MouseButton1Click:Connect(function()
			ToggleEquipTool(Tool)
		end)
		table.insert(SlotData.Connections, ClickConn)
	else
		local TouchConn = SlotFrame.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				ToggleEquipTool(Tool)
			end
		end)
		table.insert(SlotData.Connections, TouchConn)
	end

	-- 2. Lắng nghe thay đổi trạng thái Equip/Unequip (Tool.Parent đổi giữa Character và Backpack)
	local function CheckEquipState()
		local Character = LocalPlayer.Character
		local IsEquipped = (Character and Tool.Parent == Character)
		UpdateSlotActiveVisual(SlotData, IsEquipped)
	end

	local AncestryConn = Tool.AncestryChanged:Connect(function()
		if not Tool:IsDescendantOf(game) then
			-- Tool đã bị Destroy
			SyncTools()
			return
		end
		CheckEquipState()
	end)
	table.insert(SlotData.Connections, AncestryConn)

	-- 3. Lắng nghe Cooldown attribute từ Tool (do IcicleScript phát ra)
	local CooldownConn = Tool:GetAttributeChangedSignal("IsOnCooldown"):Connect(function()
		local IsOnCooldown = Tool:GetAttribute("IsOnCooldown") == true
		if IsOnCooldown then
			PlayCooldownAnimation(SlotData, Tool)
		else
			-- Hủy animation nếu cooldown kết thúc
			if SlotData.CooldownThread then
				task.cancel(SlotData.CooldownThread)
				SlotData.CooldownThread = nil
			end
			local Curtain = SlotFrame:FindFirstChild(CurtainName, true)
			local TextLbl = SlotFrame:FindFirstChild(TextName, true)
			if Curtain then
				Curtain.Visible = false
				Curtain.Size = UDim2.new(1, 0, 0, 0)
			end
			if TextLbl then
				TextLbl.Visible = false
				TextLbl.Text = ""
			end
		end
	end)
	table.insert(SlotData.Connections, CooldownConn)

	-- Gán KeyCode tương ứng
	local KeyCode = SLOT_KEY_CODES[SlotIndex]
	if KeyCode then
		_KeySlotMap[KeyCode] = Tool
	end

	-- Đặt trạng thái ban đầu
	CheckEquipState()

	-- Khôi phục Cooldown animation nếu Tool đang trong thời gian Cooldown
	if Tool:GetAttribute("IsOnCooldown") == true then
		local EndTime = Tool:GetAttribute("CooldownEndTime")
		if EndTime and EndTime > os.clock() then
			PlayCooldownAnimation(SlotData, Tool)
		end
	end

	SlotFrame.Parent = _HotbarFrame
	_ActiveSlots[Tool] = SlotData
end

--- Dọn dẹp toàn bộ các slot đang hiển thị
local function ClearAllSlots()
	for Tool, SlotData in pairs(_ActiveSlots) do
		for _, Conn in ipairs(SlotData.Connections) do
			Conn:Disconnect()
		end
		if SlotData.CooldownThread then
			task.cancel(SlotData.CooldownThread)
		end
		if SlotData.SlotFrame then
			local Elements = GuiConfig.HotbarElements
			local ViewportName = Elements and Elements.ItemViewport or "ItemViewport"
			local ItemViewport = SlotData.SlotFrame:FindFirstChild(ViewportName, true)
			if ItemViewport and ItemViewport:IsA("ViewportFrame") then
				ViewportManager.CleanViewport(ItemViewport)
			end
			SlotData.SlotFrame:Destroy()
		end
	end
	_ActiveSlots = {}
	_KeySlotMap = {}
end

--- Kiểm tra danh sách tool thực tế có thay đổi so với _ActiveSlots không trước khi refresh
local function SyncTools()
	if not _HotbarFrame or not _TemplateSlot then return end

	local ToolsList = {}
	local Backpack = LocalPlayer:FindFirstChild("Backpack")
	local Character = LocalPlayer.Character

	if Character then
		for _, Item in ipairs(Character:GetChildren()) do
			if Item:IsA("Tool") then
				table.insert(ToolsList, Item)
			end
		end
	end

	if Backpack then
		for _, Item in ipairs(Backpack:GetChildren()) do
			if Item:IsA("Tool") and not table.find(ToolsList, Item) then
				table.insert(ToolsList, Item)
			end
		end
	end

	-- Kiểm tra xem có tool nào mới trong ToolsList mà chưa có trong _ActiveSlots không
	local HasChanged = false
	for _, Tool in ipairs(ToolsList) do
		if not _ActiveSlots[Tool] or not _ActiveSlots[Tool].SlotFrame or not _ActiveSlots[Tool].SlotFrame.Parent then
			HasChanged = true
			break
		end
	end

	-- Kiểm tra xem có tool nào trong _ActiveSlots không còn nằm trong ToolsList hoặc đã bị Destroy không
	if not HasChanged then
		for Tool, _ in pairs(_ActiveSlots) do
			if not Tool:IsDescendantOf(game) or not table.find(ToolsList, Tool) then
				HasChanged = true
				break
			end
		end
	end

	if HasChanged then
		HotbarController.RefreshHotbar()
	end
end

-- =========================================================
-- PUBLIC CONTROLLER API
-- =========================================================

local HotbarController = {}

--- Đặt lại trạng thái Frozen / Dead về mặc định (chưa bị đóng băng, còn sống)
function HotbarController.ResetState()
	_IsFrozen = false
	_IsDead   = false
end

--- Quét Backpack và Character của LocalPlayer để xây dựng lại danh sách Slot
function HotbarController.RefreshHotbar()
	ClearAllSlots()

	if not _HotbarFrame or not _TemplateSlot then return end

	local ToolsList = {}
	local Backpack = LocalPlayer:FindFirstChild("Backpack")
	local Character = LocalPlayer.Character

	-- 1. Ưu tiên tool đang cầm trên tay Character
	if Character then
		for _, Item in ipairs(Character:GetChildren()) do
			if Item:IsA("Tool") then
				table.insert(ToolsList, Item)
			end
		end
	end

	-- 2. Thêm các tool trong Backpack
	if Backpack then
		for _, Item in ipairs(Backpack:GetChildren()) do
			if Item:IsA("Tool") then
				-- Tránh trùng lặp
				if not table.find(ToolsList, Item) then
					table.insert(ToolsList, Item)
				end
			end
		end
	end

	-- 3. Tạo ItemSlot cho từng tool tìm thấy
	for Index, Tool in ipairs(ToolsList) do
		CreateSlotForTool(Tool, Index)
	end
end

--- Ẩn / Hiện toàn bộ Frame Hotbar theo điều kiện hiển thị tổng hợp
--- @param Visible boolean
function HotbarController.SetVisible(Visible)
	local ShouldShow = Visible and (not _IsFrozen) and (not _IsDead)

	-- Idempotency Guard: Nếu trạng thái không thay đổi, bỏ qua không làm gì
	if _isVisible == Visible and _HotbarFrame and _HotbarFrame.Visible == ShouldShow then
		return
	end
	_isVisible = Visible

	if _HotbarFrame then
		_HotbarFrame.Visible = ShouldShow
		if ShouldShow then
			HotbarController.RefreshHotbar()
		elseif not Visible then
			ClearAllSlots()
		end
	end
end

--- Khởi tạo controller
function HotbarController:Init()
	-- 1. Tắt CoreGui Backpack mặc định của Roblox
	DisableRobloxBackpack()

	-- 2. Resolve GUI components
	if not ResolveGuiReferences() then return end

	-- 3. Bắt sự kiện phím số 1..9 từ bàn phím
	if _InputConnection then
		_InputConnection:Disconnect()
		_InputConnection = nil
	end

	_InputConnection = UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed then return end
		if _IsFrozen or _IsDead then return end

		if Input.UserInputType == Enum.UserInputType.Keyboard then
			local BoundTool = _KeySlotMap[Input.KeyCode]
			if BoundTool then
				ToggleEquipTool(BoundTool)
			end
		end
	end)

	-- 4. Lắng nghe trạng thái Frozen / Dead từ Server
	local UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
	UpdatePlayerStateEvent.OnClientEvent:Connect(function(Data)
		if not Data or Data.PlayerId ~= LocalPlayer.UserId then return end

		local PrevFrozen = _IsFrozen
		local PrevDead   = _IsDead

		_IsFrozen = (Data.State == "Frozen")
		_IsDead   = (Data.State == "Dead")

		if _IsFrozen or _IsDead then
			-- Tự động cất vũ khí nếu bị đóng băng hoặc chết
			local Character = LocalPlayer.Character
			local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				Humanoid:UnequipTools()
			end

			-- Ẩn Hotbar hoàn toàn khi Frozen hoặc Dead (Phương án A)
			if _HotbarFrame then
				_HotbarFrame.Visible = false
			end
		elseif (PrevFrozen or PrevDead) and (not _IsFrozen) and (not _IsDead) then
			-- Được Thaw / Hồi phục Normal: hiện lại Hotbar và nạp lại Tool mới
			if _isVisible and _HotbarFrame then
				_HotbarFrame.Visible = true
				task.defer(HotbarController.RefreshHotbar)
			end
		end
	end)

	-- 5. Lắng nghe CharacterAdded để bind lại Backpack / Character listeners khi respawn
	local function BindCharacter(Character)
		for _, Conn in ipairs(_characterConnections) do
			Conn:Disconnect()
		end
		_characterConnections = {}

		local Backpack = LocalPlayer:WaitForChild("Backpack", 5)

		if Backpack then
			local AddedConn = Backpack.ChildAdded:Connect(function(Child)
				if Child:IsA("Tool") then
					task.defer(SyncTools)
				end
			end)
			local RemovedConn = Backpack.ChildRemoved:Connect(function(Child)
				if Child:IsA("Tool") then
					task.defer(SyncTools)
				end
			end)
			table.insert(_characterConnections, AddedConn)
			table.insert(_characterConnections, RemovedConn)
		end

		if Character then
			local AddedConn = Character.ChildAdded:Connect(function(Child)
				if Child:IsA("Tool") then
					task.defer(SyncTools)
				end
			end)
			local RemovedConn = Character.ChildRemoved:Connect(function(Child)
				if Child:IsA("Tool") then
					task.defer(SyncTools)
				end
			end)
			table.insert(_characterConnections, AddedConn)
			table.insert(_characterConnections, RemovedConn)
		end

		HotbarController.ResetState()
		if _isVisible and not _IsFrozen and not _IsDead then
			if _HotbarFrame then
				_HotbarFrame.Visible = true
			end
			task.defer(HotbarController.RefreshHotbar)
		end
	end

	LocalPlayer.CharacterAdded:Connect(BindCharacter)
	if LocalPlayer.Character then
		BindCharacter(LocalPlayer.Character)
	end

	-- 6. Lắng nghe thay đổi SkinIcicle từ Attribute
	LocalPlayer:GetAttributeChangedSignal("EquippedIcicleSkinId"):Connect(function()
		if _isVisible and not _IsFrozen and not _IsDead then
			HotbarController.RefreshHotbar()
		end
	end)

	-- 7. Lắng nghe vòng đời trận đấu để làm sạch Hotbar khi về sảnh (Intermission) và đồng bộ state
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		local Phase = Data.Phase or "Intermission"

		-- Chỉ xử lý khi Phase thực sự thay đổi (tránh reset mỗi giây theo chu kỳ đếm ngược TimeRemaining)
		if Phase == _lastPhase then
			return
		end
		_lastPhase = Phase

		if Phase == "Intermission" then
			HotbarController.ResetState()
			ClearAllSlots()
		elseif Phase == "Setup" or Phase == "Ready" then
			HotbarController.ResetState()
		elseif Phase == "InGame" then
			HotbarController.ResetState()
			if _isVisible and not _IsFrozen and not _IsDead then
				if _HotbarFrame then
					_HotbarFrame.Visible = true
				end
				task.defer(HotbarController.RefreshHotbar)
			end
		end
	end)

	print("[HotbarController] Đã khởi tạo.")
end

return HotbarController
