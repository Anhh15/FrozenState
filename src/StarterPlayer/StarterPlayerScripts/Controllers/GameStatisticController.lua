-- GameStatisticController.lua (ModuleScript)
-- Điều khiển GUI GameStatistic với ViewportFrame, Pop/Stagger Animations và UI SFX
-- Phase 8.3: Chuẩn hóa Animation & SFX (Pop, Stagger, Button Hover Scale, Per-Item SFX)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local RewardHelper      = require(ReplicatedStorage.Shared.Tools.RewardHelper)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = nil
local StatGui      = nil

-- ── TopPlayersStats (Bảng Đội Thắng / Winner) ────────────────────────────────────
local TopPlayersStats = nil
local WinLabel        = nil
local AnnounceText    = nil
local NextButton      = nil
local CloseButton1    = nil
local PlayerSlots     = {}

-- ── PlayerStats (Bảng Thống Kê Cá Nhân) ───────────────────
local PlayerStats         = nil
local GameResultText      = nil
local CloseButton2        = nil
local MainAvatarThumbnail = nil

local StatsPanel    = nil
local TotalStats    = nil
local TotalMoney    = nil

-- Tham chiếu tới các dòng thống kê con trong TotalStats
local FreezeVal       = nil
local ThawVal         = nil
local FSpreeVal       = nil
local TSpreeVal       = nil
local FirstBloodVal   = nil
local LastStandingVal = nil
local TotalMoneyVal   = nil

-- Danh sách tuần tự các phần tử chỉ số để thực hiện hiệu ứng StaggerPopOpen
local StatsItemsSequence = {}

-- Thread theo dõi Stagger animation đang chạy dở
local _ActiveStaggerThread = nil

--- Dừng Stagger animation đang chạy dở nếu có
local function StopActiveStagger()
	if _ActiveStaggerThread then
		task.cancel(_ActiveStaggerThread)
		_ActiveStaggerThread = nil
	end
end

--- Phát âm thanh GUI qua AudioHelper
--- @param SoundId number
local function PlayGuiSound(SoundId)
	AudioHelper.PlayGuiSound(SoundId)
end

-- =========================================================
-- PRIVATE
-- =========================================================

local function HideAll()
	StopActiveStagger()

	if TopPlayersStats then
		GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(TopPlayersStats))
		TopPlayersStats.Visible = false
	end
	if PlayerStats then
		GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(PlayerStats))
		PlayerStats.Visible     = false
	end

	for _, Slot in ipairs(PlayerSlots) do
		if Slot then
			GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(Slot))
		end
	end

	for _, StatItem in ipairs(StatsItemsSequence) do
		if StatItem then
			GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(StatItem))
		end
	end

	if StatGui then
		StatGui.Enabled = false
	end
end

local function ShowTopPlayers(TopPlayersData)
	StopActiveStagger()

	StatGui.Enabled     = true
	PlayerStats.Visible = false
	GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(PlayerStats))

	GuiHelper.PopOpen(TopPlayersStats)

	-- Lọc các slot có dữ liệu người chơi thực tế để áp dụng Stagger
	local ActiveSlots = {}
	for i, Slot in ipairs(PlayerSlots) do
		if TopPlayersData and TopPlayersData[i] then
			table.insert(ActiveSlots, Slot)
		else
			Slot.Visible = false
		end
	end

	if #ActiveSlots > 0 then
		_ActiveStaggerThread = GuiHelper.StaggerPopOpen(ActiveSlots, "TopPlayersStats")
	end
end

