-- GuiAnimConfig.lua
-- Cấu hình thông số animation, màu sắc UI và hành vi runtime cho GUI FrozenState
-- Tách biệt khỏi GuiConfig.lua (tên phần tử) để rõ trách nhiệm
-- Hệ thống 2 tầng: Default (mặc định) + Overrides (theo Key cụ thể)
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local GuiAnimConfig = {

	-- =========================================================
	-- 1. CẤU HÌNH PLAYERSTATUS (MÀU SẮC HUD IN-GAME)
	-- =========================================================
	PlayerStatus = {
		AllyColor         = Color3.fromHex("009DFF"),
		EnemyColor        = Color3.fromHex("FF5151"),
		InactiveColor     = Color3.fromHex("868686"), -- Màu xám khi người chơi Frozen hoặc Dead
		DefaultImageColor = Color3.fromRGB(255, 255, 255),
	},

	-- =========================================================
	-- 2. CẤU HÌNH GAMEOVER (MÀU SẮC & GIỚI HẠN VĂN BẢN)
	-- =========================================================
	GameOver = {
		FFAWinnerColor = Color3.fromHex("FFD700"),     -- Màu Vàng Kim vinh danh người chiến thắng FFA
		SpectatorColor = Color3.fromRGB(255, 255, 255), -- Màu Trắng sáng cho khán giả không thuộc đội nào
		MaxNameLength  = 15,                           -- Độ dài tối đa của DisplayName trước khi cắt thêm "..."
	},

	-- =========================================================
	-- 2.1 CẤU HÌNH HIGHLIGHT (ĐỒ HỌA VIỀN NHÂN VẬT & KHỐI BĂNG)
	-- =========================================================
	Highlight = {
		EnemyColor          = Color3.fromRGB(220, 50,  50),  -- Đỏ kẻ địch
		AllyColor           = Color3.fromRGB(50,  120, 220), -- Xanh đồng minh
		FillTransparency    = 1.0,
		OutlineTransparency = 0.0,
	},

	-- =========================================================
	-- 2.2 CẤU HÌNH QUEST (MÀU SẮC TAB & TIẾN TRÌNH)
	-- =========================================================
	Quest = {
		ActiveTabColor   = Color3.fromRGB(255, 255, 255),
		InactiveTabColor = Color3.fromRGB(47, 47, 47),
	},

	-- =========================================================
	-- 3. CẤU HÌNH ANIMATION GUI (TWEEN / SCALE / TIMING)
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
				Duration     = 0.15,
				EasingStyle  = Enum.EasingStyle.Back,
				EasingDir    = Enum.EasingDirection.Out,
				DefaultScale = 1.0,
				HoverScale   = 1.15,
				PressScale   = 0.92,
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
				["ItemTemplate"] = {
					HoverScale = 1.05,
					PressScale = 0.95,
					Duration   = 0.15,
				},
			},
		},

		-- 3. Cấu hình hiệu ứng xuất hiện lần lượt cho các Template (Inventory, Shop, Quest...)
		Stagger = {
			-- Thông số mặc định dùng chung cho tất cả các danh sách
			Default = {
				DelayStep    = 0.03, -- Khoảng thời gian trễ giữa các item liên tiếp (giây)
				Duration     = 0.2,  -- Thời gian bung nở của từng item
				EasingStyle  = Enum.EasingStyle.Back,
				EasingDir    = Enum.EasingDirection.Out,
				InitialScale = 0.0,
				TargetScale  = 1.0,
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
				DotMaxScale         = 1,    -- Scale lớn nhất của dot
				DotEasingStyle      = Enum.EasingStyle.Sine,
				DotEasingDir        = Enum.EasingDirection.InOut,
				TitleMinScale       = 1.0,  -- Scale ban đầu của Title
				TitleLoadMaxScale   = 1.4,  -- Scale tối đa của Title khi đạt 100% load
				TitlePopScale       = 1.6,  -- Scale bung nở của Title ở Pha 1 kết thúc
				Phase1PopDuration   = 0.35, -- Thời gian bung Title lên 1.6
				Phase1DotBlinkCount = 2,    -- Số lần nhấp nháy của Dot ở Pha 1 (1.6 -> 1.3 -> 1.6)
				Phase1DotBlinkTime  = 0.4,  -- Thời gian mỗi lượt nhấp nháy của Dot
				Phase2Duration      = 0.5,  -- Thời gian trượt rèm Upper/Lower ra khỏi màn hình (giây)
				Phase2EasingStyle   = Enum.EasingStyle.Quad,
				Phase2EasingDir     = Enum.EasingDirection.InOut,
				MinLoadingDuration  = 4,    -- Thời gian nạp tối thiểu (giây) để hiển thị đầy đủ hoạt ảnh
				SafetyTimeout       = 10,   -- Timeout tối đa (giây) tự động hoàn tất nếu CDN rớt mạng
				ProgressLerpSpeed   = 8,    -- Tốc độ lerp mượt mà của VisualProgress
			},
			Overrides = {},
		},

		-- 9. Cấu hình thông báo kết thúc trận đấu (Special/GameOverAnnouncement)
		GameOverAnnouncement = {
			Default = {
				DisplayDuration       = 3.2,   -- Thời gian giữ hiển thị thông báo trước khi đóng (giây)
				SplitDuration         = 0.6,   -- Thời gian mở rộng ngang Background từ tâm sang 2 bên (giây)
				FlyInDuration         = 0.35,  -- Thời gian AnnouncementText bay từ dưới lên vị trí mặc định (giây)
				FlyOutDuration        = 0.25,  -- Thời gian AnnouncementText bay ra khỏi màn hình trước khi đóng nền (giây)
				CloseDuration         = 0.3,   -- Thời gian thu nhỏ Background khi kết thúc (giây)
				FlyInStartPosYScale   = 2.0,   -- Vị trí Y ban đầu của AnnouncementText (dưới đáy màn hình)
				FlyOutTargetPosYScale = -1.0,  -- Vị trí Y đích khi AnnouncementText bay ra ngoài (trên đỉnh màn hình)
				SplitEasingStyle      = Enum.EasingStyle.Back,
				SplitEasingDir        = Enum.EasingDirection.Out,
				FlyInEasingStyle      = Enum.EasingStyle.Back,
				FlyInEasingDir        = Enum.EasingDirection.Out,
				FlyOutEasingStyle     = Enum.EasingStyle.Quad,
				FlyOutEasingDir       = Enum.EasingDirection.In,
				CloseEasingStyle      = Enum.EasingStyle.Quad,
				CloseEasingDir        = Enum.EasingDirection.In,
			},
			Overrides = {},
		},

		-- 10. Cấu hình Hotbar (InGameGui/Hotbar)
		Hotbar = {
			Default = {
				InactiveScale           = 1.0,
				ActiveScale             = 1.3,
				ScaleDuration           = 0.15,
				ScaleEasingStyle        = Enum.EasingStyle.Back,
				ScaleEasingDir          = Enum.EasingDirection.Out,
				InactiveBackgroundTrans = 0.8,
				ActiveBackgroundTrans   = 0.4,
				CooldownEasingStyle     = Enum.EasingStyle.Linear,
				CooldownEasingDir       = Enum.EasingDirection.InOut,
			},
			Overrides = {},
		},

		-- 11. Cấu hình thông báo Frozen State (InGameGui/FrozenStateAnnouncement)
		FrozenStateAnnouncement = {
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
			Overrides = {},
		},

		-- 12. Cấu hình nút gạt Menu Setting (Menu/Setting Toggle)
		Setting = {
			Default = {
				ActiveBackgroundColor   = Color3.fromHex("FFFFFF"),
				ActiveTextColor         = Color3.fromHex("000000"),
				InactiveBackgroundColor = Color3.fromHex("B6B6B6"),
				InactiveTextColor       = Color3.fromHex("747474"),
				Duration                = 0.15,
				EasingStyle             = Enum.EasingStyle.Quad,
				EasingDir               = Enum.EasingDirection.Out,
			},
			Overrides = {},
		},

		-- 13. Cấu hình thanh trượt Slider (Setting Sound Sliders)
		Slider = {
			Default = {
				StepCount        = 10,  -- 10 khoảng (11 ticks: 0%, 10%, ..., 100%)
				TickCount        = 11,  -- Số lượng ticks
				Duration         = 0.08, -- Thời gian tween knob giữa các nấc
				EasingStyle      = Enum.EasingStyle.Quad,
				EasingDir        = Enum.EasingDirection.Out,
			},
			Overrides = {},
		},
	},

}

