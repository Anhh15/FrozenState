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
--           ItemImage   (ImageLabel)
--           RarityText  (TextLabel)
--           NameText    (TextLabel)
--           EquippedText (GuiObject) — Hiển thị khi item đang được trang bị
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
local AudioConfig           = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiConfig             = require(ReplicatedStorage.Shared.Config.GuiConfig)
local PlayerDataController  = require(script.Parent.PlayerDataController)
local ViewportManager       = require(ReplicatedStorage.Shared.Tools.ViewportManager)
local GuiHelper             = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local ItemCard              = require(ReplicatedStorage.Shared.Tools.ItemCard)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MenuGui = GuiHelper.GetScreenGui("Menu")

-- Inventory frame nằm bên trong Menu
local Inventory        = MenuGui and MenuGui:FindFirstChild("Inventory", true)

-- Các phần tử bên trong Inventory (dùng FindFirstChild để không crash nếu GUI chưa đúng tên)
local CloseButton      = Inventory and Inventory:FindFirstChild("CloseButton", true)
local TabContainer     = Inventory and Inventory:FindFirstChild("TabContainer", true)
local IciclesTab       = TabContainer and TabContainer:FindFirstChild("IciclesTab")
local BlocksTab        = TabContainer and TabContainer:FindFirstChild("BlocksTab")
local ItemList         = Inventory and Inventory:FindFirstChild("ItemList", true)
local ScrollingFrame   = ItemList and ItemList:FindFirstChildOfClass("ScrollingFrame")
local ItemSelection    = Inventory and Inventory:FindFirstChild("ItemSelection", true)
local SelectionViewport = ItemSelection and ItemSelection:FindFirstChild("ItemViewport")
local SelectionName    = ItemSelection and ItemSelection:FindFirstChild("NameText")
local SelectionRarity  = ItemSelection and ItemSelection:FindFirstChild("RarityText")
local EquipButton      = ItemSelection and ItemSelection:FindFirstChild("EquipButton")

-- =========================================================
-- STATE
-- =========================================================

local _CurrentTab      = "Icicle"   -- Tab đang chọn: "Icicle" hoặc "Block"
local _SelectedEntry   = nil        -- Entry item đang được chọn trong ItemSelection
local _SelectionModel  = nil        -- Model đang render trong ItemSelection ViewportFrame
local _ListConnections = {}        -- Kết nối RenderItem (dọn dẹp khi re-render)
local _StaggerThread   = nil        -- Thread animation stagger danh sách item

--- Dừng animation stagger đang chạy dở
local function StopStaggerAnimation()
	if _StaggerThread then
		task.cancel(_StaggerThread)
		_StaggerThread = nil
	end
end

--- Phát âm thanh GUI qua GuiHelper
local function PlayGuiSound(SoundId)
	GuiHelper.PlayGuiSound(SoundId)
end

-- =========================================================
-- HELPERS
-- =========================================================

--- Lazy-require MenuController để điều phối mở/đóng cửa sổ
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

--- Dọn dẹp toàn bộ nội dung ViewportFrame để tránh memory leak
--- Ủy quyền cho ViewportManager để đảm bảo dọn đúng cả Camera lẫn Model
local function CleanViewport(Viewport)
	ViewportManager.CleanViewport(Viewport)
end

--- Clone model preview từ ReplicatedStorage vào ViewportFrame và tự động căn camera
--- Đường dẫn: ReplicatedStorage.Assets.ItemPreview.Icicles.<Id> hoặc .Blocks.<Id>
--- Camera được tính tự động qua ViewportManager dựa trên Bounding Box của model
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

	-- Tạo camera tự động dựa trên Bounding Box và cấu hình ViewportConfig
	ViewportManager.RenderItem(Viewport, Model, Entry.Type, Entry.Id)
end

--- Cập nhật trạng thái EquipButton dựa trên item đang được chọn
local function RefreshEquipButton()
	if not EquipButton or not _SelectedEntry then return end

	local Data          = PlayerDataController.GetData()
	local SlotKey       = (_SelectedEntry.Type == "Icicle") and "EquippedIcicle" or "EquippedIceBlock"
	local CurrentEquip  = Data and Data[SlotKey] or "Default"
	local IsEquipped    = (CurrentEquip == _SelectedEntry.Id)

	local StatusText = EquipButton:FindFirstChild("StatusText")
	if StatusText then
		StatusText.Text = IsEquipped and "Equipped" or "Equip"
	else
		EquipButton.Text = IsEquipped and "Equipped" or "Equip"
	end

	EquipButton.Active      = not IsEquipped
	EquipButton.AutoButtonColor = not IsEquipped
end

--- Cập nhật trạng thái hiển thị của Equipped tag cho các item đang render trong ScrollingFrame
local function UpdateEquippedTags()
	if not ScrollingFrame then return end

	local Data         = PlayerDataController.GetData()
	local SlotKey      = (_CurrentTab == "Icicle") and "EquippedIcicle" or "EquippedIceBlock"
	local CurrentEquip = Data and Data[SlotKey] or "Default"

	for _, Child in ipairs(ScrollingFrame:GetChildren()) do
		if Child:IsA("GuiObject") and not Child:IsA("UIGridLayout") and not Child:IsA("UIListLayout") then
			ItemCard.SetEquipped(Child, Child.Name == CurrentEquip)
		end
	end
end