local function ShowPlayerStats()
	StopActiveStagger()

	StatGui.Enabled = true

	-- Fast Switch: Ẩn TopPlayersStats tức thì để chuyển sang PlayerStats
	GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(TopPlayersStats))
	TopPlayersStats.Visible = false

	-- Bung mở bảng PlayerStats
	GuiHelper.PopOpen(PlayerStats)

	-- Phát âm thanh tổng quan trận đấu
	PlayGuiSound(AudioConfig.Stats.Overall)

	-- Bung nở lần lượt từng dòng thống kê kèm SFX 132948338000932 cho mỗi dòng
	_ActiveStaggerThread = GuiHelper.StaggerPopOpen(StatsItemsSequence, "TotalStats")
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
			Slot.FreezesStats.ValueText.Text = GuiHelper.FormatNumber(Data.Freezes)
			Slot.ThawsStats.ValueText.Text = GuiHelper.FormatNumber(Data.Thaws)

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

	if GameResultText then GameResultText.Text = Won and "VICTORY" or "DEFEATED" end
	
	-- Render ảnh 2D từ eo trở lên (AvatarBust) cho cá nhân người chơi
	if MainAvatarThumbnail then
		SetPlayerThumbnail(MainAvatarThumbnail, LocalPlayer.UserId, Enum.ThumbnailType.AvatarBust)
	end

	-- Format hiển thị chi tiết: "Số lượng (x Giá trị) = Tổng nhận được"
	if FreezeVal then
		FreezeVal.Text = ("%s (×%s) = %s"):format(
			GuiHelper.FormatNumber(Stats.Freezes),
			GuiHelper.FormatNumber(RewardPerFreeze),
			GuiHelper.FormatNumber(Stats.Freezes * RewardPerFreeze)
		)
	end

	if ThawVal then
		ThawVal.Text = ("%s (×%s) = %s"):format(
			GuiHelper.FormatNumber(Stats.Thaws),
			GuiHelper.FormatNumber(RewardPerThaw),
			GuiHelper.FormatNumber(Stats.Thaws * RewardPerThaw)
		)
	end

	-- Đối với First Blood và Last Standing hiển thị số tiền trực tiếp
	if FSpreeVal then
		FSpreeVal.Text = ("%s (×%s) = %s"):format(
			GuiHelper.FormatNumber(Stats.FreezingSprees),
			GuiHelper.FormatNumber(RewardPerFreezingSpree),
			GuiHelper.FormatNumber(Stats.FreezingSprees * RewardPerFreezingSpree)
		)
	end
	if TSpreeVal then
		TSpreeVal.Text = ("%s (×%s) = %s"):format(
			GuiHelper.FormatNumber(Stats.ThawingSprees),
			GuiHelper.FormatNumber(RewardPerThawingSpree),
			GuiHelper.FormatNumber(Stats.ThawingSprees * RewardPerThawingSpree)
		)
	end
	if FirstBloodVal then FirstBloodVal.Text   = Stats.FirstBlood and GuiHelper.FormatNumber(RewardFirstBlood) or "0" end
	if LastStandingVal then LastStandingVal.Text = Stats.LastStanding and GuiHelper.FormatNumber(RewardLastStanding) or "0" end
	
	if TotalMoneyVal then TotalMoneyVal.Text   = GuiHelper.FormatNumber(Stats.MoneyEarned) end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local GameStatisticController = {}

