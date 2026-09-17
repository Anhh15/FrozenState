-- AnalyticsService.lua
-- Quản lý toàn bộ telemetry và phân tích dữ liệu trên Server
-- Wrap Roblox native AnalyticsService, hỗ trợ Mock trong Studio và chuẩn hóa định dạng dữ liệu

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local RobloxAnalytics   = game:GetService("AnalyticsService")

local AnalyticsConfig   = require(ReplicatedStorage.Shared.Config.AnalyticsConfig)

local AnalyticsService = {}

local _IsStudio = RunService:IsStudio()

-- =========================================================
-- PRIVATE: Helpers
-- =========================================================

local function FormatCustomFields(Fields)
	if not Fields then return nil end
	local Formatted = {}
	for Key, Value in pairs(Fields) do
		Formatted[tostring(Key)] = tostring(Value)
	end
	return Formatted
end

local function PrintDebug(Message)
	if AnalyticsConfig.Settings.DebugMode then
		print(("[AnalyticsService] %s"):format(Message))
	end
end

-- =========================================================
-- CORE LOGGING METHODS (Safe wrappers)
-- =========================================================

--- Ghi nhận Custom Event lên Roblox Analytics
--- @param Player Player?
--- @param EventName string
--- @param Value number?
--- @param CustomFields table?  -- key-value pairs (string: string)
function AnalyticsService.LogCustomEvent(Player, EventName, Value, CustomFields)
	if not AnalyticsConfig.Settings.EnableCustomEvents then return end

	Value = Value or 1
	local FormattedFields = FormatCustomFields(CustomFields)

	if _IsStudio and AnalyticsConfig.Settings.IsStudioMockEnabled then
		local PlayerName = Player and Player.Name or "Global"
		local FieldString = ""
		if FormattedFields then
			local Pairs = {}
			for K, V in pairs(FormattedFields) do
				table.insert(Pairs, ("%s=%s"):format(K, V))
			end
			FieldString = " | Fields: {" .. table.concat(Pairs, ", ") .. "}"
		end
		PrintDebug(("[Mock CustomEvent] Target: %s | Event: %s | Value: %s%s"):format(
			PlayerName, EventName, tostring(Value), FieldString
		))
		return
	end

	local Success, Err = pcall(function()
		RobloxAnalytics:LogCustomEvent(Player, EventName, Value, FormattedFields)
	end)

	if not Success and AnalyticsConfig.Settings.DebugMode then
		warn(("[AnalyticsService] Lỗi khi LogCustomEvent '%s': %s"):format(EventName, tostring(Err)))
	end
end

--- Ghi nhận Economy Event (Vàng vào / Vàng ra)
--- @param Player Player
--- @param FlowType "Source" | "Sink"
--- @param Amount number
--- @param EndingBalance number
--- @param TransactionType string
--- @param ItemSku string?
--- @param CustomFields table?
function AnalyticsService.LogEconomyEvent(Player, FlowType, Amount, EndingBalance, TransactionType, ItemSku, CustomFields)
	if not AnalyticsConfig.Settings.EnableEconomyEvents or not Player then return end

	Amount = math.abs(Amount or 0)
	EndingBalance = EndingBalance or 0
	TransactionType = TransactionType or "Gameplay"
	ItemSku = ItemSku or "Default"
	local FormattedFields = FormatCustomFields(CustomFields)

	local EconomyFlowEnum = (FlowType == "Sink")
		and Enum.AnalyticsEconomyFlowType.Sink
		or  Enum.AnalyticsEconomyFlowType.Source

	if _IsStudio and AnalyticsConfig.Settings.IsStudioMockEnabled then
		PrintDebug(("[Mock EconomyEvent] %s | Flow: %s | Amount: %d | Balance: %d | Type: %s | Sku: %s"):format(
			Player.Name, FlowType, Amount, EndingBalance, TransactionType, ItemSku
		))
		return
	end

	local Success, Err = pcall(function()
		RobloxAnalytics:LogEconomyEvent(
			Player,
			EconomyFlowEnum,
			AnalyticsConfig.Settings.CurrencyName,
			Amount,
			EndingBalance,
			TransactionType,
			ItemSku,
			FormattedFields
		)
	end)

	if not Success and AnalyticsConfig.Settings.DebugMode then
		warn(("[AnalyticsService] Lỗi khi LogEconomyEvent cho %s: %s"):format(Player.Name, tostring(Err)))
	end
end