--- Cập nhật ItemSelection panel khi chọn một item
--- @param Entry table — entry từ ItemRegistry
local function SelectItem(Entry)
	_SelectedEntry = Entry

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
		_SelectionModel = SelectionViewport:FindFirstChildWhichIsA("Model")
	end

	-- Cập nhật trạng thái nút Equip
	RefreshEquipButton()
end

--- Xử lý trang bị item khi bấm EquipButton
local function EquipCurrentItem()
	if not _SelectedEntry then return end

	local SlotName = (_SelectedEntry.Type == "Icicle") and "EquippedIcicle" or "EquippedIceBlock"

	-- Disable tạm thời để tránh spam
	if EquipButton then EquipButton.Active = false end

	local EquipItemFn = RemoteDefinitions.GetFunction("EquipItem")
	local Success, Result = pcall(function()
		return EquipItemFn:InvokeServer(SlotName, _SelectedEntry.Id)
	end)

	if Success and Result then
		-- Cập nhật cache local
		local Data = PlayerDataController.GetData()
		if Data then
			Data[SlotName] = _SelectedEntry.Id
		end
		UpdateEquippedTags()
		print(("[InventoryController] Đã trang bị '%s' vào slot '%s'"):format(_SelectedEntry.Id, SlotName))
	else
		warn(("[InventoryController] EquipItem thất bại: %s"):format(tostring(Result)))
	end

	-- Luôn refresh nút sau khi nhận phản hồi
	RefreshEquipButton()
end

-- =========================================================
-- LIST MANAGEMENT
-- =========================================================

--- Dọn dẹp toàn bộ ItemFrame cũ trong ScrollingFrame
local function ClearItemList()
	StopStaggerAnimation()

	-- Hủy kết nối sự kiện click cũ
	for _, Conn in ipairs(_ListConnections) do
		if Conn and Conn.Connected then
			Conn:Disconnect()
		end
	end
	table.clear(_ListConnections)

	-- Xóa toàn bộ item đã render
	if not ScrollingFrame then return end
	for _, Child in ipairs(ScrollingFrame:GetChildren()) do
		if Child:IsA("GuiObject") and not Child:IsA("UIGridLayout") and not Child:IsA("UIListLayout") then
			GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(Child))
			ItemCard.Destroy(Child)
		end
	end
end

--- Render danh sách item vào ScrollingFrame theo ItemType
--- Chỉ hiển thị: item "Default" + item đã sở hữu (OwnedIcicles / OwnedBlocks)
--- @param ItemType string — "Icicle" hoặc "Block"
local function RenderList(ItemType)
	if not ScrollingFrame then
		warn("[InventoryController] Thiếu ScrollingFrame trong GUI.")
		return
	end

	ClearItemList()
	CleanViewport(SelectionViewport)
	_SelectedEntry = nil
	_SelectionModel = nil

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

	local SlotKey      = (ItemType == "Icicle") and "EquippedIcicle" or "EquippedIceBlock"
	local CurrentEquip = Data and Data[SlotKey] or "Default"

	local Catalog = (ItemType == "Icicle")
		and ItemRegistry.GetAllIcicles()
		or  ItemRegistry.GetAllBlocks()

	local LayoutOrder = 0
	local RenderedFrames = {}

	for _, Entry in ipairs(Catalog) do
		-- Chỉ hiển thị Default hoặc item đã sở hữu
		local IsDefault = (Entry.Id == "Default")
		local IsOwned   = OwnedSet[Entry.Id]
		if not IsDefault and not IsOwned then continue end

		local EntrySnapshot = Entry  -- closure capture
		local Frame = ItemCard.Create(ScrollingFrame, Entry.Id, Entry.Type, {
			LayoutOrder  = LayoutOrder,
			ShowEquipped = true,
			IsEquipped   = (Entry.Id == CurrentEquip),
			ShowDropRate = false,
			EnableHover  = true,
			OnClick      = function()
				SelectItem(EntrySnapshot)
			end,
		})

		if Frame then
			LayoutOrder += 1
			table.insert(RenderedFrames, Frame)
		end
	end

	-- Kích hoạt hiệu ứng xuất hiện lần lượt (Stagger Pop)
	_StaggerThread = GuiHelper.StaggerPopOpen(RenderedFrames)
end

-- =========================================================
-- TAB LOGIC
-- =========================================================

local function SwitchTab(ItemType)
	_CurrentTab = ItemType

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

	SwitchTab(_CurrentTab)

	-- Tải dữ liệu mới bất đồng bộ từ Server để hiển thị các skin mới nhất
	task.spawn(function()
		PlayerDataController.RefreshData()
		SwitchTab(_CurrentTab)
	end)
end

local function CloseInventory()
	if not Inventory then return end
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

	-- Đăng ký tab với MenuController
	local MenuCtrl = GetMenuController()
	if MenuCtrl then
		MenuCtrl.RegisterTab("Inventory", {
			Open  = OpenInventory,
			Close = CloseInventory,
			Frame = Inventory,
		})
	end

	-- Nút đóng Inventory
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			local MenuC = GetMenuController()
			if MenuC then
				MenuC.CloseCurrentTab()
			else
				CloseInventory()
			end
		end)
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

	-- Nút Equip: Kết nối click trang bị
	if EquipButton then
		EquipButton.MouseButton1Click:Connect(function()
			EquipCurrentItem()
		end)
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

function InventoryController:Start()
	local Module = script.Parent:FindFirstChild("MenuController")
	if Module then
		_MenuController = require(Module)
	end
end

return InventoryController

