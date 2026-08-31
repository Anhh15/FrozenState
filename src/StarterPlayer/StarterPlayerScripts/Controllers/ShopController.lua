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

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local RemoteDefinitions    = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig           = require(ReplicatedStorage.Shared.Config.GameConfig)
local ChestConfig          = require(ReplicatedStorage.Shared.Config.ChestConfig)
local ItemRegistry         = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig         = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ShopConfig           = require(ReplicatedStorage.Shared.Config.ShopConfig)
local ProductConfig        = require(ReplicatedStorage.Shared.Config.ProductConfig)
local AudioConfig          = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiConfig            = require(ReplicatedStorage.Shared.Config.GuiConfig)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ViewportManager      = require(ReplicatedStorage.Shared.Tools.ViewportManager)
local GuiHelper            = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local ItemCard             = require(ReplicatedStorage.Shared.Tools.ItemCard)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MenuGui = GuiHelper.GetScreenGui(GuiConfig.ScreenGuis.Menu)

-- Shop frame nằm bên trong Menu
local Shop = MenuGui and MenuGui:FindFirstChild(GuiConfig.MenuFrames.Shop, true)	

-- Các phần tử bên trong Shop
local ShopClose       = Shop and Shop:FindFirstChild(GuiConfig.ShopElements.CloseButton, true)
local TabContainer    = Shop and Shop:FindFirstChild(GuiConfig.ShopElements.TabContainer, true)
local IciclesTab      = TabContainer and TabContainer:FindFirstChild(GuiConfig.ShopElements.IciclesTab)
local BlocksTab       = TabContainer and TabContainer:FindFirstChild(GuiConfig.ShopElements.BlocksTab)
local RobuxTab        = TabContainer and TabContainer:FindFirstChild(GuiConfig.ShopElements.RobuxTab)
local ChestList       = Shop and Shop:FindFirstChild(GuiConfig.ShopElements.ChestList, true)
local ChestScroll     = ChestList and ChestList:FindFirstChildOfClass("ScrollingFrame")
local RobuxShopList   = Shop and Shop:FindFirstChild(GuiConfig.ShopElements.RobuxShopList, true)
local CurrencySection = RobuxShopList and RobuxShopList:FindFirstChild(GuiConfig.ShopElements.CurrencySection, true)

-- Template nằm trong Menu/Shop/Templates (không phải ReplicatedStorage)
local TemplatesFolder       = Shop and Shop:FindFirstChild("Templates")
local ChestPreviewTemplate  = TemplatesFolder and TemplatesFolder:FindFirstChild("ChestPreview")

-- Folder chứa model 3D rương
local Assets       = ReplicatedStorage:FindFirstChild("Assets")
local ChestsFolder = Assets and Assets:FindFirstChild("Chests")

-- =========================================================
-- STATE
-- =========================================================

local _CurrentTab       = "Icicle"  -- Tab đang hiển thị: "Icicle", "Block", hoặc "Robux"
local _ListConnections  = {}        -- Connections của ChestList cards (dọn khi re-render)
local _RobuxConnections = {}        -- Connections của Robux card buttons
local _PreviewStates    = {}        -- [Frame] = { Amount: number } — trạng thái per-card
local _LazyRenderQueue  = {}        -- { Frame, ChestEntry } — cards chờ render viewport
local _ProductInfoCache = {}        -- [ProductId] = ProductInfo dictionary (Cache giá động theo khu vực)
local _ScrollConn       = nil       -- Connection theo dõi ChestScroll.CanvasPosition
local _StaggerThread    = nil       -- Thread animation stagger danh sách rương

--- Dừng animation stagger đang chạy dở
local function StopStaggerAnimation()
	if _StaggerThread then
		task.cancel(_StaggerThread)
		_StaggerThread = nil
	end
end

--- Phát âm thanh GUI qua GuiHelper
local function PlayGuiSound(SoundId, Volume)
	GuiHelper.PlayGuiSound(SoundId, Volume)
end

