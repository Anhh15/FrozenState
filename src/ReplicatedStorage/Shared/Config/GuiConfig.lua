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
	-- TÊN CÁC FRAME CHÍNH TRONG SCREENGUI SPECIAL
	-- =========================================================
	SpecialFrames = {
		RoundLoadingScreen = "RoundLoadingScreen",
		ItemReward         = "ItemReward",
		ModeAnnouncement   = "ModeAnnouncement",
	},

	-- =========================================================
	-- TÊN CÁC PHẦN TỬ TRONG FRAME MODEANNOUNCEMENT
	-- =========================================================
	ModeAnnouncementElements = {
		Background      = "Background",
		ModeNameText    = "ModeNameText",
		DescriptionText = "DescriptionText",
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

	-- =========================================================
	-- CẤU HÌNH ANIMATION GUI (TWEEN / SCALE / TIMING)
	-- =========================================================
	Animations = {
		-- Cấu hình popup mở/đóng cửa sổ Menu (Inventory, Shop, Quest, Profile...)
		Pop = {
			-- Thông số mặc định dùng chung cho tất cả các menu
			Default = {
				OpenDuration     = 0.25,
				CloseDuration    = 0.2,
				OpenEasingStyle  = Enum.EasingStyle.Back,
				OpenEasingDir    = Enum.EasingDirection.Out,
				CloseEasingStyle = Enum.EasingStyle.Quad,
				CloseEasingDir   = Enum.EasingDirection.In,
				InitialScale     = 0,
				TargetScale      = 1,
			},

			-- Ghi đè riêng cho từng frame menu cụ thể nếu cần (mẫu comment)
			Overrides = {
				-- ["Shop"] = {
				-- 	OpenDuration = 0.3,
				-- },
				-- ["Inventory"] = {
				-- 	OpenDuration = 0.22,
				-- },
			},
		},

		-- Cấu hình hiệu ứng phóng to nút bấm điều hướng khi Hover & Click
		ButtonScale = {
			-- Thông số mặc định dùng chung cho tất cả các nút
			Default = {
				Duration         = 0.15,
				EasingStyle      = Enum.EasingStyle.Back,
				EasingDir        = Enum.EasingDirection.Out,
				DefaultScale     = 1.0,
				HoverScale       = 1.15,
				PressScale       = 0.92,
			},

			-- Ghi đè riêng cho từng nút cụ thể nếu cần (mẫu comment)
			Overrides = {
				-- ["Shop"] = {
				-- 	HoverScale = 1.12,
				-- },
				-- ["Inventory"] = {
				-- 	HoverScale = 1.18,
				-- },
			},
		},
		-- Cấu hình hiệu ứng xuất hiện lần lượt cho các Template (Inventory, Shop, Quest...)
		Stagger = {
			-- Thông số mặc định dùng chung cho tất cả các danh sách
			Default = {
				DelayStep        = 0.03, -- Khoảng thời gian trễ giữa các item liên tiếp (giây)
				Duration         = 0.2,  -- Thời gian bung nở của từng item
				EasingStyle      = Enum.EasingStyle.Back,
				EasingDir        = Enum.EasingDirection.Out,
				InitialScale     = 0.0,
				TargetScale      = 1.0,
			},

			-- Ghi đè riêng cho từng menu/danh sách cụ thể nếu cần (mẫu comment)
			Overrides = {
				-- ["Inventory"] = {
				-- 	DelayStep = 0.03,
				-- },
				-- ["Shop"] = {
				-- 	DelayStep = 0.03,
				-- },
				-- ["Quest"] = {
				-- 	DelayStep = 0.03,
				-- },
				["Quest"] = {
					DelayStep        = 0.03,
					Duration         = 0.2,
					EasingStyle      = Enum.EasingStyle.Sine,
					EasingDir        = Enum.EasingDirection.Out,
					InitialScale     = 0.0,
					TargetScale      = 1.0,
				},
			},
		},
	},

}

return GuiConfig
