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

-- Cache các nút điều hướng
local _navButtons = {}

-- Lazy-require MenuController để chuyển tiếp sự kiện mở menu
local _menuController = nil
local function GetMenuController()
	if not _menuController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("MenuController")
		if Module then
			_menuController = require(Module)
		end
	end
	return _menuController
end

-- Lazy-require SpectateController để chuyển tiếp sự kiện Spectate
local _spectateController = nil
local function GetSpectateController()
	if not _spectateController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("SpectateController")
		if Module then
			_spectateController = require(Module)
		end
	end
	return _spectateController
end

-- Lazy-require PlayerDataController để lấy số tiền hiển thị
local _playerDataController = nil
local function GetPlayerDataController()
	if not _playerDataController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("PlayerDataController")
		if Module then
			_playerDataController = require(Module)
		end
	end
	return _playerDataController
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
--- @param BoundRoots table Cache tránh bind trùng
local function BindNavItemEffects(ItemRoot, BoundRoots)
	if not ItemRoot or not ItemRoot:IsA("GuiObject") or BoundRoots[ItemRoot] then return end
	if ItemRoot.Name == "Buttons" or ItemRoot.Name == "Extra" or ItemRoot.Name == "Stats" then return end

	BoundRoots[ItemRoot] = true

	-- Bind Scale Animation
	if ItemRoot:IsA("GuiButton") then
		GuiHelper.BindButtonScale(ItemRoot, ItemRoot)
	end

	-- Bind SFX và Scale cho tất cả GuiButton con/cháu
	for _, Descendant in ipairs(ItemRoot:GetDescendants()) do
		if Descendant:IsA("GuiButton") then
			GuiHelper.BindButtonScale(Descendant, ItemRoot)
			Descendant.MouseButton1Click:Connect(function()
				AudioHelper.PlayGuiSound(AudioConfig.Gui.ButtonClick)
			end)
			Descendant.MouseEnter:Connect(function()
				AudioHelper.PlayGuiSound(AudioConfig.Gui.MouseEnter)
			end)
		end
	end

	if ItemRoot:IsA("GuiButton") then
		ItemRoot.MouseButton1Click:Connect(function()
			AudioHelper.PlayGuiSound(AudioConfig.Gui.ButtonClick)
		end)
		ItemRoot.MouseEnter:Connect(function()
			AudioHelper.PlayGuiSound(AudioConfig.Gui.MouseEnter)
		end)
	end
end

--- Tự động quét và gắn SFX/Animation cho toàn bộ các nút trong NavigationButtons
local function BindAllNavigationEffects()
	if not NavGui then return end
	local BoundRoots = {}

	if ButtonsContainer then
		for _, Child in ipairs(ButtonsContainer:GetChildren()) do
			if Child:IsA("GuiObject") and not Child:IsA("UIListLayout") and not Child:IsA("UIGridLayout") and not Child:IsA("UIPadding") then
				BindNavItemEffects(Child, BoundRoots)
			end
		end

		ButtonsContainer.ChildAdded:Connect(function(Child)
			if Child:IsA("GuiObject") and not Child:IsA("UIListLayout") and not Child:IsA("UIGridLayout") and not Child:IsA("UIPadding") then
				BindNavItemEffects(Child, BoundRoots)
			end
		end)
	end

	if ExtraContainer then
		for _, Child in ipairs(ExtraContainer:GetChildren()) do
			if Child:IsA("GuiObject") and not Child:IsA("UIListLayout") and not Child:IsA("UIGridLayout") and not Child:IsA("UIPadding") then
				BindNavItemEffects(Child, BoundRoots)
			end
		end

		ExtraContainer.ChildAdded:Connect(function(Child)
			if Child:IsA("GuiObject") and not Child:IsA("UIListLayout") and not Child:IsA("UIGridLayout") and not Child:IsA("UIPadding") then
				BindNavItemEffects(Child, BoundRoots)
			end
		end)
	end
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
