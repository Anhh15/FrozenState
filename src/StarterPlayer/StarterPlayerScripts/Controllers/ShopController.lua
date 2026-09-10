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
--         ChestIcon     (ImageLabel) — hiển thị icon 2D rương
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
local GuiHelper            = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local ItemCard             = require(ReplicatedStorage.Shared.Tools.ItemCard)

-- =========================================================
-- GUI REFERENCES (Được nạp an toàn trong Init)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _MenuGui              = nil
local Shop                 = nil
local ShopClose            = nil
local TabContainer         = nil
local IciclesTab           = nil
local BlocksTab            = nil
local RobuxTab             = nil
local ChestList            = nil
local ChestScroll          = nil
local RobuxShopList        = nil
local CurrencySection      = nil
local GamePassSection      = nil
local TemplatesFolder      = nil
local ChestPreviewTemplate = nil

-- =========================================================
-- STATE
-- =========================================================

local _CurrentTab       = "Icicle"  -- Tab đang hiển thị: "Icicle", "Block", hoặc "Robux"
local _ListConnections  = {}        -- Connections của ChestList cards (dọn khi re-render)
local _RobuxConnections = {}        -- Connections của Robux card buttons
local _PreviewStates    = {}        -- [Frame] = { Amount: number } — trạng thái per-card
local _ProductInfoCache = {}        -- [ProductId / CacheKey] = ProductInfo dictionary (Cache giá động theo khu vực)
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

--- Lấy thông tin GamePass và giá Robux động theo khu vực người chơi (có memory cache)
--- @param PassId number
--- @param FallbackPrice number
--- @param Callback function(Price: number)
local function FetchDynamicGamePassPrice(PassId, FallbackPrice, Callback)
	if not PassId or PassId <= 0 then
		Callback(FallbackPrice)
		return
	end

	-- 1. Đọc từ cache nếu đã fetch trước đó
	local CacheKey = "GP_" .. tostring(PassId)
	local Cached = _ProductInfoCache[CacheKey]
	if Cached and Cached.PriceInRobux then
		Callback(Cached.PriceInRobux)
		return
	end

	-- 2. Fetch ngầm từ MarketplaceService (Regional Price cho GamePass)
	task.spawn(function()
		local Success, Result = pcall(function()
			return MarketplaceService:GetProductInfo(PassId, Enum.InfoType.GamePass)
		end)

		if Success and Result and Result.PriceInRobux then
			_ProductInfoCache[CacheKey] = Result
			Callback(Result.PriceInRobux)
		else
			Callback(FallbackPrice)
		end
	end)
end

-- =========================================================
-- HELPERS
-- =========================================================

--- Tham chiếu ItemRewardController & MenuController được nạp trực tiếp trong Start()
local _ItemRewardController = nil
local _MenuController       = nil

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

--- Render 2D Icon của rương vào ChestIcon ImageLabel
--- @param Card        Frame — ChestPreview card
--- @param ChestEntry  table — entry từ ChestConfig
local function LoadChestIcon(Card, ChestEntry)
	local ChestIcon = Card:FindFirstChild(GuiConfig.ShopElements.ChestIcon, true)
	if ChestIcon and ChestIcon:IsA("ImageLabel") then
		ChestIcon.Image = ChestConfig.GetChestIcon(ChestEntry.Id)
	end
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
		if _ItemRewardController and Result.ReceivedItems then
			_ItemRewardController.ShowChestReward(Result.ReceivedItems, ChestEntry.Id)
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

--- Xóa toàn bộ nội dung ChestScroll và dọn connections cũ
local function ClearChestList()
	StopStaggerAnimation()
	DisconnectAll(_ListConnections)
	DisconnectAll(_RobuxConnections)

	-- Reset state per-card
	table.clear(_PreviewStates)

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

		-- Nạp trực tiếp 2D Icon rương và previews item
		LoadChestIcon(Card, ChestEntry)
		LoadItemPreviews(Card, ChestEntry)

		Card.Parent = ChestScroll
		table.insert(RenderedCards, Card)
	end

	-- Kích hoạt hiệu ứng xuất hiện lần lượt (Stagger Pop)
	_StaggerThread = GuiHelper.StaggerPopOpen(RenderedCards)
end

