-- MusicController.lua (ModuleScript)
-- Quản lý nhạc nền cho local player dựa trên phase của match và trạng thái GameLoading
--
-- Logic:
--   1. Đang ở GameLoading:
--      - Có cấu hình AudioConfig.Music.GameLoading → Phát nhạc GameLoading (Volume.GameLoading)
--      - Không cấu hình (nil/0)                  → Giữ im lặng hoàn toàn
--
--   2. Đã hoàn tất GameLoading:
--      - Phase GameOver                          → Nhạc GameOver (Volume.GameOver)
--      - Có team/InMatch:
--          - InGame + FrozenState                → Nhạc FrozenState (Volume.FrozenState)
--          - InGame (bình thường)                → Nhạc InGame (Volume.InGame)
--          - Ready (chuẩn bị)                    → Nhạc Ready (Volume.Ready) hoặc fallback Lobby
--          - Không InGame/Ready                  → Nhạc Lobby (Volume.Lobby)
--      - Không có team/Spectator:
--          - Phase GameOver                      → Nhạc GameOver (thông báo kết thúc trận)
--          - Các phase khác                      → Nhạc Lobby (Volume.Lobby)
--
-- Chuyển nhạc: dừng ngay lập tức, play nhạc mới (không fade)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService      = game:GetService("SoundService")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer

-- Cache trạng thái mới nhất từ server & client
local _CurrentPhase   = "Intermission"
local _IsFrozenState  = false
local _IsGameLoaded   = false

-- Sound instance duy nhất để phát nhạc nền
-- Đặt trong SoundService → không spatial, phát toàn cục
local _BgmSound = Instance.new("Sound")
_BgmSound.Name     = "BackgroundMusic"
_BgmSound.Looped   = true
_BgmSound.Volume   = (AudioConfig.Music and AudioConfig.Music.DefaultVolume) or 0.3
_BgmSound.Parent   = SoundService

-- SoundId và MusicKey đang phát (để tránh restart nhạc khi không cần)
local _CurrentSoundId  = nil
local _CurrentMusicKey = nil

local UpdateGameStateEvent

-- =========================================================
-- PRIVATE
-- =========================================================

--- Xác định nhạc cần phát và Key định danh dựa trên trạng thái hiện tại
--- @return number?, string? — SoundId cần phát và MusicKey tương ứng
local function ResolveMusicId()
	-- 1. Nếu chưa tải xong màn hình GameLoadingScreen ban đầu
	if not _IsGameLoaded then
		return AudioConfig.Music and AudioConfig.Music.GameLoading, "GameLoading"
	end

	-- 2. Đang ở phase GameOver (thông báo kết thúc trận đấu)
	if _CurrentPhase == "GameOver" then
		return AudioConfig.Music and AudioConfig.Music.GameOver, "GameOver"
	end

	-- 3. Đang trong trận đấu (InMatch)
	local IsInMatch = PlayerStateHelper.IsInMatch(LocalPlayer)
	if IsInMatch then
		if _CurrentPhase == "InGame" then
			if _IsFrozenState then
				return AudioConfig.Music.FrozenState, "FrozenState"
			else
				return AudioConfig.Music.InGame, "InGame"
			end
		elseif _CurrentPhase == "Ready" then
			local ReadyMusicId = AudioConfig.Music and AudioConfig.Music.Ready
			if ReadyMusicId then
				return ReadyMusicId, "Ready"
			else
				return AudioConfig.Music.Lobby, "Lobby"
			end
		else
			return AudioConfig.Music.Lobby, "Lobby"
		end
	else
		-- Spectator / Người chơi ở Sảnh
		return AudioConfig.Music.Lobby, "Lobby"
	end
end

--- Áp dụng nhạc nền theo SoundId và MusicKey
--- Tự động cập nhật âm lượng cơ sở tương ứng cho từng track
--- Hỗ trợ SoundId là nil/0 để dừng nhạc an toàn
--- @param SoundId number?
--- @param MusicKey string?
local function ApplyMusic(SoundId, MusicKey)
	local TargetVolume = AudioConfig.GetMusicVolume(MusicKey)

	if not SoundId or SoundId == 0 then
		_CurrentSoundId = nil
		_CurrentMusicKey = nil
		_BgmSound:Stop()
		_BgmSound.SoundId = ""
		return
	end

	-- Cập nhật âm lượng cho track
	_BgmSound.Volume = TargetVolume

	-- Nếu cùng SoundId đang phát thì không khởi động lại
	if _CurrentSoundId == SoundId then return end
	_CurrentSoundId  = SoundId
	_CurrentMusicKey = MusicKey

	_BgmSound:Stop()
	_BgmSound.SoundId = "rbxassetid://" .. tostring(SoundId)
	_BgmSound:Play()
end

--- Cập nhật nhạc dựa trên trạng thái mới nhất
local function UpdateMusic()
	local SoundId, MusicKey = ResolveMusicId()
	ApplyMusic(SoundId, MusicKey)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local MusicController = {}

function MusicController:Init()
	UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")

	-- Lắng nghe cập nhật phase từ server
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		_CurrentPhase  = Data.Phase          or "Intermission"
		_IsFrozenState = Data.IsFrozenState  or false
		UpdateMusic()
	end)

	-- Lắng nghe thay đổi trạng thái tham gia trận (InMatch hoặc Team)
	PlayerStateHelper.ObserveMatchState(LocalPlayer, function()
		UpdateMusic()
	end)

	-- Lắng nghe trạng thái hoàn tất màn hình tải game (GameLoadingScreen)
	PlayerStateHelper.ObserveGameLoaded(LocalPlayer, function(IsLoaded)
		_IsGameLoaded = (IsLoaded == true)
		UpdateMusic()
	end)

	print("[MusicController] Đã khởi tạo.")
end

return MusicController

