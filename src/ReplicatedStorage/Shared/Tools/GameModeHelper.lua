-- GameModeHelper.lua
-- Module tiện ích dùng chung (Shared) cho Client & Server để kiểm tra luật chơi và thuộc tính của GameMode
-- Sử dụng GameModeConfig làm Single Source of Truth

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameModeConfig    = require(ReplicatedStorage.Shared.Config.GameModeConfig)

local GameModeHelper = {}

-- =========================================================
-- GETTERS & QUERIES
-- =========================================================

--- Lấy cấu hình của một mode theo key (hoặc trả về Normal nếu không hợp lệ)
--- @param ModeKey string?
--- @return table
function GameModeHelper.GetMode(ModeKey)
	return GameModeConfig.GetMode(ModeKey or "Normal")
end

--- Lấy tên hiển thị của mode
--- @param ModeKey string?
--- @return string
function GameModeHelper.GetDisplayName(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.DisplayName or "Normal Mode"
end

--- Lấy mô tả chi tiết của mode
--- @param ModeKey string?
--- @return string
function GameModeHelper.GetDescription(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.Description or ""
end

--- Kiểm tra xem mode có phải là Special Round không
--- @param ModeKey string?
--- @return boolean
function GameModeHelper.IsSpecialRound(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.IsSpecialRound == true
end

--- Kiểm tra xem mode có phải là Free For All (không chia đội) không
--- @param ModeKey string?
--- @return boolean
function GameModeHelper.IsFFA(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.HasTeams == false
end

--- Kiểm tra xem mode có phân chia đội (TeamBased) không
--- @param ModeKey string?
--- @return boolean
function GameModeHelper.IsTeamBased(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.HasTeams == true
end

--- Kiểm tra xem mode có cho phép đồng đội giải cứu (Thaw) không
--- @param ModeKey string?
--- @return boolean
function GameModeHelper.CanThaw(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.AllowThaw == true
end

--- Kiểm tra xem mode có kích hoạt phase Frozen State (nhạc và highlight đặc biệt) không
--- @param ModeKey string?
--- @return boolean
function GameModeHelper.HasFrozenState(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.AllowFrozenState == true
end

--- Kiểm tra xem mode có thưởng cho Last Man Standing không
--- @param ModeKey string?
--- @return boolean
function GameModeHelper.AllowLastStanding(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.AllowLastStanding == true
end

--- Lấy kiểu Highlight của mode ("TeamBased" | "FFA" | "Disabled")
--- @param ModeKey string?
--- @return string
function GameModeHelper.GetHighlightMode(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.HighlightMode or "TeamBased"
end

--- Lấy kiểu Scoreboard của mode ("TwoTeams" | "Disabled")
--- @param ModeKey string?
--- @return string
function GameModeHelper.GetScoreboardType(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.ScoreboardType or "TwoTeams"
end

--- Lấy kiểu hiển thị PlayerStatus HUD của mode ("TwoTeams" | "Disabled")
--- @param ModeKey string?
--- @return string
function GameModeHelper.GetPlayerStatusType(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.PlayerStatusType or "TwoTeams"
end

--- Lấy loại Spawn Point yêu cầu ("TeamBased" | "FFA")
--- @param ModeKey string?
--- @return string
function GameModeHelper.GetSpawnType(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.SpawnType or "TeamBased"
end

--- Lấy điều kiện kết thúc / phân thắng bại ("TeamBased" | "FFA")
--- @param ModeKey string?
--- @return string
function GameModeHelper.GetWinCondition(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.WinCondition or "TeamBased"
end

--- Lấy thời lượng thi đấu trong trận (giây)
--- @param ModeKey string?
--- @return number
function GameModeHelper.GetInGameDuration(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.InGameDuration or 180
end

--- Lấy thời điểm ngưỡng bắt đầu FrozenState (giây đếm ngược)
--- @param ModeKey string?
--- @return number
function GameModeHelper.GetFrozenStateThreshold(ModeKey)
	local Mode = GameModeHelper.GetMode(ModeKey)
	return Mode.FrozenStateThreshold or 45
end

return GameModeHelper
