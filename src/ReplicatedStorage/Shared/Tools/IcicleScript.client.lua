-- IcicleScript (LocalScript)
-- Nằm trong ReplicatedStorage.Shared.Tools — được IcicleService inject vào Tool khi cấp
-- Chạy khi player cầm Tool (context: Backpack / Character)
--
-- Cơ chế hit detection:
--   Tool.Activated → PlaySwingAnimation() → task.delay(HitStartTime) → Heartbeat poll GetPartsInPart(Hitbox)
--   → FireServer(OnToolHit, TargetPlayer) ngay khi phát hiện hit mới → task.delay(HitEndTime) → dừng poll
--   Không dùng Raycast. Hitbox là Part vô hình trong Tool template (tạo trong Studio).
--   Một lần swing có thể đóng băng/giải cứu nhiều người cùng lúc (AoE).
--   Mỗi mục tiêu chỉ bị hit 1 lần duy nhất per swing (dedup bằng HitPlayers table).
--   Timing cửa sổ Hitbox lấy từ AudioConfig.HitStartTime / HitEndTime (per skin).
--
-- Phase 3: phát hiện Block Model (VictimUserId attribute) → signal Thaw đồng đội
-- Phase 8.2: play swing audio (random 1/3) tại HitStartTime + swing animation phía client mỗi lần Activated

local Tool             = script.Parent
local Player           = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")

-- Chờ các dependency sẵn sàng
local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local OnToolHit        = Remotes:WaitForChild("OnToolHit")
local GameConfig       = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("GameConfig")
)
local AudioConfig      = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("AudioConfig")
)

-- Chờ Hitbox từ template
local Hitbox           = Tool:WaitForChild("Hitbox")
local COOLDOWN         = GameConfig.Tool.IcicleCooldown

local _IsOnCooldown      = false
local _CurrentSwingTrack = nil  -- Lưu Track đang chạy để dừng khi Unequip
local _HitboxConnection  = nil  -- Heartbeat connection trong cửa sổ HitStart→HitEnd

-- =========================================================
-- PRIVATE: Audio & Animation
-- =========================================================

