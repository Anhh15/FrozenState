-- EconomyConfig.lua
-- Cấu hình tập trung toàn bộ phần thưởng và kinh tế trong game FrozenState
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local EconomyConfig = {

	-- =========================================================
	-- TIỀN THƯỞNG CHO MỖI HÀNH ĐỘNG IN-GAME
	-- =========================================================
	Rewards = {
		PerFreeze        = 10,  -- Tiền thưởng khi đóng băng 1 kẻ địch
		PerThaw          = 10,  -- Tiền thưởng khi giải cứu 1 đồng minh
		PerFreezingSpree = 30,  -- Thưởng thêm khi đạt Freezing Spree (chuỗi N lần freeze liên tiếp)
		PerThawingSpree  = 30,  -- Thưởng thêm khi đạt Thawing Spree (chuỗi N lần thaw liên tiếp)
		FirstBlood       = 20,  -- Thưởng cho người đầu tiên thực hiện đóng băng trong trận
		LastStanding     = 20,  -- Thưởng cho người sống sót cuối cùng
		MatchWin         = 30,  -- Thưởng khi đội hoặc cá nhân thắng trận
		MatchLose        = 10,  -- Thưởng an ủi khi thua trận
	},

	-- =========================================================
	-- CẤU HÌNH CHUỖI SPREE (STREAK)
	-- =========================================================
	Spree = {
		Threshold = 3,  -- Số lần hành động liên tiếp để kích hoạt 1 mốc Spree
	},

}

return EconomyConfig
