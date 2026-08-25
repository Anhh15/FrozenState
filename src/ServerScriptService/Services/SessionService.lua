local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)
local GameModeHelper    = require(ReplicatedStorage.Shared.Tools.GameModeHelper)

-- =========================================================
-- SESSION STATE
-- =========================================================

local _playerStates   = {}  -- { [Player] = "Normal" | "Frozen" | "Dead" }
local _teamAssignment = {}  -- { [Player] = "Team1" | "Team2" | nil }
local _sessionStats   = {}  -- { [Player] = { Freezes, Thaws, ... } }
local _freezeStreaks  = {}  -- { [Player] = number } freeze liên tiếp chưa bị đóng băng
local _thawStreaks    = {}  -- { [Player] = number } thaw liên tiếp
local _participants   = {}  -- { [Player] = true } danh sách người chơi thực sự tham gia trận đấu
local _teamScores     = { Team1 = 0, Team2 = 0 }  -- { Team1 = number, Team2 = number } tổng điểm Freeze + Thaw theo đội

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
	_participants[Player]   = nil
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

--- Đếm số lượng người chơi đang Normal trong team
--- @param TeamName "Team1" | "Team2"
--- @return number
function SessionService.GetAliveCount(TeamName)
	local Count = 0
	for _, Player in ipairs(SessionService.GetTeamPlayers(TeamName)) do
		if _playerStates[Player] == "Normal" then
			Count = Count + 1
		end
	end
	return Count
end

--- Lấy tổng điểm Freeze + Thaw của một team trong ván hiện tại (bảo toàn kể cả khi người chơi rớt mạng)
--- @param TeamName "Team1" | "Team2"
--- @return number
function SessionService.GetTeamTotalScore(TeamName)
	return _teamScores[TeamName] or 0
end

-- ── Participants ─────────────────────────────────────────

--- Đánh dấu người chơi có tham gia thi đấu trong ván hiện tại
--- @param Player Player
--- @param IsParticipant boolean
function SessionService.SetParticipant(Player, IsParticipant)
	if IsParticipant then
		_participants[Player] = true
	else
		_participants[Player] = nil
	end
end

--- Kiểm tra người chơi có phải là người tham gia ván đấu hiện tại không
--- @param Player Player
--- @return boolean
function SessionService.IsParticipant(Player)
	return _participants[Player] == true
end

--- Lấy danh sách tất cả players thực sự tham gia ván đấu (và còn online)
--- @return table -- list of Player objects
function SessionService.GetParticipants()
	local Result = {}
	for Player, IsPart in pairs(_participants) do
		if IsPart and Player:IsDescendantOf(Players) then
			table.insert(Result, Player)
		end
	end
	return Result
end

--- Lấy người chơi có số lần Freeze cao nhất trong FFA (nếu bằng điểm thì random 1 người trong nhóm đầu)
--- @param CandidatePool table? -- danh sách ứng viên tùy chọn (mặc định lấy toàn bộ GetParticipants)
--- @return Player?
function SessionService.GetTopScorerFFA(CandidatePool)
	local Participants = CandidatePool or SessionService.GetParticipants()
	if #Participants == 0 then
		return nil
	end

	local function GetScore(P)
		local Stats = _sessionStats[P] or {}
		return Stats.Freezes or 0
	end

	table.sort(Participants, function(A, B)
		return GetScore(A) > GetScore(B)
	end)

	local TopScore = GetScore(Participants[1])
	local Tied = {}
	for _, P in ipairs(Participants) do
		if GetScore(P) == TopScore then
			table.insert(Tied, P)
		end
	end

	if #Tied == 1 then
		return Tied[1]
	end

	return Tied[math.random(1, #Tied)]
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

	-- Cộng dồn điểm vào đội tương ứng nếu là Freeze hoặc Thaw
	if StatName == "Freezes" or StatName == "Thaws" then
		local Team = _teamAssignment[Player]
		if Team and _teamScores[Team] ~= nil then
			_teamScores[Team] = _teamScores[Team] + Amount
		end
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

-- ── Win Condition ────────────────────────────────────────

--- Kiểm tra điều kiện kết thúc trận đấu và phát MatchEndSignal nếu thỏa mãn
function SessionService.CheckWinCondition()
	if not _isMatchActive then return end

	local WinCondition = GameModeHelper.GetWinCondition(_currentModeKey)

	if WinCondition == "TeamBased" then
		local Team1Wiped = SessionService.IsTeamWiped("Team1")
		local Team2Wiped = SessionService.IsTeamWiped("Team2")

		if Team1Wiped and Team2Wiped then
			-- Cả 2 team đều wipe -> so tổng điểm Freeze + Thaw (bảo toàn điểm dù có người out), nếu bằng nhau thì random 50/50
			local Score1 = SessionService.GetTeamTotalScore("Team1")
			local Score2 = SessionService.GetTeamTotalScore("Team2")
			local WinTeam
			if Score1 > Score2 then
				WinTeam = "Team1"
			elseif Score2 > Score1 then
				WinTeam = "Team2"
			else
				WinTeam = (math.random() < 0.5) and "Team1" or "Team2"
			end
			MatchEndSignal:Fire({ WinTeam = WinTeam })
		elseif Team1Wiped then
			MatchEndSignal:Fire({ WinTeam = "Team2" })
		elseif Team2Wiped then
			MatchEndSignal:Fire({ WinTeam = "Team1" })
		end

	elseif WinCondition == "FFA" then
		local NormalPlayers = SessionService.GetAllNormalPlayers()
		if #NormalPlayers == 1 then
			-- Chỉ còn 1 người Normal → đó là người thắng
			MatchEndSignal:Fire({ WinPlayer = NormalPlayers[1] })
		elseif #NormalPlayers == 0 then
			-- Cả 2 người cuối cùng bị loại đồng thời → chọn người có Freeze cao nhất (hoặc random nếu bằng)
			local WinPlayer = SessionService.GetTopScorerFFA()
			if WinPlayer then
				MatchEndSignal:Fire({ WinPlayer = WinPlayer })
			end
		end
	end
end

-- ── Reset ────────────────────────────────────────────────

--- Xóa sạch dữ liệu session, giữ nguyên danh sách player
function SessionService.ResetSession()
	_participants = {}
	_teamScores   = { Team1 = 0, Team2 = 0 }
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

			-- Kiểm tra điều kiện thắng TRƯỚC KHI xóa Team để bảo toàn dữ liệu phân đội
			SessionService.CheckWinCondition()

			SessionService.ClearTeam(Player)
			PlayerStateHelper.SetInMatch(Player, false)
		end

		-- Xóa Attribute team và InMatch trước khi dọn entry
		PlayerStateHelper.SetTeam(Player, nil)
		PlayerStateHelper.SetInMatch(Player, false)

		-- Dọn dẹp entry
		_participants[Player]   = nil
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