--- Ghi nhận Progression Event (Nhiệm vụ, Cột mốc)
--- @param Player Player
--- @param Category "DailyQuest" | "MilestoneQuest"
--- @param Action "Start" | "Complete" | "Fail"
--- @param Path string  -- Ví dụ: QuestId
--- @param Status string?
--- @param CustomFields table?
function AnalyticsService.LogProgressionEvent(Player, Category, Action, Path, Status, CustomFields)
	if not AnalyticsConfig.Settings.EnableProgressionEvents or not Player then return end

	Path = Path or "Default"
	Status = Status or "None"
	local FormattedFields = FormatCustomFields(CustomFields)

	local ProgressionTypeEnum = Enum.AnalyticsProgressionType.Complete
	if Action == "Start" then
		ProgressionTypeEnum = Enum.AnalyticsProgressionType.Start
	elseif Action == "Fail" then
		ProgressionTypeEnum = Enum.AnalyticsProgressionType.Fail
	end

	if _IsStudio and AnalyticsConfig.Settings.IsStudioMockEnabled then
		PrintDebug(("[Mock ProgressionEvent] %s | Category: %s | Action: %s | Path: %s | Status: %s"):format(
			Player.Name, Category, Action, Path, Status
		))
		return
	end

	local Success, Err = pcall(function()
		RobloxAnalytics:LogProgressionEvent(
			Player,
			Category,
			ProgressionTypeEnum,
			Path,
			Status,
			FormattedFields
		)
	end)

	if not Success and AnalyticsConfig.Settings.DebugMode then
		warn(("[AnalyticsService] Lỗi khi LogProgressionEvent cho %s: %s"):format(Player.Name, tostring(Err)))
	end
end

-- =========================================================
-- HIGH-LEVEL DOMAIN HELPERS
-- =========================================================

--- Ghi nhận bắt đầu trận đấu
--- @param MatchId string
--- @param ModeKey string
--- @param MapName string
--- @param PlayerCount number
function AnalyticsService.LogMatchStart(MatchId, ModeKey, MapName, PlayerCount)
	AnalyticsService.LogCustomEvent(nil, AnalyticsConfig.Events.MatchStarted, 1, {
		MatchId     = MatchId,
		ModeKey     = ModeKey,
		MapName     = MapName,
		PlayerCount = PlayerCount,
	})
end

--- Ghi nhận khi trận đấu kích hoạt Frozen State
--- @param MatchId string
--- @param TimeElapsed number
--- @param Team1Alive number
--- @param Team2Alive number
function AnalyticsService.LogFrozenStateTrigger(MatchId, TimeElapsed, Team1Alive, Team2Alive)
	AnalyticsService.LogCustomEvent(nil, AnalyticsConfig.Events.FrozenStateEntered, TimeElapsed, {
		MatchId     = MatchId,
		TimeElapsed = TimeElapsed,
		Team1Alive  = Team1Alive,
		Team2Alive  = Team2Alive,
	})
end

--- Ghi nhận sự kiện First Blood
--- @param Player Player
--- @param MatchId string
--- @param ElapsedSeconds number
function AnalyticsService.LogFirstBlood(Player, MatchId, ElapsedSeconds)
	AnalyticsService.LogCustomEvent(Player, AnalyticsConfig.Events.FirstBloodOccurred, ElapsedSeconds, {
		MatchId        = MatchId,
		ElapsedSeconds = ElapsedSeconds,
	})
end

--- Ghi nhận sự kiện đạt Spree (Streak)
--- @param Player Player
--- @param SpreeType string  -- "Freezing" | "Thawing"
--- @param StreakCount number
function AnalyticsService.LogSpreeAchieved(Player, SpreeType, StreakCount)
	AnalyticsService.LogCustomEvent(Player, AnalyticsConfig.Events.SpreeAchieved, StreakCount, {
		SpreeType   = SpreeType,
		StreakCount = StreakCount,
	})
end

--- Ghi nhận kết thúc trận đấu tổng quan
--- @param MatchSummary table
function AnalyticsService.LogMatchEnd(MatchSummary)
	AnalyticsService.LogCustomEvent(nil, AnalyticsConfig.Events.MatchEnded, MatchSummary.Duration, {
		MatchId       = MatchSummary.MatchId,
		Duration      = MatchSummary.Duration,
		ModeKey       = MatchSummary.ModeKey,
		MapName       = MatchSummary.MapName,
		WinningTeam   = MatchSummary.WinningTeam or "None",
		EndReason     = MatchSummary.EndReason or "Unknown",
		EnteredFrozen = MatchSummary.EnteredFrozen and "true" or "false",
		PlayerCount   = MatchSummary.PlayerCount or 0,
		TotalFreezes  = MatchSummary.TotalFreezes or 0,
		TotalThaws    = MatchSummary.TotalThaws or 0,
	})
end

