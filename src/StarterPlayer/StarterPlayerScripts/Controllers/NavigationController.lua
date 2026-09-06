-- NavigationController.lua (ModuleScript)
-- Quản lý toàn bộ ScreenGui "NavigationButtons" (Shop, Inventory, Profile, Quest, Spectate, Money HUD)
-- Điều khiển hiệu ứng âm thanh, animation tương tác và kết nối tới MenuController / SpectateController

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local AudioConfig       = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local AudioHelper       = require(ReplicatedStorage.Shared.Tools.AudioHelper)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- GUI REFERENCES & STATE
-- =========================================================

local NavGui           = nil
local ButtonsContainer = nil
local ExtraContainer   = nil
local StatsContainer   = nil
local MoneyLabel       = nil

-- References đến Controllers liên quan (được nạp trong :Start())
local _MenuController = nil
local _SpectateController = nil
local _PlayerDataController = nil

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Tìm MoneyLabel hiển thị tiền trong NavigationButtons
local function ResolveMoneyLabel()
	if MoneyLabel and MoneyLabel:IsDescendantOf(PlayerGui) then
		return MoneyLabel
	end
	MoneyLabel = GuiHelper.GetMoneyLabel(GuiConfig.Timeouts.ShortWait)
	return MoneyLabel
end

--- Kết nối sự kiện click của các nút chức năng điều hướng
local function BindNavigationActions()
	-- 1. Nút Shop
	local ShopBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Shop)
	if ShopBtn then
		ShopBtn.MouseButton1Click:Connect(function()
			if _MenuController then
				_MenuController.ToggleTab("Shop")
			end
		end)
	end

	-- 2. Nút Inventory
	local InvBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Inventory)
	if InvBtn then
		InvBtn.MouseButton1Click:Connect(function()
			if _MenuController then
				_MenuController.ToggleTab("Inventory")
			end
		end)
	end

	-- 3. Nút Profile
	local ProfBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Profile)
	if ProfBtn then
		ProfBtn.MouseButton1Click:Connect(function()
			if _MenuController then
				_MenuController.ToggleTab("Profile")
			end
		end)
	end

	-- 4. Nút Quest
	local QuestBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Quest)
	if QuestBtn then
		QuestBtn.MouseButton1Click:Connect(function()
			if _MenuController then
				_MenuController.ToggleTab("Quest")
			end
		end)
	end

	-- 5. Nút Spectate
	local SpecBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Spectate)
	if SpecBtn then
		SpecBtn.MouseButton1Click:Connect(function()
			if _SpectateController and _SpectateController.SetVisible then
				_SpectateController.SetVisible(true)
			end
		end)
	end

	-- 6. Nút Setting
	local SettingBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Setting)
	if SettingBtn then
		SettingBtn.MouseButton1Click:Connect(function()
			if _MenuController then
				_MenuController.ToggleTab("Setting")
			end
		end)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local NavigationController = {}

--- Bật/tắt hiển thị toàn bộ ScreenGui NavigationButtons (theo phase và Spectate)
--- @param Visible boolean
function NavigationController.SetVisible(Visible)
	if not NavGui then return end

	local IsSpectating = false
	if _SpectateController and _SpectateController.IsSpectating then
		IsSpectating = _SpectateController.IsSpectating()
	end

	NavGui.Enabled = Visible and not IsSpectating

	if Visible and NavGui.Enabled then
		NavigationController.UpdateMoneyDisplay()

		-- Tầng bảo vệ phụ: Đảm bảo ButtonsContainer hiển thị khi không có tab menu nào active
		local ActiveTab = _MenuController and _MenuController.GetActiveTab and _MenuController.GetActiveTab()
		if not ActiveTab and not IsSpectating then
			NavigationController.SetButtonsContainerVisible(true)
		end
	end
end

--- Ẩn/hiện container chứa các nút bấm (Buttons) khi mở hoặc đóng các menu toàn màn hình
--- @param Visible boolean
function NavigationController.SetButtonsContainerVisible(Visible)
	if ButtonsContainer then
		ButtonsContainer.Visible = Visible
	end
end

--- Cập nhật chuỗi hiển thị số tiền trên MoneyLabel
--- @param Amount number?
function NavigationController.UpdateMoneyDisplay(Amount)
	local Label = ResolveMoneyLabel()
	if not Label then return end

	local TargetAmount = Amount
	if TargetAmount == nil then
		local Data = _PlayerDataController and _PlayerDataController.GetData()
		TargetAmount = (Data and Data.Money) or 0
	end

	Label.Text = GuiHelper.FormatNumber(TargetAmount)
end

--- Khởi tạo NavigationController
function NavigationController:Init()
	NavGui = GuiHelper.GetNavigationGui()
	if not NavGui then
		warn("[NavigationController] Không tìm thấy ScreenGui 'NavigationButtons'.")
		return
	end

	NavGui.ResetOnSpawn = false

	ButtonsContainer = GuiHelper.GetNavButtonsContainer()
	ExtraContainer   = NavGui:FindFirstChild(GuiConfig.NavContainers.Extra, true)
	StatsContainer   = NavGui:FindFirstChild(GuiConfig.NavContainers.Stats, true)

	print("[NavigationController] Initialized.")
end

function NavigationController:Start()
	local Controllers = script.Parent

	local MenuModule = Controllers:FindFirstChild("MenuController")
	if MenuModule then _MenuController = require(MenuModule) end

	local SpectateModule = Controllers:FindFirstChild("SpectateController")
	if SpectateModule then _SpectateController = require(SpectateModule) end

	local PlayerDataModule = Controllers:FindFirstChild("PlayerDataController")
	if PlayerDataModule then _PlayerDataController = require(PlayerDataModule) end

	-- Kết nối sự kiện mở menu cho các nút
	BindNavigationActions()

	-- Cập nhật hiển thị tiền tệ ban đầu
	NavigationController.UpdateMoneyDisplay()

	print("[NavigationController] Started.")
end

return NavigationController
