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
local ModeAnnouncementController     = require(Controllers:WaitForChild("ModeAnnouncementController"))
local RoundLoadingScreenController   = require(Controllers:WaitForChild("RoundLoadingScreenController"))
local GameOverAnnouncementController = require(Controllers:WaitForChild("GameOverAnnouncementController"))
local GameLoadingController          = require(Controllers:WaitForChild("GameLoadingController"))
local HotbarController               = require(Controllers:WaitForChild("HotbarController"))
local FrozenStateAnnouncementController = require(Controllers:WaitForChild("FrozenStateAnnouncementController"))
local SettingController              = require(Controllers:WaitForChild("SettingController"))

-- Bước 3: Init tất cả controller có bảo vệ pcall (Fault Isolation)
local CONTROLLERS_ORDER = {
	{ Name = "GameLoadingController", Controller = GameLoadingController },
	{ Name = "MenuController", Controller = MenuController },
	{ Name = "NavigationController", Controller = NavigationController },
	{ Name = "PlayerDataController", Controller = PlayerDataController },
	{ Name = "GameStateController", Controller = GameStateController },
	{ Name = "GameStatisticController", Controller = GameStatisticController },
	{ Name = "HighlightController", Controller = HighlightController },
	{ Name = "InventoryController", Controller = InventoryController },
	{ Name = "ProfileController", Controller = ProfileController },
	{ Name = "ShopController", Controller = ShopController },
	{ Name = "ItemRewardController", Controller = ItemRewardController },
	{ Name = "SpectateController", Controller = SpectateController },
	{ Name = "QuestController", Controller = QuestController },
	{ Name = "MusicController", Controller = MusicController },
	{ Name = "SoundController", Controller = SoundController },
	{ Name = "PlayerStatusController", Controller = PlayerStatusController },
	{ Name = "ScoreBoardController", Controller = ScoreBoardController },
	{ Name = "AccoladesController", Controller = AccoladesController },
	{ Name = "ModeAnnouncementController", Controller = ModeAnnouncementController },
	{ Name = "RoundLoadingScreenController", Controller = RoundLoadingScreenController },
	{ Name = "GameOverAnnouncementController", Controller = GameOverAnnouncementController },
	{ Name = "HotbarController", Controller = HotbarController },
	{ Name = "FrozenStateAnnouncementController", Controller = FrozenStateAnnouncementController },
	{ Name = "SettingController", Controller = SettingController },
}

-- Pha 1: Init tất cả controller có bảo vệ pcall (Fault Isolation - thiết lập GUI, cấu hình nội bộ)
for _, Entry in ipairs(CONTROLLERS_ORDER) do
	if Entry.Controller and type(Entry.Controller.Init) == "function" then
		local Success, ErrorMessage = pcall(function()
			Entry.Controller:Init()
		end)
		if not Success then
			warn(string.format("[Client] Init %s thất bại: %s", Entry.Name, tostring(ErrorMessage)))
		end
	end
end

-- Pha 2: Start tất cả controller có bảo vệ pcall (kết nối lắng nghe, tương tác liên Controller)
for _, Entry in ipairs(CONTROLLERS_ORDER) do
	if Entry.Controller and type(Entry.Controller.Start) == "function" then
		local Success, ErrorMessage = pcall(function()
			Entry.Controller:Start()
		end)
		if not Success then
			warn(string.format("[Client] Start %s thất bại: %s", Entry.Name, tostring(ErrorMessage)))
		end
	end
end

print("[Client] FrozenState đã sẵn sàng.")