--- Render danh sách sản phẩm trong RobuxShopList (GamePassSection + CurrencySection)
local function RenderRobuxShop()
	ClearChestList()

	if ChestList then
		ChestList.Visible = false
	end
	if RobuxShopList then
		RobuxShopList.Visible = true
	end

	DisconnectAll(_RobuxConnections)

	-- 1. ─── GAMEPASS SECTION ─────────────────────────────────────
	if not GamePassSection then
		GamePassSection = RobuxShopList and RobuxShopList:FindFirstChild(GuiConfig.ShopElements.GamePassSection, true)
	end

	if GamePassSection then
		for PassKey, PassConfig in pairs(ProductConfig.GamePasses) do
			local PassFrame = GamePassSection:FindFirstChild(PassKey)
			if PassFrame then
				local AmountText = PassFrame:FindFirstChild(GuiConfig.ShopElements.AmountText, true)
				local GiftButton = PassFrame:FindFirstChild(GuiConfig.ShopElements.GiftButton, true)
				local BuyButton  = PassFrame:FindFirstChild(GuiConfig.ShopElements.BuyButton, true)
				local BuyFrame   = PassFrame:FindFirstChild(GuiConfig.ShopElements.BuyFrame, true)

				-- Không đổi NameText để bảo toàn 100% thiết kế Studio

				-- Điền giá tức thì từ cache hoặc fallback từ config (0ms latency)
				local CacheKey = "GP_" .. tostring(PassConfig.PassId)
				local Cached = _ProductInfoCache[CacheKey]
				if Cached and Cached.PriceInRobux then
					if AmountText then
						AmountText.Text = GuiHelper.FormatNumber(Cached.PriceInRobux)
					end
				else
					if AmountText then
						AmountText.Text = GuiHelper.FormatNumber(PassConfig.RobuxPrice)
					end

					-- Fetch ngầm giá theo khu vực và cập nhật in-place khi nhận dữ liệu
					FetchDynamicGamePassPrice(PassConfig.PassId, PassConfig.RobuxPrice, function(ActualPrice)
						if AmountText and AmountText.Parent then
							AmountText.Text = GuiHelper.FormatNumber(ActualPrice)
						end
					end)
				end

				if GiftButton then
					GiftButton.Visible = false
				end

				local TargetClickable = BuyButton or (BuyFrame and BuyFrame:IsA("GuiButton") and BuyFrame)
				if TargetClickable then
					local Conn = TargetClickable.MouseButton1Click:Connect(function()
						PlayGuiSound(AudioConfig.Gui.Default.ButtonClick)
						if PassConfig.PassId and PassConfig.PassId > 0 then
							MarketplaceService:PromptGamePassPurchase(LocalPlayer, PassConfig.PassId)
						else
							warn(("[ShopController] PassId cho '%s' chưa được cấu hình (PassId = 0)."):format(PassKey))
						end
					end)
					table.insert(_RobuxConnections, Conn)
				end
			end
		end
	end

	-- 2. ─── CURRENCY SECTION ─────────────────────────────────────
	if not CurrencySection then
		CurrencySection = RobuxShopList and RobuxShopList:FindFirstChild(GuiConfig.ShopElements.CurrencySection, true)
	end

	if CurrencySection then
		for PackageKey, Package in pairs(ProductConfig.CurrencyPackages) do
			local PackageFrame = CurrencySection:FindFirstChild(PackageKey)
			if PackageFrame then
				local AmountText = PackageFrame:FindFirstChild(GuiConfig.ShopElements.AmountText, true)
				local GiftButton = PackageFrame:FindFirstChild(GuiConfig.ShopElements.GiftButton, true)
				local BuyButton  = PackageFrame:FindFirstChild(GuiConfig.ShopElements.BuyButton, true)
				local BuyFrame   = PackageFrame:FindFirstChild(GuiConfig.ShopElements.BuyFrame, true)

				-- Không đổi NameText theo code nữa để giữ nguyên thiết kế Studio

				-- Điền giá tức thì từ cache hoặc fallback từ config (0ms latency)
				local Cached = _ProductInfoCache[Package.ProductId]
				if Cached and Cached.PriceInRobux then
					if AmountText then
						AmountText.Text = GuiHelper.FormatNumber(Cached.PriceInRobux)
					end
				else
					if AmountText then
						AmountText.Text = GuiHelper.FormatNumber(Package.RobuxPrice)
					end

					-- Fetch ngầm giá theo khu vực và cập nhật in-place khi nhận dữ liệu
					FetchDynamicProductPrice(Package.ProductId, Package.RobuxPrice, function(ActualPrice)
						if AmountText and AmountText.Parent then
							AmountText.Text = GuiHelper.FormatNumber(ActualPrice)
						end
					end)
				end

				if GiftButton then
					GiftButton.Visible = false
				end

				local TargetClickable = BuyButton or (BuyFrame and BuyFrame:IsA("GuiButton") and BuyFrame)
				if TargetClickable then
					local Conn = TargetClickable.MouseButton1Click:Connect(function()
						PlayGuiSound(AudioConfig.Gui.Default.ButtonClick)
						MarketplaceService:PromptProductPurchase(LocalPlayer, Package.ProductId)
					end)
					table.insert(_RobuxConnections, Conn)
				end
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
	if Visible then
		if _MenuController then
			_MenuController.OpenTab("Shop")
		else
			OpenShop()
		end
	else
		if _MenuController then
			_MenuController.CloseTab("Shop")
		else
			CloseShop()
		end
	end
