-- ItemCard.lua
-- Module Functional Helper dùng chung (Shared) để render, quản lý trạng thái và dọn dẹp thẻ vật phẩm (ItemTemplate)
-- Sử dụng ItemRegistry, RarityConfig, ViewportManager và GuiHelper làm nền tảng

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemRegistry    = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig    = require(ReplicatedStorage.Shared.Config.RarityConfig)
local GuiConfig       = require(ReplicatedStorage.Shared.Config.GuiConfig)
local ViewportManager = require(ReplicatedStorage.Shared.Tools.ViewportManager)
local GuiHelper       = require(ReplicatedStorage.Shared.Tools.GuiHelper)

local ItemCard = {}

-- =========================================================
-- INTERNAL HELPERS
-- =========================================================

--- Lấy ItemTemplate từ ReplicatedStorage.Assets.Gui an toàn
--- @return Frame?
local function GetItemTemplate()
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets then return nil end

	local GuiFolder = Assets:FindFirstChild("Gui") or Assets:FindFirstChild("GUI")
	if not GuiFolder then return nil end

	return GuiFolder:FindFirstChild("ItemTemplate")
end

--- Lấy Folder chứa 3D Model preview tương ứng với loại item
--- @param ItemType string — "Icicle" hoặc "Block"
--- @return Folder?
local function GetItemPreviewFolder(ItemType)
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets then return nil end

	local ItemPreview = Assets:FindFirstChild("ItemPreview")
	if not ItemPreview then return nil end

	local SubFolderName = (ItemType == "Icicle") and "Icicles" or "Blocks"
	return ItemPreview:FindFirstChild(SubFolderName)
end

-- =========================================================
-- PUBLIC API
-- =========================================================

--- Khởi tạo và render hoàn chỉnh một thẻ ItemCard từ template
--- @param Parent Instance — Container chứa thẻ (ScrollingFrame / Frame)
--- @param ItemId string — Id vật phẩm (ví dụ: "Default", "BlueBlock")
--- @param ItemType string — "Icicle" hoặc "Block"
--- @param Options table? — Tùy chọn cấu hình hiển thị
--- @return Frame?
function ItemCard.Create(Parent, ItemId, ItemType, Options)
	local Template = GetItemTemplate()
	if not Template then
		warn("[ItemCard] Không tìm thấy ItemTemplate trong ReplicatedStorage/Assets/Gui.")
		return nil
	end

	Options = Options or {}

	-- 1. Tra cứu thông tin chi tiết của vật phẩm từ ItemRegistry
	local FullEntry = ItemRegistry.GetItem(ItemId, ItemType)
	if not FullEntry then
		warn(string.format("[ItemCard] Không tìm thấy ItemId='%s' Type='%s' trong ItemRegistry.", tostring(ItemId), tostring(ItemType)))
		return nil
	end

	local RarityEntry = RarityConfig[FullEntry.Rarity]

	-- 2. Clone template
	local Frame = Template:Clone()
	Frame.Name = FullEntry.Id
	Frame.Visible = (Options.Visible ~= false)
	if Options.LayoutOrder then
		Frame.LayoutOrder = Options.LayoutOrder
	end

	-- 3. Cập nhật NameText
	local NameText = Frame:FindFirstChild("NameText", true)
	if NameText then
		NameText.Text = FullEntry.Name
	end

	-- 4. Cập nhật RarityText
	local RarityText = Frame:FindFirstChild("RarityText", true)
	if RarityText and RarityEntry then
		RarityText.Text = FullEntry.Rarity
		if RarityEntry.Color then
			RarityText.TextColor3 = RarityEntry.Color
		end
	end

	-- 5. Cập nhật Background theo Rarity
	local Background = Frame:FindFirstChild("Background", true)
	if Background and Background:IsA("ImageLabel") and RarityEntry then
		if RarityEntry.ImageId then
			Background.Image = RarityEntry.ImageId
		end
		if RarityEntry.Color then
			Background.ImageColor3 = RarityEntry.Color
		end
	end

	-- 6. Cập nhật trạng thái Equipped
	if Options.ShowEquipped then
		ItemCard.SetEquipped(Frame, Options.IsEquipped == true)
	else
		local EquippedTag = Frame:FindFirstChild("EquippedText", true) or Frame:FindFirstChild("Equipped", true)
		if EquippedTag then
			EquippedTag.Visible = false
		end
	end

	-- 7. Cập nhật trạng thái DropRate
	if Options.ShowDropRate and Options.DropRate ~= nil then
		ItemCard.SetDropRate(Frame, Options.DropRate)
	else
		local DropText = Frame:FindFirstChild("DropRateText", true)
		if DropText then
			DropText.Visible = false
		end
	end

	-- 8. Nạp Model 3D vào ViewportFrame
	local ItemViewport = Frame:FindFirstChild("ItemViewport", true)
	if ItemViewport then
		ViewportManager.CleanViewport(ItemViewport)
		local PreviewFolder = GetItemPreviewFolder(FullEntry.Type)
		if PreviewFolder then
			local ItemModel = PreviewFolder:FindFirstChild(FullEntry.Id)
			if ItemModel then
				local ModelClone = ItemModel:Clone()
				ModelClone.Parent = ItemViewport
				ViewportManager.RenderItem(ItemViewport, ModelClone, FullEntry.Type, FullEntry.Id)
			end
		end
	end

	-- 9. Gắn sự kiện Click (nếu có)
	if Options.OnClick then
		ItemCard.BindClick(Frame, function()
			Options.OnClick(FullEntry)
		end)
	end

	-- 10. Gắn Hover Animation qua UIScale (nếu được bật)
	if Options.EnableHover == true then
		GuiHelper.BindButtonScale(Frame)
	end

	if Parent then
		Frame.Parent = Parent
	end

	return Frame
