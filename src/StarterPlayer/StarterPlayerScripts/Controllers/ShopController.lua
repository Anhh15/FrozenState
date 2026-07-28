-- ShopController.lua (ModuleScript)
-- Điều khiển toàn bộ Shop GUI: hiển thị rương theo tab, popup chi tiết rương, mua rương
-- Chỉ hiển thị trong Lobby phase (GameStateController sẽ ẩn khi vào trận)

-- Cấu trúc GUI mong đợi (StarterGui/Menu/Shop):
--   Shop (Frame)
--     CloseButton     (ImageButton) — đóng toàn bộ Shop
--     TabContainer    (Frame)
--       IciclesTab    (ImageButton)
--       BlocksTab     (ImageButton)
--     ChestList       (Frame)
--       ScrollingFrame (ScrollingFrame) — UIGridLayout đã có sẵn trong Studio
--     ChestPopUp      (Frame) — Visible = false mặc định
--       CloseButton   (ImageButton) — đóng ChestPopUp
--       Buy1Button    (ImageButton)
--         BuyText     (TextLabel)
--       Buy3Button    (ImageButton)
--         BuyText     (TextLabel)
--       ChestTemplate (Frame/ViewportFrame) — điều chỉnh theo chest được chọn
--         ChestViewport (ViewportFrame) — đã có CurrentCamera trong Studio
--         NameText    (TextLabel)
--       ItemInfo      (Frame)
--         ScrollingFrame (ScrollingFrame)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions    = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local ChestConfig          = require(ReplicatedStorage.Shared.Config.ChestConfig)
local ItemRegistry         = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig         = require(ReplicatedStorage.Shared.Config.RarityConfig)
local PlayerDataController = require(script.Parent.PlayerDataController)
local ViewportManager      = require(ReplicatedStorage.Shared.Tools.ViewportManager)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MenuGui  = PlayerGui:WaitForChild("Menu", 10)
local NavGui   = PlayerGui:WaitForChild("NavigationButton", 10)

-- Shop frame nằm bên trong Menu
local Shop         = MenuGui and MenuGui:FindFirstChild("Shop", true)

-- Các phần tử bên trong Shop
local ShopClose    = Shop and Shop:FindFirstChild("CloseButton", true)
local TabContainer = Shop and Shop:FindFirstChild("TabContainer", true)
local IciclesTab   = TabContainer and TabContainer:FindFirstChild("IciclesTab")
local BlocksTab    = TabContainer and TabContainer:FindFirstChild("BlocksTab")
local ChestList    = Shop and Shop:FindFirstChild("ChestList", true)
local ChestScroll  = ChestList and ChestList:FindFirstChildOfClass("ScrollingFrame")

-- ChestPopUp
local ChestPopUp      = Shop and Shop:FindFirstChild("ChestPopUp", true)
local PopUpClose      = ChestPopUp and ChestPopUp:FindFirstChild("CloseButton", true)
local Buy1Button      = ChestPopUp and ChestPopUp:FindFirstChild("Buy1Button", true)
local Buy3Button      = ChestPopUp and ChestPopUp:FindFirstChild("Buy3Button", true)
local PopUpChest      = ChestPopUp and ChestPopUp:FindFirstChild("ChestTemplate", true)
local PopUpChestView  = PopUpChest and PopUpChest:FindFirstChild("ChestViewport")
local PopUpChestName  = PopUpChest and PopUpChest:FindFirstChild("NameText")
local ItemInfoFrame   = ChestPopUp and ChestPopUp:FindFirstChild("ItemInfo", true)
local ItemInfoScroll  = ItemInfoFrame and ItemInfoFrame:FindFirstChildOfClass("ScrollingFrame")

-- Nút mở Shop trong NavigationButton
local ShopNavButton = NavGui and NavGui:FindFirstChild("Shop", true)

-- Frame Button bên trong NavigationButton (ẩn khi Shop mở, Stats vẫn hiện)
local NavButton = NavGui and NavGui:FindFirstChild("Button")

-- Assets dùng chung
local Assets       = ReplicatedStorage:FindFirstChild("Assets")
local GuiFolder    = Assets and (Assets:FindFirstChild("Gui") or Assets:FindFirstChild("GUI"))
local ChestTemplate = GuiFolder and GuiFolder:FindFirstChild("ChestTemplate")
local ItemTemplate  = GuiFolder and GuiFolder:FindFirstChild("ItemTemplate")
local ChestsFolder  = Assets and Assets:FindFirstChild("Chests")

