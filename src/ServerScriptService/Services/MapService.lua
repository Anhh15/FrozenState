-- MapService.lua
-- Quản lý load / unload bản đồ từ ServerStorage vào Workspace
-- Map trong ServerStorage/Maps, mỗi map có folder SpawnPoint với t1_spawn[1-8] và t2_spawn[1-8]

local ServerStorage = game:GetService("ServerStorage")

-- =========================================================
-- HẰNG SỐ
-- =========================================================

local MAPS_FOLDER_NAME     = "Maps"       -- ServerStorage/Maps
local MAP_CONTAINER_NAME   = "CurrentMap" -- Tên instance trong Workspace
local SPAWN_FOLDER_NAME    = "SpawnPoint" -- Tên folder spawn bên trong map
local TEAM1_SPAWN_PREFIX   = "t1_spawn"
local TEAM2_SPAWN_PREFIX   = "t2_spawn"

-- =========================================================
-- STATE
-- =========================================================

local _currentMap = nil   -- Model đang active trong Workspace

-- =========================================================
-- PUBLIC API
-- =========================================================

local MapService = {}

--- Load một map ngẫu nhiên từ ServerStorage/Maps vào Workspace
--- @return Model | nil
function MapService.LoadRandomMap()
	MapService.UnloadMap()

	local MapsFolder = ServerStorage:FindFirstChild(MAPS_FOLDER_NAME)
	if not MapsFolder then
		warn("[MapService] Không tìm thấy ServerStorage/" .. MAPS_FOLDER_NAME)
		return nil
	end

	local MapList = MapsFolder:GetChildren()
	if #MapList == 0 then
		warn("[MapService] Không có map nào trong folder " .. MAPS_FOLDER_NAME)
		return nil
	end

	local ChosenTemplate = MapList[math.random(1, #MapList)]
	local Map            = ChosenTemplate:Clone()
	Map.Name             = MAP_CONTAINER_NAME
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
	local Leftover = workspace:FindFirstChild(MAP_CONTAINER_NAME)
	if Leftover then
		Leftover:Destroy()
	end
end

--- Lấy danh sách spawn point của một team
--- @param TeamName "Team1" | "Team2"
--- @return table -- { BasePart, ... }
function MapService.GetSpawnPoints(TeamName)
	if not _currentMap then
		warn("[MapService] Không có map nào đang active.")
		return {}
	end

	local SpawnFolder = _currentMap:FindFirstChild(SPAWN_FOLDER_NAME)
	if not SpawnFolder then
		warn("[MapService] Map thiếu folder '" .. SPAWN_FOLDER_NAME .. "'.")
		return {}
	end

	local Prefix = (TeamName == "Team1") and TEAM1_SPAWN_PREFIX or TEAM2_SPAWN_PREFIX
	local Result  = {}

	for _, Child in ipairs(SpawnFolder:GetChildren()) do
		if Child:IsA("BasePart") and Child.Name:sub(1, #Prefix) == Prefix then
			table.insert(Result, Child)
		end
	end

	if #Result == 0 then
		warn(("[MapService] Không tìm thấy spawn point nào với prefix '%s'."):format(Prefix))
	end

	return Result
end

--- Lấy map đang active
function MapService.GetCurrentMap()
	return _currentMap
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