end

--- Cập nhật trạng thái hiển thị của thẻ Equipped in-place mà không cần re-render
--- @param Frame Instance — Thẻ ItemCard
--- @param IsEquipped boolean — Trạng thái trang bị
function ItemCard.SetEquipped(Frame, IsEquipped)
	if not Frame or not Frame:IsA("GuiObject") then return end

	local EquippedTag = Frame:FindFirstChild("EquippedText", true) or Frame:FindFirstChild("Equipped", true)
	if EquippedTag then
		EquippedTag.Visible = (IsEquipped == true)
	end
end

--- Cập nhật nhãn DropRate in-place mà không cần re-render
--- @param Frame Instance — Thẻ ItemCard
--- @param DropRate number|string|nil — Tỉ lệ phần trăm (nil = ẩn)
function ItemCard.SetDropRate(Frame, DropRate)
	if not Frame or not Frame:IsA("GuiObject") then return end

	local DropText = Frame:FindFirstChild("DropRateText", true)
	if DropText then
		DropText.Visible = (DropRate ~= nil)
		if DropRate ~= nil then
			DropText.Text = string.format("%d%%", tonumber(DropRate) or 0)
		end
	end
end

--- Gắn sự kiện click an toàn cho Card (hỗ trợ cả GuiButton và Frame InputBegan)
--- @param Frame Instance — Thẻ ItemCard
--- @param Callback function — Hàm xử lý khi click
--- @return RBXScriptConnection?
function ItemCard.BindClick(Frame, Callback)
	if not Frame or not Callback then return nil end

	local ClickTarget = Frame:IsA("GuiButton") and Frame or Frame:FindFirstChildWhichIsA("GuiButton")
	if ClickTarget then
		return ClickTarget.MouseButton1Click:Connect(Callback)
	else
		return Frame.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Callback()
			end
		end)
	end
end

--- Dọn sạch tài nguyên 3D trong ViewportFrame và hủy Frame
--- @param Frame Instance? — Thẻ ItemCard cần hủy
function ItemCard.Destroy(Frame)
	if not Frame or not Frame:IsA("Instance") then return end

	local ItemViewport = Frame:FindFirstChild("ItemViewport", true)
	if ItemViewport then
		ViewportManager.CleanViewport(ItemViewport)
	end

	Frame:Destroy()
end

return ItemCard
