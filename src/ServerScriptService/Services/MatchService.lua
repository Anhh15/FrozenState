-- MatchService.lua
-- Điều phối vòng lặp trận đấu
-- State machine: Intermission → Setup → Ready → InGame → GameOver → (lặp lại)
-- Sub-state FrozenState nằm bên trong InGame khi còn ≤ FrozenStateThreshold giây
-- Chu kỳ mode: 2 vòng Normal → 1 Special round (Chaos, ...) → lặp lại

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
local GameModeConfig    = require(ReplicatedStorage.Shared.Config.GameModeConfig)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiAnimConfig     = require(ReplicatedStorage.Shared.Config.GuiAnimConfig)
local TagConfig         = require(ReplicatedStorage.Shared.Config.TagConfig)
local GameModeHelper    = require(ReplicatedStorage.Shared.Tools.GameModeHelper)
local RewardHelper      = require(ReplicatedStorage.Shared.Tools.RewardHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)
local TagHelper         = require(ReplicatedStorage.Shared.Tools.TagHelper)
local MapHelper         = require(ReplicatedStorage.Shared.Tools.MapHelper)

-- =========================================================
-- STATE
-- =========================================================

local _currentPhase  = "Intermission"
local _earlyResult   = nil   -- { WinTeam = "..." } hoặc { WinPlayer = player } khi kết thúc sớm
local _roundCounter  = 0     -- đếm số vòng đã chơi (dùng cho chu kỳ mode)

local UpdateGameStateEvent
local ShowGameOverEvent
local UpdateSpectateListEvent
local RequestSpectateTargetEvent
local SetGameModeEvent
local UpdatePlayerStateEvent

-- =========================================================
-- PRIVATE: Helpers
-- =========================================================

local function BroadcastGameState(Phase, TimeRemaining, IsFrozenState, WinnerInfo)
	UpdateGameStateEvent:FireAllClients({
		Phase         = Phase,
		TimeRemaining = TimeRemaining,
		IsFrozenState = IsFrozenState or false,
		WinnerInfo    = WinnerInfo,
	})
end

--- Lấy danh sách các người chơi đang thực sự còn sống, đã hoàn tất tải game (GameLoaded) và không ở chế độ AFK
local function GetAlivePlayers()
	local Alive = {}
	for _, Player in ipairs(Players:GetPlayers()) do
		local Character = Player.Character
		if Character and Character.Parent and PlayerStateHelper.IsGameLoaded(Player) and not PlayerStateHelper.IsAfk(Player) then
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			local HRP = Character:FindFirstChild("HumanoidRootPart")
			if Humanoid and Humanoid.Health > 0 and HRP then
				table.insert(Alive, Player)
			end
		end
	end
	return Alive
end

--- Teleport player đến một điểm spawn cụ thể
--- @param Player Player
--- @param SpawnPart BasePart
local function TeleportToSpawn(Player, SpawnPart)
	if not SpawnPart then return end
	local Character = Player.Character
	if not Character then return end
	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	HRP.CFrame = MapHelper.GetSpawnCFrame(SpawnPart)
end

--- Khóa / mở khóa di chuyển
local function SetMovementLocked(Player, Locked)
	local Character = Player.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	Humanoid.WalkSpeed  = Locked and 0 or GameConfig.Player.DefaultWalkSpeed
	Humanoid.JumpPower  = Locked and 0 or GameConfig.Player.DefaultJumpPower
	Humanoid.JumpHeight = Locked and 0 or GameConfig.Player.DefaultJumpHeight
end

