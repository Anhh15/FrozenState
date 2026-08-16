local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- SESSION STATE
-- =========================================================

local _playerStates   = {}  -- { [Player] = "Normal" | "Frozen" | "Dead" }
local _teamAssignment = {}  -- { [Player] = "Team1" | "Team2" | nil }
local _sessionStats   = {}  -- { [Player] = { Freezes, Thaws, ... } }
local _freezeStreaks  = {}  -- { [Player] = number } freeze liên tiếp chưa bị đóng băng
local _thawStreaks    = {}  -- { [Player] = number } thaw liên tiếp

local _isMatchActive  = false
local _isFrozenState  = false
local _currentModeKey = "Normal"  -- key của GameModeConfig hiện tại

-- BindableEvent: fires khi một đội bị đóng băng toàn bộ
-- Payload: winTeam (string "Team1" | "Team2")
local MatchEndSignal = Instance.new("BindableEvent")

-- =========================================================
-- PRIVATE
-- =========================================================

local function InitPlayerSession(Player)
	_playerStates[Player]   = "Dead"
	_teamAssignment[Player] = nil
	_freezeStreaks[Player]  = 0
	_thawStreaks[Player]    = 0
	_sessionStats[Player]   = {
		Freezes        = 0,
		Thaws          = 0,
		FreezingSprees = 0,
		ThawingSprees  = 0,
		FirstBlood     = false,
		LastStanding   = false,
		MoneyEarned    = 0,
	}
	-- Xóa Attribute team và InMatch để client biết player này là Spectator
	PlayerStateHelper.SetTeam(Player, nil)
	PlayerStateHelper.SetInMatch(Player, false)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local SessionService = {}

--- BindableEvent: fires khi team bị wipe, arg = winTeam
SessionService.MatchEndSignal = MatchEndSignal

-- ── Match State ──────────────────────────────────────────

function SessionService.IsMatchActive()
	return _isMatchActive
end

function SessionService.SetMatchActive(Active)
	_isMatchActive = Active
end

function SessionService.GetFrozenState()
	return _isFrozenState
end

function SessionService.SetFrozenState(Active)
	_isFrozenState = Active
end

-- ── GameMode ───────────────────────────────────────────────────────────────

--- Lấy key của GameMode đang chạy
--- @return string -- "Normal" | "Chaos" | ...
function SessionService.GetCurrentModeKey()
	return _currentModeKey
end

--- Đặt GameMode cho trận hiện tại
--- Được gọi bởi MatchService trong RunSetup trước khi trận bắt đầu
--- @param Key string
function SessionService.SetCurrentModeKey(Key)
	_currentModeKey = Key
end

-- ── Player State ─────────────────────────────────────────

--- @param Player Player
--- @return "Normal" | "Frozen" | "Dead"
function SessionService.GetState(Player)
	return _playerStates[Player] or "Dead"
end

--- @param Player Player
--- @param State "Normal" | "Frozen" | "Dead"
function SessionService.SetState(Player, State)
	_playerStates[Player] = State
end

-- ── Team ─────────────────────────────────────────────────

--- @param Player Player
--- @param Player Player
--- @return "Team1" | "Team2" | nil
function SessionService.GetTeam(Player)
	return _teamAssignment[Player]
end

--- Xóa phân đội của player và gỡ attribute Team
--- @param Player Player
function SessionService.ClearTeam(Player)
	_teamAssignment[Player] = nil
	PlayerStateHelper.SetTeam(Player, nil)
end

