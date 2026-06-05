-- Main.client.lua
-- Entry point phía Client
-- Khởi tạo RemoteDefinitions (chờ server tạo xong) rồi start tất cả controller

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Client] Đang kết nối FrozenState...")

-- Bước 1: Lấy reference đến tất cả Remotes (chờ server tạo xong)
require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- Bước 2: Load tất cả controller theo thứ tự
local Controllers = script.Parent:WaitForChild("Controllers")

local GameStateController      = require(Controllers:WaitForChild("GameStateController"))
local GameStatisticController  = require(Controllers:WaitForChild("GameStatisticController"))
local HighlightController      = require(Controllers:WaitForChild("HighlightController"))
local PlayerDataController     = require(Controllers:WaitForChild("PlayerDataController"))

-- Bước 3: Init tất cả controller
-- (Init theo thứ tự — GameState trước để UI sẵn sàng ngay khi data đến)
GameStateController:Init()
GameStatisticController:Init()
HighlightController:Init()
PlayerDataController:Init()

print("[Client] FrozenState đã sẵn sàng.")