--- Lấy thông tin sản phẩm và giá Robux động theo khu vực người chơi (có memory cache)
--- @param ProductId number
--- @param FallbackPrice number
--- @param Callback function(Price: number)
local function FetchDynamicProductPrice(ProductId, FallbackPrice, Callback)
	if not ProductId or ProductId <= 0 then
		Callback(FallbackPrice)
		return
	end

	-- 1. Đọc từ cache nếu đã fetch trước đó
	local Cached = _ProductInfoCache[ProductId]
	if Cached and Cached.PriceInRobux then
		Callback(Cached.PriceInRobux)
		return
	end

	-- 2. Fetch ngầm từ MarketplaceService (Regional Price)
	task.spawn(function()
		local Success, Result = pcall(function()
			return MarketplaceService:GetProductInfo(ProductId, Enum.InfoType.Product)
		end)

		if Success and Result and Result.PriceInRobux then
			_ProductInfoCache[ProductId] = Result
			Callback(Result.PriceInRobux)
		else
			-- Fallback về giá config nếu lỗi mạng hoặc timeout
			Callback(FallbackPrice)
		end
	end)
end

-- =========================================================
-- HELPERS
-- =========================================================

--- Lazy-require ItemRewardController để tránh circular dependency
local _ItemRewardController = nil
local function GetItemRewardController()
	if not _ItemRewardController then
		local Module = script.Parent:FindFirstChild("ItemRewardController")
		if Module then
			_ItemRewardController = require(Module)
		end
	end
	return _ItemRewardController
end

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
	if RobuxTab then
		RobuxTab.BackgroundColor3 = (ActiveTab == "Robux") and ActiveColor or InactiveColor
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
	if not ItemScroll then return end

	-- Dọn sạch item cũ (nếu có)
	for _, Child in ipairs(ItemScroll:GetChildren()) do
		if not Child:IsA("UIGridLayout") and not Child:IsA("UIListLayout") then
			ItemCard.Destroy(Child)
		end
	end

	for _, ItemEntry in ipairs(ChestEntry.Items) do
		ItemCard.Create(ItemScroll, ItemEntry.ItemId, ChestEntry.Type, {
			ShowDropRate = true,
			DropRate     = ItemEntry.DropRate,
			ShowEquipped = false,
			EnableHover  = false,
			EnableSound  = false,
		})
	end
end

-- =========================================================
-- LAZY RENDER
-- =========================================================

--- Kiểm tra queue và render các card đang nằm trong (hoặc gần) vùng nhìn thấy của ChestScroll
local function CheckLazyQueue()
	if not ChestScroll or #_LazyRenderQueue == 0 then return end

	local Buffer       = ShopConfig.LazyRenderBuffer
	local CanvasY      = ChestScroll.CanvasPosition.Y
	local ScrollHeight = ChestScroll.AbsoluteSize.Y
	local ScrollTop    = ChestScroll.AbsolutePosition.Y

	local VisibleTop    = CanvasY - Buffer
	local VisibleBottom = CanvasY + ScrollHeight + Buffer

	-- Duyệt ngược để an toàn khi xóa phần tử
	for Index = #_LazyRenderQueue, 1, -1 do
		local Entry = _LazyRenderQueue[Index]
		local Frame = Entry.Frame

		-- Nếu card đã bị destroy (ví dụ: đổi tab), bỏ qua
		if not Frame.Parent then
			table.remove(_LazyRenderQueue, Index)
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
			table.remove(_LazyRenderQueue, Index)
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
		PlayGuiSound(AudioConfig.Shop.ChestBuy)
		-- Kích hoạt hiệu ứng mở rương (phần thưởng đã được trao bởi server)
		local RewardCtrl = GetItemRewardController()
		if RewardCtrl and Result.ReceivedItems then
			RewardCtrl.ShowChestReward(Result.ReceivedItems, ChestEntry.Id)
		end
		task.spawn(function()
			PlayerDataController.RefreshData()
		end)
	else
		PlayGuiSound(AudioConfig.Shop.BuyFail)
	end
end

-- =========================================================
-- CHEST & ROBUX LIST RENDERING
-- =========================================================

--- Xóa toàn bộ nội dung ChestScroll và dọn connections + lazy state cũ
local function ClearChestList()
	StopStaggerAnimation()
	DisconnectAll(_ListConnections)
	DisconnectAll(_RobuxConnections)

	-- Ngắt connection theo dõi scroll
	if _ScrollConn and _ScrollConn.Connected then
		_ScrollConn:Disconnect()
		_ScrollConn = nil
	end

	-- Reset state per-card
	table.clear(_PreviewStates)
	table.clear(_LazyRenderQueue)

	-- Dọn card UI (giữ lại UIGridLayout/UIListLayout)
	if not ChestScroll then return end
	for _, Child in ipairs(ChestScroll:GetChildren()) do
		if not Child:IsA("UIGridLayout") and not Child:IsA("UIListLayout") then
			GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(Child))
			Child:Destroy()
		end
	end
