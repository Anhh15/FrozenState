-- IcicleScript (LocalScript)
-- Nằm trong ReplicatedStorage.Shared.Tools — được IcicleService inject vào Tool khi cấp
-- Chạy khi player cầm Tool (context: Backpack / Character)
--
-- Cơ chế hit detection:
--   Tool.Activated → PlaySwingAnimation() → task.delay(HitStartTime) → Heartbeat poll GetPartsInPart(Hitbox)
--   → FireServer(OnToolHit, TargetPlayer) ngay khi phát hiện hit mới → task.delay(HitEndTime) → dừng poll
--   Timing cửa sổ Hitbox lấy từ AnimationConfig.HitStartTime / HitEndTime (per skin).

local Tool              = script.Parent
local Player            = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

-- Chờ các dependency sẵn sàng
local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local OnToolHit         = Remotes:WaitForChild("OnToolHit")
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AnimationConfig   = require(ReplicatedStorage.Shared.Config.AnimationConfig)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local AnimationHelper   = require(ReplicatedStorage.Shared.Tools.AnimationHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- Chờ Hitbox từ template
local Hitbox            = Tool:WaitForChild("Hitbox")
local COOLDOWN          = GameConfig.Tool.IcicleCooldown

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
	local AnimId = AnimationConfig.GetSwingAnimation(IcicleSkinId)
	local SwingEntry = AudioConfig.GetSwingAudios(IcicleSkinId)
	local Audios = SwingEntry.Ids or SwingEntry

	-- 1. Nạp và giữ sẵn Sound instances trong Hitbox bằng AudioHelper
	for _, AudioId in ipairs(Audios) do
		if not _preloadedSounds[AudioId] or not _preloadedSounds[AudioId].Parent then
			local Pool = AudioHelper.CreateSoundPool(Hitbox, { AudioId }, { Volume = SwingEntry.Volume or 0.8, MaxDistance = SwingEntry.MaxDistance or 60 })
			_preloadedSounds[AudioId] = Pool[AudioId]
		end
	end
	AudioHelper.PreloadAudios(Audios)

	-- 2. Nạp Animation asset
	AnimationHelper.PreloadAnimations({ AnimId })

	-- 3. Pre-load AnimationTrack lên Animator nếu Character đã có sẵn
	local Character = Player.Character
	if Character and not _cachedSwingTracks[AnimId] then
		local Track = AnimationHelper.LoadTrack(Character, AnimId, {
			Looped   = false,
			Priority = Enum.AnimationPriority.Action,
		})
		if Track then
			_cachedSwingTracks[AnimId] = Track
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
	local SwingEntry = AudioConfig.GetSwingAudios(IcicleSkinId)
	local Audios = SwingEntry.Ids or SwingEntry
	if not Audios or #Audios == 0 then return end

	local ChosenId = Audios[math.random(1, #Audios)]
	local Sound = _preloadedSounds[ChosenId]

	-- Fallback nếu sound chưa được tạo trong pool
	if not Sound or not Sound.Parent then
		local Pool = AudioHelper.CreateSoundPool(Hitbox, { ChosenId }, { Volume = SwingEntry.Volume or 0.8, MaxDistance = SwingEntry.MaxDistance or 60 })
		Sound = Pool[ChosenId]
		_preloadedSounds[ChosenId] = Sound
	end

	AudioHelper.PlayPooledSound(Sound)
end

--- Play swing animation trên Animator của local player
--- Tái sử dụng track đã pre-load để đảm bảo 0ms độ trễ
local function PlaySwingAnimation(IcicleSkinId)
	local Character = Player.Character
	if not Character then return nil end

	local AnimId = AnimationConfig.GetSwingAnimation(IcicleSkinId)
	local Track = _cachedSwingTracks[AnimId]

	local Animator = AnimationHelper.GetAnimator(Character)
	if not Animator then return nil end

	-- Nếu track chưa tồn tại hoặc Animator đã bị thay thế thì load lại
	if not Track or not Track:IsDescendantOf(Animator) then
		Track = AnimationHelper.LoadTrack(Character, AnimId, {
			Looped   = false,
			Priority = Enum.AnimationPriority.Action,
		})
		_cachedSwingTracks[AnimId] = Track
	end

	if Track then
		_CurrentSwingTrack = Track
		AnimationHelper.PlayTrack(Track)
	end

	return Track
end

-- =========================================================
-- TOOL UNEQUIPPED: Dừng animation ngay lập tức
-- =========================================================

Tool.Unequipped:Connect(function()
	if _CurrentSwingTrack then
		AnimationHelper.StopTrack(_CurrentSwingTrack)
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
-- =========================================================

local function StartHitboxPoll(HitPlayers)
	local Params = OverlapParams.new()
	Params.FilterType                 = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Player.Character }

	_HitboxConnection = RunService.Heartbeat:Connect(function()
		local TouchingParts = workspace:GetPartsInPart(Hitbox, Params)

		for _, Part in ipairs(TouchingParts) do
			local TargetChar = Part:FindFirstAncestorOfClass("Model")
			if not TargetChar then continue end

			local TargetPlayer = game.Players:GetPlayerFromCharacter(TargetChar)

			-- Fallback: nếu không phải character, kiểm tra xem Model có phải Block Model không
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

			-- Fire ngay khi phát hiện hit lần đầu
			OnToolHit:FireServer(TargetPlayer)
		end
	end)
end

-- =========================================================
-- TOOL ACTIVATED
-- =========================================================

-- Khởi tạo attribute cooldown ban đầu
Tool:SetAttribute("CooldownDuration", COOLDOWN)
Tool:SetAttribute("IsOnCooldown", false)

Tool.Activated:Connect(function()
	-- Cooldown check
	if _IsOnCooldown then return end
	_IsOnCooldown = true

	-- Gán attributes để UI Hotbar bắt tín hiệu đồng bộ hoạt ảnh Cooldown
	Tool:SetAttribute("CooldownEndTime", os.clock() + COOLDOWN)
	Tool:SetAttribute("IsOnCooldown", true)

	local IcicleSkinId = PlayerStateHelper.GetEquippedIcicleSkinId(Player)

	-- Bắt đầu animation
	local Track = PlaySwingAnimation(IcicleSkinId)

	if Track then
		local HitPlayers = {}

		-- Lấy timing cửa sổ Hitbox từ AnimationConfig (per skin)
		local HitStartTime = AnimationConfig.GetHitStartTime(IcicleSkinId)
		local HitEndTime   = AnimationConfig.GetHitEndTime(IcicleSkinId)

		task.delay(HitStartTime, function()
			if _CurrentSwingTrack ~= Track then return end
			PlaySwingAudio(IcicleSkinId)
			StopHitboxPoll()
			StartHitboxPoll(HitPlayers)
		end)

		task.delay(HitEndTime, function()
			StopHitboxPoll()
		end)

		Track.Stopped:Connect(function()
			StopHitboxPoll()
		end)
	end

	-- Hồi chiêu
	task.wait(COOLDOWN)
	_IsOnCooldown = false
	Tool:SetAttribute("IsOnCooldown", false)
end)
