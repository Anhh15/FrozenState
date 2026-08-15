-- GuiHelper.lua
-- Công cụ hỗ trợ truy xuất và quản lý giao diện (GUI) an toàn cho Client
-- Sử dụng GuiConfig làm Single Source of Truth

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local GuiConfig = require(ReplicatedStorage.Shared.Config.GuiConfig)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local GuiHelper = {}

--- Lấy PlayerGui của LocalPlayer
--- @return PlayerGui
function GuiHelper.GetPlayerGui()
	return PlayerGui
end

--- Lấy ScreenGui từ PlayerGui theo Key trong GuiConfig hoặc tên trực tiếp
--- @param GuiKey string Key trong GuiConfig.ScreenGuis (ví dụ: "NavigationButtons", "Menu")
--- @param Timeout number? Thời gian timeout tùy chọn (mặc định từ GuiConfig.Timeouts)
--- @return ScreenGui?
function GuiHelper.GetScreenGui(GuiKey, Timeout)
	local GuiName = GuiConfig.ScreenGuis[GuiKey] or GuiKey
	local WaitTime = Timeout or GuiConfig.Timeouts.DefaultWaitForGui
	if WaitTime <= 0 then
		return PlayerGui:FindFirstChild(GuiName)
	end
	return PlayerGui:WaitForChild(GuiName, WaitTime)
end

--- Lấy ScreenGui NavigationButtons
--- @param Timeout number?
--- @return ScreenGui?
function GuiHelper.GetNavigationGui(Timeout)
	return GuiHelper.GetScreenGui("NavigationButtons", Timeout)
end

--- Lấy Frame chứa danh sách các nút điều hướng trong NavigationButtons
--- @param Timeout number?
--- @return Frame?
function GuiHelper.GetNavButtonsContainer(Timeout)
	local WaitTime = Timeout or GuiConfig.Timeouts.ShortWait
	local NavGui   = GuiHelper.GetNavigationGui(WaitTime)
	if not NavGui then return nil end

	local ContainerName = GuiConfig.NavContainers.Buttons
	-- Hỗ trợ tìm "Buttons" hoặc fallback "Button" nếu studio chưa đổi kịp
	local Container = NavGui:FindFirstChild(ContainerName) or NavGui:FindFirstChild("Button")
	if not Container and WaitTime and WaitTime > 0 then
		Container = NavGui:WaitForChild(ContainerName, WaitTime) or NavGui:WaitForChild("Button", WaitTime)
	end
	return Container
end

--- Tìm nút điều hướng (NavButton) trong NavigationButtons theo tên đệ quy
--- @param ButtonName string Tên nút (ví dụ: "Profile", "Shop", "Inventory", "Quest", "Spectate", "Setting")
--- @param Timeout number?
--- @return GuiButton?
function GuiHelper.GetNavButton(ButtonName, Timeout)
	local WaitTime = Timeout or GuiConfig.Timeouts.ShortWait
	local NavGui   = GuiHelper.GetNavigationGui(WaitTime)
	if not NavGui then return nil end

	local Button = NavGui:FindFirstChild(ButtonName, true)
	if not Button and WaitTime and WaitTime > 0 then
		local Container = GuiHelper.GetNavButtonsContainer(WaitTime)
		if Container then
			Button = Container:FindFirstChild(ButtonName, true)
		end
	end

	if not Button then
		warn(string.format("[GuiHelper] Không tìm thấy nút điều hướng '%s' trong NavigationButtons.", tostring(ButtonName)))
	end
	return Button
end

