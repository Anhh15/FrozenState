-- MusicController.lua (ModuleScript)
-- Quản lý nhạc nền cho local player dựa trên phase của match và trạng thái GameLoading
--
-- Logic:
--   1. Đang ở GameLoading:
--      - Có cấu hình AudioConfig.Music.GameLoading → Phát nhạc GameLoading
--      - Không cấu hình (nil/0)                  → Giữ im lặng hoàn toàn
--
--   2. Đã hoàn tất GameLoading:
--      - Phase GameOver                          → Nhạc GameOver
--      - Có team/InMatch:
--          - InGame + FrozenState                → Nhạc FrozenState
--          - InGame (bình thường)                → Nhạc InGame
--          - Không InGame                        → Nhạc Lobby
--      - Không có team/Spectator:
--          - Phase GameOver                      → Nhạc GameOver (thông báo kết thúc trận)
--          - Các phase khác                      → Nhạc Lobby
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
_BgmSound.Volume   = (AudioConfig.Music and AudioConfig.Music.DefaultVolume) or 0.5
_BgmSound.Parent   = SoundService

-- SoundId đang phát (để tránh restart nhạc khi không cần)
local _CurrentSoundId = nil

local UpdateGameStateEvent

-- =========================================================
-- PRIVATE
-- =========================================================

--- Xác định nhạc cần phát dựa trên trạng thái hiện tại
--- @return number? — SoundId cần phát (hoặc nil nếu giữ im lặng)
local function ResolveMusicId()
	-- 1. Nếu chưa tải xong màn hình GameLoadingScreen ban đầu
	if not _IsGameLoaded then
		return AudioConfig.Music and AudioConfig.Music.GameLoading
	end

	-- 2. Đang ở phase GameOver (thông báo kết thúc trận đấu)
	if _CurrentPhase == "GameOver" then
		return AudioConfig.Music and AudioConfig.Music.GameOver
	end

	-- 3. Đang trong trận đấu (InMatch)
	local IsInMatch = PlayerStateHelper.IsInMatch(LocalPlayer)
	if IsInMatch then
		if _CurrentPhase == "InGame" then
			if _IsFrozenState then
				return AudioConfig.Music.FrozenState
			else
				return AudioConfig.Music.InGame
			end
		else
			return AudioConfig.Music.Lobby
		end
	else
		-- Spectator / Người chơi ở Sảnh
		return AudioConfig.Music.Lobby
	end
end

--- Áp dụng nhạc nền theo SoundId
--- Nếu nhạc này đang phát thì không làm gì (tránh restart giữa chừng)
--- Hỗ trợ SoundId là nil/0 để dừng nhạc an toàn
--- @param SoundId number?
local function ApplyMusic(SoundId)
	if _CurrentSoundId == SoundId then return end
	_CurrentSoundId = SoundId

	local TargetVolume = (AudioConfig.Music and AudioConfig.Music.DefaultVolume) or 0.5

	if not SoundId or SoundId == 0 then
		_BgmSound:Stop()
		_BgmSound.SoundId = ""
		return
	end

	_BgmSound:Stop()
	_BgmSound.SoundId = "rbxassetid://" .. tostring(SoundId)
	_BgmSound.Volume  = TargetVolume
	_BgmSound:Play()
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

