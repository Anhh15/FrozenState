-- ScoreBoardController.lua (ModuleScript)
-- Quản lý ScoreBoard: hiển thị thống kê Freezes/Thaws và trạng thái Frozen của từng player
-- Tự động sắp xếp vị trí: người chơi có (Freezes + Thaws) cao nhất đứng đầu, ưu tiên Freezes nếu hòa
-- Toggle bằng: ScoreBoardButton (Mobile/Manual), Ctrl (PC), R1 (Console)
-- Chỉ hiển thị với player đang trong trận (có Team), ẩn với Spectator

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- GUI REFERENCES (lazy-init trong Init)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local _InGameGui        = nil
local _ScoreBoard       = nil
local _ScoreBoardButton = nil
local _AllyStatsFrame   = nil
local _EnemyStatsFrame  = nil
local _Template         = nil  -- PlayerStats Frame template

-- Cache: { [UserId] = Clone Frame } để cập nhật nhanh khi nhận UpdatePlayerState
local _PlayerCards    = {}
local _playerStats    = {}  -- [UserId] = { Card = Frame, Freezes = number, Thaws = number }
local _scoreboardType = "TwoTeams"  -- "TwoTeams" | "Disabled"

-- =========================================================
-- CONFIG
-- =========================================================

local THUMBNAIL_TYPE = Enum.ThumbnailType.HeadShot
local THUMBNAIL_SIZE = Enum.ThumbnailSize.Size100x100

-- =========================================================
-- PRIVATE
-- =========================================================

--- Tính LayoutOrder cho thẻ người chơi trong ScoreBoard
--- Freezes + Thaws càng cao thì đứng càng cao (LayoutOrder càng nhỏ)
--- Ưu tiên Freezes hơn nếu tổng điểm bằng nhau
--- @param Freezes number?
--- @param Thaws number?
--- @return number
local function CalculateLayoutOrder(Freezes, Thaws)
	local F = Freezes or 0
	local T = Thaws or 0
	local TotalScore = (F + T) * 1000 + F
	return -TotalScore
end

--- Đảm bảo Layout trong frame được sắp xếp theo LayoutOrder
--- @param Frame Frame?
local function EnsureLayoutOrderSort(Frame)
	if not Frame then return end
	local Layout = Frame:FindFirstChildOfClass("UIListLayout") or Frame:FindFirstChildOfClass("UIGridLayout")
	if Layout then
		Layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
end

--- Xóa toàn bộ PlayerStats clone cũ
local function ClearBoard()
	for _, Card in pairs(_PlayerCards) do
		Card:Destroy()
	end
	_PlayerCards = {}
	_playerStats = {}
end

--- Hiển thị hoặc ẩn ScoreBoard
--- Spectator (không có team) không được xem ScoreBoard
--- Disabled (chế độ không có Scoreboard) — block toàn bộ
--- @param Visible boolean
local function SetScoreBoardVisible(Visible)
	-- Block nếu mode không có ScoreBoard
	if _scoreboardType == "Disabled" then return end

	-- Ẩn với Spectator
	if Visible then
		local MyTeam = PlayerStateHelper.GetTeam(LocalPlayer)
		if not MyTeam then return end
	end

	if _ScoreBoard then
		_ScoreBoard.Visible = Visible
	end
end

--- Tạo một PlayerStats card cho một player
--- @param UserId number
--- @param DisplayName string
--- @param IsAlly boolean
local function CreatePlayerCard(UserId, DisplayName, IsAlly)
	if not _Template then return end

	local Clone = _Template:Clone()
	Clone.Name    = tostring(UserId)
	Clone.Visible = true

	-- Tên hiển thị
	local NameText = Clone:FindFirstChild("NameText")
	if NameText then
		NameText.Text = DisplayName
	end

	-- Khởi tạo stats về 0
	local FreezesText = Clone:FindFirstChild("FreezesText")
	local ThawsText   = Clone:FindFirstChild("ThawsText")
	if FreezesText then FreezesText.Text = "0" end
	if ThawsText   then ThawsText.Text   = "0" end

	-- FrozenStatus ẩn theo mặc định
	local FrozenStatus = Clone:FindFirstChild("FrozenStatus")
	if FrozenStatus then FrozenStatus.Visible = false end

	-- Gán LayoutOrder ban đầu (0)
	Clone.LayoutOrder = CalculateLayoutOrder(0, 0)

	-- Clone vào đúng frame trước để tránh race condition
	if IsAlly then
		Clone.Parent = _AllyStatsFrame
	else
		Clone.Parent = _EnemyStatsFrame
	end

	_PlayerCards[UserId] = Clone
	_playerStats[UserId] = {
		Card    = Clone,
		Freezes = 0,
		Thaws   = 0,
	}

	-- Avatar thumbnail bất đồng bộ
	-- GetUserThumbnailAsync trả về (url, isReady)
	local AvatarImg = Clone:FindFirstChild("AvatarThumbnail")
	if AvatarImg then
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
				AvatarImg.Image = Url
			end
		end)
	end
end

--- Xử lý khi nhận SetTeamAssignment: build board mới
--- @param Teams table -- { [tostring(UserId)] = "Team1" | "Team2" }
local function OnTeamAssigned(Teams)
	ClearBoard()

	local MyUserIdStr = tostring(LocalPlayer.UserId)
	local MyTeam = Teams[MyUserIdStr]
	-- Spectator không hiển thị ScoreBoard (chỉ build board nếu có team)
	if not MyTeam then return end

	for UserIdStr, TeamName in pairs(Teams) do
		local UserId = tonumber(UserIdStr)
		if not UserId then continue end

		local IsAlly = (TeamName == MyTeam)

		-- Lấy DisplayName từ Players service (player phải còn online)
		local TargetPlayer = Players:GetPlayerByUserId(UserId)
		local DisplayName = TargetPlayer and TargetPlayer.DisplayName or ("Player " .. UserIdStr)

		CreatePlayerCard(UserId, DisplayName, IsAlly)
	end
