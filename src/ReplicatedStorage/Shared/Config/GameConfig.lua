-- GameConfig.lua
-- Tham số chung toàn game FrozenState
-- Chỉnh sửa tại đây để thay đổi cân bằng trò chơi, không hardcode ở nơi khác

local GameConfig = {

	-- =========================================================
	-- THỜI GIAN CÁC PHASE (đơn vị: giây)
	-- =========================================================
	Phase = {
		IntermissionDuration  = 20,   -- Thời gian nghỉ giữa các trận
		ReadyDuration         = 3,    -- Đếm ngược trước khi bắt đầu
		InGameDuration        = 180,  -- Thời gian tối đa mỗi trận
		GameOverDuration      = 6,    -- Màn hình kết thúc
		GameOverRevealDelay   = 2,    -- Delay trước khi hiện win/lose trong GameOver
		FrozenStateThreshold  = 45,   -- Số giây còn lại khi kích hoạt Frozen State
	},

	-- =========================================================
	-- YÊU CẦU TRẬN ĐẤU
	-- =========================================================
	Match = {
		MinPlayers     = 2,   -- Số người tối thiểu để bắt đầu trận
		MaxPlayers     = 16,  -- Số người tối đa mỗi trận
		SpreeThreshold = 3,   -- Số lần liên tiếp để tính một spree
	},

	-- =========================================================
	-- KINH TẾ: TIỀN THƯỞNG CHO MỖI HÀNH ĐỘNG
	-- =========================================================
	Economy = {
		RewardPerFreeze        = 10,  -- Tiền thưởng khi đóng băng 1 kẻ địch
		RewardPerThaw          = 10,  -- Tiền thưởng khi giải cứu 1 đồng minh
		RewardPerFreezingSpree = 10,  -- Thưởng thêm khi đạt Freezing Spree
		RewardPerThawingSpree  = 10,  -- Thưởng thêm khi đạt Thawing Spree
		RewardFirstBlood       = 10,  -- Thưởng khi là người đóng băng đầu tiên
		RewardLastStanding     = 10,  -- Thưởng khi là người cuối cùng còn đứng
		RewardWin              = 10,  -- Thưởng khi đội thắng
		RewardLose             = 10,  -- Thưởng an ủi khi thua
	},

	-- =========================================================
	-- TOOL: ICICLE
	-- =========================================================
	Tool = {
		IcicleRange    = 10,   -- Khoảng cách Raycast tối đa (studs)
		IcicleCooldown = 0.8,  -- Thời gian hồi chiêu giữa 2 lần swing (giây)
	},

}

return GameConfig
