-- SpectateController.lua (ModuleScript)
-- Quản lý chế độ Spectate:
--   (A) Lobby Spectator: người không trong trận quan sát toàn bộ Normal bằng Orbit Camera
--   (B) Frozen Spectator: người bị Frozen trong trận quan sát:
--         - Mode HasTeams → chỉ đồng minh cùng team
--         - Mode không HasTeams (FFA) → toàn bộ Normal
-- Cycling qua danh sách target bằng Next/Back buttons
-- Tự động tắt khi: phase rời InGame, danh sách target rỗng, được thaw, chết, respawn

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- GUI REFERENCES (resolve lười trong Init để tránh lỗi timing)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Biến sẽ được gán trong Init() sau khi GUI đã load xong
local ObserverGui  -- ScreenGui độc lập cho chế độ quan sát
local SpectateGui  -- Frame Spectate bên trong ObserverGui
local CloseButton
local NextButton
local BackButton
local PlayerNameText

-- InGameGui/Buttons: SpectateButton chỉ hiện khi bị Frozen
local InGameGuiRef         = nil
local ButtonsFrame         = nil
local InGameSpectateButton = nil  -- nút SpectateButton trong Buttons frame

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

local _isSpectating        = false   -- Đang trong chế độ spectate?
local _isFrozenSpectator   = false   -- Spectate với tư cách Frozen (trong trận)?
local _isFrozen            = false   -- LocalPlayer hiện đang bị Frozen không?
local _hasTeams            = false   -- Mode hiện tại có team không? (cache từ SetGameMode)
local _targetList          = {}      -- Danh sách Player objects Normal (từ server, đã filter)
local _rawTargetList       = {}      -- Danh sách Player objects Normal thô từ server (chưa filter)
local _currentIndex        = 1       -- Vị trí hiện tại trong vòng lặp
local _savedCameraSubject  = nil     -- Lưu CameraSubject gốc để restore
local _currentPhase        = "Intermission"  -- Cache phase hiện tại

-- Remote
local RequestSpectateTargetEvent

-- Streaming: thời gian tối đa chờ Character stream in sau khi ReplicationFocus được set
local STREAM_WAIT_TIMEOUT  = 5    -- giây
local STREAM_POLL_INTERVAL = 0.1  -- giây

--- Phát âm thanh GUI qua AudioHelper
local function PlayGuiSound(SoundId)
	AudioHelper.PlayGuiSound(SoundId)
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
--- Chỉ gọi khi là Lobby Spectator — Frozen Spectator do server quản lý lock
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
		if RequestSpectateTargetEvent then
			RequestSpectateTargetEvent:FireServer(TargetPlayer)
		end

		-- Bước 2: Poll chờ Character stream in (tối đa STREAM_WAIT_TIMEOUT giây)
		local Elapsed = 0
		while Elapsed < STREAM_WAIT_TIMEOUT do
			if not _isSpectating then return end
			local Character = TargetPlayer.Character
			if Character and Character.Parent then
				local Humanoid = Character:FindFirstChildOfClass("Humanoid")
				if Humanoid and Humanoid.Health > 0 then
					local Cam = workspace.CurrentCamera
					if Cam then
						Cam.CameraType = Enum.CameraType.Custom
						Cam.CameraSubject = Humanoid
					end
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
	local Cam = workspace.CurrentCamera
	if not Cam then return end

	Cam.CameraType = Enum.CameraType.Custom

	-- Kiểm tra nếu _savedCameraSubject còn hợp lệ trong workspace và còn sống
	local IsSavedValid = _savedCameraSubject 
		and _savedCameraSubject:IsDescendantOf(workspace) 
		and _savedCameraSubject:IsA("Humanoid") 
		and _savedCameraSubject.Health > 0

	if IsSavedValid then
		Cam.CameraSubject = _savedCameraSubject
	else
		-- Fallback: khôi phục về Humanoid của LocalPlayer hiện tại
		local Character = LocalPlayer.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			Cam.CameraSubject = Humanoid
		end
	end

	_savedCameraSubject = nil
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
-- PRIVATE: Target List Filter
-- =========================================================

