-- AudioConfig.lua
-- Cấu hình âm thanh và animation toàn game FrozenState
-- Hệ thống 2 tầng: Default (mặc định) + Overrides (theo SkinId của Icicle hoặc Block)
-- Thêm skin đặc biệt vào bảng Overrides để ghi đè âm thanh/animation tương ứng

local AudioConfig = {

	-- =========================================================
	-- NHẠC NỀN
	-- =========================================================
	Music = {
		Lobby       = 1846271108,   -- Nhạc khi ở lobby (không tham gia trận)
		InGame      = 92288659295773,   -- Nhạc khi đang trong trận
		FrozenState = 135654634674766,   -- Nhạc khi kích hoạt Frozen State (45 giây cuối)
	},

	-- =========================================================
	-- ÂM THANH VÀ ANIMATION MẶC ĐỊNH
	-- Dùng khi item trang bị không có override riêng
	-- =========================================================
	Default = {
		-- Swing: random 1 trong 3 âm thanh mỗi lần vung
		SwingAudios    = {136455914086398, 134318072265347, 136610895235499},
		--SwingAnimation = 123684645672968,  -- Animation khi vung Icicle
		SwingAnimation = 128425806238119,  -- Animation khi vung Icicle

		-- Cửa sổ Hitbox active (giây) — phải khớp với giai đoạn 'vung' trong animation
		-- HitStart: thời điểm bắt đầu đập xuống | HitEnd: thời điểm tay chạm đáy
		HitStartTime   = 0.167,  -- Giây kể từ lúc Activated
		HitEndTime     = 0.333,  -- Giây kể từ lúc Activated

		FreezeAudio    = 92048469072346,   -- Âm thanh khi đóng băng ai đó
		ThawAudio      = 138690892117059,  -- Âm thanh khi giải cứu ai đó
		PoseAnimation  = 127604545127643,  -- Animation của victim khi bị đóng băng
	},

	-- =========================================================
	-- OVERRIDE THEO SKIN
	-- Key là SkinId của Icicle hoặc Block (vd: "GoldenIcicle", "CrystalBlock")
	-- Chỉ cần khai báo trường cần ghi đè, không cần khai báo hết
	--
	-- Icicle skin ghi đè:  SwingAudios, SwingAnimation
	-- Block skin ghi đè:   FreezeAudio, ThawAudio, PoseAnimation
	--
	-- Í dụ:
	-- ["GoldenIcicle"] = {
	--     SwingAudios    = { 111111111, 222222222, 333333333 },
	--     SwingAnimation = 444444444,
	--     HitStartTime   = 0.2,   -- Nếu animation skin này có timing khác
	--     HitEndTime     = 0.4,
	-- },
	-- ["CrystalBlock"] = {
	--     FreezeAudio   = 555555555,
	--     ThawAudio     = 666666666,
	--     PoseAnimation = 777777777,
	-- },
	-- =========================================================
	Overrides = {
		-- Thêm override cho skin đặc biệt tại đây
	},

}

-- =========================================================
-- HELPER: Lấy âm thanh swing theo SkinId (Icicle)
-- Trả về SwingAudios (table) từ override nếu có, không thì default
-- =========================================================
function AudioConfig.GetSwingAudios(IcicleSkinId)
	local Override = IcicleSkinId and AudioConfig.Overrides[IcicleSkinId]
	if Override and Override.SwingAudios then
		return Override.SwingAudios
	end
	return AudioConfig.Default.SwingAudios
end

-- =========================================================
-- HELPER: Lấy animation swing theo SkinId (Icicle)
-- =========================================================
function AudioConfig.GetSwingAnimation(IcicleSkinId)
	local Override = IcicleSkinId and AudioConfig.Overrides[IcicleSkinId]
	if Override and Override.SwingAnimation then
		return Override.SwingAnimation
	end
	return AudioConfig.Default.SwingAnimation
end

-- =========================================================
-- HELPER: Lấy thời điểm bắt đầu cửa sổ Hitbox theo SkinId (Icicle)
-- =========================================================
function AudioConfig.GetHitStartTime(IcicleSkinId)
	local Override = IcicleSkinId and AudioConfig.Overrides[IcicleSkinId]
	if Override and Override.HitStartTime then
		return Override.HitStartTime
	end
	return AudioConfig.Default.HitStartTime
end

-- =========================================================
-- HELPER: Lấy thời điểm kết thúc cửa sổ Hitbox theo SkinId (Icicle)
-- =========================================================
function AudioConfig.GetHitEndTime(IcicleSkinId)
	local Override = IcicleSkinId and AudioConfig.Overrides[IcicleSkinId]
	if Override and Override.HitEndTime then
		return Override.HitEndTime
	end
	return AudioConfig.Default.HitEndTime
end

-- =========================================================
-- HELPER: Lấy freeze audio theo SkinId (Block)
-- =========================================================
function AudioConfig.GetFreezeAudio(BlockSkinId)
	local Override = BlockSkinId and AudioConfig.Overrides[BlockSkinId]
	if Override and Override.FreezeAudio then
		return Override.FreezeAudio
	end
	return AudioConfig.Default.FreezeAudio
end

-- =========================================================
-- HELPER: Lấy thaw audio theo SkinId (Block)
-- =========================================================
function AudioConfig.GetThawAudio(BlockSkinId)
	local Override = BlockSkinId and AudioConfig.Overrides[BlockSkinId]
	if Override and Override.ThawAudio then
		return Override.ThawAudio
	end
	return AudioConfig.Default.ThawAudio
end

-- =========================================================
-- HELPER: Lấy pose animation theo SkinId (Block)
-- =========================================================
function AudioConfig.GetPoseAnimation(BlockSkinId)
	local Override = BlockSkinId and AudioConfig.Overrides[BlockSkinId]
	if Override and Override.PoseAnimation then
		return Override.PoseAnimation
	end
	return AudioConfig.Default.PoseAnimation
end

return AudioConfig
