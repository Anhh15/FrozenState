-- IconGenerator.lua
-- Pipeline tự động hóa tạo Icon 2D từ Model 3D qua GUI ViewportFrame trong Roblox Studio
-- Đồng bộ góc chụp và ánh sáng 100% với ViewportConfig / ItemSelection, giao tiếp với Python Local Worker qua HttpService

local HttpService       = game:GetService("HttpService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconPipelineConfig = require(ReplicatedStorage.Shared.Config.IconPipelineConfig)
local ItemRegistry       = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local ViewportManager    = require(ReplicatedStorage.Shared.Tools.ViewportManager)

local IconGenerator = {}

-- =========================================================
-- PRIVATE STATE & REFERENCES
-- =========================================================

local CaptureScreenGui = nil
local CaptureViewport  = nil

-- =========================================================
-- INTERNAL HELPERS: GUI BUỒNG CHỤP VIEWPORTFRAME
-- =========================================================

--- Tìm container thích hợp nhất để gắn ScreenGui trong cả Edit Mode lẫn Play Mode
--- @return Instance
local function GetCaptureGuiContainer()
	-- Ưu tiên 1: CoreGui trong Studio Command Bar / Edit Mode
	local SuccessCore, TargetCore = pcall(function()
		return game:GetService("CoreGui")
	end)
	if SuccessCore and TargetCore then
		return TargetCore
	end

	-- Ưu tiên 2: PlayerGui nếu đang ở Play / Run Mode
	if Players.LocalPlayer then
		local PlayerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if PlayerGui then
			return PlayerGui
		end
	end

	-- Fallback cuối cùng: StarterGui
	return game:GetService("StarterGui")
end

--- Dọn dẹp ScreenGui buồng chụp nếu đang tồn tại
local function CleanupCaptureGui()
	if CaptureScreenGui then
		CaptureScreenGui:Destroy()
		CaptureScreenGui = nil
		CaptureViewport = nil
	end

	-- Quét dọn phòng hờ instance cũ trùng tên còn sót lại
	local Container = GetCaptureGuiContainer()
	if Container then
		local ExistingGui = Container:FindFirstChild(IconPipelineConfig.GuiConfig.ScreenGuiName)
		if ExistingGui then
			ExistingGui:Destroy()
		end
	end
end

--- Khởi tạo ScreenGui và ViewportFrame buồng chụp vuông tỉ lệ 1:1 căn giữa màn hình
local function SetupCaptureGui()
	CleanupCaptureGui()

	local Container = GetCaptureGuiContainer()
	local GuiCfg = IconPipelineConfig.GuiConfig

	CaptureScreenGui = Instance.new("ScreenGui")
	CaptureScreenGui.Name           = GuiCfg.ScreenGuiName
	CaptureScreenGui.DisplayOrder   = GuiCfg.DisplayOrder
	CaptureScreenGui.IgnoreGuiInset = true
	CaptureScreenGui.ResetOnSpawn   = false
	CaptureScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	CaptureViewport = Instance.new("ViewportFrame")
	CaptureViewport.Name                   = "CaptureViewport"
	CaptureViewport.AnchorPoint            = Vector2.new(0.5, 0.5)
	CaptureViewport.Position               = UDim2.new(0.5, 0, 0.5, 0)
	CaptureViewport.Size                   = UDim2.new(0, GuiCfg.ViewportSize.X, 0, GuiCfg.ViewportSize.Y)
	CaptureViewport.BackgroundColor3       = IconPipelineConfig.BackgroundColors.Black
	CaptureViewport.BorderSizePixel        = 0
	CaptureViewport.BackgroundTransparency = 0
	CaptureViewport.Parent                 = CaptureScreenGui

	CaptureScreenGui.Parent = Container
end

--- Thay đổi màu nền của ViewportFrame cho các pha chụp Dual-Shot Matte
--- @param TargetColor Color3
local function SetCaptureBackgroundColor(TargetColor)
	if CaptureViewport then
		CaptureViewport.BackgroundColor3 = TargetColor
	end
end

-- =========================================================
-- INTERNAL HELPERS: CAMERA VÀ MODEL
-- =========================================================

--- Tìm model preview từ cây thư mục chuẩn ReplicatedStorage.Assets.ItemPreview
--- @param ItemType string
--- @param ItemId   string
--- @return Instance|nil
local function FindPreviewModelTemplate(ItemType, ItemId)
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	local ItemPreview = Assets and Assets:FindFirstChild("ItemPreview")
	if not ItemPreview then
		warn("[IconGenerator] Không tìm thấy thư mục Assets.ItemPreview trong ReplicatedStorage.")
		return nil
	end

	local TypeFolderName = IconPipelineConfig.PreviewFolderNames[ItemType] or (ItemType .. "s")
	local TypeFolder = ItemPreview:FindFirstChild(TypeFolderName)
	if not TypeFolder then
		warn(("[IconGenerator] Không tìm thấy thư mục phân loại '%s' tại ItemPreview."):format(TypeFolderName))
		return nil
	end

	local Template = TypeFolder:FindFirstChild(ItemId)
	if not Template then
		warn(("[IconGenerator] Không tìm thấy model preview cho ItemId='%s' trong %s."):format(ItemId, TypeFolderName))
		return nil
	end

	return Template
end

-- =========================================================
-- INTERNAL HELPERS: HTTP GIAO TIẾP VỚI PYTHON WORKER
-- =========================================================

--- Gửi lệnh chụp tới Python Local Worker
--- @param ItemId   string
--- @param ItemType string
--- @param Step     string - "Black" hoặc "White"
--- @return boolean
local function RequestCaptureStep(ItemId, ItemType, Step)
	local Payload = {
		ItemId   = ItemId,
		ItemType = ItemType,
		Step     = Step,
	}

	local Success, Response = pcall(function()
		return HttpService:PostAsync(
			IconPipelineConfig.ServerUrl,
			HttpService:JSONEncode(Payload),
			Enum.HttpContentType.ApplicationJson,
			false
		)
	end)

	if not Success then
		warn(("[IconGenerator] Lỗi gửi HTTP request (%s - %s): %s"):format(ItemId, Step, tostring(Response)))
		return false
	end

	return true
end

-- =========================================================
-- PUBLIC API
-- =========================================================

--- Thực thi pipeline chụp ảnh toàn bộ hoặc một phần danh mục item qua GUI ViewportFrame
--- @param FilterType   string|nil - Lọc theo loại ("Icicle", "Block", "Chest") hoặc nil để chụp tất cả
--- @param FilterItemId string|nil - Lọc theo ItemId cụ thể hoặc nil để chụp toàn bộ
function IconGenerator.Run(FilterType, FilterItemId)
	print("==================================================")
	print("[IconGenerator] KHỞI ĐỘNG PIPELINE TỰ ĐỘNG CHỤP ICON (GUI VIEWPORT)...")
	print("==================================================")

	-- Kiểm tra bật HttpService
	local HttpCheckSuccess, _ = pcall(function()
		return HttpService.HttpEnabled
	end)

	if not HttpCheckSuccess then
		warn("[IconGenerator] CẢNH BÁO: HttpService chưa được kích hoạt! Hãy bật 'Allow HTTP Requests' trong Game Settings.")
		return
	end

	-- Khởi tạo ScreenGui và ViewportFrame buồng chụp
	SetupCaptureGui()

	-- Thu thập danh sách item cần chụp từ ItemRegistry
	local TargetItems = {}

	local AllIcicles = ItemRegistry.GetAllIcicles()
	for _, Entry in ipairs(AllIcicles) do
		if (not FilterType or FilterType == "Icicle") and (not FilterItemId or FilterItemId == Entry.Id) then
			table.insert(TargetItems, Entry)
		end
	end

	local AllBlocks = ItemRegistry.GetAllBlocks()
	for _, Entry in ipairs(AllBlocks) do
		if (not FilterType or FilterType == "Block") and (not FilterItemId or FilterItemId == Entry.Id) then
			table.insert(TargetItems, Entry)
		end
	end

	print(("[IconGenerator] Tổng số vật phẩm sẽ xử lý: %d"):format(#TargetItems))

	local SuccessCount = 0

	-- Bọc toàn bộ quá trình chụp trong pcall để luôn đảm bảo dọn dẹp sạch sẽ GUI kể cả khi crash
	local PipelineSuccess, PipelineError = pcall(function()
		for Index, Entry in ipairs(TargetItems) do
			print(("[%d/%d] Đang xử lý: %s (%s)..."):format(Index, #TargetItems, Entry.Name, Entry.Type))

			local Template = FindPreviewModelTemplate(Entry.Type, Entry.Id)
			if not Template then
				warn(("[IconGenerator] Bỏ qua '%s' do không có model preview."):format(Entry.Id))
				continue
			end

			-- Dọn dẹp nội dung cũ trong Viewport trước khi nạp mới
			ViewportManager.CleanViewport(CaptureViewport)

			-- Clone model preview vào ViewportFrame
			local ClonedModel = Template:Clone()

			-- Phòng thủ trường hợp asset là BasePart đơn lẻ thay vì Model
			if not ClonedModel:IsA("Model") then
				local WrapperModel = Instance.new("Model")
				WrapperModel.Name = ClonedModel.Name
				ClonedModel.Parent = WrapperModel
				ClonedModel = WrapperModel
			end

			ClonedModel.Parent = CaptureViewport

			-- Thiết lập Camera và Ánh sáng đồng bộ 100% qua ViewportManager
			ViewportManager.RenderItem(CaptureViewport, ClonedModel, Entry.Type, Entry.Id)
			task.wait(IconPipelineConfig.RenderDelays.AfterModelLoaded)

			-- Pha 1: Nền ĐEN
			SetCaptureBackgroundColor(IconPipelineConfig.BackgroundColors.Black)
			task.wait(IconPipelineConfig.RenderDelays.AfterColorChange)
			local BlackOk = RequestCaptureStep(Entry.Id, Entry.Type, "Black")

			-- Pha 2: Nền TRẮNG
			SetCaptureBackgroundColor(IconPipelineConfig.BackgroundColors.White)
			task.wait(IconPipelineConfig.RenderDelays.AfterColorChange)
			local WhiteOk = RequestCaptureStep(Entry.Id, Entry.Type, "White")

			-- Dọn dẹp model hiện tại
			ViewportManager.CleanViewport(CaptureViewport)

			if BlackOk and WhiteOk then
				SuccessCount = SuccessCount + 1
			else
				warn(("[IconGenerator] Thất bại khi chụp '%s'."):format(Entry.Id))
			end

			task.wait(IconPipelineConfig.RenderDelays.BetweenItems)
		end
	end)

	-- Dọn dẹp sạch sẽ GUI sau khi chụp xong
	CleanupCaptureGui()

	if not PipelineSuccess then
		warn(("[IconGenerator] LỖI TRONG QUÁ TRÌNH CHẠY PIPELINE: %s"):format(tostring(PipelineError)))
	end

	print("==================================================")
	print(("[IconGenerator] HOÀN TẤT PIPELINE! Thành công: %d/%d"):format(SuccessCount, #TargetItems))
	print("==================================================")
end

return IconGenerator
