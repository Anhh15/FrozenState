-- TeamService.lua
-- Quản lý việc broadcast phân đội và điều phối highlight AlwaysOnTop khi FrozenState

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SessionService    = require(script.Parent.SessionService)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

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
--- Format: { ["userId"] = "Team1" | "Team2" }
--- Client (HighlightController) sẽ dùng để tạo highlight đúng màu
function TeamService.BroadcastTeamAssignment()
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
