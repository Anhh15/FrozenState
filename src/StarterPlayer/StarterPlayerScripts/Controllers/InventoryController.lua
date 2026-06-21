-- InventoryController.lua (ModuleScript)
-- Điều khiển toàn bộ Inventory GUI: render danh sách item, chọn item, trang bị skin
-- Chỉ hiển thị trong Lobby phase (GameStateController sẽ ẩn khi vào trận)

-- Cấu trúc GUI mong đợi (StarterGui/Menu/Inventory):
--   Inventory (Frame)
--     CloseButton (TextButton)
--     TabContainer (Frame)
--       IciclesTab (TextButton)
--       BlocksTab  (TextButton)
--     ItemList (Frame)
--       ScrollingFrame (ScrollingFrame)
--         ItemTemplate (Frame) — Visible = false, dùng để clone
--           Background  (ImageLabel)
--           ItemViewport (ViewportFrame)
--           RarityText  (TextLabel)
--           NameText    (TextLabel)
--     ItemSelection (Frame)
--       ItemViewport (ViewportFrame)
--       NameText     (TextLabel)
--       RarityText   (TextLabel)
--       EquipButton  (TextButton)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions     = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local ItemRegistry          = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig          = require(ReplicatedStorage.Shared.Config.RarityConfig)
local PlayerDataController  = require(script.Parent.PlayerDataController)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MenuGui          = PlayerGui:WaitForChild("Menu", 10)
local NavGui           = PlayerGui:WaitForChild("NavigationButton", 10)

-- Inventory frame nằm bên trong Menu
local Inventory        = MenuGui and MenuGui:FindFirstChild("Inventory", true)

-- Các phần tử bên trong Inventory (dùng FindFirstChild để không crash nếu GUI chưa đúng tên)
local CloseButton      = Inventory and Inventory:FindFirstChild("CloseButton", true)
local TabContainer     = Inventory and Inventory:FindFirstChild("TabContainer", true)
local IciclesTab       = TabContainer and TabContainer:FindFirstChild("IciclesTab")
local BlocksTab        = TabContainer and TabContainer:FindFirstChild("BlocksTab")
local ItemList         = Inventory and Inventory:FindFirstChild("ItemList", true)
local ScrollingFrame   = ItemList and ItemList:FindFirstChildOfClass("ScrollingFrame")
local Assets           = ReplicatedStorage:FindFirstChild("Assets")
local GuiFolder        = Assets and (Assets:FindFirstChild("Gui") or Assets:FindFirstChild("GUI"))
local ItemTemplate     = GuiFolder and GuiFolder:FindFirstChild("ItemTemplate")
local ItemSelection    = Inventory and Inventory:FindFirstChild("ItemSelection", true)
local SelectionViewport = ItemSelection and ItemSelection:FindFirstChild("ItemViewport")
local SelectionName    = ItemSelection and ItemSelection:FindFirstChild("NameText")
local SelectionRarity  = ItemSelection and ItemSelection:FindFirstChild("RarityText")
local EquipButton      = ItemSelection and ItemSelection:FindFirstChild("EquipButton")

-- NavigationButton mở Inventory
local InventoryNavButton = NavGui and NavGui:FindFirstChild("Inventory", true)

-- =========================================================
-- STATE
-- =========================================================

local _currentTab     = "Icicle"   -- Tab đang chọn: "Icicle" hoặc "Block"
local _selectedEntry  = nil        -- Entry item đang được chọn trong ItemSelection
local _selectionModel = nil        -- Model đang render trong ItemSelection ViewportFrame
local _listConnections = {}        -- Kết nối RenderItem (dọn dẹp khi re-render)

-- =========================================================
-- HELPERS
-- =========================================================

--- Dọn dẹp toàn bộ nội dung ViewportFrame để tránh memory leak
local function CleanViewport(Viewport)
	if not Viewport then return end
	for _, Child in ipairs(Viewport:GetChildren()) do
		Child:Destroy()
	end
end

--- Clone model preview từ ReplicatedStorage vào ViewportFrame
--- Đường dẫn: ReplicatedStorage.Assets.ItemPreview.Icicles.<Id> hoặc .Blocks.<Id>
--- @param Viewport ViewportFrame
--- @param Entry    table  — entry từ ItemRegistry
local function LoadPreviewModel(Viewport, Entry)
	CleanViewport(Viewport)

	local TypeFolder = (Entry.Type == "Icicle") and "Icicles" or "Blocks"
	local PreviewFolder = ReplicatedStorage
		:FindFirstChild("Assets")
		and ReplicatedStorage.Assets
		:FindFirstChild("ItemPreview")
		and ReplicatedStorage.Assets.ItemPreview
		:FindFirstChild(TypeFolder)

	if not PreviewFolder then
		warn(("[InventoryController] Không tìm thấy thư mục preview: Assets.ItemPreview.%s"):format(TypeFolder))
		return
	end

	local ModelTemplate = PreviewFolder:FindFirstChild(Entry.Id)
	if not ModelTemplate then
		warn(("[InventoryController] Không tìm thấy preview model cho Id='%s'"):format(Entry.Id))
		return
	end

	local Model = ModelTemplate:Clone()
	Model.Parent = Viewport
