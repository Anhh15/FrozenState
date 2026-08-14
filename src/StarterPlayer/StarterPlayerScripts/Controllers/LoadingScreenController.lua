-- LoadingScreenController.lua (ModuleScript)
-- Quan ly man hinh chuyen canh LoadingScreen khi bat dau tran dau
-- Chi hien voi player co team (tham gia tran), Spectator khong thay
--
-- Luong:
--   Setup  -> fade-in  (BackgroundTransparency: 1 -> 0, trong FadeInDuration giay)
--   Ready  -> hold HoldDuration giay -> fade-out (0 -> 1) -> Visible = false
--   InGame -> safety net: an ngay lap tuc neu Ready ket thuc som

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)

-- =========================================================
-- CONFIG
-- =========================================================

local FADE_IN_DURATION  = GameConfig.GUI.LoadingScreen.FadeInDuration
local HOLD_DURATION     = GameConfig.GUI.LoadingScreen.HoldDuration
local FADE_OUT_DURATION = GameConfig.GUI.LoadingScreen.FadeOutDuration

local TWEEN_FADE_IN  = TweenInfo.new(FADE_IN_DURATION,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_FADE_OUT = TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- =========================================================
-- GUI REFERENCES (lazy-init trong Init de tranh race condition)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _LoadingScreen = nil  -- Frame: InGameGui/LoadingScreen

-- =========================================================
-- STATE
-- =========================================================

local _activeTween    = nil   -- Tween dang chay (de cancel khi can)
local _fadeOutTask    = nil   -- task.delay handle cho fade-out sau hold
local _lastPhase      = ""    -- Phase nhan duoc lan cuoi

-- =========================================================
-- PRIVATE
-- =========================================================

--- Cancel tween va task dang chay (don dep truoc khi bat dau animation moi)
local function CancelPending()
	if _activeTween then
		_activeTween:Cancel()
		_activeTween = nil
	end
	if _fadeOutTask then
		task.cancel(_fadeOutTask)
		_fadeOutTask = nil
	end
end

--- An LoadingScreen ngay lap tuc (safety net hoac reset)
local function ForceHide()
	CancelPending()
	if _LoadingScreen then
		_LoadingScreen.BackgroundTransparency = 1
		_LoadingScreen.Visible = false
	end
end

--- Bat dau fade-in: hien man hinh roi tween transparency 1 -> 0
local function StartFadeIn()
	if not _LoadingScreen then return end

	-- Chi hien voi player tham gia tran (InMatch = true hoac co Team)
	local IsInMatch = (LocalPlayer:GetAttribute("InMatch") == true) or (LocalPlayer:GetAttribute("Team") ~= nil)
	if not IsInMatch then return end

	CancelPending()

	_LoadingScreen.BackgroundTransparency = 1
	_LoadingScreen.Visible = true

	local Tween = TweenService:Create(_LoadingScreen, TWEEN_FADE_IN, {
		BackgroundTransparency = 0,
	})
	_activeTween = Tween
	Tween:Play()
	Tween.Completed:Connect(function()
		if _activeTween == Tween then
			_activeTween = nil
		end
	end)
end

--- Bat dau fade-out sau HoldDuration giay (danh cho Ready state)
local function StartFadeOutSequence()
	if not _LoadingScreen then return end
	if not _LoadingScreen.Visible then return end  -- Neu khong dang hien thi khong can

	CancelPending()

	-- Hold HoldDuration giay roi fade-out
	_fadeOutTask = task.delay(HOLD_DURATION, function()
		_fadeOutTask = nil

		-- Neu da bi force-hide (phase nhay sang InGame) thi bo qua
		if not _LoadingScreen.Visible then return end

		local Tween = TweenService:Create(_LoadingScreen, TWEEN_FADE_OUT, {
			BackgroundTransparency = 1,
		})
		_activeTween = Tween
		Tween:Play()
		Tween.Completed:Connect(function()
			if _activeTween == Tween then
				_activeTween = nil
				_LoadingScreen.Visible = false
			end
		end)
	end)
end

--- Xu ly khi nhan UpdateGameState tu server
--- @param Phase string
local function OnPhaseChanged(Phase)
	-- Tranh xu ly lap cung phase
	if Phase == _lastPhase then return end
	_lastPhase = Phase

	if Phase == "Setup" then
		StartFadeIn()

	elseif Phase == "Ready" then
		StartFadeOutSequence()

	else
		-- InGame, GameOver, Intermission -> an ngay (safety net)
		ForceHide()
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local LoadingScreenController = {}

function LoadingScreenController:Init()
	-- Lay GUI reference - WaitForChild khong timeout de tranh race condition
	local InGameGui  = PlayerGui:WaitForChild("InGameGui")
	_LoadingScreen   = InGameGui:WaitForChild("LoadingScreen")

	-- Dam bao trang thai ban dau la an
	_LoadingScreen.BackgroundTransparency = 1
	_LoadingScreen.Visible = false

	-- Lang nghe UpdateGameState (cung remote voi GameStateController)
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		OnPhaseChanged(Data.Phase or "Intermission")
	end)

	print("[LoadingScreenController] Da khoi tao.")
end

return LoadingScreenController
