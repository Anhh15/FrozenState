-- ShopController.lua (ModuleScript)
-- Điều khiển toàn bộ Shop GUI: hiển thị rương theo tab, preview vật phẩm, mua rương
-- Chỉ hiển thị trong Lobby phase (GameStateController sẽ ẩn khi vào trận)

-- Cấu trúc GUI mong đợi (StarterGui/Menu/Shop):
--   Shop (Frame)
--     CloseButton       (ImageButton) — đóng toàn bộ Shop
--     TabContainer      (Frame)
--       IciclesTab      (ImageButton)
--       BlocksTab       (ImageButton)
--     ChestList         (Frame)
--       ScrollingFrame  (ScrollingFrame) — UIGridLayout đã có sẵn trong Studio
--     Templates         (Folder)
--       ChestPreview    (Frame) — template card, Visible = false
--         ChestViewport (ViewportFrame) — hiển thị model 3D rương
--         ItemPreview   (Frame)
--           ScrollingFrame (ScrollingFrame) — UIGridLayout — hiển thị danh sách item
--           BuyButton      (ImageButton) — nút mua, text = giá tổng
--           AmountAlterButton (ImageButton) — nút tùy chỉnh số lượng, text = "x[N]"
--           ChestNameText  (TextLabel) — tên rương

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions    = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local ChestConfig          = require(ReplicatedStorage.Shared.Config.ChestConfig)
local ItemRegistry         = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig         = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ShopConfig           = require(ReplicatedStorage.Shared.Config.ShopConfig)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ViewportManager      = require(ReplicatedStorage.Shared.Tools.ViewportManager)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MenuGui = PlayerGui:WaitForChild("Menu", 10)
local NavGui  = PlayerGui:WaitForChild("NavigationButton", 10)

-- Shop frame nằm bên trong Menu
local Shop = MenuGui and MenuGui:FindFirstChild("Shop", true)	

-- Các phần tử bên trong Shop
local ShopClose    = Shop and Shop:FindFirstChild("CloseButton", true)
local TabContainer = Shop and Shop:FindFirstChild("TabContainer", true)
local IciclesTab   = TabContainer and TabContainer:FindFirstChild("IciclesTab")
local BlocksTab    = TabContainer and TabContainer:FindFirstChild("BlocksTab")
local ChestList    = Shop and Shop:FindFirstChild("ChestList", true)
local ChestScroll  = ChestList and ChestList:FindFirstChildOfClass("ScrollingFrame")

-- Template nằm trong Menu/Shop/Templates (không phải ReplicatedStorage)
local TemplatesFolder       = Shop and Shop:FindFirstChild("Templates")
local ChestPreviewTemplate  = TemplatesFolder and TemplatesFolder:FindFirstChild("ChestPreview")

-- ItemTemplate dùng chung từ ReplicatedStorage/Assets/Gui
local Assets       = ReplicatedStorage:FindFirstChild("Assets")
local GuiFolder    = Assets and (Assets:FindFirstChild("Gui") or Assets:FindFirstChild("GUI"))
local ItemTemplate = GuiFolder and GuiFolder:FindFirstChild("ItemTemplate")

-- Folder chứa model 3D rương
local ChestsFolder = Assets and Assets:FindFirstChild("Chests")

-- Nút mở Shop trong NavigationButton
local ShopNavButton = NavGui and NavGui:FindFirstChild("Shop", true)

-- Frame Button bên trong NavigationButton (ẩn khi Shop mở, Stats vẫn hiện)
local NavButton = NavGui and NavGui:FindFirstChild("Button")

-- =========================================================
-- STATE
-- =========================================================

local _currentTab      = "Icicle"  -- Tab đang hiển thị: "Icicle" hoặc "Block"
local _listConnections = {}        -- Connections của ChestList cards (dọn khi re-render)
local _previewStates   = {}        -- [Frame] = { Amount: number } — trạng thái per-card
local _lazyRenderQueue = {}        -- { Frame, ChestEntry } — cards chờ render viewport
local _scrollConn      = nil       -- Connection theo dõi ChestScroll.CanvasPosition

-- =========================================================
-- SFX
-- =========================================================

