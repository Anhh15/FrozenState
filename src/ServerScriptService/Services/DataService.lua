-- DataService.lua
-- Quản lý toàn bộ dữ liệu bền vững (DataStore) của người chơi
-- Wrap ProfileService để che đi complexity, cung cấp API đơn giản cho các service khác

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileService    = require(ReplicatedStorage.Shared.Lib.ProfileService)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- SCHEMA MẶC ĐỊNH — Dữ liệu bền vững của mỗi người chơi
-- Thêm field mới vào đây khi cần ở các phase sau
-- =========================================================

local PROFILE_TEMPLATE = {
	Money               = 0,
	TotalFreezes        = 0,
	TotalThaws          = 0,
	TotalFreezingSpree  = 0,
	TotalThawingSpree   = 0,
	TotalFirstBlood     = 0,
	TotalLastStanding   = 0,
	OwnedCosmetics      = {},
	EquippedIcicle      = "Default",
	EquippedIceBlock    = "Default",
}

-- =========================================================
-- KHỞI TẠO PROFILESERVICE
-- =========================================================

local PlayerStore = ProfileService.GetProfileStore("PlayerData_v1", PROFILE_TEMPLATE)

-- Lưu trữ profile đang active: { [player] = profile }
local ActiveProfiles = {}

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
		local Owned = false
		for _, OwnedId in ipairs(Profile.Data.OwnedCosmetics) do
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

--- Thêm cosmetic vào danh sách sở hữu
--- @param Player Player
--- @param ItemId string
function DataService.AddCosmetic(Player, ItemId)
	local Profile = ActiveProfiles[Player]
	if not Profile then return end

	-- Tránh duplicate
	for _, OwnedId in ipairs(Profile.Data.OwnedCosmetics) do
		if OwnedId == ItemId then return end
	end

	table.insert(Profile.Data.OwnedCosmetics, ItemId)
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
	local GetPlayerDataFn = RemoteDefinitions.GetFunction("GetPlayerData")
	GetPlayerDataFn.OnServerInvoke = function(Player)
		local Data = DataService.GetData(Player)
		if not Data then return nil end
		-- Trả bản copy để tránh client modify trực tiếp
		return {
			Money              = Data.Money,
			TotalFreezes       = Data.TotalFreezes,
			TotalThaws         = Data.TotalThaws,
			TotalFreezingSpree = Data.TotalFreezingSpree,
			TotalThawingSpree  = Data.TotalThawingSpree,
			TotalFirstBlood    = Data.TotalFirstBlood,
			TotalLastStanding  = Data.TotalLastStanding,
			OwnedCosmetics     = Data.OwnedCosmetics,
			EquippedIcicle     = Data.EquippedIcicle,
			EquippedIceBlock   = Data.EquippedIceBlock,
		}
	end

	-- Xử lý EquipItem: client trang bị cosmetic (Phase 2+)
	local EquipItemFn = RemoteDefinitions.GetFunction("EquipItem")
	EquipItemFn.OnServerInvoke = function(Player, SlotName, ItemId)
		return DataService.EquipCosmetic(Player, SlotName, ItemId)
	end

	print("[DataService] Đang chạy.")
end

return DataService
