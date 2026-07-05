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

--- Thiết lập và tạo mô hình nhân vật 3D trong ViewportFrame bằng UserId
local function SetupPlayerViewport(viewportFrame, userId)
	-- Dọn dẹp tất cả Model, Camera và WorldModel cũ để tránh rò rỉ bộ nhớ
	for _, child in ipairs(viewportFrame:GetChildren()) do
		if child:IsA("Model") or child:IsA("Camera") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end

	-- Tạo Camera với góc nhìn hẹp để avatar ít bị méo
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera

	-- Tạo WorldModel làm lớp trung gian bắt buộc để Humanoid/Joints/Accessories hoạt động đúng
	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewportFrame

	--- Căn chỉnh camera tự động dựa trên kích thước thực tế của avatar
	local function AlignCameraToModel(model)
		model.Parent = worldModel

		-- Khóa cứng mô hình tĩnh (Anchor) và xóa bỏ các script/animator thừa để tránh chuyển động
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Sound") or descendant:IsA("Animator") then
				descendant:Destroy()
			end
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = true
		end

		-- Đưa toàn bộ avatar về gốc tọa độ cố định để camera không bị lệch
		model:PivotTo(CFrame.new(0, 0, 0))

		-- Tìm bộ phận Head để chỉnh camera trực diện vào khuôn mặt (Portrait Face View)
		local head = model:FindFirstChild("Head")
		if head then
			local distance = GameConfig.GUI.ViewportCameraDistance -- Chỉnh tại GameConfig.GUI.ViewportCameraDistance
			local headCFrame = head.CFrame
			-- Trong Roblox, mặt của nhân vật hướng theo LookVector của Head
			local cameraPos = headCFrame.Position + (headCFrame.LookVector * distance)
			camera.CFrame = CFrame.new(cameraPos, headCFrame.Position)
		else
			-- Fallback: Căn chỉnh camera tự động theo bounding box nếu không tìm thấy Head
			local pivotCFrame, size = model:GetBoundingBox()
			local avatarHeight  = size.Y
			local avatarCenter  = pivotCFrame.Position

			local distance = avatarHeight * 0.9
			local lookAtTarget = avatarCenter + Vector3.new(0, avatarHeight * 0.1, 0)
			local cameraPos    = avatarCenter + Vector3.new(0, avatarHeight * 1, -distance)

			camera.CFrame = CFrame.new(cameraPos, lookAtTarget)
		end
	end

	-- Chạy tiến trình tải model bất đồng bộ để không làm đơ client
	task.spawn(function()
		local clonedModel = nil

		-- Ưu tiên 1: Lấy model tĩnh đã được Server chuẩn bị sẵn trong ReplicatedStorage (cho Top 1, 2, 3)
		local PlayerAvatars = ReplicatedStorage:WaitForChild("PlayerAvatars", 5)
		local pregeneratedModel = PlayerAvatars and PlayerAvatars:WaitForChild(tostring(userId), 5)

		if pregeneratedModel then
			clonedModel = pregeneratedModel:Clone()
		else
			-- Ưu tiên 2: Clone Character hiện tại của người chơi (dành cho PlayerStats/LocalPlayer)
			local targetPlayer = nil
			for _, player in ipairs(Players:GetPlayers()) do
				if player.UserId == userId then
					targetPlayer = player
					break
				end
			end

			if targetPlayer and targetPlayer.Character then
				local character = targetPlayer.Character
				character.Archivable = true
				clonedModel = character:Clone()
				character.Archivable = false
			end
		end

		if clonedModel then
			AlignCameraToModel(clonedModel)
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

			-- Render mô hình 3D cho Top player — dùng UserId trực tiếp từ server
			local userId = data.UserId or 0
			if userId ~= 0 then
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

	GameResultText.Text  = won and "VICTORY" or "DEFEAT"
	
	-- Render mô hình 3D của chính người chơi hiện tại
	SetupPlayerViewport(MainViewport, LocalPlayer.UserId)

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