end

--- Cập nhật trạng thái EquipButton dựa trên item đang được chọn
local function RefreshEquipButton()
	if not EquipButton or not _selectedEntry then return end

	local Data          = PlayerDataController.GetData()
	local SlotKey       = (_selectedEntry.Type == "Icicle") and "EquippedIcicle" or "EquippedIceBlock"
	local CurrentEquip  = Data and Data[SlotKey] or "Default"
	local IsEquipped    = (CurrentEquip == _selectedEntry.Id)

	local StatusText = EquipButton:FindFirstChild("StatusText")
	if StatusText then
		StatusText.Text = IsEquipped and "Equipped" or "Equip"
	else
		EquipButton.Text = IsEquipped and "Equipped" or "Equip"
	end

	EquipButton.Active      = not IsEquipped
	EquipButton.AutoButtonColor = not IsEquipped
end

--- Cập nhật ItemSelection panel khi chọn một item
--- @param Entry table — entry từ ItemRegistry
local function SelectItem(Entry)
	_selectedEntry = Entry

	-- Cập nhật text thông tin
	if SelectionName   then SelectionName.Text   = Entry.Name   end
	if SelectionRarity then
		SelectionRarity.Text      = Entry.Rarity
		local RarityCfg           = RarityConfig[Entry.Rarity]
		if RarityCfg then
			SelectionRarity.TextColor3 = RarityCfg.Color
		end
	end

	-- Cập nhật model preview lớn
	if SelectionViewport then
		LoadPreviewModel(SelectionViewport, Entry)
		_selectionModel = SelectionViewport:FindFirstChildWhichIsA("Model")
	end

	-- Cập nhật trạng thái nút Equip
	RefreshEquipButton()
end

--- Xử lý trang bị item khi bấm EquipButton
local function EquipCurrentItem()
	if not _selectedEntry then return end

	local SlotName = (_selectedEntry.Type == "Icicle") and "EquippedIcicle" or "EquippedIceBlock"

	-- Disable tạm thời để tránh spam
	if EquipButton then EquipButton.Active = false end

	local EquipItemFn = RemoteDefinitions.GetFunction("EquipItem")
	local Success, Result = pcall(function()
		return EquipItemFn:InvokeServer(SlotName, _selectedEntry.Id)
	end)

	if Success and Result then
		-- Cập nhật cache local
		local Data = PlayerDataController.GetData()
		if Data then
			Data[SlotName] = _selectedEntry.Id
		end
		print(("[InventoryController] Đã trang bị '%s' vào slot '%s'"):format(_selectedEntry.Id, SlotName))
	else
		warn(("[InventoryController] EquipItem thất bại: %s"):format(tostring(Result)))
	end

	-- Luôn refresh nút sau khi nhận phản hồi
	RefreshEquipButton()
end

--- Dọn dẹp toàn bộ ItemFrame cũ trong ScrollingFrame
local function ClearItemList()
	-- Hủy kết nối sự kiện click cũ
	for _, Conn in ipairs(_listConnections) do
		Conn:Disconnect()
	end
	_listConnections = {}

	-- Xóa toàn bộ item đã render (giữ lại template)
	if not ScrollingFrame then return end
	for _, Child in ipairs(ScrollingFrame:GetChildren()) do
		if Child ~= ItemTemplate and Child:IsA("GuiObject") then
			Child:Destroy()
		end
	end
end

