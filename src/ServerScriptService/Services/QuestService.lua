-- QuestService.lua
-- Quản lý toàn bộ logic Quest & Objective Engine 2.0 phía Server
-- Hỗ trợ Event-Driven Dispatcher, In-Match RAM Counter, Repeatable Milestone Quest và trao thưởng đa hình (Money, Chest, Item)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local DataService       = require(script.Parent.DataService)
local QuestConfig       = require(ReplicatedStorage.Shared.Config.QuestConfig)
local ChestConfig       = require(ReplicatedStorage.Shared.Config.ChestConfig)
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig      = require(ReplicatedStorage.Shared.Config.RarityConfig)
local RewardHelper      = require(ReplicatedStorage.Shared.Tools.RewardHelper)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- PRIVATE STATE
-- =========================================================

-- Lưu thời điểm join của mỗi player để tính PlayTime
local _sessionStart     = {} -- { [Player] = os.time() }
local _lastPlayTimeSync = {} -- { [Player] = os.time() }

-- Bộ đếm tạm thời cho các nhiệm vụ InMatchCounter theo trận đấu trong RAM
-- Cấu trúc: { [Player] = { [QuestId] = number } }
local _matchProgress    = {}

local NotifyAccoladeEvent = nil
local UpdateMoneyEvent    = nil

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Lấy giá trị stat hiện tại của player
--- @param Player Player
--- @param RawData table
--- @param StatKey string
--- @return number
local function GetStatValue(Player, RawData, StatKey)
	local Value = RawData[StatKey] or 0
	if StatKey == "PlayTime" and Player and _sessionStart[Player] then
		Value = Value + (os.time() - _sessionStart[Player])
	end
	return Value
end

--- So khớp các điều kiện lọc (Conditions) của Objective với EventData
--- @param Conditions table?
--- @param EventData table
--- @return boolean
local function MatchesConditions(Conditions, EventData)
	if not Conditions then return true end
	for Key, ExpectedValue in pairs(Conditions) do
		if EventData[Key] ~= ExpectedValue then
			return false
		end
	end
	return true
end

