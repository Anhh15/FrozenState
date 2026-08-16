-- HighlightController.lua (ModuleScript)
-- Quản lý Highlight instance trên character của các player khác
-- Highlight màu đỏ = kẻ địch, xanh = đồng minh, không highlight bản thân
-- Khi bị đóng băng (Frozen): Highlight Adornee chỉ hướng vào Part/Mesh HighlightHelper của IceBlock Model
-- Khi FrozenState: chuyển sang DepthMode.AlwaysOnTop (xuyên vật thể)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- CONFIG
-- =========================================================

local HIGHLIGHT_NAME        = "TeamHighlight"
local HIGHLIGHT_HELPER_NAME = "HighlightHelper"
local ENEMY_COLOR           = Color3.fromRGB(220, 50,  50)   -- đỏ
local ALLY_COLOR            = Color3.fromRGB(50,  120, 220)  -- xanh dương
local FILL_TRANSPARENCY     = 1
local OUTLINE_TRANSPARENCY  = 0.0

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer    = Players.LocalPlayer
local KnownTeams     = {}   -- { [tostring(userId)] = "Team1" | "Team2" }
local _isFrozenState = false
local _frozenPlayers = {}   -- { [tostring(userId)] = true | false }
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
	local H = Character:FindFirstChild(HIGHLIGHT_NAME)
	if H then H:Destroy() end
end

--- Refresh highlight cho tất cả player (gọi lại khi team thay đổi hoặc FrozenState đổi)
local function RefreshAll()
	-- Disabled: không tạo highlight
	if _highlightMode == "Disabled" then
		for _, Player in ipairs(Players:GetPlayers()) do
			if Player.Character then
				RemoveHighlight(Player.Character)
			end
		end
		return
	end

	if _highlightMode == "FFA" then
		-- FFA: tất cả là kẻ địch, luôn AlwaysOnTop
		for _, Player in ipairs(Players:GetPlayers()) do
			if Player == LocalPlayer then continue end
			local Character = Player.Character
			if not Character then continue end
			local IsFrozen = (_frozenPlayers[tostring(Player.UserId)] == true)
			ApplyHighlightForPlayer(Player, true, IsFrozen, true)  -- IsEnemy=true, ForceAlwaysOnTop=true
		end
		return
	end

	-- TeamBased: logic cũ
	local MyTeamKey = tostring(LocalPlayer.UserId)
	local MyTeam    = KnownTeams[MyTeamKey]

	for _, Player in ipairs(Players:GetPlayers()) do
		if Player == LocalPlayer then continue end

		local Character = Player.Character
		if not Character then continue end

		local PlayerUserIdStr = tostring(Player.UserId)
		local PlayerTeam      = KnownTeams[PlayerUserIdStr]

		if not PlayerTeam or not MyTeam then
			RemoveHighlight(Character)
		else
			local IsEnemy  = (PlayerTeam ~= MyTeam)
			local IsFrozen = (_frozenPlayers[PlayerUserIdStr] == true)
			ApplyHighlightForPlayer(Player, IsEnemy, IsFrozen, false)
		end
	end
end

--- Gắn listener cho character mới của một player
local function WatchPlayer(Player)
	if Player == LocalPlayer then return end

	Player.CharacterAdded:Connect(function(Character)
		-- Đợi nhân vật fully loaded
		Character:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		RefreshAll()
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
			_frozenPlayers[tostring(Data.PlayerId)] = (Data.State == "Frozen")
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
			for _, Player in ipairs(Players:GetPlayers()) do
				if Player.Character then
					RemoveHighlight(Player.Character)
				end
			end
		end
	end)

	-- Watch tất cả player hiện tại
	for _, Player in ipairs(Players:GetPlayers()) do
		WatchPlayer(Player)
	end

	-- Watch player mới join
	Players.PlayerAdded:Connect(WatchPlayer)

	-- Lắng nghe khi IceBlock Model thêm/xóa trong Workspace để cập nhật Highlight.Adornee
	Workspace.ChildAdded:Connect(function(Child)
		if Child:IsA("Model") and PlayerStateHelper.GetVictimUserId(Child) ~= nil then
			RefreshAll()
		end
	end)

	Workspace.ChildRemoved:Connect(function(Child)
		if Child:IsA("Model") and PlayerStateHelper.GetVictimUserId(Child) ~= nil then
			RefreshAll()
		end
	end)

	print("[HighlightController] Đã khởi tạo.")
end

return HighlightController
