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
local PlayerStats         = StatGui:WaitForChild("PlayerStats")
local GameResultText      = PlayerStats:WaitForChild("GameResult"):WaitForChild("GameResultText")
local CloseButton2        = PlayerStats:WaitForChild("CloseButton")
local MainAvatarThumbnail = PlayerStats:WaitForChild("AvatarThumbnail")

local StatsPanel    = PlayerStats:WaitForChild("Stats")
local TotalStats    = StatsPanel:WaitForChild("TotalStats")
local TotalMoney    = StatsPanel:WaitForChild("TotalMoney")

-- Tham chiếu tới các dòng thống kê con trong TotalStats
local FreezeVal       = TotalStats:WaitForChild("Freeze"):WaitForChild("ValueText")
local ThawVal         = TotalStats:WaitForChild("Thaw"):WaitForChild("ValueText")
local FSpreeVal       = TotalStats:WaitForChild("FreezingSpree"):WaitForChild("ValueText")
local TSpreeVal       = TotalStats:WaitForChild("ThawingSpree"):WaitForChild("ValueText")
local FirstBloodVal   = TotalStats:WaitForChild("FirstBlood"):WaitForChild("ValueText")
local LastStandingVal = TotalStats:WaitForChild("LastStanding"):WaitForChild("ValueText")
local TotalMoneyVal   = TotalMoney:WaitForChild("ValueText")

-- Danh sách tuần tự các phần tử chỉ số để thực hiện hiệu ứng StaggerPopOpen
local StatsItemsSequence = {
	TotalStats:WaitForChild("Freeze"),
	TotalStats:WaitForChild("Thaw"),
	TotalStats:WaitForChild("FreezingSpree"),
	TotalStats:WaitForChild("ThawingSpree"),
	TotalStats:WaitForChild("FirstBlood"),
	TotalStats:WaitForChild("LastStanding"),
	TotalMoney,
}

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

	GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(TopPlayersStats))
	GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(PlayerStats))

	for _, Slot in ipairs(PlayerSlots) do
		GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(Slot))
	end

	for _, StatItem in ipairs(StatsItemsSequence) do
		GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(StatItem))
	end

	TopPlayersStats.Visible = false
	PlayerStats.Visible     = false
	StatGui.Enabled         = false
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

	-- Gắn hiệu ứng phóng to hover/click và âm thanh SFX cho NextButton
	GuiHelper.BindButtonScale(NextButton)
	GuiHelper.BindButtonSound(NextButton, AudioConfig.Gui.ButtonClick, AudioConfig.Gui.MouseEnter)

	-- Gắn hiệu ứng cho các nút đóng CloseButton
	GuiHelper.BindButtonScale(CloseButton1)
	GuiHelper.BindButtonSound(CloseButton1, AudioConfig.Gui.CloseButtonClick, AudioConfig.Gui.MouseEnter)

	GuiHelper.BindButtonScale(CloseButton2)
	GuiHelper.BindButtonSound(CloseButton2, AudioConfig.Gui.CloseButtonClick, AudioConfig.Gui.MouseEnter)

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
	NextButton.MouseButton1Click:Connect(function()
		ShowPlayerStats()
	end)

	CloseButton1.MouseButton1Click:Connect(function()
		GuiHelper.PopClose(TopPlayersStats, nil, function()
			HideAll()
		end)
	end)

	CloseButton2.MouseButton1Click:Connect(function()
		GuiHelper.PopClose(PlayerStats, nil, function()
			HideAll()
		end)
	end)

	print("[GameStatisticController] Khởi tạo thành công với Pop/Stagger Animation & SFX.")
end

return GameStatisticController