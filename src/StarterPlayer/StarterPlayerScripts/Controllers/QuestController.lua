-- QuestController.lua
-- Quản lý GUI Quest phía Client (Phase 7)
-- Pattern: 1 ScrollingFrame chung, TabContainer chuyển tab thì clear + re-clone (giống ShopController)

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local QuestConfig       = require(ReplicatedStorage.Shared.Config.QuestConfig)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- PRIVATE STATE
-- =========================================================

-- Configuration text formats
local TEXT_MILESTONE     = "Repeatable quest"
local FORMAT_DAILY_TIME  = "Time remain: %02d:%02d:%02d"

-- GUI references — được gán trong Init()
local _questGui          = nil  -- StarterGui/Menu/Quest (Frame)
local _questList         = nil  -- MainFrame/QuestList (ScrollingFrame)
local _notificationText  = nil  -- MainFrame/NotificationText (TextLabel)
local _tabDaily          = nil  -- TabContainer/DailyTab (ImageButton)
local _tabMilestone      = nil  -- TabContainer/MilestoneTab (ImageButton)
local _closeButton       = nil  -- CloseButton (ImageButton)
local _rewardAnnouncement = nil -- RewardAnnouncement (Frame)
local _rewardIcon        = nil  -- RewardAnnouncement/Icon (ImageLabel)
local _rewardAmount      = nil  -- RewardAnnouncement/AmountText (TextLabel)
local _rewardOriginalSize = nil -- Kích thước ban đầu từ GUI (UDim2)
local _templates         = nil  -- Templates (Folder)
local _menuFrame         = nil  -- StarterGui/Menu (Frame — parent của Quest)
local _navGui            = nil  -- NavigationButtons ScreenGui
local _navButton         = nil  -- NavigationButtons/Buttons (Frame — ẩn khi Quest mở)

-- Tab đang active: "Daily" hoặc "Milestone"
local _currentTab = "Daily"

-- Cache dữ liệu quest nhận từ server
local _questData = nil  -- { Daily = {...}, Milestone = {...}, NextResetTimestamp = number }

-- Task quản lý vòng lặp đếm ngược và auto refresh UI
local _countdownTask = nil
local _autoRefreshTask = nil

-- Tab active color và inactive color (dùng BackgroundColor3 giống pattern InventoryController)
local COLOR_ACTIVE   = Color3.fromRGB(255, 255, 255)
local COLOR_INACTIVE = Color3.fromRGB(47, 47, 47)

-- Tween thông số cho RewardAnnouncement
local TWEEN_INFO_IN  = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- =========================================================
-- SFX
-- =========================================================

local SFX_BUTTON_CLICK       = 7249903719
local SFX_CLOSE_BUTTON_CLICK = 103307955424380
local SFX_QUEST_REWARD       = 116439187028468

local function PlayGuiSound(SoundId)
	GuiHelper.PlayGuiSound(SoundId)
end

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Lazy-require PlayerDataController để tránh circular dependency
local _playerDataController = nil
local function GetPlayerDataController()
	if not _playerDataController then
		_playerDataController = require(script.Parent.PlayerDataController)
	end
	return _playerDataController
end

--- Lazy-require GameStateController để kiểm tra spectate
local _gameStateController = nil
local function GetGameStateController()
	if not _gameStateController then
		_gameStateController = require(script.Parent.GameStateController)
	end
	return _gameStateController
end

--- Lazy-require SpectateController để tránh circular dependency
local _spectateController = nil
local function GetSpectateController()
	if not _spectateController then
		local Module = script.Parent:FindFirstChild("SpectateController")
		if Module then
			_spectateController = require(Module)
		end
	end
	return _spectateController
end

--- Ẩn tất cả Frame con trong Menu (trừ frame đang mở)
--- @param ExceptFrame Instance | nil
local function HideAllMenuFrames(ExceptFrame)
	GuiHelper.HideOtherMenuFrames(_menuFrame, ExceptFrame)
end

