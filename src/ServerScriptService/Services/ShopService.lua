-- ShopService.lua
-- Xử lý logic mua rương (Chest) phía server
-- Validate, trừ tiền, random item theo weighted drop rate, hoàn tiền nếu trùng

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService       = require(script.Parent.DataService)
local ChestConfig       = require(ReplicatedStorage.Shared.Config.ChestConfig)
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig      = require(ReplicatedStorage.Shared.Config.RarityConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

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
			RefundAmount = math.floor(RefundBasePrice * RarityEntry.RefundPercent)
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
	--- @param Quantity number  -- 1 hoặc 3
	--- @return table           -- { Success, ReceivedItems, RefundAmount, NewMoney }
	BuyChestFn.OnServerInvoke = function(Player, ChestId, Quantity)
		-- ─── VALIDATE ────────────────────────────────────────────
		local Chest = ChestConfig.GetChest(ChestId)
		if not Chest then
			warn(("[ShopService] BuyChest: ChestId '%s' không tồn tại."):format(tostring(ChestId)))
			return { Success = false, Reason = "INVALID_CHEST" }
		end

		if Quantity ~= 1 and Quantity ~= 3 then
			warn(("[ShopService] BuyChest: Quantity không hợp lệ: %s"):format(tostring(Quantity)))
			return { Success = false, Reason = "INVALID_QUANTITY" }
		end

		local Data = DataService.GetData(Player)
		if not Data then
			return { Success = false, Reason = "DATA_NOT_READY" }
		end

		-- ─── TÍNH GIÁ ────────────────────────────────────────────
		local TotalPrice = (Quantity == 1) and Chest.Price1 or Chest.Price3

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

		return {
			Success       = true,
			ReceivedItems = ReceivedItems,
			RefundAmount  = TotalRefund,
			NewMoney      = NewMoney,
		}
	end

	print("[ShopService] Đang chạy.")
end

return ShopService
