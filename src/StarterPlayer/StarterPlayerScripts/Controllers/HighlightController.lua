-- HighlightController.lua (ModuleScript)
-- Quản lý Highlight instance trên character của các player khác
-- Highlight màu đỏ = kẻ địch, xanh = đồng minh, không highlight bản thân
-- Khi FrozenState: chuyển sang DepthMode.AlwaysOnTop (xuyên vật thể)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- CONFIG
-- =========================================================

local HIGHLIGHT_NAME       = "TeamHighlight"
local ENEMY_COLOR          = Color3.fromRGB(220, 50,  50)   -- đỏ
local ALLY_COLOR           = Color3.fromRGB(50,  120, 220)  -- xanh dương
local FILL_TRANSPARENCY    = 0.65
local OUTLINE_TRANSPARENCY = 0.0

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer    = Players.LocalPlayer
local KnownTeams     = {}   -- { [tostring(userId)] = "Team1" | "Team2" }
local _isFrozenState = false

-- =========================================================
-- PRIVATE
-- =========================================================

local function ApplyHighlight(Character, IsEnemy)
	-- Tạo mới hoặc lấy Highlight đã có
	local Highlight = Character:FindFirstChild(HIGHLIGHT_NAME)
	if not Highlight then
		Highlight        = Instance.new("Highlight")
		Highlight.Name   = HIGHLIGHT_NAME
		Highlight.Parent = Character
	end

	Highlight.FillColor          = IsEnemy and ENEMY_COLOR or ALLY_COLOR
	Highlight.OutlineColor       = IsEnemy and ENEMY_COLOR or ALLY_COLOR
	Highlight.FillTransparency   = FILL_TRANSPARENCY
	Highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
	Highlight.DepthMode          = _isFrozenState
		and Enum.HighlightDepthMode.AlwaysOnTop
		or  Enum.HighlightDepthMode.Occluded
end

local function RemoveHighlight(Character)
	local H = Character:FindFirstChild(HIGHLIGHT_NAME)
	if H then H:Destroy() end
end

--- Refresh highlight cho tất cả player (gọi lại khi team thay đổi hoặc FrozenState đổi)
local function RefreshAll()
	local MyTeamKey = tostring(LocalPlayer.UserId)
	local MyTeam    = KnownTeams[MyTeamKey]

	for _, Player in ipairs(Players:GetPlayers()) do
		-- Không highlight bản thân
		if Player == LocalPlayer then continue end

		local Character = Player.Character
		if not Character then continue end

		local PlayerTeam = KnownTeams[tostring(Player.UserId)]

		if not PlayerTeam or not MyTeam then
			-- Chưa có team info hoặc trận chưa bắt đầu: xóa highlight
			RemoveHighlight(Character)
		else
			local IsEnemy = (PlayerTeam ~= MyTeam)
			ApplyHighlight(Character, IsEnemy)
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

	-- Xóa highlight khi Ready (match mới sắp bắt đầu)
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.Phase == "Ready" then
			-- Team sẽ được set lại qua SetTeamAssignment ngay trước Ready
			-- Chỉ cần refresh lại
			RefreshAll()
		elseif Data and Data.Phase == "Intermission" then
			-- Xóa highlight khi vào Intermission
			KnownTeams = {}
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

	print("[HighlightController] Đã khởi tạo.")
end

return HighlightController
