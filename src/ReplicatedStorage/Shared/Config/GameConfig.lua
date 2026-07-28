-- GameConfig.lua
-- Tham số chung toàn game FrozenState
-- Chỉnh sửa tại đây để thay đổi cân bằng trò chơi, không hardcode ở nơi khác

local GameConfig = {

	-- =========================================================
	-- THỜI GIAN CÁC PHASE (đơn vị: giây)
	-- =========================================================
	Phase = {
		IntermissionDuration  = 6,   -- Thời gian nghỉ giữa các trận
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
		IcicleCooldown = 1,  -- Thời gian hồi chiêu giữa 2 lần swing (giây)
		HitboxRange    = 20,    -- Tolerance server-side validation (studs, ~= chiều dài Hitbox trong Studio)
	},

	-- =========================================================
	-- GUI: VIEWPORT FRAME
	-- =========================================================
	GUI = {
		ViewportCameraDistance = 5,  -- Khoảng cách camera đến đầu nhân vật trong ViewportFrame (studs)
		                               -- Tăng để zoom ra, giảm để zoom vào

		-- LoadingScreen transition timing (đơn vị: giây)
		LoadingScreen = {
			FadeInDuration  = 1,   -- Thời gian fade-in (transparent → opaque)
			HoldDuration    = 1,   -- Thời gian giữ nguyên trước khi fade-out
			FadeOutDuration = 1,   -- Thời gian fade-out (opaque → transparent)
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