--- Highlight tab button đang active
--- @param ActiveTab string  -- "Daily" | "Milestone"
local function UpdateTabHighlight(ActiveTab)
	if _tabDaily then
		_tabDaily.BackgroundColor3 = (ActiveTab == "Daily") and COLOR_ACTIVE or COLOR_INACTIVE
	end
	if _tabMilestone then
		_tabMilestone.BackgroundColor3 = (ActiveTab == "Milestone") and COLOR_ACTIVE or COLOR_INACTIVE
	end
end

--- Dọn sạch tất cả clone trong QuestList
local function ClearQuestList()
	if not _questList then return end
	for _, Child in ipairs(_questList:GetChildren()) do
		if not Child:IsA("UIListLayout") and not Child:IsA("UIPadding") then
			Child:Destroy()
		end
	end
end

--- Render ProgressBar: điều chỉnh chiều rộng của Progress frame bên trong ProgressBar
--- @param ProgressBarFrame Frame
--- @param Current number
--- @param Requirement number
local function RenderProgressBar(ProgressBarFrame, Current, Requirement)
	local ProgressFill = ProgressBarFrame:FindFirstChild("Progress")
	local ProgressText = ProgressBarFrame:FindFirstChild("ProgressText")

	local Ratio = (Requirement > 0) and math.clamp(Current / Requirement, 0, 1) or 1

	if ProgressFill then
		-- Điều chỉnh theo trục X (UDim2 Scale)
		ProgressFill.Size = UDim2.new(Ratio, 0, 1, 0)
	end

	if ProgressText then
		if Current >= Requirement then
			ProgressText.Text = "DONE"
		else
			ProgressText.Text = ("%d/%d"):format(Current, Requirement)
		end
	end
end

--- Hiện RewardAnnouncement với animation zoom in → tồn tại 3s → zoom out → ẩn
--- @param RewardType string
--- @param RewardAmount number
local function ShowRewardAnnouncement(RewardType, RewardAmount)
	if not _rewardAnnouncement then return end

	-- Set nội dung
	if _rewardAmount then
		_rewardAmount.Text = "+" .. tostring(RewardAmount) .. " " .. RewardType
	end

	-- Lấy kích thước gốc được lưu từ UI trong Studio
	local TargetSize = _rewardOriginalSize or _rewardAnnouncement.Size

	-- Reset về scale 0 rồi hiện
	_rewardAnnouncement.Size         = UDim2.fromScale(0, 0)
	_rewardAnnouncement.AnchorPoint  = Vector2.new(0.5, 0.5)
	_rewardAnnouncement.Visible      = true

	-- Zoom in
	local TweenIn = TweenService:Create(_rewardAnnouncement, TWEEN_INFO_IN, { Size = TargetSize })
	TweenIn:Play()

	-- Sau 3 giây → zoom out và ẩn
	task.delay(3, function()
		if not _rewardAnnouncement then return end
		local TweenOut = TweenService:Create(_rewardAnnouncement, TWEEN_INFO_OUT, {
			Size = UDim2.fromScale(0, 0)
		})
		TweenOut:Play()
		TweenOut.Completed:Once(function()
			if _rewardAnnouncement then
				_rewardAnnouncement.Visible = false
				_rewardAnnouncement.Size = TargetSize
			end
		end)
	end)
end

-- =========================================================
-- NOTIFICATION & COUNTDOWN LOGIC
-- =========================================================

--- Format thời gian còn lại thành chuỗi "Time remain: hh:mm:ss"
--- @param TotalSeconds number
--- @return string
local function FormatTimeRemaining(TotalSeconds)
	local Seconds = math.max(0, math.floor(TotalSeconds))
	local Hours   = math.floor(Seconds / 3600)
	local Mins    = math.floor((Seconds % 3600) / 60)
	local Secs    = math.floor(Seconds % 60)
	return string.format(FORMAT_DAILY_TIME, Hours, Mins, Secs)
end

--- Hủy thread auto refresh nếu đang chạy
local function StopAutoRefreshLoop()
	if _autoRefreshTask then
		task.cancel(_autoRefreshTask)
		_autoRefreshTask = nil
	end
