local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig     = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local RewardHelper = {}

-- =========================================================
-- REWARD CALCULATIONS
-- =========================================================

--- Lấy giá trị thưởng của một hành động theo Key
--- @param ActionKey string
--- @return number
function RewardHelper.GetRewardAmount(ActionKey)
	return (EconomyConfig.Rewards and EconomyConfig.Rewards[ActionKey]) or 0
end

--- Lấy ngưỡng kích hoạt Spree
--- @return number
function RewardHelper.GetSpreeThreshold()
	return (EconomyConfig.Spree and EconomyConfig.Spree.Threshold) or 3
end

--- Tính toán phần thưởng khi đóng băng mục tiêu (Freeze)
--- @param CurrentStreak number -- Chuỗi freeze hiện tại của Attacker
--- @return number, number, boolean -- BaseReward, SpreeBonus, IsSpree
function RewardHelper.CalculateFreezeReward(CurrentStreak)
	local BaseReward = RewardHelper.GetRewardAmount("PerFreeze")
	local SpreeBonus = 0
	local IsSpree = false

	local Threshold = RewardHelper.GetSpreeThreshold()
	if CurrentStreak and CurrentStreak > 0 and (CurrentStreak % Threshold == 0) then
		IsSpree = true
		SpreeBonus = RewardHelper.GetRewardAmount("PerFreezingSpree")
	end

	return BaseReward, SpreeBonus, IsSpree
end

--- Tính toán phần thưởng khi giải cứu đồng đội (Thaw)
--- @param CurrentStreak number -- Chuỗi thaw hiện tại của Rescuer
--- @return number, number, boolean -- BaseReward, SpreeBonus, IsSpree
function RewardHelper.CalculateThawReward(CurrentStreak)
	local BaseReward = RewardHelper.GetRewardAmount("PerThaw")
	local SpreeBonus = 0
	local IsSpree = false

	local Threshold = RewardHelper.GetSpreeThreshold()
	if CurrentStreak and CurrentStreak > 0 and (CurrentStreak % Threshold == 0) then
		IsSpree = true
		SpreeBonus = RewardHelper.GetRewardAmount("PerThawingSpree")
	end

	return BaseReward, SpreeBonus, IsSpree
end

--- Tính phần thưởng kết thúc trận (Win / Lose)
--- @param IsWinner boolean
--- @return number
function RewardHelper.GetMatchEndReward(IsWinner)
	if IsWinner then
		return RewardHelper.GetRewardAmount("MatchWin")
	else
		return RewardHelper.GetRewardAmount("MatchLose")
	end
end

--- Lấy phần thưởng First Blood
--- @return number
function RewardHelper.GetFirstBloodReward()
	return RewardHelper.GetRewardAmount("FirstBlood")
end

--- Lấy phần thưởng Last Man Standing
--- @return number
function RewardHelper.GetLastStandingReward()
	return RewardHelper.GetRewardAmount("LastStanding")
end

-- =========================================================
-- RANDOM WEIGHTED DROPS
-- =========================================================

--- Chọn ngẫu nhiên 1 ItemId từ danh sách Items theo DropRate (tổng DropRate = 100)
--- @param Items table -- array { ItemId, DropRate }
--- @return string? -- ItemId được chọn
function RewardHelper.WeightedRandom(Items)
	if not Items or #Items == 0 then return nil end
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

-- =========================================================
-- SERVER REWARD & SYNC HELPER
-- =========================================================

--- Trao tiền và đồng bộ về client an toàn từ Server
--- @param Player Player
--- @param Amount number
--- @param DataService table -- DataService instance
--- @param UpdateMoneyEvent RemoteEvent?
--- @param Multiplier number? -- Hệ số nhân tùy chọn (mặc định là 1)
--- @return number?, number -- (NewMoney, FinalAmount)
function RewardHelper.RewardAndSync(Player, Amount, DataService, UpdateMoneyEvent, Multiplier)
	if not Player or not Amount or Amount <= 0 or not DataService then return nil, 0 end

	local ActualMultiplier = Multiplier or 1
	local FinalAmount = math.round(Amount * ActualMultiplier)
	local NewMoney = DataService.AddMoney(Player, FinalAmount)
	if UpdateMoneyEvent and NewMoney then
		UpdateMoneyEvent:FireClient(Player, NewMoney)
	end
	return NewMoney, FinalAmount
end

return RewardHelper
