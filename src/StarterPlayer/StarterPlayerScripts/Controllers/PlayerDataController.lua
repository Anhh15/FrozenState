-- PlayerDataController.lua (ModuleScript)
-- Sync dữ liệu bền vững từ DataStore về client khi mới join
-- Cập nhật money display trong NavigationButtons mỗi khi tiền thay đổi
-- Cung cấp Signal OnDataLoaded để các Controller khác đăng ký nhận dữ liệu đồng bộ

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local DataConfig        = require(ReplicatedStorage.Shared.Config.DataConfig)
local GuiConfig         = require(ReplicatedStorage.Shared.Config.GuiConfig)
local GuiHelper         = require(ReplicatedStorage.Shared.Tools.GuiHelper)

-- =========================================================
-- STATE
-- =========================================================

local LocalPlayer        = Players.LocalPlayer
local _localData         = {}                       -- Cache dữ liệu player
local _isDataLoaded      = false                    -- Cờ đánh dấu đã load dữ liệu thành công ít nhất 1 lần
local _isRefreshing      = false                    -- Cờ chống duplicate refresh request
local _dataLoadedBindable = Instance.new("BindableEvent") -- Signal bắn khi data load xong/refresh

-- =========================================================
-- Lazy-require NavigationController để cập nhật GUI hiển thị tiền
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

local function UpdateMoneyDisplay(Amount)
	local DisplayAmount = Amount
	if DisplayAmount == nil then
		DisplayAmount = (_localData and _localData.Money) or 0
	end

	local NavCtrl = GetNavigationController()
	if NavCtrl and NavCtrl.UpdateMoneyDisplay then
		NavCtrl.UpdateMoneyDisplay(DisplayAmount)
	end
end

--- Thực hiện lấy dữ liệu từ Server kèm retry có giới hạn
--- @return table | nil
local function FetchDataFromServer()
	local GetPlayerDataFn = RemoteDefinitions.GetFunction("GetPlayerData")
	local MaxRetries      = DataConfig.MaxLoadRetries or 3
	local RetryDelay      = DataConfig.RetryDelay or 1

	for Attempt = 1, MaxRetries do
		local Success, Data = pcall(function()
			return GetPlayerDataFn:InvokeServer()
		end)

		if Success and Data then
			return Data
		end

		if Attempt < MaxRetries then
			task.wait(RetryDelay)
		else
			warn(("[PlayerDataController] FetchDataFromServer: Thử lại %d lần thất bại: %s"):format(
				MaxRetries,
				tostring(Data)
			))
		end
	end
	return nil
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local PlayerDataController = {}

--- Lấy dữ liệu local đã cache (dùng cho các controller khác nếu cần)
--- @return table
function PlayerDataController.GetData()
	return _localData
end

--- Kiểm tra dữ liệu đã được nạp về thành công ít nhất một lần chưa
--- @return boolean
function PlayerDataController.IsLoaded()
	return _isDataLoaded
end

--- Đăng ký callback khi dữ liệu ban đầu hoặc dữ liệu mới được nạp về từ Server
--- Nếu dữ liệu đã có sẵn từ trước, callback sẽ được gọi ngay lập tức trong thread riêng
--- @param Callback function (Data: table)
--- @return RBXScriptConnection
function PlayerDataController.OnDataLoaded(Callback)
	if _isDataLoaded and _localData then
		task.spawn(Callback, _localData)
	end
	return _dataLoadedBindable.Event:Connect(Callback)
end

--- Chờ cho đến khi dữ liệu nạp về thành công (hàm này sẽ yield)
--- @param Timeout number?
--- @return table | nil
function PlayerDataController.WaitForData(Timeout)
	if _isDataLoaded and _localData then
		return _localData
	end

	Timeout = Timeout or DataConfig.ClientLoadTimeout
	local StartTime = os.clock()
	while not _isDataLoaded and (os.clock() - StartTime < Timeout) do
		task.wait(0.05)
	end
	return _localData
end

--- Cập nhật chuỗi hiển thị số tiền trên GUI NavigationButtons
--- @param Amount number? (Nếu nil sẽ lấy từ cache _localData.Money)
function PlayerDataController.UpdateMoneyDisplay(Amount)
	UpdateMoneyDisplay(Amount)
end

--- Đồng bộ lại dữ liệu mới nhất từ Server về Client cache (hàm này sẽ yield)
--- Có cơ chế debounce tự động chờ nếu đang có tiến trình refresh khác đang chạy
--- @return table
function PlayerDataController.RefreshData()
	if _isRefreshing then
		local StartTime = os.clock()
		local Timeout = DataConfig.ClientLoadTimeout or 10
		while _isRefreshing and (os.clock() - StartTime < Timeout) do
			task.wait(0.05)
		end
		return _localData
	end

	_isRefreshing = true
	local Data = FetchDataFromServer()
	_isRefreshing = false

	if Data then
		_localData = Data
		_isDataLoaded = true
		UpdateMoneyDisplay(Data.Money or 0)
		_dataLoadedBindable:Fire(_localData)
	else
		warn("[PlayerDataController] RefreshData: Không nhận được dữ liệu từ Server.")
	end
	return _localData
end

function PlayerDataController:Init()
	-- Phòng thủ: đảm bảo NavigationButtons không bị reset khi respawn
	local NavGui = GuiHelper.GetNavigationGui(GuiConfig.Timeouts.ShortWait)
	if NavGui then
		NavGui.ResetOnSpawn = false
	end

	local UpdateMoneyEvent = RemoteDefinitions.GetEvent("UpdateMoney")

	-- Lấy dữ liệu ban đầu khi join (async để không block Main.client)
	task.spawn(function()
		local Data = FetchDataFromServer()
		if Data then
			_localData = Data
			_isDataLoaded = true
			UpdateMoneyDisplay(Data.Money or 0)
			_dataLoadedBindable:Fire(_localData)
			print(("[PlayerDataController] Data đã load — Money: %d"):format(Data.Money or 0))
		else
			warn("[PlayerDataController] Không thể nạp dữ liệu ban đầu sau nhiều lần thử lại.")
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