--- Random PoolCount quest từ Daily Pool, không trùng nhau
--- @return table
local function PickRandomDailyQuests()
	local Pool = QuestConfig.Daily.Pool
	local Count = math.min(QuestConfig.Daily.PoolCount, #Pool)

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
--- @param RawData table
local function CheckAndResetDaily(Player, RawData)
	local QuestData = RawData.QuestData or {}
	local DailyData = QuestData.Daily or { ResetTimestamp = 0, Quests = {} }
	local Now = os.time()
	local ResetSeconds = QuestConfig.Daily.ResetSeconds

	if DailyData.ResetTimestamp == 0 or (Now - DailyData.ResetTimestamp) >= ResetSeconds then
		local PickedQuests = PickRandomDailyQuests()
		local NewQuestsMap = {}

		for _, QuestEntry in ipairs(PickedQuests) do
			NewQuestsMap[QuestEntry.Id] = {
				Progress  = 0,
				Completed = false,
				Claimed   = false,
			}
		end

		DataService.SetDailyQuestData(Player, {
			ResetTimestamp = Now,
			Quests         = NewQuestsMap,
		})

		print(("[QuestService] Daily reset cho %s — %d quest mới."):format(Player.Name, #PickedQuests))
	end
end

-- =========================================================
-- REWARD PROCESSORS (CHEST & ITEM)
-- =========================================================

--- Rút thăm ngẫu nhiên item từ rương theo trọng số DropRate
--- @param Items table
--- @return string
local function WeightedRandomItem(Items)
	local Roll = math.random(1, 100)
	local Cumulative = 0
	for _, Entry in ipairs(Items) do
		Cumulative = Cumulative + Entry.DropRate
		if Roll <= Cumulative then
			return Entry.ItemId
		end
	end
	return Items[#Items].ItemId
end

--- Xử lý trao thưởng mở rương (hỗ trợ mở 1 lần nhận X vật phẩm)
--- @param Player Player
--- @param ChestId string
--- @param Quantity number
--- @return table, number -- ReceivedItems, TotalRefund
local function ProcessChestReward(Player, ChestId, Quantity)
	local Chest = ChestConfig.GetChest(ChestId)
	if not Chest then
		warn(("[QuestService] ProcessChestReward: Không tìm thấy ChestId '%s'."):format(tostring(ChestId)))
		return {}, 0
	end

	Quantity = math.max(1, math.floor(Quantity or 1))
	local RefundBasePrice = Chest.Price1 or 1000
	local TotalRefund     = 0
	local ReceivedItems   = {}

	for _ = 1, Quantity do
		local ItemId = WeightedRandomItem(Chest.Items)
		local AlreadyOwned = DataService.HasItem(Player, Chest.Type, ItemId)

		if AlreadyOwned then
			local ItemEntry   = ItemRegistry.GetItem(ItemId, Chest.Type)
			local RarityEntry = ItemEntry and RarityConfig[ItemEntry.Rarity]
			local RefundAmount = 0
			if RarityEntry then
				RefundAmount = math.round(RefundBasePrice * RarityEntry.RefundPercent)
			end
			table.insert(ReceivedItems, {
				ItemId       = ItemId,
				Type         = Chest.Type,
				WasDuplicate = true,
				Refund       = RefundAmount,
			})
			TotalRefund = TotalRefund + RefundAmount
		else
			if Chest.Type == "Icicle" then
				DataService.AddIcicle(Player, ItemId)
			else
				DataService.AddBlock(Player, ItemId)
			end
			table.insert(ReceivedItems, {
				ItemId       = ItemId,
				Type         = Chest.Type,
				WasDuplicate = false,
				Refund       = 0,
			})
		end
	end

	if TotalRefund > 0 then
		DataService.AddMoney(Player, TotalRefund)
	end

	return ReceivedItems, TotalRefund
end

--- Xử lý trao thưởng Item cụ thể (Icicle hoặc Block)
--- @param Player Player
--- @param ItemType string
--- @param ItemId string
--- @return table, number -- ReceivedItems, TotalRefund
local function ProcessItemReward(Player, ItemType, ItemId)
	local AlreadyOwned = DataService.HasItem(Player, ItemType, ItemId)
	local TotalRefund = 0
	local ReceivedItems = {}

	if AlreadyOwned then
		local ItemEntry   = ItemRegistry.GetItem(ItemId, ItemType)
		local RarityEntry = ItemEntry and RarityConfig[ItemEntry.Rarity]
		local BasePrice   = 1000
		if RarityEntry then
			TotalRefund = math.round(BasePrice * RarityEntry.RefundPercent)
		end
		DataService.AddMoney(Player, TotalRefund)
		table.insert(ReceivedItems, {
			ItemId       = ItemId,
			Type         = ItemType,
			WasDuplicate = true,
			Refund       = TotalRefund,
		})
	else
		if ItemType == "Icicle" then
			DataService.AddIcicle(Player, ItemId)
		else
			DataService.AddBlock(Player, ItemId)
		end
		table.insert(ReceivedItems, {
			ItemId       = ItemId,
			Type         = ItemType,
			WasDuplicate = false,
			Refund       = 0,
		})
	end

	return ReceivedItems, TotalRefund
end

-- =========================================================
-- EVENT-DRIVEN DISPATCHER (OBJECTIVE ENGINE 2.0)
-- =========================================================

local QuestService = {}

--- Xử lý sự kiện gameplay gửi tới từ FreezeService / MatchService / ShopService
--- @param Player Player
--- @param EventName string -- "OnFreeze" | "OnThaw" | "OnMatchEnd" | "OnChestOpened" | "OnPlayTime"
--- @param EventData table
function QuestService.DispatchEvent(Player, EventName, EventData)
	if not Player or not Player:IsDescendantOf(Players) then return end

	local RawData = DataService.GetQuestRawData(Player)
	if not RawData then return end

	local QuestData = RawData.QuestData or {}
	local DailyStored = (QuestData.Daily and QuestData.Daily.Quests) or {}
	local MilestoneStored = (QuestData.Milestone and QuestData.Milestone.Quests) or {}

	local function EvaluateQuest(QuestType, ConfigEntry, StoredEntry)
		if not ConfigEntry or not ConfigEntry.Objective then return end
		local Obj = ConfigEntry.Objective

		if Obj.Event ~= EventName then return end
		if not MatchesConditions(Obj.Conditions, EventData) then return end

		local QuestId = ConfigEntry.Id
		local WasCompleted = (StoredEntry and StoredEntry.Completed == true)
		local WasClaimed = (StoredEntry and StoredEntry.Claimed == true)
		local IsRepeatable = (ConfigEntry.Repeatable == true)

		-- Nếu không phải Repeatable và đã Claim rồi thì bỏ qua
		if not IsRepeatable and WasClaimed then return end

		local Amount = EventData.Amount or 1
		local JustCompleted = false

		if Obj.Type == "InMatchCounter" then
			if not _matchProgress[Player] then
				_matchProgress[Player] = {}
			end
			local Current = (_matchProgress[Player][QuestId] or 0) + Amount
			_matchProgress[Player][QuestId] = Current

			if Current >= Obj.Requirement and not WasCompleted then
				DataService.SetQuestProgress(Player, QuestType, QuestId, Obj.Requirement, true)
				JustCompleted = true
			end

		elseif Obj.Type == "Accumulative" then
			local Current = ((StoredEntry and StoredEntry.Progress) or 0) + Amount
			local IsDone = (Current >= Obj.Requirement)
			-- Lưu toàn bộ tiến trình kể cả khi vượt mốc Requirement để bảo lưu cho vòng lặp tiếp theo
			DataService.SetQuestProgress(Player, QuestType, QuestId, Current, IsDone)

			if IsDone and not WasCompleted then
				JustCompleted = true
			end

		elseif Obj.Type == "MatchCondition" then
			DataService.SetQuestProgress(Player, QuestType, QuestId, 1, true)
			if not WasCompleted then
				JustCompleted = true
			end
		end

		if JustCompleted and NotifyAccoladeEvent then
			NotifyAccoladeEvent:FireClient(Player, {
				Type       = "QuestComplete",
				QuestTitle = ConfigEntry.Description,
			})
			print(("[QuestService] 🎉 %s hoàn thành nhiệm vụ: '%s'!"):format(Player.Name, ConfigEntry.Description))
		end
	end

	-- Duyệt Daily Active Quests
	for QuestId, StoredEntry in pairs(DailyStored) do
		local ConfigEntry = QuestConfig.FindQuest("Daily", QuestId)
		if ConfigEntry then
			EvaluateQuest("Daily", ConfigEntry, StoredEntry)
		end
	end

	-- Duyệt Milestone Quests
	for _, ConfigEntry in ipairs(QuestConfig.Milestone.List) do
		local QuestId = ConfigEntry.Id
		local StoredEntry = MilestoneStored[QuestId]
		EvaluateQuest("Milestone", ConfigEntry, StoredEntry)
	end
end

--- Reset toàn bộ bộ đếm InMatch trong RAM (gọi khi bắt đầu ván mới hoặc kết thúc ván)
function QuestService.ResetMatchProgress()
	_matchProgress = {}
end

-- =========================================================
-- BUILD QUEST DATA (GỬI XUỐNG CLIENT)
-- =========================================================

--- Xây dựng bảng dữ liệu Quest đầy đủ để gửi xuống Client
--- @param Player Player
--- @return table | nil
local function BuildQuestData(Player)
	local RawData = DataService.GetQuestRawData(Player)
	if not RawData then return nil end

	-- Đồng bộ PlayTime session trôi qua kể từ lần sync trước
	local Now = os.time()
	local LastSync = _lastPlayTimeSync[Player] or _sessionStart[Player] or Now
	local Elapsed = Now - LastSync
	_lastPlayTimeSync[Player] = Now
	if Elapsed > 0 then
		QuestService.DispatchEvent(Player, "OnPlayTime", { Amount = Elapsed })
	end

	-- Kiểm tra và reset daily nếu cần
	CheckAndResetDaily(Player, RawData)
	RawData = DataService.GetQuestRawData(Player)
	if not RawData then return nil end

	local QuestData = RawData.QuestData or {}
	local DailyStored = (QuestData.Daily and QuestData.Daily.Quests) or {}
	local MilestoneStored = (QuestData.Milestone and QuestData.Milestone.Quests) or {}

	-- ── Daily ──
	local DailyQuests = {}
	for QuestId, StoredEntry in pairs(DailyStored) do
		local ConfigEntry = QuestConfig.FindQuest("Daily", QuestId)
		if ConfigEntry then
			local Obj = ConfigEntry.Objective
			local CurrentProgress = StoredEntry.Progress or 0
			local IsCompleted = StoredEntry.Completed == true
			local IsClaimed = StoredEntry.Claimed == true

			if Obj.Type == "InMatchCounter" then
				local InMatchVal = (_matchProgress[Player] and _matchProgress[Player][QuestId]) or 0
				CurrentProgress = IsCompleted and Obj.Requirement or InMatchVal
			end

			table.insert(DailyQuests, {
				QuestId      = ConfigEntry.Id,
				Description  = ConfigEntry.Description,
				Progress     = math.clamp(CurrentProgress, 0, Obj.Requirement),
				Requirement  = Obj.Requirement,
				Reward       = ConfigEntry.Reward,
				RewardType   = ConfigEntry.Reward.Type,
				RewardAmount = ConfigEntry.Reward.Amount or 1,
				Completed    = IsCompleted or (CurrentProgress >= Obj.Requirement),
				Claimed      = IsClaimed,
				Repeatable   = false,
			})
		end
	end

	table.sort(DailyQuests, function(A, B) return A.QuestId < B.QuestId end)

	-- ── Milestone (Repeatable) ──
	local MilestoneQuests = {}
	for _, ConfigEntry in ipairs(QuestConfig.Milestone.List) do
		local QuestId = ConfigEntry.Id
		local StoredEntry = MilestoneStored[QuestId] or { Progress = 0, Completed = false, Claimed = false }
		local Obj = ConfigEntry.Objective
		local CurrentProgress = StoredEntry.Progress or 0
		local IsRepeatable = (ConfigEntry.Repeatable == true)
		local IsCompleted = IsRepeatable and (CurrentProgress >= Obj.Requirement) or (StoredEntry.Completed == true or CurrentProgress >= Obj.Requirement)
		local IsClaimed = (not IsRepeatable) and (StoredEntry.Claimed == true)

		table.insert(MilestoneQuests, {
			QuestId      = ConfigEntry.Id,
			Description  = ConfigEntry.Description,
			Progress     = math.clamp(CurrentProgress, 0, Obj.Requirement),
			Requirement  = Obj.Requirement,
			Reward       = ConfigEntry.Reward,
			RewardType   = ConfigEntry.Reward.Type,
			RewardAmount = ConfigEntry.Reward.Amount or 1,
			Completed    = IsCompleted,
			Claimed      = IsClaimed,
			Repeatable   = IsRepeatable,
		})
	end

	local ResetTimestamp = (QuestData.Daily and QuestData.Daily.ResetTimestamp) or os.time()

	return {
		Daily              = DailyQuests,
		Milestone          = MilestoneQuests,
		NextResetTimestamp = ResetTimestamp + QuestConfig.Daily.ResetSeconds,
	}
end

-- =========================================================
-- CLAIM LOGIC
-- =========================================================

--- Xử lý claim nhiệm vụ
--- @param Player Player
--- @param QuestType string -- "Daily" | "Milestone"
--- @param QuestId string
--- @return table -- Result payload
local function ClaimQuest(Player, QuestType, QuestId)
	local RawData = DataService.GetQuestRawData(Player)
	if not RawData then return { Success = false } end

	local ConfigEntry = QuestConfig.FindQuest(QuestType, QuestId)
	if not ConfigEntry then
		warn(("[QuestService] ClaimQuest: QuestId '%s' không tồn tại trong %s."):format(QuestId, QuestType))
		return { Success = false }
	end

	local QuestData = RawData.QuestData or {}
	local CategoryStored = (QuestData[QuestType] and QuestData[QuestType].Quests) or {}
	local StoredEntry = CategoryStored[QuestId]

	local Obj = ConfigEntry.Objective
	local CurrentProgress = (StoredEntry and StoredEntry.Progress) or 0
	local IsRepeatable = (ConfigEntry.Repeatable == true)
	local IsClaimed = (StoredEntry and StoredEntry.Claimed == true)
	local IsCompleted = IsRepeatable and (CurrentProgress >= Obj.Requirement) or ((StoredEntry and StoredEntry.Completed == true) or (CurrentProgress >= Obj.Requirement))

	if not IsRepeatable and IsClaimed then
		warn(("[QuestService] ClaimQuest: %s đã claim '%s'."):format(Player.Name, QuestId))
		return { Success = false }
	end

	if not IsCompleted then
		warn(("[QuestService] ClaimQuest: %s chưa hoàn thành '%s' (%.0f/%.0f)."):format(
			Player.Name, QuestId, CurrentProgress, Obj.Requirement
		))
		return { Success = false }
	end

	-- Xử lý Reset Tiến trình cho Quest Repeatable vs One-time
	if IsRepeatable then
		-- Trừ Requirement khỏi Progress, bảo lưu toàn bộ tiến trình dôi dư cho vòng lặp tiếp theo!
		local NewProgress = math.max(0, CurrentProgress - Obj.Requirement)
		local IsCompletedNow = (NewProgress >= Obj.Requirement)
		DataService.SetQuestProgress(Player, QuestType, QuestId, NewProgress, IsCompletedNow)
		DataService.SetQuestClaimed(Player, QuestType, QuestId, false)
	else
		-- Đánh dấu Claimed vĩnh viễn trong chu kỳ
		DataService.SetQuestClaimed(Player, QuestType, QuestId, true)
	end

	-- Cấp phần thưởng đa hình
	local Reward = ConfigEntry.Reward
	local ReceivedItems = {}
	local RefundAmount = 0

	if Reward.Type == "Money" then
		RewardHelper.RewardAndSync(Player, Reward.Amount, DataService, UpdateMoneyEvent)
	elseif Reward.Type == "Chest" then
		ReceivedItems, RefundAmount = ProcessChestReward(Player, Reward.ChestId, Reward.Amount or 1)
		if UpdateMoneyEvent then
			local NewMoney = DataService.GetData(Player) and DataService.GetData(Player).Money or 0
			UpdateMoneyEvent:FireClient(Player, NewMoney)
		end
	elseif Reward.Type == "Item" then
		ReceivedItems, RefundAmount = ProcessItemReward(Player, Reward.ItemType, Reward.ItemId)
		if UpdateMoneyEvent and RefundAmount > 0 then
			local NewMoney = DataService.GetData(Player) and DataService.GetData(Player).Money or 0
			UpdateMoneyEvent:FireClient(Player, NewMoney)
		end
	end

	local FinalMoney = DataService.GetData(Player) and DataService.GetData(Player).Money or 0

	print(("[QuestService] %s claim %s '%s' thành công — Thưởng: %s (Repeatable: %s)."):format(
		Player.Name, QuestType, QuestId, Reward.Type, tostring(IsRepeatable)
	))

	return {
		Success       = true,
		RewardType    = Reward.Type,
		RewardAmount  = Reward.Amount or 1,
		ChestId       = Reward.ChestId,
		ItemId        = Reward.ItemId,
		ReceivedItems = ReceivedItems,
		RefundAmount  = RefundAmount,
		NewMoney      = FinalMoney,
	}
end

-- =========================================================
-- KHỞI TẠO SERVICE
-- =========================================================

function QuestService:Init()
	assert(RunService:IsServer(), "QuestService chỉ được chạy trên Server")

	NotifyAccoladeEvent = RemoteDefinitions.GetEvent("NotifyAccolade")
	UpdateMoneyEvent    = RemoteDefinitions.GetEvent("UpdateMoney")

	-- Tracking PlayTime & Dọn dẹp RAM session
	Players.PlayerAdded:Connect(function(Player)
		_sessionStart[Player]     = os.time()
		_lastPlayTimeSync[Player] = os.time()
	end)

	Players.PlayerRemoving:Connect(function(Player)
		local JoinTime = _sessionStart[Player]
		if JoinTime then
			local SessionSeconds = os.time() - JoinTime
			DataService.AddPlayTime(Player, SessionSeconds)
			_sessionStart[Player] = nil
		end
		local LastSync = _lastPlayTimeSync[Player]
		if LastSync then
			local Elapsed = os.time() - LastSync
			if Elapsed > 0 then
				QuestService.DispatchEvent(Player, "OnPlayTime", { Amount = Elapsed })
			end
			_lastPlayTimeSync[Player] = nil
		end
		_matchProgress[Player] = nil
	end)

	for _, Player in ipairs(Players:GetPlayers()) do
		_sessionStart[Player]     = os.time()
		_lastPlayTimeSync[Player] = os.time()
	end

	print("[QuestService] Đã khởi tạo Objective Engine 2.0 (Hỗ trợ Repeatable Quests).")
end

function QuestService:Start()
	-- Handler: Client lấy dữ liệu quest (gọi 1 lần duy nhất khi mở GUI)
	local GetQuestDataFn = RemoteDefinitions.GetFunction("GetQuestData")
	GetQuestDataFn.OnServerInvoke = function(Player)
		return BuildQuestData(Player)
	end

	-- Handler: Client claim quest
	local ClaimQuestFn = RemoteDefinitions.GetFunction("ClaimQuest")
	ClaimQuestFn.OnServerInvoke = function(Player, QuestType, QuestId)
		if type(QuestType) ~= "string" or type(QuestId) ~= "string" then
			warn(("[QuestService] ClaimQuest: Tham số không hợp lệ từ %s."):format(Player.Name))
			return { Success = false }
		end

		return ClaimQuest(Player, QuestType, QuestId)
	end

	print("[QuestService] Đang chạy.")
end

return QuestService