-- =========================================================
-- PUBLIC GETTERS & RESOLUTION UTILITIES
-- =========================================================

--- Lấy cặp (Default, Override) cho một AnimKey và OverrideKey tùy chọn
--- @param AnimKey string -- "Pop" | "ButtonScale" | "Stagger" | ...
--- @param OverrideKey string?
--- @return table, table -- DefaultCfg, OverrideCfg
local function Resolve(AnimKey, OverrideKey)
	local Block = GuiAnimConfig.Animations[AnimKey]
	if not Block then return {}, {} end
	local DefaultCfg  = Block.Default or {}
	local OverrideCfg = (OverrideKey and Block.Overrides and Block.Overrides[OverrideKey]) or {}
	return DefaultCfg, OverrideCfg
end

--- Lấy cấu hình Pop của Frame dựa theo tên (kết hợp Default và Overrides)
--- @param FrameName string? -- "TopPlayersStats" | "PlayerStats" | ...
--- @return table
function GuiAnimConfig.GetPopConfig(FrameName)
	local D, O = Resolve("Pop", FrameName)
	return {
		OpenDuration     = O.OpenDuration     or D.OpenDuration     or 0.25,
		CloseDuration    = O.CloseDuration    or D.CloseDuration    or 0.2,
		OpenEasingStyle  = O.OpenEasingStyle  or D.OpenEasingStyle  or Enum.EasingStyle.Back,
		OpenEasingDir    = O.OpenEasingDir    or D.OpenEasingDir    or Enum.EasingDirection.Out,
		CloseEasingStyle = O.CloseEasingStyle or D.CloseEasingStyle or Enum.EasingStyle.Quad,
		CloseEasingDir   = O.CloseEasingDir   or D.CloseEasingDir   or Enum.EasingDirection.In,
		InitialScale     = O.InitialScale     or D.InitialScale     or 0,
		TargetScale      = O.TargetScale      or D.TargetScale      or 1,
	}
