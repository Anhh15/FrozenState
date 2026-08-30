-- GuiConfig.lua
-- Cấu hình tên ScreenGui, Buttons, Containers và các định danh phần tử GUI tập trung
-- Chỉ chứa tên phần tử (strings) — thông số animation và màu sắc nằm trong GuiAnimConfig.lua
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
		ObserverGui       = "ObserverGui",       -- ScreenGui độc lập cho chế độ quan sát (Lobby + Frozen Spectator)
		GameLoadingScreen = "GameLoadingScreen", -- ScreenGui nạp game ban đầu khi mới kết nối
	},

	-- =========================================================
	-- TÊN CÁC CONTAINER PHÂN CẤP BÊN TRONG NAVIGATIONBUTTONS
	-- =========================================================
	NavContainers = {
		Buttons = "Buttons", -- Container chứa các nút điều hướng
		Extra   = "Extra",   -- Container phụ chứa Profile, Setting
		Stats   = "Stats",   -- Container chứa thông tin tiền, chỉ số
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
		Hotbar           = "Hotbar",           -- Frame chứa thanh phím tắt vũ khí
	},

	-- =========================================================
	-- TÊN CÁC PHẦN TỬ THÔNG BÁO TRONG INGAMEGUI
	-- =========================================================
	InGameAnnouncements = {
		AccoladesAnnouncement   = "AccoladesAnnouncement",
		FrozenStateAnnouncement = "FrozenStateAnnouncement",
	},

	-- =========================================================
	-- TÊN CÁC PHẦN TỬ TRONG FRAME HOTBAR CỦA INGAMEGUI
	-- =========================================================
	HotbarElements = {
		Hotbar          = "Hotbar",
		Templates       = "Templates",
		ItemSlot        = "ItemSlot",
		Background      = "Background",
		ItemViewport    = "ItemViewport",
		CooldownCurtain = "CooldownCurtain",
		CooldownText    = "CooldownText",
		IndexText       = "IndexText",
		UIScale         = "UIScale",
	},

	-- =========================================================
	-- TÊN CÁC FRAME MENU CHÍNH TRONG SCREENGUI MENU
	-- =========================================================
	MenuFrames = {
		Shop      = "Shop",
		Inventory = "Inventory",
		Profile   = "Profile",
		Quest     = "Quest",
		Setting   = "Setting",
		-- Spectate đã được chuyển sang ObserverGui (không còn là menu tab)
	},

	-- =========================================================
	-- TÊN CÁC PHẦN TỬ TRONG FRAME SETTING
	-- =========================================================
	SettingElements = {
		ScrollingFrame       = "ScrollingFrame",
		CloseButton          = "CloseButton",

		-- Gameplay Section
		GameplaySection      = "GameplaySection",
		Config               = "Config",
		OnButton             = "OnButton",
		OffButton            = "OffButton",
		AfkText              = "AfkText",
		Background           = "Background",
		Text                 = "Text",

		-- Sound Section
		SoundSection         = "SoundSection",
		MasterRow            = "MasterRow",
		MusicRow             = "MusicRow",
		SFXRow               = "SFXRow",
		UIRow                = "UIRow",

		-- Slider Components
		SlideBar             = "SlideBar",
		Track                = "Track",
		TicksContainer       = "TicksContainer",
		TickPrefix           = "Tick",
		Knob                 = "Knob",
		SlideButton          = "SlideButton",
		VolumeTextContainer  = "VolumeTextContainer",
		TitleText            = "TitleText",
	},

	-- =========================================================
	-- TÊN CÁC FRAME TRONG SCREENGUI OBSERVERGUI
	-- =========================================================
	ObserverFrames = {
		Spectate = "Spectate", -- Panel điều khiển camera quan sát
	},

	-- =========================================================
	-- TÊN CÁC FRAME CHÍNH TRONG SCREENGUI SPECIAL
	-- =========================================================
	SpecialFrames = {
		RoundLoadingScreen   = "RoundLoadingScreen",
		ItemReward           = "ItemReward",
		ModeAnnouncement     = "ModeAnnouncement",
		GameOverAnnouncement = "GameOverAnnouncement",
	},

	-- =========================================================
	-- TÊN CÁC PHẦN TỬ TRONG FRAME GAMEOVERANNOUNCEMENT
	-- =========================================================
	GameOverAnnouncementElements = {
		Background       = "Background",
		AnnouncementText = "AnnouncementText",
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
	-- TÊN CÁC ATTRIBUTES ĐIỀU KHIỂN GUI
	-- =========================================================
	Attributes = {
		IgnoreAutoBind = "IgnoreAutoBind",
		AutoBind       = "AutoBind",
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
