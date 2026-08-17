-- GameConfig.lua
-- Tham số chung toàn game FrozenState
-- Chỉnh sửa tại đây để thay đổi cân bằng trò chơi, không hardcode ở nơi khác

local GameConfig = {

	-- =========================================================
	-- THỜI GIAN CÁC PHASE (đơn vị: giây)
	-- =========================================================
	Phase = {
		IntermissionDuration = 6,   -- Thời gian nghỉ giữa các trận
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
		SpecialRoundInterval = 2,   -- Cứ mỗi N vòng sẽ có 1 Special round (ví dụ: 3 = 2 Normal → 1 Special)
	},

	-- =========================================================
	-- TOOL: ICICLE
	-- =========================================================
	Tool = {
		IcicleCooldown = 1,   -- Thời gian hồi chiêu giữa 2 lần swing (giây)
		HitboxRange    = 20,  -- Tolerance server-side validation (studs, ~= chiều dài Hitbox trong Studio)
	},

	-- =========================================================
	-- GUI: VIEWPORT FRAME & TRANSITION
	-- =========================================================
	GUI = {
		ViewportCameraDistance = 5,  -- Khoảng cách camera đến đầu nhân vật trong ViewportFrame (studs)

		-- RoundLoadingScreen transition timing (đơn vị: giây)
		RoundLoadingScreen = {
			FadeInDuration  = 1.0,  -- Thời gian mờ đen màn hình khi bắt đầu Setup
			HoldDuration    = 1.0,  -- Thời gian giữ màn hình đen khi vào Ready
			FadeOutDuration = 0.5,  -- Thời gian sáng dần trở lại
		},
	},

	-- =========================================================
	-- PLAYER: Chỉ số di chuyển mặc định
	-- =========================================================
	Player = {
		DefaultWalkSpeed  = 16,   -- WalkSpeed khi không bị lock
		DefaultJumpPower  = 50,   -- JumpPower khi không bị lock (legacy)
		DefaultJumpHeight = 7.2,  -- JumpHeight khi không bị lock
	},

	-- =========================================================
	-- RARITY: Độ hiếm vật phẩm và màu hiển thị (Hex)
	-- =========================================================
	Rarity = {
		Common    = { Color = "#FFFFFF" },  -- Trắng
		Rare      = { Color = "#4A90D9" },  -- Xanh lam
		Epic      = { Color = "#9B59B6" },  -- Tím
		Legendary = { Color = "#F1C40F" },  -- Vàng
	},

}

return GameConfig
