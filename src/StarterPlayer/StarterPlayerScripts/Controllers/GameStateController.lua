-- GameStateController.lua (ModuleScript)
-- Điều khiển GUI GameState: cập nhật tên phase và thời gian đếm ngược
-- Đồng thời quản lý visibility của các lobby GUI (Menu, NavigationButtons)
-- theo phase: ẩn khi Ready/InGame, hiện lại khi Intermission/GameOver
-- GUI cần có: Frame/TimeText, Frame/StateText, Frame/TimeShadowText, Frame/StateShadowText

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- GameState HUD (luôn hiện)
local GameStateGui    = GuiHelper.GetScreenGui("GameState")
local Frame           = GameStateGui:WaitForChild("Frame")
local TimeText        = Frame:WaitForChild("TimeText")
local StateText       = Frame:WaitForChild("StateText")
local TimeShadowText  = Frame:WaitForChild("TimeShadowText")
local StateShadowText = Frame:WaitForChild("StateShadowText")

-- Lobby GUIs (ẩn khi Ready/InGame)
local MenuGui = GuiHelper.GetScreenGui("Menu")
local NavGui  = GuiHelper.GetNavigationGui()

-- InGameGui và các thành phần gameplay HUD (quản lý ẩn/hiện theo phase)
local InGameGui        = GuiHelper.GetScreenGui("InGameGui")
local PlayerStatus     = InGameGui and InGameGui:WaitForChild("PlayerStatus", 10)
local ScoreBoard       = InGameGui and InGameGui:WaitForChild("ScoreBoard", 10)
local ScoreBoardButton = InGameGui and InGameGui:FindFirstChild("ScoreBoardButton")

-- Inventory nằm bên trong Menu — lazy-require để tránh circular load
-- InventoryController được load sau bởi Main.client.lua
local _inventoryController = nil
local function GetInventoryController()
	if not _inventoryController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("InventoryController")
		if Module then
			_inventoryController = require(Module)
		end
	end
	return _inventoryController
end

-- Profile nằm bên trong Menu — lazy-require để tránh circular load
-- ProfileController được load sau bởi Main.client.lua
local _profileController = nil
local function GetProfileController()
	if not _profileController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("ProfileController")
		if Module then
			_profileController = require(Module)
		end
	end
	return _profileController
end

-- Shop nằm bên trong Menu — lazy-require để tránh circular load
-- ShopController được load sau bởi Main.client.lua
local _shopController = nil
local function GetShopController()
	if not _shopController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("ShopController")
		if Module then
			_shopController = require(Module)
		end
	end
	return _shopController
end

-- ItemRewardController — lazy-require để tránh circular load
local _itemRewardController = nil
local function GetItemRewardController()
	if not _itemRewardController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("ItemRewardController")
		if Module then
			_itemRewardController = require(Module)
		end
	end
	return _itemRewardController
end

-- Spectate nằm bên trong Menu — lazy-require để tránh circular load
-- SpectateController được load sau bởi Main.client.lua
local _spectateController = nil
local function GetSpectateController()
	if not _spectateController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("SpectateController")
		if Module then
			_spectateController = require(Module)
		end
	end
	return _spectateController
end

-- Quest nằm bên trong Menu — lazy-require để tránh circular load
local _questController = nil
local function GetQuestController()
	if not _questController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("QuestController")
		if Module then
			_questController = require(Module)
		end
	end
	return _questController
end

-- PlayerDataController — lazy-require để làm mới hiển thị tiền khi cần
local _playerDataController = nil
local function GetPlayerDataController()
	if not _playerDataController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("PlayerDataController")
		if Module then
			_playerDataController = require(Module)
		end
	end
	return _playerDataController
end

-- =========================================================
-- CONFIG
-- =========================================================

-- Tên hiển thị cho từng phase (Setup ẩn sau "Intermission")
local PHASE_DISPLAY = {
	Intermission = "INTERMISSION",
	Setup        = "INTERMISSION",
	Ready        = "READY",
	InGame       = "IN GAME",
	GameOver     = "GAME OVER",
}

-- Phase mà lobby GUI phải bị ẩn (chỉ áp dụng khi player đang trong trận, tức là có Team)
local GAMEPLAY_PHASES = {
	Ready    = true,
	InGame   = true,
	GameOver = true,  -- Ẩn GUI trong 6s đếm ngược sau trận, trước khi về Lobby
}

-- Cache phase hiện tại để re-evaluate GUI khi Attribute Team thay đổi
local _lastPhase          = "Intermission"
local _lastTimeRemaining  = 0
local _lastIsFrozenState  = false
local _playerStatusType   = "TwoTeams"
local _scoreboardType     = "TwoTeams"

-- =========================================================
-- HELPERS
-- =========================================================

-- SFX IDs
local SFX_BUTTON_CLICK  = 7249903719
local SFX_MOUSE_ENTER   = 137872392480008

--- Phát âm thanh GUI bất đồng bộ (Sound object tự hủy sau khi phát xong)
--- @param SoundId number
local function PlayGuiSound(SoundId)
	local S = Instance.new("Sound")
	S.SoundId = "rbxassetid://" .. tostring(SoundId)
	S.Volume = 1
	S.Parent = PlayerGui
	S:Play()
	game:GetService("Debris"):AddItem(S, 3)
end

local function FormatTime(Seconds)
	local M = math.floor(Seconds / 60)
	local S = Seconds % 60
	return string.format("%02d:%02d", M, S)
end