end

--- Lấy cấu hình Scale của Button dựa theo tên (kết hợp Default và Overrides)
--- @param ButtonName string? -- "NextButton" | "CloseButton" | "ItemTemplate" | ...
--- @return table
function GuiAnimConfig.GetButtonScaleConfig(ButtonName)
	local D, O = Resolve("ButtonScale", ButtonName)
	return {
		Duration     = O.Duration     or D.Duration     or 0.15,
		EasingStyle  = O.EasingStyle  or D.EasingStyle  or Enum.EasingStyle.Back,
		EasingDir    = O.EasingDir    or D.EasingDir    or Enum.EasingDirection.Out,
		DefaultScale = O.DefaultScale or D.DefaultScale or 1.0,
		HoverScale   = O.HoverScale   or D.HoverScale   or 1.15,
		PressScale   = O.PressScale   or D.PressScale   or 0.92,
	}
end

--- Lấy cấu hình Stagger của danh sách (kết hợp Default và Overrides)
--- @param Identifier string? -- "Inventory" | "Shop" | "Quest" | "TopPlayersStats" | "TotalStats" | ...
--- @return table
function GuiAnimConfig.GetStaggerConfig(Identifier)
	local D, O = Resolve("Stagger", Identifier)
	return {
		DelayStep    = O.DelayStep    or D.DelayStep    or 0.03,
		Duration     = O.Duration     or D.Duration     or 0.2,
		EasingStyle  = O.EasingStyle  or D.EasingStyle  or Enum.EasingStyle.Back,
		EasingDir    = O.EasingDir    or D.EasingDir    or Enum.EasingDirection.Out,
		InitialScale = O.InitialScale or D.InitialScale or 0.0,
		TargetScale  = O.TargetScale  or D.TargetScale  or 1.0,
		ItemSoundId  = O.ItemSoundId  or D.ItemSoundId,
	}
end

