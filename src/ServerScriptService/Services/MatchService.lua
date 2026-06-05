-- MatchService.lua
-- Điều phối vòng lặp trận đấu
-- State machine: Intermission → Setup → Ready → InGame → GameOver → (lặp lại)
-- Sub-state FrozenState nằm bên trong InGame khi còn ≤ FrozenStateThreshold giây

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionService    = require(script.Parent.SessionService)
local TeamService       = require(script.Parent.TeamService)
local MapService        = require(script.Parent.MapService)
local FreezeService     = require(script.Parent.FreezeService)
local IcicleService     = require(script.Parent.IcicleService)
local DataService       = require(script.Parent.DataService)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)

-- =========================================================
-- HẰNG SỐ
-- =========================================================

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

-- =========================================================
-- STATE
-- =========================================================

local _currentPhase = "Intermission"
local _earlyWinner  = nil  -- set khi FreezeService trigger MatchEndSignal

local UpdateGameStateEvent
local ShowGameOverEvent

-- =========================================================
-- PRIVATE: Helpers
-- =========================================================

local function BroadcastGameState(Phase, TimeRemaining, IsFrozenState)
	UpdateGameStateEvent:FireAllClients({
		Phase         = Phase,
		TimeRemaining = TimeRemaining,
		IsFrozenState = IsFrozenState or false,
	})
end

