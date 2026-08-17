-- Main.client.lua
-- Entry point phía Client
-- Khởi tạo RemoteDefinitions (chờ server tạo xong) rồi start tất cả controller

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Client] Đang kết nối FrozenState...")

-- Bước 1: Lấy reference đến tất cả Remotes (chờ server tạo xong)
require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- Bước 2: Load tất cả controller theo thứ tự
local Controllers = script.Parent:WaitForChild("Controllers")

local MenuController          = require(Controllers:WaitForChild("MenuController"))
local NavigationController    = require(Controllers:WaitForChild("NavigationController"))
local GameStateController      = require(Controllers:WaitForChild("GameStateController"))
local GameStatisticController  = require(Controllers:WaitForChild("GameStatisticController"))
local HighlightController      = require(Controllers:WaitForChild("HighlightController"))
local PlayerDataController     = require(Controllers:WaitForChild("PlayerDataController"))
local InventoryController      = require(Controllers:WaitForChild("InventoryController"))
local ProfileController        = require(Controllers:WaitForChild("ProfileController"))
local ShopController           = require(Controllers:WaitForChild("ShopController"))
local ItemRewardController     = require(Controllers:WaitForChild("ItemRewardController"))
local SpectateController       = require(Controllers:WaitForChild("SpectateController"))
local QuestController          = require(Controllers:WaitForChild("QuestController"))
local MusicController          = require(Controllers:WaitForChild("MusicController"))
local SoundController          = require(Controllers:WaitForChild("SoundController"))
local PlayerStatusController   = require(Controllers:WaitForChild("PlayerStatusController"))
local ScoreBoardController     = require(Controllers:WaitForChild("ScoreBoardController"))
local AccoladesController      = require(Controllers:WaitForChild("AccoladesController"))
local RoundLoadingScreenController  = require(Controllers:WaitForChild("RoundLoadingScreenController"))

-- Bước 3: Init tất cả controller
-- MenuController & NavigationController khởi tạo trước để sẵn sàng đăng ký tab và bind sự kiện
MenuController:Init()
NavigationController:Init()
PlayerDataController:Init()
GameStateController:Init()
GameStatisticController:Init()
HighlightController:Init()
InventoryController:Init()
ProfileController:Init()
ShopController:Init()
ItemRewardController:Init()
SpectateController:Init()
QuestController:Init()
MusicController:Init()
SoundController:Init()
PlayerStatusController:Init()
ScoreBoardController:Init()
AccoladesController:Init()
RoundLoadingScreenController:Init()

print("[Client] FrozenState đã sẵn sàng.")
