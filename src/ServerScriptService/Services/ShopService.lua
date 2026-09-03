-- ShopService.lua
-- Xử lý logic mua rương (Chest) phía server
-- Validate, trừ tiền, random item theo weighted drop rate, hoàn tiền nếu trùng

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local DataService       = require(script.Parent.DataService)
local ChestConfig       = require(ReplicatedStorage.Shared.Config.ChestConfig)
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig      = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ProductConfig     = require(ReplicatedStorage.Shared.Config.ProductConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- Bộ nhớ đệm RAM lưu trạng thái sở hữu GamePass: { [Player] = { [PassKey: string] = boolean } }
local _GamePassCache = {}

-- Mutex lock per player chống double-spend khi mua rương: { [UserId: number] = boolean }
local _BuyLocks = {}

-- =========================================================
-- PRIVATE: WEIGHTED RANDOM
-- =========================================================

--- Chọn ngẫu nhiên 1 ItemId từ danh sách Items của rương theo DropRate
--- @param Items table  -- array { ItemId, DropRate }, tổng DropRate = 100
--- @return string      -- ItemId được chọn
local function WeightedRandom(Items)
	local Roll = math.random(1, 100)
	local Cumulative = 0
	for _, Entry in ipairs(Items) do
		Cumulative = Cumulative + Entry.DropRate
		if Roll <= Cumulative then
			return Entry.ItemId
		end
	end
	-- Fallback an toàn: trả item cuối nếu tổng DropRate < 100 do làm tròn
	return Items[#Items].ItemId
end

-- =========================================================
-- PRIVATE: XỬ LÝ MỘT LẦN MỞ RƯƠNG
-- =========================================================

--- Xử lý 1 lần mở rương: random item, trao hoặc hoàn tiền nếu trùng
--- @param Player Player
--- @param Chest table      -- entry từ ChestConfig
--- @param ChestPrice number -- giá rương đã trả (Price1 hoặc Price3/3 ~ không dùng, dùng Price1 cho refund)
--- @return string, number  -- (ItemId nhận được, RefundAmount)
local function ProcessOneDraw(Player, Chest, RefundBasePrice)
	local ItemId = WeightedRandom(Chest.Items)

	-- Kiểm tra đã sở hữu chưa
	local AlreadyOwned = DataService.HasItem(Player, Chest.Type, ItemId)

	if AlreadyOwned then
		-- Tính hoàn tiền dựa trên Rarity của item
		local ItemEntry = ItemRegistry.GetItem(ItemId, Chest.Type)
		local RarityEntry = RarityConfig[ItemEntry.Rarity]
		local RefundAmount = 0
		if RarityEntry then
			RefundAmount = math.round(RefundBasePrice * RarityEntry.RefundPercent)
		end
		return ItemId, RefundAmount, true   -- (ItemId, Refund, WasDuplicate)
	else
		-- Trao item cho player
		if Chest.Type == "Icicle" then
			DataService.AddIcicle(Player, ItemId)
		else
			DataService.AddBlock(Player, ItemId)
		end
		return ItemId, 0, false             -- (ItemId, Refund=0, WasDuplicate=false)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local ShopService = {}

function ShopService:Init()
	print("[ShopService] Đã khởi tạo.")
end

function ShopService:Start()
	local BuyChestFn    = RemoteDefinitions.GetFunction("BuyChest")
	local UpdateMoneyEv = RemoteDefinitions.GetEvent("UpdateMoney")

	--- Handler BuyChest: Client gọi khi muốn mua rương
	--- @param Player Player
	--- @param ChestId string   -- Id của rương trong ChestConfig
	--- @param Quantity number  -- Số lượng mua (1 — 5)
	--- @return table           -- { Success, ReceivedItems, RefundAmount, NewMoney }
	BuyChestFn.OnServerInvoke = function(Player, ChestId, Quantity)
		if not Player or not Player:IsA("Player") then
			return { Success = false, Reason = "INVALID_PLAYER" }
		end

		-- Mutex lock per player chống double-spend / spam request đồng thời
		if _BuyLocks[Player.UserId] then
			return { Success = false, Reason = "BUSY" }
		end
		_BuyLocks[Player.UserId] = true

		local Success, Result = pcall(function()
			-- ─── VALIDATE ────────────────────────────────────────────
			local Chest = ChestConfig.GetChest(ChestId)
			if not Chest then
				warn(("[ShopService] BuyChest: ChestId '%s' không tồn tại."):format(tostring(ChestId)))
				return { Success = false, Reason = "INVALID_CHEST" }
			end

			local MinQty = 1
			local MaxQty = 5
			if type(Quantity) ~= "number"
				or math.floor(Quantity) ~= Quantity
				or Quantity < MinQty
				or Quantity > MaxQty
			then
				warn(("[ShopService] BuyChest: Quantity không hợp lệ: %s"):format(tostring(Quantity)))
				return { Success = false, Reason = "INVALID_QUANTITY" }
			end

			local Data = DataService.GetData(Player)
			if not Data then
				return { Success = false, Reason = "DATA_NOT_READY" }
			end

			-- ─── TÍNH GIÁ ────────────────────────────────────────────
			local TotalPrice = Chest.Price1 * Quantity

			if Data.Money < TotalPrice then
				return { Success = false, Reason = "NOT_ENOUGH_MONEY" }
			end

			-- ─── TRỪ TIỀN TRƯỚC (để tránh double-spend) ──────────────
			DataService.AddMoney(Player, -TotalPrice)

			-- ─── MỞ RƯƠNG ────────────────────────────────────────────
			-- RefundBasePrice = Price1 (hoàn tiền dựa trên giá 1 lần mở, không phải giá gói)
			local RefundBasePrice = Chest.Price1
			local TotalRefund     = 0
			local ReceivedItems   = {}

			for _ = 1, Quantity do
				local ItemId, RefundAmount, WasDuplicate = ProcessOneDraw(Player, Chest, RefundBasePrice)
				table.insert(ReceivedItems, {
					ItemId       = ItemId,
					WasDuplicate = WasDuplicate,
					Refund       = RefundAmount,
				})
				TotalRefund = TotalRefund + RefundAmount
			end

			-- ─── HOÀN TIỀN (nếu có) ──────────────────────────────────
			if TotalRefund > 0 then
				DataService.AddMoney(Player, TotalRefund)
			end

			-- ─── CẬP NHẬT TIỀN VỀ CLIENT ─────────────────────────────
			local NewMoney = DataService.GetData(Player).Money
			UpdateMoneyEv:FireClient(Player, NewMoney)

			print(("[ShopService] %s mua %s x%d — Nhận: %d item, Hoàn: %d Cash"):format(
				Player.Name, ChestId, Quantity, #ReceivedItems, TotalRefund
			))

			-- Dispatch Event cho QuestService (Objective Engine 2.0)
			local QuestModule = script.Parent:FindFirstChild("QuestService")
			if QuestModule then
				local QuestService = require(QuestModule)
				if QuestService and QuestService.DispatchEvent then
					QuestService.DispatchEvent(Player, "OnChestOpened", {
						ChestId  = ChestId,
						Quantity = Quantity,
						Amount   = Quantity,
					})
				end
			end

			return {
				Success       = true,
				ReceivedItems = ReceivedItems,
				RefundAmount  = TotalRefund,
				NewMoney      = NewMoney,
			}
		end)

		_BuyLocks[Player.UserId] = nil

		if not Success then
			warn(("[ShopService] Lỗi khi xử lý BuyChest cho %s: %s"):format(Player.Name, tostring(Result)))
			return { Success = false, Reason = "INTERNAL_ERROR" }
		end

		return Result
	end

	-- =========================================================
	-- MARKETPLACESERVICE: PROCESS RECEIPT (DEVELOPER PRODUCTS)
	-- =========================================================

	--- Callback xử lý khi người chơi mua Developer Product (Gói tiền tệ Robux)
	--- @param ReceiptInfo table -- { PlayerId, ProductId, PurchaseId, CurrencySpent, ... }
	--- @return Enum.ProductPurchaseDecision
	MarketplaceService.ProcessReceipt = function(ReceiptInfo)
		local Player = Players:GetPlayerByUserId(ReceiptInfo.PlayerId)
		if not Player then
			-- Người chơi không còn trong server, hoãn xử lý để Roblox retry khi họ quay lại
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Tra cứu gói sản phẩm theo ProductId
		local Package = ProductConfig.GetPackageByProductId(ReceiptInfo.ProductId)
		if not Package then
			warn(("[ShopService] ProcessReceipt: Không tìm thấy gói tương ứng với ProductId %s"):format(
				tostring(ReceiptInfo.ProductId)
			))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Chờ Profile của người chơi sẵn sàng
		local Profile = DataService.WaitForProfile(Player)
		if not Profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Kiểm tra xem PurchaseId này đã được xử lý trước đó chưa (Chống trùng lặp / Replay)
		local PurchaseId = tostring(ReceiptInfo.PurchaseId)
		if DataService.HasProcessedPurchase(Player, PurchaseId) then
			print(("[ShopService] ProcessReceipt: PurchaseId '%s' đã được xử lý trước đó cho %s."):format(
				PurchaseId, Player.Name
			))
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		-- Trao thưởng tiền tệ vào DataStore
		local NewMoney = DataService.AddMoney(Player, Package.CurrencyAmount)
		DataService.RecordPurchase(Player, PurchaseId)

		-- Đồng bộ số tiền mới về Client
		UpdateMoneyEv:FireClient(Player, NewMoney)

		print(("[ShopService] ProcessReceipt thành công: %s mua gói %s (+%d Money, PurchaseId: %s)"):format(
			Player.Name, Package.DisplayName, Package.CurrencyAmount, PurchaseId
		))

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- =========================================================
	-- MARKETPLACESERVICE: GAMEPASS PURCHASE FINISHED (SERVER)
	-- =========================================================

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(Player, PassId, WasPurchased)
		if WasPurchased and Player and Player.Parent then
			local _, PassKey = ProductConfig.GetGamePassById(PassId)
			if PassKey then
				if not _GamePassCache[Player] then
					_GamePassCache[Player] = {}
				end
				_GamePassCache[Player][PassKey] = true
				print(("[ShopService] %s đã mua thành công GamePass: %s (PassId: %s)"):format(
					Player.Name, PassKey, tostring(PassId)
				))
			end
		end
	end)

	-- Dọn dẹp cache và lock khi người chơi rời khỏi server
	Players.PlayerRemoving:Connect(function(Player)
		_GamePassCache[Player] = nil
		_BuyLocks[Player.UserId] = nil
	end)

	print("[ShopService] Đang chạy.")
end

-- =========================================================
-- PUBLIC GAMEPASS API
-- =========================================================

--- Kiểm tra người chơi có sở hữu GamePass hay không (có bộ nhớ đệm RAM chống HTTP 429)
--- @param Player Player
--- @param PassKey string -- "DoubleMatchMoney" | "UpgradeDailyQuests"
--- @return boolean
function ShopService.PlayerOwnsGamePass(Player, PassKey)
	if not Player or not Player.Parent or not PassKey then return false end

	-- 1. Kiểm tra cache trong RAM trước
	local PlayerCache = _GamePassCache[Player]
	if PlayerCache and PlayerCache[PassKey] ~= nil then
		return PlayerCache[PassKey]
	end

	-- 2. Lấy cấu hình GamePass
	local PassConfig = ProductConfig.GetGamePassByKey(PassKey)
	if not PassConfig or not PassConfig.PassId or PassConfig.PassId <= 0 then
		-- ID chưa được cấu hình hoặc = 0 (an toàn khi dev/test)
		return false
	end

	-- 3. Gọi UserOwnsGamePassAsync với pcall để chống lỗi mạng
	local Success, OwnsPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, PassConfig.PassId)
	end)

	local Result = (Success and OwnsPass == true)

	-- 4. Lưu kết quả vào RAM cache
	if not _GamePassCache[Player] then
		_GamePassCache[Player] = {}
	end
	_GamePassCache[Player][PassKey] = Result

	return Result
end

--- Gán trực tiếp trạng thái sở hữu GamePass trong RAM cache (dùng cho testing/admin/override)
--- @param Player Player
--- @param PassKey string
--- @param Owned boolean
function ShopService.SetGamePassOwnership(Player, PassKey, Owned)
	if not Player or not PassKey then return end
	if not _GamePassCache[Player] then
		_GamePassCache[Player] = {}
	end
	_GamePassCache[Player][PassKey] = (Owned == true)
end

return ShopService