--- Lọc danh sách target từ server theo ngữ cảnh:
--- - Lobby Spectator: giữ tất cả
--- - Frozen Spectator + HasTeams: chỉ giữ đồng minh cùng team
--- - Frozen Spectator + FFA: giữ tất cả
--- @param RawList table -- danh sách Player thô từ server
--- @return table -- danh sách đã lọc
local function FilterTargetList(RawList)
	if not _isFrozenSpectator or not _hasTeams then
		return RawList
	end

	-- Frozen Spectator trong mode có team: chỉ xem đồng minh
	local MyTeam = LocalPlayer:GetAttribute("Team")
	if not MyTeam then
		-- Không có team (edge case): trả về list rỗng để tránh xem kẻ địch
		return {}
	end

	local Filtered = {}
	for _, Player in ipairs(RawList) do
		if Player:GetAttribute("Team") == MyTeam then
			table.insert(Filtered, Player)
		end
	end
	return Filtered
end

-- =========================================================
-- PRIVATE: SpectateButton visibility
-- =========================================================

--- Ẩn/hiện SpectateButton trong InGameGui/Buttons theo trạng thái Frozen
local function SetSpectateButtonVisible(Visible)
	if InGameSpectateButton then
		InGameSpectateButton.Visible = Visible
	end
end

-- =========================================================
-- PRIVATE: Target List Update
-- =========================================================

--- Xử lý khi server gửi danh sách Spectate mới
local function OnSpectateListUpdated(NormalPlayers)
	_rawTargetList = NormalPlayers or {}
	_targetList    = FilterTargetList(_rawTargetList)

	if not _isSpectating then return end

	-- Nếu danh sách rỗng → tự động tắt spectate
	if #_targetList == 0 then
		task.defer(function()
			local SpectateController = require(script)
			SpectateController.SetVisible(false)
		end)
		return
	end

	-- Tìm player đang focus trong danh sách mới
	local Cam = workspace.CurrentCamera
	local CurrentSubject = Cam and Cam.CameraSubject
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
-- PRIVATE: Reset Frozen state phía client
-- =========================================================