end

-- Khai báo trước hàm RefreshQuestUI để vòng lặp countdown và auto-refresh sử dụng
local RefreshQuestUI

--- Chạy thread auto refresh dữ liệu từ server khi GUI đang mở (mỗi 1 giây)
local function StartAutoRefreshLoop()
	StopAutoRefreshLoop()

	_autoRefreshTask = task.spawn(function()
		while _questGui and _questGui.Visible do
			task.wait(1)
			if _questGui and _questGui.Visible and RefreshQuestUI then
				RefreshQuestUI()
			end
		end
		_autoRefreshTask = nil
	end)
end

--- Hủy thread đếm ngược nếu đang chạy
local function StopCountdownLoop()
	if _countdownTask then
		task.cancel(_countdownTask)
		_countdownTask = nil
	end
end

--- Chạy thread đếm ngược cập nhật NotificationText khi ở tab Daily
local function StartCountdownLoop()
	StopCountdownLoop()

	_countdownTask = task.spawn(function()
		while _questGui and _questGui.Visible and _currentTab == "Daily" do
			if _questData and _questData.NextResetTimestamp then
				local Remaining = _questData.NextResetTimestamp - os.time()
				if Remaining <= 0 then
					if _notificationText then
						_notificationText.Text = string.format(FORMAT_DAILY_TIME, 0, 0, 0)
					end
					-- Tự động làm mới dữ liệu Quest từ server khi hết giờ
					if RefreshQuestUI then
						RefreshQuestUI()
					end
				else
					if _notificationText then
						_notificationText.Text = FormatTimeRemaining(Remaining)
					end
				end
			end
			task.wait(1)
		end
		_countdownTask = nil
	end)
end

--- Cập nhật hiển thị NotificationText theo Tab hiện tại
local function UpdateNotificationDisplay()
	if _currentTab == "Milestone" then
		StopCountdownLoop()
		if _notificationText then
			_notificationText.Text = TEXT_MILESTONE
		end
	elseif _currentTab == "Daily" then
		StartCountdownLoop()
	end
end

-- =========================================================
-- RENDER LOGIC
-- =========================================================