--- Teleport player đến một trong các spawn point của team
local function TeleportToSpawn(Player, SpawnPoints)
	if #SpawnPoints == 0 then return end
	local Character = Player.Character
	if not Character then return end
	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	local Spawn = SpawnPoints[math.random(1, #SpawnPoints)]
	HRP.CFrame  = Spawn.CFrame + Vector3.new(0, 4, 0)
end

--- Khóa / mở khóa di chuyển
local function SetMovementLocked(Player, Locked)
	local Character = Player.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	Humanoid.WalkSpeed = Locked and 0 or DEFAULT_WALK_SPEED
	Humanoid.JumpPower = Locked and 0 or DEFAULT_JUMP_POWER
end

--- Xác định đội thắng khi hết giờ (không ai bị wipe)
local function ResolveWinner()
	local function CountAlive(TeamName)
		local Count = 0
		for _, P in ipairs(SessionService.GetTeamPlayers(TeamName)) do
			if SessionService.GetState(P) == "Normal" then
				Count = Count + 1
			end
		end
		return Count
	end

	local Team1Players = SessionService.GetTeamPlayers("Team1")
	local Team2Players = SessionService.GetTeamPlayers("Team2")
	local Alive1 = CountAlive("Team1")
	local Alive2 = CountAlive("Team2")

	-- Bù số lượng nếu đội nhỏ hơn (đội ít người được cộng 1 survivor để công bằng)
	if #Team1Players < #Team2Players then
		Alive1 = Alive1 + 1
	elseif #Team2Players < #Team1Players then
		Alive2 = Alive2 + 1
	end

	if Alive1 > Alive2 then return "Team1" end
	if Alive2 > Alive1 then return "Team2" end

	-- Hòa: so sánh tổng Freeze + Thaw
	local function TotalScore(TeamName)
		local Score = 0
		for _, P in ipairs(SessionService.GetTeamPlayers(TeamName)) do
			local Stats = SessionService.GetStats(P) or {}
			Score = Score + (Stats.Freezes or 0) + (Stats.Thaws or 0)
		end
		return Score
	end

	local Score1 = TotalScore("Team1")
	local Score2 = TotalScore("Team2")

	if Score1 > Score2 then return "Team1" end
	if Score2 > Score1 then return "Team2" end

	-- Vẫn hòa: random (không có draw)
	return math.random() < 0.5 and "Team1" or "Team2"
end

--- Tính top N player của đội thắng theo Freeze + Thaw
local function GetTopPlayers(WinTeam, MaxCount)
	local WinPlayers = SessionService.GetTeamPlayers(WinTeam)

	table.sort(WinPlayers, function(A, B)
		local SA = SessionService.GetStats(A) or {}
		local SB = SessionService.GetStats(B) or {}
		return ((SA.Freezes or 0) + (SA.Thaws or 0)) > ((SB.Freezes or 0) + (SB.Thaws or 0))
	end)

	local Result = {}
	for i = 1, math.min(MaxCount, #WinPlayers) do
		local P     = WinPlayers[i]
		local Stats = SessionService.GetStats(P) or {}
		table.insert(Result, {
			Name    = P.DisplayName,
			Freezes = Stats.Freezes or 0,
			Thaws   = Stats.Thaws   or 0,
		})
	end
	return Result
end

--- Phát phần thưởng Win/Lose + LastStanding
local function DistributeRewards(WinTeam)
	-- Tìm Last Standing: người cuối còn Normal trong đội thắng
	local WinPlayers  = SessionService.GetTeamPlayers(WinTeam)
	local NormalCount = 0
	local LastAlive   = nil

	for _, P in ipairs(WinPlayers) do
		if SessionService.GetState(P) == "Normal" then
			NormalCount = NormalCount + 1
			LastAlive   = P
		end
	end

	if NormalCount == 1 and LastAlive then
		SessionService.SetStat(LastAlive, "LastStanding", true)
		DataService.IncrementStat(LastAlive, "TotalLastStanding")
		DataService.AddMoney(LastAlive, GameConfig.Economy.RewardLastStanding)
		SessionService.IncrementStat(LastAlive, "MoneyEarned", GameConfig.Economy.RewardLastStanding)
	end

	-- Thưởng Win / Lose cho tất cả player trong trận
	for _, Player in ipairs(Players:GetPlayers()) do
		local Team = SessionService.GetTeam(Player)
		if not Team then continue end

		local Reward = (Team == WinTeam)
			and GameConfig.Economy.RewardWin
			or  GameConfig.Economy.RewardLose

		DataService.AddMoney(Player, Reward)
		SessionService.IncrementStat(Player, "MoneyEarned", Reward)

		-- Sync tiền về client
		local Data = DataService.GetData(Player)
		if Data then
			RemoteDefinitions.GetEvent("UpdateMoney"):FireClient(Player, Data.Money)
		end
	end
end

--- Gửi GameStatistic data về từng client
local function BroadcastGameOver(WinTeam)
	local TopPlayers = GetTopPlayers(WinTeam, 3)

	for _, Player in ipairs(Players:GetPlayers()) do
		local PlayerTeam = SessionService.GetTeam(Player)
		local Stats      = SessionService.GetStats(Player) or {}
		local Won        = (PlayerTeam == WinTeam)

		ShowGameOverEvent:FireClient(Player, {
			WinTeam    = WinTeam,
			Won        = Won,
			TopPlayers = TopPlayers,
			PersonalStats = {
				Freezes        = Stats.Freezes        or 0,
				Thaws          = Stats.Thaws          or 0,
				FreezingSprees = Stats.FreezingSprees or 0,
				ThawingSprees  = Stats.ThawingSprees  or 0,
				FirstBlood     = Stats.FirstBlood     or false,
				LastStanding   = Stats.LastStanding   or false,
				MoneyEarned    = Stats.MoneyEarned    or 0,
			},
		})
	end
end

-- =========================================================
-- PHASE FUNCTIONS
-- =========================================================

--- Intermission: 20 giây, reset về full nếu không đủ người
local function RunIntermission()
	_currentPhase     = "Intermission"
	local Duration    = GameConfig.Phase.IntermissionDuration
	local TimeLeft    = Duration

	while TimeLeft > 0 do
		local PlayerCount = #Players:GetPlayers()

		if PlayerCount < GameConfig.Match.MinPlayers then
			-- Không đủ người: giữ thời gian tối đa, không đếm ngược
			TimeLeft = Duration
			BroadcastGameState("Intermission", Duration, false)
		else
			BroadcastGameState("Intermission", TimeLeft, false)
			TimeLeft = TimeLeft - 1
		end

		task.wait(1)
	end
end

--- Setup: không có timer, ẩn khỏi client (vẫn broadcast Intermission)
local function RunSetup()
	_currentPhase = "Setup"
	BroadcastGameState("Intermission", 0, false)

	-- Reset session và flag
	SessionService.ResetSession()
	FreezeService.ResetRound()

	-- Load map ngẫu nhiên
	MapService.LoadRandomMap()

	-- Phân đội và đặt state Normal
	local ActivePlayers = Players:GetPlayers()
	SessionService.AssignTeams(ActivePlayers)

	for _, Player in ipairs(ActivePlayers) do
		SessionService.SetState(Player, "Normal")
	end

	-- Broadcast team xuống client để HighlightController cập nhật
	TeamService.BroadcastTeamAssignment()

	SessionService.SetMatchActive(true)

	task.wait(0.5)  -- buffer nhỏ để map load xong
end

--- Ready: 3 giây, teleport + khóa di chuyển + cấp tool
local function RunReady()
	_currentPhase = "Ready"
	local Duration = GameConfig.Phase.ReadyDuration

	local Team1Spawns = MapService.GetSpawnPoints("Team1")
	local Team2Spawns = MapService.GetSpawnPoints("Team2")

	-- Teleport và khóa di chuyển
	for _, Player in ipairs(Players:GetPlayers()) do
		local Team = SessionService.GetTeam(Player)
		if not Team then continue end

		if Player.Character then
			local Spawns = (Team == "Team1") and Team1Spawns or Team2Spawns
			TeleportToSpawn(Player, Spawns)
		end
		SetMovementLocked(Player, true)
	end

	-- Cấp tool
	IcicleService.GiveToolToAll()

	-- Đếm ngược Ready
	for t = Duration, 0, -1 do
		BroadcastGameState("Ready", t, false)
		if t == 0 then break end
		task.wait(1)
	end

	-- Mở khóa di chuyển cho player đang Normal
	for _, Player in ipairs(Players:GetPlayers()) do
		if SessionService.GetState(Player) == "Normal" then
			SetMovementLocked(Player, false)
		end
	end
end

--- InGame: tối đa InGameDuration giây, có thể kết thúc sớm khi một đội bị wipe
local function RunInGame()
	_currentPhase        = "InGame"
	_earlyWinner         = nil
	local Duration       = GameConfig.Phase.InGameDuration
	local FSTThreshold   = GameConfig.Phase.FrozenStateThreshold
	local FrozenStateOn  = false

	-- Lắng nghe MatchEndSignal (fired bởi SessionService khi team bị wipe)
	local EndConn = SessionService.MatchEndSignal.Event:Connect(function(WinTeam)
		_earlyWinner = WinTeam
	end)

	for t = Duration, 0, -1 do
		-- Thoát sớm nếu có đội bị wipe
		if _earlyWinner then break end

		-- Kích hoạt FrozenState khi còn đúng FSTThreshold giây
		if t <= FSTThreshold and not FrozenStateOn then
			FrozenStateOn = true
			SessionService.SetFrozenState(true)
			TeamService.SetFrozenStateHighlights(true)
			print("[MatchService] ❄ FrozenState đã kích hoạt!")
		end

		BroadcastGameState("InGame", t, FrozenStateOn)
		if t == 0 then break end
		task.wait(1)
	end

	EndConn:Disconnect()

	-- Tắt FrozenState
	if FrozenStateOn then
		SessionService.SetFrozenState(false)
		TeamService.SetFrozenStateHighlights(false)
	end

	return _earlyWinner or ResolveWinner()
end

--- GameOver: đếm ngược, teleport về lobby, dọn dẹp, rồi mới hiện bảng thống kê
local function RunGameOver(WinTeam)
	_currentPhase  = "GameOver"
	local Duration = GameConfig.Phase.GameOverDuration

	-- Thu hồi tool và kết thúc trận
	IcicleService.RemoveToolFromAll()
	SessionService.SetMatchActive(false)

	-- Phát phần thưởng
	DistributeRewards(WinTeam)

	-- Thaw tất cả người bị đóng băng ngay lập tức
	FreezeService.ThawAll()

	-- Đếm ngược để player xem thống kê
	for t = Duration, 0, -1 do
		BroadcastGameState("GameOver", t, false)
		if t == 0 then break end
		task.wait(1)
	end

	-- Teleport tất cả player về SpawnLocation (lobby) sau khi hết giờ
	local LobbySpawn = workspace:FindFirstChild("SpawnLocation")
	for _, Player in ipairs(Players:GetPlayers()) do
		local Character = Player.Character
		if not Character then continue end
		local HRP = Character:FindFirstChild("HumanoidRootPart")
		if HRP and LobbySpawn then
			HRP.CFrame = LobbySpawn.CFrame + Vector3.new(0, 4, 0)
		end
	end

	-- Dọn sạch IceBlock tàn dư còn sót trong Workspace
	for _, Child in ipairs(workspace:GetChildren()) do
		if Child.Name == "IceBlock" then
			Child:Destroy()
		end
	end

	-- Dọn dẹp map
	MapService.UnloadMap()

	-- Gửi thống kê cuối trận xuống client sau khi đã dọn dẹp xong
	-- (player đã về Lobby trước khi thấy bảng thống kê)
	BroadcastGameOver(WinTeam)
end

-- =========================================================
-- GAME LOOP
-- =========================================================

local function GameLoop()
	while true do
		-- Chờ đủ người tối thiểu trước khi bắt đầu vòng
		while #Players:GetPlayers() < GameConfig.Match.MinPlayers do
			BroadcastGameState("Intermission", GameConfig.Phase.IntermissionDuration, false)
			task.wait(1)
		end

		RunIntermission()

		-- Kiểm tra lại sau intermission (player có thể đã thoát)
		if #Players:GetPlayers() < GameConfig.Match.MinPlayers then
			continue
		end

		RunSetup()
		RunReady()
		local WinTeam = RunInGame()
		RunGameOver(WinTeam)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local MatchService = {}

function MatchService.GetCurrentPhase()
	return _currentPhase
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function MatchService:Init()
	UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	ShowGameOverEvent    = RemoteDefinitions.GetEvent("ShowGameOver")
	print("[MatchService] Đã khởi tạo.")
end

function MatchService:Start()
	task.spawn(GameLoop)
	print("[MatchService] Game loop đã bắt đầu.")
end

return MatchService