--- Ghi nhận tổng kết trận đấu của từng người chơi
--- @param Player Player
--- @param MatchData table
function AnalyticsService.LogPlayerMatchSummary(Player, MatchData)
	local Accuracy = (MatchData.Throws and MatchData.Throws > 0)
		and math.floor((MatchData.Hits / MatchData.Throws) * 100)
		or 0

	AnalyticsService.LogCustomEvent(Player, "PlayerMatchSummary", MatchData.MoneyEarned or 0, {
		MatchId         = MatchData.MatchId,
		Freezes         = MatchData.Freezes or 0,
		Thaws           = MatchData.Thaws or 0,
		Throws          = MatchData.Throws or 0,
		Hits            = MatchData.Hits or 0,
		AccuracyPercent = Accuracy,
		TimeSpentFrozen = MatchData.TimeSpentFrozen or 0,
		IsWinner        = MatchData.IsWinner and "true" or "false",
	})
end

--- Ghi nhận người chơi nhận tiền (Source)
--- @param Player Player
--- @param Amount number
--- @param SourceKey string  -- Từ AnalyticsConfig.EconomySources
--- @param EndingBalance number
--- @param CustomFields table?
--- @param ItemSku string?
function AnalyticsService.LogIncome(Player, Amount, SourceKey, EndingBalance, CustomFields, ItemSku)
	AnalyticsService.LogEconomyEvent(
		Player,
		"Source",
		Amount,
		EndingBalance,
		SourceKey or AnalyticsConfig.EconomySources.FreezeReward,
		ItemSku or "InGameReward",
		CustomFields
	)
end

--- Ghi nhận người chơi tiêu tiền (Sink)
--- @param Player Player
--- @param Amount number
--- @param SinkKey string  -- Từ AnalyticsConfig.EconomySinks
--- @param ItemSku string
--- @param EndingBalance number
--- @param CustomFields table?
function AnalyticsService.LogExpense(Player, Amount, SinkKey, ItemSku, EndingBalance, CustomFields)
	AnalyticsService.LogEconomyEvent(
		Player,
		"Sink",
		Amount,
		EndingBalance,
		SinkKey or AnalyticsConfig.EconomySinks.ChestPurchase,
		ItemSku or "Chest",
		CustomFields
	)
end

--- Ghi nhận người chơi nhận vật phẩm (Mở rương, nhận thưởng)
--- @param Player Player
--- @param ItemId string
--- @param ItemType string  -- "Icicle" | "Block"
--- @param Rarity string    -- "Common" | "Rare" | "Epic" | "Legendary"
--- @param AcquireMethod string -- "Chest" | "Shop" | "QuestReward"
--- @param TotalPlayTime number?
--- @param TotalMatches number?
function AnalyticsService.LogItemAcquired(Player, ItemId, ItemType, Rarity, AcquireMethod, TotalPlayTime, TotalMatches)
	AnalyticsService.LogCustomEvent(Player, AnalyticsConfig.Events.ItemAcquired, 1, {
		ItemId        = ItemId,
		ItemType      = ItemType,
		Rarity        = Rarity,
		AcquireMethod = AcquireMethod or "Chest",
		PlayTime      = TotalPlayTime or 0,
		TotalMatches  = TotalMatches or 0,
	})
end

--- Ghi nhận người chơi mở rương
--- @param Player Player
--- @param ChestId string
--- @param Quantity number
--- @param DuplicateCount number
--- @param RefundAmount number
function AnalyticsService.LogChestOpened(Player, ChestId, Quantity, DuplicateCount, RefundAmount)
	AnalyticsService.LogCustomEvent(Player, AnalyticsConfig.Events.ChestOpened, Quantity, {
		ChestId        = ChestId,
		Quantity       = Quantity,
		DuplicateCount = DuplicateCount or 0,
		RefundAmount   = RefundAmount or 0,
	})
end

--- Ghi nhận nhận thưởng Quest
--- @param Player Player
--- @param QuestId string
--- @param QuestType "DailyQuest" | "MilestoneQuest"
--- @param RewardAmount number
function AnalyticsService.LogQuestClaim(Player, QuestId, QuestType, RewardAmount)
	AnalyticsService.LogProgressionEvent(
		Player,
		QuestType,
		AnalyticsConfig.ProgressionActions.Complete,
		QuestId,
		"Claimed",
		{ RewardAmount = RewardAmount }
	)
end

--- Ghi nhận kết thúc phiên chơi của người chơi (Session Summary)
--- @param Player Player
--- @param SessionDuration number
--- @param MatchesPlayed number
--- @param NetMoneyChange number
function AnalyticsService.LogSessionSummary(Player, SessionDuration, MatchesPlayed, NetMoneyChange)
	AnalyticsService.LogCustomEvent(Player, AnalyticsConfig.Events.PlayerSessionEnded, SessionDuration, {
		SessionDuration = SessionDuration,
		MatchesPlayed   = MatchesPlayed or 0,
		NetMoneyChange  = NetMoneyChange or 0,
	})
end

-- =========================================================
-- LIFECYCLE
-- =========================================================

function AnalyticsService:Init()
	PrintDebug("Đã khởi tạo AnalyticsService.")
end

function AnalyticsService:Start()
	PrintDebug("AnalyticsService đang hoạt động.")
end

return AnalyticsService
