-- GameConfig.lua
-- Tham số chung toàn game FrozenState
-- Chỉnh sửa tại đây để thay đổi cân bằng trò chơi, không hardcode ở nơi khác

local GameConfig = {

	-- =========================================================
	-- THỜI GIAN CÁC PHASE (đơn vị: giây)
	-- =========================================================
	Phase = {
		IntermissionDuration = 15,   -- Thời gian nghỉ giữa các trận
		ReadyDuration        = 3,   -- Đếm ngược trước khi bắt đầu
		GameOverDuration     = 6,   -- Màn hình kết thúc
		GameOverRevealDelay  = 2,   -- Delay trước khi hiện win/lose trong GameOver
	},

	-- =========================================================
	-- YÊU CẦU TRẬN ĐẤU
	-- =========================================================
	Match = {
		MinPlayers           = 2,   -- Số người tối thiểu để bắt đầu trận
		MaxPlayers           = 16,  -- Số người tối đa mỗi trận
		SpecialRoundInterval = 5,   -- Cứ mỗi N vòng sẽ có 1 Special round (ví dụ: 3 = 2 Normal → 1 Special)
	},

	-- =========================================================
	-- TOOL: ICICLE
	-- =========================================================
	Tool = {
		IcicleCooldown = 1,   -- Thời gian hồi chiêu giữa 2 lần swing (giây)
		HitboxRange    = 20,  -- Tolerance server-side validation (studs, ~= chiều dài Hitbox trong Studio)
	},

	-- =========================================================
	-- PLAYER: Chỉ số di chuyển mặc định
	-- =========================================================
	Player = {
		DefaultWalkSpeed  = 16,   -- WalkSpeed khi không bị lock
		DefaultJumpPower  = 50,   -- JumpPower khi không bị lock (legacy)
		DefaultJumpHeight = 7.2,  -- JumpHeight khi không bị lock
	},

}

return GameConfig
