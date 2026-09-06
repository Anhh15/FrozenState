-- SoundController.lua (ModuleScript)
-- Quản lý âm thanh SFX 3D (Freeze/Thaw/Swing) phía client
-- Nạp trước toàn bộ Asset âm thanh khi khởi động game (0ms delay)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer

local PlayFreezeSFXEvent
local PlayThawSFXEvent

-- =========================================================
-- PUBLIC API
-- =========================================================

local SoundController = {}

function SoundController:Init()
	-- 1. Preload toàn bộ Audio vào RAM của Client ngay khi vào game
	AudioHelper.PreloadAllGameAudios()

	PlayFreezeSFXEvent = RemoteDefinitions.GetEvent("PlayFreezeSFX")
	PlayThawSFXEvent   = RemoteDefinitions.GetEvent("PlayThawSFX")
	local PlaySwingSFXEvent  = RemoteDefinitions.GetEvent("PlaySwingSFX")

	-- 2. Lắng nghe Freeze SFX từ Server (Broadcast đến toàn bộ Client)
	PlayFreezeSFXEvent.OnClientEvent:Connect(function(Payload)
		if not Payload then return end
		local BlockSkinId = Payload.BlockSkinId or "Default"
		local FreezeSoundEntry = AudioConfig.GetFreezeAudio(BlockSkinId)

		-- Tìm Character của nạn nhân để phát Spatial Sound 3D
		local TargetChar = Payload.VictimCharacter or (Payload.VictimPlayer and Payload.VictimPlayer.Character)
		if TargetChar then
			AudioHelper.PlaySpatialSound(TargetChar, FreezeSoundEntry)
		end
	end)

	-- 3. Lắng nghe Thaw SFX từ Server (Broadcast đến toàn bộ Client)
	PlayThawSFXEvent.OnClientEvent:Connect(function(Payload)
		local BlockSkinId = (Payload and Payload.BlockSkinId) or "Default"
		local ThawSoundEntry = AudioConfig.GetThawAudio(BlockSkinId)

		-- Tìm Character của nạn nhân để phát Spatial Sound 3D
		local TargetChar = Payload and (Payload.VictimCharacter or (Payload.VictimPlayer and Payload.VictimPlayer.Character))
		if TargetChar then
			AudioHelper.PlaySpatialSound(TargetChar, ThawSoundEntry)
		end
	end)

	-- 4. Lắng nghe Swing SFX từ Server (Broadcast 3D Spatial Sound khi người chơi khác vung vũ khí)
	PlaySwingSFXEvent.OnClientEvent:Connect(function(Payload)
		if not Payload then return end

		-- Bỏ qua nếu chính là LocalPlayer (vì LocalPlayer đã phát local Sound Pool với 0ms delay)
		if Payload.Player == LocalPlayer then return end

		local TargetChar = Payload.Character or (Payload.Player and Payload.Player.Character)
		if TargetChar and TargetChar.Parent then
			local IcicleSkinId = Payload.IcicleSkinId or "Default"
			local SwingSoundEntry = AudioConfig.GetSwingAudios(IcicleSkinId)
			AudioHelper.PlaySpatialSound(TargetChar, SwingSoundEntry)
		end
	end)

	print("[SoundController] Đã khởi tạo và nạp trước toàn bộ SFX.")
end

return SoundController