--- Lấy TextLabel hiển thị tiền (Cash) trong NavigationButtons/Stats/MoneyStats/MoneyText
--- @param Timeout number?
--- @return TextLabel?
function GuiHelper.GetMoneyLabel(Timeout)
	local WaitTime = Timeout or GuiConfig.Timeouts.ShortWait
	local NavGui   = GuiHelper.GetNavigationGui(WaitTime)
	if not NavGui then
		warn("[GuiHelper] Không tìm thấy NavigationButtons GUI để lấy MoneyLabel.")
		return nil
	end

	local StatsContainerName = GuiConfig.NavContainers.Stats
	local MoneyStatsName     = GuiConfig.Stats.MoneyStats
	local MoneyTextName      = GuiConfig.Stats.MoneyText

	local Stats = NavGui:FindFirstChild(StatsContainerName, true)
		or (WaitTime > 0 and NavGui:WaitForChild(StatsContainerName, WaitTime))

	local MoneyStats = Stats and (
		Stats:FindFirstChild(MoneyStatsName)
		or (WaitTime > 0 and Stats:WaitForChild(MoneyStatsName, WaitTime))
	)

	local MoneyText = MoneyStats and (
		MoneyStats:FindFirstChild(MoneyTextName)
		or (WaitTime > 0 and MoneyStats:WaitForChild(MoneyTextName, WaitTime))
	)

	if not MoneyText then
		warn(string.format("[GuiHelper] Không tìm thấy %s trong NavigationButtons/%s/%s/.", MoneyTextName, StatsContainerName, MoneyStatsName))
	end

	return MoneyText
end

--- Phát âm thanh GUI cục bộ
--- @param SoundId number | string
function GuiHelper.PlayGuiSound(SoundId)
	if not SoundId then return end
	local Sound = Instance.new("Sound")
	Sound.SoundId = "rbxassetid://" .. tostring(SoundId)
	Sound.Volume = 1
	Sound.Parent = PlayerGui
	Sound:Play()
	Debris:AddItem(Sound, 3)
end

--- Gắn hiệu ứng âm thanh (Hover/Click) cho một GuiButton
--- @param Button GuiButton
--- @param ClickSoundId number?
--- @param HoverSoundId number?
function GuiHelper.BindButtonSound(Button, ClickSoundId, HoverSoundId)
	if not Button or not Button:IsA("GuiButton") then return end

	if HoverSoundId then
		Button.MouseEnter:Connect(function()
			GuiHelper.PlayGuiSound(HoverSoundId)
		end)
	end

	if ClickSoundId then
		Button.MouseButton1Click:Connect(function()
			GuiHelper.PlayGuiSound(ClickSoundId)
		end)
	end
end

--- Gắn âm thanh Hover/Click cho tất cả các nút con/cháu trong container Buttons (kể cả trong Extra)
--- Đồng thời tự động lắng nghe các nút con xuất hiện sau qua DescendantAdded
--- @param ClickSoundId number?
--- @param HoverSoundId number?
function GuiHelper.BindAllNavButtonsSound(ClickSoundId, HoverSoundId)
	local Container = GuiHelper.GetNavButtonsContainer(GuiConfig.Timeouts.ShortWait)
	if not Container then return end

	for _, Descendant in ipairs(Container:GetDescendants()) do
		if Descendant:IsA("GuiButton") then
			GuiHelper.BindButtonSound(Descendant, ClickSoundId, HoverSoundId)
		end
	end

	-- Lắng nghe các element xuất hiện sau (do streaming hoặc clone)
	Container.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("GuiButton") then
			GuiHelper.BindButtonSound(Descendant, ClickSoundId, HoverSoundId)
		end
	end)
end

--- Ẩn tất cả các Frame con trong MenuGui ngoại trừ Frame được chỉ định
--- @param MenuGui Instance
--- @param ExceptFrame Frame? Frame cần giữ hiển thị (hoặc nil để ẩn tất cả)
function GuiHelper.HideOtherMenuFrames(MenuGui, ExceptFrame)
	if not MenuGui then return end
	for _, Child in ipairs(MenuGui:GetChildren()) do
		if Child:IsA("Frame") and Child ~= ExceptFrame then
			Child.Visible = false
		end
	end
end

return GuiHelper