--- Reset toàn bộ trạng thái Frozen phía client
--- Gọi khi chết, respawn, hoặc được thaw (trước khi SetVisible xử lý)
local function ResetFrozenClientState()
	_isFrozen = false
	SetSpectateButtonVisible(false)
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
		local IsInMatch = PlayerStateHelper.IsInMatch(LocalPlayer)
		local IsFrozenInMatch = IsInMatch and _isFrozen

		if IsInMatch and not IsFrozenInMatch then
			-- Đang trong trận nhưng không bị Frozen → không thể spectate
			return
		end

		if _currentPhase ~= "InGame" then
			-- Không phải phase InGame → không thể spectate
			return
		end

		-- Cập nhật filter và kiểm tra list
		_isFrozenSpectator = IsFrozenInMatch
		_targetList        = FilterTargetList(_rawTargetList)

		if #_targetList == 0 then
			-- Không có ai để quan sát
			return
		end

		-- Đóng toàn bộ tab Menu nếu đang mở (SpectateGui ở ObserverGui riêng, không cần exclude)
		local MenuCtrl = GetMenuController()
		if MenuCtrl then
			MenuCtrl.CloseAll()
		end

		-- Ẩn thanh nút điều hướng (chỉ với Lobby Spectator — Frozen Spectator không có nav)
		if not _isFrozenSpectator then
			local NavCtrl = GetNavigationController()
			if NavCtrl then
				NavCtrl.SetVisible(false)
			end
		end

		-- Bật spectate
		_isSpectating = true
		_currentIndex = 1

		-- Lock movement: chỉ cần với Lobby Spectator (Frozen Spectator đã bị lock bởi server)
		if not _isFrozenSpectator then
			LockSpectatorMovement()
		end

		-- Lưu camera hiện tại
		local Cam = workspace.CurrentCamera
		if Cam then
			_savedCameraSubject = Cam.CameraSubject
		end

		-- Hiện Spectate GUI
		if SpectateGui then
			SpectateGui.Visible = true
		end

		-- Focus vào target đầu tiên
		ApplyCurrentTarget()

		print("[SpectateController] Chế độ Spectate đã bật" 
			.. (_isFrozenSpectator and " (Frozen Spectator)" or " (Lobby Spectator)") .. ".")
	else
		-- Tắt spectate
		if not _isSpectating and not (SpectateGui and SpectateGui.Visible) then
			return
		end

		local WasFrozenSpectator = _isFrozenSpectator

		_isSpectating      = false
		_isFrozenSpectator = false

		-- Khôi phục movement: chỉ với Lobby Spectator
		-- Frozen Spectator: server quản lý lock, không tự unlock
		if not WasFrozenSpectator then
			UnlockSpectatorMovement()
		end

		-- Yêu cầu server reset ReplicationFocus về chính player
		if RequestSpectateTargetEvent then
			RequestSpectateTargetEvent:FireServer(nil)
		end

		-- Ẩn Spectate GUI
		if SpectateGui then
			SpectateGui.Visible = false
		end

		-- Khôi phục nav bar: chỉ với Lobby Spectator
		if not WasFrozenSpectator then
			local NavCtrl = GetNavigationController()
			if NavCtrl then
				NavCtrl.SetVisible(true)
			end
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
	-- Resolve ObserverGui và Frame Spectate bên trong
	ObserverGui  = GuiHelper.GetScreenGui(GuiConfig.ScreenGuis.ObserverGui)
	SpectateGui  = ObserverGui and ObserverGui:WaitForChild(GuiConfig.ObserverFrames.Spectate)

	if ObserverGui then
		ObserverGui.ResetOnSpawn = false  -- Bắt buộc theo learning: tránh mất listener khi respawn
		ObserverGui.Enabled      = false  -- GameStateController quản lý Enabled theo phase
	end

	if SpectateGui then
		CloseButton  = SpectateGui:WaitForChild("CloseButton")
		NextButton   = SpectateGui:WaitForChild("NextButton")
		BackButton   = SpectateGui:WaitForChild("BackButton")
		local PlayerNameFrame = SpectateGui:WaitForChild("PlayerName")
		PlayerNameText = PlayerNameFrame:WaitForChild("PlayerNameText")
		SpectateGui.Visible = false
	end

	-- Resolve InGameGui/Buttons/SpectateButton
	local InGameGuiCfg   = GuiConfig.InGameButtons
	InGameGuiRef = GuiHelper.GetScreenGui("InGameGui")
	if InGameGuiRef then
		ButtonsFrame = InGameGuiRef:FindFirstChild(InGameGuiCfg.Buttons)
		if ButtonsFrame then
			InGameSpectateButton = ButtonsFrame:FindFirstChild(InGameGuiCfg.SpectateButton)
		end
	end
	-- Ẩn SpectateButton lúc khởi tạo (chỉ hiện khi bị Frozen)
	SetSpectateButtonVisible(false)

	-- Gắn sự kiện click và âm thanh SFX cho các nút điều khiển (không kèm animation scale theo quy định)
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			PlayGuiSound(AudioConfig.Gui.CloseButtonClick)
			SpectateController.SetVisible(false)
		end)
		CloseButton.MouseEnter:Connect(function()
			PlayGuiSound(AudioConfig.Gui.MouseEnter)
		end)
	end

	if NextButton then
		NextButton.MouseButton1Click:Connect(function()
			PlayGuiSound(AudioConfig.Gui.ButtonClick)
			CycleNext()
		end)
		NextButton.MouseEnter:Connect(function()
			PlayGuiSound(AudioConfig.Gui.MouseEnter)
		end)
	end

	if BackButton then
		BackButton.MouseButton1Click:Connect(function()
			PlayGuiSound(AudioConfig.Gui.ButtonClick)
			CycleBack()
		end)
		BackButton.MouseEnter:Connect(function()
			PlayGuiSound(AudioConfig.Gui.MouseEnter)
		end)
	end

	-- Gắn click cho SpectateButton trong InGameGui
	if InGameSpectateButton then
		InGameSpectateButton.MouseButton1Click:Connect(function()
			PlayGuiSound(AudioConfig.Gui.ButtonClick)
			SpectateController.SetVisible(true)
		end)
		InGameSpectateButton.MouseEnter:Connect(function()
			PlayGuiSound(AudioConfig.Gui.MouseEnter)
		end)
	end

	-- Lắng nghe danh sách Spectate từ server
	local UpdateSpectateListEvent = RemoteDefinitions.GetEvent("UpdateSpectateList")
	UpdateSpectateListEvent.OnClientEvent:Connect(OnSpectateListUpdated)

	-- Resolve remote để gửi yêu cầu ReplicationFocus lên server
	RequestSpectateTargetEvent = RemoteDefinitions.GetEvent("RequestSpectateTarget")

	-- Lắng nghe phase game để auto-close khi rời InGame và cache _hasTeams
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

	-- Lắng nghe SetGameMode để cache HasTeams cho filter logic
	local SetGameModeEvent = RemoteDefinitions.GetEvent("SetGameMode")
	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		-- HasTeams khi HighlightMode là "TeamBased" (nhất quán với GameModeConfig)
		-- Server gửi ModeKey, dùng HighlightMode làm proxy vì không gửi HasTeams trực tiếp
		-- Mode không team: HighlightMode = "FFA" hoặc PlayerStatusType = "Disabled"
		_hasTeams = (Data.PlayerStatusType ~= "Disabled") and (Data.HighlightMode ~= "FFA")

		-- Khi mode mới bắt đầu, reset trạng thái Frozen phía client
		ResetFrozenClientState()
	end)

	-- Lắng nghe UpdatePlayerState để theo dõi trạng thái Frozen của LocalPlayer
	local UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
	UpdatePlayerStateEvent.OnClientEvent:Connect(function(Data)
		if not Data or Data.PlayerId ~= LocalPlayer.UserId then return end

		if Data.State == "Frozen" then
			-- LocalPlayer bị Frozen → hiện SpectateButton
			_isFrozen = true
			SetSpectateButtonVisible(true)

		else
			-- LocalPlayer được Thaw, chết, hoặc bất kỳ trạng thái không phải Frozen
			-- Tắt Spectate trước, sau đó reset state
			if _isSpectating and _isFrozenSpectator then
				SpectateController.SetVisible(false)
			end
			ResetFrozenClientState()
		end
	end)

	-- Tự động tắt spectate khi player được đưa vào trận (Lobby Spectator trường hợp)
	PlayerStateHelper.ObserveMatchState(LocalPlayer, function(IsInMatch)
		if IsInMatch and _isSpectating and not _isFrozenSpectator then
			-- Lobby Spectator bị kéo vào trận → tắt spectate
			SpectateController.SetVisible(false)
		end
	end)

	-- CharacterAdded: safety net khi chết/respawn trong lúc Frozen Spectate hoặc Frozen bình thường
	LocalPlayer.CharacterAdded:Connect(function()
		if _isSpectating then
			SpectateController.SetVisible(false)
		else
			-- Không đang spectate nhưng có thể đang bị "kẹt" state Frozen phía client
			-- (ví dụ: respawn sau khi chết, server đã broadcast Dead nhưng CharacterAdded đến trước)
			if not _isFrozenSpectator then
				UnlockSpectatorMovement()
				RestoreCamera()
			end
		end
		-- Đảm bảo SpectateButton ẩn sau respawn
		ResetFrozenClientState()
	end)

	print("[SpectateController] Đã khởi tạo.")
end

return SpectateController
