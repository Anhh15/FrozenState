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
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)

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
	BlockModel:SetAttribute("VictimUserId", Victim.UserId)

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
			Part.CanQuery   = (Part.Name == "Hitbox")
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
		Block:Destroy()
		_iceBlocks[Victim.UserId] = nil
	end
end

-- =========================================================
-- PRIVATE: Audio
-- =========================================================

--- Phát âm thanh spatial trong HumanoidRootPart của Character
--- Roblox tự replication Sound instance đến tất cả client, đảm bảo spatial audio theo khoảng cách
--- Sound sẽ tự hủy sau khi phát xong (hoặc sau 5 giây để tránh leak)
--- @param Character Model
--- @param SoundId number
local function PlaySpatialSound(Character, SoundId)
	if not Character then return end
	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	local Sound = Instance.new("Sound")
	Sound.SoundId          = "rbxassetid://" .. tostring(SoundId)
	Sound.RollOffMaxDistance = 60   -- studs — nghe được trong phạm vi hợp lý
	Sound.Volume           = 1
	Sound.Parent           = HRP
	Sound:Play()

	-- Tự dọn ngay khi phát xong (chính xác hơn task.delay(5) cố định)
	Sound.Ended:Once(function()
		if Sound and Sound.Parent then
			Sound:Destroy()
		end
	end)
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

	-- Play freeze SFX spatial tại Character của victim
	PlaySpatialSound(Victim.Character, AudioConfig.GetFreezeAudio(BlockSkinId))

	-- Báo victim client kích hoạt pose animation
	PlayFreezeSFXEvent:FireClient(Victim, { BlockSkinId = BlockSkinId })

	-- Victim bị đóng băng → reset cả 2 streak của victim
	SessionService.ResetFreezeStreak(Victim)
	SessionService.ResetThawStreak(Victim)

	-- Attacker: tăng freeze stat + streak
	SessionService.IncrementStat(Attacker, "Freezes")
	DataService.IncrementStat(Attacker, "TotalFreezes")
	SessionService.IncrementFreezeStreak(Attacker)
	-- Broadcast state mới của Attacker để client cập nhật Freezes count trên ScoreBoard
	BroadcastPlayerState(Attacker)

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
		NotifyAccoladeEvent:FireClient(Attacker, { Type = "FreezingSpree" })
		print(("[FreezeService] ❄ %s đạt Freezing Spree!"):format(Attacker.Name))
	end

	-- First Blood: người đầu tiên freeze trong trận
	if not _firstBloodClaimed then
		_firstBloodClaimed = true
		SessionService.SetStat(Attacker, "FirstBlood", true)
		DataService.IncrementStat(Attacker, "TotalFirstBlood")
		RewardAndSync(Attacker, GameConfig.Economy.RewardFirstBlood)
		NotifyAccoladeEvent:FireClient(Attacker, { Type = "FirstBlood" })
		print(("[FreezeService] 🩸 %s đạt First Blood!"):format(Attacker.Name))
	end

	print(("[FreezeService] %s đã đóng băng %s"):format(Attacker.Name, Victim.Name))

	-- Kiểm tra điều kiện thắng
	CheckWinCondition(SessionService.GetTeam(Victim))

	-- Cập nhật danh sách Spectate (1 người bị loại khỏi Normal)
	BroadcastSpectateList()
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

	-- Play thaw SFX spatial tại Character của victim
	PlaySpatialSound(Victim.Character, AudioConfig.GetThawAudio(BlockSkinId))

	-- Báo victim client dừng pose animation
	PlayThawSFXEvent:FireClient(Victim)

	-- Rescuer: tăng thaw stat + streak
	SessionService.IncrementStat(Rescuer, "Thaws")
	DataService.IncrementStat(Rescuer, "TotalThaws")
	SessionService.IncrementThawStreak(Rescuer)
	-- Broadcast state mới của Rescuer để client cập nhật Thaws count trên ScoreBoard
	BroadcastPlayerState(Rescuer)

	-- Thưởng
	RewardAndSync(Rescuer, GameConfig.Economy.RewardPerThaw)

	-- Kiểm tra Thawing Spree
	local ThawStreak = SessionService.GetThawStreak(Rescuer)
	if ThawStreak >= GameConfig.Match.SpreeThreshold then
		SessionService.IncrementStat(Rescuer, "ThawingSprees")
		DataService.IncrementStat(Rescuer, "TotalThawingSpree")
		RewardAndSync(Rescuer, GameConfig.Economy.RewardPerThawingSpree)
		SessionService.ResetThawStreak(Rescuer)
		NotifyAccoladeEvent:FireClient(Rescuer, { Type = "ThawingSpree" })
		print(("[FreezeService] 💧 %s đạt Thawing Spree!"):format(Rescuer.Name))
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

			-- Báo victim client dừng pose animation (cuối trận)
			PlayThawSFXEvent:FireClient(Player)
		end
	end
end

--- Loại bỏ người chơi khỏi trận đấu (dùng khi nhân vật chết hoặc rơi khỏi map)
--- Đặt trạng thái Dead, gỡ Team attribute, thu Tool, xóa IceBlock và kiểm tra điều kiện thắng
--- @param Player Player
function FreezeService.EliminatePlayer(Player)
	if not SessionService.IsMatchActive() then return end

	local OldTeam = SessionService.GetTeam(Player)
	if not OldTeam then return end

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

	-- Chuyển trạng thái sang Dead và xóa Team assignment
	SessionService.SetState(Player, "Dead")
	SessionService.ClearTeam(Player)

	-- Reset streaks
	SessionService.ResetFreezeStreak(Player)
	SessionService.ResetThawStreak(Player)

	-- Broadcast state mới (để Spectate UI & ScoreBoard cập nhật)
	BroadcastPlayerState(Player)
	BroadcastSpectateList()

	-- Kiểm tra điều kiện thắng trận cho đội cũ
	CheckWinCondition(OldTeam)

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
	if Distance > GameConfig.Tool.HitboxRange * 1.5 then return end  -- 1.5x tolerance lag

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
