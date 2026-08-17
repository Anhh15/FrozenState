-- PlayerDataController.lua (ModuleScript)
-- Sync dữ liệu bền vững từ DataStore về client khi mới join
-- Cập nhật money display trong NavigationButtons mỗi khi tiền thay đổi

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local _localData  = {}    -- Cache dữ liệu player

-- =========================================================
-- GUI REFERENCES (NavigationButtons — Money label)
-- =========================================================

local PlayerGui = GuiHelper.GetPlayerGui()

-- Tìm Money label trong NavigationButtons GUI
local function FindMoneyLabel()
	return GuiHelper.GetMoneyLabel(GuiConfig.Timeouts.ShortWait)
end

local MoneyLabel = nil

local function UpdateMoneyDisplay(Amount)
	local DisplayAmount = Amount
	if DisplayAmount == nil then
		DisplayAmount = (_localData and _localData.Money) or 0
	end

	-- Kiểm tra tham chiếu: nếu chưa có hoặc không còn nằm trong PlayerGui, tìm lại
	if not MoneyLabel or not MoneyLabel:IsDescendantOf(PlayerGui) then
		MoneyLabel = FindMoneyLabel()
	end

	if MoneyLabel then
		MoneyLabel.Text = tostring(DisplayAmount)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local PlayerDataController = {}

--- Lấy dữ liệu local đã cache (dùng cho các controller khác nếu cần)
function PlayerDataController.GetData()
	return _localData
end

--- Cập nhật chuỗi hiển thị số tiền trên GUI NavigationButtons
--- @param Amount number? (Nếu nil sẽ lấy từ cache _localData.Money)
function PlayerDataController.UpdateMoneyDisplay(Amount)
	UpdateMoneyDisplay(Amount)
end

--- Đồng bộ lại dữ liệu mới nhất từ Server về Client cache (hàm này sẽ yield)
function PlayerDataController.RefreshData()
	local GetPlayerDataFn = RemoteDefinitions.GetFunction("GetPlayerData")
	local Success, Data = pcall(function()
		return GetPlayerDataFn:InvokeServer()
	end)

	if Success and Data then
		_localData = Data
		UpdateMoneyDisplay(Data.Money or 0)
	else
		warn("[PlayerDataController] RefreshData: InvokeServer thất bại: " .. tostring(Data))
	end
	return _localData
end

function PlayerDataController:Init()
	-- Phòng thủ: đảm bảo NavigationButtons không bị reset khi respawn
	local NavGui = GuiHelper.GetNavigationGui(GuiConfig.Timeouts.ShortWait)
	if NavGui then
		NavGui.ResetOnSpawn = false
	end

	local GetPlayerDataFn  = RemoteDefinitions.GetFunction("GetPlayerData")
	local UpdateMoneyEvent = RemoteDefinitions.GetEvent("UpdateMoney")

	-- Lấy dữ liệu ban đầu khi join (async để không block Main.client)
	task.spawn(function()
		local Success, Data = pcall(function()
			return GetPlayerDataFn:InvokeServer()
		end)

		if Success and Data then
			_localData = Data
			UpdateMoneyDisplay(Data.Money or 0)
			print(("[PlayerDataController] Data đã load — Money: %d"):format(Data.Money or 0))
		else
			warn("[PlayerDataController] InvokeServer thất bại: " .. tostring(Data))
		end
	end)

	-- Lắng nghe cập nhật tiền từ server
	UpdateMoneyEvent.OnClientEvent:Connect(function(NewAmount)
		_localData.Money = NewAmount
		UpdateMoneyDisplay(NewAmount)
	end)

	-- Phòng thủ: khi nhân vật respawn, cập nhật lại hiển thị số tiền
	LocalPlayer.CharacterAdded:Connect(function()
		task.defer(function()
			UpdateMoneyDisplay(_localData.Money or 0)
		end)
	end)

	print("[PlayerDataController] Đã khởi tạo.")
end

return PlayerDataController
