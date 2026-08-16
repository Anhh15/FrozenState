-- AudioConfig.lua
-- Cấu hình âm thanh toàn game FrozenState
-- Hệ thống 2 tầng: Default (mặc định) + Overrides (theo SkinId của Icicle hoặc Block)
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local AudioConfig = {

	-- =========================================================
	-- NHẠC NỀN (BGM)
	-- =========================================================
	Music = {
		Lobby       = 1846271108,      -- Nhạc khi ở lobby (không tham gia trận)
		InGame      = 92288659295773,  -- Nhạc khi đang trong trận
		FrozenState = 135654634674766, -- Nhạc khi kích hoạt Frozen State (45 giây cuối)
	},

	-- =========================================================
	-- ÂM THANH ITEM REWARD (HIỆU ỨNG MỞ RƯƠNG VÀ PHẦN THƯỞNG)
	-- =========================================================
	ItemReward = {
		ChestClick        = 74139702398034,  -- Âm thanh phát mỗi lần nhấn rương ở Pha 1
		Phase2Transition  = 4612378086,      -- Âm thanh chuyển sang Pha 2 (hiển thị item)
		ChestClickVolumes = {1, 3, 5},       -- Mức âm lượng tăng dần qua 3 lần nhấn
	},

	-- =========================================================
	-- ÂM THANH MẶC ĐỊNH
	-- Dùng khi item trang bị không có override riêng
	-- =========================================================
	Default = {
		-- Swing: âm thanh phát mỗi lần vung vũ khí
		SwingAudios = {136455914086398},
		FreezeAudio = 92048469072346,   -- Âm thanh khi đóng băng mục tiêu
		ThawAudio   = 138690892117059,  -- Âm thanh khi giải cứu đồng đội
	},

	-- =========================================================
	-- OVERRIDE THEO SKIN
	-- Key là SkinId của Icicle hoặc Block (vd: "GoldenIcicle", "CrystalBlock")
	-- Chỉ cần khai báo trường cần ghi đè
	-- =========================================================
	Overrides = {
		-- Thêm override cho skin đặc biệt tại đây
	},

}

-- =========================================================
-- PUBLIC GETTERS
-- =========================================================

--- Lấy âm thanh swing theo SkinId (Icicle)
--- @param IcicleSkinId string?
--- @return table -- { number, ... }
function AudioConfig.GetSwingAudios(IcicleSkinId)
	local Override = IcicleSkinId and AudioConfig.Overrides[IcicleSkinId]
	if Override and Override.SwingAudios then
		return Override.SwingAudios
	end
	return AudioConfig.Default.SwingAudios
end

--- Lấy freeze audio theo SkinId (Block)
--- @param BlockSkinId string?
--- @return number
function AudioConfig.GetFreezeAudio(BlockSkinId)
	local Override = BlockSkinId and AudioConfig.Overrides[BlockSkinId]
	if Override and Override.FreezeAudio then
		return Override.FreezeAudio
	end
	return AudioConfig.Default.FreezeAudio
end

--- Lấy thaw audio theo SkinId (Block)
--- @param BlockSkinId string?
--- @return number
function AudioConfig.GetThawAudio(BlockSkinId)
	local Override = BlockSkinId and AudioConfig.Overrides[BlockSkinId]
	if Override and Override.ThawAudio then
		return Override.ThawAudio
	end
	return AudioConfig.Default.ThawAudio
end

return AudioConfig
