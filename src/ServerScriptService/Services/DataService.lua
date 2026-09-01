-- DataService.lua
-- Quản lý toàn bộ dữ liệu bền vững (DataStore) của người chơi
-- Wrap ProfileService để che đi complexity, cung cấp API đơn giản cho các service khác

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileService    = require(ReplicatedStorage.Shared.Lib.ProfileService)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local DataConfig        = require(ReplicatedStorage.Shared.Config.DataConfig)
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- SCHEMA MẶC ĐỊNH — Dữ liệu bền vững của mỗi người chơi
-- Thêm field mới vào đây khi cần ở các phase sau
-- =========================================================

local PROFILE_TEMPLATE = {
	Money               = 0,
	TotalWins           = 0,
	TotalFreezes        = 0,
	TotalThaws          = 0,
	TotalFreezingSpree  = 0,
	TotalThawingSpree   = 0,
	TotalFirstBlood     = 0,
	TotalLastStanding   = 0,
	OwnedCosmetics      = {},   -- Giữ lại để tương thích ngược (không xóa)
	OwnedIcicles        = {},   -- Phase 5: danh sách Icicle skin sở hữu
	OwnedBlocks         = {},   -- Phase 5: danh sách Block skin sở hữu
	EquippedIcicle      = "Default",
	EquippedIceBlock    = "Default",

	-- Phase 7 / Objective Engine 2.0: Quest & Milestone Data
	PlayTime            = 0,    -- Tổng thời gian chơi (giây), cộng dồn mỗi session
	QuestData           = {
		Daily = {
			ResetTimestamp = 0,
			ResetsUsed     = 0,  -- Số lần làm mới toàn bộ daily quest đã sử dụng trong chu kỳ 24h
			Quests         = {}, -- { [QuestId] = { Progress = 0, Completed = false, Claimed = false } }
		},
		Milestone = {
			Quests = {}, -- { [QuestId] = { Progress = 0, Completed = false, Claimed = false } }
		},
	},
	DailyQuestData      = {     -- Giữ lại để tương thích ngược
		ResetTimestamp = 0,
		ActiveQuests   = {},
	},
	MilestoneQuestData  = {},   -- Giữ lại để tương thích ngược

	-- Settings (Âm lượng & Thiết lập cá nhân)
	Settings            = {
		MasterVolume = DataConfig.DefaultSettings.MasterVolume,
		MusicVolume  = DataConfig.DefaultSettings.MusicVolume,
		SFXVolume    = DataConfig.DefaultSettings.SFXVolume,
		UIVolume     = DataConfig.DefaultSettings.UIVolume,
	},

	-- Phase 9: Lịch sử giao dịch mua hàng qua Robux (Chống duplicate receipt)
	PurchaseHistory     = {},   -- Array lưu các PurchaseId (string) đã xử lý thành công
}

-- =========================================================
-- KHỞI TẠO PROFILESERVICE
-- =========================================================

local PlayerStore = ProfileService.GetProfileStore(DataConfig.ProfileStoreName, PROFILE_TEMPLATE)

-- Lưu trữ profile đang active: { [player] = profile }
local ActiveProfiles = {}
local _ProfileLoadedBindable = Instance.new("BindableEvent")

-- =========================================================
-- PRIVATE FUNCTIONS
-- =========================================================

--- Xử lý khi profile được load thành công cho một player
local function OnProfileLoaded(Player, Profile)
	-- Reconcile: điền vào những field còn thiếu so với template (data migration)
	Profile:Reconcile()

	-- Đảm bảo cấu trúc QuestData 2.0 luôn tồn tại (Migration an toàn)
	if not Profile.Data.QuestData then
		Profile.Data.QuestData = {
			Daily = {
				ResetTimestamp = (Profile.Data.DailyQuestData and Profile.Data.DailyQuestData.ResetTimestamp) or 0,
				Quests = {},
			},
			Milestone = {
				Quests = {},
			},
		}
	end
	if not Profile.Data.QuestData.Daily then
		Profile.Data.QuestData.Daily = { ResetTimestamp = 0, Quests = {} }
	end
	if not Profile.Data.QuestData.Milestone then
		Profile.Data.QuestData.Milestone = { Quests = {} }
	end

	-- Lắng nghe nếu profile bị release từ bên ngoài (server khác force-load)
	Profile:ListenToRelease(function()
		ActiveProfiles[Player] = nil
		-- Kick player vì dữ liệu không còn hợp lệ trong session này
		Player:Kick("[FrozenState] Dữ liệu của bạn đã được tải ở nơi khác. Vui lòng kết nối lại.")
	end)

	if Player:IsDescendantOf(Players) then
		ActiveProfiles[Player] = Profile
		_ProfileLoadedBindable:Fire(Player, Profile)
		print(("[DataService] Profile đã load: %s | Money: %d"):format(Player.Name, Profile.Data.Money))
	else
		-- Player đã rời server trước khi profile load xong
		Profile:Release()
	end