-- =========================================================
-- STATE
-- =========================================================

local _currentTab       = "Icicle"  -- Tab đang hiển thị: "Icicle" hoặc "Block"
local _selectedChest    = nil       -- ChestConfig entry đang mở trong PopUp
local _listConnections  = {}        -- Connections của ChestList (dọn khi re-render)
local _popupConnections = {}        -- Connections của ChestPopUp buttons
local _popupChestModel  = nil       -- Model chest đang hiển thị trong PopUp viewport

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

--- Lấy BuyText label bên trong một button (ImageButton thường có TextLabel con)
local function GetBuyText(Button)
	if not Button then return nil end
	return Button:FindFirstChild("BuyText")
		or Button:FindFirstChildOfClass("TextLabel")
end

-- =========================================================
-- POPUP MANAGEMENT
-- =========================================================

--- Đóng và dọn dẹp ChestPopUp
local function CleanPopUp()
	if not ChestPopUp then return end
	ChestPopUp.Visible = false
	_selectedChest     = nil

	-- Dọn model trong viewport PopUp
	if PopUpChestView then
		CleanViewport(PopUpChestView)
	end
	_popupChestModel = nil

	-- Dọn danh sách item bên trong ItemInfo
	if ItemInfoScroll then
		for _, Child in ipairs(ItemInfoScroll:GetChildren()) do
			if not Child:IsA("UIGridLayout") and not Child:IsA("UIListLayout") then
				Child:Destroy()
			end
		end
	end

	-- Ngắt kết nối event PopUp
	DisconnectAll(_popupConnections)
end

--- Mở ChestPopUp với thông tin của rương được chọn
--- @param ChestEntry table  -- Entry từ ChestConfig
local function OpenPopUp(ChestEntry)
	if not ChestPopUp then return end
	_selectedChest = ChestEntry

	-- Hiện PopUp
	ChestPopUp.Visible = true

	-- Cập nhật tên rương
	if PopUpChestName then
		PopUpChestName.Text = ChestEntry.Name
	end

	-- Load Chest model vào viewport
	if PopUpChestView then
		LoadChestModel(PopUpChestView, ChestEntry.Id)
	end

	-- Cập nhật giá trên Buy1Button và Buy3Button
	local Buy1Text = GetBuyText(Buy1Button)
	local Buy3Text = GetBuyText(Buy3Button)
	if Buy1Text then
		Buy1Text.Text = ("Buy 1: %d"):format(ChestEntry.Price1)
	end
	if Buy3Text then
		Buy3Text.Text = ("Buy 3: %d"):format(ChestEntry.Price3)
	end

	-- Render danh sách item + DropRate trong ItemInfo
	if ItemInfoScroll and ItemTemplate then
		for _, ItemEntry in ipairs(ChestEntry.Items) do
			-- Lấy thông tin đầy đủ từ ItemRegistry
			local FullEntry  = ItemRegistry.GetItem(ItemEntry.ItemId, ChestEntry.Type)
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
				RarityText.Text      = FullEntry.Rarity
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

			-- Render item model vào ItemViewport và tự động tạo camera (nếu có)
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
						-- Tạo camera tự động qua ViewportManager
						ViewportManager.RenderItem(ItemViewport, Clone, FullEntry.Type, FullEntry.Id)
					end
				end
			end

			Frame.Parent = ItemInfoScroll
		end
	end

	-- Kết nối nút Buy1
	if Buy1Button then
		local Conn = Buy1Button.MouseButton1Click:Connect(function()
			if _selectedChest then
				local BuyChestFn = RemoteDefinitions.GetFunction("BuyChest")
				local Result = BuyChestFn:InvokeServer(_selectedChest.Id, 1)
				-- Sync lại dữ liệu sở hữu về client cache để Inventory hiển thị đúng
				if Result and Result.Success then
					PlayGuiSound(SFX_CHEST_BUY, 10)
					-- Kích hoạt hiệu ứng mở rương (phần thưởng đã được trao bởi server)
					local RewardCtrl = GetItemRewardController()
					if RewardCtrl and Result.ReceivedItems then
						RewardCtrl.ShowChestReward(Result.ReceivedItems, _selectedChest.Id)
					end
					task.spawn(function()
						PlayerDataController.RefreshData()
					end)
				else
					PlayGuiSound(SFX_BUY_FAIL)
				end
			end
		end)
		table.insert(_popupConnections, Conn)
	end

	-- Kết nối nút Buy3
	if Buy3Button then
		local Conn = Buy3Button.MouseButton1Click:Connect(function()
			if _selectedChest then
				local BuyChestFn = RemoteDefinitions.GetFunction("BuyChest")
				local Result = BuyChestFn:InvokeServer(_selectedChest.Id, 3)
				-- Sync lại dữ liệu sở hữu về client cache để Inventory hiển thị đúng
				if Result and Result.Success then
					PlayGuiSound(SFX_CHEST_BUY, 10)
					-- Kích hoạt hiệu ứng mở rương (phần thưởng đã được trao bởi server)
					local RewardCtrl = GetItemRewardController()
					if RewardCtrl and Result.ReceivedItems then
						RewardCtrl.ShowChestReward(Result.ReceivedItems, _selectedChest.Id)
					end
					task.spawn(function()
						PlayerDataController.RefreshData()
					end)
				else
					PlayGuiSound(SFX_BUY_FAIL)
				end
			end
		end)
		table.insert(_popupConnections, Conn)
	end

	-- Kết nối CloseButton của PopUp
	if PopUpClose then
		local Conn = PopUpClose.MouseButton1Click:Connect(function()
			PlayGuiSound(SFX_CLOSE_BUTTON_CLICK)
			CleanPopUp()
		end)
		table.insert(_popupConnections, Conn)
	end