--- Render danh sách item vào ScrollingFrame theo ItemType
--- Chỉ hiển thị: item "Default" + item đã sở hữu (OwnedIcicles / OwnedBlocks)
--- @param ItemType string — "Icicle" hoặc "Block"
local function RenderList(ItemType)
	if not ScrollingFrame or not ItemTemplate then
		warn("[InventoryController] Thiếu ScrollingFrame hoặc ItemTemplate trong GUI.")
		return
	end

	ClearItemList()
	CleanViewport(SelectionViewport)
	_selectedEntry = nil
	_selectionModel = nil

	-- Reset ItemSelection panel
	if SelectionName   then SelectionName.Text   = "" end
	if SelectionRarity then SelectionRarity.Text  = "" end
	if EquipButton     then
		local StatusText = EquipButton:FindFirstChild("StatusText")
		if StatusText then
			StatusText.Text = "Equip"
		else
			EquipButton.Text = "Equip"
		end
		EquipButton.Active = false
	end

	local Data         = PlayerDataController.GetData()
	local OwnedSet     = {}
	if Data then
		-- Đọc đúng danh sách sở hữu theo tab hiện tại (Phase 5 schema)
		local OwnedList = (ItemType == "Icicle") and Data.OwnedIcicles or Data.OwnedBlocks
		if OwnedList then
			for _, Id in ipairs(OwnedList) do
				OwnedSet[Id] = true
			end
		end
		-- Tương thích ngược: dữ liệu cũ từ OwnedCosmetics (nếu có)
		if Data.OwnedCosmetics then
			for _, Id in ipairs(Data.OwnedCosmetics) do
				OwnedSet[Id] = true
			end
		end
	end

	local Catalog = (ItemType == "Icicle")
		and ItemRegistry.GetAllIcicles()
		or  ItemRegistry.GetAllBlocks()

	local LayoutOrder = 0

	for _, Entry in ipairs(Catalog) do
		-- Chỉ hiển thị Default hoặc item đã sở hữu
		local IsDefault = (Entry.Id == "Default")
		local IsOwned   = OwnedSet[Entry.Id]
		if not IsDefault and not IsOwned then continue end

		local Frame = ItemTemplate:Clone()
		Frame.Name    = Entry.Id
		Frame.Visible = true
		Frame.LayoutOrder = LayoutOrder
		LayoutOrder += 1

		-- Gán Background theo Rarity
		local Background = Frame:FindFirstChild("Background")
		local RarityCfg  = RarityConfig[Entry.Rarity]
		if Background and RarityCfg then
			if Background:IsA("ImageLabel") then
				Background.Image            = RarityCfg.ImageId
				Background.ImageColor3      = RarityCfg.Color
			end
		end

		-- Gán RarityText color
		local RarityText = Frame:FindFirstChild("RarityText")
		if RarityText and RarityCfg then
			RarityText.Text       = Entry.Rarity
			RarityText.TextColor3 = RarityCfg.Color
		end

		-- Gán NameText
		local NameText = Frame:FindFirstChild("NameText")
		if NameText then
			NameText.Text = Entry.Name
		end

		-- Load model preview vào ViewportFrame của ItemFrame
		local ItemViewport = Frame:FindFirstChild("ItemViewport")
		if ItemViewport then
			LoadPreviewModel(ItemViewport, Entry)
		end

		Frame.Parent = ScrollingFrame

		-- Kết nối sự kiện click
		local EntrySnapshot = Entry  -- closure capture
		local ClickTarget = Frame:IsA("GuiButton") and Frame or Frame:FindFirstChildWhichIsA("GuiButton")
		local Conn
		if ClickTarget then
			Conn = ClickTarget.MouseButton1Click:Connect(function()
				SelectItem(EntrySnapshot)
			end)
		else
			Conn = Frame.InputBegan:Connect(function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
					SelectItem(EntrySnapshot)
				end
			end)
		end
		table.insert(_listConnections, Conn)
	end
end

-- =========================================================
-- TAB LOGIC
-- =========================================================

local function SwitchTab(ItemType)
	_currentTab = ItemType

	-- Highlight tab đang chọn bằng màu nền (Active: FFFFFF, Inactive: 2F2F2F)
	if ItemType == "Icicle" then
		if IciclesTab then IciclesTab.BackgroundColor3 = Color3.fromHex("FFFFFF") end
		if BlocksTab  then BlocksTab.BackgroundColor3  = Color3.fromHex("2F2F2F") end
	else
		if IciclesTab then IciclesTab.BackgroundColor3 = Color3.fromHex("2F2F2F") end
		if BlocksTab  then BlocksTab.BackgroundColor3  = Color3.fromHex("FFFFFF") end
	end

	RenderList(ItemType)
end

-- =========================================================
-- OPEN / CLOSE
-- =========================================================

local function OpenInventory()
	if not Inventory then return end
	Inventory.Visible = true
	SwitchTab(_currentTab)

	-- Tải dữ liệu mới bất đồng bộ từ Server để hiển thị các skin mới nhất
	task.spawn(function()
		PlayerDataController.RefreshData()
		if Inventory.Visible then
			SwitchTab(_currentTab)
		end
	end)
end

local function CloseInventory()
	if not Inventory then return end
	Inventory.Visible = false
	ClearItemList()
	CleanViewport(SelectionViewport)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local InventoryController = {}

function InventoryController:Init()
	if not Inventory then
		warn("[InventoryController] Không tìm thấy Inventory frame trong Menu GUI.")
		return
	end

	-- Đóng Inventory khi khởi tạo (đảm bảo trạng thái ban đầu là ẩn)
	Inventory.Visible = false

	-- Nút mở Inventory từ NavigationButton
	if InventoryNavButton then
		InventoryNavButton.MouseButton1Click:Connect(OpenInventory)
	else
		warn("[InventoryController] Không tìm thấy nút Inventory trong NavigationButton.")
	end

	-- Nút đóng Inventory
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(CloseInventory)
	end

	-- Tab switching
	if IciclesTab then
		IciclesTab.MouseButton1Click:Connect(function()
			SwitchTab("Icicle")
		end)
	end
	if BlocksTab then
		BlocksTab.MouseButton1Click:Connect(function()
			SwitchTab("Block")
		end)
	end

	-- Nút Equip
	if EquipButton then
		EquipButton.MouseButton1Click:Connect(EquipCurrentItem)
	end

	print("[InventoryController] Đã khởi tạo.")
end

--- Hàm public để GameStateController ẩn/hiện Inventory
--- @param Visible boolean
function InventoryController.SetVisible(Visible)
	if not Inventory then return end
	if not Visible then
		CloseInventory()
	end
	-- Khi visible = true, không tự mở — để người chơi tự bấm mở
end

return InventoryController
