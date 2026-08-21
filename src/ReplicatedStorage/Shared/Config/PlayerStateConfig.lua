-- PlayerStateConfig.lua
-- Cấu hình tập trung các Attribute, Teams, và State liên quan đến Player
-- Giúp loại bỏ hardcoded string rải rác trên Client và Server

local PlayerStateConfig = {

	-- =========================================================
	-- TÊN CÁC ATTRIBUTE TRÊN PLAYER / CHARACTER / INSTANCES
	-- =========================================================
	Attributes = {
		InMatch              = "InMatch",              -- boolean: player đang trực tiếp tham chiến
		GameLoaded           = "GameLoaded",           -- boolean: player đã hoàn thành GameLoadingScreen (sẵn sàng ghép trận)
		Team                 = "Team",                 -- string: "Team1" | "Team2" | nil
		EquippedIcicleSkinId = "EquippedIcicleSkinId", -- string: SkinId của Icicle đang trang bị
		VictimUserId         = "VictimUserId",         -- number: UserId nạn nhân bị đóng băng (trên IceBlock Model)
	},

	-- =========================================================
	-- ĐỊNH NGHĨA CÁC ĐỘI (TEAMS)
	-- =========================================================
	Teams = {
		Team1 = "Team1",
		Team2 = "Team2",
	},

	-- =========================================================
	-- TRẠNG THÁI CỦA PLAYER TRONG SESSION (PLAYER STATES)
	-- =========================================================
	SessionStates = {
		Normal = "Normal",
		Frozen = "Frozen",
		Dead   = "Dead",
	},
}

return PlayerStateConfig
