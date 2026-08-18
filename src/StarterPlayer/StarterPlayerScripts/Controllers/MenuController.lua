-- MenuController.lua (ModuleScript)
-- Điều phối và quản lý toàn bộ các cửa sổ trong ScreenGui "Menu" (Shop, Inventory, Profile, Quest)
-- Hiện thực cơ chế độc quyền hiển thị (Mutual Exclusion) và giao tiếp với NavigationController

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuiConfig = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper = require(ReplicatedStorage.Shared.Tools.GuiHelper)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- =========================================================
-- STATE & REFS
-- =========================================================

local MenuGui    = nil
local _activeTab = nil  -- Tên tab đang mở (vd: "Shop", "Inventory", "Profile", "Quest") hoặc nil

-- Danh sách các tab đã đăng ký: { [TabName: string] = { Open = fn, Close = fn, Frame = GuiObject? } }
local _registeredTabs = {}

-- Lazy-require NavigationController để tránh circular dependency
local _navigationController = nil
local function GetNavigationController()
	if not _navigationController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("NavigationController")
		if Module then
			_navigationController = require(Module)
		end
	end
	return _navigationController
end

-- Lazy-require ItemRewardController để reset khi CloseAll
local _itemRewardController = nil
local function GetItemRewardController()
	if not _itemRewardController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("ItemRewardController")
		if Module then
			_itemRewardController = require(Module)
		end
	end
	return _itemRewardController
end

-- Lazy-require SpectateController để kiểm tra trạng thái Spectate
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

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Ẩn tất cả các Frame trực thuộc ScreenGui Menu (ngoại trừ Frame được chỉ định nếu có)
--- @param ExcludedFrame GuiObject?
local function HideAllFrames(ExcludedFrame)
	if not MenuGui then return end
	for _, Child in ipairs(MenuGui:GetChildren()) do
		if Child:IsA("GuiObject") and Child ~= ExcludedFrame then
			GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(Child))
			Child.Visible = false
		end
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local MenuController = {}

--- Đăng ký một tab menu vào hệ thống điều phối
--- @param TabName string Tên tab (vd: "Shop", "Inventory", "Profile", "Quest")
--- @param TabData table { Open: () -> (), Close: () -> (), Frame: GuiObject? }
function MenuController.RegisterTab(TabName, TabData)
	if not TabName or not TabData then return end
	_registeredTabs[TabName] = TabData
end

--- Mở một tab cụ thể và tự động đóng tab đang mở trước đó
--- @param TabName string Tên tab cần mở
function MenuController.OpenTab(TabName)
	if not TabName then return end

	-- Nếu đang mở Spectate thì tắt Spectate để nhường chỗ cho Menu tab
	local SpecCtrl = GetSpectateController()
	if SpecCtrl and SpecCtrl.IsSpectating and SpecCtrl.IsSpectating() then
		SpecCtrl.SetVisible(false)
	end

	-- Nếu tab yêu cầu đã đang mở thì không làm gì
	if _activeTab == TabName then return end

	-- Đóng tab hiện tại nếu có (Phương án A: Fast Switch - ẩn tức thì tab cũ để nhường chỗ)
	if _activeTab then
		local OldTabData = _registeredTabs[_activeTab]
		if OldTabData then
			if OldTabData.Close then
				OldTabData.Close()
			end
			if OldTabData.Frame then
				GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(OldTabData.Frame))
				OldTabData.Frame.Visible = false
			end
		end
		_activeTab = nil
	end

	-- Ẩn an toàn tất cả các Frame con khác trong Menu
	HideAllFrames()

	-- Ẩn thanh nút điều hướng (NavigationButtons/Buttons) để nhường chỗ cho Menu
	local NavCtrl = GetNavigationController()
	if NavCtrl and NavCtrl.SetButtonsContainerVisible then
		NavCtrl.SetButtonsContainerVisible(false)
	end

	-- Mở tab mới kèm hiệu ứng PopOpen
	local TargetData = _registeredTabs[TabName]
	if TargetData then
		_activeTab = TabName
		if TargetData.Open then
			TargetData.Open()
		end
		if TargetData.Frame then
			GuiHelper.PopOpen(TargetData.Frame)
		end
	else
		warn(string.format("[MenuController] Tab '%s' chưa được đăng ký trong hệ thống.", tostring(TabName)))
	end
