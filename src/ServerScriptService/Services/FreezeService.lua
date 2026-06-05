-- FreezeService.lua
-- Logic Freeze / Thaw, quản lý IceBlock và Spree
-- Xử lý OnToolHit RemoteEvent từ client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionService    = require(script.Parent.SessionService)
local DataService       = require(script.Parent.DataService)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)

-- =========================================================
-- HẰNG SỐ (từ GameConfig để không hardcode)
-- =========================================================

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50

-- =========================================================
-- STATE
-- =========================================================

local _firstBloodClaimed = false

local UpdatePlayerStateEvent
local UpdateMoneyEvent
local OnToolHitEvent

-- =========================================================
-- PRIVATE: IceBlock
-- =========================================================

--- Tạo khối băng bao quanh nạn nhân (WeldConstraint theo HumanoidRootPart)
local function CreateIceBlock(Victim)
	local Character = Victim.Character
	if not Character then return end

	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	local IceBlock = Instance.new("Part")
	IceBlock.Name        = "IceBlock"
	IceBlock.Size        = Vector3.new(4, 6.5, 4)
	IceBlock.BrickColor  = BrickColor.new("Cyan")
	IceBlock.Material    = Enum.Material.Ice
	IceBlock.Transparency = 0.35
	IceBlock.CanCollide  = false
	IceBlock.CastShadow  = false
	IceBlock.Anchored    = false
	IceBlock:SetAttribute("VictimUserId", Victim.UserId)

	-- Weld theo HRP để khối băng đi cùng nhân vật
	local Weld    = Instance.new("WeldConstraint")
	Weld.Part0    = IceBlock
	Weld.Part1    = HRP
	Weld.Parent   = IceBlock

	IceBlock.CFrame = HRP.CFrame
	IceBlock.Parent = workspace
end

--- Xóa IceBlock của một player
local function RemoveIceBlock(Victim)
	for _, Child in ipairs(workspace:GetChildren()) do
		if Child.Name == "IceBlock"
			and Child:GetAttribute("VictimUserId") == Victim.UserId
		then
			Child:Destroy()
		end
	end
end

-- =========================================================
-- PRIVATE: Helpers
-- =========================================================

--- Thưởng tiền và đồng bộ về client
local function RewardAndSync(Player, Amount)
	DataService.AddMoney(Player, Amount)
	SessionService.IncrementStat(Player, "MoneyEarned", Amount)

	local Data = DataService.GetData(Player)
	if Data then
		UpdateMoneyEvent:FireClient(Player, Data.Money)
	end
end

--- Broadcast trạng thái player xuống tất cả client
local function BroadcastPlayerState(Player)
	UpdatePlayerStateEvent:FireAllClients({
		PlayerId = Player.UserId,
		State    = SessionService.GetState(Player),
	})
end

--- Sau mỗi freeze: kiểm tra xem đội vừa bị đóng băng có bị wipe không
local function CheckWinCondition(FrozenTeam)
	if SessionService.IsTeamWiped(FrozenTeam) then
		local WinTeam = (FrozenTeam == "Team1") and "Team2" or "Team1"
		SessionService.MatchEndSignal:Fire(WinTeam)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local FreezeService = {}

--- Đóng băng một player
--- @param Attacker Player  -- người tấn công
--- @param Victim Player    -- mục tiêu
function FreezeService.FreezePlayer(Attacker, Victim)
	-- Đặt trạng thái Frozen
	SessionService.SetState(Victim, "Frozen")
	BroadcastPlayerState(Victim)

	-- Khóa chuyển động
	local VictimChar = Victim.Character
	if VictimChar then
		local Humanoid = VictimChar:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Humanoid.WalkSpeed = 0
			Humanoid.JumpPower = 0
		end
	end

	-- Tạo IceBlock
	CreateIceBlock(Victim)

	-- Victim bị đóng băng → reset cả 2 streak của victim
	SessionService.ResetFreezeStreak(Victim)
	SessionService.ResetThawStreak(Victim)

	-- Attacker: tăng freeze stat + streak, reset thaw streak
	SessionService.IncrementStat(Attacker, "Freezes")
	DataService.IncrementStat(Attacker, "TotalFreezes")
	SessionService.IncrementFreezeStreak(Attacker)
	SessionService.ResetThawStreak(Attacker)

	-- Thưởng cơ bản
	RewardAndSync(Attacker, GameConfig.Economy.RewardPerFreeze)

	-- Kiểm tra Freezing Spree
	-- Spree đạt khi streak >= SpreeThreshold, sau đó reset streak về 0
	local FreezeStreak = SessionService.GetFreezeStreak(Attacker)
	if FreezeStreak >= GameConfig.Match.SpreeThreshold then
		SessionService.IncrementStat(Attacker, "FreezingSprees")
		DataService.IncrementStat(Attacker, "TotalFreezingSpree")
		RewardAndSync(Attacker, GameConfig.Economy.RewardPerFreezingSpree)
		SessionService.ResetFreezeStreak(Attacker)
		print(("[FreezeService] ❄ %s đạt Freezing Spree!"):format(Attacker.Name))
	end

	-- First Blood: người đầu tiên freeze trong trận
	if not _firstBloodClaimed then
		_firstBloodClaimed = true
		SessionService.SetStat(Attacker, "FirstBlood", true)
		DataService.IncrementStat(Attacker, "TotalFirstBlood")
		RewardAndSync(Attacker, GameConfig.Economy.RewardFirstBlood)
		print(("[FreezeService] 🩸 %s đạt First Blood!"):format(Attacker.Name))
	end

	print(("[FreezeService] %s đã đóng băng %s"):format(Attacker.Name, Victim.Name))

	-- Kiểm tra điều kiện thắng
	CheckWinCondition(SessionService.GetTeam(Victim))
