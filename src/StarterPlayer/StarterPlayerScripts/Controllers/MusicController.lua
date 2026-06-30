-- MusicController.lua (ModuleScript)
-- Quản lý nhạc nền cho local player dựa trên phase của match và trạng thái spectate
--
-- Logic:
--   Có team (đang tham gia trận):
--     - InGame + FrozenState  → Nhạc FrozenState
--     - InGame (bình thường)  → Nhạc InGame
--     - Không InGame          → Nhạc Lobby
--
--   Không có team (spectator):
--     - Đang spectate + server InGame + FrozenState  → Nhạc FrozenState
--     - Đang spectate + server InGame                → Nhạc InGame
--     - Không spectate                               → Nhạc Lobby
--
-- Chuyển nhạc: dừng ngay lập tức, play nhạc mới (không fade)
-- Phase 8.1

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer

-- Cache trạng thái mới nhất từ server
local _currentPhase    = "Intermission"
local _isFrozenState   = false

-- Sound instance duy nhất để phát nhạc nền
-- Đặt trong SoundService → không spatial, phát toàn cục
local _bgmSound = Instance.new("Sound")
_bgmSound.Name     = "BackgroundMusic"
_bgmSound.Looped   = true
_bgmSound.Volume   = 0.5
_bgmSound.Parent   = SoundService

-- SkinId đang phát (để tránh restart nhạc khi không cần)
local _currentSoundId = nil

-- Lazy reference đến SpectateController (load sau Main để tránh circular)
local _spectateController = nil

local UpdateGameStateEvent

-- =========================================================
-- PRIVATE
-- =========================================================

--- Lấy lazy reference đến SpectateController
local function GetSpectateController()
	if not _spectateController then
		local Controllers = LocalPlayer
			:WaitForChild("PlayerScripts", 5)
			and LocalPlayer.PlayerScripts
		if Controllers then
			local Module = Controllers:FindFirstChild("Controllers")
				and Controllers.Controllers:FindFirstChild("SpectateController")
			if Module then
				_spectateController = require(Module)
			end
		end
	end
	return _spectateController
end

--- Xác định nhạc cần phát dựa trên trạng thái hiện tại
--- @return number — SoundId cần phát
local function ResolveMusicId()
	local HasTeam = LocalPlayer:GetAttribute("Team") ~= nil

	if HasTeam then
		-- Đang tham gia trận
		if _currentPhase == "InGame" then
			if _isFrozenState then
				return AudioConfig.Music.FrozenState
			else
				return AudioConfig.Music.InGame
			end
		else
			return AudioConfig.Music.Lobby
		end
	else
		-- Spectator hoặc lobby
		local SC = GetSpectateController()
		local IsSpectating = SC and SC.IsSpectating() or false

		if IsSpectating and _currentPhase == "InGame" then
			if _isFrozenState then
				return AudioConfig.Music.FrozenState
			else
				return AudioConfig.Music.InGame
			end
		else
			return AudioConfig.Music.Lobby
		end
	end
end

--- Áp dụng nhạc nền theo SoundId
--- Nếu nhạc này đang phát thì không làm gì (tránh restart giữa chừng)
--- @param SoundId number
local function ApplyMusic(SoundId)
	if _currentSoundId == SoundId then return end
	_currentSoundId = SoundId

	_bgmSound:Stop()
	_bgmSound.SoundId = "rbxassetid://" .. tostring(SoundId)
	_bgmSound:Play()
end

--- Cập nhật nhạc dựa trên trạng thái mới nhất
local function UpdateMusic()
	local SoundId = ResolveMusicId()
	ApplyMusic(SoundId)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local MusicController = {}

function MusicController:Init()
	UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")

	-- Lắng nghe cập nhật phase từ server
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		_currentPhase  = Data.Phase          or "Intermission"
		_isFrozenState = Data.IsFrozenState  or false
		UpdateMusic()
	end)

	-- Lắng nghe thay đổi team attribute (khi vào/ra trận)
	-- Khi server gán team cho local player, attribute "Team" thay đổi → update nhạc
	LocalPlayer:GetAttributeChangedSignal("Team"):Connect(function()
		UpdateMusic()
	end)

	-- Phát nhạc lobby ngay khi init (trước khi nhận UpdateGameState đầu tiên)
	ApplyMusic(AudioConfig.Music.Lobby)

	print("[MusicController] Đã khởi tạo.")
end

--- Được gọi bởi SpectateController khi trạng thái spectate thay đổi
--- Cho phép MusicController cập nhật nhạc ngay lập tức
function MusicController.OnSpectateChanged()
	UpdateMusic()
end

return MusicController