end

function ShopController:Init()
	_MenuGui = GuiHelper.GetScreenGui(GuiConfig.ScreenGuis.Menu, GuiConfig.Timeouts.DefaultWaitForGui)
	if not _MenuGui then
		warn("[ShopController] Không tìm thấy ScreenGui 'Menu'.")
		return
	end

	Shop = _MenuGui:FindFirstChild(GuiConfig.MenuFrames.Shop, true)
		or _MenuGui:WaitForChild(GuiConfig.MenuFrames.Shop, GuiConfig.Timeouts.ShortWait)
	if not Shop then
		warn("[ShopController] Không tìm thấy Shop frame trong Menu GUI. Kiểm tra lại tên GUI.")
		return
	end

	ShopClose       = Shop:FindFirstChild(GuiConfig.ShopElements.CloseButton, true)
	TabContainer    = Shop:FindFirstChild(GuiConfig.ShopElements.TabContainer, true)
	IciclesTab      = TabContainer and TabContainer:FindFirstChild(GuiConfig.ShopElements.IciclesTab)
	BlocksTab       = TabContainer and TabContainer:FindFirstChild(GuiConfig.ShopElements.BlocksTab)
	RobuxTab        = TabContainer and TabContainer:FindFirstChild(GuiConfig.ShopElements.RobuxTab)
	ChestList       = Shop:FindFirstChild(GuiConfig.ShopElements.ChestList, true)
	ChestScroll     = ChestList and ChestList:FindFirstChildOfClass("ScrollingFrame")
	RobuxShopList   = Shop:FindFirstChild(GuiConfig.ShopElements.RobuxShopList, true)
	CurrencySection = RobuxShopList and RobuxShopList:FindFirstChild(GuiConfig.ShopElements.CurrencySection, true)
	GamePassSection = RobuxShopList and RobuxShopList:FindFirstChild(GuiConfig.ShopElements.GamePassSection, true)

	TemplatesFolder      = Shop:FindFirstChild("Templates")
	ChestPreviewTemplate = TemplatesFolder and TemplatesFolder:FindFirstChild("ChestPreview")

	-- Shop bắt đầu ẩn
	Shop.Visible = false

	-- ─── CLOSE BUTTON (đóng toàn bộ Shop) ──────────────────────────
	if ShopClose then
		ShopClose.MouseButton1Click:Connect(function()
			if _MenuController then
				_MenuController.CloseCurrentTab()
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

	-- Highlight tab mặc định
	UpdateTabHighlight("Icicle")

	print("[ShopController] Đã khởi tạo.")
end

function ShopController:Start()
	local Controllers = script.Parent
	local MenuModule = Controllers:FindFirstChild("MenuController")
	if MenuModule then _MenuController = require(MenuModule) end

	local ItemRewardModule = Controllers:FindFirstChild("ItemRewardController")
	if ItemRewardModule then _ItemRewardController = require(ItemRewardModule) end

	-- Đăng ký tab với MenuController
	if _MenuController and Shop then
		_MenuController.RegisterTab("Shop", {
			Open  = OpenShop,
			Close = CloseShop,
			Frame = Shop,
		})
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

	-- ─── MARKETPLACE SERVICE: MUA GAMEPASS THÀNH CÔNG (CLIENT FEEDBACK) ───
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, PassId, WasPurchased)
		if Player == LocalPlayer and WasPurchased then
			PlayGuiSound(AudioConfig.Shop.ChestBuy)
			task.spawn(function()
				PlayerDataController.RefreshData()
			end)
		end
	end)
end

return ShopController
