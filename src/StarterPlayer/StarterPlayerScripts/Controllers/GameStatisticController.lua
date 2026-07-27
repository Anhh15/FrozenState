-- GameStatisticController.lua (ModuleScript)
-- Điều khiển GUI GameStatistic mới với ViewportFrame và UIListLayout
-- Phase 8.3: GUI SFX — CloseButton, NextButton, PlayerStats overall

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local StatGui      = PlayerGui:WaitForChild("GameStatistic")

-- ── TeamWonStats (Bảng Đội Thắng) ─────────────────────────
local TeamWonStats  = StatGui:WaitForChild("TeamWonStats")
local TeamWonText   = TeamWonStats:WaitForChild("TeamWon"):WaitForChild("TeamWonText")
local NextButton    = TeamWonStats:WaitForChild("NextButton")
local CloseButton1  = TeamWonStats:WaitForChild("CloseButton")

local PlayerSlots = {
	TeamWonStats:WaitForChild("PlayerTop1"),
	TeamWonStats:WaitForChild("PlayerTop2"),
	TeamWonStats:WaitForChild("PlayerTop3"),
}

-- ── PlayerStats (Bảng Thống Kê Cá Nhân) ───────────────────
local PlayerStats          = StatGui:WaitForChild("PlayerStats")
local GameResultText       = PlayerStats:WaitForChild("GameResult"):WaitForChild("GameResultText")
local CloseButton2         = PlayerStats:WaitForChild("CloseButton")
local MainAvatarThumbnail = PlayerStats:WaitForChild("AvatarThumbnail")

local StatsPanel     = PlayerStats:WaitForChild("Stats")
local TotalStats     = StatsPanel:WaitForChild("TotalStats")

-- Tham chiếu tới các dòng thống kê con trong TotalStats
local FreezeVal       = TotalStats:WaitForChild("Freeze"):WaitForChild("ValueText")
local ThawVal         = TotalStats:WaitForChild("Thaw"):WaitForChild("ValueText")
local FSpreeVal       = TotalStats:WaitForChild("FreezingSpree"):WaitForChild("ValueText")
local TSpreeVal       = TotalStats:WaitForChild("ThawingSpree"):WaitForChild("ValueText")
local FirstBloodVal   = TotalStats:WaitForChild("FirstBlood"):WaitForChild("ValueText")
local LastStandingVal = TotalStats:WaitForChild("LastStanding"):WaitForChild("ValueText")

local TotalMoneyVal   = StatsPanel:WaitForChild("TotalMoney"):WaitForChild("ValueText")

-- =========================================================
-- SFX
-- =========================================================

local SFX_BUTTON_CLICK       = 7249903719
local SFX_CLOSE_BUTTON_CLICK = 103307955424380
local SFX_OVERALL            = 119804136935260

local function PlayGuiSound(SoundId)
	local S = Instance.new("Sound")
	S.SoundId = "rbxassetid://" .. tostring(SoundId)
	S.Volume = 1
	S.Parent = PlayerGui
	S:Play()
	game:GetService("Debris"):AddItem(S, 3)
end

-- =========================================================
-- PRIVATE
-- =========================================================

local function HideAll()
	StatGui.Enabled      = false
	TeamWonStats.Visible = false
	PlayerStats.Visible  = false
end

local function ShowTeamWon()
	StatGui.Enabled      = true
	TeamWonStats.Visible = true
	PlayerStats.Visible  = false
end

local function ShowPlayerStats()
	StatGui.Enabled      = true
	TeamWonStats.Visible = false
	PlayerStats.Visible  = true
	-- Phase 8.3: Phát 'overall' khi PlayerStats hiện ra
	PlayGuiSound(SFX_OVERALL)
end

--- Hiển thị ảnh đại diện 2D của người chơi qua rbxthumb CDN
--- @param imageLabel ImageLabel
--- @param userId number
--- @param thumbnailType string|nil — "Avatar" (Toàn thân) hoặc "AvatarBust" (Từ eo trở lên)
local function SetPlayerThumbnail(imageLabel, userId, thumbnailType)
	if not imageLabel then return end
	if not userId or userId == 0 then
		imageLabel.Image = ""
		return
	end
	thumbnailType = thumbnailType or "Avatar"
	imageLabel.Image = string.format("rbxthumb://type=%s&id=%d&w=352&h=352", thumbnailType, userId)
end

