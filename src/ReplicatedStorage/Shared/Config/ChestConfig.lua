-- ChestConfig.lua
-- Định nghĩa tập trung toàn bộ rương (Chest) trong Shop
-- Để thêm rương mới: thêm entry vào CHEST_CATALOG, đảm bảo model tồn tại tại ReplicatedStorage/Asset/Chests

-- CẤU TRÚC MỖI ENTRY:
--   Id      (string) — Tên folder model tại ReplicatedStorage/Asset/Chests
--   Name    (string) — Tên hiển thị trong Shop
--   Type    (string) — "Icicle" hoặc "Block" (tab nào hiển thị rương này)
--   Price1  (number) — Giá mua 1 rương (nhân với số lượng để ra tổng giá)
--   Items   (table)  — Danh sách item có thể rơi từ rương này:
--                        { ItemId (string), DropRate (number 0-100) }
--                        Tổng DropRate của tất cả Items PHẢI bằng 100

local ChestConfig = {}

-- =========================================================
-- CATALOG
-- =========================================================

local CHEST_CATALOG = {

	-- -------------------------------------------------------
	-- ICICLE CHESTS
	-- -------------------------------------------------------
	{
		Id     = "BasicIcicleChest",
		Name   = "Basic Icicle Chest",
		Type   = "Icicle",
		Price1 = 10,
		Items  = {
			{ ItemId = "Green", DropRate = 60 },
			{ ItemId = "Red",   DropRate = 40 },
		},
	},

	-- Thêm rương Icicle mới vào đây
	-- Ví dụ:
	-- {
	--     Id     = "PremiumIcicleChest",
	--     Name   = "Premium Icicle Chest",
	--     Type   = "Icicle",
	--     Price1 = 2000,
	--     Items  = {
	--         { ItemId = "GoldenIcicle",   DropRate = 10 },
	--         { ItemId = "DiamondIcicle",  DropRate = 90 },
	--     },
	-- },

	-- -------------------------------------------------------
	-- BLOCK CHESTS
	-- -------------------------------------------------------
	{
		Id     = "BasicBlockChest",
		Name   = "Basic Block Chest",
		Type   = "Block",
		Price1 = 10,
		Items  = {
			{ ItemId = "Green", DropRate = 60 },
			{ ItemId = "Red",   DropRate = 40 },
		},
	},

	-- Thêm rương Block mới vào đây
}

-- =========================================================
-- INDEX: Tra cứu nhanh theo Id
-- =========================================================

local _ChestIndex = {}
for _, Entry in ipairs(CHEST_CATALOG) do
	_ChestIndex[Entry.Id] = Entry
end

-- =========================================================
-- PUBLIC API
-- =========================================================

--- Lấy toàn bộ catalog rương
--- @return table[]
function ChestConfig.GetAllChests()
	return CHEST_CATALOG
end

--- Lấy thông tin rương theo Id
--- @param ChestId string
--- @return table | nil
function ChestConfig.GetChest(ChestId)
	local Entry = _ChestIndex[ChestId]
	if not Entry then
		warn(("[ChestConfig] Không tìm thấy Chest Id='%s'."):format(ChestId))
	end
	return Entry
end

--- Lấy danh sách rương theo type (dùng cho tab switching trong Shop)
--- @param Type string  -- "Icicle" hoặc "Block"
--- @return table[]
function ChestConfig.GetChestsByType(Type)
	local Result = {}
	for _, Entry in ipairs(CHEST_CATALOG) do
		if Entry.Type == Type then
			table.insert(Result, Entry)
		end
	end
	return Result
end

return ChestConfig
