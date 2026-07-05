-- QuestController.lua
-- Quản lý GUI Quest phía Client (Phase 7)
-- Pattern: 1 ScrollingFrame chung, TabContainer chuyển tab thì clear + re-clone (giống ShopController)

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- PRIVATE STATE
-- =========================================================

-- GUI references — được gán trong Init()
local _questGui          = nil  -- StarterGui/Menu/Quest (Frame)
local _questList         = nil  -- QuestList (ScrollingFrame)
local _tabDaily          = nil  -- TabContainer/DailyTab (ImageButton)
local _tabMilestone      = nil  -- TabContainer/MilestoneTab (ImageButton)
local _closeButton       = nil  -- CloseButton (ImageButton)
local _rewardAnnouncement = nil -- RewardAnnouncement (Frame)
local _rewardIcon        = nil  -- RewardAnnouncement/Icon (ImageLabel)
local _rewardAmount      = nil  -- RewardAnnouncement/Amount (TextLabel)
local _questTemplates    = nil  -- QuestTemplates (Folder)
local _menuFrame         = nil  -- StarterGui/Menu (Frame — parent của Quest)
local _navGui            = nil  -- NavigationButton ScreenGui

-- Tab đang active: "Daily" hoặc "Milestone"
local _currentTab = "Daily"

-- Cache dữ liệu quest nhận từ server
local _questData = nil  -- { Daily = {...}, Milestone = {...} }

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
	local S = Instance.new("Sound")
	S.SoundId = "rbxassetid://" .. tostring(SoundId)
	S.Volume = 1
	S.Parent = PlayerGui
	S:Play()
	game:GetService("Debris"):AddItem(S, 3)
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

--- Ẩn tất cả Frame con trong Menu (trừ frame đang mở)
--- @param ExceptFrame Instance | nil
local function HideAllMenuFrames(ExceptFrame)
	if not _menuFrame then return end
	for _, Child in ipairs(_menuFrame:GetChildren()) do
		if Child:IsA("Frame") and Child ~= ExceptFrame then
			Child.Visible = false
		end
	end
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

	-- Reset về scale 0 rồi hiện
	_rewardAnnouncement.Size         = UDim2.fromScale(0, 0)
	_rewardAnnouncement.AnchorPoint  = Vector2.new(0.5, 0.5)
	_rewardAnnouncement.Visible      = true

	-- Lấy kích thước gốc từ UI (giả định thiết kế sẵn trong Studio)
	local TargetSize = UDim2.fromScale(0.4, 0.15)

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
			end
		end)
	end)
end

-- =========================================================
-- RENDER LOGIC
-- =========================================================

--- Render danh sách quest vào QuestList
--- @param QuestList table  -- mảng quest data từ server
local function RenderQuestList(QuestList)
	ClearQuestList()
	if not _questTemplates then return end

	local Template = _questTemplates:FindFirstChild("QuestTemplate")
	if not Template then
		warn("[QuestController] Không tìm thấy QuestTemplates/QuestTemplate.")
		return
	end

	for _, QuestEntry in ipairs(QuestList) do
		local Frame = Template:Clone()
		Frame.Name    = QuestEntry.QuestId
		Frame.Visible = true
		Frame.Parent  = _questList

		-- QuestText
		local QuestText = Frame:FindFirstChild("QuestText")
		if QuestText then
			QuestText.Text = QuestEntry.Description
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
			local CanClaim = (not QuestEntry.Claimed) and (QuestEntry.Progress >= QuestEntry.Requirement)

			-- Hiện/ẩn ClaimButton tùy trạng thái
			ClaimButton.Visible = CanClaim

			if CanClaim then
				ClaimButton.MouseButton1Click:Connect(function()
					-- Disable ngay để tránh double-click
					ClaimButton.Active = false

					-- Gọi server
					local ClaimQuestFn = RemoteDefinitions.GetFunction("ClaimQuest")
					local Result = ClaimQuestFn:InvokeServer(
						_currentTab == "Daily" and "Daily" or "Milestone",
						QuestEntry.QuestId
					)

					if Result and Result.Success then
						-- Phase 8.3: Phát QuestReward sfx khi claim thành công
						PlayGuiSound(SFX_QUEST_REWARD)
						-- Hiện thông báo phần thưởng
						ShowRewardAnnouncement(Result.RewardType, Result.RewardAmount)

						-- Refresh UI để phản ánh trạng thái mới
						task.spawn(function()
							task.wait(0.3) -- Delay nhỏ để server lưu xong
							local GetQuestDataFn = RemoteDefinitions.GetFunction("GetQuestData")
							_questData = GetQuestDataFn:InvokeServer()
							if _questData then
								local List = (_currentTab == "Daily") and _questData.Daily or _questData.Milestone
								RenderQuestList(List)
							end
						end)
					else
						-- Nếu thất bại, re-enable button
						ClaimButton.Active = true
					end
				end)
			end
		end
	end