--- Ẩn/hiện các lobby GUI theo phase và trạng thái team của LocalPlayer
--- Spectator (chưa có team) luôn thấy GUI dù ở phase nào
local function SetLobbyGuisVisible(Visible)
	if MenuGui then MenuGui.Enabled = Visible end

	-- NavGui: chỉ hiện khi Visible = true VÀ spectator không đang trong chế độ spectate
	-- Tránh conflict với SpectateController (SpectateController tự quản lý NavGui.Enabled)
	if NavGui then
		local IsSpectating = false
		local SpecCtrl = GetSpectateController()
		if SpecCtrl and SpecCtrl.IsSpectating then
			IsSpectating = SpecCtrl.IsSpectating()
		end
		NavGui.Enabled = Visible and not IsSpectating
	end

	if Visible then
		-- Làm mới số tiền hiển thị khi bật lại Lobby GUI
		local PlayerDataCtrl = GetPlayerDataController()
		if PlayerDataCtrl and PlayerDataCtrl.UpdateMoneyDisplay then
			PlayerDataCtrl.UpdateMoneyDisplay()
		end
	else
		-- Khi vào trận: buộc đóng Inventory, Profile, Shop, Spectate và hiệu ứng ItemReward nếu đang mở
		local InvCtrl = GetInventoryController()
		if InvCtrl then
			InvCtrl.SetVisible(false)
		end
		local ProfCtrl = GetProfileController()
		if ProfCtrl then
			ProfCtrl.SetVisible(false)
		end
		local ShopCtrl = GetShopController()
		if ShopCtrl then
			ShopCtrl.SetVisible(false)
		end
		local SpecCtrl = GetSpectateController()
		if SpecCtrl then
			SpecCtrl.SetVisible(false)
		end
		local QuestCtrl = GetQuestController()
		if QuestCtrl then
			QuestCtrl.SetVisible(false)
		end
		-- Reset hiệu ứng mở rương nếu đang chạy (phần thưởng vẫn an toàn vì đã được trao trước đó)
		local RewardCtrl = GetItemRewardController()
		if RewardCtrl then
			RewardCtrl.Reset()
		end
	end
end

local function UpdateDisplay(Phase, TimeRemaining, IsFrozenState)
	-- Cập nhật cache để re-evaluate khi Attribute Team thay đổi
	_lastPhase         = Phase
	_lastTimeRemaining = TimeRemaining
	_lastIsFrozenState = IsFrozenState

	local DisplayPhase = PHASE_DISPLAY[Phase] or Phase

	-- Thêm indicator khi FrozenState đang active
	if IsFrozenState and Phase == "InGame" then
		DisplayPhase = "❄  FROZEN STATE"
	end

	local TimeStr = FormatTime(TimeRemaining)

	StateText.Text       = DisplayPhase
	StateShadowText.Text = DisplayPhase
	TimeText.Text        = TimeStr
	TimeShadowText.Text  = TimeStr

	-- Kiểm tra xem LocalPlayer có đang trong trận không (hỗ trợ cả mode có team và FFA)
	local IsInMatch = PlayerStateHelper.IsInMatch(LocalPlayer)
	if IsInMatch then
		-- Player trong trận: ẩn/hiện theo phase
		SetLobbyGuisVisible(not GAMEPLAY_PHASES[Phase])
	else
		-- Spectator (chưa trong trận): luôn hiện GUI để đổi skin
		SetLobbyGuisVisible(true)
	end

	-- Quản lý hiển thị InGameGui và các gameplay HUD con
	local IsInGamePhase = (Phase == "Ready" or Phase == "InGame" or Phase == "GameOver")
	if InGameGui then
		InGameGui.Enabled = IsInGamePhase
	end

	local ShowGameplayHud = IsInGamePhase
	if PlayerStatus then
		PlayerStatus.Visible = ShowGameplayHud and (_playerStatusType ~= "Disabled")
	end
	if ScoreBoard then
		if not ShowGameplayHud or _scoreboardType == "Disabled" then
			ScoreBoard.Visible = false
		end
	end
	if ScoreBoardButton then
		ScoreBoardButton.Visible = ShowGameplayHud and (_scoreboardType ~= "Disabled")
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameStateController = {}

function GameStateController:Init()
	-- Ngăn GUI reset khi player chết (respawn)
	GameStateGui.ResetOnSpawn = false
	if NavGui then
		NavGui.ResetOnSpawn = false
	end

	-- Bind SFX cho các Button con/cháu trong NavigationButtons
	-- Mỗi button con/cháu (kể cả trong Extra): MouseEnter → SFX_MOUSE_ENTER | MouseButton1Click → SFX_BUTTON_CLICK
	GuiHelper.BindAllNavButtonsSound(SFX_BUTTON_CLICK, SFX_MOUSE_ENTER)

	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	local SetGameModeEvent     = RemoteDefinitions.GetEvent("SetGameMode")

	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if Data then
			_playerStatusType = Data.PlayerStatusType or "TwoTeams"
			_scoreboardType   = Data.ScoreboardType   or "TwoTeams"
			UpdateDisplay(_lastPhase, _lastTimeRemaining, _lastIsFrozenState)
		end
	end)

	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		local Phase = Data.Phase or "Intermission"
		if Phase == "Intermission" then
			_playerStatusType = "TwoTeams"
			_scoreboardType   = "TwoTeams"
		end
		UpdateDisplay(
			Phase,
			Data.TimeRemaining or 0,
			Data.IsFrozenState or false
		)
	end)

	-- Re-evaluate GUI ngay khi trạng thái tham gia trận thay đổi (InMatch hoặc Team)
	PlayerStateHelper.ObserveMatchState(LocalPlayer, function()
		UpdateDisplay(_lastPhase, _lastTimeRemaining, _lastIsFrozenState)
	end)

	-- Đặt trạng thái ban đầu (lobby)
	UpdateDisplay("Intermission", 0, false)

	print("[GameStateController] Đã khởi tạo.")
end

return GameStateController
