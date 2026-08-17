-- GameStatisticController.lua (ModuleScript)
-- Điều khiển GUI GameStatistic mới với ViewportFrame và UIListLayout
-- Phase 8.3: GUI SFX — CloseButton, NextButton, PlayerStats overall

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local RewardHelper      = require(ReplicatedStorage.Shared.Tools.RewardHelper)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local StatGui      = PlayerGui:WaitForChild("GameStatistic")

-- ── TopPlayersStats (Bảng Đội Thắng / Winner) ────────────────────────────────────
local TopPlayersStats = StatGui:WaitForChild("TopPlayersStats")
local WinLabel        = TopPlayersStats:WaitForChild("WinLabel")
local AnnounceText    = WinLabel:WaitForChild("AnnounceText")
local NextButton      = TopPlayersStats:WaitForChild("NextButton")
local CloseButton1    = TopPlayersStats:WaitForChild("CloseButton")

local PlayerSlots = {
	TopPlayersStats:WaitForChild("PlayerTop1"),
	TopPlayersStats:WaitForChild("PlayerTop2"),
	TopPlayersStats:WaitForChild("PlayerTop3"),
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

--- Phát âm thanh GUI qua AudioHelper
--- @param SoundId number
local function PlayGuiSound(SoundId)
	AudioHelper.PlayGuiSound(SoundId)
end

-- =========================================================
-- PRIVATE
-- =========================================================

local function HideAll()
	StatGui.Enabled         = false
	TopPlayersStats.Visible = false
	PlayerStats.Visible     = false
end

local function ShowTopPlayers()
	StatGui.Enabled         = true
	TopPlayersStats.Visible = true
	PlayerStats.Visible     = false
end

local function ShowPlayerStats()
	StatGui.Enabled         = true
	TopPlayersStats.Visible = false
	PlayerStats.Visible     = true
	-- Phase 8.3: Phát 'overall' khi PlayerStats hiện ra
	PlayGuiSound(AudioConfig.Stats.Overall)
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
	local RewardPerFreeze        = RewardHelper.GetRewardAmount("PerFreeze")
	local RewardPerThaw          = RewardHelper.GetRewardAmount("PerThaw")
	local RewardPerFreezingSpree = RewardHelper.GetRewardAmount("PerFreezingSpree")
	local RewardPerThawingSpree  = RewardHelper.GetRewardAmount("PerThawingSpree")
	local RewardFirstBlood       = RewardHelper.GetRewardAmount("FirstBlood")
	local RewardLastStanding     = RewardHelper.GetRewardAmount("LastStanding")

	GameResultText.Text  = won and "VICTORY" or "DEFEAT"
	
	-- Render ảnh 2D từ eo trở lên (AvatarBust) cho cá nhân người chơi
	SetPlayerThumbnail(MainAvatarThumbnail, LocalPlayer.UserId, "AvatarBust")

	-- Format hiển thị chi tiết: "Số lượng (x Giá trị) = Tổng nhận được"
	FreezeVal.Text = ("%d (×%d) = %d"):format(
		stats.Freezes, RewardPerFreeze, stats.Freezes * RewardPerFreeze
	)

	ThawVal.Text = ("%d (×%d) = %d"):format(
		stats.Thaws, RewardPerThaw, stats.Thaws * RewardPerThaw
	)

	-- Đối với First Blood và Last Standing hiển thị số tiền trực tiếp
	FSpreeVal.Text = ("%d (×%d) = %d"):format(
		stats.FreezingSprees, RewardPerFreezingSpree, stats.FreezingSprees * RewardPerFreezingSpree
	)
	TSpreeVal.Text = ("%d (×%d) = %d"):format(
		stats.ThawingSprees, RewardPerThawingSpree, stats.ThawingSprees * RewardPerThawingSpree
	)
	FirstBloodVal.Text   = stats.FirstBlood and tostring(RewardFirstBlood) or "0"
	LastStandingVal.Text = stats.LastStanding and tostring(RewardLastStanding) or "0"
	
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

		-- Xác định text thông báo thắng theo mode
		if data.WinTeam then
			-- TeamBased: hiển thị tên đội
			AnnounceText.Text = (data.WinTeam == "Team1") and "TEAM 1 WINS!" or "TEAM 2 WINS!"
		elseif data.WinPlayer then
			-- FFA: hiển thị tên người thắng
			AnnounceText.Text = data.WinPlayer.Name .. " WINS!"
		else
			-- Edge case: hòa (FFA dừa 0 người Normal)
			AnnounceText.Text = "DRAW!"
		end

		FillTopPlayers(data.TopPlayers or {})
		FillPersonalStats(data.Won, data.PersonalStats or {})

		ShowTopPlayers()
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
		PlayGuiSound(AudioConfig.Gui.ButtonClick)
		ShowPlayerStats()
	end)
	CloseButton1.MouseButton1Click:Connect(function()
		PlayGuiSound(AudioConfig.Gui.CloseButtonClick)
		HideAll()
	end)
	CloseButton2.MouseButton1Click:Connect(function()
		PlayGuiSound(AudioConfig.Gui.CloseButtonClick)
		HideAll()
	end)

	print("[GameStatisticController] Khởi tạo thành công với cấu trúc GUI mới.")
end

return GameStatisticController