--- Lấy cấu hình Animation ItemReward (kết hợp Default và Overrides theo ChestId)
--- @param ChestId string? -- "GoldenChest" | ...
--- @return table
function GuiAnimConfig.GetItemRewardAnimConfig(ChestId)
	local D, O = Resolve("ItemReward", ChestId)
	return {
		ChestZoomDuration   = O.ChestZoomDuration   or D.ChestZoomDuration   or 0.4,
		RotationSpeed       = O.RotationSpeed       or D.RotationSpeed       or 36,
		ChestShrinkDuration = O.ChestShrinkDuration or D.ChestShrinkDuration or 0.15,
		ChestExpandDuration = O.ChestExpandDuration or D.ChestExpandDuration or 0.25,
		FlashDuration       = O.FlashDuration       or D.FlashDuration       or 0.4,
		FadeDuration        = O.FadeDuration        or D.FadeDuration        or 0.4,
		ZoomEasingStyle     = O.ZoomEasingStyle     or D.ZoomEasingStyle     or Enum.EasingStyle.Back,
		ZoomEasingDir       = O.ZoomEasingDir       or D.ZoomEasingDir       or Enum.EasingDirection.Out,
		ShrinkEasingStyle   = O.ShrinkEasingStyle   or D.ShrinkEasingStyle   or Enum.EasingStyle.Quad,
		ShrinkEasingDir     = O.ShrinkEasingDir     or D.ShrinkEasingDir     or Enum.EasingDirection.Out,
		ExpandEasingStyle   = O.ExpandEasingStyle   or D.ExpandEasingStyle   or Enum.EasingStyle.Back,
		ExpandEasingDir     = O.ExpandEasingDir     or D.ExpandEasingDir     or Enum.EasingDirection.Out,
	}
end

--- Lấy cấu hình Animation ModeAnnouncement (kết hợp Default và Overrides theo ModeKey)
--- @param ModeKey string? -- "Chaos" | "EternalFreeze" | ...
--- @return table
function GuiAnimConfig.GetModeAnnouncementAnimConfig(ModeKey)
	local D, O = Resolve("ModeAnnouncement", ModeKey)
	return {
		DisplayDuration = O.DisplayDuration or D.DisplayDuration or 4.0,
		FadeInDuration  = O.FadeInDuration  or D.FadeInDuration  or 0.5,
		EasingStyle     = O.EasingStyle     or D.EasingStyle     or Enum.EasingStyle.Quad,
		EasingDir       = O.EasingDir       or D.EasingDir       or Enum.EasingDirection.Out,
	}
end

--- Lấy cấu hình Animation RoundLoadingScreen (kết hợp Default và Overrides theo ModeKey)
--- @param ModeKey string? -- "Chaos" | ...
--- @return table
function GuiAnimConfig.GetRoundLoadingAnimConfig(ModeKey)
	local D, O = Resolve("RoundLoadingScreen", ModeKey)
	return {
		FadeInDuration     = O.FadeInDuration     or D.FadeInDuration     or 1.0,
		HoldDuration       = O.HoldDuration       or D.HoldDuration       or 1.0,
		FadeOutDuration    = O.FadeOutDuration    or D.FadeOutDuration    or 0.5,
		FadeInEasingStyle  = O.FadeInEasingStyle  or D.FadeInEasingStyle  or Enum.EasingStyle.Quad,
		FadeInEasingDir    = O.FadeInEasingDir    or D.FadeInEasingDir    or Enum.EasingDirection.Out,
		FadeOutEasingStyle = O.FadeOutEasingStyle or D.FadeOutEasingStyle or Enum.EasingStyle.Quad,
		FadeOutEasingDir   = O.FadeOutEasingDir   or D.FadeOutEasingDir   or Enum.EasingDirection.In,
	}
end

--- Lấy cấu hình Animation Accolades (kết hợp Default và Overrides theo AccoladeType)
--- @param AccoladeType string? -- "FirstBlood" | ...
--- @return table
function GuiAnimConfig.GetAccoladesAnimConfig(AccoladeType)
	local D, O = Resolve("Accolades", AccoladeType)
	return {
		OpenDuration     = O.OpenDuration     or D.OpenDuration     or 0.25,
		CloseDuration    = O.CloseDuration    or D.CloseDuration    or 0.2,
		DisplayDuration  = O.DisplayDuration  or D.DisplayDuration  or 1.5,
		OpenEasingStyle  = O.OpenEasingStyle  or D.OpenEasingStyle  or Enum.EasingStyle.Back,
		OpenEasingDir    = O.OpenEasingDir    or D.OpenEasingDir    or Enum.EasingDirection.Out,
		CloseEasingStyle = O.CloseEasingStyle or D.CloseEasingStyle or Enum.EasingStyle.Quad,
		CloseEasingDir   = O.CloseEasingDir   or D.CloseEasingDir   or Enum.EasingDirection.In,
		InitialScale     = O.InitialScale     or D.InitialScale     or 0,
		TargetScale      = O.TargetScale      or D.TargetScale      or 1,
	}
end

