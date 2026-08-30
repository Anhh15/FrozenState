-- AudioConfig.lua
-- Cấu hình âm thanh toàn game FrozenState
-- Chuẩn hóa dữ liệu theo AudioEntry: { Id = number, Volume = number, ... }
-- Hệ thống 2 tầng: Default (mặc định) + Overrides (theo MenuName hoặc SkinId)
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local AudioConfig = {

	-- =========================================================
	-- 1. ÂM THANH GIAO DIỆN (GUI)
	-- =========================================================
	Gui = {
		Default = {
			ButtonClick      = { Id = 7249903719,       Volume = 0.8 },
			MouseEnter       = { Id = 137872392480008,  Volume = 0.35 }, -- Âm lượng hover dịu nhẹ
			CloseButtonClick = { Id = 103307955424380,  Volume = 0.8 },
		},
		-- Ghi đè âm thanh theo từng Menu cụ thể nếu cần
		Overrides = {
			-- Ví dụ: Shop = { ButtonClick = { Id = ..., Volume = ... } }
		},
	},

	-- =========================================================
	-- 2. NHẠC NỀN (BGM)
	-- =========================================================
	Music = {
		DefaultVolume = 0.3,
		Tracks = {
			Lobby       = { Id = 1846271108,      Volume = 0.3 },
			Ready       = { Id = 140401222967075,  Volume = 0.3 },
			InGame      = { Id = 92288659295773,  Volume = 0.3 },
			FrozenState = { Id = 135654634674766, Volume = 0.3 },
			GameOver    = { Id = 132515049116690, Volume = 0.6 },
			GameLoading = { Id = 127066705522583, Volume = 0.25 },
		},
	},

	-- =========================================================
	-- 3. ÂM THANH ITEM REWARD (HIỆU ỨNG MỞ RƯƠNG VÀ PHẦN THƯỞNG)
	-- =========================================================
	ItemReward = {
		ChestClick        = { Id = 74139702398034, Volumes = { 0.5, 0.75, 1.0 } },
		Phase2Transition  = { Id = 4612378086,     Volume = 0.9 },
	},

	-- =========================================================
	-- 4. ÂM THANH MÀN HÌNH ĐẶC BIỆT (SPECIAL GUI)
	-- =========================================================
	Special = {
		ModeAnnouncement        = { Id = 75713209190949,  Volume = 1.0 },
		FrozenStateAnnouncement = { Id = 117797923415428, Volume = 1.0 },
	},

	-- =========================================================
	-- 5. ÂM THANH DANH HIỆU (ACCOLADES)
	-- =========================================================
	Accolades = {
		Announcement      = { Id = 96102213526905, Volume = 1.0 },
	},

	-- =========================================================
	-- 6. ÂM THANH CỬA HÀNG (SHOP)
	-- =========================================================
	Shop = {
		ChestBuy          = { Id = 113890702074571, Volume = 1.0 },
		BuyFail           = { Id = 128827503277042, Volume = 0.7 },
	},

	-- =========================================================
	-- 7. ÂM THANH NHIỆM VỤ (QUEST)
	-- =========================================================
	Quest = {
		RewardClaim       = { Id = 116439187028468, Volume = 0.8 },
	},

	-- =========================================================
	-- 8. ÂM THANH THỐNG KÊ (STATS & MATCH END)
	-- =========================================================
	Stats = {
		Overall           = { Id = 119804136935260, Volume = 0.8 },
		StaggerCount      = { Id = 132948338000932, Volume = 0.4 },
	},

	-- =========================================================
	-- 9. ÂM THANH CÀI ĐẶT (SETTING)
	-- =========================================================
	Setting = {
		Toggle            = { Id = 139077385959653, Volume = 0.8 },
	},

	-- =========================================================
	-- 10. ÂM THANH GAMEPLAY (3D SPATIAL & WEAPONS)
	-- =========================================================
	Gameplay = {
		Default = {
			SwingAudios   = { Ids = { 136455914086398 }, Volume = 0.8, MaxDistance = 60 },
			FreezeAudio   = { Id = 92048469072346,     Volume = 1.0, MaxDistance = 80 },
			ThawAudio     = { Id = 138690892117059,    Volume = 1.0, MaxDistance = 80 },
		},
		Overrides = {
			-- Skin overrides theo SkinId (vd: "GoldenIcicle", "CrystalBlock")
		},
	},

	-- Tương thích ngược (Fallback compatibility)
	Default = {
		SwingAudios = { 136455914086398 },
		FreezeAudio = 92048469072346,
		ThawAudio   = 138690892117059,
	},
	Overrides = {},

}

-- =========================================================
-- PUBLIC GETTERS & RESOLUTION UTILITIES
-- =========================================================