end

--- Render danh sách rương theo Type ("Icicle" hoặc "Block")
--- @param Type string
local function RenderChestList(Type)
	ClearChestList()

	if RobuxShopList then
		RobuxShopList.Visible = false
	end
	if ChestList then
		ChestList.Visible = true
	end

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
	local RenderedCards = {}

	for _, ChestEntry in ipairs(Chests) do
		local Card = ChestPreviewTemplate:Clone()
		Card.Visible = true

		-- Khởi tạo trạng thái số lượng cho card này
		local State = { Amount = MinAmount }
		_PreviewStates[Card] = State

		-- Tìm các element bên trong card (search từ Card để không phụ thuộc vào nesting cụ thể)
		local ChestNameText     = Card:FindFirstChild(GuiConfig.ShopElements.ChestNameText,     true)
		local BuyButton         = Card:FindFirstChild(GuiConfig.ShopElements.BuyButton,         true)
		local AmountAlterButton = Card:FindFirstChild(GuiConfig.ShopElements.AmountAlterButton, true)

		-- Điền tên rương
		if ChestNameText then
			ChestNameText.Text = ChestEntry.Name
		end

		-- Helper cập nhật text BuyButton theo Amount hiện tại
		local function UpdateBuyText()
			if BuyButton then
				local BuyLabel = BuyButton:FindFirstChild("Text")
				if BuyLabel then
					BuyLabel.Text = GuiHelper.FormatNumber(ChestEntry.Price1 * State.Amount)
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
				PlayGuiSound(AudioConfig.Gui.Default.ButtonClick)
				State.Amount = (State.Amount % MaxAmount) + 1
				local AlterLabel = AmountAlterButton:FindFirstChild("Text")
				if AlterLabel then
					AlterLabel.Text = "x" .. tostring(State.Amount)
				end
				UpdateBuyText()
			end)
			table.insert(_ListConnections, Conn)
		end

		-- Kết nối BuyButton
		if BuyButton then
			local Conn = BuyButton.MouseButton1Click:Connect(function()
				ExecuteBuy(ChestEntry, State.Amount)
			end)
			table.insert(_ListConnections, Conn)
		end

		Card.Parent = ChestScroll
		table.insert(RenderedCards, Card)

		-- Đẩy vào lazy render queue (viewport chưa render)
		table.insert(_LazyRenderQueue, { Frame = Card, ChestEntry = ChestEntry })
	end

	-- Kích hoạt hiệu ứng xuất hiện lần lượt (Stagger Pop)
	_StaggerThread = GuiHelper.StaggerPopOpen(RenderedCards)

	-- Kết nối scroll để trigger lazy render khi cuộn
	_ScrollConn = ChestScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(CheckLazyQueue)
	table.insert(_ListConnections, _ScrollConn)

	-- Render ngay các card đang trong vùng nhìn thấy (không chờ người dùng scroll)
	-- Dùng task.defer để đảm bảo AbsolutePosition đã được tính bởi engine
	task.defer(CheckLazyQueue)
end

--- Render danh sách sản phẩm tiền tệ trong RobuxShopList (CurrencySection)
local function RenderRobuxShop()
	ClearChestList()

	if ChestList then
		ChestList.Visible = false
	end
	if RobuxShopList then
		RobuxShopList.Visible = true
	end

	if not CurrencySection then
		CurrencySection = RobuxShopList and RobuxShopList:FindFirstChild(GuiConfig.ShopElements.CurrencySection, true)
	end

	if not CurrencySection then
		warn("[ShopController] Không tìm thấy CurrencySection bên trong RobuxShopList.")
		return
	end

	for PackageKey, Package in pairs(ProductConfig.CurrencyPackages) do
		local PackageFrame = CurrencySection:FindFirstChild(PackageKey)
		if PackageFrame then
			local NameText   = PackageFrame:FindFirstChild(GuiConfig.ShopElements.NameText, true)
			local AmountText = PackageFrame:FindFirstChild(GuiConfig.ShopElements.AmountText, true)
			local GiftButton = PackageFrame:FindFirstChild(GuiConfig.ShopElements.GiftButton, true)
			local BuyButton  = PackageFrame:FindFirstChild(GuiConfig.ShopElements.BuyButton, true)

			if NameText then
				NameText.Text = Package.DisplayName
			end

			-- 1. Điền giá tức thì từ cache hoặc fallback từ config (0ms latency)
			local Cached = _ProductInfoCache[Package.ProductId]
			if Cached and Cached.PriceInRobux then
				if AmountText then
					AmountText.Text = GuiHelper.FormatNumber(Cached.PriceInRobux)
				end
			else
				if AmountText then
					AmountText.Text = GuiHelper.FormatNumber(Package.RobuxPrice)
				end

				-- 2. Fetch ngầm giá theo khu vực và cập nhật in-place khi nhận dữ liệu
				FetchDynamicProductPrice(Package.ProductId, Package.RobuxPrice, function(ActualPrice)
					if AmountText and AmountText.Parent then
						AmountText.Text = GuiHelper.FormatNumber(ActualPrice)
					end
				end)
			end

			if GiftButton then
				GiftButton.Visible = false
			end

			if BuyButton then
				local Conn = BuyButton.MouseButton1Click:Connect(function()
					PlayGuiSound(AudioConfig.Gui.Default.ButtonClick)
					MarketplaceService:PromptProductPurchase(LocalPlayer, Package.ProductId)
				end)
				table.insert(_RobuxConnections, Conn)
			end
		end
	end