end

--- Xử lý khi player join
local function OnPlayerAdded(Player)
	local Profile = PlayerStore:LoadProfileAsync(
		("Player_%d"):format(Player.UserId),
		"ForceLoad"
	)

	if Profile ~= nil then
		OnProfileLoaded(Player, Profile)
	else
		-- ProfileService không thể load (DataStore bị lỗi)
		Player:Kick("[FrozenState] Không thể tải dữ liệu. Vui lòng thử lại.")
	end
end

--- Xử lý khi player rời server
local function OnPlayerRemoving(Player)
	local Profile = ActiveProfiles[Player]
	if Profile ~= nil then
		Profile:Release()
		ActiveProfiles[Player] = nil
		print(("[DataService] Profile đã release: %s"):format(Player.Name))
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local DataService = {}

--- Chờ cho đến khi Profile của player được nạp xong từ DataStore (hoặc hết timeout)
--- @param Player Player
--- @param Timeout number?
--- @return table | nil -- Profile hoặc nil nếu timeout/player rời server
function DataService.WaitForProfile(Player, Timeout)
	if not Player then return nil end
	if ActiveProfiles[Player] then
		return ActiveProfiles[Player]
	end
	if not Player:IsDescendantOf(Players) then
		return nil
	end

	Timeout = Timeout or DataConfig.ProfileLoadTimeout
	local StartTime = os.clock()
	local ProfileResult = nil

	local Connection
	Connection = _ProfileLoadedBindable.Event:Connect(function(LoadedPlayer, Profile)
		if LoadedPlayer == Player then
			ProfileResult = Profile
		end
	end)

	while not ProfileResult and (os.clock() - StartTime < Timeout) and Player:IsDescendantOf(Players) do
		task.wait(0.05)
	end

	if Connection then
		Connection:Disconnect()
	end

	return ProfileResult or ActiveProfiles[Player]
end

--- Chờ cho đến khi Data của player sẵn sàng
--- @param Player Player
--- @param Timeout number?
--- @return table | nil -- Data hoặc nil
function DataService.WaitForData(Player, Timeout)
	local Profile = DataService.WaitForProfile(Player, Timeout)
	return Profile and Profile.Data or nil
end

--- Lấy profile của player (trả về nil nếu chưa load xong)
--- @param Player Player
--- @return table | nil
function DataService.GetProfile(Player)
	return ActiveProfiles[Player]
end

--- Lấy dữ liệu của player (shorthand an toàn hơn)
--- @param Player Player
--- @return table | nil  -- Profile.Data hoặc nil
function DataService.GetData(Player)
	local Profile = ActiveProfiles[Player]
	return Profile and Profile.Data or nil
end

--- Cộng tiền cho player
--- @param Player Player
--- @param Amount number
function DataService.AddMoney(Player, Amount)
	local Profile = ActiveProfiles[Player]
	if not Profile then
		warn(("[DataService] AddMoney: Không tìm thấy profile của %s"):format(Player.Name))
		return
	end
	Profile.Data.Money = math.max(0, Profile.Data.Money + Amount)
	return Profile.Data.Money
end

--- Gán trực tiếp số tiền cho player
--- @param Player Player
--- @param Amount number
--- @return number?
function DataService.SetMoney(Player, Amount)
	local Profile = ActiveProfiles[Player]
	if not Profile then
		warn(("[DataService] SetMoney: Không tìm thấy profile của %s"):format(Player.Name))
		return nil
	end
	Profile.Data.Money = math.max(0, math.floor(Amount or 0))
	return Profile.Data.Money
end

--- Gán giá trị cụ thể cho một stat của player
--- @param Player Player
--- @param StatName string
--- @param Value any
--- @return boolean
function DataService.SetStat(Player, StatName, Value)
	local Profile = ActiveProfiles[Player]
	if not Profile then
		warn(("[DataService] SetStat: Không tìm thấy profile của %s"):format(Player.Name))
		return false
	end
	if PROFILE_TEMPLATE[StatName] == nil then
		warn(("[DataService] SetStat: StatName '%s' không tồn tại trong PROFILE_TEMPLATE."):format(StatName))
		return false
	end
	Profile.Data[StatName] = Value
	return true