local SFX_BUTTON_CLICK       = 7249903719
local SFX_CLOSE_BUTTON_CLICK = 103307955424380
local SFX_CHEST_BUY          = 113890702074571
local SFX_BUY_FAIL           = 128827503277042

local function PlayGuiSound(SoundId, Volume)
	local S = Instance.new("Sound")
	S.SoundId = "rbxassetid://" .. tostring(SoundId)
	S.Volume = Volume or 1
	S.Parent = PlayerGui
	S:Play()
	game:GetService("Debris"):AddItem(S, 3)
end

-- =========================================================
-- HELPERS
-- =========================================================

--- Lazy-require ItemRewardController để tránh circular dependency
local _itemRewardController = nil
local function GetItemRewardController()
	if not _itemRewardController then
		local Module = script.Parent:FindFirstChild("ItemRewardController")
		if Module then
			_itemRewardController = require(Module)
		end
	end
	return _itemRewardController
end

--- Lazy-require SpectateController để tránh circular dependency
local _spectateController = nil
local function GetSpectateController()
	if not _spectateController then
		local Module = script.Parent:FindFirstChild("SpectateController")
		if Module then
			_spectateController = require(Module)
		end
	end
	return _spectateController
end

--- Ẩn tất cả Frame con trong Menu ngoại trừ Shop
local function HideAllMenuFrames()
	if not MenuGui then return end
	for _, Child in ipairs(MenuGui:GetChildren()) do
		if Child:IsA("Frame") and Child ~= Shop then
			Child.Visible = false
		end
	end
end

--- Dọn dẹp ViewportFrame tránh memory leak (cả Camera lẫn Model)
--- Ủy quyền cho ViewportManager thay vì giữ lại Camera tĩnh cũ
local function CleanViewport(Viewport)
	ViewportManager.CleanViewport(Viewport)
end

--- Disconnect và xóa danh sách connections
local function DisconnectAll(ConnectionList)
	for _, Conn in ipairs(ConnectionList) do
		if Conn and Conn.Connected then
			Conn:Disconnect()
		end
	end
	table.clear(ConnectionList)
end

--- Cập nhật highlight tab active (BackgroundColor3)
local function UpdateTabHighlight(ActiveTab)
	local ActiveColor   = Color3.fromHex("FFFFFF")  -- Trắng = active
	local InactiveColor = Color3.fromHex("2F2F2F")  -- Xám   = inactive
	if IciclesTab then
		IciclesTab.BackgroundColor3 = (ActiveTab == "Icicle") and ActiveColor or InactiveColor
	end
	if BlocksTab then
		BlocksTab.BackgroundColor3 = (ActiveTab == "Block") and ActiveColor or InactiveColor
	end
end

--- Clone model Chest vào ViewportFrame và tự động tạo camera theo Bounding Box
--- @param Viewport  ViewportFrame
--- @param ChestId   string
local function LoadChestModel(Viewport, ChestId)
	CleanViewport(Viewport)
	if not ChestsFolder then return end
	local Model = ChestsFolder:FindFirstChild(ChestId)
	if not Model then
		warn(("[ShopController] Không tìm thấy Chest model '%s' trong Assets/Chests."):format(ChestId))
		return
	end
	local Clone = Model:Clone()
	Clone.Parent = Viewport

	-- Tạo camera tự động dựa trên Bounding Box và cấu hình ViewportConfig
	ViewportManager.RenderItem(Viewport, Clone, "Chest", ChestId)
end

