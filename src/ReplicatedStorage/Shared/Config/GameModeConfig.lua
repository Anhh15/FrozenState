-- GameModeConfig.lua
-- Config trung tâm cho từng chế độ chơi
-- Mỗi mode là một entry độc lập với đầy đủ tham số
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được
-- Không hardcode mode logic ở nơi khác — chỉ đọc từ đây

-- =========================================================
-- ĐỊNH NGHĨA CÁC GIÁ TRỊ THAM SỐ
-- =========================================================

-- HighlightMode:
--   "TeamBased" = highlight đỏ/xanh theo team, AlwaysOnTop chỉ khi FrozenState
--   "FFA"       = tất cả highlight đỏ AlwaysOnTop liên tục, bản thân bỏ qua
--   "Disabled"  = không tạo highlight, không cho phép tương tác

-- ScoreboardType:
--   "TwoTeams"  = 2 cột Ally/Enemy
--   "Disabled"  = không hiển thị, không toggle được

-- PlayerStatusType:
--   "TwoTeams"  = hiển thị avatar theo panel team
--   "Disabled"  = không hiển thị

-- SpawnType:
--   "TeamBased" = [map]/SpawnPoint/TeamBase/T1SpawnPoint[1-8] & T2SpawnPoint[1-8]
--   "FFA"       = [map]/SpawnPoint/FFA/SpawnPoint[1-16]

-- WinCondition:
--   "TeamBased" = đội đối phương bị wipe → thắng; hết giờ → so số người → so score (Freeze+Thaw) → random
--   "FFA"       = last man standing → so Freeze count → random

-- =========================================================
-- MODE CONFIGS
-- =========================================================

local Modes = {

	Normal = {
		DisplayName          = "Normal Mode",
		Description          = "",
		IsSpecialRound       = false,

		-- Cơ chế
		HasTeams             = true,
		AllowThaw            = true,
		AllowFrozenState     = true,
		AllowLastStanding    = true,

		-- UI
		HighlightMode        = "TeamBased",
		ScoreboardType       = "TwoTeams",
		PlayerStatusType     = "TwoTeams",

		-- Map & Spawn
		SpawnType            = "TeamBased",

		-- Win condition
		WinCondition         = "TeamBased",

		-- Thời gian
		InGameDuration       = 49,
		FrozenStateThreshold = 45,   -- chỉ dùng khi AllowFrozenState = true
	},

	Chaos = {
		DisplayName          = "Chaos",
		Description          = "No team, only you. Win by defeat them all",
		IsSpecialRound       = true,

		HasTeams             = false,
		AllowThaw            = false,
		AllowFrozenState     = false,
		AllowLastStanding    = true,

		HighlightMode        = "FFA",
		ScoreboardType       = "Disabled",
		PlayerStatusType     = "Disabled",

		SpawnType            = "FFA",
		WinCondition         = "FFA",

		InGameDuration       = 180,
		FrozenStateThreshold = 45,   -- ignored khi AllowFrozenState = false
	},

	EternalFreeze = {
		DisplayName          = "Eternal Freeze",
		Description          = "Thaw is no longer a way to escape",
		IsSpecialRound       = true,

		HasTeams             = true,
		AllowThaw            = false,
		AllowFrozenState     = true,
		AllowLastStanding    = true,

		HighlightMode        = "TeamBased",
		ScoreboardType       = "TwoTeams",
		PlayerStatusType     = "TwoTeams",

		SpawnType            = "TeamBased",
		WinCondition         = "TeamBased",

		InGameDuration       = 180,
		FrozenStateThreshold = 45,
	},

}

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameModeConfig = {}

--- Lấy config của một mode theo key
--- Fallback về Normal nếu key không hợp lệ
--- @param Key string -- "Normal" | "Chaos" | "EternalFreeze"
--- @return table
function GameModeConfig.GetMode(Key)
	return Modes[Key] or Modes["Normal"]
end

--- Lấy danh sách key của tất cả Special modes (IsSpecialRound = true)
--- Dùng cho MatchService khi chọn Special round
--- @return table -- { "Chaos", "EternalFreeze", ... }
function GameModeConfig.GetSpecialModeKeys()
	local Result = {}
	for Key, Config in pairs(Modes) do
		if Config.IsSpecialRound then
			table.insert(Result, Key)
		end
	end
	return Result
end

return GameModeConfig
