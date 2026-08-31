-- ProfileController.lua (ModuleScript)
-- Điều khiển GUI Profile: hiển thị thông tin cá nhân, skin đang trang bị và thống kê người chơi
-- Chỉ hiển thị trong Lobby phase (GameStateController sẽ ẩn khi vào trận)

-- Cấu trúc GUI mong đợi (StarterGui/Menu/Profile):
--   Profile (Frame)
--     Background    (ImageLabel) — bỏ qua
--     MenuLabel     (TextLabel)  — bỏ qua
--     CloseButton   (TextButton / ImageButton)
--     PlayerInfo    (Frame)
--       AvatarThumbnail (ImageLabel)     — avatar 2D (HeadShot)
--       PlayerNameText  (TextLabel)      — tên + id
--     ItemList      (Frame)
--       UIGridLayout
--       [ItemTemplate × 2 sẽ được clone vào đây]
--     PlayerStats   (Frame)
--       Stats (Frame)
--         Freezes        (Frame) → NameText, ValueText
--         Thaws          (Frame) → NameText, ValueText
--         FreezingSpree  (Frame) → NameText, ValueText
--         ThawingSpree   (Frame) → NameText, ValueText
--         FirstBlood     (Frame) → NameText, ValueText
--         LastStanding   (Frame) → NameText, ValueText
--       GameWins (Frame) → NameText, ValueText

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions     = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local PlayerDataController  = require(script.Parent.PlayerDataController)
local ItemRegistry          = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig          = require(ReplicatedStorage.Shared.Config.RarityConfig)
local AudioConfig           = require(ReplicatedStorage.Shared.Config.AudioConfig)
local GameConfig            = require(ReplicatedStorage.Shared.Config.GameConfig)
local GuiConfig             = require(ReplicatedStorage.Shared.Config.GuiConfig)
local ViewportManager       = require(ReplicatedStorage.Shared.Tools.ViewportManager)
local GuiHelper             = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local ItemCard              = require(ReplicatedStorage.Shared.Tools.ItemCard)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MenuGui = GuiHelper.GetScreenGui("Menu")

-- Profile frame nằm trong Menu
local Profile      = MenuGui and MenuGui:FindFirstChild("Profile", true)

-- Các phần tử bên trong Profile
local CloseButton          = Profile and Profile:FindFirstChild("CloseButton", true)
local PlayerInfo           = Profile and Profile:FindFirstChild("PlayerInfo", true)
local AvatarThumbnailFrame = PlayerInfo and (PlayerInfo:FindFirstChild("AvatarThumbnail") or PlayerInfo:FindFirstChild("PlayerViewport"))
local PlayerNameText      = PlayerInfo and PlayerInfo:FindFirstChild("PlayerNameText")

local ItemList     = Profile and Profile:FindFirstChild("ItemList", true)

local PlayerStatsFrame = Profile and Profile:FindFirstChild("PlayerStats", true)
local StatsFrame       = PlayerStatsFrame and PlayerStatsFrame:FindFirstChild("Stats")
local GameWinsFrame    = PlayerStatsFrame and PlayerStatsFrame:FindFirstChild("GameWins")

-- Tham chiếu nhanh các ValueText trong Stats

--- Phát âm thanh GUI qua GuiHelper
local function PlayGuiSound(SoundId)
	GuiHelper.PlayGuiSound(SoundId)
end

--- Lazy-require MenuController để điều phối mở/đóng cửa sổ
local _menuController = nil
local function GetMenuController()
	if not _menuController then
		local Controllers = script.Parent
		local Module = Controllers:FindFirstChild("MenuController")
		if Module then
			_menuController = require(Module)
		end
	end
	return _menuController
end

local function GetStatValue(StatName)
	if not StatsFrame then return nil end
	local Frame = StatsFrame:FindFirstChild(StatName)
	return Frame and Frame:FindFirstChild("ValueText")
end

-- =========================================================
-- STATE
-- =========================================================

local _renderedItems = {}  -- Lưu các Frame đã clone để dọn dẹp khi đóng

-- =========================================================
-- PRIVATE: Avatar 2D Thumbnail
-- =========================================================

--- Hiển thị ảnh đại diện chân dung (HeadShot) 2D cho LocalPlayer trong Profile
local function LoadPlayerAvatar(ImageLabel)
	if not ImageLabel then return end
	ImageLabel.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId)
end

-- =========================================================
-- PRIVATE: Hiển thị skin đang trang bị trong ItemList
-- =========================================================

--- Dọn dẹp các ItemFrame đã clone
local function ClearItemList()
	for _, Frame in ipairs(_renderedItems) do
		ItemCard.Destroy(Frame)
	end
	_renderedItems = {}
end

--- Clone 1 ItemFrame từ template và điền thông tin Entry
--- @param Entry table  — entry từ ItemRegistry
--- @param LayoutOrder number
local function RenderSingleItem(Entry, LayoutOrder)
	if not ItemList then return end

	local Frame = ItemCard.Create(ItemList, Entry.Id, Entry.Type, {
		LayoutOrder  = LayoutOrder,
		ShowEquipped = false,
		ShowDropRate = false,
		EnableHover  = false,
		EnableSound  = false,
	})

	if Frame then
		table.insert(_renderedItems, Frame)
	end