--- Render danh sách item vào ItemPreview/ScrollingFrame của một card
--- @param Card        Frame  — ChestPreview card
--- @param ChestEntry  table  — entry từ ChestConfig
local function LoadItemPreviews(Card, ChestEntry)
	local ItemPreview  = Card:FindFirstChild("ItemPreview", true)
	local ItemScroll   = ItemPreview and ItemPreview:FindFirstChildOfClass("ScrollingFrame")
	if not ItemScroll or not ItemTemplate then return end

	-- Dọn sạch item cũ (nếu có)
	for _, Child in ipairs(ItemScroll:GetChildren()) do
		if not Child:IsA("UIGridLayout") and not Child:IsA("UIListLayout") then
			Child:Destroy()
		end
	end

	for _, ItemEntry in ipairs(ChestEntry.Items) do
		-- Lấy thông tin đầy đủ từ ItemRegistry
		local FullEntry   = ItemRegistry.GetItem(ItemEntry.ItemId, ChestEntry.Type)
		local RarityEntry = RarityConfig[FullEntry.Rarity]

		local Frame = ItemTemplate:Clone()
		Frame.Visible = true

		-- Cập nhật các label
		local NameText    = Frame:FindFirstChild("NameText",     true)
		local RarityText  = Frame:FindFirstChild("RarityText",   true)
		local DropText    = Frame:FindFirstChild("DropRateText", true)
		local Background  = Frame:FindFirstChild("Background",   true)
		local EquippedTag = Frame:FindFirstChild("EquippedText", true) or Frame:FindFirstChild("Equipped", true)

		if NameText   then NameText.Text  = FullEntry.Name end
		if RarityText then
			RarityText.Text = FullEntry.Rarity
			if RarityEntry then
				RarityText.TextColor3 = RarityEntry.Color
			end
		end
		if DropText then
			DropText.Visible = true
			DropText.Text    = ("%d%%"):format(ItemEntry.DropRate)
		end
		if EquippedTag then
			EquippedTag.Visible = false
		end
		if Background and RarityEntry then
			Background.Image = RarityEntry.ImageId
		end

		-- Render item model vào ItemViewport (nếu có)
		local ItemViewport = Frame:FindFirstChild("ItemViewport", true)
		if ItemViewport then
			CleanViewport(ItemViewport)
			local ItemPreviewFolder = ReplicatedStorage:FindFirstChild("Assets")
				and ReplicatedStorage.Assets:FindFirstChild("ItemPreview")
				and ReplicatedStorage.Assets.ItemPreview:FindFirstChild(
					ChestEntry.Type == "Icicle" and "Icicles" or "Blocks"
				)
			if ItemPreviewFolder then
				local ItemModel = ItemPreviewFolder:FindFirstChild(FullEntry.Id)
				if ItemModel then
					local Clone = ItemModel:Clone()
					Clone.Parent = ItemViewport
					ViewportManager.RenderItem(ItemViewport, Clone, FullEntry.Type, FullEntry.Id)
				end
			end
		end

		Frame.Parent = ItemScroll
	end
end

-- =========================================================
-- LAZY RENDER
-- =========================================================

--- Kiểm tra queue và render các card đang nằm trong (hoặc gần) vùng nhìn thấy của ChestScroll
local function CheckLazyQueue()
	if not ChestScroll or #_lazyRenderQueue == 0 then return end

	local Buffer       = ShopConfig.LazyRenderBuffer
	local CanvasY      = ChestScroll.CanvasPosition.Y
	local ScrollHeight = ChestScroll.AbsoluteSize.Y
	local ScrollTop    = ChestScroll.AbsolutePosition.Y

	local VisibleTop    = CanvasY - Buffer
	local VisibleBottom = CanvasY + ScrollHeight + Buffer

	-- Duyệt ngược để an toàn khi xóa phần tử
	for Index = #_lazyRenderQueue, 1, -1 do
		local Entry = _lazyRenderQueue[Index]
		local Frame = Entry.Frame

		-- Nếu card đã bị destroy (ví dụ: đổi tab), bỏ qua
		if not Frame.Parent then
			table.remove(_lazyRenderQueue, Index)
			continue
		end

		-- Tính vị trí card trong canvas coordinate
		local CardTop    = Frame.AbsolutePosition.Y - ScrollTop + CanvasY
		local CardBottom = CardTop + Frame.AbsoluteSize.Y

		if CardBottom >= VisibleTop and CardTop <= VisibleBottom then
			-- Card trong vùng nhìn thấy → render
			local ChestView = Frame:FindFirstChild("ChestViewport", true)
			if ChestView then
				LoadChestModel(ChestView, Entry.ChestEntry.Id)
			end
			LoadItemPreviews(Frame, Entry.ChestEntry)
			table.remove(_lazyRenderQueue, Index)
		end
	end
end

-- =========================================================
-- BUY LOGIC
-- =========================================================

