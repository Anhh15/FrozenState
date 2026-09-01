-- FreezeService.lua
-- Logic Freeze / Thaw, quản lý IceBlock và Spree
-- Xử lý OnToolHit RemoteEvent từ client
-- Phase 2: IceBlock là Model clone từ ServerStorage/Blocks theo skin của Attacker
-- Phase 3: Thu hồi tool khi Freeze, trao trả khi Thaw; Block Hitbox để client detect Thaw
-- Phase 8.2: Play SFX spatial trong Character (server-side); fire pose animation đến victim client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SessionService    = require(script.Parent.SessionService)
local DataService       = require(script.Parent.DataService)
local IcicleService     = require(script.Parent.IcicleService)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local GameModeConfig    = require(ReplicatedStorage.Shared.Config.GameModeConfig)
local GameModeHelper    = require(ReplicatedStorage.Shared.Tools.GameModeHelper)
local RewardHelper      = require(ReplicatedStorage.Shared.Tools.RewardHelper)
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local TagConfig         = require(ReplicatedStorage.Shared.Config.TagConfig)
local TagHelper         = require(ReplicatedStorage.Shared.Tools.TagHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- HẰNG SỐ (từ GameConfig để không hardcode)
-- =========================================================

-- Hằng số di chuyển được lấy từ GameConfig.Player (không hardcode)

-- =========================================================
-- STATE
-- =========================================================

local _firstBloodClaimed = false

-- Cache IceBlock theo UserId — để RemoveIceBlock chạy O(1) thay vì scan workspace
-- { [UserId: number] = BlockModel: Model }
local _iceBlocks = {}

local UpdatePlayerStateEvent
local UpdateMoneyEvent
local OnToolHitEvent
local UpdateSpectateListEvent
local PlayFreezeSFXEvent
local PlayThawSFXEvent
local NotifyAccoladeEvent

-- =========================================================
-- PRIVATE: IceBlock
-- =========================================================

--- Spawn Model Block bao quanh nạn nhân theo skin của Attacker
--- @param Attacker Player  — đọc EquippedIceBlock từ attacker
--- @param Victim Player    — được bao quanh bởi Model
local function SpawnIceBlock(Attacker, Victim)
	local Character = Victim.Character
	if not Character then return end

	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	-- Đọc skin của attacker
	local SkinId = "Default"
	local AttackerData = DataService.GetData(Attacker)
	if AttackerData and AttackerData.EquippedIceBlock then
		local Entry = ItemRegistry.GetItem(AttackerData.EquippedIceBlock, "Block")
		SkinId = Entry and Entry.Id or "Default"
	end

	-- Tìm Model trong ServerStorage/Blocks
	local BlocksFolder = ServerStorage:FindFirstChild("Blocks")
	if not BlocksFolder then
		warn("[FreezeService] Không tìm thấy folder ServerStorage/Blocks")
		return
	end

	local Template = BlocksFolder:FindFirstChild(SkinId)
	if not Template then
		warn(("[FreezeService] Không tìm thấy Block skin '%s', fallback về Default."):format(SkinId))
		Template = BlocksFolder:FindFirstChild("Default")
	end

	if not Template then
		warn("[FreezeService] Không tìm thấy ServerStorage/Blocks/Default")
		return
	end

	local BlockModel = Template:Clone()
	-- Đánh dấu Model để RemoveIceBlock có thể tìm đúng theo victim
	PlayerStateHelper.SetVictimUserId(BlockModel, Victim.UserId)
	TagHelper.AddTag(BlockModel, TagConfig.Tags.IceBlock)

	-- Tìm PrimaryPart hoặc Part đầu tiên làm gốc để weld vào HRP
	local PrimaryPart = BlockModel.PrimaryPart or BlockModel:FindFirstChildOfClass("BasePart")
	if not PrimaryPart then
		warn("[FreezeService] Khối băng không chứa BasePart nào để hiển thị.")
		BlockModel:Destroy()
		return
	end

	-- Đảm bảo model có PrimaryPart được thiết lập để PivotTo hoạt động chuẩn xác
	if not BlockModel.PrimaryPart then
		BlockModel.PrimaryPart = PrimaryPart
	end

	-- Đặt parent vào workspace trước khi tạo WeldConstraint để cơ chế vật lý hoạt động chính xác
	BlockModel.Parent = workspace

	-- Lưu reference vào cache — dùng cho RemoveIceBlock O(1)
	_iceBlocks[Victim.UserId] = BlockModel

	-- Di chuyển Model về vị trí HRP sau khi đã parent vào workspace
	BlockModel:PivotTo(HRP.CFrame)

	-- Tắt Anchored, CanCollide cho toàn bộ các part trong model (để di chuyển cùng nhân vật)
	-- nhưng giữ nguyên các liên kết weld thủ công có sẵn giữa chúng
	-- Hitbox (nếu có) được set CanQuery=true để IcicleScript.client detect được khi Thaw
	for _, Part in ipairs(BlockModel:GetDescendants()) do
		if Part:IsA("BasePart") then
			Part.Anchored   = false
			Part.CanCollide = false
			Part.CastShadow = false
			-- Hitbox phải CanQuery=true để GetPartsInPart() của Icicle có thể detect
			local IsHitbox = (Part.Name == "Hitbox")
			Part.CanQuery = IsHitbox
			if IsHitbox then
				TagHelper.AddTag(Part, TagConfig.Tags.Hitbox)
			end
		end
	end

	-- Chỉ tạo duy nhất 1 WeldConstraint kết nối giữa PrimaryPart của khối băng và HRP của victim
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = PrimaryPart
	Weld.Part1 = HRP
	Weld.Parent = PrimaryPart
end

--- Xóa Model IceBlock của một player — O(1) qua cache _iceBlocks
--- @param Victim Player
local function RemoveIceBlock(Victim)
	local Block = _iceBlocks[Victim.UserId]
	if Block then
		TagHelper.RemoveTag(Block, TagConfig.Tags.IceBlock)
		Block:Destroy()
		_iceBlocks[Victim.UserId] = nil
	end
end

-- =========================================================
-- PRIVATE: Audio
-- =========================================================



-- =========================================================
-- PRIVATE: Helpers
-- =========================================================

--- Thưởng tiền và đồng bộ về client
local function RewardAndSync(Player, Amount)
	RewardHelper.RewardAndSync(Player, Amount, DataService, UpdateMoneyEvent)
	SessionService.IncrementStat(Player, "MoneyEarned", Amount)
end

--- Broadcast trạng thái player xuống tất cả client
--- Payload mở rộng: kèm Freezes/Thaws để ScoreBoardController cập nhật thống kê thời gian thực
local function BroadcastPlayerState(Player)
	local Stats = SessionService.GetStats(Player) or {}
	UpdatePlayerStateEvent:FireAllClients({
		PlayerId = Player.UserId,
		State    = SessionService.GetState(Player),
		Freezes  = Stats.Freezes or 0,
		Thaws    = Stats.Thaws   or 0,
	})
end

--- Broadcast danh sách player Normal xuống tất cả client (Spectate system)
local function BroadcastSpectateList()
	local NormalPlayers = SessionService.GetAllNormalPlayers()
	UpdateSpectateListEvent:FireAllClients(NormalPlayers)
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

	-- Khóa chuyển động và vị trí
	local VictimChar = Victim.Character
	if VictimChar then
		local Humanoid = VictimChar:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Humanoid.WalkSpeed  = 0
			Humanoid.JumpPower  = 0
			Humanoid.JumpHeight = 0
		end
		local HRP = VictimChar:FindFirstChild("HumanoidRootPart")
		if HRP then
			HRP.Anchored = true
		end
	end

	-- Thu hồi tool của victim khi bị đóng băng
	IcicleService.RemoveTool(Victim)

	-- Tạo Model IceBlock theo skin của attacker
	SpawnIceBlock(Attacker, Victim)

	-- Đọc skin Block của attacker để chọn đúng SFX
	local BlockSkinId = "Default"
	local AttackerData = DataService.GetData(Attacker)
	if AttackerData and AttackerData.EquippedIceBlock then
		local Entry = ItemRegistry.GetItem(AttackerData.EquippedIceBlock, "Block")
		BlockSkinId = Entry and Entry.Id or "Default"
	end

	-- Broadcast đến tất cả Client để tự phát 3D SFX và kích hoạt pose animation phía Client
	PlayFreezeSFXEvent:FireAllClients({
		VictimPlayer    = Victim,
		VictimCharacter = Victim.Character,
		BlockSkinId     = BlockSkinId,
		Attacker        = Attacker,
	})

	-- Victim bị đóng băng → reset cả 2 streak của victim
	SessionService.ResetFreezeStreak(Victim)
	SessionService.ResetThawStreak(Victim)

	-- Attacker: tăng freeze stat + streak
	SessionService.IncrementStat(Attacker, "Freezes")
	DataService.IncrementStat(Attacker, "TotalFreezes")
	SessionService.IncrementFreezeStreak(Attacker)
	-- Broadcast state mới của Attacker để client cập nhật Freezes count trên ScoreBoard
	BroadcastPlayerState(Attacker)

	-- Thưởng cơ bản & Spree
	local FreezeStreak = SessionService.GetFreezeStreak(Attacker)
	local BaseReward, SpreeBonus, IsSpree = RewardHelper.CalculateFreezeReward(FreezeStreak)

	RewardAndSync(Attacker, BaseReward)

	if IsSpree then
		SessionService.IncrementStat(Attacker, "FreezingSprees")
		DataService.IncrementStat(Attacker, "TotalFreezingSpree")
		RewardAndSync(Attacker, SpreeBonus)
		SessionService.ResetFreezeStreak(Attacker)
		NotifyAccoladeEvent:FireClient(Attacker, { Type = "FreezingSpree" })
		print(("[FreezeService] ❄ %s đạt Freezing Spree!"):format(Attacker.Name))
	end

	-- First Blood: người đầu tiên freeze trong trận
	local IsFirstBlood = false
	if not _firstBloodClaimed then
		_firstBloodClaimed = true
		IsFirstBlood = true
		SessionService.SetStat(Attacker, "FirstBlood", true)
		DataService.IncrementStat(Attacker, "TotalFirstBlood")
		RewardAndSync(Attacker, RewardHelper.GetFirstBloodReward())
		NotifyAccoladeEvent:FireClient(Attacker, { Type = "FirstBlood" })
		print(("[FreezeService] 🩸 %s đạt First Blood!"):format(Attacker.Name))
	end

	-- Dispatch Event cho QuestService (Objective Engine 2.0)
	local QuestModule = script.Parent:FindFirstChild("QuestService")
	if QuestModule then
		local QuestService = require(QuestModule)
		if QuestService and QuestService.DispatchEvent then
			QuestService.DispatchEvent(Attacker, "OnFreeze", {
				Victim        = Victim,
				IsSpree       = IsSpree,
				IsFirstBlood  = IsFirstBlood,
				ModeKey       = SessionService.GetCurrentModeKey(),
				IsFrozenState = SessionService.GetFrozenState(),
			})
		end
	end

	print(("[FreezeService] %s đã đóng băng %s"):format(Attacker.Name, Victim.Name))

	-- Kiểm tra điều kiện thắng
	SessionService.CheckWinCondition()

	-- Cập nhật danh sách Spectate (1 người bị loại khỏi Normal)
	BroadcastSpectateList()
end

--- Giải cứu một player đang bị đóng băng
--- @param Rescuer Player
--- @param Victim Player
function FreezeService.ThawPlayer(Rescuer, Victim)
	local ModeKey = SessionService.GetCurrentModeKey()

	-- Không thể thaw nếu mode không cho phép (EternalFreeze, Chaos)
	if not GameModeHelper.CanThaw(ModeKey) then return end

	-- Không thể thaw trong FrozenState
	if SessionService.GetFrozenState() then
		return
	end

	-- Khôi phục trạng thái Normal
	SessionService.SetState(Victim, "Normal")
	BroadcastPlayerState(Victim)

	-- Khôi phục chuyển động và vị trí
	local VictimChar = Victim.Character
	if VictimChar then
		local Humanoid = VictimChar:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Humanoid.WalkSpeed  = GameConfig.Player.DefaultWalkSpeed
			Humanoid.JumpPower  = GameConfig.Player.DefaultJumpPower
			Humanoid.JumpHeight = GameConfig.Player.DefaultJumpHeight
		end
		local HRP = VictimChar:FindFirstChild("HumanoidRootPart")
		if HRP then
			HRP.Anchored = false
		end
	end

	-- Xóa IceBlock
	RemoveIceBlock(Victim)

	-- Trao trả tool cho victim nếu trận đấu vẫn đang active
	if SessionService.IsMatchActive() then
		IcicleService.GiveTool(Victim)
	end

	-- Đọc skin Block của rescuer để chọn đúng SFX
	local BlockSkinId = "Default"
	local RescuerData = DataService.GetData(Rescuer)
	if RescuerData and RescuerData.EquippedIceBlock then
		local Entry = ItemRegistry.GetItem(RescuerData.EquippedIceBlock, "Block")
		BlockSkinId = Entry and Entry.Id or "Default"
	end

	-- Broadcast đến tất cả Client để tự phát 3D SFX và dừng pose animation phía Client
	PlayThawSFXEvent:FireAllClients({
		VictimPlayer    = Victim,
		VictimCharacter = Victim.Character,
		BlockSkinId     = BlockSkinId,
		Rescuer         = Rescuer,
	})

	-- Rescuer: tăng thaw stat + streak
	SessionService.IncrementStat(Rescuer, "Thaws")
	DataService.IncrementStat(Rescuer, "TotalThaws")
	SessionService.IncrementThawStreak(Rescuer)
	-- Broadcast state mới của Rescuer để client cập nhật Thaws count trên ScoreBoard
	BroadcastPlayerState(Rescuer)

	-- Thưởng cơ bản & Spree
	local ThawStreak = SessionService.GetThawStreak(Rescuer)
	local BaseReward, SpreeBonus, IsSpree = RewardHelper.CalculateThawReward(ThawStreak)

	RewardAndSync(Rescuer, BaseReward)

	if IsSpree then
		SessionService.IncrementStat(Rescuer, "ThawingSprees")
		DataService.IncrementStat(Rescuer, "TotalThawingSpree")
		RewardAndSync(Rescuer, SpreeBonus)
		SessionService.ResetThawStreak(Rescuer)
		NotifyAccoladeEvent:FireClient(Rescuer, { Type = "ThawingSpree" })
		print(("[FreezeService] 💧 %s đạt Thawing Spree!"):format(Rescuer.Name))
	end

	-- Dispatch Event cho QuestService (Objective Engine 2.0)
	local QuestModule = script.Parent:FindFirstChild("QuestService")
	if QuestModule then
		local QuestService = require(QuestModule)
		if QuestService and QuestService.DispatchEvent then
			QuestService.DispatchEvent(Rescuer, "OnThaw", {
				Victim        = Victim,
				IsSpree       = IsSpree,
				ModeKey       = ModeKey,
				IsFrozenState = SessionService.GetFrozenState(),
			})
		end
	end

	print(("[FreezeService] %s đã giải cứu %s"):format(Rescuer.Name, Victim.Name))

	-- Cập nhật danh sách Spectate (1 người trở lại Normal)
	BroadcastSpectateList()
end

--- Thaw toàn bộ người đang bị frozen (gọi cuối GameOver)
function FreezeService.ThawAll()
	for _, Player in ipairs(Players:GetPlayers()) do
		if SessionService.GetState(Player) == "Frozen" then
			local Char = Player.Character
			if Char then
				local Humanoid = Char:FindFirstChildOfClass("Humanoid")
				if Humanoid then
					Humanoid.WalkSpeed  = GameConfig.Player.DefaultWalkSpeed
					Humanoid.JumpPower  = GameConfig.Player.DefaultJumpPower
					Humanoid.JumpHeight = GameConfig.Player.DefaultJumpHeight
				end
				local HRP = Char:FindFirstChild("HumanoidRootPart")
				if HRP then
					HRP.Anchored = false
				end
			end
			RemoveIceBlock(Player)
			SessionService.SetState(Player, "Normal")
			BroadcastPlayerState(Player)

			-- Báo client dừng pose animation và phát âm thanh giải cứu (cuối trận)
			PlayThawSFXEvent:FireAllClients({
				VictimPlayer    = Player,
				VictimCharacter = Char,
				BlockSkinId     = "Default",
			})
		end
	end
end

--- Loại bỏ người chơi khỏi trận đấu (dùng khi nhân vật chết hoặc rơi khỏi map)
--- Đặt trạng thái Dead, gỡ InMatch & Team attribute, thu Tool, xóa IceBlock và kiểm tra điều kiện thắng
--- @param Player Player
function FreezeService.EliminatePlayer(Player)
	if not SessionService.IsMatchActive() then return end
	if SessionService.GetState(Player) == "Dead" then return end

	-- Unanchor HRP nếu player đang bị frozen
	local Char = Player.Character
	if Char then
		local HRP = Char:FindFirstChild("HumanoidRootPart")
		if HRP then
			HRP.Anchored = false
		end
	end

	-- Thu hồi Tool & xóa IceBlock
	IcicleService.RemoveTool(Player)
	RemoveIceBlock(Player)

	-- Chuyển trạng thái sang Dead và gỡ InMatch attribute (giữ nguyên phân đội trong SessionService cho ván đấu)
	SessionService.SetState(Player, "Dead")
	PlayerStateHelper.SetInMatch(Player, false)

	-- Reset streaks
	SessionService.ResetFreezeStreak(Player)
	SessionService.ResetThawStreak(Player)

	-- Broadcast state mới (để Spectate UI & ScoreBoard cập nhật)
	BroadcastPlayerState(Player)
	BroadcastSpectateList()

	-- Kiểm tra điều kiện thắng trận
	SessionService.CheckWinCondition()

	print(("[FreezeService] 💀 %s đã bị loại khỏi trận và chuyển sang Spectator."):format(Player.Name))
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

	-- Server-side distance validation (chống lag exploit)
	local AttackerChar = Attacker.Character
	local TargetChar   = Target.Character
	if not AttackerChar or not TargetChar then return end

	local AttackerHRP = AttackerChar:FindFirstChild("HumanoidRootPart")
	local TargetHRP   = TargetChar:FindFirstChild("HumanoidRootPart")
	if not AttackerHRP or not TargetHRP then return end

	local Distance = (AttackerHRP.Position - TargetHRP.Position).Magnitude
	if Distance > GameConfig.Tool.HitboxRange * 1.5 then return end  -- 1.5x tolerance lag

	local ModeKey = SessionService.GetCurrentModeKey()

	if GameModeHelper.IsTeamBased(ModeKey) then
		-- TeamBased: cần cả 2 có team
		local AttackerTeam = SessionService.GetTeam(Attacker)
		local TargetTeam   = SessionService.GetTeam(Target)
		if not AttackerTeam or not TargetTeam then return end

		if TargetTeam ~= AttackerTeam then
			-- Kẻ địch → Freeze (chỉ khi đang Normal)
			if SessionService.GetState(Target) == "Normal" then
				FreezeService.FreezePlayer(Attacker, Target)
			end
		else
			-- Đồng minh → Thaw (chỉ khi Frozen và AllowThaw)
			if GameModeHelper.CanThaw(ModeKey) and SessionService.GetState(Target) == "Frozen" then
				FreezeService.ThawPlayer(Attacker, Target)
			end
		end
	else
		-- FFA: không có team → mọi người đều là kẻ địch → chỉ Freeze
		-- Target phải có stats (tức đang trong trận)
		if SessionService.GetStats(Target) and SessionService.GetState(Target) == "Normal" then
			FreezeService.FreezePlayer(Attacker, Target)
		end
	end
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function FreezeService:Init()
	UpdatePlayerStateEvent   = RemoteDefinitions.GetEvent("UpdatePlayerState")
	UpdateMoneyEvent         = RemoteDefinitions.GetEvent("UpdateMoney")
	OnToolHitEvent           = RemoteDefinitions.GetEvent("OnToolHit")
	UpdateSpectateListEvent  = RemoteDefinitions.GetEvent("UpdateSpectateList")
	PlayFreezeSFXEvent       = RemoteDefinitions.GetEvent("PlayFreezeSFX")
	PlayThawSFXEvent         = RemoteDefinitions.GetEvent("PlayThawSFX")
	NotifyAccoladeEvent      = RemoteDefinitions.GetEvent("NotifyAccolade")

	OnToolHitEvent.OnServerEvent:Connect(HandleToolHit)

	-- Dọn cache IceBlock khi player rời game (tránh memory leak)
	Players.PlayerRemoving:Connect(function(Player)
		_iceBlocks[Player.UserId] = nil
	end)

	print("[FreezeService] Đã khởi tạo.")
end

function FreezeService:Start()
	print("[FreezeService] Đang chạy.")
end

return FreezeService
