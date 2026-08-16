-- SoundController.lua (ModuleScript)
-- Quản lý pose animation phía client cho local player
-- Lắng nghe PlayFreezeSFX → play pose animation khi bị đóng băng
-- Lắng nghe PlayThawSFX   → dừng pose animation khi được giải cứu

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AnimationConfig   = require(ReplicatedStorage.Shared.Config.AnimationConfig)
local AnimationHelper   = require(ReplicatedStorage.Shared.Tools.AnimationHelper)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local _PoseTrack  = nil  -- AnimationTrack hiện tại (pose khi bị đóng băng)

local PlayFreezeSFXEvent
local PlayThawSFXEvent

-- =========================================================
-- PRIVATE
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
	PlayFreezeSFXEvent = RemoteDefinitions.GetEvent("PlayFreezeSFX")
	PlayThawSFXEvent   = RemoteDefinitions.GetEvent("PlayThawSFX")

	-- Server báo bị đóng băng → play pose animation
	PlayFreezeSFXEvent.OnClientEvent:Connect(function(Payload)
		local BlockSkinId = (Payload and Payload.BlockSkinId) or "Default"
		PlayPoseAnimation(BlockSkinId)
	end)

	-- Server báo được giải cứu → dừng pose animation
	PlayThawSFXEvent.OnClientEvent:Connect(function()
		StopPoseAnimation()
	end)

	-- Dừng animation khi character respawn (tránh animation ghost)
	LocalPlayer.CharacterAdded:Connect(function()
		_PoseTrack = nil
	end)

	print("[SoundController] Đã khởi tạo.")
end

return SoundController