--- Render danh sách quest vào QuestList (cập nhật mượt không làm mất vị trí cuộn UI)
--- @param QuestList table  -- mảng quest data từ server
local function RenderQuestList(QuestList)
	if not _templates or not _questList then return end

	local Template = _templates:FindFirstChild("QuestTemplate")
	if not Template then
		warn("[QuestController] Không tìm thấy Templates/QuestTemplate.")
		return
	end

	local ValidQuestIds = {}

	for _, QuestEntry in ipairs(QuestList) do
		ValidQuestIds[QuestEntry.QuestId] = true

		local Frame = _questList:FindFirstChild(QuestEntry.QuestId)
		if not Frame then
			Frame = Template:Clone()
			Frame.Name    = QuestEntry.QuestId
			Frame.Visible = true
			Frame.Parent  = _questList
		end

		-- DescriptionText
		local DescriptionText = Frame:FindFirstChild("DescriptionText")
		if DescriptionText then
			DescriptionText.Text = QuestEntry.Description
		end

		-- Reward
		local RewardFrame = Frame:FindFirstChild("Reward")
		if RewardFrame then
			local AmountLabel = RewardFrame:FindFirstChild("Amount")
			if AmountLabel then
				AmountLabel.Text = tostring(QuestEntry.RewardAmount)
			end
		end

		-- ProgressBar
		local ProgressBarFrame = Frame:FindFirstChild("ProgressBar")
		if ProgressBarFrame then
			RenderProgressBar(ProgressBarFrame, QuestEntry.Progress, QuestEntry.Requirement)
		end

		-- ClaimButton
		local ClaimButton = Frame:FindFirstChild("ClaimButton")
		if ClaimButton then
			ClaimButton.Visible = true

			local IsClaimed = QuestEntry.Claimed == true
			local CanClaim  = (not IsClaimed) and (QuestEntry.Progress >= QuestEntry.Requirement)

			-- Cập nhật hình nền background và thuộc tính tương tác dựa trên trạng thái
			local TargetImage = nil
			local ButtonText  = "Claim"

			if IsClaimed then
				TargetImage = QuestConfig.ClaimButtonImages.Completed
				ButtonText  = "Claimed"
				ClaimButton.Active = false
			elseif CanClaim then
				TargetImage = QuestConfig.ClaimButtonImages.Completed
				ButtonText  = "Claim"
				ClaimButton.Active = true
			else
				TargetImage = QuestConfig.ClaimButtonImages.Uncompleted
				ButtonText  = "Claim"
				ClaimButton.Active = false
			end

			if TargetImage then
				if ClaimButton:IsA("ImageButton") or ClaimButton:IsA("ImageLabel") then
					ClaimButton.Image = TargetImage
				end
			end

			local ButtonTextLabel = ClaimButton:FindFirstChildOfClass("TextLabel")
				or ClaimButton:FindFirstChild("Text")
				or ClaimButton:FindFirstChild("ClaimText")
			if ButtonTextLabel then
				ButtonTextLabel.Text = ButtonText
			elseif ClaimButton:IsA("TextButton") then
				ClaimButton.Text = ButtonText
			end

			if not Frame:GetAttribute("HasClaimHandler") then
				Frame:SetAttribute("HasClaimHandler", true)

				ClaimButton.MouseButton1Click:Connect(function()
					local IsClaimable = Frame:GetAttribute("CanClaim")
					if not IsClaimable then return end

					ClaimButton.Active = false
					Frame:SetAttribute("CanClaim", false)

					local ClaimQuestFn = RemoteDefinitions.GetFunction("ClaimQuest")
					local Result = ClaimQuestFn:InvokeServer(
						_currentTab == "Daily" and "Daily" or "Milestone",
						Frame.Name
					)

					if Result and Result.Success then
						PlayGuiSound(SFX_QUEST_REWARD)
						ShowRewardAnnouncement(Result.RewardType, Result.RewardAmount)

						task.spawn(function()
							task.wait(0.3)
							RefreshQuestUI()
						end)
					else
						ClaimButton.Active = true
						Frame:SetAttribute("CanClaim", true)
					end
				end)
			end

			Frame:SetAttribute("CanClaim", CanClaim)
		end
	end

	-- Xóa các Frame không thuộc tab hiện tại
	for _, Child in ipairs(_questList:GetChildren()) do
		if not Child:IsA("UIListLayout") and not Child:IsA("UIPadding") then
			if not ValidQuestIds[Child.Name] then
				Child:Destroy()
			end
		end
	end
end

--- Refresh toàn bộ dữ liệu từ server rồi render tab hiện tại
RefreshQuestUI = function()
	local GetQuestDataFn = RemoteDefinitions.GetFunction("GetQuestData")
	_questData = GetQuestDataFn:InvokeServer()

	if not _questData then
		warn("[QuestController] Không nhận được dữ liệu quest từ server.")
		return
	end

	local QuestList = (_currentTab == "Daily") and _questData.Daily or _questData.Milestone
	RenderQuestList(QuestList)
	UpdateNotificationDisplay()
end

-- =========================================================
-- TAB SWITCHING
-- =========================================================

--- Chuyển tab và re-render
--- @param TabName string  -- "Daily" | "Milestone"
local function SwitchTab(TabName)
	if _currentTab == TabName and _questData then
		return -- Không cần làm gì
	end
	_currentTab = TabName
	UpdateTabHighlight(TabName)

	ClearQuestList()

	if _questData then
		local QuestList = (TabName == "Daily") and _questData.Daily or _questData.Milestone
		RenderQuestList(QuestList)
		UpdateNotificationDisplay()
	end
end

-- =========================================================
-- OPEN / CLOSE
-- =========================================================

local QuestController = {}

