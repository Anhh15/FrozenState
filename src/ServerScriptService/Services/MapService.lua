-- MapService.lua
-- Quản lý load / unload bản đồ từ ServerStorage vào Workspace
-- SpawnType "TeamBased": map/SpawnPoint/TeamBase/T1SpawnPoint[1-8], T2SpawnPoint[1-8]
-- SpawnType "FFA":       map/SpawnPoint/FFA/SpawnPoint[1-16]

local ServerStorage = game:GetService("ServerStorage")

-- =========================================================
-- HẰNG SỐ
-- =========================================================

local MAPS_FOLDER_NAME    = "Maps"        -- ServerStorage/Maps
local MAP_CONTAINER_NAME  = "CurrentMap"  -- Tên instance trong Workspace
local SPAWN_FOLDER_NAME   = "SpawnPoint"  -- Folder spawn bên trong map

-- TeamBased spawn
local SPAWN_FOLDER_TEAM   = "TeamBase"
local TEAM1_SPAWN_PREFIX  = "T1SpawnPoint"
local TEAM2_SPAWN_PREFIX  = "T2SpawnPoint"

-- FFA spawn
local SPAWN_FOLDER_FFA    = "FFA"
local FFA_SPAWN_PREFIX    = "SpawnPoint"

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

--- Lấy danh sách spawn point theo SpawnType và TeamName
--- @param TeamName "Team1" | "Team2" | nil  -- chỉ dùng khi SpawnType = "TeamBased"
--- @param SpawnType "TeamBased" | "FFA"
--- @return table -- { BasePart, ... }
function MapService.GetSpawnPoints(TeamName, SpawnType)
	if not _currentMap then
		warn("[MapService] Không có map nào đang active.")
		return {}
	end

	local SpawnRoot = _currentMap:FindFirstChild(SPAWN_FOLDER_NAME)
	if not SpawnRoot then
		warn("[MapService] Map thiếu folder '" .. SPAWN_FOLDER_NAME .. "'.")
		return {}
	end

	if SpawnType == "FFA" then
		-- FFA: tất cả spawn point trong /SpawnPoint/FFA/
		local FFAFolder = SpawnRoot:FindFirstChild(SPAWN_FOLDER_FFA)
		if not FFAFolder then
			warn("[MapService] Map thiếu folder SpawnPoint/" .. SPAWN_FOLDER_FFA)
			return {}
		end

		local Result = {}
		for _, Child in ipairs(FFAFolder:GetChildren()) do
			if Child:IsA("BasePart") and Child.Name:sub(1, #FFA_SPAWN_PREFIX) == FFA_SPAWN_PREFIX then
				table.insert(Result, Child)
			end
		end

		if #Result == 0 then
			warn("[MapService] Không tìm thấy FFA spawn point nào.")
		end
		return Result

	else
		-- TeamBased: spawn point của từng team trong /SpawnPoint/TeamBase/
		local TeamFolder = SpawnRoot:FindFirstChild(SPAWN_FOLDER_TEAM)
		if not TeamFolder then
			warn("[MapService] Map thiếu folder SpawnPoint/" .. SPAWN_FOLDER_TEAM)
			return {}
		end

		local Prefix = (TeamName == "Team1") and TEAM1_SPAWN_PREFIX or TEAM2_SPAWN_PREFIX
		local Result = {}

		for _, Child in ipairs(TeamFolder:GetChildren()) do
			if Child:IsA("BasePart") and Child.Name:sub(1, #Prefix) == Prefix then
				table.insert(Result, Child)
			end
		end

		if #Result == 0 then
			warn(("[MapService] Không tìm thấy spawn point nào với prefix '%s'."):format(Prefix))
		end
		return Result
	end
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
