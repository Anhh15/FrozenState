-- HighlightController.lua (ModuleScript)
-- Quản lý Highlight instance trên character của các player khác và FrozenMarker (BillboardGui) cho đồng đội bị đóng băng
-- Highlight màu đỏ = kẻ địch, xanh = đồng minh, không highlight bản thân
-- Khi đồng đội bị đóng băng (Frozen): Highlight trắng viền + fill (hoặc xám nếu unthawable), kèm FrozenMarker trên đầu
-- Khi kẻ địch bị đóng băng (Frozen): Highlight đỏ AlwaysOnTop (xuyên vật thể), không fill, không có FrozenMarker

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)
local GameModeHelper    = require(ReplicatedStorage.Shared.Tools.GameModeHelper)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiAnimConfig     = require(ReplicatedStorage.Shared.Config.GuiAnimConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

-- =========================================================
-- CONFIG
-- =========================================================

local HIGHLIGHT_NAME = "TeamHighlight"

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer        = Players.LocalPlayer
local KnownTeams         = {}   -- { [tostring(userId)] = "Team1" | "Team2" }
local _isFrozenState     = false
local _currentModeKey    = nil  -- string? ("Normal" | "Chaos" | "EternalFreeze"...)
local _frozenPlayers     = {}   -- { [tostring(userId)] = true | false }
local _playerStates      = {}   -- { [tostring(userId)] = "Normal" | "Frozen" | "Dead" }
local _highlightMode     = "TeamBased"  -- "TeamBased" | "FFA" | "Disabled"
local _PlayerConnections = {}   -- [Player] = { RBXScriptConnection }
local _frozenMarkers     = {}   -- { [tostring(userId)] = BillboardGui }
local _markerTemplate    = nil  -- Cache template từ InGameGui.Templates.FrozenMarker
local _viewportConn      = nil  -- Connection lắng nghe ViewportSize
local _cameraConn        = nil  -- Connection lắng nghe CurrentCamera

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Kiểm tra xem trạng thái trận đấu hiện tại có cấm rã đông (Thaw) hay không
--- @return boolean
local function IsPlayerUnthawable()
	if _isFrozenState then
		return true
	end
	if _currentModeKey and not GameModeHelper.CanThaw(_currentModeKey) then
		return true
	end
	return false
end

--- Tính toán tỉ lệ phóng to/thu nhỏ cho Marker dựa trên độ cao Viewport của Camera
--- @return number
local function GetScaleFactor()
	local Camera = Workspace.CurrentCamera
	if not Camera or Camera.ViewportSize.Y <= 0 then
		return 1.0
	end
	local MarkerConfig = GuiAnimConfig.FrozenMarker
	local RefRes       = (MarkerConfig and MarkerConfig.ReferenceResolution) or 1080
	local MinScale     = (MarkerConfig and MarkerConfig.MinScale) or 0.75
	local MaxScale     = (MarkerConfig and MarkerConfig.MaxScale) or 1.4
	return math.clamp(Camera.ViewportSize.Y / RefRes, MinScale, MaxScale)
end

--- Cập nhật scale của tất cả các FrozenMarker đang hoạt động khi kích thước màn hình thay đổi
local function UpdateAllMarkerScales()
	local Factor = GetScaleFactor()
	local ContainerName = (GuiConfig.FrozenMarker and GuiConfig.FrozenMarker.Container) or "Frame"

	for _, Marker in pairs(_frozenMarkers) do
		if Marker and Marker.Parent then
			local Frame = Marker:FindFirstChild(ContainerName) or Marker:FindFirstChild("Frame")
			if Frame then
				local UIScale = Frame:FindFirstChildOfClass("UIScale")
				if UIScale then
					UIScale.Scale = Factor
				end
			end
		end
	end
end

--- Lấy hoặc tìm template FrozenMarker trong PlayerGui.InGameGui.Templates
--- @return BillboardGui?
local function GetFrozenMarkerTemplate()
	if _markerTemplate and _markerTemplate.Parent then
		return _markerTemplate
	end

	local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", GuiConfig.Timeouts.ShortWait)
	if not PlayerGui then return nil end

	local InGameGuiName = (GuiConfig.ScreenGuis and GuiConfig.ScreenGuis.InGameGui) or "InGameGui"
	local InGameGui = PlayerGui:FindFirstChild(InGameGuiName) or PlayerGui:WaitForChild(InGameGuiName, GuiConfig.Timeouts.ShortWait)
	if not InGameGui then return nil end

	local TemplatesName = (GuiConfig.FrozenMarker and GuiConfig.FrozenMarker.Templates) or "Templates"
	local Templates = InGameGui:FindFirstChild(TemplatesName) or InGameGui:WaitForChild(TemplatesName, GuiConfig.Timeouts.ShortWait)
	if not Templates then return nil end

	local MarkerName = (GuiConfig.FrozenMarker and GuiConfig.FrozenMarker.FrozenMarker) or "FrozenMarker"
	_markerTemplate = Templates:FindFirstChild(MarkerName)
	return _markerTemplate
end

--- Xóa và giải phóng instance FrozenMarker của một người chơi
--- @param PlayerUserIdStr string
local function RemoveFrozenMarker(PlayerUserIdStr)
	local Marker = _frozenMarkers[PlayerUserIdStr]
	if Marker then
		Marker:Destroy()
		_frozenMarkers[PlayerUserIdStr] = nil
	end
end

--- Xóa toàn bộ các FrozenMarker đang tồn tại
local function RemoveAllMarkers()
	for UserIdStr, Marker in pairs(_frozenMarkers) do
		if Marker then
			Marker:Destroy()
		end
	end
	_frozenMarkers = {}
end

--- Tạo mới hoặc cập nhật nội dung/màu sắc của FrozenMarker cho đồng đội bị đóng băng
--- @param Player Player
--- @param Character Model
--- @param IsUnthawable boolean
local function CreateOrUpdateFrozenMarker(Player, Character, IsUnthawable)
	if not Player or Player == LocalPlayer or not Character then return end
	local PlayerUserIdStr = tostring(Player.UserId)
	local MarkerConfig    = GuiAnimConfig.FrozenMarker
	local ElementNames    = GuiConfig.FrozenMarker
	local ContainerName   = (ElementNames and ElementNames.Container) or "Frame"
	local IconName        = (ElementNames and ElementNames.Icon) or "Icon"
	local NameTextName    = (ElementNames and ElementNames.NameText) or "NameText"
	local TargetColor     = IsUnthawable and MarkerConfig.UnthawableColor or MarkerConfig.NormalColor

	local ExistingMarker = _frozenMarkers[PlayerUserIdStr]
	if ExistingMarker and ExistingMarker.Parent then
		local Frame = ExistingMarker:FindFirstChild(ContainerName) or ExistingMarker:FindFirstChild("Frame")
		if Frame then
			local Icon = Frame:FindFirstChild(IconName)
			if Icon and Icon:IsA("ImageLabel") then
				Icon.ImageColor3 = TargetColor
			end
		end
		return
	end

	local Template = GetFrozenMarkerTemplate()
	if not Template then
		return
	end

	local Marker = Template:Clone()
	Marker.Name        = (ElementNames and ElementNames.FrozenMarker) or "FrozenMarker"
	Marker.Enabled     = true
	Marker.AlwaysOnTop = MarkerConfig.AlwaysOnTop
	Marker.StudsOffset = MarkerConfig.StudsOffset

	local Frame = Marker:FindFirstChild(ContainerName) or Marker:FindFirstChild("Frame")
	if Frame then
		-- Gán hoặc tạo mới UIScale để hỗ trợ responsive kích thước theo màn hình
		local UIScale = Frame:FindFirstChildOfClass("UIScale")
		if not UIScale then
			UIScale = Instance.new("UIScale")
			UIScale.Parent = Frame
		end
		UIScale.Scale = GetScaleFactor()

		-- Cập nhật màu sắc Icon
		local Icon = Frame:FindFirstChild(IconName)
		if Icon and Icon:IsA("ImageLabel") then
			Icon.ImageColor3 = TargetColor
		end

		-- Cập nhật DisplayName với giới hạn MaxNameLength = 12 ký tự
		local NameText = Frame:FindFirstChild(NameTextName)
		if NameText and NameText:IsA("TextLabel") then
			local MaxLen = MarkerConfig.MaxNameLength or 12
			NameText.Text = GuiHelper.TruncateText(Player.DisplayName or Player.Name, MaxLen)
		end
	end

	-- Ưu tiên gán Adornee và Parent vào Head của Character
	local Head = Character:FindFirstChild("Head") or Character.PrimaryPart or Character:WaitForChild("HumanoidRootPart", 2)
	if Head then
		Marker.Adornee = Head
		Marker.Parent  = Head
	else
		Marker.Adornee = Character
		Marker.Parent  = Character
	end

	_frozenMarkers[PlayerUserIdStr] = Marker
end

--- Xóa Highlight khỏi Character
--- @param Character Model?
local function RemoveHighlight(Character)
	if not Character then return end
	local H = Character:FindFirstChild(HIGHLIGHT_NAME)
	if H then H:Destroy() end
end

--- Áp dụng Highlight cho nhân vật theo góc nhìn của LocalPlayer
--- @param Player Player
--- @param IsEnemy boolean
--- @param IsFrozen boolean
--- @param ForceAlwaysOnTop boolean
local function ApplyHighlightForPlayer(Player, IsEnemy, IsFrozen, ForceAlwaysOnTop)
	if not Player or Player == LocalPlayer then return end

	local Character = Player.Character
	if not Character then return end

	local HighlightConfig  = GuiAnimConfig.Highlight
	local EnemyColor        = (HighlightConfig and HighlightConfig.EnemyColor) or Color3.fromRGB(220, 50,  50)
	local AllyColor         = (HighlightConfig and HighlightConfig.AllyColor) or Color3.fromRGB(50,  120, 220)
	local DefaultFillTrans  = (HighlightConfig and HighlightConfig.FillTransparency) or 1.0
	local DefaultOutTrans   = (HighlightConfig and HighlightConfig.OutlineTransparency) or 0.0

	-- Tạo mới hoặc lấy Highlight đã có trên Character
	local Highlight = Character:FindFirstChild(HIGHLIGHT_NAME)
	if not Highlight then
		Highlight        = Instance.new("Highlight")
		Highlight.Name   = HIGHLIGHT_NAME
		Highlight.Parent = Character
	end

	-- Highlight luôn gán Adornee vào Character để hiển thị rõ silhouette tư thế đóng băng
	Highlight.Adornee = Character

	local PlayerUserIdStr = tostring(Player.UserId)

	if IsEnemy then
		-- Kẻ địch: Luôn thấy viền đỏ, không fill, không thấy FrozenMarker
		Highlight.FillColor           = EnemyColor
		Highlight.OutlineColor        = EnemyColor
		Highlight.FillTransparency    = DefaultFillTrans
		Highlight.OutlineTransparency = DefaultOutTrans
		Highlight.DepthMode           = (IsFrozen or _isFrozenState or ForceAlwaysOnTop)
			and Enum.HighlightDepthMode.AlwaysOnTop
			or  Enum.HighlightDepthMode.Occluded

		RemoveFrozenMarker(PlayerUserIdStr)
	else
		-- Đồng minh:
		if IsFrozen then
			local Unthawable  = IsPlayerUnthawable()
			local VisualGroup = Unthawable and HighlightConfig.Unthawable or HighlightConfig.Thawable

			Highlight.FillColor           = VisualGroup.FillColor
			Highlight.OutlineColor        = VisualGroup.OutlineColor
			Highlight.FillTransparency    = VisualGroup.FillTransparency
			Highlight.OutlineTransparency = VisualGroup.OutlineTransparency
			Highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop

			-- Đồng minh bị đóng băng -> Hiển thị FrozenMarker trên đầu
			CreateOrUpdateFrozenMarker(Player, Character, Unthawable)
		else
			-- Đồng minh bình thường:
			Highlight.FillColor           = AllyColor
			Highlight.OutlineColor        = AllyColor
			Highlight.FillTransparency    = DefaultFillTrans
			Highlight.OutlineTransparency = DefaultOutTrans
			Highlight.DepthMode           = (_isFrozenState or ForceAlwaysOnTop)
				and Enum.HighlightDepthMode.AlwaysOnTop
				or  Enum.HighlightDepthMode.Occluded

			RemoveFrozenMarker(PlayerUserIdStr)
		end
	end
end

--- Cập nhật Highlight và Marker cho duy nhất một Player theo góc nhìn của LocalPlayer (O(1))
--- @param Player Player
local function UpdateSinglePlayerHighlight(Player)
	if not Player or Player == LocalPlayer then return end

	local Character = Player.Character
	if not Character then return end

	local PlayerUserIdStr = tostring(Player.UserId)

	if _highlightMode == "Disabled" then
		RemoveHighlight(Character)
		RemoveFrozenMarker(PlayerUserIdStr)
		return
	end

	local IsLocalInMatch  = PlayerStateHelper.IsInMatch(LocalPlayer) and (_playerStates[tostring(LocalPlayer.UserId)] ~= "Dead")
	local IsTargetInMatch = PlayerStateHelper.IsInMatch(Player) and (_playerStates[PlayerUserIdStr] ~= "Dead")

	if not IsTargetInMatch then
		RemoveHighlight(Character)
		RemoveFrozenMarker(PlayerUserIdStr)
		return
	end

	local IsFrozen = (_frozenPlayers[PlayerUserIdStr] == true)

	if _highlightMode == "FFA" then
		if not IsLocalInMatch then
			RemoveHighlight(Character)
			RemoveFrozenMarker(PlayerUserIdStr)
		else
			ApplyHighlightForPlayer(Player, true, IsFrozen, true)
		end
	elseif _highlightMode == "TeamBased" then
		local MyTeamKey  = tostring(LocalPlayer.UserId)
		local MyTeam     = IsLocalInMatch and KnownTeams[MyTeamKey] or nil
		local PlayerTeam = KnownTeams[PlayerUserIdStr]

		if not MyTeam or not PlayerTeam then
			RemoveHighlight(Character)
			RemoveFrozenMarker(PlayerUserIdStr)
		else
			local IsEnemy = (PlayerTeam ~= MyTeam)
			ApplyHighlightForPlayer(Player, IsEnemy, IsFrozen, false)
		end
	end
end

--- Refresh highlight và marker cho tất cả player
local function RefreshAll()
	if _highlightMode == "Disabled" then
		for _, Player in ipairs(Players:GetPlayers()) do
			if Player.Character then
				RemoveHighlight(Player.Character)
			end
		end
		RemoveAllMarkers()
		return
	end

	for _, Player in ipairs(Players:GetPlayers()) do
		UpdateSinglePlayerHighlight(Player)
	end
end

--- Gắn listener cho character mới của một player
--- @param Player Player
local function WatchPlayer(Player)
	if not Player then return end

	-- Dọn connection cũ nếu có
	if _PlayerConnections[Player] then
		for _, Conn in ipairs(_PlayerConnections[Player]) do
			if Conn and Conn.Connected then
				Conn:Disconnect()
			end
		end
	end
	_PlayerConnections[Player] = {}

	if Player == LocalPlayer then
		local Conn = Player.CharacterAdded:Connect(function(Character)
			Character:WaitForChild("HumanoidRootPart", 5)
			RemoveHighlight(Character)
		end)
		table.insert(_PlayerConnections[Player], Conn)
		return
	end

	local Conn = Player.CharacterAdded:Connect(function(Character)
		Character:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.1)

		local PlayerUserIdStr = tostring(Player.UserId)
		local IsInMatch = PlayerStateHelper.IsInMatch(Player) and (_playerStates[PlayerUserIdStr] ~= "Dead")
		if not IsInMatch then
			RemoveHighlight(Character)
			RemoveFrozenMarker(PlayerUserIdStr)
		else
			RefreshAll()
		end
	end)
	table.insert(_PlayerConnections[Player], Conn)

	if Player.Character then
		RefreshAll()
	end
