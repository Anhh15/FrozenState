-- AudioConfig.lua
-- Cấu hình âm thanh toàn game FrozenState
-- Hệ thống 2 tầng: Default (mặc định) + Overrides (theo SkinId của Icicle hoặc Block)
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local AudioConfig = {

	-- =========================================================
	-- NHẠC NỀN (BGM)
	-- =========================================================
	Music = {
		Lobby          = 1846271108,      -- Nhạc khi ở lobby (không tham gia trận)
		InGame         = 92288659295773,  -- Nhạc khi đang trong trận
		FrozenState    = 135654634674766, -- Nhạc khi kích hoạt Frozen State (45 giây cuối)
		GameOver       = 132515049116690, -- Nhạc nền khi kết thúc trận (GameOver phase)
		GameLoading    = 127066705522583, -- Nhạc nền màn hình tải game (nil = im lặng)
		DefaultVolume  = 0.3,             -- Âm lượng mặc định cho nhạc nền
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
	-- ÂM THANH MÀN HÌNH ĐẶC BIỆT (SPECIAL GUI)
	-- =========================================================
	Special = {
		ModeAnnouncement       = 75713209190949,  -- Âm thanh thông báo chế độ chơi đặc biệt
		ModeAnnouncementVolume = 3,               -- Âm lượng phát thông báo chế độ
	},

	-- =========================================================
	-- ÂM THANH GIAO DIỆN (GUI)
	-- =========================================================
	Gui = {
		ButtonClick      = 7249903719,       -- Âm thanh khi nhấn nút thông thường
		MouseEnter       = 137872392480008,  -- Âm thanh khi hover chuột vào nút
		CloseButtonClick = 103307955424380,  -- Âm thanh khi nhấn nút đóng giao diện (X)
	},

	-- =========================================================
	-- ÂM THANH DANH HIỆU (ACCOLADES)
	-- =========================================================
	Accolades = {
		Announcement       = 96102213526905,   -- Âm thanh khi đạt First Blood, Spree
		AnnouncementVolume = 3,                -- Âm lượng phát thông báo danh hiệu
	},

	-- =========================================================
	-- ÂM THANH CỬA HÀNG (SHOP)
	-- =========================================================
	Shop = {
		ChestBuy         = 113890702074571,  -- Âm thanh khi mua rương thành công
		ChestBuyVolume   = 5,                -- Âm lượng phát khi mua rương thành công
		BuyFail          = 128827503277042,  -- Âm thanh khi mua thất bại (thiếu tiền)
	},

	-- =========================================================
	-- ÂM THANH NHIỆM VỤ (QUEST)
	-- =========================================================
	Quest = {
		RewardClaim      = 116439187028468,  -- Âm thanh khi nhận thưởng hoàn thành quest
	},

	-- =========================================================
	-- ÂM THANH THỐNG KÊ (STATS & MATCH END)
	-- =========================================================
	Stats = {
		Overall          = 119804136935260,  -- Âm thanh khi hiển thị bảng PlayerStats sau trận
		StaggerCount     = 132948338000932,  -- Âm thanh phát cho từng dòng thống kê khi bung ra
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
-- PUBLIC GETTERS & UTILITIES
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

--- Thu thập tất cả Audio ID trong config để preload vào RAM
--- @return table -- { number, ... }
function AudioConfig.GetAllAudioIds()
	local AudioIdSet = {}
	local AudioIdList = {}

	local function Collect(Value)
		if type(Value) == "number" and Value >= 1000 and math.floor(Value) == Value then
			if not AudioIdSet[Value] then
				AudioIdSet[Value] = true
				table.insert(AudioIdList, Value)
			end
		elseif type(Value) == "table" then
			for _, SubValue in pairs(Value) do
				Collect(SubValue)
			end
		end
	end

	Collect(AudioConfig.Music)
	Collect(AudioConfig.ItemReward)
	Collect(AudioConfig.Special)
	Collect(AudioConfig.Gui)
	Collect(AudioConfig.Accolades)
	Collect(AudioConfig.Shop)
	Collect(AudioConfig.Quest)
	Collect(AudioConfig.Stats)
	Collect(AudioConfig.Default)
	Collect(AudioConfig.Overrides)

	return AudioIdList
end

return AudioConfig
