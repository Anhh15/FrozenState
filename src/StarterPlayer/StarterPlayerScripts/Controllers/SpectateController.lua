-- SpectateController.lua (ModuleScript)
-- Quản lý chế độ Spectate: cho phép Spectator (không có team) quan sát
-- người chơi đang trong trận bằng Orbit Camera
-- Cycling qua danh sách target bằng Next/Back buttons
-- Tự động tắt khi phase rời InGame hoặc danh sách target rỗng

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- GUI REFERENCES (resolve lười trong Init để tránh lỗi timing)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

-- Biến sẽ được gán trong Init() sau khi GUI đã load xong
local MenuGui
local SpectateGui
local CloseButton
local NextButton
local BackButton
local PlayerNameText

-- Lazy-require MenuController để đóng menu khi bắt đầu Spectate
local _menuController = nil
local function GetMenuController()
	if not _menuController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("MenuController")
		if Module then
			_menuController = require(Module)
		end
	end
	return _menuController
end

-- Lazy-require NavigationController để ẩn/hiện thanh nút điều hướng
local _navigationController = nil
local function GetNavigationController()
	if not _navigationController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("NavigationController")
		if Module then
			_navigationController = require(Module)
		end
	end
	return _navigationController
end

-- =========================================================
-- STATE
-- =========================================================

local _isSpectating       = false   -- Đang trong chế độ spectate?
local _targetList         = {}      -- Danh sách Player objects Normal (từ server)
local _currentIndex       = 1       -- Vị trí hiện tại trong vòng lặp
local _savedCameraSubject = nil     -- Lưu CameraSubject gốc để restore
local _currentPhase       = "Intermission"  -- Cache phase hiện tại

-- Remote
local RequestSpectateTargetEvent

-- Streaming: thời gian tối đa chờ Character stream in sau khi ReplicationFocus được set
local STREAM_WAIT_TIMEOUT  = 5    -- giây
local STREAM_POLL_INTERVAL = 0.1  -- giây

--- Phát âm thanh GUI qua GuiHelper
local function PlayGuiSound(SoundId)
	GuiHelper.PlayGuiSound(SoundId)
end

-- =========================================================
-- PRIVATE: Movement Lock
-- =========================================================

--- Khóa di chuyển của spectator trong khi đang xem
--- Ngăn character trôi dạt khi ReplicationFocus được dời sang đấu trường
local function LockSpectatorMovement()
	local Character = LocalPlayer.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	Humanoid.WalkSpeed  = 0
	Humanoid.JumpPower  = 0
	Humanoid.JumpHeight = 0
end

--- Khôi phục di chuyển của spectator sau khi tắt spectate
local function UnlockSpectatorMovement()
	local Character = LocalPlayer.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	Humanoid.WalkSpeed  = GameConfig.Player.DefaultWalkSpeed
	Humanoid.JumpPower  = GameConfig.Player.DefaultJumpPower
	Humanoid.JumpHeight = GameConfig.Player.DefaultJumpHeight
end

-- =========================================================
-- PRIVATE: Camera
-- =========================================================

--- Hướng camera Orbit vào target player
--- Gửi RequestSpectateTarget lên server để server set ReplicationFocus,
--- sau đó poll chờ Character được stream in rồi mới set CameraSubject
local function FocusOnTarget(TargetPlayer)
	if not TargetPlayer then return end

	task.spawn(function()
		-- Bước 1: Yêu cầu server set ReplicationFocus vào target
		-- Engine sẽ tự stream world xung quanh target về cho client này
		RequestSpectateTargetEvent:FireServer(TargetPlayer)

		-- Bước 2: Poll chờ Character stream in (tối đa STREAM_WAIT_TIMEOUT giây)
		local Elapsed = 0
		while Elapsed < STREAM_WAIT_TIMEOUT do
			local Character = TargetPlayer.Character
			if Character then
				local Humanoid = Character:FindFirstChildOfClass("Humanoid")
				if Humanoid then
					Camera.CameraSubject = Humanoid
					return
				end
			end
			task.wait(STREAM_POLL_INTERVAL)
			Elapsed = Elapsed + STREAM_POLL_INTERVAL
		end

		warn("[SpectateController] Timeout chờ Character của "
			.. TargetPlayer.Name .. " sau " .. STREAM_WAIT_TIMEOUT .. "s")
	end)