end

--- Cập nhật card của một player khi nhận UpdatePlayerState
--- @param Data table -- { PlayerId, State, Freezes, Thaws }
local function OnPlayerStateUpdated(Data)
	if not Data or not Data.PlayerId then return end

	local Card = _PlayerCards[Data.PlayerId]
	if not Card then return end

	-- Cập nhật FrozenStatus icon (Frozen hoặc Dead đều hiện biểu tượng FrozenStatus)
	local FrozenStatus = Card:FindFirstChild("FrozenStatus")
	if FrozenStatus then
		FrozenStatus.Visible = (Data.State == "Frozen" or Data.State == "Dead")
	end

	-- Cập nhật stats count
	local Freezes = Data.Freezes or 0
	local Thaws   = Data.Thaws   or 0

	local FreezesText = Card:FindFirstChild("FreezesText")
	local ThawsText   = Card:FindFirstChild("ThawsText")
	if FreezesText then FreezesText.Text = tostring(Freezes) end
	if ThawsText   then ThawsText.Text   = tostring(Thaws) end

	-- Cập nhật cache và tính lại LayoutOrder để tự động sắp xếp
	local Entry = _playerStats[Data.PlayerId]
	if Entry then
		Entry.Freezes = Freezes
		Entry.Thaws   = Thaws
	else
		_playerStats[Data.PlayerId] = {
			Card    = Card,
			Freezes = Freezes,
			Thaws   = Thaws,
		}
	end

	Card.LayoutOrder = CalculateLayoutOrder(Freezes, Thaws)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local ScoreBoardController = {}

function ScoreBoardController:Init()
	-- Lấy GUI references
	_InGameGui        = PlayerGui:WaitForChild("InGameGui")
	_ScoreBoard       = _InGameGui:WaitForChild("ScoreBoard")
	_ScoreBoardButton = _InGameGui:FindFirstChild("ScoreBoardButton")

	local AllyInfo  = _ScoreBoard:WaitForChild("AllyInfo")
	local EnemyInfo = _ScoreBoard:WaitForChild("EnemyInfo")
	_AllyStatsFrame  = AllyInfo:WaitForChild("StatsFrame")
	_EnemyStatsFrame = EnemyInfo:WaitForChild("StatsFrame")

	-- Đảm bảo Layout trong cả 2 StatsFrame sắp xếp theo LayoutOrder
	EnsureLayoutOrderSort(_AllyStatsFrame)
	EnsureLayoutOrderSort(_EnemyStatsFrame)

	local TemplateFolder = _ScoreBoard:WaitForChild("Template")
	_Template = TemplateFolder:WaitForChild("PlayerStats")

	-- ScoreBoard ẩn mặc định
	_ScoreBoard.Visible = false

	-- ── TOGGLE: ScoreBoardButton (Mobile / Manual) ──
	if _ScoreBoardButton then
		_ScoreBoardButton.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				SetScoreBoardVisible(true)
			end
		end)
		_ScoreBoardButton.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1
				or Input.UserInputType == Enum.UserInputType.Touch
			then
				SetScoreBoardVisible(false)
			end
		end)
	end

	-- ── TOGGLE: CloseButton bên trong ScoreBoard (nếu có sự cố) ──
	local CloseButton = _ScoreBoard:FindFirstChild("CloseButton")
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			SetScoreBoardVisible(false)
		end)
	end

	-- ── TOGGLE: PC — giữ Ctrl để hiện, thả để ẩn ──
	UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed then return end
		if Input.KeyCode == Enum.KeyCode.LeftControl
			or Input.KeyCode == Enum.KeyCode.RightControl
		then
			SetScoreBoardVisible(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.LeftControl
			or Input.KeyCode == Enum.KeyCode.RightControl
		then
			SetScoreBoardVisible(false)
		end
	end)

	-- ── TOGGLE: Console — giữ R1 để hiện, thả để ẩn ──
	UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed then return end
		if Input.KeyCode == Enum.KeyCode.ButtonR1 then
			SetScoreBoardVisible(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(Input)
		if Input.KeyCode == Enum.KeyCode.ButtonR1 then
			SetScoreBoardVisible(false)
		end
	end)

	-- ── DATA: Lắng nghe SetGameMode để biết loại ScoreBoard ──
	local SetGameModeEvent = RemoteDefinitions.GetEvent("SetGameMode")
	SetGameModeEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.ScoreboardType then
			_scoreboardType = Data.ScoreboardType
			-- Ẩn ScoreBoard ngay nếu mode không có Scoreboard
			if _scoreboardType == "Disabled" then
				SetScoreBoardVisible(false)
			end
		end
	end)

	-- ── DATA: Lắng nghe SetTeamAssignment để build board ──
	local SetTeamEvent = RemoteDefinitions.GetEvent("SetTeamAssignment")
	SetTeamEvent.OnClientEvent:Connect(function(Teams)
		OnTeamAssigned(Teams)
	end)

	-- ── DATA: Lắng nghe UpdatePlayerState để cập nhật real-time ──
	local UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
	UpdatePlayerStateEvent.OnClientEvent:Connect(function(Data)
		OnPlayerStateUpdated(Data)
	end)

	-- ── CLEANUP: Dọn board khi trận kết thúc ──
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and Data.Phase == "Intermission" then
			ClearBoard()
			SetScoreBoardVisible(false)
			_scoreboardType = "TwoTeams"  -- reset về default cho vòng tiếp theo
		end
	end)

	print("[ScoreBoardController] Đã khởi tạo.")
end

return ScoreBoardController
