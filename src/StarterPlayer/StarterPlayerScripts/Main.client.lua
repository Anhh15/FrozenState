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
local InventoryController      = require(Controllers:WaitForChild("InventoryController"))
local ProfileController        = require(Controllers:WaitForChild("ProfileController"))
local ShopController           = require(Controllers:WaitForChild("ShopController"))
local SpectateController       = require(Controllers:WaitForChild("SpectateController"))
local QuestController          = require(Controllers:WaitForChild("QuestController"))
local MusicController          = require(Controllers:WaitForChild("MusicController"))
local SoundController          = require(Controllers:WaitForChild("SoundController"))

-- Bước 3: Init tất cả controller
-- (Init theo thứ tự — GameState trước để UI sẵn sàng ngay khi data đến)
-- PlayerDataController phải Init trước InventoryController, ProfileController và ShopController để cache data sẵn sàng
-- MusicController sau SpectateController để lazy-require hoạt động đúng
GameStateController:Init()
GameStatisticController:Init()
HighlightController:Init()
PlayerDataController:Init()
InventoryController:Init()
ProfileController:Init()
ShopController:Init()
SpectateController:Init()
QuestController:Init()
MusicController:Init()
SoundController:Init()

print("[Client] FrozenState đã sẵn sàng.")

