-- QuestConfig.lua
-- Tham số và định nghĩa toàn bộ nhiệm vụ trong game
-- Thêm quest mới vào Pool (Daily) hoặc List (Milestone) tại đây, không hardcode ở nơi khác
-- StatKey phải khớp với tên field trong DataService PROFILE_TEMPLATE

local QuestConfig = {

	-- =========================================================
	-- DAILY QUEST
	-- =========================================================
	Daily = {
		PoolCount    = 5,     -- Số quest được random mỗi chu kỳ
		ResetSeconds = 86400, -- Thời gian reset: 24 giờ (giây)

		-- Bể nhiệm vụ — random PoolCount quest từ đây mỗi chu kỳ
		-- StatKey: tên field stat trong DataService (TotalFreezes, TotalWins, PlayTime,...)
		-- RewardType: loại phần thưởng hiện tại chỉ có "Money"
		Pool = {
			{
				Id            = "D_Freeze5",
				Description   = "Freeze 5 enemies",
				StatKey       = "TotalFreezes",
				Requirement   = 5,
				RewardType    = "Money",
				RewardAmount  = 50,
			},
			{
				Id            = "D_Thaw5",
				Description   = "Thaw 5 allies",
				StatKey       = "TotalThaws",
				Requirement   = 5,
				RewardType    = "Money",
				RewardAmount  = 50,
			},
			{
				Id            = "D_Win3",
				Description   = "Win 3 matches",
				StatKey       = "TotalWins",
				Requirement   = 3,
				RewardType    = "Money",
				RewardAmount  = 100,
			},
			{
				Id            = "D_FreezingSpree2",
				Description   = "Achieve Freezing Spree 2 times",
				StatKey       = "TotalFreezingSpree",
				Requirement   = 2,
				RewardType    = "Money",
				RewardAmount  = 75,
			},
			{
				Id            = "D_ThawingSpree2",
				Description   = "Achieve Thawing Spree 2 times",
				StatKey       = "TotalThawingSpree",
				Requirement   = 2,
				RewardType    = "Money",
				RewardAmount  = 75,
			},
			{
				Id            = "D_Freeze10",
				Description   = "Freeze 10 enemies",
				StatKey       = "TotalFreezes",
				Requirement   = 10,
				RewardType    = "Money",
				RewardAmount  = 120,
			},
			{
				Id            = "D_Thaw10",
				Description   = "Thaw 10 allies",
				StatKey       = "TotalThaws",
				Requirement   = 10,
				RewardType    = "Money",
				RewardAmount  = 120,
			},
			{
				Id            = "D_FirstBlood1",
				Description   = "Get First Blood 1 time",
				StatKey       = "TotalFirstBlood",
				Requirement   = 1,
				RewardType    = "Money",
				RewardAmount  = 80,
			},
			{
				Id            = "D_LastStanding1",
				Description   = "Be Last Standing 1 time",
				StatKey       = "TotalLastStanding",
				Requirement   = 1,
				RewardType    = "Money",
				RewardAmount  = 80,
			},
			{
				Id            = "D_PlayTime30",
				Description   = "Play for 30 minutes",
				StatKey       = "PlayTime",
				Requirement   = 1800,  -- 30 phút = 1800 giây
				RewardType    = "Money",
				RewardAmount  = 60,
			},
		},
	},

	-- =========================================================
	-- MILESTONE QUEST
	-- =========================================================
	Milestone = {
		StackExcessProgress = false, -- false: reset tiến trình dôi dư về 0 khi claim; true: cộng dồn tiến trình dư vào mốc tiếp theo

		-- Quest lặp vô hạn: sau khi claim sẽ tự reset về mốc tiếp theo
		-- Tiến trình dùng stat tổng (TotalFreezes, TotalWins,...) trừ đi BaseProgress đã claim
		List = {
			{
				Id            = "M_Freeze50",
				Description   = "Freeze 50 enemies",
				StatKey       = "TotalFreezes",
				Requirement   = 50,
				RewardType    = "Money",
				RewardAmount  = 500,
			},
			{
				Id            = "M_Thaw50",
				Description   = "Thaw 50 allies",
				StatKey       = "TotalThaws",
				Requirement   = 50,
				RewardType    = "Money",
				RewardAmount  = 500,
			},
			{
				Id            = "M_Win10",
				Description   = "Win 10 matches",
				StatKey       = "TotalWins",
				Requirement   = 10,
				RewardType    = "Money",
				RewardAmount  = 1000,
			},
			{
				Id            = "M_FreezingSpree10",
				Description   = "Achieve Freezing Spree 10 times",
				StatKey       = "TotalFreezingSpree",
				Requirement   = 10,
				RewardType    = "Money",
				RewardAmount  = 750,
			},
			{
				Id            = "M_ThawingSpree10",
				Description   = "Achieve Thawing Spree 10 times",
				StatKey       = "TotalThawingSpree",
				Requirement   = 10,
				RewardType    = "Money",
				RewardAmount  = 750,
			},
			{
				Id            = "M_FirstBlood10",
				Description   = "Get First Blood 10 times",
				StatKey       = "TotalFirstBlood",
				Requirement   = 10,
				RewardType    = "Money",
				RewardAmount  = 800,
			},
			{
				Id            = "M_LastStanding10",
				Description   = "Be Last Standing 10 times",
				StatKey       = "TotalLastStanding",
				Requirement   = 10,
				RewardType    = "Money",
				RewardAmount  = 800,
			},
			{
				Id            = "M_PlayTime2h",
				Description   = "Play for 2 hours",
				StatKey       = "PlayTime",
				Requirement   = 7200,
				RewardType    = "Money",
				RewardAmount  = 600,
			},
		},
	},
}

return QuestConfig
