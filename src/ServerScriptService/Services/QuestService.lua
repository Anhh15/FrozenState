-- QuestService.lua
-- Quản lý toàn bộ logic Quest phía Server (Phase 7)
-- Bao gồm: tracking PlayTime, reset Daily, validate + cấp thưởng khi Claim

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local DataService       = require(script.Parent.DataService)
local QuestConfig       = require(ReplicatedStorage.Shared.Config.QuestConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- PRIVATE STATE
-- =========================================================

-- Lưu thời điểm join của mỗi player để tính PlayTime khi rời
local _sessionStart = {} -- { [Player] = os.time() }

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Lấy giá trị stat hiện tại của player theo tên field (tự động cộng dồn PlayTime của session hiện tại)
--- @param Player Player
--- @param RawData table  -- kết quả từ DataService.GetQuestRawData
--- @param StatKey string
--- @return number
local function GetStatValue(Player, RawData, StatKey)
	local Value = RawData[StatKey] or 0
	if StatKey == "PlayTime" and Player and _sessionStart[Player] then
		Value = Value + (os.time() - _sessionStart[Player])
	end
	return Value
end

--- Random PoolCount quest từ Daily Pool, không trùng nhau
--- @return table  -- mảng các quest entry từ QuestConfig.Daily.Pool
local function PickRandomDailyQuests()
	local Pool = QuestConfig.Daily.Pool
	local Count = math.min(QuestConfig.Daily.PoolCount, #Pool)

	-- Shuffle bản sao index
	local Indices = {}
	for I = 1, #Pool do
		Indices[I] = I
	end
	for I = #Indices, 2, -1 do
		local J = math.random(1, I)
		Indices[I], Indices[J] = Indices[J], Indices[I]
	end

	local Picked = {}
	for I = 1, Count do
		Picked[I] = Pool[Indices[I]]
	end
	return Picked
end

--- Kiểm tra và reset Daily Quest nếu chu kỳ 24h đã kết thúc
--- @param Player Player
--- @param RawData table  -- DataService.GetQuestRawData (đọc-only, tham chiếu)
local function CheckAndResetDaily(Player, RawData)
	local DailyData = RawData.DailyQuestData
	local Now = os.time()
	local ResetSeconds = QuestConfig.Daily.ResetSeconds

	-- Chưa có chu kỳ nào hoặc đã hết 24h → reset
	if DailyData.ResetTimestamp == 0 or (Now - DailyData.ResetTimestamp) >= ResetSeconds then
		local PickedQuests = PickRandomDailyQuests()
		local NewActiveQuests = {}

		for _, QuestEntry in ipairs(PickedQuests) do
			-- Snapshot BaseProgress = stat hiện tại tại thời điểm reset
			local BaseProgress = GetStatValue(Player, RawData, QuestEntry.StatKey)
			table.insert(NewActiveQuests, {
				QuestId      = QuestEntry.Id,
				BaseProgress = BaseProgress,
				Claimed      = false,
			})
		end

		DataService.SetDailyQuestData(Player, {
			ResetTimestamp = Now,
			ActiveQuests   = NewActiveQuests,
		})

		print(("[QuestService] Daily reset cho %s — %d quest mới."):format(Player.Name, #NewActiveQuests))
	end
end

--- Tìm quest entry trong QuestConfig theo Id và loại
--- @param QuestType string  -- "Daily" | "Milestone"
--- @param QuestId string
--- @return table | nil
local function FindQuestConfig(QuestType, QuestId)
	if QuestType == "Daily" then
		for _, Entry in ipairs(QuestConfig.Daily.Pool) do
			if Entry.Id == QuestId then return Entry end
		end
	elseif QuestType == "Milestone" then
		for _, Entry in ipairs(QuestConfig.Milestone.List) do
			if Entry.Id == QuestId then return Entry end
		end
	end
	return nil
end

-- =========================================================
-- BUILD QUEST DATA (dùng để gửi xuống Client)
-- =========================================================

--- Xây dựng bảng dữ liệu Quest đầy đủ để gửi xuống Client
--- @param Player Player
--- @return table | nil
local function BuildQuestData(Player)
	local RawData = DataService.GetQuestRawData(Player)
	if not RawData then return nil end

	-- Kiểm tra và reset daily nếu cần TRƯỚC khi build data
	CheckAndResetDaily(Player, RawData)

	-- Đọc lại sau khi có thể vừa reset
	RawData = DataService.GetQuestRawData(Player)
	if not RawData then return nil end

	-- ── Daily ──
	local DailyQuests = {}
	for _, ActiveEntry in ipairs(RawData.DailyQuestData.ActiveQuests) do
		local ConfigEntry = FindQuestConfig("Daily", ActiveEntry.QuestId)
		if ConfigEntry then
			local CurrentStat  = GetStatValue(Player, RawData, ConfigEntry.StatKey)
			local Progress     = CurrentStat - ActiveEntry.BaseProgress
			local Requirement  = ConfigEntry.Requirement
			DailyQuests[#DailyQuests + 1] = {
				QuestId      = ConfigEntry.Id,
				Description  = ConfigEntry.Description,
				Progress     = math.clamp(Progress, 0, Requirement),
				Requirement  = Requirement,
				RewardType   = ConfigEntry.RewardType,
				RewardAmount = ConfigEntry.RewardAmount,
				Claimed      = ActiveEntry.Claimed,
			}
		end
	end

	-- ── Milestone ──
	local MilestoneQuests = {}
	for _, ConfigEntry in ipairs(QuestConfig.Milestone.List) do
		local BaseProgress = RawData.MilestoneQuestData[ConfigEntry.Id] or 0
		local CurrentStat  = GetStatValue(Player, RawData, ConfigEntry.StatKey)
		local Progress     = CurrentStat - BaseProgress
		local Requirement  = ConfigEntry.Requirement
		MilestoneQuests[#MilestoneQuests + 1] = {
			QuestId      = ConfigEntry.Id,
			Description  = ConfigEntry.Description,
			Progress     = math.clamp(Progress, 0, Requirement),
			Requirement  = Requirement,
			RewardType   = ConfigEntry.RewardType,
			RewardAmount = ConfigEntry.RewardAmount,
			Claimed      = false, -- Milestone không có trạng thái Claimed cố định
		}
	end

	return {
		Daily              = DailyQuests,
		Milestone          = MilestoneQuests,
		NextResetTimestamp = RawData.DailyQuestData.ResetTimestamp + QuestConfig.Daily.ResetSeconds,
	}
end

-- =========================================================
-- CLAIM LOGIC
-- =========================================================

--- Xử lý claim Daily Quest
--- @param Player Player
--- @param QuestId string
--- @return boolean, string, number  -- Success, RewardType, RewardAmount
local function ClaimDailyQuest(Player, QuestId)
	local RawData = DataService.GetQuestRawData(Player)
	if not RawData then return false, "", 0 end

	local ConfigEntry = FindQuestConfig("Daily", QuestId)
	if not ConfigEntry then
		warn(("[QuestService] ClaimDaily: QuestId '%s' không hợp lệ."):format(QuestId))
		return false, "", 0
	end

	-- Tìm entry trong ActiveQuests
	local ActiveQuests = RawData.DailyQuestData.ActiveQuests
	local FoundEntry = nil
	local FoundIndex = nil
	for I, Entry in ipairs(ActiveQuests) do
		if Entry.QuestId == QuestId then
			FoundEntry = Entry
			FoundIndex = I
			break
		end
	end

	if not FoundEntry then
		warn(("[QuestService] ClaimDaily: %s không có quest '%s' active."):format(Player.Name, QuestId))
		return false, "", 0
	end

	if FoundEntry.Claimed then
		warn(("[QuestService] ClaimDaily: %s đã claim quest '%s'."):format(Player.Name, QuestId))
		return false, "", 0
	end

	-- Kiểm tra tiến trình đủ chưa
	local CurrentStat = GetStatValue(Player, RawData, ConfigEntry.StatKey)
	local Progress    = CurrentStat - FoundEntry.BaseProgress
	if Progress < ConfigEntry.Requirement then
		warn(("[QuestService] ClaimDaily: %s chưa đủ tiến trình (%.0f/%.0f)."):format(
			Player.Name, Progress, ConfigEntry.Requirement))
		return false, "", 0
	end

	-- Đánh dấu Claimed
	FoundEntry.Claimed = true
	DataService.SetDailyQuestData(Player, RawData.DailyQuestData)

	-- Cấp thưởng
	if ConfigEntry.RewardType == "Money" then
		DataService.AddMoney(Player, ConfigEntry.RewardAmount)
		-- Sync tiền xuống client
		local UpdateMoney = RemoteDefinitions.GetEvent("UpdateMoney")
		local NewMoney = DataService.GetData(Player) and DataService.GetData(Player).Money or 0
		UpdateMoney:FireClient(Player, NewMoney)
	end

	print(("[QuestService] %s claim Daily '%s' — +%d %s."):format(
		Player.Name, QuestId, ConfigEntry.RewardAmount, ConfigEntry.RewardType))
	return true, ConfigEntry.RewardType, ConfigEntry.RewardAmount
end

--- Xử lý claim Milestone Quest
--- @param Player Player
--- @param QuestId string
--- @return boolean, string, number
local function ClaimMilestoneQuest(Player, QuestId)
	local RawData = DataService.GetQuestRawData(Player)
	if not RawData then return false, "", 0 end

	local ConfigEntry = FindQuestConfig("Milestone", QuestId)
	if not ConfigEntry then
		warn(("[QuestService] ClaimMilestone: QuestId '%s' không hợp lệ."):format(QuestId))
		return false, "", 0
	end

	local BaseProgress = RawData.MilestoneQuestData[QuestId] or 0
	local CurrentStat  = GetStatValue(Player, RawData, ConfigEntry.StatKey)
	local Progress     = CurrentStat - BaseProgress

	if Progress < ConfigEntry.Requirement then
		warn(("[QuestService] ClaimMilestone: %s chưa đủ tiến trình (%.0f/%.0f)."):format(
			Player.Name, Progress, ConfigEntry.Requirement))
		return false, "", 0
	end

	-- Reset BaseProgress về mốc tiếp theo
	local NewBase = BaseProgress + ConfigEntry.Requirement
	DataService.SetMilestoneBase(Player, QuestId, NewBase)

	-- Cấp thưởng
	if ConfigEntry.RewardType == "Money" then
		DataService.AddMoney(Player, ConfigEntry.RewardAmount)
		local UpdateMoney = RemoteDefinitions.GetEvent("UpdateMoney")
		local NewMoney = DataService.GetData(Player) and DataService.GetData(Player).Money or 0
		UpdateMoney:FireClient(Player, NewMoney)
	end

	print(("[QuestService] %s claim Milestone '%s' — +%d %s. NewBase=%d."):format(
		Player.Name, QuestId, ConfigEntry.RewardAmount, ConfigEntry.RewardType, NewBase))
	return true, ConfigEntry.RewardType, ConfigEntry.RewardAmount
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local QuestService = {}

function QuestService:Init()
	assert(RunService:IsServer(), "QuestService chỉ được chạy trên Server")

	-- Tracking PlayTime: lưu thời điểm join
	Players.PlayerAdded:Connect(function(Player)
		_sessionStart[Player] = os.time()
	end)

	-- Khi player rời: cộng dồn PlayTime vào DataStore
	Players.PlayerRemoving:Connect(function(Player)
		local JoinTime = _sessionStart[Player]
		if JoinTime then
			local SessionSeconds = os.time() - JoinTime
			DataService.AddPlayTime(Player, SessionSeconds)
			_sessionStart[Player] = nil
		end
	end)

	-- Xử lý player đã join trước khi Init (chạy trong Studio)
	for _, Player in ipairs(Players:GetPlayers()) do
		_sessionStart[Player] = os.time()
	end

	print("[QuestService] Đã khởi tạo.")
end

function QuestService:Start()
	-- Handler: Client lấy dữ liệu quest
	local GetQuestDataFn = RemoteDefinitions.GetFunction("GetQuestData")
	GetQuestDataFn.OnServerInvoke = function(Player)
		return BuildQuestData(Player)
	end

	-- Handler: Client claim quest
	local ClaimQuestFn = RemoteDefinitions.GetFunction("ClaimQuest")
	ClaimQuestFn.OnServerInvoke = function(Player, QuestType, QuestId)
		-- Validate input
		if type(QuestType) ~= "string" or type(QuestId) ~= "string" then
			warn(("[QuestService] ClaimQuest: tham số không hợp lệ từ %s."):format(Player.Name))
			return { Success = false }
		end

		local Success, RewardType, RewardAmount
		if QuestType == "Daily" then
			Success, RewardType, RewardAmount = ClaimDailyQuest(Player, QuestId)
		elseif QuestType == "Milestone" then
			Success, RewardType, RewardAmount = ClaimMilestoneQuest(Player, QuestId)
		else
			warn(("[QuestService] ClaimQuest: QuestType '%s' không hợp lệ."):format(QuestType))
			return { Success = false }
		end

		return {
			Success      = Success,
			RewardType   = RewardType,
			RewardAmount = RewardAmount,
		}
	end

	print("[QuestService] Đang chạy.")
end

return QuestService
