-- DataService.lua
-- Quản lý toàn bộ dữ liệu bền vững (DataStore) của người chơi
-- Wrap ProfileService để che đi complexity, cung cấp API đơn giản cho các service khác

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileService    = require(ReplicatedStorage.Shared.Lib.ProfileService)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local DataConfig        = require(ReplicatedStorage.Shared.Config.DataConfig)
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

	-- Phase 7: Quest System
	PlayTime            = 0,    -- Tổng thời gian chơi (giây), cộng dồn mỗi session
	DailyQuestData      = {     -- Dữ liệu Daily Quest của chu kỳ hiện tại
		ResetTimestamp = 0,     -- Unix timestamp thời điểm chu kỳ bắt đầu
		ActiveQuests   = {},    -- Mảng 5 phần tử: { QuestId, BaseProgress, Claimed }
	},
	MilestoneQuestData  = {},   -- { [QuestId] = BaseProgress } mốc stat đã claim

	-- Settings (Âm lượng & Thiết lập cá nhân)
	Settings            = {
		MasterVolume = DataConfig.DefaultSettings.MasterVolume,
		MusicVolume  = DataConfig.DefaultSettings.MusicVolume,
		SFXVolume    = DataConfig.DefaultSettings.SFXVolume,
		UIVolume     = DataConfig.DefaultSettings.UIVolume,
	},
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
		DailyQuestData     = Data.DailyQuestData,
		MilestoneQuestData = Data.MilestoneQuestData,
	}
end

--- Ghi lại toàn bộ DailyQuestData sau khi QuestService tính toán
--- @param Player Player
--- @param NewDailyData table  -- { ResetTimestamp, ActiveQuests }
function DataService.SetDailyQuestData(Player, NewDailyData)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end
	Profile.Data.DailyQuestData = NewDailyData
end

--- Cập nhật BaseProgress của 1 Milestone Quest (khi claim thành công)
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
		-- Trả bản copy để tránh client modify trực tiếp
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