end

local function OpenShop()
	if not Shop then return end
	_CurrentTab = "Icicle"
	UpdateTabHighlight("Icicle")
	RenderChestList("Icicle")
end

local function CloseShop()
	if not Shop then return end
	ClearChestList()
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local ShopController = {}

--- Đặt Visible cho Shop frame qua MenuController
--- @param Visible boolean
function ShopController.SetVisible(Visible)
	if not Shop then return end
	local MenuCtrl = GetMenuController()
	if Visible then
		if MenuCtrl then
			MenuCtrl.OpenTab("Shop")
		else
			OpenShop()
		end
	else
		if MenuCtrl then
			MenuCtrl.CloseTab("Shop")
		else
			CloseShop()
		end
	end
end

function ShopController:Init()
	if not Shop then
		warn("[ShopController] Không tìm thấy Shop frame trong Menu GUI. Kiểm tra lại tên GUI.")
		return
	end

	-- Shop bắt đầu ẩn
	Shop.Visible = false

	-- Đăng ký tab với MenuController
	local MenuCtrl = GetMenuController()
	if MenuCtrl then
		MenuCtrl.RegisterTab("Shop", {
			Open  = OpenShop,
			Close = CloseShop,
			Frame = Shop,
		})
	end

	-- ─── AUTO BIND BUTTONS (Scale & SFX cho toàn bộ nút trong Shop) ─────────
	if TemplatesFolder then
		GuiHelper.SetIgnoreAutoBind(TemplatesFolder, true)
	end

	if Shop then
		GuiHelper.AutoBindButtons(Shop, { MenuName = "Shop" })
	end

	-- ─── CLOSE BUTTON (đóng toàn bộ Shop) ──────────────────────────
	if ShopClose then
		ShopClose.MouseButton1Click:Connect(function()
			local MenuC = GetMenuController()
			if MenuC then
				MenuC.CloseCurrentTab()
			else
				CloseShop()
			end
		end)
	end

	-- ─── TAB CONTAINER ───────────────────────────────────────
	if IciclesTab then
		IciclesTab.MouseButton1Click:Connect(function()
			if _CurrentTab == "Icicle" then return end
			_CurrentTab = "Icicle"
			UpdateTabHighlight("Icicle")
			RenderChestList("Icicle")
		end)
	end

	if BlocksTab then
		BlocksTab.MouseButton1Click:Connect(function()
			if _CurrentTab == "Block" then return end
			_CurrentTab = "Block"
			UpdateTabHighlight("Block")
			RenderChestList("Block")
		end)
	end

	if RobuxTab then
		RobuxTab.MouseButton1Click:Connect(function()
			if _CurrentTab == "Robux" then return end
			_CurrentTab = "Robux"
			UpdateTabHighlight("Robux")
			RenderRobuxShop()
		end)
	end

	-- ─── MARKETPLACE SERVICE: MUA PRODUCT THÀNH CÔNG (CLIENT FEEDBACK) ────
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(UserId, ProductId, IsPurchased)
		if UserId == LocalPlayer.UserId and IsPurchased then
			PlayGuiSound(AudioConfig.Shop.ChestBuy)
			task.spawn(function()
				PlayerDataController.RefreshData()
			end)
		end
	end)

	-- Highlight tab mặc định
	UpdateTabHighlight("Icicle")

	print("[ShopController] Đã khởi tạo.")
end

return ShopController
