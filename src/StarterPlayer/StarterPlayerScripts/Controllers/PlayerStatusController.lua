-- PlayerStatusController.lua (ModuleScript)
-- Hiển thị avatar thumbnail của tất cả người chơi trong trận theo đội (AllyTeam / EnemyTeam)
-- Hoạt động với cả người đang trong trận lẫn Spectator
-- Spectator: Team1 = xanh dương (AllyTeam), Team2 = đỏ (EnemyTeam)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- CONFIG
-- =========================================================

local ALLY_COLOR  = Color3.fromHex("009DFF")
local ENEMY_COLOR = Color3.fromHex("FF5151")

-- Thumbnail type: HeadShot
local THUMBNAIL_TYPE = Enum.ThumbnailType.HeadShot
local THUMBNAIL_SIZE = Enum.ThumbnailSize.Size100x100

-- =========================================================
-- GUI REFERENCES (lazy-init trong Init để tránh race condition)
-- =========================================================

local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")

local _InGameGui    = nil
local _StatusFrame  = nil
local _AllyTeamFrame  = nil
local _EnemyTeamFrame = nil
local _Template       = nil  -- AvatarThumbnail ImageLabel template

-- Cache danh sách clone để dọn dẹp khi reset trận
local _AllyClones  = {}
local _EnemyClones = {}

-- =========================================================
-- PRIVATE
-- =========================================================

--- Xóa tất cả avatar đã clone trước đó
local function ClearAvatars()
	for _, Clone in ipairs(_AllyClones) do
		Clone:Destroy()
	end
	for _, Clone in ipairs(_EnemyClones) do
		Clone:Destroy()
	end
	_AllyClones  = {}
	_EnemyClones = {}
end

--- Clone một AvatarThumbnail và gán UserId + màu nền vào đúng frame
--- @param UserId number
--- @param IsAlly boolean
local function SpawnAvatarCard(UserId, IsAlly)
	if not _Template then return end

	local Clone = _Template:Clone()
	Clone.Name    = tostring(UserId)
	Clone.Visible = true

	-- Đặt màu nền theo đội
	Clone.BackgroundColor3 = IsAlly and ALLY_COLOR or ENEMY_COLOR

	-- Clone vào đúng frame đội trước để tránh race condition khi check Clone.Parent
	if IsAlly then
		Clone.Parent = _AllyTeamFrame
		table.insert(_AllyClones, Clone)
	else
		Clone.Parent = _EnemyTeamFrame
		table.insert(_EnemyClones, Clone)
	end

	-- Load thumbnail bất đồng bộ để không block UI
	-- GetUserThumbnailAsync trả về (url, isReady) — retry nếu isReady = false
	task.spawn(function()
		local TargetUserId = UserId
		if TargetUserId <= 0 then
			TargetUserId = 1 -- Sử dụng ID mẫu để test được trong Studio
		end

		local Url, IsReady
		local Ok = pcall(function()
			Url, IsReady = Players:GetUserThumbnailAsync(TargetUserId, THUMBNAIL_TYPE, THUMBNAIL_SIZE)
		end)
		if Ok and Clone.Parent then
			Clone.Image = Url
		end
	end)
end

--- Xử lý khi nhận được bảng phân đội từ server
--- @param Teams table -- { [tostring(UserId)] = "Team1" | "Team2" }
local function OnTeamAssigned(Teams)
	ClearAvatars()

	local MyUserIdStr = tostring(LocalPlayer.UserId)
	local MyTeam = Teams[MyUserIdStr]
	-- Spectator (MyTeam = nil): Team1 → AllyTeam (xanh), Team2 → EnemyTeam (đỏ)

	for UserIdStr, TeamName in pairs(Teams) do
		local UserId = tonumber(UserIdStr)
		if not UserId then continue end

		local IsAlly
		if MyTeam then
			-- Player trong trận: so sánh đội với LocalPlayer
			IsAlly = (TeamName == MyTeam)
		else
			-- Spectator: Team1 luôn là "đội xanh" (AllyTeam), Team2 là "đội đỏ" (EnemyTeam)
			IsAlly = (TeamName == "Team1")
		end

		SpawnAvatarCard(UserId, IsAlly)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local PlayerStatusController = {}

function PlayerStatusController:Init()
	-- Lấy GUI references (InGameGui đã có sẵn trong Studio)
	_InGameGui      = PlayerGui:WaitForChild("InGameGui")
	_StatusFrame    = _InGameGui:WaitForChild("PlayerStatus")
	_AllyTeamFrame  = _StatusFrame:WaitForChild("AllyTeam")
	_EnemyTeamFrame = _StatusFrame:WaitForChild("EnemyTeam")

	local TemplateFolder = _StatusFrame:WaitForChild("Template")
	_Template = TemplateFolder:WaitForChild("AvatarThumbnail")

	-- Ngăn reset khi player respawn
	_InGameGui.ResetOnSpawn = false

	-- Lắng nghe SetTeamAssignment để render avatar
	local SetTeamEvent = RemoteDefinitions.GetEvent("SetTeamAssignment")
	SetTeamEvent.OnClientEvent:Connect(function(Teams)
		OnTeamAssigned(Teams)
	end)

	-- Dọn avatar khi trận kết thúc (phase chuyển về Intermission)
	-- GameStateController sẽ broadcast UpdateGameState — listen và dọn khi cần
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.Phase == "Intermission" then
			ClearAvatars()
		end
	end)

	print("[PlayerStatusController] Đã khởi tạo.")
end

return PlayerStatusController