end

--- Đóng tab đang mở hoặc đóng một tab cụ thể
--- @param TabName string? Tùy chọn đóng đúng tab được chỉ định
function MenuController.CloseTab(TabName)
	local TargetTab = TabName or _activeTab
	if not TargetTab then return end

	local TargetData = _registeredTabs[TargetTab]
	if _activeTab == TargetTab then
		_activeTab = nil
	end

	if TargetData then
		if TargetData.Close then
			TargetData.Close()
		end

		if TargetData.Frame then
			GuiHelper.PopClose(TargetData.Frame, nil, function()
				-- Khi animation đóng hoàn tất, nếu không còn tab nào mở, khôi phục lại thanh nút điều hướng
				if not _activeTab then
					local NavCtrl = GetNavigationController()
					if NavCtrl and NavCtrl.SetButtonsContainerVisible then
						local SpecCtrl = GetSpectateController()
						local IsSpectating = SpecCtrl and SpecCtrl.IsSpectating and SpecCtrl.IsSpectating()
						NavCtrl.SetButtonsContainerVisible(not IsSpectating)
					end
				end
			end)
		else
			if not _activeTab then
				local NavCtrl = GetNavigationController()
				if NavCtrl and NavCtrl.SetButtonsContainerVisible then
					local SpecCtrl = GetSpectateController()
					local IsSpectating = SpecCtrl and SpecCtrl.IsSpectating and SpecCtrl.IsSpectating()
					NavCtrl.SetButtonsContainerVisible(not IsSpectating)
				end
			end
		end
	end
end

--- Đóng tab hiện tại đang mở
function MenuController.CloseCurrentTab()
	MenuController.CloseTab(_activeTab)
end

--- Toggle (bật/tắt) một tab: Nếu đang mở thì đóng, nếu đang đóng thì mở
--- @param TabName string
function MenuController.ToggleTab(TabName)
	if _activeTab == TabName then
		MenuController.CloseCurrentTab()
	else
		MenuController.OpenTab(TabName)
	end
end

--- Đóng toàn bộ các tab và dọn dẹp hiệu ứng mở rương (dùng khi vào trận)
--- @param ExcludedFrame GuiObject?
function MenuController.CloseAll(ExcludedFrame)
	if _activeTab and _registeredTabs[_activeTab] and _registeredTabs[_activeTab].Close then
		_registeredTabs[_activeTab].Close()
	end

	for _, TabData in pairs(_registeredTabs) do
		if TabData.Frame and TabData.Frame ~= ExcludedFrame then
			GuiHelper.CancelTween(GuiHelper.GetOrCreateScale(TabData.Frame))
			TabData.Frame.Visible = false
		end
	end

	_activeTab = nil
	HideAllFrames(ExcludedFrame)

	-- Reset hiệu ứng mở rương nếu đang chạy
	local RewardCtrl = GetItemRewardController()
	if RewardCtrl and RewardCtrl.Reset then
		RewardCtrl.Reset()
	end

	-- Khôi phục hiển thị cho ButtonsContainer của NavigationButtons nếu không đang Spectate
	local NavCtrl = GetNavigationController()
	if NavCtrl and NavCtrl.SetButtonsContainerVisible then
		local SpecCtrl = GetSpectateController()
		local IsSpectating = SpecCtrl and SpecCtrl.IsSpectating and SpecCtrl.IsSpectating()
		NavCtrl.SetButtonsContainerVisible(not IsSpectating)
	end
end

--- Bật/tắt hiển thị của ScreenGui Menu
--- @param Visible boolean
function MenuController.SetVisible(Visible)
	if MenuGui then
		MenuGui.Enabled = Visible
	end
	if not Visible then
		MenuController.CloseAll()
	end
end

--- Lấy tên tab đang mở hiện tại
--- @return string?
function MenuController.GetActiveTab()
	return _activeTab
end

--- Khởi tạo MenuController
function MenuController:Init()
	MenuGui = GuiHelper.GetScreenGui("Menu")
	if MenuGui then
		MenuGui.ResetOnSpawn = false
		MenuGui.Enabled = true
		HideAllFrames()
	else
		warn("[MenuController] Không tìm thấy ScreenGui 'Menu'.")
	end

	print("[MenuController] Đã khởi tạo.")
end

return MenuController
