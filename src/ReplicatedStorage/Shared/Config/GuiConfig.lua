-- GuiConfig.lua
-- Cấu hình tên ScreenGui, Buttons, Containers và các thông số GUI tập trung
-- Giúp loại bỏ hardcoded string rải rác trong các controller client

local GuiConfig = {

	-- =========================================================
	-- TÊN CÁC SCREENGUI CHÍNH TRONG PLAYERGUI
	-- =========================================================
	ScreenGuis = {
		NavigationButtons = "NavigationButtons",
		Menu              = "Menu",
		InGameGui         = "InGameGui",
		GameState         = "GameState",
		Special           = "Special",
		GameStatistic     = "GameStatistic",
	},

	-- =========================================================
	-- TÊN CÁC CONTAINER PHÂN CẤP BÊN TRONG NAVIGATIONBUTTONS
	-- =========================================================
	NavContainers = {
		Buttons = "Buttons",  -- Container chứa các nút điều hướng
		Extra   = "Extra",    -- Container phụ chứa Profile, Setting
		Stats   = "Stats",    -- Container chứa thông tin tiền, chỉ số
	},

	-- =========================================================
	-- TÊN CÁC NÚT ĐIỀU HƯỚNG (NAVIGATION BUTTONS)
	-- =========================================================
	NavButtons = {
		Shop      = "Shop",
		Inventory = "Inventory",
		Quest     = "Quest",
		Spectate  = "Spectate",
		Profile   = "Profile",
		Setting   = "Setting",
	},

	-- =========================================================
	-- TÊN CÁC FRAME MENU CHÍNH TRONG SCREENGUI MENU
	-- =========================================================
	MenuFrames = {
		Shop      = "Shop",
		Inventory = "Inventory",
		Profile   = "Profile",
		Quest     = "Quest",
		Spectate  = "Spectate",
	},

	-- =========================================================
	-- THÔNG SỐ HUD VÀ CHỈ SỐ (STATS)
	-- =========================================================
	Stats = {
		MoneyStats = "MoneyStats",
		MoneyText  = "MoneyText",
	},

	-- =========================================================
	-- TIMEOUT MẶC ĐỊNH KHI WAIT CHO CÁC PHẦN TỬ GUI (giây)
	-- =========================================================
	Timeouts = {
		DefaultWaitForGui = 10,
		ShortWait         = 5,
	},

}

return GuiConfig
