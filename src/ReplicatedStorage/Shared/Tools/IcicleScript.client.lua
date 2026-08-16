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

local ContentProvider  = game:GetService("ContentProvider")

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
local PlayerStateHelper = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Tools")
		:WaitForChild("PlayerStateHelper")
)

-- Chờ Hitbox từ template
local Hitbox           = Tool:WaitForChild("Hitbox")
local COOLDOWN         = GameConfig.Tool.IcicleCooldown

local _IsOnCooldown       = false
local _CurrentSwingTrack   = nil  -- Lưu Track đang chạy để dừng khi Unequip
local _HitboxConnection    = nil  -- Heartbeat connection trong cửa sổ HitStart→HitEnd
local _preloadedSounds     = {}   -- { [AudioId] = Sound instance } lưu trữ sound đã nạp sẵn
local _cachedSwingTracks   = {}   -- { [AnimId] = AnimationTrack } cache track đã load

-- =========================================================
-- PRIVATE: Preload Assets
-- =========================================================

--- Nạp trước Animation và Audio vào bộ nhớ để 100% phát ngay từ cú vung đầu tiên
local function PreloadAssets()
	local IcicleSkinId = PlayerStateHelper.GetEquippedIcicleSkinId(Player)
	local AnimId = AudioConfig.GetSwingAnimation(IcicleSkinId)
	local Audios = AudioConfig.GetSwingAudios(IcicleSkinId)

	local ItemsToPreload = {}

	-- 1. Nạp và giữ sẵn các Sound instances trong Hitbox
	for _, AudioId in ipairs(Audios) do
		if not _preloadedSounds[AudioId] or not _preloadedSounds[AudioId].Parent then
			local Sound = Instance.new("Sound")
			Sound.Name                = "SwingSFX_" .. tostring(AudioId)
			Sound.SoundId             = "rbxassetid://" .. tostring(AudioId)
			Sound.RollOffMaxDistance  = 60
			Sound.Volume              = 1
			Sound.Parent              = Hitbox
			_preloadedSounds[AudioId] = Sound
			table.insert(ItemsToPreload, Sound)
		end
	end

	-- 2. Nạp Animation
	local Anim = Instance.new("Animation")
	Anim.AnimationId = "rbxassetid://" .. tostring(AnimId)
	table.insert(ItemsToPreload, Anim)

	pcall(function()
		ContentProvider:PreloadAsync(ItemsToPreload)
	end)

	Anim:Destroy()

	-- 3. Pre-load AnimationTrack lên Animator nếu Character đã có sẵn
	local Character = Player.Character
	if Character then
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			local Animator = Humanoid:FindFirstChildOfClass("Animator")
			if Animator and not _cachedSwingTracks[AnimId] then
				local PreloadAnim = Instance.new("Animation")
				PreloadAnim.AnimationId = "rbxassetid://" .. tostring(AnimId)
				local Track = Animator:LoadAnimation(PreloadAnim)
				Track.Looped = false
				_cachedSwingTracks[AnimId] = Track
				PreloadAnim:Destroy()
			end
		end
	end
end

-- Preload ngay khi script khởi tạo
task.spawn(PreloadAssets)

Tool.Equipped:Connect(function()
	task.spawn(PreloadAssets)
end)

-- Khi Character thay đổi (respawn), dọn dẹp cache AnimationTrack cũ
Player.CharacterAdded:Connect(function()
	_cachedSwingTracks = {}
end)

-- =========================================================
-- PRIVATE: Audio & Animation
-- =========================================================

--- Phát swing audio ngẫu nhiên từ Sound Pool đã nạp sẵn
local function PlaySwingAudio(IcicleSkinId)
	local Audios = AudioConfig.GetSwingAudios(IcicleSkinId)
	if not Audios or #Audios == 0 then return end

	local ChosenId = Audios[math.random(1, #Audios)]
	local Sound = _preloadedSounds[ChosenId]

	-- Fallback nếu sound chưa được tạo trong pool
	if not Sound or not Sound.Parent then
		Sound = Instance.new("Sound")
		Sound.Name                = "SwingSFX_" .. tostring(ChosenId)
		Sound.SoundId             = "rbxassetid://" .. tostring(ChosenId)
		Sound.RollOffMaxDistance  = 60
		Sound.Volume              = 1
		Sound.Parent              = Hitbox
		_preloadedSounds[ChosenId] = Sound
	end

	Sound.TimePosition = 0
	Sound:Play()
end

--- Play swing animation trên Humanoid của local player
--- Tái sử dụng track đã pre-load để đảm bảo 0ms độ trễ
local function PlaySwingAnimation(IcicleSkinId)
	local Character = Player.Character
	if not Character then return nil end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return nil end
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then return nil end

	local AnimId = AudioConfig.GetSwingAnimation(IcicleSkinId)
	local Track = _cachedSwingTracks[AnimId]

	-- Nếu track chưa tồn tại hoặc Animator đã bị thay thế thì load lại
	if not Track or not Track:IsDescendantOf(Animator) then
		local Anim = Instance.new("Animation")
		Anim.AnimationId = "rbxassetid://" .. tostring(AnimId)
		Track = Animator:LoadAnimation(Anim)
		Track.Looped = false
		_cachedSwingTracks[AnimId] = Track
		Anim:Destroy()
	end

	_CurrentSwingTrack = Track
	Track:Play()

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
				local VictimUserId = PlayerStateHelper.GetVictimUserId(TargetChar)
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
	local IcicleSkinId = PlayerStateHelper.GetEquippedIcicleSkinId(Player)

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
