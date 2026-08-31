-- ItemRegistry.lua
-- Catalog tập trung toàn bộ vật phẩm trong game (Icicle và Block)
-- Mỗi item cần có entry ở đây để IcicleService / FreezeService có thể load đúng model
-- Để thêm item mới: thêm entry vào đúng bảng, đảm bảo folder model tồn tại trong Studio

-- CẤU TRÚC MỖI ENTRY:
--   Id      (string) — Tên folder trong ServerStorage/Icicles hoặc ServerStorage/Blocks
--   Name    (string) — Tên hiển thị (dùng cho GUI)
--   Rarity  (string) — Khớp với key trong RarityConfig (Basic/Common/Uncommon/Rare/Epic/Legendary)
--   Type    (string) — "Icicle" hoặc "Block"
--   Icon    (string) — Image ID của icon 2D hiển thị trên GUI ("rbxassetid://..." hoặc "")

local ItemRegistry = {}

-- =========================================================
-- CATALOG: ICICLE
-- =========================================================

local IcicleCatalog = {
	{
		Id     = "Default",
		Name   = "Default Icicle",
		Rarity = "Basic",
		Type   = "Icicle",
		Icon   = "rbxassetid://106702914411826",
	},
	{
		Id     = "Green",
		Name   = "Green Icicle",
		Rarity = "Basic",
		Type   = "Icicle",
		Icon   = "rbxassetid://106702914411826",
	},
	{
		Id     = "Red",
		Name   = "Red Icicle",
		Rarity = "Basic",
		Type   = "Icicle",
		Icon   = "rbxassetid://106702914411826",
	},
}

-- =========================================================
-- CATALOG: BLOCK
-- =========================================================

local BlockCatalog = {
	{
		Id     = "Default",
		Name   = "Default Block",
		Rarity = "Basic",
		Type   = "Block",
		Icon   = "rbxassetid://106702914411826",
	},
	{
		Id     = "Green",
		Name   = "Green Block",
		Rarity = "Basic",
		Type   = "Block",
		Icon   = "rbxassetid://106702914411826",
	},
	{
		Id     = "Red",
		Name   = "Red Block",
		Rarity = "Basic",
		Type   = "Block",
		Icon   = "rbxassetid://106702914411826",
	},
}

-- =========================================================
-- INDEX: Tra cứu nhanh theo Id
-- =========================================================

-- Xây dựng lookup table để GetItem() chạy O(1) thay vì O(n)
local _IcicleIndex = {}
for _, Entry in ipairs(IcicleCatalog) do
	_IcicleIndex[Entry.Id] = Entry
end

local _BlockIndex = {}
for _, Entry in ipairs(BlockCatalog) do
	_BlockIndex[Entry.Id] = Entry
end

-- =========================================================
-- PUBLIC API
-- =========================================================

--- Lấy thông tin item theo Id và Type
--- Tự động fallback về "Default" nếu Id không tồn tại trong catalog
--- @param ItemId string   — Id của item (vd: "Default", "Green")
--- @param ItemType string — "Icicle" hoặc "Block"
--- @return table          — entry từ catalog
function ItemRegistry.GetItem(ItemId, ItemType)
	local Index = (ItemType == "Icicle") and _IcicleIndex or _BlockIndex

	local Entry = Index[ItemId]
	if not Entry then
		warn(("[ItemRegistry] Không tìm thấy %s Id='%s', fallback về Default."):format(ItemType, ItemId))
		Entry = Index["Default"]
	end

	return Entry
end

--- Lấy Icon của item theo Id và Type
--- Tự động fallback về Icon của "Default" nếu item không có icon riêng
--- @param ItemId string
--- @param ItemType string
--- @return string
function ItemRegistry.GetItemIcon(ItemId, ItemType)
	local Entry = ItemRegistry.GetItem(ItemId, ItemType)
	if Entry and Entry.Icon and Entry.Icon ~= "" then
		return Entry.Icon
	end

	local DefaultEntry = ItemRegistry.GetItem("Default", ItemType)
	return (DefaultEntry and DefaultEntry.Icon) or ""
end

--- Lấy toàn bộ catalog Icicle (dùng cho Shop / Inventory sau này)
--- @return table[]
function ItemRegistry.GetAllIcicles()
	return IcicleCatalog
end

--- Lấy toàn bộ catalog Block (dùng cho Shop / Inventory sau này)
--- @return table[]
function ItemRegistry.GetAllBlocks()
	return BlockCatalog
end

return ItemRegistry