end

--- Giải cứu một player đang bị đóng băng
--- @param Rescuer Player
--- @param Victim Player
function FreezeService.ThawPlayer(Rescuer, Victim)
	-- Không thể thaw trong FrozenState
	if SessionService.GetFrozenState() then
		return
	end

	-- Khôi phục trạng thái Normal
	SessionService.SetState(Victim, "Normal")
	BroadcastPlayerState(Victim)

	-- Khôi phục chuyển động
	local VictimChar = Victim.Character
	if VictimChar then
		local Humanoid = VictimChar:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Humanoid.WalkSpeed = DEFAULT_WALK_SPEED
			Humanoid.JumpPower = DEFAULT_JUMP_POWER
		end
	end

	-- Xóa IceBlock
	RemoveIceBlock(Victim)

	-- Rescuer: tăng thaw stat + streak, reset freeze streak
	SessionService.IncrementStat(Rescuer, "Thaws")
	DataService.IncrementStat(Rescuer, "TotalThaws")
	SessionService.IncrementThawStreak(Rescuer)
	SessionService.ResetFreezeStreak(Rescuer)

	-- Thưởng
	RewardAndSync(Rescuer, GameConfig.Economy.RewardPerThaw)

	-- Kiểm tra Thawing Spree
	local ThawStreak = SessionService.GetThawStreak(Rescuer)
	if ThawStreak >= GameConfig.Match.SpreeThreshold then
		SessionService.IncrementStat(Rescuer, "ThawingSprees")
		DataService.IncrementStat(Rescuer, "TotalThawingSpree")
		RewardAndSync(Rescuer, GameConfig.Economy.RewardPerThawingSpree)
		SessionService.ResetThawStreak(Rescuer)
		print(("[FreezeService] 💧 %s đạt Thawing Spree!"):format(Rescuer.Name))
	end

	print(("[FreezeService] %s đã giải cứu %s"):format(Rescuer.Name, Victim.Name))
end

--- Thaw toàn bộ người đang bị frozen (gọi cuối GameOver)
function FreezeService.ThawAll()
	for _, Player in ipairs(Players:GetPlayers()) do
		if SessionService.GetState(Player) == "Frozen" then
			local Char = Player.Character
			if Char then
				local Humanoid = Char:FindFirstChildOfClass("Humanoid")
				if Humanoid then
					Humanoid.WalkSpeed = DEFAULT_WALK_SPEED
					Humanoid.JumpPower = DEFAULT_JUMP_POWER
				end
			end
			RemoveIceBlock(Player)
			SessionService.SetState(Player, "Normal")
			BroadcastPlayerState(Player)
		end
	end
end

--- Reset flag First Blood (gọi khi bắt đầu trận mới)
function FreezeService.ResetRound()
	_firstBloodClaimed = false
end

-- =========================================================
-- HANDLER: OnToolHit (Client → Server)
-- =========================================================

local function HandleToolHit(Attacker, Target)
	-- Validate: Target phải là Player
	if not Target or not Target:IsA("Player") then return end
	if Target == Attacker then return end

	-- Match phải đang active
	if not SessionService.IsMatchActive() then return end

	-- Attacker phải ở trạng thái Normal
	if SessionService.GetState(Attacker) ~= "Normal" then return end

	-- Cả hai phải có team (tức là đang trong trận)
	local AttackerTeam = SessionService.GetTeam(Attacker)
	local TargetTeam   = SessionService.GetTeam(Target)
	if not AttackerTeam or not TargetTeam then return end

	-- Server-side distance validation (chống lag exploit)
	local AttackerChar = Attacker.Character
	local TargetChar   = Target.Character
	if not AttackerChar or not TargetChar then return end

	local AttackerHRP = AttackerChar:FindFirstChild("HumanoidRootPart")
	local TargetHRP   = TargetChar:FindFirstChild("HumanoidRootPart")
	if not AttackerHRP or not TargetHRP then return end

	local Distance = (AttackerHRP.Position - TargetHRP.Position).Magnitude
	if Distance > GameConfig.Tool.IcicleRange * 1.5 then return end  -- 1.5x tolerance lag

	if TargetTeam ~= AttackerTeam then
		-- Kẻ địch → Freeze (chỉ khi đang Normal)
		if SessionService.GetState(Target) == "Normal" then
			FreezeService.FreezePlayer(Attacker, Target)
		end
	else
		-- Đồng minh → Thaw (chỉ khi đang Frozen và không phải FrozenState)
		if SessionService.GetState(Target) == "Frozen" then
			FreezeService.ThawPlayer(Attacker, Target)
		end
	end
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function FreezeService:Init()
	UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
	UpdateMoneyEvent       = RemoteDefinitions.GetEvent("UpdateMoney")
	OnToolHitEvent         = RemoteDefinitions.GetEvent("OnToolHit")

	OnToolHitEvent.OnServerEvent:Connect(HandleToolHit)

	print("[FreezeService] Đã khởi tạo.")
end

function FreezeService:Start()
	print("[FreezeService] Đang chạy.")
end

return FreezeService
