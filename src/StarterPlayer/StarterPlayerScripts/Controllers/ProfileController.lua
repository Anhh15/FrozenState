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

local PlayerDataController = require(script.Parent.PlayerDataController)
local ItemRegistry         = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig         = require(ReplicatedStorage.Shared.Config.RarityConfig)
local GameConfig           = require(ReplicatedStorage.Shared.Config.GameConfig)
local ViewportManager       = require(ReplicatedStorage.Shared.Tools.ViewportManager)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local MenuGui = PlayerGui:WaitForChild("Menu", 10)
local NavGui  = PlayerGui:WaitForChild("NavigationButton", 10)

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

-- =========================================================
-- SFX
-- =========================================================

local SFX_CLOSE_BUTTON_CLICK = 103307955424380

local function PlayGuiSound(SoundId)
	local S = Instance.new("Sound")
	S.SoundId = "rbxassetid://" .. tostring(SoundId)
	S.Volume = 1
	S.Parent = PlayerGui
	S:Play()
	game:GetService("Debris"):AddItem(S, 3)
end

--- Lazy-require SpectateController để tránh circular dependency
local _spectateController = nil
local function GetSpectateController()
	if not _spectateController then
		local Module = script.Parent:FindFirstChild("SpectateController")
		if Module then
			_spectateController = require(Module)
		end
	end
	return _spectateController
end

--- Ẩn tất cả Frame con trong Menu ngoại trừ Profile
local function HideAllMenuFrames()
	if not MenuGui then return end
	for _, Child in ipairs(MenuGui:GetChildren()) do
		if Child:IsA("Frame") and Child ~= Profile then
			Child.Visible = false
		end
	end
end

local function GetStatValue(StatName)
	if not StatsFrame then return nil end
	local Frame = StatsFrame:FindFirstChild(StatName)
	return Frame and Frame:FindFirstChild("ValueText")
end

-- ItemTemplate dùng chung từ ReplicatedStorage
local Assets       = ReplicatedStorage:FindFirstChild("Assets")
local GuiFolder    = Assets and (Assets:FindFirstChild("Gui") or Assets:FindFirstChild("GUI"))
local ItemTemplate = GuiFolder and GuiFolder:FindFirstChild("ItemTemplate")

-- NavigationButton mở Profile
local ProfileNavButton = NavGui and NavGui:FindFirstChild("Profile", true)

-- Frame Button bên trong NavigationButton (ẩn khi Profile mở, Stats vẫn hiện)
local NavButton = NavGui and NavGui:FindFirstChild("Button")

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
		if Frame and Frame.Parent then
			local ItemViewport = Frame:FindFirstChild("ItemViewport")
			if ItemViewport then
				ViewportManager.CleanViewport(ItemViewport)
			end
			Frame:Destroy()
		end
	end
	_renderedItems = {}
end

--- Clone 1 ItemFrame từ template và điền thông tin Entry
--- @param Entry table  — entry từ ItemRegistry
--- @param LayoutOrder number
local function RenderSingleItem(Entry, LayoutOrder)
	if not ItemList or not ItemTemplate then return end

	local Frame = ItemTemplate:Clone()
	Frame.Name        = Entry.Id
	Frame.Visible     = true
	Frame.LayoutOrder = LayoutOrder

	-- Gán Background theo Rarity
	local Background = Frame:FindFirstChild("Background")
	local RarityCfg  = RarityConfig[Entry.Rarity]
	if Background and RarityCfg then
		if Background:IsA("ImageLabel") then
			Background.Image       = RarityCfg.ImageId
			Background.ImageColor3 = RarityCfg.Color
		end
	end

	-- RarityText
	local RarityText = Frame:FindFirstChild("RarityText")
	if RarityText and RarityCfg then
		RarityText.Text       = Entry.Rarity
		RarityText.TextColor3 = RarityCfg.Color
	end

	-- NameText
	local NameText = Frame:FindFirstChild("NameText")
	if NameText then
		NameText.Text = Entry.Name
	end

	-- EquippedTag (ẩn trong profile view)
	local EquippedTag = Frame:FindFirstChild("EquippedText", true) or Frame:FindFirstChild("Equipped", true)
	if EquippedTag then
		EquippedTag.Visible = false
	end

	-- ViewportFrame bên trong ItemFrame — dùng LoadPreviewModel pattern từ InventoryController
	local ItemViewport = Frame:FindFirstChild("ItemViewport")
	if ItemViewport then
		local TypeFolder = (Entry.Type == "Icicle") and "Icicles" or "Blocks"
		local PreviewFolder = ReplicatedStorage
			:FindFirstChild("Assets")
			and ReplicatedStorage.Assets
			:FindFirstChild("ItemPreview")
			and ReplicatedStorage.Assets.ItemPreview
			:FindFirstChild(TypeFolder)

		if PreviewFolder then
			local ModelTemplate = PreviewFolder:FindFirstChild(Entry.Id)
			if ModelTemplate then
				local Model = ModelTemplate:Clone()
				Model.Parent = ItemViewport
				-- Tạo camera tự động qua ViewportManager
				ViewportManager.RenderItem(ItemViewport, Model, Entry.Type, Entry.Id)
			end
		end
	end

	Frame.Parent = ItemList
	table.insert(_renderedItems, Frame)
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

--- Format giá trị boolean thành "Yes" / "No"
local function FormatBool(Value)
	return Value and "Yes" or "No"
end

local function PopulateStats()
	local Data = PlayerDataController.GetData()
	if not Data then return end

	-- Stats trong PlayerStats.Stats
	local StatMappings = {
		{ Frame = "Freezes",       Key = "TotalFreezes",       Format = tostring },
		{ Frame = "Thaws",         Key = "TotalThaws",         Format = tostring },
		{ Frame = "FreezingSpree", Key = "TotalFreezingSpree", Format = tostring },
		{ Frame = "ThawingSpree",  Key = "TotalThawingSpree",  Format = tostring },
		{ Frame = "FirstBlood",    Key = "TotalFirstBlood",    Format = tostring },
		{ Frame = "LastStanding",  Key = "TotalLastStanding",  Format = tostring },
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
			WinsValueText.Text = tostring(Data.TotalWins or 0)
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

	-- Ẩn các Frame Menu anh em và NavButton trước khi mở Profile
	HideAllMenuFrames()
	if NavButton then NavButton.Visible = false end

	Profile.Visible = true

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
	Profile.Visible = false
	ClearItemList()
	-- Khôi phục NavButton trừ khi đang spectate
	-- Khôi phục NavButton trừ khi đang spectate
	if NavButton then
		local SpecCtrl = GetSpectateController()
		local IsSpectating = SpecCtrl and SpecCtrl.IsSpectating and SpecCtrl.IsSpectating()
		NavButton.Visible = not IsSpectating
	end
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

	-- Nút mở Profile từ NavigationButton
	if ProfileNavButton then
		ProfileNavButton.MouseButton1Click:Connect(OpenProfile)
	else
		warn("[ProfileController] Không tìm thấy nút Profile trong NavigationButton.")
	end

	-- Nút đóng Profile
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			PlayGuiSound(SFX_CLOSE_BUTTON_CLICK)
			CloseProfile()
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