--- Chia đội ngẫu nhiên, lệch tối đa 1 người
--- @param PlayerList table -- list of Player objects
--- @return table { Team1 = {}, Team2 = {} }
function SessionService.AssignTeams(PlayerList)
	-- Fisher-Yates shuffle
	local Shuffled = {}
	for _, p in ipairs(PlayerList) do
		table.insert(Shuffled, p)
	end
	for i = #Shuffled, 2, -1 do
		local j = math.random(1, i)
		Shuffled[i], Shuffled[j] = Shuffled[j], Shuffled[i]
	end

	local Team1, Team2 = {}, {}
	local Half = math.ceil(#Shuffled / 2)

	for i, Player in ipairs(Shuffled) do
		if i <= Half then
			_teamAssignment[Player] = "Team1"
			PlayerStateHelper.SetTeam(Player, "Team1")
			table.insert(Team1, Player)
		else
			_teamAssignment[Player] = "Team2"
			PlayerStateHelper.SetTeam(Player, "Team2")
			table.insert(Team2, Player)
		end
	end

	return { Team1 = Team1, Team2 = Team2 }
end

--- Lấy danh sách players thuộc team (chỉ những người còn online)
--- @param TeamName "Team1" | "Team2"
--- @return table
function SessionService.GetTeamPlayers(TeamName)
	local Result = {}
	for Player, Team in pairs(_teamAssignment) do
		if Team == TeamName and Player:IsDescendantOf(Players) then
			table.insert(Result, Player)
		end
	end
	return Result
end

--- Kiểm tra một team đã bị đóng băng hoặc bị loại hết chưa
--- (Dead và Frozen đều tính là "không còn Normal")
--- @param TeamName "Team1" | "Team2"
--- @return boolean
function SessionService.IsTeamWiped(TeamName)
	local TeamPlayers = SessionService.GetTeamPlayers(TeamName)
	if #TeamPlayers == 0 then return true end

	for _, Player in ipairs(TeamPlayers) do
		if _playerStates[Player] == "Normal" then
			return false
		end
	end
	return true
end

--- Lấy danh sách tất cả player đang Normal (còn online)
--- Dùng cho Spectate system broadcast
--- @return table -- list of Player objects
function SessionService.GetAllNormalPlayers()
	local Result = {}
	for Player, State in pairs(_playerStates) do
		if State == "Normal" and Player:IsDescendantOf(Players) then
			table.insert(Result, Player)
		end
	end
	return Result
end

-- ── Stats ────────────────────────────────────────────────

function SessionService.GetStats(Player)
	return _sessionStats[Player]
end

--- @param StatName "Freezes"|"Thaws"|"FreezingSprees"|"ThawingSprees"|"MoneyEarned"
function SessionService.IncrementStat(Player, StatName, Amount)
	Amount = Amount or 1
	local Stats = _sessionStats[Player]
	if Stats and type(Stats[StatName]) == "number" then
		Stats[StatName] = Stats[StatName] + Amount
	end
end

function SessionService.SetStat(Player, StatName, Value)
	local Stats = _sessionStats[Player]
	if Stats then
		Stats[StatName] = Value
	end
end

-- ── Streaks ──────────────────────────────────────────────

function SessionService.GetFreezeStreak(Player)
	return _freezeStreaks[Player] or 0
end

function SessionService.IncrementFreezeStreak(Player)
	_freezeStreaks[Player] = (_freezeStreaks[Player] or 0) + 1
end

function SessionService.ResetFreezeStreak(Player)
	_freezeStreaks[Player] = 0
end

function SessionService.GetThawStreak(Player)
	return _thawStreaks[Player] or 0
end

function SessionService.IncrementThawStreak(Player)
	_thawStreaks[Player] = (_thawStreaks[Player] or 0) + 1
end

function SessionService.ResetThawStreak(Player)
	_thawStreaks[Player] = 0
end

-- ── Reset ────────────────────────────────────────────────

--- Xóa sạch dữ liệu session, giữ nguyên danh sách player
function SessionService.ResetSession()
	for Player in pairs(_playerStates) do
		InitPlayerSession(Player)
	end
	_isMatchActive  = false
	_isFrozenState  = false
	_currentModeKey = "Normal"
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function SessionService:Init()
	-- Khởi tạo cho players đang có mặt
	for _, Player in ipairs(Players:GetPlayers()) do
		InitPlayerSession(Player)
	end

	Players.PlayerAdded:Connect(function(Player)
		InitPlayerSession(Player)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		-- Nếu thoát giữa trận: loại khỏi trận (Dead) → trigger win condition nếu làm team bị wipe / FFA kết thúc
		if _isMatchActive then
			local Team = _teamAssignment[Player]
			_playerStates[Player] = "Dead"

			-- Broadcast state mới để tất cả client (ScoreBoard/HUD) cập nhật biểu tượng FrozenStatus
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
			local UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
			if UpdatePlayerStateEvent then
				local Stats = _sessionStats[Player] or {}
				UpdatePlayerStateEvent:FireAllClients({
					PlayerId = Player.UserId,
					State    = "Dead",
					Freezes  = Stats.Freezes or 0,
					Thaws    = Stats.Thaws   or 0,
				})
			end

			SessionService.ClearTeam(Player)
			PlayerStateHelper.SetInMatch(Player, false)

			if Team and SessionService.IsTeamWiped(Team) then
				local WinTeam = (Team == "Team1") and "Team2" or "Team1"
				MatchEndSignal:Fire({ WinTeam = WinTeam })
			elseif not Team then
				-- FFA: kiểm tra xem chỉ còn 1 hoặc 0 người Normal không
				local NormalPlayers = SessionService.GetAllNormalPlayers()
				if #NormalPlayers == 1 then
					MatchEndSignal:Fire({ WinPlayer = NormalPlayers[1] })
				elseif #NormalPlayers == 0 then
					MatchEndSignal:Fire({ WinPlayer = nil })
				end
			end
		end

		-- Xóa Attribute team và InMatch trước khi dọn entry
		PlayerStateHelper.SetTeam(Player, nil)
		PlayerStateHelper.SetInMatch(Player, false)

		-- Dọn dẹp entry
		_playerStates[Player]   = nil
		_teamAssignment[Player] = nil
		_sessionStats[Player]   = nil
		_freezeStreaks[Player]  = nil
		_thawStreaks[Player]    = nil
	end)

	print("[SessionService] Đã khởi tạo.")
end

function SessionService:Start()
	print("[SessionService] Đang chạy.")
end

return SessionService
