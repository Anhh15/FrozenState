-- RemoteDefinitions.lua
-- Khai báo tập trung toàn bộ RemoteEvent và RemoteFunction
-- Server tạo, Client lấy reference qua module này
-- Không tạo Remote ở nơi khác

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =========================================================
-- CẤU HÌNH: Danh sách tất cả remotes
-- Thêm remote mới vào đây khi cần ở các phase sau
-- =========================================================

-- RemoteEvent: giao tiếp một chiều (Fire và không chờ trả lời)
local REMOTE_EVENTS = {
	-- Server → Client: Đẩy trạng thái game + thời gian xuống
	"UpdateGameState",

	-- Server → Client: Báo trạng thái của một player (Normal / Frozen / Dead)
	"UpdatePlayerState",

	-- Server → Client: Cập nhật bảng điểm ingame
	"UpdateLeaderboard",

	-- Server → Client: Sync số tiền sau khi có thay đổi
	"UpdateMoney",

	-- Server → Client: Hiện màn hình thắng/thua + thống kê cuối trận
	"ShowGameOver",

	-- Client → Server: Báo tool đã hit một player (Raycast đã xử lý client-side)
	"OnToolHit",

	-- Server → Client: Bật/tắt AlwaysOnTop cho highlight (FrozenState)
	"UpdateFrozenState",

	-- Server → Client: Gửi bảng phân đội khi trận bắt đầu
	"SetTeamAssignment",
}

-- RemoteFunction: giao tiếp hai chiều (Client gọi, Server trả lời)
local REMOTE_FUNCTIONS = {
	-- Client → Server: Trang bị cosmetic (icicle / ice block)
	"EquipItem",

	-- Client → Server: Lấy dữ liệu ban đầu khi client vừa join
	"GetPlayerData",
}

-- =========================================================
-- KHỞI TẠO
-- =========================================================

local RemoteFolder

if RunService:IsServer() then
	-- Server: tạo folder và tất cả remote objects
	RemoteFolder = Instance.new("Folder")
	RemoteFolder.Name = "Remotes"
	RemoteFolder.Parent = ReplicatedStorage

	for _, Name in ipairs(REMOTE_EVENTS) do
		local Remote = Instance.new("RemoteEvent")
		Remote.Name = Name
		Remote.Parent = RemoteFolder
	end

	for _, Name in ipairs(REMOTE_FUNCTIONS) do
		local Remote = Instance.new("RemoteFunction")
		Remote.Name = Name
		Remote.Parent = RemoteFolder
	end

else
	-- Client: chờ folder xuất hiện (server phải chạy trước)
	RemoteFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not RemoteFolder then
		error("[RemoteDefinitions] Không tìm thấy folder Remotes sau 10 giây. Server có đang chạy không?")
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local RemoteDefinitions = {}

--- Lấy RemoteEvent theo tên
--- @param Name string
--- @return RemoteEvent
function RemoteDefinitions.GetEvent(Name)
	local Remote = RemoteFolder:FindFirstChild(Name)
	assert(Remote and Remote:IsA("RemoteEvent"),
		("[RemoteDefinitions] RemoteEvent '%s' không tồn tại."):format(Name))
	return Remote
end

--- Lấy RemoteFunction theo tên
--- @param Name string
--- @return RemoteFunction
function RemoteDefinitions.GetFunction(Name)
	local Remote = RemoteFolder:FindFirstChild(Name)
	assert(Remote and Remote:IsA("RemoteFunction"),
		("[RemoteDefinitions] RemoteFunction '%s' không tồn tại."):format(Name))
	return Remote
end

return RemoteDefinitions
