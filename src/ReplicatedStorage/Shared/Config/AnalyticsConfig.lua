-- AnalyticsConfig.lua
-- Cấu hình tập trung toàn bộ hệ thống Thống kê & Phân tích Dữ liệu (Telemetry/Analytics)
-- Nằm trong ReplicatedStorage để cả Server và Client (nếu cần) đều có thể require

local AnalyticsConfig = {

	-- =========================================================
	-- CẤU HÌNH HỆ THỐNG & DEBUG
	-- =========================================================
	Settings = {
		DebugMode               = true,   -- In chi tiết telemetry log ra console
		IsStudioMockEnabled     = true,   -- Khi chạy trong Studio, giả lập ghi nhận log thay vì gọi Roblox API
		EnableCustomEvents      = true,   -- Bật ghi nhận Custom Events
		EnableEconomyEvents     = true,   -- Bật ghi nhận Economy Events (Inflow / Outflow)
		EnableProgressionEvents = true,   -- Bật ghi nhận Progression Events (Quests)
		CurrencyName            = "Coins",-- Tên định danh tiền tệ hiển thị trên Creator Dashboard
	},

	-- =========================================================
	-- TÊN CÁC SỰ KIỆN TÙY BIẾN (CUSTOM EVENTS)
	-- =========================================================
	Events = {
		MatchStarted       = "MatchStarted",
		MatchEnded         = "MatchEnded",
		FrozenStateEntered = "FrozenStateEntered",
		FirstBloodOccurred = "FirstBloodOccurred",
		SpreeAchieved      = "SpreeAchieved",
		ItemAcquired       = "ItemAcquired",
		ChestOpened        = "ChestOpened",
		PlayerSessionEnded = "PlayerSessionEnded",
	},

	-- =========================================================
	-- NGUỒN TIỀN VÀO (ECONOMY SOURCES)
	-- =========================================================
	EconomySources = {
		FreezeReward         = "FreezeReward",
		ThawReward           = "ThawReward",
		SpreeReward          = "SpreeReward",
		FirstBloodReward     = "FirstBloodReward",
		LastStandingReward   = "LastStandingReward",
		MatchWinReward       = "MatchWinReward",
		MatchLoseReward      = "MatchLoseReward",
		DailyQuestReward     = "DailyQuestReward",
		MilestoneQuestReward = "MilestoneQuestReward",
		ProductPurchase      = "ProductPurchase",
		DuplicateRefund      = "DuplicateRefund",
	},

	-- =========================================================
	-- NƠI TIÊU TIỀN RA (ECONOMY SINKS)
	-- =========================================================
	EconomySinks = {
		ChestPurchase    = "ChestPurchase",
		ShopItemPurchase = "ShopItemPurchase",
	},

	-- =========================================================
	-- DANH MỤC TIẾN TRÌNH (PROGRESSION CATEGORIES & ACTIONS)
	-- =========================================================
	ProgressionCategories = {
		DailyQuest     = "DailyQuest",
		MilestoneQuest = "MilestoneQuest",
	},

	ProgressionActions = {
		Start    = "Start",
		Complete = "Complete",
		Fail     = "Fail",
	},

}

return AnalyticsConfig