--- Chọn mode cho vòng tiếp theo theo chu kỳ: 2 Normal → 1 Special → lặp
local function PickMode()
	_roundCounter = _roundCounter + 1

	local Interval = GameConfig.Match.SpecialRoundInterval
	local ModeKey

	if _roundCounter % Interval == 0 then
		-- Special round: chọn ngẫu nhiên trong danh sách Special modes
		local SpecialKeys = GameModeConfig.GetSpecialModeKeys()
		if #SpecialKeys > 0 then
			ModeKey = SpecialKeys[math.random(1, #SpecialKeys)]
		else
			ModeKey = "Normal"
		end
	else
		ModeKey = "Normal"
	end

	SessionService.SetCurrentModeKey(ModeKey)
	local Mode = GameModeConfig.GetMode(ModeKey)
	print(("[MatchService] 🎮 Vòng %d — Mode: %s (%s)"):format(_roundCounter, ModeKey, Mode.DisplayName))
	return ModeKey, Mode
end

-- =========================================================
-- PRIVATE: Win Condition Resolvers
-- =========================================================

--- TeamBased: so sánh số người Normal còn lại của từng team
local function ResolveWinnerTeamBased()
	local Team1Players = SessionService.GetTeamPlayers("Team1")
	local Team2Players = SessionService.GetTeamPlayers("Team2")

	-- Xử lý đội rỗng (nếu 1 team out sạch server)
	if #Team1Players == 0 and #Team2Players > 0 then return { WinTeam = "Team2" } end
	if #Team2Players == 0 and #Team1Players > 0 then return { WinTeam = "Team1" } end

	local Alive1 = SessionService.GetAliveCount("Team1")
	local Alive2 = SessionService.GetAliveCount("Team2")

	-- Chỉ bù 1 người sống ảo nếu đội ít người hơn thực sự còn ít nhất 1 người sống
	if #Team1Players < #Team2Players and Alive1 > 0 then
		Alive1 = Alive1 + 1
	elseif #Team2Players < #Team1Players and Alive2 > 0 then
		Alive2 = Alive2 + 1
	end

	if Alive1 > Alive2 then return { WinTeam = "Team1" } end
	if Alive2 > Alive1 then return { WinTeam = "Team2" } end

	-- Hòa số người sống: so sánh tổng Freeze + Thaw
	local Score1 = SessionService.GetTeamTotalScore("Team1")
	local Score2 = SessionService.GetTeamTotalScore("Team2")
	if Score1 > Score2 then return { WinTeam = "Team1" } end
	if Score2 > Score1 then return { WinTeam = "Team2" } end

	-- Vẫn hòa: random 50/50
	return { WinTeam = (math.random() < 0.5) and "Team1" or "Team2" }
end

--- FFA: so sánh Freeze count của các player sống sót khi hết giờ, nếu không còn ai sống thì so toàn bộ
local function ResolveWinnerFFA()
	local NormalPlayers = SessionService.GetAllNormalPlayers()
	local WinPlayer
	if #NormalPlayers > 0 then
		-- Ưu tiên người còn Normal
		WinPlayer = SessionService.GetTopScorerFFA(NormalPlayers)
	else
		-- Không còn ai Normal: so toàn bộ participants
		WinPlayer = SessionService.GetTopScorerFFA()
	end
	return { WinPlayer = WinPlayer }
end

--- Xác định kết quả khi hết giờ (không ai kết thúc sớm)
local function ResolveWinner()
	local WinCondition = GameModeHelper.GetWinCondition(SessionService.GetCurrentModeKey())
	if WinCondition == "FFA" then
		return ResolveWinnerFFA()
	else
		return ResolveWinnerTeamBased()
	end
end

-- =========================================================
-- PRIVATE: Rewards & Broadcast
-- =========================================================

--- Tính top N player theo Freeze + Thaw (TeamBased) hoặc Freeze (FFA)
local function GetTopPlayers(Result, MaxCount)
	local WinCondition = GameModeHelper.GetWinCondition(SessionService.GetCurrentModeKey())
	local Pool = {}

	if WinCondition == "FFA" then
		-- FFA: chỉ các participants thực sự trong ván
		Pool = SessionService.GetParticipants()
		table.sort(Pool, function(A, B)
			local SA = SessionService.GetStats(A) or {}
			local SB = SessionService.GetStats(B) or {}
			return (SA.Freezes or 0) > (SB.Freezes or 0)
		end)
	else
		-- TeamBased: chỉ đội thắng
		Pool = SessionService.GetTeamPlayers(Result.WinTeam)
		table.sort(Pool, function(A, B)
			local SA = SessionService.GetStats(A) or {}
			local SB = SessionService.GetStats(B) or {}
			return ((SA.Freezes or 0) + (SA.Thaws or 0)) > ((SB.Freezes or 0) + (SB.Thaws or 0))
		end)
	end

	local TopList = {}
	for i = 1, math.min(MaxCount, #Pool) do
		local P     = Pool[i]
		local Stats = SessionService.GetStats(P) or {}
		table.insert(TopList, {
			Name    = P.DisplayName,
			UserId  = P.UserId,
			Freezes = Stats.Freezes or 0,
			Thaws   = Stats.Thaws   or 0,
		})
	end
	return TopList
end

--- Phát phần thưởng Win/Lose + LastStanding theo mode
local function DistributeRewards(Result)
	local ModeKey = SessionService.GetCurrentModeKey()
	local WinCondition = GameModeHelper.GetWinCondition(ModeKey)

	if WinCondition == "TeamBased" then
		local WinTeam = Result.WinTeam

		-- LastStanding: người duy nhất còn Normal trong đội thắng
		if GameModeHelper.AllowLastStanding(ModeKey) then
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
				local LastReward = RewardHelper.GetLastStandingReward()
				RewardHelper.RewardAndSync(LastAlive, LastReward, DataService, RemoteDefinitions.GetEvent("UpdateMoney"))
				SessionService.IncrementStat(LastAlive, "MoneyEarned", LastReward)
			end
		end

		-- Thưởng Win / Lose cho tất cả participants
		for _, Player in ipairs(Players:GetPlayers()) do
			local Team = SessionService.GetTeam(Player)
			if not Team then continue end

			local IsWinner = (Team == WinTeam)
			local Reward = RewardHelper.GetMatchEndReward(IsWinner)

			RewardHelper.RewardAndSync(Player, Reward, DataService, RemoteDefinitions.GetEvent("UpdateMoney"))
			SessionService.IncrementStat(Player, "MoneyEarned", Reward)

			if IsWinner then
				DataService.IncrementStat(Player, "TotalWins")
			end
		end

	elseif WinCondition == "FFA" then
		local WinPlayer = Result.WinPlayer

		-- LastStanding: chỉ trao khi còn đúng 1 người Normal và người đó là người thắng
		if GameModeHelper.AllowLastStanding(ModeKey) and WinPlayer then
			local NormalCount = #SessionService.GetAllNormalPlayers()
			if NormalCount == 1 and SessionService.GetState(WinPlayer) == "Normal" then
				SessionService.SetStat(WinPlayer, "LastStanding", true)
				DataService.IncrementStat(WinPlayer, "TotalLastStanding")
				local LastReward = RewardHelper.GetLastStandingReward()
				RewardHelper.RewardAndSync(WinPlayer, LastReward, DataService, RemoteDefinitions.GetEvent("UpdateMoney"))
				SessionService.IncrementStat(WinPlayer, "MoneyEarned", LastReward)
			end
		end

		-- Thưởng Win / Lose cho tất cả participants thực sự của ván đấu
		for _, Player in ipairs(SessionService.GetParticipants()) do
			local IsWinner = (Player == WinPlayer)
			local Reward = RewardHelper.GetMatchEndReward(IsWinner)

			RewardHelper.RewardAndSync(Player, Reward, DataService, RemoteDefinitions.GetEvent("UpdateMoney"))
			SessionService.IncrementStat(Player, "MoneyEarned", Reward)

			if IsWinner then
				DataService.IncrementStat(Player, "TotalWins")
			end
		end
	end
end

--- Chuẩn bị GameStatistic data cho từng client trước khi dọn dẹp team/state
local function PrepareGameOverPayloads(Result)
	local TopPlayers = GetTopPlayers(Result, 3)
	local ModeKey = SessionService.GetCurrentModeKey()
	local WinCondition = GameModeHelper.GetWinCondition(ModeKey)
	local Payloads = {}

	local TargetPlayers = (WinCondition == "FFA") and SessionService.GetParticipants() or Players:GetPlayers()

	for _, Player in ipairs(TargetPlayers) do
		local Stats = SessionService.GetStats(Player) or {}

		local Won
		if WinCondition == "FFA" then
			Won = (Player == Result.WinPlayer)
		else
			local PlayerTeam = SessionService.GetTeam(Player)
			if not PlayerTeam then continue end
			Won = (PlayerTeam == Result.WinTeam)
		end

		Payloads[Player] = {
			-- TeamBased: WinTeam = "Team1"/"Team2", WinPlayer = nil
			-- FFA:       WinTeam = nil, WinPlayer = { Name, UserId }
			WinTeam    = Result.WinTeam,
			WinPlayer  = Result.WinPlayer and {
				Name   = Result.WinPlayer.DisplayName,
				UserId = Result.WinPlayer.UserId,
			} or nil,
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
		}
	end

	return Payloads
end

--- Gửi GameStatistic data đã chuẩn bị xuống các client
local function SendGameOverPayloads(Payloads)
	for Player, Payload in pairs(Payloads) do
		if Player.Parent then
			ShowGameOverEvent:FireClient(Player, Payload)
		end
	end
end

-- =========================================================
-- PHASE FUNCTIONS
-- =========================================================

--- Intermission: đếm ngược, reset về max nếu không đủ người
local function RunIntermission()
	_currentPhase     = "Intermission"
	local Duration    = GameConfig.Phase.IntermissionDuration
	local TimeLeft    = Duration

	while TimeLeft > 0 do
		local ActivePlayerCount = #GetAlivePlayers()

		if ActivePlayerCount < GameConfig.Match.MinPlayers then
			TimeLeft = Duration
			BroadcastGameState("Intermission", Duration, false)
		else
			BroadcastGameState("Intermission", TimeLeft, false)
			TimeLeft = TimeLeft - 1
		end

		task.wait(1)
	end
end

--- Setup: chọn mode, phân đội (nếu có), load map
--- @return boolean -- Trả về true nếu setup thành công, false nếu không đủ người sống
local function RunSetup()
	_currentPhase = "Setup"
	_earlyResult  = nil

	-- Reset session
	SessionService.ResetSession()
	FreezeService.ResetRound()

	-- Reset match progress cho QuestService (Objective Engine 2.0)
	local QuestModule = script.Parent:FindFirstChild("QuestService")
	if QuestModule then
		local QuestService = require(QuestModule)
		if QuestService and QuestService.ResetMatchProgress then
			QuestService.ResetMatchProgress()
		end
	end

	-- Danh sách player còn sống thực sự tham gia trận này
	local ActivePlayers = GetAlivePlayers()

	if #ActivePlayers < GameConfig.Match.MinPlayers then
		print(("[MatchService] ⚠️ Không đủ người chơi còn sống để bắt đầu trận (%d/%d)."):format(#ActivePlayers, GameConfig.Match.MinPlayers))
		return false
	end

	-- Chọn mode cho vòng này
	local ModeKey, Mode = PickMode()

	-- Set Attribute "InMatch" và Participant để nhận diện người chơi thực sự trong ván
	for _, Player in ipairs(ActivePlayers) do
		SessionService.SetParticipant(Player, true)
		PlayerStateHelper.SetInMatch(Player, true)
	end

	-- Phân đội và set state Normal
	if Mode.HasTeams then
		SessionService.AssignTeams(ActivePlayers)
	end

	for _, Player in ipairs(ActivePlayers) do
		SessionService.SetState(Player, "Normal")
		if UpdatePlayerStateEvent then
			UpdatePlayerStateEvent:FireAllClients({
				PlayerId = Player.UserId,
				State    = "Normal",
				Freezes  = 0,
				Thaws    = 0,
			})
		end
	end

	-- Broadcast GameMode TRƯỚC (client cần biết mode trước khi nhận team data)
	SetGameModeEvent:FireAllClients({
		ModeKey          = ModeKey,
		HighlightMode    = GameModeHelper.GetHighlightMode(ModeKey),
		ScoreboardType   = GameModeHelper.GetScoreboardType(ModeKey),
		PlayerStatusType = GameModeHelper.GetPlayerStatusType(ModeKey),
	})

	-- Broadcast team sau (HighlightController đã biết mode, sẽ xử lý đúng)
	TeamService.BroadcastTeamAssignment()

	SessionService.SetMatchActive(true)

	-- Báo client bắt đầu Setup (và ModeAnnouncement nếu là Special Round)
	BroadcastGameState("Setup", 0, false)

	-- Load map ngẫu nhiên
	MapService.LoadRandomMap()

	-- Nếu là Special Round: chờ thêm thời gian để client hiển thị ModeAnnouncement
	if GameModeHelper.IsSpecialRound(ModeKey) then
		local AnnouncementDuration = GuiAnimConfig.GetModeAnnouncementAnimConfig(ModeKey).DisplayDuration
		task.wait(AnnouncementDuration)
	end

	local FadeInDuration = GuiAnimConfig.GetRoundLoadingAnimConfig(ModeKey).FadeInDuration
	task.wait(FadeInDuration)
	task.wait(0.5)  -- buffer nhỏ để map load xong

	return true
end

--- Ready: teleport + khóa di chuyển
local function RunReady()
	_currentPhase = "Ready"
	local Duration = GameConfig.Phase.ReadyDuration
	local ModeKey  = SessionService.GetCurrentModeKey()

	-- Teleport theo SpawnType (chỉ teleport và khóa di chuyển người chơi đang Normal trong trận)
	if GameModeHelper.GetSpawnType(ModeKey) == "FFA" then
		local AllSpawns = MapService.GetSpawnPoints(nil, "FFA")
		local PlayersToSpawn = {}

		for _, Player in ipairs(Players:GetPlayers()) do
			if SessionService.GetState(Player) == "Normal" and PlayerStateHelper.IsInMatch(Player) and Player.Character then
				table.insert(PlayersToSpawn, Player)
			end
		end

		local Assignments = MapHelper.AssignSpawnPoints(PlayersToSpawn, AllSpawns)
		for Player, SpawnPart in pairs(Assignments) do
			TeleportToSpawn(Player, SpawnPart)
			SetMovementLocked(Player, true)
		end
	else
		local Team1Spawns = MapService.GetSpawnPoints("Team1", "TeamBased")
		local Team2Spawns = MapService.GetSpawnPoints("Team2", "TeamBased")
		local Team1Players = {}
		local Team2Players = {}

		for _, Player in ipairs(Players:GetPlayers()) do
			local Team = SessionService.GetTeam(Player)
			if not Team then continue end
			if SessionService.GetState(Player) == "Normal" and PlayerStateHelper.IsInMatch(Player) and Player.Character then
				if Team == "Team1" then
					table.insert(Team1Players, Player)
				elseif Team == "Team2" then
					table.insert(Team2Players, Player)
				end
			end
		end

		local Team1Assignments = MapHelper.AssignSpawnPoints(Team1Players, Team1Spawns)
		local Team2Assignments = MapHelper.AssignSpawnPoints(Team2Players, Team2Spawns)

		for Player, SpawnPart in pairs(Team1Assignments) do
			TeleportToSpawn(Player, SpawnPart)
			SetMovementLocked(Player, true)
		end

		for Player, SpawnPart in pairs(Team2Assignments) do
			TeleportToSpawn(Player, SpawnPart)
			SetMovementLocked(Player, true)
		end
	end

	-- Đếm ngược Ready (kiểm tra ngắt sớm nếu đã có kết quả trận đấu do out/reset)
	for t = Duration, 0, -1 do
		if _earlyResult then break end
		BroadcastGameState("Ready", t, false)
		if t == 0 then break end
		task.wait(1)
	end

	-- Mở khóa di chuyển cho player đang Normal trong trận
	for _, Player in ipairs(Players:GetPlayers()) do
		if SessionService.GetState(Player) == "Normal" and PlayerStateHelper.IsInMatch(Player) then
			SetMovementLocked(Player, false)
		end
	end
end

--- InGame: tối đa InGameDuration giây, có thể kết thúc sớm
local function RunInGame()
	_currentPhase    = "InGame"

	-- Nếu đã có kết quả sớm từ Setup/Ready (ví dụ đối thủ out/reset sạch)
	if _earlyResult then
		return _earlyResult
	end

	local ModeKey    = SessionService.GetCurrentModeKey()
	local Duration   = GameModeHelper.GetInGameDuration(ModeKey)
	local FSTThresh  = GameModeHelper.GetFrozenStateThreshold(ModeKey)
	local FrozenStateOn = false

	-- Broadcast danh sách Spectate đầy đủ khi InGame bắt đầu
	local NormalPlayers = SessionService.GetAllNormalPlayers()
	UpdateSpectateListEvent:FireAllClients(NormalPlayers)

	-- Cấp tool
	IcicleService.GiveToolToAll()

	for t = Duration, 0, -1 do
		if _earlyResult then break end

		-- Kích hoạt FrozenState nếu mode cho phép
		if GameModeHelper.HasFrozenState(ModeKey) and t <= FSTThresh and not FrozenStateOn then
			FrozenStateOn = true
			SessionService.SetFrozenState(true)
			TeamService.SetFrozenStateHighlights(true)
			print("[MatchService] ❄ FrozenState đã kích hoạt!")
		end

		BroadcastGameState("InGame", t, FrozenStateOn)
		if t == 0 then break end
		task.wait(1)
	end

	-- Tắt FrozenState nếu đã bật
	if FrozenStateOn then
		SessionService.SetFrozenState(false)
		TeamService.SetFrozenStateHighlights(false)
	end

	return _earlyResult or ResolveWinner()
end

--- GameOver: thu tool, phát thưởng, đếm ngược, teleport lobby
local function RunGameOver(Result)
	_currentPhase  = "GameOver"
	local Duration = GameConfig.Phase.GameOverDuration

	-- Thu hồi tool và kết thúc trận
	IcicleService.RemoveToolFromAll()
	SessionService.SetMatchActive(false)

	-- Broadcast danh sách Spectate rỗng — signal client tắt Spectate
	UpdateSpectateListEvent:FireAllClients({})

	-- Phát phần thưởng
	DistributeRewards(Result)

	-- Chuẩn bị dữ liệu thống kê cuối trận TRƯỚC KHI ClearTeam để giữ nguyên dữ liệu team và top players
	local Payloads = PrepareGameOverPayloads(Result)

	-- Dispatch Event OnMatchEnd cho QuestService (Objective Engine 2.0)
	local QuestModule = script.Parent:FindFirstChild("QuestService")
	if QuestModule then
		local QuestService = require(QuestModule)
		if QuestService and QuestService.DispatchEvent then
			local ModeKey = SessionService.GetCurrentModeKey()
			local WinCondition = GameModeHelper.GetWinCondition(ModeKey)
			for Player, Payload in pairs(Payloads) do
				QuestService.DispatchEvent(Player, "OnMatchEnd", {
					Won          = Payload.Won,
					WinTeam      = Payload.WinTeam,
					WinPlayer    = Payload.WinPlayer,
					ModeKey      = ModeKey,
					WinCondition = WinCondition,
					Freezes      = Payload.PersonalStats and Payload.PersonalStats.Freezes or 0,
					Thaws        = Payload.PersonalStats and Payload.PersonalStats.Thaws or 0,
					LastStanding = Payload.PersonalStats and Payload.PersonalStats.LastStanding or false,
					FirstBlood   = Payload.PersonalStats and Payload.PersonalStats.FirstBlood or false,
				})
			end
		end
	end

	-- Thaw tất cả người bị đóng băng
	FreezeService.ThawAll()

	-- Chuẩn bị WinnerInfo gửi sớm cho client hiển thị GameOverAnnouncement
	local WinnerInfo = {
		WinTeam   = Result and Result.WinTeam,
		WinPlayer = Result and Result.WinPlayer and {
			Name   = Result.WinPlayer.DisplayName,
			UserId = Result.WinPlayer.UserId,
		} or nil,
	}

	-- Đếm ngược GameOverDuration (người chơi ở trong map xem kết quả ván đấu)
	for t = Duration, 0, -1 do
		BroadcastGameState("GameOver", t, false, WinnerInfo)
		if t == 0 then break end
		task.wait(1)
	end

	-- Teleport tất cả player về SpawnLocation (lobby) và xóa InMatch/Team attribute
	local LobbySpawn = workspace:FindFirstChild("SpawnLocation")
	for _, Player in ipairs(Players:GetPlayers()) do
		PlayerStateHelper.SetInMatch(Player, false)
		SessionService.ClearTeam(Player)
		local Character = Player.Character
		if not Character then continue end
		local HRP = Character:FindFirstChild("HumanoidRootPart")
		if HRP and LobbySpawn then
			HRP.CFrame = LobbySpawn.CFrame + Vector3.new(0, 4, 0)
		end
		if HRP then
			Player.ReplicationFocus = HRP
		end
	end

	-- Khoảng đệm nhỏ đảm bảo physics tọa độ lobby được đồng bộ trước khi xóa map
	task.wait(0.2)

	-- Dọn sạch IceBlock tàn dư
	for _, Block in ipairs(TagHelper.GetTagged(TagConfig.Tags.IceBlock)) do
		Block:Destroy()
	end

	-- Dọn dẹp map
	MapService.UnloadMap()

	-- Gửi thống kê cuối trận xuống client khi đã về lobby (chuyển sang Intermission)
	SendGameOverPayloads(Payloads)
end

-- =========================================================
-- GAME LOOP
-- =========================================================

local function GameLoop()
	while true do
		while #GetAlivePlayers() < GameConfig.Match.MinPlayers do
			BroadcastGameState("Intermission", GameConfig.Phase.IntermissionDuration, false)
			task.wait(1)
		end

		RunIntermission()

		local SetupOk = RunSetup()
		if not SetupOk then
			continue
		end

		RunReady()
		local Result = RunInGame()
		RunGameOver(Result)
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
	UpdateGameStateEvent       = RemoteDefinitions.GetEvent("UpdateGameState")
	ShowGameOverEvent          = RemoteDefinitions.GetEvent("ShowGameOver")
	UpdateSpectateListEvent    = RemoteDefinitions.GetEvent("UpdateSpectateList")
	RequestSpectateTargetEvent = RemoteDefinitions.GetEvent("RequestSpectateTarget")
	SetGameModeEvent           = RemoteDefinitions.GetEvent("SetGameMode")
	UpdatePlayerStateEvent     = RemoteDefinitions.GetEvent("UpdatePlayerState")

	-- Đăng ký lắng nghe MatchEndSignal xuyên suốt vòng đời Service
	SessionService.MatchEndSignal.Event:Connect(function(Result)
		_earlyResult = Result
	end)

	-- Đăng ký lắng nghe Humanoid.Died
	local function BindCharacterDeath(Player, Character)
		if not Character then return end
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then return end

		Humanoid.Died:Connect(function()
			if SessionService.IsMatchActive() then
				FreezeService.EliminatePlayer(Player)
			end
		end)
	end

	local function BindPlayer(Player)
		if Player.Character then
			BindCharacterDeath(Player, Player.Character)
		end
		Player.CharacterAdded:Connect(function(Char)
			BindCharacterDeath(Player, Char)
		end)
	end

	for _, P in ipairs(Players:GetPlayers()) do
		PlayerStateHelper.SetGameLoaded(P, false)
		PlayerStateHelper.SetAfk(P, false)
		BindPlayer(P)
	end

	-- Lắng nghe khi Client hoàn thành GameLoadingScreen
	local FinishGameLoadingEvent = RemoteDefinitions.GetEvent("FinishGameLoading")
	FinishGameLoadingEvent.OnServerEvent:Connect(function(Player)
		if not Player then return end
		PlayerStateHelper.SetGameLoaded(Player, true)
		print(string.format("[MatchService] Player %s (%d) đã hoàn tất GameLoadingScreen.", Player.Name, Player.UserId))
	end)

	-- Lắng nghe khi Client chuyển đổi trạng thái AFK
	local SetAfkStateEvent = RemoteDefinitions.GetEvent("SetAfkState")
	SetAfkStateEvent.OnServerEvent:Connect(function(Player, Payload)
		if not Player then return end
		local IsAfk = false
		if type(Payload) == "table" then
			IsAfk = (Payload.IsAfk == true)
		elseif type(Payload) == "boolean" then
			IsAfk = Payload
		end
		PlayerStateHelper.SetAfk(Player, IsAfk)
		print(string.format("[MatchService] Player %s (%d) đã cập nhật trạng thái AFK: %s", Player.Name, Player.UserId, tostring(IsAfk)))
	end)

	-- Khi player mới join giữa trận
	Players.PlayerAdded:Connect(function(NewPlayer)
		PlayerStateHelper.SetGameLoaded(NewPlayer, false)
		PlayerStateHelper.SetAfk(NewPlayer, false)
		BindPlayer(NewPlayer)

		task.wait(2)
		if _currentPhase == "InGame" and SessionService.IsMatchActive() then
			local NormalPlayers = SessionService.GetAllNormalPlayers()
			UpdateSpectateListEvent:FireClient(NewPlayer, NormalPlayers)
			TeamService.BroadcastTeamAssignmentTo(NewPlayer)

			-- Gửi lại GameMode cho người mới join
			local ModeKey = SessionService.GetCurrentModeKey()
			SetGameModeEvent:FireClient(NewPlayer, {
				ModeKey          = ModeKey,
				HighlightMode    = GameModeHelper.GetHighlightMode(ModeKey),
				ScoreboardType   = GameModeHelper.GetScoreboardType(ModeKey),
				PlayerStatusType = GameModeHelper.GetPlayerStatusType(ModeKey),
			})
		end
	end)

	-- Spectator yêu cầu focus vào target hoặc reset về chính mình
	RequestSpectateTargetEvent.OnServerEvent:Connect(function(SpectatorPlayer, TargetPlayer)
		-- Nếu TargetPlayer là nil: reset ReplicationFocus về chính spectator (cho phép ở mọi phase)
		if TargetPlayer == nil then
			local SpectatorCharacter = SpectatorPlayer.Character
			if SpectatorCharacter then
				local SpectatorHRP = SpectatorCharacter:FindFirstChild("HumanoidRootPart")
				if SpectatorHRP then
					SpectatorPlayer.ReplicationFocus = SpectatorHRP
				end
			end
			return
		end

		-- Chỉ cho phép trong phase InGame
		if _currentPhase ~= "InGame" then return end

		local IsInMatch     = PlayerStateHelper.IsInMatch(SpectatorPlayer)
		local SpectatorState = SessionService.GetState(SpectatorPlayer)
		local IsFrozenInMatch = IsInMatch and (SpectatorState == "Frozen")

		-- Validate target còn tồn tại, có character và HRP
		if not TargetPlayer:IsDescendantOf(Players) then return end
		local TargetCharacter = TargetPlayer.Character
		if not TargetCharacter then return end
		local TargetHRP = TargetCharacter:FindFirstChild("HumanoidRootPart")
		if not TargetHRP then return end

		-- Target phải đang Normal (không cho spectate người đã Frozen/Dead)
		if SessionService.GetState(TargetPlayer) ~= "Normal" then return end

		if IsFrozenInMatch then
			-- Player bị Frozen trong trận: validate theo mode
			local ModeKey = SessionService.GetCurrentModeKey()
			if GameModeHelper.IsTeamBased(ModeKey) then
				-- Mode có team: chỉ cho phép target cùng team
				local SpectatorTeam = SessionService.GetTeam(SpectatorPlayer)
				local TargetTeam    = SessionService.GetTeam(TargetPlayer)
				if not SpectatorTeam or SpectatorTeam ~= TargetTeam then return end
			end
			-- Mode không có team (FFA): cho phép target bất kỳ Normal — không cần thêm điều kiện

		elseif not IsInMatch then
			-- Lobby spectator (không trong trận): cho phép target bất kỳ Normal
			-- (không cần điều kiện thêm)

		else
			-- Player đang trong trận nhưng không bị Frozen (Normal) → không được spectate
			return
		end

		SpectatorPlayer.ReplicationFocus = TargetHRP
	end)

	print("[MatchService] Đã khởi tạo.")
end

function MatchService:Start()
	task.spawn(GameLoop)
	print("[MatchService] Game loop đã bắt đầu.")
end

return MatchService