end

-- =========================================================
-- CHEST LIST RENDERING
-- =========================================================

--- Xóa toàn bộ nội dung ChestScroll và dọn connections cũ
local function ClearChestList()
	DisconnectAll(_listConnections)
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
	if not ChestScroll or not ChestTemplate then
		warn("[ShopController] Thiếu ChestScroll hoặc ChestTemplate — không thể render danh sách rương.")
		return
	end

	local Chests = ChestConfig.GetChestsByType(Type)

	for _, ChestEntry in ipairs(Chests) do
		local Frame = ChestTemplate:Clone()
		Frame.Visible = true

		-- Cập nhật tên rương
		local NameText   = Frame:FindFirstChild("NameText", true)
		if NameText then
			NameText.Text = ChestEntry.Name
		end

		-- Load Chest model vào ChestViewport trong template
		local ChestView = Frame:FindFirstChild("ChestViewport", true)
		if ChestView then
			LoadChestModel(ChestView, ChestEntry.Id)
		end

		-- Kết nối click để mở PopUp
		local ClickTarget = Frame
		if Frame:IsA("GuiButton") then
			local Conn = Frame.MouseButton1Click:Connect(function()
				CleanPopUp()
				OpenPopUp(ChestEntry)
			end)
			table.insert(_listConnections, Conn)
		else
			-- Tìm GuiButton con
			local Button = Frame:FindFirstChildOfClass("ImageButton")
				or Frame:FindFirstChildOfClass("TextButton")
			if Button then
				local Conn = Button.MouseButton1Click:Connect(function()
					CleanPopUp()
					OpenPopUp(ChestEntry)
				end)
				table.insert(_listConnections, Conn)
			else
				-- Fallback: bắt InputBegan trên Frame
				local Conn = Frame.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1
						or Input.UserInputType == Enum.UserInputType.Touch then
						CleanPopUp()
						OpenPopUp(ChestEntry)
					end
				end)
				table.insert(_listConnections, Conn)
			end
		end

		Frame.Parent = ChestScroll
	end
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
		CleanPopUp()
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
	if ChestPopUp then ChestPopUp.Visible = false end

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
			CleanPopUp()
			UpdateTabHighlight("Icicle")
			RenderChestList("Icicle")
		end)
	end

	if BlocksTab then
		BlocksTab.MouseButton1Click:Connect(function()
			if _currentTab == "Block" then return end
			PlayGuiSound(SFX_BUTTON_CLICK)
			_currentTab = "Block"
			CleanPopUp()
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
