-- QuestConfig.lua
-- Tham số và định nghĩa toàn bộ nhiệm vụ trong game (Objective Engine 2.0)
-- Hỗ trợ 4 loại Objective: InMatchCounter, Accumulative, MatchCondition, LifetimeStat
-- Hỗ trợ 3 loại Reward: Money, Chest, Item (Mỗi quest có DUY NHẤT 1 loại phần thưởng)
-- Hỗ trợ cờ Repeatable: true (lặp vô hạn sau khi claim) / false (chỉ 1 lần trong chu kỳ)

local QuestConfig = {

	-- =========================================================
	-- DAILY QUESTS (Repeatable = false: Reset mỗi 24h)
	-- =========================================================
	Daily = {
		PoolCount    = 5,     -- Số quest được random mỗi chu kỳ
		ResetSeconds = 86400, -- Thời gian reset: 24 giờ (giây)

		Pool = {
			-- [Nhóm 1: InMatchCounter — Yêu cầu đạt được trong DUY NHẤT 1 trận đấu]
			{
				Id          = "D_FreezeInMatch5",
				Description = "Freeze 5 enemies in a single match",
				Objective   = {
					Type        = "InMatchCounter",
					Event       = "OnFreeze",
					Requirement = 5,
				},
				Reward      = { Type = "Money", Amount = 100 },
				Repeatable  = false,
			},
			{
				Id          = "D_FreezeInMatch10",
				Description = "Freeze 10 enemies in a single match",
				Objective   = {
					Type        = "InMatchCounter",
					Event       = "OnFreeze",
					Requirement = 10,
				},
				Reward      = { Type = "Chest", ChestId = "BasicIcicleChest", Amount = 1 },
				Repeatable  = false,
			},
			{
				Id          = "D_ThawInMatch5",
				Description = "Thaw 5 allies in a single match",
				Objective   = {
					Type        = "InMatchCounter",
					Event       = "OnThaw",
					Requirement = 5,
				},
				Reward      = { Type = "Money", Amount = 100 },
				Repeatable  = false,
			},
			{
				Id          = "D_FreezingSpreeInMatch2",
				Description = "Achieve Freezing Spree 2 times in a single match",
				Objective   = {
					Type        = "InMatchCounter",
					Event       = "OnFreeze",
					Requirement = 2,
					Conditions  = { IsSpree = true },
				},
				Reward      = { Type = "Money", Amount = 120 },
				Repeatable  = false,
			},
			{
				Id          = "D_ThawingSpreeInMatch2",
				Description = "Achieve Thawing Spree 2 times in a single match",
				Objective   = {
					Type        = "InMatchCounter",
					Event       = "OnThaw",
					Requirement = 2,
					Conditions  = { IsSpree = true },
				},
				Reward      = { Type = "Money", Amount = 120 },
				Repeatable  = false,
			},

			-- [Nhóm 2: Accumulative — Tích lũy cộng dồn qua nhiều trận]
			{
				Id          = "D_FreezeTotal15",
				Description = "Freeze 15 enemies",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnFreeze",
					Requirement = 15,
				},
				Reward      = { Type = "Money", Amount = 80 },
				Repeatable  = false,
			},
			{
				Id          = "D_ThawTotal10",
				Description = "Thaw 10 allies",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnThaw",
					Requirement = 10,
				},
				Reward      = { Type = "Money", Amount = 80 },
				Repeatable  = false,
			},
			{
				Id          = "D_ThawInFrozenState3",
				Description = "Thaw 3 allies during FrozenState",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnThaw",
					Requirement = 3,
					Conditions  = { IsFrozenState = true },
				},
				Reward      = { Type = "Money", Amount = 100 },
				Repeatable  = false,
			},
			{
				Id          = "D_FirstBlood2",
				Description = "Get First Blood 2 times",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnFreeze",
					Requirement = 2,
					Conditions  = { IsFirstBlood = true },
				},
				Reward      = { Type = "Money", Amount = 90 },
				Repeatable  = false,
			},
			{
				Id          = "D_OpenChests2",
				Description = "Open 2 Chests",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnChestOpened",
					Requirement = 2,
				},
				Reward      = { Type = "Money", Amount = 150 },
				Repeatable  = false,
			},

			-- [Nhóm 3: MatchCondition — Điều kiện kết thúc trận cụ thể]
			{
				Id          = "D_Win3Matches",
				Description = "Win 3 matches",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnMatchEnd",
					Requirement = 3,
					Conditions  = { Won = true },
				},
				Reward      = { Type = "Money", Amount = 120 },
				Repeatable  = false,
			},
			{
				Id          = "D_WinChaosMode1",
				Description = "Win 1 match in Chaos Mode",
				Objective   = {
					Type        = "MatchCondition",
					Event       = "OnMatchEnd",
					Requirement = 1,
					Conditions  = { Won = true, ModeKey = "Chaos" },
				},
				Reward      = { Type = "Money", Amount = 100 },
				Repeatable  = false,
			},
			{
				Id          = "D_WinLastStanding1",
				Description = "Be Last Standing 1 time",
				Objective   = {
					Type        = "MatchCondition",
					Event       = "OnMatchEnd",
					Requirement = 1,
					Conditions  = { Won = true, LastStanding = true },
				},
				Reward      = { Type = "Money", Amount = 100 },
				Repeatable  = false,
			},

			-- [Nhóm 4: PlayTime — Tích lũy thời gian chơi]
			{
				Id          = "D_PlayTime30m",
				Description = "Play for 30 minutes",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnPlayTime",
					Requirement = 1800, -- 30 phút = 1800 giây
				},
				Reward      = { Type = "Money", Amount = 80 },
				Repeatable  = false,
			},
		},
	},

	-- =========================================================
	-- MILESTONE QUESTS (Repeatable = true: Lặp lại vô hạn sau khi claim)
	-- =========================================================
	Milestone = {
		List = {
			{
				Id          = "M_Freeze50",
				Description = "Freeze 50 enemies",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnFreeze",
					Requirement = 50,
				},
				Reward      = { Type = "Money", Amount = 500 },
				Repeatable  = true,
			},
			{
				Id          = "M_Freeze100",
				Description = "Freeze 100 enemies",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnFreeze",
					Requirement = 100,
				},
				Reward      = { Type = "Chest", ChestId = "BasicIcicleChest", Amount = 1 },
				Repeatable  = true,
			},
			{
				Id          = "M_Thaw50",
				Description = "Thaw 50 allies",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnThaw",
					Requirement = 50,
				},
				Reward      = { Type = "Money", Amount = 500 },
				Repeatable  = true,
			},
			{
				Id          = "M_Thaw100",
				Description = "Thaw 100 allies",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnThaw",
					Requirement = 100,
				},
				Reward      = { Type = "Chest", ChestId = "BasicBlockChest", Amount = 1 },
				Repeatable  = true,
			},
			{
				Id          = "M_Win10",
				Description = "Win 10 matches",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnMatchEnd",
					Requirement = 10,
					Conditions  = { Won = true },
				},
				Reward      = { Type = "Money", Amount = 1000 },
				Repeatable  = true,
			},
			{
				Id          = "M_Win25",
				Description = "Win 25 matches",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnMatchEnd",
					Requirement = 25,
					Conditions  = { Won = true },
				},
				Reward      = { Type = "Chest", ChestId = "BasicIcicleChest", Amount = 2 },
				Repeatable  = true,
			},
			{
				Id          = "M_FreezingSpree10",
				Description = "Achieve Freezing Spree 10 times",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnFreeze",
					Requirement = 10,
					Conditions  = { IsSpree = true },
				},
				Reward      = { Type = "Money", Amount = 750 },
				Repeatable  = true,
			},
			{
				Id          = "M_ThawingSpree10",
				Description = "Achieve Thawing Spree 10 times",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnThaw",
					Requirement = 10,
					Conditions  = { IsSpree = true },
				},
				Reward      = { Type = "Money", Amount = 750 },
				Repeatable  = true,
			},
			{
				Id          = "M_FirstBlood10",
				Description = "Get First Blood 10 times",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnFreeze",
					Requirement = 10,
					Conditions  = { IsFirstBlood = true },
				},
				Reward      = { Type = "Money", Amount = 800 },
				Repeatable  = true,
			},
			{
				Id          = "M_LastStanding5",
				Description = "Be Last Standing 5 times",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnMatchEnd",
					Requirement = 5,
					Conditions  = { Won = true, LastStanding = true },
				},
				Reward      = { Type = "Money", Amount = 800 },
				Repeatable  = true,
			},
			{
				Id          = "M_PlayTime2h",
				Description = "Play for 2 hours",
				Objective   = {
					Type        = "Accumulative",
					Event       = "OnPlayTime",
					Requirement = 15, -- 2 giờ = 7200 giây
				},
				Reward      = { Type = "Money", Amount = 600 },
				Repeatable  = true,
			},
		},
	},

	-- =========================================================
	-- UI ASSETS & ICONS
	-- =========================================================
	ClaimButtonImages = {
		Uncompleted = "rbxassetid://132149908740563",
		Completed   = "rbxassetid://99096499302637",
	},

	RewardAnnouncementIcons = {
		Money = "rbxassetid://106702914411826",
		Chest = "rbxassetid://106702914411826",
		Item  = "rbxassetid://106702914411826",
	},
}