function GameStatisticController:Init()
	local Timeout = (GuiConfig.Timeouts and GuiConfig.Timeouts.DefaultWaitForGui) or 10

	PlayerGui = LocalPlayer:WaitForChild("PlayerGui", Timeout)
	if not PlayerGui then
		warn("[GameStatisticController] Không tìm thấy PlayerGui!")
		return
	end

	StatGui = PlayerGui:WaitForChild("GameStatistic", Timeout)
	if not StatGui then
		warn("[GameStatisticController] Không tìm thấy GameStatistic ScreenGui!")
		return
	end

	StatGui.ResetOnSpawn = false

	-- ── TopPlayersStats ──
	TopPlayersStats = StatGui:WaitForChild("TopPlayersStats", Timeout)
	if TopPlayersStats then
		WinLabel     = TopPlayersStats:WaitForChild("WinLabel", Timeout)
		AnnounceText = WinLabel and WinLabel:WaitForChild("AnnounceText", Timeout)
		NextButton   = TopPlayersStats:WaitForChild("NextButton", Timeout)
		CloseButton1 = TopPlayersStats:WaitForChild("CloseButton", Timeout)

		PlayerSlots = {
			TopPlayersStats:WaitForChild("PlayerTop1", Timeout),
			TopPlayersStats:WaitForChild("PlayerTop2", Timeout),
			TopPlayersStats:WaitForChild("PlayerTop3", Timeout),
		}
	end

	-- ── PlayerStats ──
	PlayerStats = StatGui:WaitForChild("PlayerStats", Timeout)
	if PlayerStats then
		local GameResult = PlayerStats:WaitForChild("GameResult", Timeout)
		GameResultText   = GameResult and GameResult:WaitForChild("GameResultText", Timeout)
		CloseButton2     = PlayerStats:WaitForChild("CloseButton", Timeout)
		MainAvatarThumbnail = PlayerStats:WaitForChild("AvatarThumbnail", Timeout)

		StatsPanel = PlayerStats:WaitForChild("Stats", Timeout)
		if StatsPanel then
			TotalStats = StatsPanel:WaitForChild("TotalStats", Timeout)
			TotalMoney = StatsPanel:WaitForChild("TotalMoney", Timeout)

			if TotalStats then
				local FreezePart       = TotalStats:WaitForChild("Freeze", Timeout)
				local ThawPart         = TotalStats:WaitForChild("Thaw", Timeout)
				local FSpreePart       = TotalStats:WaitForChild("FreezingSpree", Timeout)
				local TSpreePart       = TotalStats:WaitForChild("ThawingSpree", Timeout)
				local FirstBloodPart   = TotalStats:WaitForChild("FirstBlood", Timeout)
				local LastStandingPart = TotalStats:WaitForChild("LastStanding", Timeout)

				FreezeVal       = FreezePart and FreezePart:WaitForChild("ValueText", Timeout)
				ThawVal         = ThawPart and ThawPart:WaitForChild("ValueText", Timeout)
				FSpreeVal       = FSpreePart and FSpreePart:WaitForChild("ValueText", Timeout)
				TSpreeVal       = TSpreePart and TSpreePart:WaitForChild("ValueText", Timeout)
				FirstBloodVal   = FirstBloodPart and FirstBloodPart:WaitForChild("ValueText", Timeout)
				LastStandingVal = LastStandingPart and LastStandingPart:WaitForChild("ValueText", Timeout)

				StatsItemsSequence = {
					FreezePart,
					ThawPart,
					FSpreePart,
					TSpreePart,
					FirstBloodPart,
					LastStandingPart,
					TotalMoney,
				}
			end

			if TotalMoney then
				TotalMoneyVal = TotalMoney:WaitForChild("ValueText", Timeout)
			end
		end
	end

	HideAll()

	-- Lắng nghe dữ liệu cuối trận từ server
	local ShowGameOverEvent = RemoteDefinitions.GetEvent("ShowGameOver")
	ShowGameOverEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end

		-- Xác định text thông báo thắng theo mode
		if AnnounceText then
			if Data.WinTeam then
				-- TeamBased: hiển thị tên đội
				AnnounceText.Text = (Data.WinTeam == "Team1") and "TEAM 1 WINS!" or "TEAM 2 WINS!"
			elseif Data.WinPlayer then
				-- FFA: hiển thị tên người thắng
				AnnounceText.Text = Data.WinPlayer.Name .. " WINS!"
			else
				AnnounceText.Text = "MATCH ENDED"
			end
		end

		FillTopPlayers(Data.TopPlayers or {})
		FillPersonalStats(Data.Won, Data.PersonalStats or {})

		ShowTopPlayers(Data.TopPlayers or {})
	end)

	-- Ẩn GUI khi bắt đầu trận đấu mới
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if Data and (Data.Phase == "Ready" or Data.Phase == "InGame") then
			HideAll()
		end
	end)

	-- Cài đặt sự kiện nút bấm chuyển tiếp và đóng
	if NextButton then
		NextButton.MouseButton1Click:Connect(function()
			ShowPlayerStats()
		end)
	end

	if CloseButton1 and TopPlayersStats then
		CloseButton1.MouseButton1Click:Connect(function()
			GuiHelper.PopClose(TopPlayersStats, nil, function()
				HideAll()
			end)
		end)
	end

	if CloseButton2 and PlayerStats then
		CloseButton2.MouseButton1Click:Connect(function()
			GuiHelper.PopClose(PlayerStats, nil, function()
				HideAll()
			end)
		end)
	end

	print("[GameStatisticController] Khởi tạo thành công với Pop/Stagger Animation & SFX.")
end

return GameStatisticController