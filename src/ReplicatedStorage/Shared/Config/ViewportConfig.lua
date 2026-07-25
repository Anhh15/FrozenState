-- ViewportConfig.lua
-- Tham số camera cho các ViewportFrame hiển thị vật phẩm (Item, Chest)
-- KHÔNG áp dụng cho PlayerViewport (avatar 3D)
--
-- Cấu trúc ưu tiên (thấp → cao):
--   Default → TypeOverrides[ItemType] → ItemOverrides[ItemId]

local ViewportConfig = {}

-- =========================================================
-- DEFAULT — Áp dụng cho tất cả vật phẩm nếu không có override
-- =========================================================

local Default = {
	FieldOfView   = 30,   -- FOV nhỏ giúp giảm méo góc rộng (perspective distortion)
	PitchAngle    = -15,  -- Góc nghiêng dọc camera (âm = nhìn hơi xuống vào vật phẩm)
	YawAngle      = 45,   -- Góc quay ngang camera (45° = nhìn góc chéo đẹp)
	PaddingFactor = 1.2,  -- Hệ số khoảng cách sau khi tính qua BBox (1.0 = khít, >1 = thoáng hơn)
}

-- =========================================================
-- TYPE OVERRIDES — Ghi đè theo loại vật phẩm
-- Key phải khớp với Entry.Type trong ItemRegistry ("Icicle", "Block")
-- và ChestConfig.Type ("Chest")
-- =========================================================

local TypeOverrides = {
	Icicle = {
		PitchAngle    = 0,
		YawAngle      = 180,
		PaddingFactor = 1,
	},
	Block = {
		PitchAngle    = 10,
		YawAngle      = 135,
		PaddingFactor = 1,
	},
	Chest = {
		FieldOfView   = 70,
		PitchAngle    = 0,
		YawAngle      = 180,
		PaddingFactor = .85,
	},
}

-- =========================================================
-- ITEM OVERRIDES — Ghi đè theo ItemId cụ thể (để sẵn cho tương lai)
-- Key là Entry.Id trong ItemRegistry
-- =========================================================

local ItemOverrides = {
	-- Ví dụ cách dùng (bỏ comment khi cần):
	-- GoldenIcicle = {
	--     YawAngle   = 60,
	--     PitchAngle = -10,
	-- },
	-- ObsidianBlock = {
	--     PaddingFactor = 1.5,
	-- },
}

-- =========================================================
-- PUBLIC API
-- =========================================================

--- Trả về bảng tham số camera đã được merge theo đúng ưu tiên:
--- Default → TypeOverrides[ItemType] → ItemOverrides[ItemId]
--- @param ItemType string|nil — "Icicle", "Block", "Chest" (có thể nil)
--- @param ItemId   string|nil — Id cụ thể trong ItemRegistry (có thể nil)
--- @return table — Bảng tham số camera đã merge
function ViewportConfig.Resolve(ItemType, ItemId)
	local Result = {}

	-- Lớp 1: Copy từ Default
	for Key, Value in pairs(Default) do
		Result[Key] = Value
	end

	-- Lớp 2: Ghi đè theo Type (nếu có)
	if ItemType and TypeOverrides[ItemType] then
		for Key, Value in pairs(TypeOverrides[ItemType]) do
			Result[Key] = Value
		end
	end

	-- Lớp 3: Ghi đè theo ItemId cụ thể (nếu có)
	if ItemId and ItemOverrides[ItemId] then
		for Key, Value in pairs(ItemOverrides[ItemId]) do
			Result[Key] = Value
		end
	end

	return Result
end

return ViewportConfig