end

--- Dọn dẹp Highlight, Marker, connection và cache khi một player rời khỏi game (Vá [HIGH-06])
--- @param Player Player
local function CleanupPlayer(Player)
	if not Player then return end

	if _PlayerConnections[Player] then
		for _, Conn in ipairs(_PlayerConnections[Player]) do
			if Conn and Conn.Connected then
				Conn:Disconnect()
			end
		end
		_PlayerConnections[Player] = nil
	end

	if Player.Character then
		RemoveHighlight(Player.Character)
	end

	local PlayerUserIdStr = tostring(Player.UserId)
	RemoveFrozenMarker(PlayerUserIdStr)
	KnownTeams[PlayerUserIdStr]     = nil
	_frozenPlayers[PlayerUserIdStr] = nil
	_playerStates[PlayerUserIdStr]  = nil
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local HighlightController = {}

function HighlightController:Init()
	KnownTeams         = {}
	_frozenPlayers     = {}
	_playerStates      = {}
	_isFrozenState     = false
	_currentModeKey    = nil
	_highlightMode     = "TeamBased"
	_PlayerConnections = {}
	_frozenMarkers     = {}
	_markerTemplate    = nil

	print("[HighlightController] Đã khởi tạo.")
end

function HighlightController:Start()
	-- Nhận GameMode khi mỗi trận bắt đầu
	local SetGameModeEvent = RemoteDefinitions.GetEvent("SetGameMode")
	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if Data then
			if Data.HighlightMode then
				_highlightMode = Data.HighlightMode
			end
			if Data.ModeKey then
				_currentModeKey = Data.ModeKey
			end
			-- Reset state cũ của trận trước
			KnownTeams     = {}
			_frozenPlayers = {}
			_playerStates  = {}
			_isFrozenState = false
			RemoveAllMarkers()
			RefreshAll()
		end
	end)

	-- Nhận bảng phân đội khi match bắt đầu
	local SetTeamEvent = RemoteDefinitions.GetEvent("SetTeamAssignment")
	SetTeamEvent.OnClientEvent:Connect(function(Teams)
		KnownTeams = {}
		for UserIdStr, Team in pairs(Teams) do
			KnownTeams[UserIdStr] = Team
		end
		RefreshAll()
	end)

	-- Nhận FrozenState update
	local UpdateFrozenStateEvent = RemoteDefinitions.GetEvent("UpdateFrozenState")
	UpdateFrozenStateEvent.OnClientEvent:Connect(function(IsActive)
		_isFrozenState = IsActive
		RefreshAll()
	end)

	-- Nhận cập nhật trạng thái của từng player
	local UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
	UpdatePlayerStateEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.PlayerId then
			local PlayerIdStr = tostring(Data.PlayerId)
			_playerStates[PlayerIdStr]  = Data.State
			_frozenPlayers[PlayerIdStr] = (Data.State == "Frozen")

			if Data.State == "Dead" then
				KnownTeams[PlayerIdStr] = nil
				RemoveFrozenMarker(PlayerIdStr)
				local DeadPlayer = Players:GetPlayerByUserId(Data.PlayerId)
				if DeadPlayer and DeadPlayer.Character then
					RemoveHighlight(DeadPlayer.Character)
				end
			elseif Data.State == "Normal" then
				RemoveFrozenMarker(PlayerIdStr)
			end

			RefreshAll()
		end
	end)

	-- Xóa highlight và marker khi Ready (match mới sắp bắt đầu)
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.Phase == "Ready" then
			_frozenPlayers = {}
			RemoveAllMarkers()
			RefreshAll()
		elseif Data and Data.Phase == "Intermission" then
			-- Reset hoàn toàn khi vào Intermission
			_highlightMode  = "TeamBased"
			_currentModeKey = nil
			KnownTeams      = {}
			_frozenPlayers  = {}
			_playerStates   = {}
			_isFrozenState  = false
			RemoveAllMarkers()
			for _, Player in ipairs(Players:GetPlayers()) do
				if Player.Character then
					RemoveHighlight(Player.Character)
				end
			end
		end
	end)

	-- Lắng nghe thay đổi trạng thái tham gia trận của LocalPlayer
	PlayerStateHelper.ObserveMatchState(LocalPlayer, function()
		RefreshAll()
	end)

	-- Lắng nghe thay đổi kích thước màn hình để điều chỉnh scale cho FrozenMarker
	local function SetupCameraListener()
		if _viewportConn then
			_viewportConn:Disconnect()
			_viewportConn = nil
		end
		local Cam = Workspace.CurrentCamera
		if Cam then
			_viewportConn = Cam:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateAllMarkerScales)
		end
	end

	SetupCameraListener()
	_cameraConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		SetupCameraListener()
		UpdateAllMarkerScales()
	end)

	-- Watch tất cả player hiện tại
	for _, Player in ipairs(Players:GetPlayers()) do
		WatchPlayer(Player)
	end

	-- Watch player mới join
	Players.PlayerAdded:Connect(WatchPlayer)

	-- Dọn dẹp bộ nhớ khi player rời game (Vá [HIGH-06])
	Players.PlayerRemoving:Connect(CleanupPlayer)
end

return HighlightController
