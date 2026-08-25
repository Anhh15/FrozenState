-- MapHelper.lua
-- Module tiện ích dùng chung (Shared) cho Client & Server để truy xuất và xử lý bản đồ và điểm Spawn
-- Sử dụng MapConfig làm Single Source of Truth

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapConfig         = require(ReplicatedStorage.Shared.Config.MapConfig)

local MapHelper = {}

-- =========================================================
-- MAP INSTANCE QUERIES
-- =========================================================

--- Lấy Model map hiện tại đang active trong Workspace
--- @return Model?
function MapHelper.GetCurrentMap()
	return workspace:FindFirstChild(MapConfig.Folders.MapContainer)
end

-- =========================================================
-- SPAWN POINT UTILITIES
-- =========================================================

--- Lấy danh sách điểm Spawn từ Model map theo SpawnType và TeamName
--- @param MapModel Model?
--- @param TeamName "Team1" | "Team2" | nil  -- chỉ dùng khi SpawnType = "TeamBased"
--- @param SpawnType "TeamBased" | "FFA"
--- @return table -- { BasePart, ... }
function MapHelper.GetSpawnPoints(MapModel, TeamName, SpawnType)
	local ActiveMap = MapModel or MapHelper.GetCurrentMap()
	if not ActiveMap then
		warn("[MapHelper] Không tìm thấy bản đồ đang active.")
		return {}
	end

	local SpawnRoot = ActiveMap:FindFirstChild(MapConfig.Folders.SpawnRoot)
	if not SpawnRoot then
		warn(("[MapHelper] Map thiếu folder gốc '%s'"):format(MapConfig.Folders.SpawnRoot))
		return {}
	end

	local Result = {}

	if SpawnType == "FFA" then
		local FFAFolder = SpawnRoot:FindFirstChild(MapConfig.Folders.FFA)
		if not FFAFolder then
			warn(("[MapHelper] Map thiếu folder '%s/%s'"):format(MapConfig.Folders.SpawnRoot, MapConfig.Folders.FFA))
			return {}
		end

		local Prefix = MapConfig.Prefixes.FFA
		for _, Child in ipairs(FFAFolder:GetChildren()) do
			if Child:IsA("BasePart") and Child.Name:sub(1, #Prefix) == Prefix then
				table.insert(Result, Child)
			end
		end

		if #Result == 0 then
			warn("[MapHelper] Không tìm thấy FFA spawn point nào.")
		end
	else
		local TeamFolder = SpawnRoot:FindFirstChild(MapConfig.Folders.TeamBase)
		if not TeamFolder then
			warn(("[MapHelper] Map thiếu folder '%s/%s'"):format(MapConfig.Folders.SpawnRoot, MapConfig.Folders.TeamBase))
			return {}
		end

		local Prefix = (TeamName == "Team1") and MapConfig.Prefixes.Team1 or MapConfig.Prefixes.Team2
		for _, Child in ipairs(TeamFolder:GetChildren()) do
			if Child:IsA("BasePart") and Child.Name:sub(1, #Prefix) == Prefix then
				table.insert(Result, Child)
			end
		end

		if #Result == 0 then
			warn(("[MapHelper] Không tìm thấy spawn point nào với prefix '%s'"):format(Prefix))
		end
	end

	return Result
end

--- Lấy ngẫu nhiên một điểm spawn từ danh sách
--- @param SpawnPointList table -- { BasePart, ... }
--- @return BasePart?
function MapHelper.GetRandomSpawnPoint(SpawnPointList)
	if not SpawnPointList or #SpawnPointList == 0 then
		return nil
	end
	return SpawnPointList[math.random(1, #SpawnPointList)]
end

--- Tính toán CFrame an toàn phía trên SpawnPart
--- @param SpawnPart BasePart
--- @param YOffset number? -- Chiều cao cộng thêm (mặc định lấy từ MapConfig.Spawn.DefaultYOffset)
--- @return CFrame
function MapHelper.GetSpawnCFrame(SpawnPart, YOffset)
	local DefaultOffset = (MapConfig.Spawn and MapConfig.Spawn.DefaultYOffset) or 4
	local Offset = YOffset or DefaultOffset
	return SpawnPart.CFrame + Vector3.new(0, Offset, 0)
end

--- Gán điểm spawn độc nhất (không trùng lặp) cho danh sách người chơi sử dụng Fisher-Yates Shuffle
--- @param PlayerList table -- { Player, ... }
--- @param SpawnPointList table -- { BasePart, ... }
--- @return table -- { [Player] = BasePart }
function MapHelper.AssignSpawnPoints(PlayerList, SpawnPointList)
	local Assignments = {}
	if not PlayerList or #PlayerList == 0 then
		return Assignments
	end
	if not SpawnPointList or #SpawnPointList == 0 then
		warn("[MapHelper] Danh sách SpawnPointList rỗng, không thể phân bổ điểm spawn.")
		return Assignments
	end

	-- Xáo trộn mảng SpawnPointList (Fisher-Yates Shuffle)
	local ShuffledSpawns = table.clone(SpawnPointList)
	for i = #ShuffledSpawns, 2, -1 do
		local j = math.random(1, i)
		ShuffledSpawns[i], ShuffledSpawns[j] = ShuffledSpawns[j], ShuffledSpawns[i]
	end

	-- Gán 1-1 cho từng người chơi. Tự động wrap-around nếu số người chơi vượt quá số spawn
	for Index, Player in ipairs(PlayerList) do
		local SpawnIndex = ((Index - 1) % #ShuffledSpawns) + 1
		Assignments[Player] = ShuffledSpawns[SpawnIndex]
	end

	return Assignments
end

return MapHelper
