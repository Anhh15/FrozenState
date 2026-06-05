-- GameStatisticController.lua (ModuleScript)
-- Điều khiển GUI GameStatistic: 2 panel TeamWonStats và YourStats
--
-- Cấu trúc GUI (do user cung cấp):
-- GameStatistic
--   TeamWonStats
--     TeamWon/Text          — tên đội thắng
--     Player1Stats, Player2Stats, Player3Stats
--       PlayerAvatar/PlayerName — tên người chơi
--       FreezeValueText, ThawValueText
--     NextButton            — chuyển sang YourStats
--     CloseButton
--   YourStats
--     GameResult/Text       — WIN / LOSE
--     PlayerMainStats
--       PlayerAvatar/PlayerName
--       FreezeValueText, ThawValueText
--     FreezeStats/Text/ValueText
--     ThawStats/Text/ValueText
--     F_SpreeStats/Text/ValueText
--     T_SpreeStats/Text/ValueText
--     LastStadingStats/Text/ValueText
--     FirstBloodStats/Text/ValueText
--     TotalMoney/Text/ValueText
--     CloseButton

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

-- ── TeamWonStats ──────────────────────────────────────────
local TeamWonStats  = StatGui:WaitForChild("TeamWonStats")
local TeamWonText   = TeamWonStats:WaitForChild("TeamWon"):WaitForChild("Text")
local NextButton    = TeamWonStats:WaitForChild("NextButton")
local CloseButton1  = TeamWonStats:WaitForChild("CloseButton")

local PlayerSlots = {
	TeamWonStats:WaitForChild("Player1Stats"),
	TeamWonStats:WaitForChild("Player2Stats"),
	TeamWonStats:WaitForChild("Player3Stats"),
}

-- ── YourStats ─────────────────────────────────────────────
local YourStats      = StatGui:WaitForChild("YourStats")
local GameResultText = YourStats:WaitForChild("GameResult"):WaitForChild("Text")
local CloseButton2   = YourStats:WaitForChild("CloseButton")

local PlayerMainStats = YourStats:WaitForChild("PlayerMainStats")
local MainNameLabel   = PlayerMainStats:WaitForChild("PlayerAvatar"):WaitForChild("PlayerName")
local MainFreezeVal   = PlayerMainStats:WaitForChild("FreezeValueText")
local MainThawVal     = PlayerMainStats:WaitForChild("ThawValueText")

-- Các stat + tiền thưởng tương ứng
local FreezeStatsVal      = YourStats:WaitForChild("FreezeStats")    :WaitForChild("Text"):WaitForChild("ValueText")
local ThawStatsVal        = YourStats:WaitForChild("ThawStats")      :WaitForChild("Text"):WaitForChild("ValueText")
local FSpreeStatsVal      = YourStats:WaitForChild("F_SpreeStats")   :WaitForChild("Text"):WaitForChild("ValueText")
local TSpreeStatsVal      = YourStats:WaitForChild("T_SpreeStats")   :WaitForChild("Text"):WaitForChild("ValueText")
local LastStandingStatsVal = YourStats:WaitForChild("LastStadingStats"):WaitForChild("Text"):WaitForChild("ValueText")
local FirstBloodStatsVal  = YourStats:WaitForChild("FirstBloodStats"):WaitForChild("Text"):WaitForChild("ValueText")
local TotalMoneyVal       = YourStats:WaitForChild("TotalMoney")     :WaitForChild("Text"):WaitForChild("ValueText")

-- =========================================================
-- PRIVATE
-- =========================================================

local function HideAll()
	StatGui.Enabled         = false
	TeamWonStats.Visible    = false
	YourStats.Visible       = false
end

local function ShowTeamWon()
	StatGui.Enabled         = true
	TeamWonStats.Visible    = true
	YourStats.Visible       = false
end

local function ShowYourStats()
	StatGui.Enabled         = true
	TeamWonStats.Visible    = false
	YourStats.Visible       = true
end

--- Điền thông tin top 3 vào PlayerSlots
local function FillTopPlayers(TopPlayers)
	for i, Slot in ipairs(PlayerSlots) do
		local Data = TopPlayers[i]
		if Data then
			local NameLbl     = Slot:FindFirstChild("PlayerAvatar") and Slot.PlayerAvatar:FindFirstChild("PlayerName")
			local FreezeLbl   = Slot:FindFirstChild("FreezeValueText")
			local ThawLbl     = Slot:FindFirstChild("ThawValueText")

			if NameLbl   then NameLbl.Text   = Data.Name end
			if FreezeLbl then FreezeLbl.Text = tostring(Data.Freezes) end
			if ThawLbl   then ThawLbl.Text   = tostring(Data.Thaws)   end

			Slot.Visible = true
		else
			Slot.Visible = false
		end
	end
end

--- Điền thống kê cá nhân vào YourStats
local function FillPersonalStats(Won, Stats)
	local Eco = GameConfig.Economy

	GameResultText.Text  = Won and "YOU WIN! 🏆" or "YOU LOSE 💀"
	MainNameLabel.Text   = LocalPlayer.DisplayName
	MainFreezeVal.Text   = tostring(Stats.Freezes)
	MainThawVal.Text     = tostring(Stats.Thaws)

	-- Hiện số tiền kiếm được từ mỗi stat (count × reward)
	FreezeStatsVal.Text  = ("%d × %d = %d"):format(
		Stats.Freezes, Eco.RewardPerFreeze, Stats.Freezes * Eco.RewardPerFreeze)

	ThawStatsVal.Text    = ("%d × %d = %d"):format(
		Stats.Thaws, Eco.RewardPerThaw, Stats.Thaws * Eco.RewardPerThaw)

	FSpreeStatsVal.Text  = tostring(Stats.FreezingSprees * Eco.RewardPerFreezingSpree)
	TSpreeStatsVal.Text  = tostring(Stats.ThawingSprees  * Eco.RewardPerThawingSpree)

	LastStandingStatsVal.Text = Stats.LastStanding and tostring(Eco.RewardLastStanding) or "0"
	FirstBloodStatsVal.Text   = Stats.FirstBlood   and tostring(Eco.RewardFirstBlood)   or "0"
	TotalMoneyVal.Text        = tostring(Stats.MoneyEarned)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameStatisticController = {}

function GameStatisticController:Init()
	-- Ngăn GUI reset khi player chết (respawn)
	StatGui.ResetOnSpawn = false

	HideAll()

	-- Nhận dữ liệu cuối trận từ server
	local ShowGameOverEvent = RemoteDefinitions.GetEvent("ShowGameOver")
	ShowGameOverEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end

		local WinTeam   = Data.WinTeam or "Team1"
		local TeamLabel = (WinTeam == "Team1") and "TEAM 1 WINS! 🏆" or "TEAM 2 WINS! 🏆"
		TeamWonText.Text = TeamLabel

		FillTopPlayers(Data.TopPlayers     or {})
		FillPersonalStats(Data.Won, Data.PersonalStats or {})

		ShowTeamWon()
	end)

	-- Ẩn GUI khi đang trong gameplay (Ready hoặc InGame)
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and (Data.Phase == "Ready" or Data.Phase == "InGame") then
			HideAll()
		end
	end)

	-- Nút NextButton: chuyển sang YourStats
	NextButton.MouseButton1Click:Connect(ShowYourStats)

	-- CloseButton ở cả 2 panel
	CloseButton1.MouseButton1Click:Connect(HideAll)
	CloseButton2.MouseButton1Click:Connect(HideAll)

	print("[GameStatisticController] Đã khởi tạo.")
end

return GameStatisticController