end

--- Render 2 skin đang trang bị (EquippedIcicle + EquippedIceBlock)
local function RenderEquippedItems()
	ClearItemList()

	local Data = PlayerDataController.GetData()
	if not Data then return end

	local EquippedIcicleId  = Data.EquippedIcicle  or "Default"
	local EquippedIceBlockId = Data.EquippedIceBlock or "Default"

	-- Tìm entry trong registry
	local IcicleEntry = ItemRegistry.GetItem(EquippedIcicleId, "Icicle")
	local BlockEntry  = ItemRegistry.GetItem(EquippedIceBlockId, "Block")

	if IcicleEntry then
		RenderSingleItem(IcicleEntry, 0)
	end
	if BlockEntry then
		RenderSingleItem(BlockEntry, 1)
	end
end

-- =========================================================
-- PRIVATE: Điền số liệu thống kê
-- =========================================================

local function PopulateStats()
	local Data = PlayerDataController.GetData()
	if not Data then return end

	-- Stats trong PlayerStats.Stats
	local StatMappings = {
		{ Frame = "Freezes",       Key = "TotalFreezes",       Format = GuiHelper.FormatNumber },
		{ Frame = "Thaws",         Key = "TotalThaws",         Format = GuiHelper.FormatNumber },
		{ Frame = "FreezingSpree", Key = "TotalFreezingSpree", Format = GuiHelper.FormatNumber },
		{ Frame = "ThawingSpree",  Key = "TotalThawingSpree",  Format = GuiHelper.FormatNumber },
		{ Frame = "FirstBlood",    Key = "TotalFirstBlood",    Format = GuiHelper.FormatNumber },
		{ Frame = "LastStanding",  Key = "TotalLastStanding",  Format = GuiHelper.FormatNumber },
	}

	for _, Mapping in ipairs(StatMappings) do
		local ValueLabel = GetStatValue(Mapping.Frame)
		if ValueLabel then
			local RawValue = Data[Mapping.Key] or 0
			ValueLabel.Text = Mapping.Format(RawValue)
		end
	end

	-- GameWins ở PlayerStats.GameWins
	if GameWinsFrame then
		local WinsValueText = GameWinsFrame:FindFirstChild("ValueText")
		if WinsValueText then
			WinsValueText.Text = GuiHelper.FormatNumber(Data.TotalWins or 0)
		end
	end
end

--- Điền thông tin PlayerInfo
local function PopulatePlayerInfo()
	-- Tên: "DisplayName (@Name)"
	if PlayerNameText then
		PlayerNameText.Text = string.format(
			"%s (@%s)",
			LocalPlayer.DisplayName,
			LocalPlayer.Name
		)
	end

	-- Avatar 2D Thumbnail (HeadShot)
	LoadPlayerAvatar(AvatarThumbnailFrame)
end

-- =========================================================
-- OPEN / CLOSE
-- =========================================================

local function OpenProfile()
	if not Profile then return end

	-- Hiển thị dữ liệu cũ trước từ cache để tránh giao diện trống/trễ
	PopulatePlayerInfo()
	RenderEquippedItems()
	PopulateStats()

	-- Tải dữ liệu mới bất đồng bộ từ Server và cập nhật lại giao diện
	task.spawn(function()
		PlayerDataController.RefreshData()
		PopulatePlayerInfo()
		RenderEquippedItems()
		PopulateStats()
	end)
end

local function CloseProfile()
	if not Profile then return end
	ClearItemList()
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local ProfileController = {}

function ProfileController:Init()
	if not Profile then
		warn("[ProfileController] Không tìm thấy Profile frame trong Menu GUI.")
		return
	end

	-- Ẩn mặc định khi khởi tạo
	Profile.Visible = false

	-- Đăng ký tab với MenuController
	local MenuCtrl = GetMenuController()
	if MenuCtrl then
		MenuCtrl.RegisterTab("Profile", {
			Open  = OpenProfile,
			Close = CloseProfile,
			Frame = Profile,
		})
	end

	-- Tự động gắn Scale & SFX cho toàn bộ nút trong Profile (bỏ qua ItemList chứa skin trang bị)
	if ItemList then
		GuiHelper.SetIgnoreAutoBind(ItemList, true)
	end

	GuiHelper.AutoBindButtons(Profile, { MenuName = "Profile" })

	-- Nút đóng Profile
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			local MenuC = GetMenuController()
			if MenuC then
				MenuC.CloseCurrentTab()
			else
				CloseProfile()
			end
		end)
	end

	print("[ProfileController] Đã khởi tạo.")
end

--- Hàm public để GameStateController ẩn Profile khi vào trận
--- @param Visible boolean
function ProfileController.SetVisible(Visible)
	if not Profile then return end
	if not Visible then
		CloseProfile()
	end
	-- Khi Visible = true, không tự mở — để người chơi tự bấm mở
end

return ProfileController