end

--- Refresh toàn bộ dữ liệu từ server rồi render tab hiện tại
local function RefreshQuestUI()
	local GetQuestDataFn = RemoteDefinitions.GetFunction("GetQuestData")
	_questData = GetQuestDataFn:InvokeServer()

	if not _questData then
		warn("[QuestController] Không nhận được dữ liệu quest từ server.")
		return
	end

	local QuestList = (_currentTab == "Daily") and _questData.Daily or _questData.Milestone
	RenderQuestList(QuestList)
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

	if _questData then
		local QuestList = (TabName == "Daily") and _questData.Daily or _questData.Milestone
		RenderQuestList(QuestList)
	end
end

-- =========================================================
-- OPEN / CLOSE
-- =========================================================

local QuestController = {}

local function CloseQuest()
	if not _questGui then return end
	_questGui.Visible = false
end

local function OpenQuest()
	if not _questGui then return end

	-- Ẩn các frame khác trong Menu
	HideAllMenuFrames(_questGui)
	_questGui.Visible = true

	-- Ẩn NavigationButton khi quest mở (không cần ẩn, quest nằm trong Menu)
	-- Note: Quest là frame trong Menu, không phải overlay full-screen

	-- Reset tab về Daily khi mở mới
	_currentTab = "Daily"
	UpdateTabHighlight("Daily")

	-- Refresh dữ liệu từ server
	task.spawn(RefreshQuestUI)
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

	-- QuestTemplates folder
	_questTemplates = _questGui:WaitForChild("QuestTemplates")

	-- QuestList ScrollingFrame
	_questList = _questGui:WaitForChild("QuestList")

	-- TabContainer
	local TabContainer = _questGui:WaitForChild("TabContainer")
	_tabDaily          = TabContainer:WaitForChild("DailyTab")
	_tabMilestone      = TabContainer:WaitForChild("MilestoneTab")

	-- CloseButton
	_closeButton = _questGui:WaitForChild("CloseButton")

	-- RewardAnnouncement
	_rewardAnnouncement = _questGui:WaitForChild("RewardAnnouncement")
	_rewardIcon         = _rewardAnnouncement:FindFirstChild("Icon")
	_rewardAmount       = _rewardAnnouncement:FindFirstChild("Amount")
	_rewardAnnouncement.Visible = false

	-- NavigationButton
	_navGui = PlayerGui:WaitForChild("NavigationButton")

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
	local NavButton = _navGui:WaitForChild("Button"):WaitForChild("Quest")
	if NavButton then
		NavButton.MouseButton1Click:Connect(OpenQuest)
	else
		warn("[QuestController] Không tìm thấy NavigationButton/Button/Quest.")
	end

	-- Highlight tab mặc định
	UpdateTabHighlight("Daily")

	print("[QuestController] Đã khởi tạo.")
end

return QuestController
