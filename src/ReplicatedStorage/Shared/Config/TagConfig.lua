-- TagConfig.lua
-- Cấu hình danh mục CollectionService Tags chuẩn toàn game FrozenState
-- Giúp loại bỏ hardcoded string tag và tạo chuẩn gắn nhãn thực thể

local TagConfig = {

	-- =========================================================
	-- TÊN CÁC COLLECTION SERVICE TAGS
	-- =========================================================
	Tags = {
		IceBlock        = "IceBlock",         -- Đánh dấu Model khối băng đang active
		Hitbox          = "Hitbox",           -- Đánh dấu Part nhận diện va chạm (Tool / Block)
		HighlightHelper = "HighlightHelper",  -- Đánh dấu Adornee part của khối băng cho Highlight
		SpawnPoint      = "SpawnPoint",       -- Đánh dấu các BasePart điểm xuất phát trong map
	},

}

return TagConfig