--- Thực hiện mua rương với số lượng đã chọn
--- @param ChestEntry table  — entry từ ChestConfig
--- @param Amount     number — số lượng (1–5)
local function ExecuteBuy(ChestEntry, Amount)
	local BuyChestFn = RemoteDefinitions.GetFunction("BuyChest")
	local Result = BuyChestFn:InvokeServer(ChestEntry.Id, Amount)

	if Result and Result.Success then
		PlayGuiSound(SFX_CHEST_BUY, 10)
		-- Kích hoạt hiệu ứng mở rương (phần thưởng đã được trao bởi server)
		local RewardCtrl = GetItemRewardController()
		if RewardCtrl and Result.ReceivedItems then
			RewardCtrl.ShowChestReward(Result.ReceivedItems, ChestEntry.Id)
		end
		task.spawn(function()
			PlayerDataController.RefreshData()
		end)
	else
		PlayGuiSound(SFX_BUY_FAIL)
	end
end

-- =========================================================
-- CHEST LIST RENDERING
-- =========================================================

--- Xóa toàn bộ nội dung ChestScroll và dọn connections + lazy state cũ
local function ClearChestList()
	DisconnectAll(_listConnections)

	-- Ngắt connection theo dõi scroll
	if _scrollConn and _scrollConn.Connected then
		_scrollConn:Disconnect()
		_scrollConn = nil
	end

	-- Reset state per-card
	table.clear(_previewStates)
	table.clear(_lazyRenderQueue)

	-- Dọn card UI (giữ lại UIGridLayout/UIListLayout)
	if not ChestScroll then return end
	for _, Child in ipairs(ChestScroll:GetChildren()) do
		if not Child:IsA("UIGridLayout") and not Child:IsA("UIListLayout") then
			Child:Destroy()
		end
	end
end

--- Render danh sách rương theo Type ("Icicle" hoặc "Block")
--- @param Type string
local function RenderChestList(Type)
	ClearChestList()

	if not ChestScroll then
		warn("[ShopController] Thiếu ChestScroll — không thể render danh sách rương.")
		return
	end
	if not ChestPreviewTemplate then
		warn("[ShopController] Thiếu ChestPreview template trong Menu/Shop/Templates — không thể render.")
		return
	end

	local MinAmount = ShopConfig.MinAmount
	local MaxAmount = ShopConfig.MaxAmount

	local Chests = ChestConfig.GetChestsByType(Type)

	for _, ChestEntry in ipairs(Chests) do
		local Card = ChestPreviewTemplate:Clone()
		Card.Visible = true

		-- Khởi tạo trạng thái số lượng cho card này
		local State = { Amount = MinAmount }
		_previewStates[Card] = State

		-- Tìm các element bên trong card (search từ Card để không phụ thuộc vào nesting cụ thể)
		local ChestNameText     = Card:FindFirstChild("ChestNameText",     true)
		local BuyButton         = Card:FindFirstChild("BuyButton",         true)
		local AmountAlterButton = Card:FindFirstChild("AmountAlterButton", true)

		-- Điền tên rương
		if ChestNameText then
			ChestNameText.Text = ChestEntry.Name
		end

		-- Helper cập nhật text BuyButton theo Amount hiện tại
		local function UpdateBuyText()
			if BuyButton then
				local BuyLabel = BuyButton:FindFirstChild("Text")
				if BuyLabel then
					BuyLabel.Text = tostring(ChestEntry.Price1 * State.Amount)
				end
			end
		end

		-- Cập nhật text ban đầu
		if AmountAlterButton then
			local AlterLabel = AmountAlterButton:FindFirstChild("Text")
			if AlterLabel then
				AlterLabel.Text = "x" .. tostring(State.Amount)
			end
		end
		UpdateBuyText()

		-- Kết nối AmountAlterButton: vòng lặp MinAmount → MaxAmount → MinAmount
		if AmountAlterButton then
			local Conn = AmountAlterButton.MouseButton1Click:Connect(function()
				PlayGuiSound(SFX_BUTTON_CLICK)
				State.Amount = (State.Amount % MaxAmount) + 1
				local AlterLabel = AmountAlterButton:FindFirstChild("Text")
				if AlterLabel then
					AlterLabel.Text = "x" .. tostring(State.Amount)
				end
				UpdateBuyText()
			end)
			table.insert(_listConnections, Conn)
		end

		-- Kết nối BuyButton
		if BuyButton then
			local Conn = BuyButton.MouseButton1Click:Connect(function()
				ExecuteBuy(ChestEntry, State.Amount)
			end)
			table.insert(_listConnections, Conn)
		end

		Card.Parent = ChestScroll

		-- Đẩy vào lazy render queue (viewport chưa render)
		table.insert(_lazyRenderQueue, { Frame = Card, ChestEntry = ChestEntry })
	end

	-- Kết nối scroll để trigger lazy render khi cuộn
	_scrollConn = ChestScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(CheckLazyQueue)
	table.insert(_listConnections, _scrollConn)

	-- Render ngay các card đang trong vùng nhìn thấy (không chờ người dùng scroll)
	-- Dùng task.defer để đảm bảo AbsolutePosition đã được tính bởi engine
	task.defer(CheckLazyQueue)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local ShopController = {}

