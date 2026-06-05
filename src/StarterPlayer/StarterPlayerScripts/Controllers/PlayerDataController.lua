-- PlayerDataController.lua (ModuleScript)
-- Sync dữ liệu bền vững từ DataStore về client khi mới join
-- Cập nhật money display trong NavigationButton mỗi khi tiền thay đổi

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local _localData  = {}    -- Cache dữ liệu player

-- =========================================================
-- GUI REFERENCES (NavigationButton — Money label)
-- =========================================================

local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Tìm Money label trong NavigationButton GUI
-- Đường dẫn mong đợi: NavigationButton/Money/Text (hoặc tương tự)
local function FindMoneyLabel()
	local NavGui = PlayerGui:WaitForChild("NavigationButton", 5)
	if not NavGui then
		warn("[PlayerDataController] Không tìm thấy NavigationButton GUI.")
		return nil
	end

	-- Tìm element Money theo tên (FindFirstChild recursive = true)
	local MoneyFrame = NavGui:FindFirstChild("Money", true)
	if MoneyFrame then
		local TextLabel = MoneyFrame:FindFirstChildOfClass("TextLabel")
		return TextLabel
	end

	return nil
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
