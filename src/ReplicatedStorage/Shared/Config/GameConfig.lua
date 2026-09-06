-- GameConfig.lua
-- Tham số chung toàn game FrozenState
-- Chỉnh sửa tại đây để thay đổi cân bằng trò chơi, không hardcode ở nơi khác

local GameConfig = {

	-- =========================================================
	-- THỜI GIAN CÁC PHASE (đơn vị: giây)
	-- =========================================================
	Phase = {
		IntermissionDuration = 7,   -- Thời gian nghỉ giữa các trận
		ReadyDuration        = 4,   -- Đếm ngược trước khi bắt đầu
		GameOverDuration     = 6,   -- Màn hình kết thúc
		GameOverRevealDelay  = 2,   -- Delay trước khi hiện win/lose trong GameOver
	},

	-- =========================================================
	-- YÊU CẦU TRẬN ĐẤU
	-- =========================================================
	Match = {
		MinPlayers           = 2,   -- Số người tối thiểu để bắt đầu trận
		MaxPlayers           = 16,  -- Số người tối đa mỗi trận
		SpecialRoundInterval = 3,   -- Cứ mỗi N vòng sẽ có 1 Special round (ví dụ: 3 = 2 Normal → 1 Special)
	},

	-- =========================================================
	-- TOOL: ICICLE
	-- =========================================================
	Tool = {
		IcicleCooldown             = 1,    -- Thời gian hồi chiêu giữa 2 lần swing (giây)
		HitboxRange                = 8,    -- Tolerance server-side validation (studs, ~= chiều dài Hitbox trong Studio)
		HitLagTolerance            = 1.5,  -- Hệ số bù trừ độ trễ mạng cho khoảng cách
		HitDebounceWindow          = 0.8,  -- Khoảng cách tối thiểu giữa 2 lần nhận hit trên server (giây)
		HitSwingWindow             = 0.4,  -- Cửa sổ thời gian tối đa cho 1 cú vung (giây, cho phép chém lan AoE nhiều mục tiêu)
		MinDotProduct              = 0.5,  -- Ngưỡng cosin góc nhìn tối thiểu phía trước mặt (cos 60 độ = 0.5, hình nón 120 độ)
		HitWindowLatencyTolerance  = 0.15, -- Dung sai độ trễ mạng (giây) cho cửa sổ vung kiếm
		MinAttackDistanceThreshold = 0.001, -- Ngưỡng khoảng cách tối thiểu tránh chia cho 0 khi tính Vector Unit
		RaycastMaxTransparency     = 0.9,  -- Ngưỡng trong suốt tối đa: Part có Transparency >= 0.9 và CanCollide = false được coi là Trigger vô hình không cản tầm nhìn
		RaycastMaxAttempts         = 4,    -- Số lần dò tia tối đa khi xuyên qua các Volume vô hình
	},

	-- =========================================================
	-- PLAYER: Chỉ số di chuyển mặc định
	-- =========================================================
	Player = {
		DefaultWalkSpeed  = 16,   -- WalkSpeed khi không bị lock
		DefaultJumpPower  = 50,   -- JumpPower khi không bị lock (legacy)
		DefaultJumpHeight = 7.2,  -- JumpHeight khi không bị lock
		AfkCooldown             = 1.5,  -- Khoảng cách tối thiểu giữa 2 lần chuyển đổi trạng thái AFK (giây)
		SpectateRequestCooldown = 0.5,  -- Khoảng cách tối thiểu giữa 2 lần yêu cầu chuyển mục tiêu quan sát (giây)
	},

}

return GameConfig