local function CloseQuest()
	if not _questGui then return end
	StopCountdownLoop()
	StopAutoRefreshLoop()
	_questGui.Visible = false
	-- Khôi phục NavButton trừ khi đang spectate
	if _navButton then
		local SpecCtrl = GetSpectateController()
		local IsSpectating = SpecCtrl and SpecCtrl.IsSpectating and SpecCtrl.IsSpectating()
		_navButton.Visible = not IsSpectating
	end
end

local function OpenQuest()
	if not _questGui then return end

	-- Ẩn các frame khác trong Menu và NavButton
	HideAllMenuFrames(_questGui)
	if _navButton then _navButton.Visible = false end
	_questGui.Visible = true

	-- Reset tab về Daily khi mở mới
	_currentTab = "Daily"
	UpdateTabHighlight("Daily")

	-- Refresh dữ liệu từ server và kích hoạt tự động làm mới
	task.spawn(function()
		RefreshQuestUI()
		StartAutoRefreshLoop()
	end)
end

-- =========================================================
-- INIT
-- =========================================================

function QuestController:Init()
	-- Chờ PlayerGui sẵn sàng
	local Menu = PlayerGui:WaitForChild("Menu")
	_menuFrame  = Menu

	_questGui   = Menu:WaitForChild("Quest")

	-- Đảm bảo GUI không bị reset khi character chết
	local MenuGui = Menu.Parent
	if MenuGui and MenuGui:IsA("ScreenGui") then
		MenuGui.ResetOnSpawn = false
	end

	-- Templates folder
	_templates = _questGui:WaitForChild("Templates")

	-- MainFrame, QuestList ScrollingFrame & NotificationText
	local MainFrame    = _questGui:WaitForChild("MainFrame")
	_questList         = MainFrame:WaitForChild("QuestList")
	_notificationText  = MainFrame:WaitForChild("NotificationText")

	-- TabContainer
	local TabContainer = _questGui:WaitForChild("TabContainer")
	_tabDaily          = TabContainer:WaitForChild("DailyTab")
	_tabMilestone      = TabContainer:WaitForChild("MilestoneTab")

	-- CloseButton
	_closeButton = _questGui:WaitForChild("CloseButton")

	-- RewardAnnouncement
	_rewardAnnouncement = _questGui:WaitForChild("RewardAnnouncement")
	_rewardIcon         = _rewardAnnouncement:FindFirstChild("Icon")
	_rewardAmount       = _rewardAnnouncement:FindFirstChild("AmountText")
	_rewardOriginalSize = _rewardAnnouncement.Size
	_rewardAnnouncement.Visible = false

	-- NavigationButtons
	_navGui    = GuiHelper.GetNavigationGui()
	_navButton = GuiHelper.GetNavButtonsContainer()

	-- ── Kết nối sự kiện ──

	-- CloseButton
	_closeButton.MouseButton1Click:Connect(function()
		PlayGuiSound(SFX_CLOSE_BUTTON_CLICK)
		CloseQuest()
	end)

	-- Tab buttons
	_tabDaily.MouseButton1Click:Connect(function()
		PlayGuiSound(SFX_BUTTON_CLICK)
		SwitchTab("Daily")
	end)
	_tabMilestone.MouseButton1Click:Connect(function()
		PlayGuiSound(SFX_BUTTON_CLICK)
		SwitchTab("Milestone")
	end)

	-- Navigation button mở Quest
	local NavQuestBtn = GuiHelper.GetNavButton("Quest")
	if NavQuestBtn then
		NavQuestBtn.MouseButton1Click:Connect(OpenQuest)
	else
		warn("[QuestController] Không tìm thấy nút Quest trong NavigationButtons.")
	end

	-- Highlight tab mặc định
	UpdateTabHighlight("Daily")

	print("[QuestController] Đã khởi tạo.")
end

--- Hàm public để đóng/mở Quest từ bên ngoài (ví dụ GameStateController)
--- @param Visible boolean
function QuestController.SetVisible(Visible)
	if not _questGui then return end
	if Visible then
		OpenQuest()
	else
		CloseQuest()
	end
end

return QuestController
