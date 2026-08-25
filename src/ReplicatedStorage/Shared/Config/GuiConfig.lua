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
		ObserverGui       = "ObserverGui",  -- ScreenGui độc lập cho chế độ quan sát (Lobby + Frozen Spectator)
		GameLoadingScreen = "GameLoadingScreen", -- ScreenGui nạp game ban đầu khi mới kết nối
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
	-- TÊN CÁC PHẦN TỬ TRONG FRAME BUTTONS CỦA INGAMEGUI
	-- =========================================================
	InGameButtons = {
		Buttons          = "Buttons",          -- Frame chứa các nút in-game
		SpectateButton   = "SpectateButton",   -- Nút bật Spectate (chỉ hiện khi bị Frozen)
		ScoreBoardButton = "ScoreBoardButton", -- Nút mở bảng điểm
	},

	-- =========================================================
	-- TÊN CÁC FRAME MENU CHÍNH TRONG SCREENGUI MENU
	-- =========================================================
	MenuFrames = {
		Shop      = "Shop",
		Inventory = "Inventory",
		Profile   = "Profile",
		Quest     = "Quest",
		-- Spectate đã được chuyển sang ObserverGui (không còn là menu tab)
	},

	-- =========================================================
	-- TÊN CÁC FRAME TRONG SCREENGUI OBSERVERGUI
	-- =========================================================
	ObserverFrames = {
		Spectate = "Spectate",  -- Panel điều khiển camera quan sát
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
	-- TÊN CÁC PHẦN TỬ TRONG SCREENGUI GAMELOADINGSCREEN
	-- =========================================================
	GameLoadingScreenElements = {
		ScreenFrame     = "GameLoadingScreen",
		UpperContainer  = "UpperContainer",
		LowerContainer  = "LowerContainer",
		TitleContainer  = "TitleContainer",
		Title           = "Title",
		TitleBackground = "TitleBackground",
		UIGradient      = "UIGradient",
		Dots            = "Dots",
		DotPrefix       = "Dot",
		SkipButton      = "SkipButton",
		SkipText        = "SkipText",
		Background      = "Background",
	},

	-- =========================================================
	-- THÔNG SỐ HUD VÀ CHỈ SỐ (STATS)
	-- =========================================================
	Stats = {
		MoneyStats = "MoneyStats",
		MoneyText  = "MoneyText",
	},

	-- =========================================================
	-- CẤU HÌNH PLAYERSTATUS (HUD IN-GAME)
	-- =========================================================
	PlayerStatus = {
		AllyColor         = Color3.fromHex("009DFF"),
		EnemyColor        = Color3.fromHex("FF5151"),
		InactiveColor     = Color3.fromHex("868686"), -- Màu xám khi người chơi Frozen hoặc Dead
		DefaultImageColor = Color3.fromRGB(255, 255, 255),
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
	-- Hệ thống 2 tầng: Default (mặc định) + Overrides (theo Key cụ thể)
	-- =========================================================
	Animations = {
		-- 1. Cấu hình popup mở/đóng cửa sổ Menu (Inventory, Shop, Quest, Profile...)
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

			-- Ghi đè riêng cho từng frame menu cụ thể nếu cần (Key = FrameName)
			Overrides = {
				["TopPlayersStats"] = {
					OpenDuration  = 0.3,
					CloseDuration = 0.2,
				},
				["PlayerStats"] = {
					OpenDuration  = 0.3,
					CloseDuration = 0.2,
				},
			},
		},

		-- 2. Cấu hình hiệu ứng phóng to nút bấm điều hướng khi Hover & Click
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

			-- Ghi đè riêng cho từng nút cụ thể nếu cần (Key = ButtonName)
			Overrides = {
				["NextButton"] = {
					HoverScale = 1.1,
					PressScale = 0.95,
				},
				["CloseButton"] = {
					HoverScale = 1.15,
					PressScale = 0.9,
				},
			},
		},

		-- 3. Cấu hình hiệu ứng xuất hiện lần lượt cho các Template (Inventory, Shop, Quest...)
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

			-- Ghi đè riêng cho từng menu/danh sách cụ thể (Key = Identifier)
			Overrides = {
				["Quest"] = {
					DelayStep   = 0.07,
					Duration    = 0.3,
					EasingStyle = Enum.EasingStyle.Sine,
				},
				["TopPlayersStats"] = {
					DelayStep   = 0.08,
					Duration    = 0.25,
					EasingStyle = Enum.EasingStyle.Back,
				},
				["TotalStats"] = {
					DelayStep   = 0.08,
					Duration    = 0.22,
					EasingStyle = Enum.EasingStyle.Back,
					ItemSoundId = 132948338000932,
				},
			},
		},

		-- 4. Cấu hình hiệu ứng mở rương và phần thưởng (Special/ItemReward)
		ItemReward = {
			-- Thông số mặc định dùng chung cho tất cả các loại rương
			Default = {
				ChestZoomDuration   = 0.4,   -- Thời gian rương 3D zoom vào giữa màn hình (giây)
				RotationSpeed       = 36,    -- Tốc độ xoay hào quang EffectImage (độ/giây, 360° trong 10s)
				ChestShrinkDuration = 0.15,  -- Thời gian thu nhỏ khi click rương ở Pha 1 (giây)
				ChestExpandDuration = 0.25,  -- Thời gian bật nảy lại sau khi thu nhỏ ở Pha 1 (giây)
				FlashDuration       = 0.4,   -- Thời gian flash trắng khi chuyển sang Pha 2 (giây)
				FadeDuration        = 0.4,   -- Thời gian fade về nền mờ sau flash (giây)
				ZoomEasingStyle     = Enum.EasingStyle.Back,
				ZoomEasingDir       = Enum.EasingDirection.Out,
				ShrinkEasingStyle   = Enum.EasingStyle.Quad,
				ShrinkEasingDir     = Enum.EasingDirection.Out,
				ExpandEasingStyle   = Enum.EasingStyle.Back,
				ExpandEasingDir     = Enum.EasingDirection.Out,
			},

			-- Ghi đè riêng cho từng rương cụ thể nếu cần (Key = ChestId)
			Overrides = {
				-- ["GoldenChest"] = {
				-- 	ChestZoomDuration = 0.5,
				-- 	RotationSpeed     = 72,
				-- },
			},
		},

		-- 5. Cấu hình màn hình thông báo chế độ chơi đặc biệt (Special/ModeAnnouncement)
		ModeAnnouncement = {
			-- Thông số mặc định dùng chung cho tất cả các chế độ chơi đặc biệt
			Default = {
				DisplayDuration = 4.0,  -- Thời gian hiển thị thông báo trước khi chuyển sang loading (giây)
				FadeInDuration  = 0.5,  -- Thời gian fade in mỗi dòng chữ (ModeNameText, DescriptionText)
				EasingStyle     = Enum.EasingStyle.Quad,
				EasingDir       = Enum.EasingDirection.Out,
			},

			-- Ghi đè riêng cho từng chế độ chơi cụ thể nếu cần (Key = ModeKey)
			Overrides = {
				-- ["Chaos"] = {
				-- 	DisplayDuration = 5.0,
				-- },
				-- ["EternalFreeze"] = {
				-- 	DisplayDuration = 4.5,
				-- },
			},
		},

		-- 6. Cấu hình màn hình chuyển cảnh đầu trận (Special/RoundLoadingScreen)
		RoundLoadingScreen = {
			-- Thông số mặc định dùng chung cho tất cả các vòng đấu
			Default = {
				FadeInDuration     = 1.0,  -- Thời gian mờ đen màn hình khi bắt đầu Setup (giây)
				HoldDuration       = 1.0,  -- Thời gian giữ màn hình đen khi vào Ready (giây)
				FadeOutDuration    = 0.5,  -- Thời gian sáng dần trở lại (giây)
				FadeInEasingStyle  = Enum.EasingStyle.Quad,
				FadeInEasingDir    = Enum.EasingDirection.Out,
				FadeOutEasingStyle = Enum.EasingStyle.Quad,
				FadeOutEasingDir   = Enum.EasingDirection.In,
			},

			-- Ghi đè riêng cho từng chế độ chơi nếu cần chuyển cảnh khác nhau (Key = ModeKey)
			Overrides = {
				-- ["Chaos"] = {
				-- 	HoldDuration = 1.5,
				-- },
			},
		},

		-- 7. Cấu hình thông báo danh hiệu trong trận (InGameGui/AccoladesAnnouncement)
		Accolades = {
			-- Thông số mặc định dùng chung cho tất cả các danh hiệu theo phong cách Pop (UIScale)
			Default = {
				OpenDuration     = 0.25, -- Thời gian bung nở Pop mở ra (giây)
				CloseDuration    = 0.2,  -- Thời gian thu nhỏ Pop đóng lại (giây)
				DisplayDuration  = 1.5,  -- Thời gian duy trì hiển thị trước khi tự động đóng (giây)
				OpenEasingStyle  = Enum.EasingStyle.Back,
				OpenEasingDir    = Enum.EasingDirection.Out,
				CloseEasingStyle = Enum.EasingStyle.Quad,
				CloseEasingDir   = Enum.EasingDirection.In,
				InitialScale     = 0,
				TargetScale      = 1,
			},

			-- Ghi đè riêng cho từng danh hiệu cụ thể nếu cần (Key = AccoladeType)
			Overrides = {
				-- ["FirstBlood"] = {
				-- 	DisplayDuration = 2.0,
				-- },
			},
		},

		-- 8. Cấu hình màn hình khởi động game ban đầu (GameLoadingScreen)
		GameLoadingScreen = {
			Default = {
				DotWaveDuration     = 1.2,  -- Thời gian 1 chu kỳ nở và co của 1 dot (giây)
				DotMinScale         = 0.6,  -- Scale nhỏ nhất của dot
				DotMaxScale         = 1,  -- Scale lớn nhất của dot
				DotEasingStyle      = Enum.EasingStyle.Sine,
				DotEasingDir        = Enum.EasingDirection.InOut,
				TitleMinScale       = 1.0,  -- Scale ban đầu của Title
				TitleLoadMaxScale   = 1.4,  -- Scale tối đa của Title khi đạt 100% load
				TitlePopScale       = 1.6,  -- Scale bung nở của Title ở Pha 1 kết thúc
				Phase1PopDuration   = 0.35, -- Thời gian bung Title lên 1.6
				Phase1DotBlinkCount = 2,    -- Số lần nhấp nháy của Dot ở Pha 1 (1.6 -> 1.3 -> 1.6)
				Phase1DotBlinkTime  = 0.4, -- Thời gian mỗi lượt nhấp nháy của Dot
				Phase2Duration      = 0.5, -- Thời gian trượt rèm Upper/Lower ra khỏi màn hình (giây)
				Phase2EasingStyle   = Enum.EasingStyle.Quad,
				Phase2EasingDir     = Enum.EasingDirection.InOut,
				MinLoadingDuration  = 10,  -- Thời gian nạp tối thiểu (giây) để hiển thị đầy đủ hoạt ảnh
				SafetyTimeout       = 10,   -- Timeout tối đa (giây) tự động hoàn tất nếu CDN rớt mạng
				ProgressLerpSpeed   = 8,    -- Tốc độ lerp mượt mà của VisualProgress
			},
			Overrides = {},
		},
	},

}

return GuiConfig