--- Lấy AudioEntry của GUI theo ActionName và MenuName (kết hợp Default và Overrides)
--- @param ActionName string -- "ButtonClick" | "MouseEnter" | "CloseButtonClick"
--- @param MenuName string? -- "Shop" | "Inventory" | "Quest" | "Profile" | ...
--- @return table -- { Id = number, Volume = number }
function AudioConfig.GetGuiAudio(ActionName, MenuName)
	if not ActionName then return { Id = nil, Volume = 1 } end

	local MenuOverride = MenuName and AudioConfig.Gui.Overrides and AudioConfig.Gui.Overrides[MenuName]
	if MenuOverride and MenuOverride[ActionName] then
		return MenuOverride[ActionName]
	end

	local DefaultEntry = AudioConfig.Gui.Default and AudioConfig.Gui.Default[ActionName]
	if DefaultEntry then
		return DefaultEntry
	end

	return { Id = nil, Volume = 1 }
end

--- Lấy AudioEntry của bản nhạc nền theo MusicKey
--- @param MusicKey string?
--- @return table -- { Id = number?, Volume = number }
function AudioConfig.GetMusicAudio(MusicKey)
	local Track = MusicKey and AudioConfig.Music.Tracks and AudioConfig.Music.Tracks[MusicKey]
	if Track then
		return Track
	end
	return { Id = nil, Volume = AudioConfig.Music.DefaultVolume or 0.3 }
end

--- Lấy âm lượng cơ sở cho bản nhạc theo MusicKey
--- @param MusicKey string?
--- @return number
function AudioConfig.GetMusicVolume(MusicKey)
	local Track = AudioConfig.GetMusicAudio(MusicKey)
	return (Track and Track.Volume) or (AudioConfig.Music.DefaultVolume or 0.3)
end

--- Lấy AudioEntry cho Gameplay SFX theo ActionKey và SkinId
--- @param ActionKey string -- "SwingAudios" | "FreezeAudio" | "ThawAudio"
--- @param SkinId string?
--- @return table -- { Id = number?, Ids = table?, Volume = number, MaxDistance = number }
function AudioConfig.GetGameplayAudio(ActionKey, SkinId)
	local SkinOverride = SkinId and AudioConfig.Gameplay.Overrides and AudioConfig.Gameplay.Overrides[SkinId]
	if SkinOverride and SkinOverride[ActionKey] then
		return SkinOverride[ActionKey]
	end

	local DefaultEntry = AudioConfig.Gameplay.Default and AudioConfig.Gameplay.Default[ActionKey]
	if DefaultEntry then
		return DefaultEntry
	end

	return { Volume = 1, MaxDistance = 60 }
end

--- Lấy âm thanh swing theo SkinId (Icicle)
--- @param IcicleSkinId string?
--- @return table -- { Ids = { number, ... }, Volume = number, MaxDistance = number }
function AudioConfig.GetSwingAudios(IcicleSkinId)
	return AudioConfig.GetGameplayAudio("SwingAudios", IcicleSkinId)
end

--- Lấy freeze audio theo SkinId (Block)
--- @param BlockSkinId string?
--- @return table -- { Id = number, Volume = number, MaxDistance = number }
function AudioConfig.GetFreezeAudio(BlockSkinId)
	return AudioConfig.GetGameplayAudio("FreezeAudio", BlockSkinId)
end

--- Lấy thaw audio theo SkinId (Block)
--- @param BlockSkinId string?
--- @return table -- { Id = number, Volume = number, MaxDistance = number }
function AudioConfig.GetThawAudio(BlockSkinId)
	return AudioConfig.GetGameplayAudio("ThawAudio", BlockSkinId)
end

--- Thu thập tất cả Audio ID trong config để preload vào RAM một cách chính xác
--- @return table -- { number, ... }
function AudioConfig.GetAllAudioIds()
	local AudioIdSet = {}
	local AudioIdList = {}

	local function AddId(Id)
		if type(Id) == "number" and Id >= 1000 and math.floor(Id) == Id then
			if not AudioIdSet[Id] then
				AudioIdSet[Id] = true
				table.insert(AudioIdList, Id)
			end
		end
	end

	local function CollectFromTable(TableObj)
		if type(TableObj) ~= "table" then return end

		-- Nếu là AudioEntry có trường Id hoặc Ids
		if TableObj.Id then
			AddId(TableObj.Id)
		end
		if type(TableObj.Ids) == "table" then
			for _, SubId in ipairs(TableObj.Ids) do
				AddId(SubId)
			end
		end

		-- Duyệt đệ quy các bảng con
		for Key, SubValue in pairs(TableObj) do
			if Key ~= "Volumes" and Key ~= "Volume" and Key ~= "DefaultVolume" and Key ~= "MaxDistance" then
				if type(SubValue) == "table" then
					CollectFromTable(SubValue)
				elseif type(SubValue) == "number" then
					AddId(SubValue)
				end
			end
		end
	end

	CollectFromTable(AudioConfig.Gui)
	CollectFromTable(AudioConfig.Music)
	CollectFromTable(AudioConfig.ItemReward)
	CollectFromTable(AudioConfig.Special)
	CollectFromTable(AudioConfig.Accolades)
	CollectFromTable(AudioConfig.Shop)
	CollectFromTable(AudioConfig.Quest)
	CollectFromTable(AudioConfig.Stats)
	CollectFromTable(AudioConfig.Setting)
	CollectFromTable(AudioConfig.Gameplay)

	return AudioIdList
end

return AudioConfig
