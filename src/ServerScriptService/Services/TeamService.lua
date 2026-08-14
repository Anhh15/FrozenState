-- TeamService.lua
-- Quản lý việc broadcast phân đội và điều phối highlight AlwaysOnTop khi FrozenState

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionService    = require(script.Parent.SessionService)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameModeConfig    = require(ReplicatedStorage.Shared.Config.GameModeConfig)

-- =========================================================
-- PRIVATE
-- =========================================================

local SetTeamAssignmentEvent
local UpdateFrozenStateEvent

-- =========================================================
-- PUBLIC API
-- =========================================================

local TeamService = {}

--- Broadcast bảng phân đội xuống tất cả client
--- Không broadcast nếu mode hiện tại không có team (HasTeams = false)
--- Format: { ["userId"] = "Team1" | "Team2" }
function TeamService.BroadcastTeamAssignment()
	local Mode = GameModeConfig.GetMode(SessionService.GetCurrentModeKey())
	if not Mode.HasTeams then return end

	local Teams = {}
	for _, Player in ipairs(Players:GetPlayers()) do
		local Team = SessionService.GetTeam(Player)
		if Team then
			Teams[tostring(Player.UserId)] = Team
		end
	end

	SetTeamAssignmentEvent:FireAllClients(Teams)
	print("[TeamService] Đã broadcast team assignment.")
end

--- Fire SetTeamAssignment chỉ đến một client cụ thể (dùng khi player join muộn giữa trận)
--- Không gửi nếu mode hiện tại không có team
--- @param TargetPlayer Player
function TeamService.BroadcastTeamAssignmentTo(TargetPlayer)
	local Mode = GameModeConfig.GetMode(SessionService.GetCurrentModeKey())
	if not Mode.HasTeams then return end

	local Teams = {}
	for _, Player in ipairs(Players:GetPlayers()) do
		local Team = SessionService.GetTeam(Player)
		if Team then
			Teams[tostring(Player.UserId)] = Team
		end
	end

	SetTeamAssignmentEvent:FireClient(TargetPlayer, Teams)
	print(("[TeamService] Đã gửi team assignment riêng cho %s."):format(TargetPlayer.Name))
end

--- Kích hoạt hoặc hủy chế độ AlwaysOnTop cho highlight (FrozenState)
--- @param IsActive boolean
function TeamService.SetFrozenStateHighlights(IsActive)
	UpdateFrozenStateEvent:FireAllClients(IsActive)
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function TeamService:Init()
	SetTeamAssignmentEvent  = RemoteDefinitions.GetEvent("SetTeamAssignment")
	UpdateFrozenStateEvent  = RemoteDefinitions.GetEvent("UpdateFrozenState")
	print("[TeamService] Đã khởi tạo.")
end

function TeamService:Start()
	print("[TeamService] Đang chạy.")
end

return TeamService
