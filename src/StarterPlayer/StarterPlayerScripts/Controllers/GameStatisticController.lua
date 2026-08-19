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

--- Hiển thị ảnh đại diện của người chơi qua GetUserThumbnailAsync (kèm Studio fallback)
--- @param ImageLabel ImageLabel
--- @param UserId number
--- @param ThumbnailType Enum.ThumbnailType|nil
local function SetPlayerThumbnail(ImageLabel, UserId, ThumbnailType)
	if not ImageLabel then return end

	ThumbnailType = ThumbnailType or Enum.ThumbnailType.AvatarThumbnail
	local ThumbnailSize = Enum.ThumbnailSize.Size352x352

	task.spawn(function()
		local TargetUserId = UserId
		if not TargetUserId or TargetUserId <= 0 then
			TargetUserId = 1 -- Sử dụng ID mẫu để test được trong Studio
		end

		local Url, IsReady
		local Ok = pcall(function()
			Url, IsReady = Players:GetUserThumbnailAsync(TargetUserId, ThumbnailType, ThumbnailSize)
		end)

		if Ok and Url and ImageLabel and ImageLabel.Parent then
			ImageLabel.Image = Url
		end
	end)
end

--- Điền thông tin top 3 vào các PlayerSlots
local function FillTopPlayers(TopPlayers)
	for i, Slot in ipairs(PlayerSlots) do
		local Data = TopPlayers[i]
		if Data then
			Slot.PlayerNameText.Text = Data.Name
			Slot.FreezesStats.ValueText.Text = tostring(Data.Freezes)
			Slot.ThawsStats.ValueText.Text = tostring(Data.Thaws)

			-- Render ảnh 2D toàn thân (AvatarThumbnail) cho Top player
			local UserId = Data.UserId or 0
			local AvatarThumbnail = Slot:FindFirstChild("AvatarThumbnail")
			if AvatarThumbnail then
				SetPlayerThumbnail(AvatarThumbnail, UserId, Enum.ThumbnailType.AvatarThumbnail)
			end

			Slot.Visible = true
		else
			Slot.Visible = false
		end
	end
end

--- Điền thống kê cá nhân vào bảng PlayerStats
local function FillPersonalStats(Won, Stats)
	local RewardPerFreeze        = RewardHelper.GetRewardAmount("PerFreeze")
	local RewardPerThaw          = RewardHelper.GetRewardAmount("PerThaw")
	local RewardPerFreezingSpree = RewardHelper.GetRewardAmount("PerFreezingSpree")
	local RewardPerThawingSpree  = RewardHelper.GetRewardAmount("PerThawingSpree")
	local RewardFirstBlood       = RewardHelper.GetRewardAmount("FirstBlood")
	local RewardLastStanding     = RewardHelper.GetRewardAmount("LastStanding")

	GameResultText.Text  = Won and "VICTORY" or "DEFEAT"
	
	-- Render ảnh 2D từ eo trở lên (AvatarBust) cho cá nhân người chơi
	SetPlayerThumbnail(MainAvatarThumbnail, LocalPlayer.UserId, Enum.ThumbnailType.AvatarBust)

	-- Format hiển thị chi tiết: "Số lượng (x Giá trị) = Tổng nhận được"
	FreezeVal.Text = ("%d (×%d) = %d"):format(
		Stats.Freezes, RewardPerFreeze, Stats.Freezes * RewardPerFreeze
	)

	ThawVal.Text = ("%d (×%d) = %d"):format(
		Stats.Thaws, RewardPerThaw, Stats.Thaws * RewardPerThaw
	)

	-- Đối với First Blood và Last Standing hiển thị số tiền trực tiếp
	FSpreeVal.Text = ("%d (×%d) = %d"):format(
		Stats.FreezingSprees, RewardPerFreezingSpree, Stats.FreezingSprees * RewardPerFreezingSpree
	)
	TSpreeVal.Text = ("%d (×%d) = %d"):format(
		Stats.ThawingSprees, RewardPerThawingSpree, Stats.ThawingSprees * RewardPerThawingSpree
	)
	FirstBloodVal.Text   = Stats.FirstBlood and tostring(RewardFirstBlood) or "0"
	LastStandingVal.Text = Stats.LastStanding and tostring(RewardLastStanding) or "0"
	
	TotalMoneyVal.Text   = tostring(Stats.MoneyEarned)
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
	ShowGameOverEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end

		-- Xác định text thông báo thắng theo mode
		if Data.WinTeam then
			-- TeamBased: hiển thị tên đội
			AnnounceText.Text = (Data.WinTeam == "Team1") and "TEAM 1 WINS!" or "TEAM 2 WINS!"
		elseif Data.WinPlayer then
			-- FFA: hiển thị tên người thắng
			AnnounceText.Text = Data.WinPlayer.Name .. " WINS!"
		else
			-- Edge case: hòa (FFA dừa 0 người Normal)
			AnnounceText.Text = "DRAW!"
		end

		FillTopPlayers(Data.TopPlayers or {})
		FillPersonalStats(Data.Won, Data.PersonalStats or {})

		ShowTopPlayers()
	end)

	-- Ẩn GUI khi bắt đầu trận đấu mới
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and (Data.Phase == "Ready" or Data.Phase == "InGame") then
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