--- Lấy cấu hình Animation GameLoadingScreen (kết hợp Default và Overrides theo VariantKey)
--- @param VariantKey string? -- Key cho Overrides nếu cần tùy chỉnh theo biến thể
--- @return table
function GuiAnimConfig.GetGameLoadingAnimConfig(VariantKey)
	local D, O = Resolve("GameLoadingScreen", VariantKey)
	return {
		DotWaveDuration     = O.DotWaveDuration     or D.DotWaveDuration     or 1.2,
		DotMinScale         = O.DotMinScale         or D.DotMinScale         or 0.6,
		DotMaxScale         = O.DotMaxScale         or D.DotMaxScale         or 1,
		DotEasingStyle      = O.DotEasingStyle      or D.DotEasingStyle      or Enum.EasingStyle.Sine,
		DotEasingDir        = O.DotEasingDir        or D.DotEasingDir        or Enum.EasingDirection.InOut,
		TitleMinScale       = O.TitleMinScale       or D.TitleMinScale       or 1.0,
		TitleLoadMaxScale   = O.TitleLoadMaxScale   or D.TitleLoadMaxScale   or 1.4,
		TitlePopScale       = O.TitlePopScale       or D.TitlePopScale       or 1.6,
		Phase1PopDuration   = O.Phase1PopDuration   or D.Phase1PopDuration   or 0.35,
		Phase1DotBlinkCount = O.Phase1DotBlinkCount or D.Phase1DotBlinkCount or 2,
		Phase1DotBlinkTime  = O.Phase1DotBlinkTime  or D.Phase1DotBlinkTime  or 0.4,
		Phase2Duration      = O.Phase2Duration      or D.Phase2Duration      or 0.5,
		Phase2EasingStyle   = O.Phase2EasingStyle   or D.Phase2EasingStyle   or Enum.EasingStyle.Quad,
		Phase2EasingDir     = O.Phase2EasingDir     or D.Phase2EasingDir     or Enum.EasingDirection.InOut,
		MinLoadingDuration  = O.MinLoadingDuration  or D.MinLoadingDuration  or 4,
		SafetyTimeout       = O.SafetyTimeout       or D.SafetyTimeout       or 10,
		ProgressLerpSpeed   = O.ProgressLerpSpeed   or D.ProgressLerpSpeed   or 8,
	}
end

--- Lấy cấu hình Animation GameOverAnnouncement (kết hợp Default và Overrides theo VariantKey)
--- @param VariantKey string? -- Key cho Overrides nếu cần tùy chỉnh theo biến thể
--- @return table
function GuiAnimConfig.GetGameOverAnnouncementAnimConfig(VariantKey)
	local D, O = Resolve("GameOverAnnouncement", VariantKey)
	return {
		DisplayDuration       = O.DisplayDuration       or D.DisplayDuration       or 3.2,
		SplitDuration         = O.SplitDuration         or D.SplitDuration         or 0.6,
		FlyInDuration         = O.FlyInDuration         or D.FlyInDuration         or 0.35,
		FlyOutDuration        = O.FlyOutDuration        or D.FlyOutDuration        or 0.25,
		CloseDuration         = O.CloseDuration         or D.CloseDuration         or 0.3,
		FlyInStartPosYScale   = O.FlyInStartPosYScale   or D.FlyInStartPosYScale   or 2.0,
		FlyOutTargetPosYScale = O.FlyOutTargetPosYScale or D.FlyOutTargetPosYScale or -1.0,
		SplitEasingStyle      = O.SplitEasingStyle      or D.SplitEasingStyle      or Enum.EasingStyle.Back,
		SplitEasingDir        = O.SplitEasingDir        or D.SplitEasingDir        or Enum.EasingDirection.Out,
		FlyInEasingStyle      = O.FlyInEasingStyle      or D.FlyInEasingStyle      or Enum.EasingStyle.Back,
		FlyInEasingDir        = O.FlyInEasingDir        or D.FlyInEasingDir        or Enum.EasingDirection.Out,
		FlyOutEasingStyle     = O.FlyOutEasingStyle     or D.FlyOutEasingStyle     or Enum.EasingStyle.Quad,
		FlyOutEasingDir       = O.FlyOutEasingDir       or D.FlyOutEasingDir       or Enum.EasingDirection.In,
		CloseEasingStyle      = O.CloseEasingStyle      or D.CloseEasingStyle      or Enum.EasingStyle.Quad,
		CloseEasingDir        = O.CloseEasingDir        or D.CloseEasingDir        or Enum.EasingDirection.In,
	}
end

