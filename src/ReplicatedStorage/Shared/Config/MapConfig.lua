-- MapConfig.lua
-- Cấu hình tên thư mục, tiền tố điểm spawn và quy chuẩn phân cấp bản đồ trong game
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local MapConfig = {

	-- =========================================================
	-- TÊN CÁC THƯ MỤC VÀ CONTAINER BẢN ĐỒ
	-- =========================================================
	Folders = {
		MapsFolder   = "Maps",        -- Thư mục chứa template map trong ServerStorage
		MapContainer = "CurrentMap",  -- Tên Model map khi được clone vào Workspace
		SpawnRoot    = "SpawnPoint",  -- Thư mục gốc chứa điểm spawn bên trong Model map
		TeamBase     = "TeamBase",    -- Thư mục con chứa spawn phân đội (SpawnPoint/TeamBase)
		FFA          = "FFA",         -- Thư mục con chứa spawn chế độ FFA (SpawnPoint/FFA)
	},

	-- =========================================================
	-- TIỀN TỐ (PREFIX) TÊN ĐIỂM SPAWN
	-- =========================================================
	Prefixes = {
		Team1 = "T1SpawnPoint",  -- Ví dụ: T1SpawnPoint1, T1SpawnPoint2...
		Team2 = "T2SpawnPoint",  -- Ví dụ: T2SpawnPoint1, T2SpawnPoint2...
		FFA   = "SpawnPoint",    -- Ví dụ: SpawnPoint1, SpawnPoint2...
	},

}

return MapConfig
