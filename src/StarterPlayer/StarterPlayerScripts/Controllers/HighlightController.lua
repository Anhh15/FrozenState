-- HighlightController.lua (ModuleScript)
-- Quản lý Highlight instance trên character của các player khác
-- Highlight màu đỏ = kẻ địch, xanh = đồng minh, không highlight bản thân
-- Khi bị đóng băng (Frozen): Highlight Adornee chỉ hướng vào Part/Mesh HighlightHelper của IceBlock Model
-- Khi FrozenState: chuyển sang DepthMode.AlwaysOnTop (xuyên vật thể)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local TagConfig         = require(ReplicatedStorage.Shared.Config.TagConfig)
local TagHelper         = require(ReplicatedStorage.Shared.Tools.TagHelper)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)
local GuiAnimConfig     = require(ReplicatedStorage.Shared.Config.GuiAnimConfig)

-- =========================================================
-- CONFIG
-- =========================================================

local HIGHLIGHT_NAME        = "TeamHighlight"
local HIGHLIGHT_HELPER_NAME = "HighlightHelper"
local ENEMY_COLOR           = (GuiAnimConfig.Highlight and GuiAnimConfig.Highlight.EnemyColor) or Color3.fromRGB(220, 50,  50)
local ALLY_COLOR            = (GuiAnimConfig.Highlight and GuiAnimConfig.Highlight.AllyColor) or Color3.fromRGB(50,  120, 220)
local FILL_TRANSPARENCY     = (GuiAnimConfig.Highlight and GuiAnimConfig.Highlight.FillTransparency) or 1
local OUTLINE_TRANSPARENCY  = (GuiAnimConfig.Highlight and GuiAnimConfig.Highlight.OutlineTransparency) or 0.0

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer    = Players.LocalPlayer
local KnownTeams     = {}   -- { [tostring(userId)] = "Team1" | "Team2" }
local _isFrozenState = false
local _frozenPlayers = {}   -- { [tostring(userId)] = true | false }
local _playerStates  = {}   -- { [tostring(userId)] = "Normal" | "Frozen" | "Dead" }
local _highlightMode = "TeamBased"  -- "TeamBased" | "FFA" | "Disabled"

-- =========================================================
-- PRIVATE
-- =========================================================

--- Tìm Model khối băng (IceBlock) trong Workspace thuộc về một Player
--- @param Player Player
--- @return Model?
local function FindIceBlockForPlayer(Player)
	if not Player then return nil end
	local TargetUserId = Player.UserId

	local IceBlocks = TagHelper.GetTagged(TagConfig.Tags.IceBlock)
	for _, Block in ipairs(IceBlocks) do
		if Block:IsA("Model") and PlayerStateHelper.GetVictimUserId(Block) == TargetUserId then
			return Block
		end
	end

	-- Fallback quét workspace nếu tag chưa replicate kịp
	for _, Child in ipairs(Workspace:GetChildren()) do
		if Child:IsA("Model") and PlayerStateHelper.GetVictimUserId(Child) == TargetUserId then
			return Child
		end
	end
	return nil
end

--- Áp dụng Highlight cho nhân vật hoặc khối băng của Player theo góc nhìn của LocalPlayer
--- @param Player Player
--- @param IsEnemy boolean
--- @param IsFrozen boolean
--- @param ForceAlwaysOnTop boolean -- bật AlwaysOnTop được buộc lược (FFA mode)
local function ApplyHighlightForPlayer(Player, IsEnemy, IsFrozen, ForceAlwaysOnTop)
	if not Player or Player == LocalPlayer then return end

	local Character = Player.Character
	if not Character then return end

	-- Tạo mới hoặc lấy Highlight đã có trên Character
	local Highlight = Character:FindFirstChild(HIGHLIGHT_NAME)
	if not Highlight then
		Highlight        = Instance.new("Highlight")
		Highlight.Name   = HIGHLIGHT_NAME
		Highlight.Parent = Character
	end

	Highlight.FillColor           = IsEnemy and ENEMY_COLOR or ALLY_COLOR
	Highlight.OutlineColor        = IsEnemy and ENEMY_COLOR or ALLY_COLOR
	Highlight.FillTransparency    = FILL_TRANSPARENCY
	Highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	Highlight.DepthMode           = (IsFrozen or _isFrozenState or ForceAlwaysOnTop)
		and Enum.HighlightDepthMode.AlwaysOnTop
		or  Enum.HighlightDepthMode.Occluded

	-- Nếu bị đóng băng, gán Adornee vào HighlightHelper của IceBlock Model (nếu có)
	if IsFrozen then
		local IceBlockModel = FindIceBlockForPlayer(Player)
		local HighlightHelper = IceBlockModel and IceBlockModel:FindFirstChild(HIGHLIGHT_HELPER_NAME, true)

		if HighlightHelper and HighlightHelper:IsA("BasePart") then
			Highlight.Adornee = HighlightHelper
		else
			Highlight.Adornee = Character
		end
	else
		Highlight.Adornee = Character
	end
end

local function RemoveHighlight(Character)
	if not Character then return end
	local H = Character:FindFirstChild(HIGHLIGHT_NAME)
	if H then H:Destroy() end
end

