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

-- Lazy-require MenuController để chuyển tiếp sự kiện mở menu
local _MenuController = nil
local function GetMenuController()
	if not _MenuController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("MenuController")
		if Module then
			_MenuController = require(Module)
		end
	end
	return _MenuController
end

-- Lazy-require SpectateController để chuyển tiếp sự kiện Spectate
local _SpectateController = nil
local function GetSpectateController()
	if not _SpectateController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("SpectateController")
		if Module then
			_SpectateController = require(Module)
		end
	end
	return _SpectateController
end

-- Lazy-require PlayerDataController để lấy số tiền hiển thị
local _PlayerDataController = nil
local function GetPlayerDataController()
	if not _PlayerDataController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("PlayerDataController")
		if Module then
			_PlayerDataController = require(Module)
		end
	end
	return _PlayerDataController
end

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

--- Gắn hiệu ứng âm thanh SFX và animation scale cho một item nút điều hướng
--- @param ItemRoot Instance GuiObject đại diện cho toàn bộ nút (bao gồm Background + Icon + Text)
--- Tự động quét và gắn SFX/Animation cho toàn bộ các nút trong NavigationButtons
local function BindAllNavigationEffects()
	if not NavGui then return end
	GuiHelper.AutoBindButtons(NavGui, { MenuName = "Navigation" })
end

--- Kết nối sự kiện click của các nút chức năng điều hướng
local function BindNavigationActions()
	-- 1. Nút Shop
	local ShopBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Shop)
	if ShopBtn then
		ShopBtn.MouseButton1Click:Connect(function()
			local MenuCtrl = GetMenuController()
			if MenuCtrl then
				MenuCtrl.ToggleTab("Shop")
			end
		end)
	end

	-- 2. Nút Inventory
	local InvBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Inventory)
	if InvBtn then
		InvBtn.MouseButton1Click:Connect(function()
			local MenuCtrl = GetMenuController()
			if MenuCtrl then
				MenuCtrl.ToggleTab("Inventory")
			end
		end)
	end

	-- 3. Nút Profile
	local ProfBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Profile)
	if ProfBtn then
		ProfBtn.MouseButton1Click:Connect(function()
			local MenuCtrl = GetMenuController()
			if MenuCtrl then
				MenuCtrl.ToggleTab("Profile")
			end
		end)
	end

	-- 4. Nút Quest
	local QuestBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Quest)
	if QuestBtn then
		QuestBtn.MouseButton1Click:Connect(function()
			local MenuCtrl = GetMenuController()
			if MenuCtrl then
				MenuCtrl.ToggleTab("Quest")
			end
		end)
	end

	-- 5. Nút Spectate
	local SpecBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Spectate)
	if SpecBtn then
		SpecBtn.MouseButton1Click:Connect(function()
			local SpecCtrl = GetSpectateController()
			if SpecCtrl and SpecCtrl.SetVisible then
				SpecCtrl.SetVisible(true)
			end
		end)
	end

	-- 6. Nút Setting
	local SettingBtn = GuiHelper.GetNavButton(GuiConfig.NavButtons.Setting)
	if SettingBtn then
		SettingBtn.MouseButton1Click:Connect(function()
			local MenuCtrl = GetMenuController()
			if MenuCtrl then
				MenuCtrl.ToggleTab("Setting")
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
	local SpecCtrl = GetSpectateController()
	if SpecCtrl and SpecCtrl.IsSpectating then
		IsSpectating = SpecCtrl.IsSpectating()
	end

	NavGui.Enabled = Visible and not IsSpectating

	if Visible and NavGui.Enabled then
		NavigationController.UpdateMoneyDisplay()

		-- Tầng bảo vệ phụ: Đảm bảo ButtonsContainer hiển thị khi không có tab menu nào active
		local MenuCtrl = GetMenuController()
		local ActiveTab = MenuCtrl and MenuCtrl.GetActiveTab and MenuCtrl.GetActiveTab()
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
		local PlayerDataCtrl = GetPlayerDataController()
		local Data = PlayerDataCtrl and PlayerDataCtrl.GetData()
		TargetAmount = (Data and Data.Money) or 0
	end

	Label.Text = tostring(TargetAmount)
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

	-- Gắn hiệu ứng animation và SFX cho tất cả các nút
	BindAllNavigationEffects()

	-- Kết nối sự kiện mở menu cho các nút
	BindNavigationActions()

	-- Cập nhật hiển thị tiền tệ ban đầu
	NavigationController.UpdateMoneyDisplay()

	print("[NavigationController] Đã khởi tạo.")
end

return NavigationController
