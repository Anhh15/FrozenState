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
	return GuiHelper.GetMoneyLabel()
end

local MoneyLabel = nil  -- lazy-init khi cần

local function UpdateMoneyDisplay(Amount)
	if not MoneyLabel then
		MoneyLabel = FindMoneyLabel()
	end
	if MoneyLabel then
		MoneyLabel.Text = tostring(Amount)
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

	print("[PlayerDataController] Đã khởi tạo.")
end

return PlayerDataController