-- =========================================================
-- PUBLIC HELPERS
-- =========================================================

--- Tìm entry cấu hình quest theo Id và QuestType
--- @param QuestType string -- "Daily" | "Milestone"
--- @param QuestId string
--- @return table | nil
function QuestConfig.FindQuest(QuestType, QuestId)
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

--- Lấy icon hiển thị cho phần thưởng (dùng cho QuestList và Popup Announcement)
--- @param Reward table -- { Type = "Money" | "Chest" | "Item", ... }
--- @return string
function QuestConfig.GetRewardIcon(Reward)
	if not Reward then return QuestConfig.RewardAnnouncementIcons.Money end
	local RewardType = Reward.Type

	if RewardType == "Money" then
		return QuestConfig.RewardAnnouncementIcons.Money
	elseif RewardType == "Chest" then
		return QuestConfig.RewardAnnouncementIcons.Chest or QuestConfig.RewardAnnouncementIcons.Money
	elseif RewardType == "Item" then
		return QuestConfig.RewardAnnouncementIcons.Item or QuestConfig.RewardAnnouncementIcons.Money
	end

	return QuestConfig.RewardAnnouncementIcons.Money
end

--- Lấy chuỗi văn bản hiển thị cho phần thưởng (vd: "150", "x2", "Green Icicle")
--- @param Reward table -- { Type = "Money" | "Chest" | "Item", ... }
--- @return string
function QuestConfig.GetRewardDisplayText(Reward)
	if not Reward then return "" end
	local RewardType = Reward.Type

	if RewardType == "Money" then
		return tostring(Reward.Amount or 0)
	elseif RewardType == "Chest" then
		local Amount = Reward.Amount or 1
		return (Amount > 1) and ("x" .. tostring(Amount)) or "x1"
	elseif RewardType == "Item" then
		return tostring(Reward.ItemId or "Item")
	end

	return tostring(Reward.Amount or "")
end

return QuestConfig