--- Lấy cấu hình hoạt ảnh cho Hotbar (kết hợp Default và Overrides)
--- @param SlotName string? -- Định danh slot tùy chọn nếu cần override riêng
--- @return table
function GuiAnimConfig.GetHotbarConfig(SlotName)
	local D, O = Resolve("Hotbar", SlotName)
	return {
		InactiveScale           = O.InactiveScale           or D.InactiveScale           or 1.0,
		ActiveScale             = O.ActiveScale             or D.ActiveScale             or 1.3,
		ScaleDuration           = O.ScaleDuration           or D.ScaleDuration           or 0.15,
		ScaleEasingStyle        = O.ScaleEasingStyle        or D.ScaleEasingStyle        or Enum.EasingStyle.Back,
		ScaleEasingDir          = O.ScaleEasingDir          or D.ScaleEasingDir          or Enum.EasingDirection.Out,
		InactiveBackgroundTrans = O.InactiveBackgroundTrans or D.InactiveBackgroundTrans or 0.8,
		ActiveBackgroundTrans   = O.ActiveBackgroundTrans   or D.ActiveBackgroundTrans   or 0.4,
		CooldownEasingStyle     = O.CooldownEasingStyle     or D.CooldownEasingStyle     or Enum.EasingStyle.Linear,
		CooldownEasingDir       = O.CooldownEasingDir       or D.CooldownEasingDir       or Enum.EasingDirection.InOut,
	}
end

--- Lấy cấu hình Animation FrozenStateAnnouncement (kết hợp Default và Overrides)
--- @param OverrideKey string?
--- @return table
function GuiAnimConfig.GetFrozenStateAnnouncementAnimConfig(OverrideKey)
	local D, O = Resolve("FrozenStateAnnouncement", OverrideKey)
	return {
		OpenDuration     = O.OpenDuration     or D.OpenDuration     or 0.25,
		CloseDuration    = O.CloseDuration    or D.CloseDuration    or 0.2,
		DisplayDuration  = O.DisplayDuration  or D.DisplayDuration  or 1.5,
		OpenEasingStyle  = O.OpenEasingStyle  or D.OpenEasingStyle  or Enum.EasingStyle.Back,
		OpenEasingDir    = O.OpenEasingDir    or D.OpenEasingDir    or Enum.EasingDirection.Out,
		CloseEasingStyle = O.CloseEasingStyle or D.CloseEasingStyle or Enum.EasingStyle.Quad,
		CloseEasingDir   = O.CloseEasingDir   or D.CloseEasingDir   or Enum.EasingDirection.In,
		InitialScale     = O.InitialScale     or D.InitialScale     or 0,
		TargetScale      = O.TargetScale      or D.TargetScale      or 1,
	}
end

--- Lấy cấu hình Animation và màu sắc cho Setting Toggle (kết hợp Default và Overrides)
--- @param OverrideKey string?
--- @return table
function GuiAnimConfig.GetSettingAnimConfig(OverrideKey)
	local D, O = Resolve("Setting", OverrideKey)
	return {
		ActiveBackgroundColor   = O.ActiveBackgroundColor   or D.ActiveBackgroundColor   or Color3.fromHex("FFFFFF"),
		ActiveTextColor         = O.ActiveTextColor         or D.ActiveTextColor         or Color3.fromHex("000000"),
		InactiveBackgroundColor = O.InactiveBackgroundColor or D.InactiveBackgroundColor or Color3.fromHex("B6B6B6"),
		InactiveTextColor       = O.InactiveTextColor       or D.InactiveTextColor       or Color3.fromHex("747474"),
		Duration                = O.Duration                or D.Duration                or 0.15,
		EasingStyle             = O.EasingStyle             or D.EasingStyle             or Enum.EasingStyle.Quad,
		EasingDir               = O.EasingDir               or D.EasingDir               or Enum.EasingDirection.Out,
	}
end

--- Lấy cấu hình Animation cho Slider (kết hợp Default và Overrides)
--- @param OverrideKey string?
--- @return table
function GuiAnimConfig.GetSliderAnimConfig(OverrideKey)
	local D, O = Resolve("Slider", OverrideKey)
	return {
		StepCount   = O.StepCount   or D.StepCount   or 10,
		TickCount   = O.TickCount   or D.TickCount   or 11,
		Duration    = O.Duration    or D.Duration    or 0.08,
		EasingStyle = O.EasingStyle or D.EasingStyle or Enum.EasingStyle.Quad,
		EasingDir   = O.EasingDir   or D.EasingDir   or Enum.EasingDirection.Out,
	}
end

return GuiAnimConfig