end

--- Tăng một stat của player lên Amount (mặc định 1)
--- @param Player Player
--- @param StatName string   -- tên field trong PROFILE_TEMPLATE
--- @param Amount number
function DataService.IncrementStat(Player, StatName, Amount)
	Amount = Amount or 1
	local Profile = ActiveProfiles[Player]
	if not Profile then
		warn(("[DataService] IncrementStat: Không tìm thấy profile của %s"):format(Player.Name))
		return
	end
	if type(Profile.Data[StatName]) ~= "number" then
		warn(("[DataService] IncrementStat: '%s' không phải kiểu number."):format(StatName))
		return
	end
	Profile.Data[StatName] = Profile.Data[StatName] + Amount
end

--- Trang bị cosmetic (icicle hoặc ice block)
--- @param Player Player
--- @param SlotName string   -- "EquippedIcicle" hoặc "EquippedIceBlock"
--- @param ItemId string
--- @return boolean  -- true nếu thành công
function DataService.EquipCosmetic(Player, SlotName, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return false end

	local ValidSlots = { EquippedIcicle = true, EquippedIceBlock = true }
	if not ValidSlots[SlotName] then
		warn(("[DataService] EquipCosmetic: SlotName '%s' không hợp lệ."):format(SlotName))
		return false
	end

	-- Kiểm tra quyền sở hữu (Default luôn được phép)
	if ItemId ~= "Default" then
		-- Xác định array sở hữu đúng theo slot
		local OwnedList = (SlotName == "EquippedIcicle")
			and Profile.Data.OwnedIcicles
			or  Profile.Data.OwnedBlocks
		local Owned = false
		for _, OwnedId in ipairs(OwnedList) do
			if OwnedId == ItemId then
				Owned = true
				break
			end
		end
		if not Owned then
			warn(("[DataService] EquipCosmetic: %s không sở hữu '%s'."):format(Player.Name, ItemId))
			return false
		end
	end

	Profile.Data[SlotName] = ItemId
	return true
end

--- Kiểm tra player có sở hữu item không
--- @param Player Player
--- @param ItemType string  -- "Icicle" hoặc "Block"
--- @param ItemId string
--- @return boolean
function DataService.HasItem(Player, ItemType, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return false end

	if ItemId == "Default" then return true end

	local OwnedList = (ItemType == "Icicle")
		and Profile.Data.OwnedIcicles
		or  Profile.Data.OwnedBlocks

	for _, OwnedId in ipairs(OwnedList) do
		if OwnedId == ItemId then return true end
	end
	return false
end

--- Thêm Icicle skin vào danh sách sở hữu (không trùng lặp)
--- @param Player Player
--- @param ItemId string
function DataService.AddIcicle(Player, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end

	for _, OwnedId in ipairs(Profile.Data.OwnedIcicles) do
		if OwnedId == ItemId then return end
	end
	table.insert(Profile.Data.OwnedIcicles, ItemId)
end

--- Thu hồi / Xóa Icicle skin khỏi danh sách sở hữu
--- @param Player Player
--- @param ItemId string
--- @return boolean
function DataService.RemoveIcicle(Player, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile or ItemId == "Default" then return false end

	local Index = table.find(Profile.Data.OwnedIcicles, ItemId)
	if Index then
		table.remove(Profile.Data.OwnedIcicles, Index)
		if Profile.Data.EquippedIcicle == ItemId then
			Profile.Data.EquippedIcicle = "Default"
		end
		return true
	end
	return false
end

--- Thêm Block skin vào danh sách sở hữu (không trùng lặp)
--- @param Player Player
--- @param ItemId string
function DataService.AddBlock(Player, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end

	for _, OwnedId in ipairs(Profile.Data.OwnedBlocks) do
		if OwnedId == ItemId then return end
	end
	table.insert(Profile.Data.OwnedBlocks, ItemId)
end

--- Thu hồi / Xóa Block skin khỏi danh sách sở hữu
--- @param Player Player
--- @param ItemId string
--- @return boolean
function DataService.RemoveBlock(Player, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile or ItemId == "Default" then return false end

	local Index = table.find(Profile.Data.OwnedBlocks, ItemId)
	if Index then
		table.remove(Profile.Data.OwnedBlocks, Index)
		if Profile.Data.EquippedIceBlock == ItemId then
			Profile.Data.EquippedIceBlock = "Default"
		end
		return true
	end
	return false
end

--- Xóa sạch toàn bộ skin đã sở hữu và fallback về Default
--- @param Player Player
--- @param SkinType string? -- "Icicle" | "Block" | nil (cả 2)
function DataService.ClearSkins(Player, SkinType)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end

	if SkinType == "Icicle" or SkinType == nil then
		Profile.Data.OwnedIcicles = {}
		Profile.Data.EquippedIcicle = "Default"
	end
	if SkinType == "Block" or SkinType == nil then
		Profile.Data.OwnedBlocks = {}
		Profile.Data.EquippedIceBlock = "Default"
	end
end

--- Cấp toàn bộ skin có trong catalog cho player
--- @param Player Player
function DataService.GiveAllSkins(Player)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end

	for _, Item in ipairs(ItemRegistry.GetAllIcicles()) do
		if Item.Id ~= "Default" then
			DataService.AddIcicle(Player, Item.Id)
		end
	end

	for _, Item in ipairs(ItemRegistry.GetAllBlocks()) do
		if Item.Id ~= "Default" then
			DataService.AddBlock(Player, Item.Id)
		end
	end
end

--- Reset toàn bộ dữ liệu người chơi về template mặc định
--- @param Player Player
function DataService.ResetProfileData(Player)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end

	Profile.Data.Money              = PROFILE_TEMPLATE.Money
	Profile.Data.TotalWins          = PROFILE_TEMPLATE.TotalWins
	Profile.Data.TotalFreezes       = PROFILE_TEMPLATE.TotalFreezes
	Profile.Data.TotalThaws         = PROFILE_TEMPLATE.TotalThaws
	Profile.Data.TotalFreezingSpree = PROFILE_TEMPLATE.TotalFreezingSpree
	Profile.Data.TotalThawingSpree  = PROFILE_TEMPLATE.TotalThawingSpree
	Profile.Data.TotalFirstBlood    = PROFILE_TEMPLATE.TotalFirstBlood
	Profile.Data.TotalLastStanding  = PROFILE_TEMPLATE.TotalLastStanding
	Profile.Data.OwnedCosmetics     = {}
	Profile.Data.OwnedIcicles       = {}
	Profile.Data.OwnedBlocks        = {}
	Profile.Data.EquippedIcicle     = PROFILE_TEMPLATE.EquippedIcicle
	Profile.Data.EquippedIceBlock   = PROFILE_TEMPLATE.EquippedIceBlock
	Profile.Data.PlayTime           = 0
	Profile.Data.DailyQuestData     = {
		ResetTimestamp = 0,
		ActiveQuests   = {},
	}
	Profile.Data.MilestoneQuestData = {}
	Profile.Data.PurchaseHistory    = {}
end

--- Xóa lịch sử mua Robux (để test lại biên lai)
--- @param Player Player
function DataService.ClearPurchaseHistory(Player)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	Profile.Data.PurchaseHistory = {}
end

--- Lấy bản copy dữ liệu an toàn để đồng bộ xuống Client
--- @param Player Player
--- @return table?
function DataService.GetFullDataCopy(Player)
	local Profile = ActiveProfiles[Player]
	if not Profile or not Profile.Data then return nil end
	local Data = Profile.Data
	return {
		Money              = Data.Money,
		TotalWins          = Data.TotalWins,
		TotalFreezes       = Data.TotalFreezes,
		TotalThaws         = Data.TotalThaws,
		TotalFreezingSpree = Data.TotalFreezingSpree,
		TotalThawingSpree  = Data.TotalThawingSpree,
		TotalFirstBlood    = Data.TotalFirstBlood,
		TotalLastStanding  = Data.TotalLastStanding,
		OwnedIcicles       = Data.OwnedIcicles,
		OwnedBlocks        = Data.OwnedBlocks,
		EquippedIcicle     = Data.EquippedIcicle,
		EquippedIceBlock   = Data.EquippedIceBlock,
		PlayTime           = Data.PlayTime,
		Settings           = Data.Settings or {
			MasterVolume = DataConfig.DefaultSettings.MasterVolume,
			MusicVolume  = DataConfig.DefaultSettings.MusicVolume,
			SFXVolume    = DataConfig.DefaultSettings.SFXVolume,
			UIVolume     = DataConfig.DefaultSettings.UIVolume,
		},
	}
end

--- Cộng thêm thời gian chơi vào DataStore
--- @param Player Player
--- @param Seconds number  -- Số giây cần cộng thêm
function DataService.AddPlayTime(Player, Seconds)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	Profile.Data.PlayTime = Profile.Data.PlayTime + Seconds
end

--- Lấy bản copy toàn bộ dữ liệu liên quan đến Quest (để QuestService đọc)
--- @param Player Player
--- @return table | nil
function DataService.GetQuestRawData(Player)
	local Profile = DataService.WaitForProfile(Player)
	if not Profile then return nil end
	local Data = Profile.Data
	return {
		PlayTime           = Data.PlayTime,
		TotalWins          = Data.TotalWins,
		TotalFreezes       = Data.TotalFreezes,
		TotalThaws         = Data.TotalThaws,
		TotalFreezingSpree = Data.TotalFreezingSpree,
		TotalThawingSpree  = Data.TotalThawingSpree,
		TotalFirstBlood    = Data.TotalFirstBlood,
		TotalLastStanding  = Data.TotalLastStanding,
		QuestData          = Data.QuestData,
		DailyQuestData     = Data.DailyQuestData,
		MilestoneQuestData = Data.MilestoneQuestData,
	}
end

--- Lấy dữ liệu QuestData 2.0 của người chơi
--- @param Player Player
--- @return table | nil
function DataService.GetQuestData(Player)
	local Profile = DataService.WaitForProfile(Player)
	if not Profile then return nil end
	return Profile.Data.QuestData
end

--- Ghi lại dữ liệu Daily Quest (ResetTimestamp và Quests map)
--- @param Player Player
--- @param NewDailyData table -- { ResetTimestamp = number, Quests = table }
function DataService.SetDailyQuestData(Player, NewDailyData)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	if not Profile.Data.QuestData then
		Profile.Data.QuestData = { Daily = { ResetTimestamp = 0, Quests = {} }, Milestone = { Quests = {} } }
	end
	Profile.Data.QuestData.Daily = NewDailyData
	-- Đồng bộ lại trường cũ nếu cần
	Profile.Data.DailyQuestData = {
		ResetTimestamp = NewDailyData.ResetTimestamp or 0,
		ActiveQuests   = {},
	}
end

--- Cập nhật tiến trình của một nhiệm vụ (Daily hoặc Milestone)
--- @param Player Player
--- @param QuestType string -- "Daily" | "Milestone"
--- @param QuestId string
--- @param Progress number
--- @param Completed boolean
function DataService.SetQuestProgress(Player, QuestType, QuestId, Progress, Completed)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	if not Profile.Data.QuestData then
		Profile.Data.QuestData = { Daily = { ResetTimestamp = 0, Quests = {} }, Milestone = { Quests = {} } }
	end

	local TargetCategory = Profile.Data.QuestData[QuestType]
	if not TargetCategory then return end
	if not TargetCategory.Quests then
		TargetCategory.Quests = {}
	end

	local Entry = TargetCategory.Quests[QuestId]
	if not Entry then
		Entry = { Progress = 0, Completed = false, Claimed = false }
		TargetCategory.Quests[QuestId] = Entry
	end

	Entry.Progress  = Progress
	Entry.Completed = (Completed == true)
end

--- Đánh dấu một nhiệm vụ đã được claim phần thưởng
--- @param Player Player
--- @param QuestType string -- "Daily" | "Milestone"
--- @param QuestId string
--- @param Claimed boolean
function DataService.SetQuestClaimed(Player, QuestType, QuestId, Claimed)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	if not Profile.Data.QuestData then return end

	local TargetCategory = Profile.Data.QuestData[QuestType]
	if not TargetCategory or not TargetCategory.Quests then return end

	local Entry = TargetCategory.Quests[QuestId]
	if not Entry then
		Entry = { Progress = 0, Completed = true, Claimed = false }
		TargetCategory.Quests[QuestId] = Entry
	end

	Entry.Claimed = (Claimed ~= false)
end

--- Cập nhật BaseProgress của 1 Milestone Quest (giữ lại cho tương thích ngược)
--- @param Player Player
--- @param QuestId string
--- @param NewBase number
function DataService.SetMilestoneBase(Player, QuestId, NewBase)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	Profile.Data.MilestoneQuestData[QuestId] = NewBase
end

--- Thêm cosmetic vào danh sách sở hữu (giữ lại cho tương thích ngược)
--- @deprecated Không sử dụng cho vật phẩm mới. Dùng AddIcicle() hoặc AddBlock() thay thế.
--- @param Player Player
--- @param ItemId string
function DataService.AddCosmetic(Player, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end

	for _, OwnedId in ipairs(Profile.Data.OwnedCosmetics) do
		if OwnedId == ItemId then return end
	end
	table.insert(Profile.Data.OwnedCosmetics, ItemId)
end

local VALID_SETTING_KEYS = {
	MasterVolume = true,
	MusicVolume  = true,
	SFXVolume    = true,
	UIVolume     = true,
}

--- Lấy thiết lập của người chơi
--- @param Player Player
--- @return table?
function DataService.GetSettings(Player)
	local Profile = DataService.WaitForProfile(Player)
	if not Profile then return nil end
	return Profile.Data.Settings
end

--- Cập nhật thiết lập của người chơi
--- @param Player Player
--- @param Key string
--- @param Value any
--- @return boolean
function DataService.SetSetting(Player, Key, Value)
	if not VALID_SETTING_KEYS[Key] then return false end
	local Profile = ActiveProfiles[Player]
	if not Profile then return false end

	if not Profile.Data.Settings then
		Profile.Data.Settings = {
			MasterVolume = DataConfig.DefaultSettings.MasterVolume,
			MusicVolume  = DataConfig.DefaultSettings.MusicVolume,
			SFXVolume    = DataConfig.DefaultSettings.SFXVolume,
			UIVolume     = DataConfig.DefaultSettings.UIVolume,
		}
	end

	if type(Value) == "number" then
		-- Clamp và làm tròn theo bước 10 (0, 10, ..., 100)
		Value = math.clamp(math.round(Value / 10) * 10, 0, 100)
	end

	Profile.Data.Settings[Key] = Value
	return true
end

--- Kiểm tra xem một PurchaseId đã được xử lý thành công chưa (Idempotency)
--- @param Player Player
--- @param PurchaseId string
--- @return boolean
function DataService.HasProcessedPurchase(Player, PurchaseId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return false end
	if not Profile.Data.PurchaseHistory then
		Profile.Data.PurchaseHistory = {}
		return false
	end
	return table.find(Profile.Data.PurchaseHistory, PurchaseId) ~= nil
end

--- Ghi lại PurchaseId vào lịch sử giao dịch đã hoàn tất
--- @param Player Player
--- @param PurchaseId string
function DataService.RecordPurchase(Player, PurchaseId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	if not Profile.Data.PurchaseHistory then
		Profile.Data.PurchaseHistory = {}
	end
	if not table.find(Profile.Data.PurchaseHistory, PurchaseId) then
		table.insert(Profile.Data.PurchaseHistory, PurchaseId)
	end
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function DataService:Init()
	-- Chỉ chạy trên server
	assert(RunService:IsServer(), "DataService chỉ được chạy trên Server")

	-- Kết nối events
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)

	-- Xử lý trường hợp player đã join trước khi service Init
	for _, Player in ipairs(Players:GetPlayers()) do
		task.spawn(OnPlayerAdded, Player)
	end

	print("[DataService] Đã khởi tạo.")
end

function DataService:Start()
	-- Xử lý GetPlayerData: client gọi lúc mới join để lấy dữ liệu ban đầu
	-- Yield chờ Profile nạp xong từ DataStore để tránh trả về nil do race condition
	local GetPlayerDataFn = RemoteDefinitions.GetFunction("GetPlayerData")
	GetPlayerDataFn.OnServerInvoke = function(Player)
		local Data = DataService.WaitForData(Player)
		if not Data then return nil end
		return DataService.GetFullDataCopy(Player)
	end

	-- Xử lý EquipItem: client trang bị cosmetic (Phase 2+)
	local EquipItemFn = RemoteDefinitions.GetFunction("EquipItem")
	EquipItemFn.OnServerInvoke = function(Player, SlotName, ItemId)
		return DataService.EquipCosmetic(Player, SlotName, ItemId)
	end

	-- Xử lý SaveSetting: client gửi khi người chơi điều chỉnh xong slider
	local SaveSettingEvent = RemoteDefinitions.GetEvent("SaveSetting")
	SaveSettingEvent.OnServerEvent:Connect(function(Player, Payload)
		if type(Payload) ~= "table" then return end
		local Key   = Payload.Key
		local Value = Payload.Value
		if type(Key) == "string" and Value ~= nil then
			DataService.SetSetting(Player, Key, Value)
		end
	end)

	print("[DataService] Đang chạy.")
end

return DataService
