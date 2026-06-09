-- GameStatisticController.lua (ModuleScript)
-- Điều khiển GUI GameStatistic mới với ViewportFrame và UIListLayout
--

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
local PlayerStats    = StatGui:WaitForChild("PlayerStats")
local GameResultText = PlayerStats:WaitForChild("GameResult"):WaitForChild("GameResultText")
local CloseButton2   = PlayerStats:WaitForChild("CloseButton")
local MainViewport   = PlayerStats:WaitForChild("PlayerViewport")

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
end

--- Thiết lập và tạo mô hình nhân vật 3D trong ViewportFrame bằng UserId
local function SetupPlayerViewport(viewportFrame, userId)
	-- Xóa bỏ các Model/Camera cũ nếu có
	for _, child in ipairs(viewportFrame:GetChildren()) do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end

	-- Tạo Camera hướng trực tiếp vào nhân vật
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	-- Tải mô hình nhân vật bất đồng bộ (giúp client không bị đơ)
	task.spawn(function()
		local success, model = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)

		if success and model then
			model.Parent = viewportFrame
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Căn chỉnh camera đứng trước ngực nhân vật, hơi chúc nhẹ xuống
				camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 5.5), hrp.Position + Vector3.new(0, 0.5, 0))
			end
		end
	end)
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

			-- Render mô hình 3D cho Top player
			local userId = GetUserIdFromName(data.Name)
			if userId > 0 then
				SetupPlayerViewport(slot.PlayerViewport, userId)
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

	GameResultText.Text  = won and "YOU WIN! 🏆" or "YOU LOSE 💀"
	
	-- Render mô hình 3D của chính người chơi hiện tại
	SetupPlayerViewport(MainViewport, LocalPlayer.UserId)

	-- Format hiển thị chi tiết: "Số lượng (x Giá trị) = Tổng nhận được"
	FreezeVal.Text = ("%d (×%d) = %d"):format(
		stats.Freezes, eco.RewardPerFreeze, stats.Freezes * eco.RewardPerFreeze
	)

	ThawVal.Text = ("%d (×%d) = %d"):format(
		stats.Thaws, eco.RewardPerThaw, stats.Thaws * eco.RewardPerThaw
	)

	-- Đối với Spree, First Blood và Last Standing hiển thị số tiền trực tiếp
	FSpreeVal.Text       = tostring(stats.FreezingSprees * eco.RewardPerFreezingSpree)
	TSpreeVal.Text       = tostring(stats.ThawingSprees * eco.RewardPerThawingSpree)
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
		local teamLabel = (winTeam == "Team1") and "TEAM 1 WINS! 🏆" or "TEAM 2 WINS! 🏆"
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
	NextButton.MouseButton1Click:Connect(ShowPlayerStats)
	CloseButton1.MouseButton1Click:Connect(HideAll)
	CloseButton2.MouseButton1Click:Connect(HideAll)

	print("[GameStatisticController] Khởi tạo thành công với cấu trúc GUI mới.")
end

return GameStatisticController