--- Cập nhật Highlight cho duy nhất một Player theo góc nhìn của LocalPlayer (O(1))
--- @param Player Player
local function UpdateSinglePlayerHighlight(Player)
	if not Player or Player == LocalPlayer then return end

	local Character = Player.Character
	if not Character then return end

	if _highlightMode == "Disabled" then
		RemoveHighlight(Character)
		return
	end

	local IsLocalInMatch  = PlayerStateHelper.IsInMatch(LocalPlayer) and (_playerStates[tostring(LocalPlayer.UserId)] ~= "Dead")
	local PlayerUserIdStr = tostring(Player.UserId)
	local IsTargetInMatch = PlayerStateHelper.IsInMatch(Player) and (_playerStates[PlayerUserIdStr] ~= "Dead")

	if not IsTargetInMatch then
		RemoveHighlight(Character)
		return
	end

	local IsFrozen = (_frozenPlayers[PlayerUserIdStr] == true)

	if _highlightMode == "FFA" then
		if not IsLocalInMatch then
			RemoveHighlight(Character)
		else
			ApplyHighlightForPlayer(Player, true, IsFrozen, true)
		end
	elseif _highlightMode == "TeamBased" then
		local MyTeamKey = tostring(LocalPlayer.UserId)
		local MyTeam    = IsLocalInMatch and KnownTeams[MyTeamKey] or nil
		local PlayerTeam = KnownTeams[PlayerUserIdStr]

		if not MyTeam or not PlayerTeam then
			RemoveHighlight(Character)
		else
			local IsEnemy = (PlayerTeam ~= MyTeam)
			ApplyHighlightForPlayer(Player, IsEnemy, IsFrozen, false)
		end
	end
end

--- Refresh highlight cho tất cả player (gọi lại khi team thay đổi hoặc FrozenState đổi)
local function RefreshAll()
	if _highlightMode == "Disabled" then
		for _, Player in ipairs(Players:GetPlayers()) do
			if Player.Character then
				RemoveHighlight(Player.Character)
			end
		end
		return
	end

	for _, Player in ipairs(Players:GetPlayers()) do
		UpdateSinglePlayerHighlight(Player)
	end
end

--- Gắn listener cho character mới của một player
local function WatchPlayer(Player)
	if Player == LocalPlayer then
		Player.CharacterAdded:Connect(function(Character)
			Character:WaitForChild("HumanoidRootPart", 5)
			RemoveHighlight(Character)
		end)
		return
	end

	Player.CharacterAdded:Connect(function(Character)
		-- Đợi nhân vật fully loaded
		Character:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.1)

		local PlayerUserIdStr = tostring(Player.UserId)
		local IsInMatch = PlayerStateHelper.IsInMatch(Player) and (_playerStates[PlayerUserIdStr] ~= "Dead")
		if not IsInMatch then
			RemoveHighlight(Character)
		else
			RefreshAll()
		end
	end)

	-- Nếu character đã có sẵn (join mid-game)
	if Player.Character then
		RefreshAll()
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local HighlightController = {}

function HighlightController:Init()
	-- Nhận GameMode khi mỗi trận bắt đầu
	local SetGameModeEvent = RemoteDefinitions.GetEvent("SetGameMode")
	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.HighlightMode then
			_highlightMode = Data.HighlightMode
			-- Reset state cũ của trận trước
			KnownTeams     = {}
			_frozenPlayers = {}
			_playerStates  = {}
			_isFrozenState = false
			RefreshAll()
		end
	end)

	-- Nhận bảng phân đội khi match bắt đầu
	local SetTeamEvent = RemoteDefinitions.GetEvent("SetTeamAssignment")
	SetTeamEvent.OnClientEvent:Connect(function(Teams)
		-- Teams = { ["userId"] = "Team1"|"Team2" } (string keys từ server)
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
				local DeadPlayer = Players:GetPlayerByUserId(Data.PlayerId)
				if DeadPlayer and DeadPlayer.Character then
					RemoveHighlight(DeadPlayer.Character)
				end
			end

			RefreshAll()
		end
	end)

	-- Xóa highlight khi Ready (match mới sắp bắt đầu)
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.Phase == "Ready" then
			_frozenPlayers = {}
			RefreshAll()
		elseif Data and Data.Phase == "Intermission" then
			-- Reset hoàn toàn khi vào Intermission
			_highlightMode = "TeamBased"
			KnownTeams     = {}
			_frozenPlayers = {}
			_playerStates  = {}
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

	-- Watch tất cả player hiện tại
	for _, Player in ipairs(Players:GetPlayers()) do
		WatchPlayer(Player)
	end

	-- Watch player mới join
	Players.PlayerAdded:Connect(WatchPlayer)

	-- Lắng nghe khi IceBlock Model thêm/xóa qua CollectionService để cập nhật Highlight.Adornee theo từng player (O(1))
	local function HandleIceBlockChanged(BlockInstance)
		if not BlockInstance or not BlockInstance:IsA("Model") then return end
		local VictimUserId = PlayerStateHelper.GetVictimUserId(BlockInstance)
		if not VictimUserId then return end

		local TargetPlayer = Players:GetPlayerByUserId(VictimUserId)
		if TargetPlayer and TargetPlayer ~= LocalPlayer then
			UpdateSinglePlayerHighlight(TargetPlayer)
		end
	end

	TagHelper.ObserveTagAdded(TagConfig.Tags.IceBlock, HandleIceBlockChanged)
	TagHelper.ObserveTagRemoved(TagConfig.Tags.IceBlock, HandleIceBlockChanged)

	print("[HighlightController] Đã khởi tạo.")
end

return HighlightController