--- Phát swing audio ngẫu nhiên tại Character của local player (spatial)
--- Các player xung quanh sẽ nghe được nhờ Roblox replication Sound trong Character
local function PlaySwingAudio(IcicleSkinId)
	local Character = Player.Character
	if not Character then return end
	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	local Audios = AudioConfig.GetSwingAudios(IcicleSkinId)
	local ChosenId = Audios[math.random(1, #Audios)]

	local Sound = Instance.new("Sound")
	Sound.SoundId            = "rbxassetid://" .. tostring(ChosenId)
	Sound.RollOffMaxDistance = 60
	Sound.Volume             = 1
	Sound.Parent             = HRP
	Sound:Play()

	-- Tự dọn sau khi phát xong (tối đa 5 giây)
	task.delay(5, function()
		if Sound and Sound.Parent then
			Sound:Destroy()
		end
	end)
end

--- Play swing animation trên Humanoid của local player
--- Override Looped = false tại client để chặn loop vô hạn dù Studio set Loop
--- Trả về Track để caller gắn Track.Stopped fallback (dừng poll nếu Unequip giữa chừng)
--- CurrentSwingTrack được lưu ra ngoài scope để Unequipped handler có thể dừng
local function PlaySwingAnimation(IcicleSkinId)
	local Character = Player.Character
	if not Character then return nil end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return nil end
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then return nil end

	local AnimId = AudioConfig.GetSwingAnimation(IcicleSkinId)
	local Anim = Instance.new("Animation")
	Anim.AnimationId = "rbxassetid://" .. tostring(AnimId)

	local Track = Animator:LoadAnimation(Anim)
	Track.Looped = false  -- Override: chắc chắn không loop dù Studio có set Loop
	_CurrentSwingTrack = Track
	Track:Play()

	-- Helper dọn dẹp Track và Anim
	local function Cleanup()
		if _CurrentSwingTrack == Track then
			_CurrentSwingTrack = nil
		end
		Track:Stop()
		Track:Destroy()
		Anim:Destroy()
	end

	-- Dọn dẹp khi animation kết thúc tự nhiên
	Track.Stopped:Connect(Cleanup)

	-- Fallback: dọn dẹp sau tối đa 5 giây phòng Stopped không fire
	task.delay(5, function()
		if _CurrentSwingTrack == Track then
			Cleanup()
		end
	end)

	return Track
end

-- =========================================================
-- TOOL UNEQUIPPED: Dừng animation ngay lập tức
-- =========================================================

Tool.Unequipped:Connect(function()
	if _CurrentSwingTrack then
		_CurrentSwingTrack:Stop()
		_CurrentSwingTrack = nil
	end
end)

-- =========================================================
-- PRIVATE: Dừng Heartbeat poll nếu đang chạy
-- =========================================================

local function StopHitboxPoll()
	if _HitboxConnection then
		_HitboxConnection:Disconnect()
		_HitboxConnection = nil
	end
end

-- =========================================================
-- PRIVATE: Bắt đầu Heartbeat poll trong cửa sổ HitStart→HitEnd
-- HitPlayers: table dedup tránh fire nhiều lần cùng 1 mục tiêu
-- =========================================================

local function StartHitboxPoll(HitPlayers)
	local Params = OverlapParams.new()
	Params.FilterType                 = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Player.Character }

	_HitboxConnection = RunService.Heartbeat:Connect(function()
		local TouchingParts = workspace:GetPartsInPart(Hitbox, Params)

		for _, Part in ipairs(TouchingParts) do
			-- Tìm Model chứa Part
			local TargetChar = Part:FindFirstAncestorOfClass("Model")
			if not TargetChar then continue end

			-- Thử resolve player từ character (thường dùng để Freeze)
			local TargetPlayer = game.Players:GetPlayerFromCharacter(TargetChar)

			-- Fallback: nếu không phải character, kiểm tra xem Model có phải Block Model không
			-- Block Model được đánh dấu bằng attribute VictimUserId (set bởi FreezeService)
			if not TargetPlayer then
				local VictimUserId = TargetChar:GetAttribute("VictimUserId")
				if VictimUserId then
					TargetPlayer = game.Players:GetPlayerByUserId(VictimUserId)
				end
			end

			if not TargetPlayer or TargetPlayer == Player then continue end

			-- Tránh hit cùng 1 player nhiều lần trong 1 swing
			if HitPlayers[TargetPlayer] then continue end
			HitPlayers[TargetPlayer] = true

			-- Fire ngay khi phát hiện hit lần đầu (không đợi HitEnd)
			OnToolHit:FireServer(TargetPlayer)
		end
	end)
end

-- =========================================================
-- TOOL ACTIVATED
-- =========================================================

Tool.Activated:Connect(function()
	-- Cooldown check
	if _IsOnCooldown then return end
	_IsOnCooldown = true

	-- Đọc SkinId của Icicle đang trang bị (gán bởi server qua Attribute)
	local IcicleSkinId = Player:GetAttribute("EquippedIcicleSkinId") or "Default"

	-- Bắt đầu animation (trả về Track để gắn marker signals)
	local Track = PlaySwingAnimation(IcicleSkinId)

	if Track then
		-- Dedup table cho swing này
		local HitPlayers = {}

		-- Lấy timing cửa sổ Hitbox từ AudioConfig (per skin, không hardcode)
		local HitStartTime = AudioConfig.GetHitStartTime(IcicleSkinId)
		local HitEndTime   = AudioConfig.GetHitEndTime(IcicleSkinId)

		-- Sau HitStartTime: bắt đầu giai đoạn vung → phát audio + bắt đầu poll
		task.delay(HitStartTime, function()
			if _CurrentSwingTrack ~= Track then return end  -- Guard: tool đã bị thu hồi
			PlaySwingAudio(IcicleSkinId)
			StopHitboxPoll()  -- Phòng trường hợp swing trước chưa kết thúc
			StartHitboxPoll(HitPlayers)
		end)

		-- Sau HitEndTime: kết thúc giai đoạn vung → dừng poll
		task.delay(HitEndTime, function()
			StopHitboxPoll()
		end)

		-- Fallback: nếu Unequip giữa chừng (Track.Stopped fire sớm)
		-- → đảm bảo poll không bị leak
		Track.Stopped:Connect(function()
			StopHitboxPoll()
		end)
	end

	-- Hồi chiêu
	task.wait(COOLDOWN)
	_IsOnCooldown = false
end)