--- Lấy UserId an toàn từ Tên hiển thị (DisplayName hoặc Name) ngay cả khi người chơi đã thoát game
local function GetUserIdFromName(name)
	local player = Players:FindFirstChild(name)
	if player then
		return player.UserId
	end
	
	local success, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	return success and userId or 0
end

--- Điền thông tin top 3 vào các PlayerSlots
local function FillTopPlayers(topPlayers)
	for i, slot in ipairs(PlayerSlots) do
		local data = topPlayers[i]
		if data then
			slot.PlayerNameText.Text = data.Name
			slot.FreezesStats.ValueText.Text = tostring(data.Freezes)
			slot.ThawsStats.ValueText.Text = tostring(data.Thaws)

			-- Render ảnh 2D toàn thân (Avatar) cho Top player
			local userId = data.UserId or 0
			local avatarThumbnail = slot:FindFirstChild("AvatarThumbnail")
			if avatarThumbnail then
				SetPlayerThumbnail(avatarThumbnail, userId, "Avatar")
			end

			slot.Visible = true
		else
			slot.Visible = false
		end
	end
end

--- Điền thống kê cá nhân vào bảng PlayerStats
local function FillPersonalStats(won, stats)
	local eco = GameConfig.Economy

	GameResultText.Text  = won and "VICTORY" or "DEFEAT"
	
	-- Render ảnh 2D từ eo trở lên (AvatarBust) cho cá nhân người chơi
	SetPlayerThumbnail(MainAvatarThumbnail, LocalPlayer.UserId, "AvatarBust")

	-- Format hiển thị chi tiết: "Số lượng (x Giá trị) = Tổng nhận được"
	FreezeVal.Text = ("%d (×%d) = %d"):format(
		stats.Freezes, eco.RewardPerFreeze, stats.Freezes * eco.RewardPerFreeze
	)

	ThawVal.Text = ("%d (×%d) = %d"):format(
		stats.Thaws, eco.RewardPerThaw, stats.Thaws * eco.RewardPerThaw
	)

	-- Đối với First Blood và Last Standing hiển thị số tiền trực tiếp
	FSpreeVal.Text = ("%d (×%d) = %d"):format(
		stats.FreezingSprees, eco.RewardPerFreezingSpree, stats.FreezingSprees * eco.RewardPerFreezingSpree
	)
	TSpreeVal.Text = ("%d (×%d) = %d"):format(
		stats.ThawingSprees, eco.RewardPerThawingSpree, stats.ThawingSprees * eco.RewardPerThawingSpree
	)
	FirstBloodVal.Text   = stats.FirstBlood and tostring(eco.RewardFirstBlood) or "0"
	LastStandingVal.Text = stats.LastStanding and tostring(eco.RewardLastStanding) or "0"
	
	TotalMoneyVal.Text   = tostring(stats.MoneyEarned)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameStatisticController = {}

function GameStatisticController:Init()
	StatGui.ResetOnSpawn = false
	HideAll()

	-- Lắng nghe dữ liệu cuối trận từ server
	local ShowGameOverEvent = RemoteDefinitions.GetEvent("ShowGameOver")
	ShowGameOverEvent.OnClientEvent:Connect(function(data)
		if not data then return end

		local winTeam   = data.WinTeam or "Team1"
		local teamLabel = (winTeam == "Team1") and "TEAM 1 WINS!" or "TEAM 2 WINS!"
		TeamWonText.Text = teamLabel

		FillTopPlayers(data.TopPlayers or {})
		FillPersonalStats(data.Won, data.PersonalStats or {})

		ShowTeamWon()
	end)

	-- Ẩn GUI khi bắt đầu trận đấu mới
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(data)
		if data and (data.Phase == "Ready" or data.Phase == "InGame") then
			HideAll()
		end
	end)

	-- Cài đặt sự kiện nút bấm chuyển tiếp và đóng
	NextButton.MouseButton1Click:Connect(function()
		PlayGuiSound(SFX_BUTTON_CLICK)
		ShowPlayerStats()
	end)
	CloseButton1.MouseButton1Click:Connect(function()
		PlayGuiSound(SFX_CLOSE_BUTTON_CLICK)
		HideAll()
	end)
	CloseButton2.MouseButton1Click:Connect(function()
		PlayGuiSound(SFX_CLOSE_BUTTON_CLICK)
		HideAll()
	end)

	print("[GameStatisticController] Khởi tạo thành công với cấu trúc GUI mới.")
end

return GameStatisticController