--- Đặt Visible cho Shop frame
--- @param Visible boolean
function ShopController.SetVisible(Visible)
	if not Shop then return end
	if Visible then
		-- Ẩn các Frame Menu anh em và NavButton trước khi mở Shop
		HideAllMenuFrames()
		if NavButton then NavButton.Visible = false end
	else
		-- Dọn dẹp lazy render khi đóng
		ClearChestList()
		-- Khôi phục NavButton trừ khi đang spectate
		if NavButton then
			local SpecCtrl = GetSpectateController()
			local IsSpectating = SpecCtrl and SpecCtrl.IsSpectating and SpecCtrl.IsSpectating()
			NavButton.Visible = not IsSpectating
		end
	end
	Shop.Visible = Visible
end

function ShopController:Init()
	if not Shop then
		warn("[ShopController] Không tìm thấy Shop frame trong Menu GUI. Kiểm tra lại tên GUI.")
		return
	end

	-- Ngăn GUI reset khi player chết
	if MenuGui then
		MenuGui.ResetOnSpawn = false
	end

	-- Shop bắt đầu ẩn
	Shop.Visible = false

	-- ─── CLOSE BUTTON (đóng toàn bộ Shop) ──────────────────────────
	if ShopClose then
		ShopClose.MouseButton1Click:Connect(function()
			PlayGuiSound(SFX_CLOSE_BUTTON_CLICK)
			ShopController.SetVisible(false)
		end)
	end

	-- ─── TAB CONTAINER ───────────────────────────────────────
	if IciclesTab then
		IciclesTab.MouseButton1Click:Connect(function()
			if _currentTab == "Icicle" then return end
			PlayGuiSound(SFX_BUTTON_CLICK)
			_currentTab = "Icicle"
			UpdateTabHighlight("Icicle")
			RenderChestList("Icicle")
		end)
	end

	if BlocksTab then
		BlocksTab.MouseButton1Click:Connect(function()
			if _currentTab == "Block" then return end
			PlayGuiSound(SFX_BUTTON_CLICK)
			_currentTab = "Block"
			UpdateTabHighlight("Block")
			RenderChestList("Block")
		end)
	end

	-- ─── NAVIGATION BUTTON MỞ SHOP ───────────────────────────
	if ShopNavButton then
		local NavBtn = ShopNavButton:IsA("GuiButton")
			and ShopNavButton
			or ShopNavButton:FindFirstChildOfClass("ImageButton")
			or ShopNavButton:FindFirstChildOfClass("TextButton")
		if NavBtn then
			NavBtn.MouseButton1Click:Connect(function()
				-- Toggle: nếu đang mở thì đóng, ngược lại mở
				local IsOpen = Shop.Visible
				ShopController.SetVisible(not IsOpen)
				if not IsOpen then
					-- Mở Shop: reset về tab mặc định và render
					_currentTab = "Icicle"
					UpdateTabHighlight("Icicle")
					RenderChestList("Icicle")
				end
			end)
		end
	end

	-- Highlight tab mặc định
	UpdateTabHighlight("Icicle")

	print("[ShopController] Đã khởi tạo.")
end

return ShopController