end

--- Khôi phục camera về nhân vật của LocalPlayer
local function RestoreCamera()
	if _savedCameraSubject then
		Camera.CameraSubject = _savedCameraSubject
		_savedCameraSubject = nil
	else
		-- Fallback: khôi phục về Humanoid của LocalPlayer
		local Character = LocalPlayer.Character
		if Character then
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				Camera.CameraSubject = Humanoid
			end
		end
	end
end

-- =========================================================
-- PRIVATE: Display
-- =========================================================

--- Cập nhật tên người đang được quan sát
local function UpdatePlayerNameDisplay()
	if not PlayerNameText then return end

	if #_targetList == 0 or _currentIndex > #_targetList then
		PlayerNameText.Text = ""
		return
	end

	local Target = _targetList[_currentIndex]
	if Target and Target:IsDescendantOf(Players) then
		PlayerNameText.Text = Target.DisplayName .. " (@" .. Target.Name .. ")"
	else
		PlayerNameText.Text = ""
	end
end

--- Chuyển camera sang target hiện tại
local function ApplyCurrentTarget()
	if #_targetList == 0 then return end

	-- Đảm bảo index hợp lệ
	if _currentIndex > #_targetList then
		_currentIndex = 1
	end
	if _currentIndex < 1 then
		_currentIndex = #_targetList
	end

	FocusOnTarget(_targetList[_currentIndex])
	UpdatePlayerNameDisplay()
end

-- =========================================================
-- PRIVATE: Cycling
-- =========================================================

