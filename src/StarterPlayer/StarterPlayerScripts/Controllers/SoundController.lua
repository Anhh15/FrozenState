-- SoundController.lua (ModuleScript)
-- Quản lý âm thanh SFX 3D (Freeze/Thaw) và pose animation phía client
-- Nạp trước toàn bộ Asset âm thanh & hoạt ảnh khi khởi động game (0ms delay)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AnimationConfig   = require(ReplicatedStorage.Shared.Config.AnimationConfig)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local AnimationHelper   = require(ReplicatedStorage.Shared.Tools.AnimationHelper)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local _PoseTrack  = nil  -- AnimationTrack hiện tại (pose khi bị đóng băng)

local PlayFreezeSFXEvent
local PlayThawSFXEvent

-- =========================================================
-- PRIVATE: Animation
-- =========================================================

--- Play pose animation trên Animator của local player
--- Lưu track để có thể dừng khi Thaw
--- @param BlockSkinId string — SkinId của Block gây ra Freeze (để lookup override)
local function PlayPoseAnimation(BlockSkinId)
	-- Dừng track cũ nếu còn đang chạy
	if _PoseTrack then
		AnimationHelper.StopTrack(_PoseTrack)
		_PoseTrack = nil
	end

	local Character = LocalPlayer.Character
	if not Character then return end

	local AnimId = AnimationConfig.GetPoseAnimation(BlockSkinId)
	local Track = AnimationHelper.LoadTrack(Character, AnimId, {
		Looped   = true,
		Priority = Enum.AnimationPriority.Action,
	})

	if Track then
		AnimationHelper.PlayTrack(Track)
		_PoseTrack = Track
	end
end

--- Dừng pose animation hiện tại
local function StopPoseAnimation()
	if _PoseTrack then
		AnimationHelper.StopTrack(_PoseTrack)
		_PoseTrack = nil
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local SoundController = {}

function SoundController:Init()
	-- 1. Preload toàn bộ Audio & Animation vào RAM của Client ngay khi vào game
	AudioHelper.PreloadAllGameAudios()
	AnimationHelper.PreloadAllGameAnimations()

	PlayFreezeSFXEvent = RemoteDefinitions.GetEvent("PlayFreezeSFX")
	PlayThawSFXEvent   = RemoteDefinitions.GetEvent("PlayThawSFX")

	-- 2. Lắng nghe Freeze SFX từ Server (Broadcast đến toàn bộ Client)
	PlayFreezeSFXEvent.OnClientEvent:Connect(function(Payload)
		if not Payload then return end
		local BlockSkinId = Payload.BlockSkinId or "Default"
		local FreezeSoundId = AudioConfig.GetFreezeAudio(BlockSkinId)

		-- Tìm Character của nạn nhân để phát Spatial Sound 3D
		local TargetChar = Payload.VictimCharacter or (Payload.VictimPlayer and Payload.VictimPlayer.Character)
		if TargetChar then
			AudioHelper.PlaySpatialSound(TargetChar, FreezeSoundId)
		end

		-- Nếu chính LocalPlayer là nạn nhân → Kích hoạt pose animation
		if Payload.VictimPlayer == LocalPlayer then
			PlayPoseAnimation(BlockSkinId)
		end
	end)

	-- 3. Lắng nghe Thaw SFX từ Server (Broadcast đến toàn bộ Client)
	PlayThawSFXEvent.OnClientEvent:Connect(function(Payload)
		local BlockSkinId = (Payload and Payload.BlockSkinId) or "Default"
		local ThawSoundId = AudioConfig.GetThawAudio(BlockSkinId)

		-- Tìm Character của nạn nhân để phát Spatial Sound 3D
		local TargetChar = Payload and (Payload.VictimCharacter or (Payload.VictimPlayer and Payload.VictimPlayer.Character))
		if TargetChar then
			AudioHelper.PlaySpatialSound(TargetChar, ThawSoundId)
		end

		-- Nếu chính LocalPlayer được giải cứu → Dừng pose animation
		if not Payload or Payload.VictimPlayer == LocalPlayer or (TargetChar and TargetChar == LocalPlayer.Character) then
			StopPoseAnimation()
		end
	end)

	-- Dừng animation khi character respawn (tránh animation ghost)
	LocalPlayer.CharacterAdded:Connect(function()
		_PoseTrack = nil
	end)

	print("[SoundController] Đã khởi tạo và nạp trước toàn bộ SFX & Animation.")
end

return SoundController
