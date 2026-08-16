-- MapService.lua
-- Quản lý load / unload bản đồ từ ServerStorage vào Workspace
-- Sử dụng MapConfig và MapHelper để đảm bảo không hardcode cấu trúc folder

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapConfig         = require(ReplicatedStorage.Shared.Config.MapConfig)
local MapHelper         = require(ReplicatedStorage.Shared.Tools.MapHelper)

-- =========================================================
-- STATE
-- =========================================================

local _currentMap = nil   -- Model đang active trong Workspace

-- =========================================================
-- PUBLIC API
-- =========================================================

local MapService = {}

--- Load một map ngẫu nhiên từ ServerStorage vào Workspace
--- @return Model | nil
function MapService.LoadRandomMap()
	MapService.UnloadMap()

	local MapsFolder = ServerStorage:FindFirstChild(MapConfig.Folders.MapsFolder)
	if not MapsFolder then
		warn(("[MapService] Không tìm thấy ServerStorage/%s"):format(MapConfig.Folders.MapsFolder))
		return nil
	end

	local MapList = MapsFolder:GetChildren()
	if #MapList == 0 then
		warn(("[MapService] Không có map nào trong folder %s"):format(MapConfig.Folders.MapsFolder))
		return nil
	end

	local ChosenTemplate = MapList[math.random(1, #MapList)]
	local Map            = ChosenTemplate:Clone()
	Map.Name             = MapConfig.Folders.MapContainer
	Map.Parent           = workspace

	_currentMap = Map
	print(("[MapService] Đã load map: %s"):format(ChosenTemplate.Name))
	return Map
end

--- Xóa map đang active khỏi Workspace
function MapService.UnloadMap()
	if _currentMap and _currentMap.Parent then
		_currentMap:Destroy()
		_currentMap = nil
		print("[MapService] Đã unload map cũ.")
	end

	-- Fallback: dọn nếu còn sót do crash
	local Leftover = workspace:FindFirstChild(MapConfig.Folders.MapContainer)
	if Leftover then
		Leftover:Destroy()
	end
end

--- Lấy danh sách spawn point theo SpawnType và TeamName
--- @param TeamName "Team1" | "Team2" | nil  -- chỉ dùng khi SpawnType = "TeamBased"
--- @param SpawnType "TeamBased" | "FFA"
--- @return table -- { BasePart, ... }
function MapService.GetSpawnPoints(TeamName, SpawnType)
	return MapHelper.GetSpawnPoints(_currentMap, TeamName, SpawnType)
end

--- Lấy map đang active
--- @return Model?
function MapService.GetCurrentMap()
	return _currentMap or MapHelper.GetCurrentMap()
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function MapService:Init()
	print("[MapService] Đã khởi tạo.")
end

function MapService:Start()
	print("[MapService] Đang chạy.")
end

return MapService