local function CycleNext()
	if not _isSpectating or #_targetList == 0 then return end
	_currentIndex = (_currentIndex % #_targetList) + 1
	ApplyCurrentTarget()
end

local function CycleBack()
	if not _isSpectating or #_targetList == 0 then return end
	_currentIndex = ((_currentIndex - 2) % #_targetList) + 1
	ApplyCurrentTarget()
end

-- =========================================================
-- PRIVATE: Target List Update
-- =========================================================

--- Xử lý khi server gửi danh sách Spectate mới
local function OnSpectateListUpdated(NormalPlayers)
	_targetList = NormalPlayers or {}

	if not _isSpectating then return end

	-- Nếu danh sách rỗng → tự động tắt spectate
	if #_targetList == 0 then
		-- Gọi SetVisible qua pcall để tránh stack overflow nếu có edge case
		task.defer(function()
			local SpectateController = require(script)
			SpectateController.SetVisible(false)
		end)
		return
	end

	-- Kiểm tra target hiện tại còn trong danh sách không
	local CurrentTarget = nil
	if _currentIndex >= 1 and _currentIndex <= #_targetList then
		-- Index cũ có thể đã shift, cần tìm lại
	end

	-- Tìm player đang focus trong danh sách mới
	local CurrentSubject = Camera.CameraSubject
	local FoundIndex = nil

	if CurrentSubject then
		for i, Player in ipairs(_targetList) do
			local Character = Player.Character
			if Character then
				local Humanoid = Character:FindFirstChildOfClass("Humanoid")
				if Humanoid == CurrentSubject then
					FoundIndex = i
					break
				end
			end
		end
	end

	if FoundIndex then
		-- Target vẫn còn, cập nhật index
		_currentIndex = FoundIndex
		UpdatePlayerNameDisplay()
	else
		-- Target đã biến mất → chuyển sang người kế tiếp
		if _currentIndex > #_targetList then
			_currentIndex = 1
		end
		ApplyCurrentTarget()
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local SpectateController = {}

--- Trả về trạng thái đang spectate hay không
--- Được dùng bởi GameStateController để tránh conflict NavGui
--- @return boolean
function SpectateController.IsSpectating()
	return _isSpectating
end

--- Bật/tắt chế độ Spectate
--- @param Visible boolean
function SpectateController.SetVisible(Visible)
	if Visible then
		-- Kiểm tra điều kiện bật
		if PlayerStateHelper.IsInMatch(LocalPlayer) then
			-- Đang trong trận → không thể spectate
			return
		end

		if _currentPhase ~= "InGame" then
			-- Không phải phase InGame → không thể spectate
			return
		end

		if #_targetList == 0 then
			-- Không có ai để quan sát
			return
		end

		-- Bật spectate
		_isSpectating = true
		_currentIndex = 1

		-- Lock movement: ngăn character trôi dạt khi ReplicationFocus dời sang đấu trường
		LockSpectatorMovement()

		-- Lưu camera hiện tại
		_savedCameraSubject = Camera.CameraSubject

		-- Hiện Spectate GUI, ẩn NavigationButtons và đóng các menu khác
		if SpectateGui then SpectateGui.Visible = true end
		
		local MenuCtrl = GetMenuController()
		if MenuCtrl then
			MenuCtrl.CloseAll()
		end

		local NavCtrl = GetNavigationController()
		if NavCtrl then
			NavCtrl.SetVisible(false)
		end

		-- Focus vào target đầu tiên
		ApplyCurrentTarget()

		print("[SpectateController] Chế độ Spectate đã bật.")
	else
		-- Tắt spectate
		if not _isSpectating and not (SpectateGui and SpectateGui.Visible) then
			return
		end

		_isSpectating = false

		-- Khôi phục movement trước khi restore camera
		UnlockSpectatorMovement()

		-- Yêu cầu server reset ReplicationFocus về chính spectator
		-- Đảm bảo engine stream lại khu vực lobby nơi character spectator đứng
		if RequestSpectateTargetEvent then
			RequestSpectateTargetEvent:FireServer(nil)
		end

		-- Ẩn Spectate GUI, hiện lại NavigationButtons
		if SpectateGui then SpectateGui.Visible = false end

		local NavCtrl = GetNavigationController()
		if NavCtrl then
			NavCtrl.SetVisible(true)
		end

		-- Khôi phục camera
		RestoreCamera()

		print("[SpectateController] Chế độ Spectate đã tắt.")
	end
end

-- =========================================================
-- INIT
-- =========================================================

function SpectateController:Init()
	-- Resolve toàn bộ GUI references
	MenuGui     = GuiHelper.GetScreenGui("Menu")
	SpectateGui = MenuGui and MenuGui:WaitForChild("Spectate")

	if SpectateGui then
		CloseButton  = SpectateGui:WaitForChild("CloseButton")
		NextButton   = SpectateGui:WaitForChild("NextButton")
		BackButton   = SpectateGui:WaitForChild("BackButton")
		local PlayerNameFrame = SpectateGui:WaitForChild("PlayerName")
		PlayerNameText = PlayerNameFrame:WaitForChild("PlayerNameText")
		SpectateGui.Visible = false
	end

	-- Kết nối các nút điều khiển
	CloseButton.MouseButton1Click:Connect(function()
		PlayGuiSound(AudioConfig.Gui.CloseButtonClick)
		SpectateController.SetVisible(false)
	end)

	NextButton.MouseButton1Click:Connect(function()
		PlayGuiSound(AudioConfig.Gui.ButtonClick)
		CycleNext()
	end)

	BackButton.MouseButton1Click:Connect(function()
		PlayGuiSound(AudioConfig.Gui.ButtonClick)
		CycleBack()
	end)

	-- Lắng nghe danh sách Spectate từ server
	local UpdateSpectateListEvent = RemoteDefinitions.GetEvent("UpdateSpectateList")
	UpdateSpectateListEvent.OnClientEvent:Connect(OnSpectateListUpdated)

	-- Resolve remote để gửi yêu cầu ReplicationFocus lên server
	RequestSpectateTargetEvent = RemoteDefinitions.GetEvent("RequestSpectateTarget")

	-- Lắng nghe phase game để auto-close khi rời InGame
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		local Phase = Data.Phase or "Intermission"
		_currentPhase = Phase

		-- Tự động tắt spectate khi phase rời InGame
		if _isSpectating and Phase ~= "InGame" then
			SpectateController.SetVisible(false)
		end
	end)

	-- Tự động tắt spectate khi player được đưa vào trận
	PlayerStateHelper.ObserveMatchState(LocalPlayer, function(IsInMatch)
		if IsInMatch and _isSpectating then
			SpectateController.SetVisible(false)
		end
	end)

	print("[SpectateController] Đã khởi tạo.")
end

return SpectateController
