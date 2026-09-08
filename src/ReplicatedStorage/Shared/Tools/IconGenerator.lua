-- IconGenerator.lua
-- Pipeline tự động hóa thiết lập buồng chụp ảnh trong Roblox Studio
-- Đồng bộ góc chụp với ViewportConfig và giao tiếp với Python Local Worker qua HttpService

local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconPipelineConfig = require(ReplicatedStorage.Shared.Config.IconPipelineConfig)
local ItemRegistry       = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local ViewportConfig     = require(ReplicatedStorage.Shared.Config.ViewportConfig)
local ViewportManager    = require(ReplicatedStorage.Shared.Tools.ViewportManager)

local IconGenerator = {}

-- =========================================================
-- PRIVATE STATE & REFERENCES
-- =========================================================

local StudioBoxFolder = nil
local WallParts       = {}
local LightInstances  = {}
local BackdropPart    = nil

-- =========================================================
-- INTERNAL HELPERS: BUỒNG CHỤP & ÁNH SÁNG
-- =========================================================

--- Tạo một vách ngăn cho buồng chụp hộp kín
--- @param Name     string  - Tên vách
--- @param Position Vector3 - Tọa độ tâm của vách
--- @param Size     Vector3 - Kích thước vách
--- @param Parent   Folder  - Thư mục chứa
--- @return Part
local function CreateWallPart(Name, Position, Size, Parent)
	local Wall = Instance.new("Part")
	Wall.Name         = Name
	Wall.Anchored     = true
	Wall.CanCollide   = false
	Wall.CanTouch     = false
	Wall.CanQuery     = false
	Wall.CastShadow   = true -- Ngăn chặn 100% ánh sáng mặt trời, skybox và ambient của game
	Wall.Material     = IconPipelineConfig.BoxMaterial
	Wall.Color        = IconPipelineConfig.BackgroundColors.Black
	Wall.Size         = Size
	Wall.CFrame       = CFrame.new(Position)
	Wall.Parent       = Parent
	return Wall
end

--- Dựng buồng chụp khép kín tại tọa độ cách ly Y = 100,000
--- Khối hộp kín ngăn hoàn toàn ánh sáng môi trường và bầu trời bên ngoài
local function SetupStudioBox()
	if StudioBoxFolder then
		StudioBoxFolder:Destroy()
	end

	StudioBoxFolder = Instance.new("Folder")
	StudioBoxFolder.Name = "IconStudioBox"
	StudioBoxFolder.Parent = Workspace

	WallParts = {}
	LightInstances = {}
	BackdropPart = nil

	local Center   = IconPipelineConfig.StudioBoxPosition
	local BoxSize  = IconPipelineConfig.StudioBoxSize
	local HalfSize = BoxSize / 2
	local WallThick = 2

	-- Dựng 6 mặt của buồng chụp lớn để cách ly hoàn toàn
	local WallsDef = {
		{ Name = "Floor",   Pos = Center + Vector3.new(0, -HalfSize.Y, 0), Size = Vector3.new(BoxSize.X + WallThick * 2, WallThick, BoxSize.Z + WallThick * 2) },
		{ Name = "Ceiling", Pos = Center + Vector3.new(0, HalfSize.Y, 0),  Size = Vector3.new(BoxSize.X + WallThick * 2, WallThick, BoxSize.Z + WallThick * 2) },
		{ Name = "Back",    Pos = Center + Vector3.new(0, 0, -HalfSize.Z), Size = Vector3.new(BoxSize.X, BoxSize.Y, WallThick) },
		{ Name = "Front",   Pos = Center + Vector3.new(0, 0, HalfSize.Z),  Size = Vector3.new(BoxSize.X, BoxSize.Y, WallThick) },
		{ Name = "Left",    Pos = Center + Vector3.new(-HalfSize.X, 0, 0), Size = Vector3.new(WallThick, BoxSize.Y, BoxSize.Z) },
		{ Name = "Right",   Pos = Center + Vector3.new(HalfSize.X, 0, 0),  Size = Vector3.new(WallThick, BoxSize.Y, BoxSize.Z) },
	}

	for _, Def in ipairs(WallsDef) do
		local Wall = CreateWallPart(Def.Name, Def.Pos, Def.Size, StudioBoxFolder)
		table.insert(WallParts, Wall)
	end

	-- Tạo tấm phông vô cực Backdrop đặt sau lưng item theo hướng nhìn camera
	BackdropPart = Instance.new("Part")
	BackdropPart.Name         = "StudioBackdrop"
	BackdropPart.Anchored     = true
	BackdropPart.CanCollide   = false
	BackdropPart.CanTouch     = false
	BackdropPart.CanQuery     = false
	BackdropPart.CastShadow   = false
	BackdropPart.Material     = IconPipelineConfig.BoxMaterial
	BackdropPart.Color        = IconPipelineConfig.BackgroundColors.Black
	BackdropPart.Size         = IconPipelineConfig.Backdrop.Size
	BackdropPart.CFrame       = CFrame.new(Center + Vector3.new(0, 0, -IconPipelineConfig.Backdrop.Distance))
	BackdropPart.Parent       = StudioBoxFolder

	-- Bố trí nguồn sáng 3 điểm gom chùm tia (SpotLight định hướng)
	local LightingCfg = IconPipelineConfig.Lighting
	local LightsToCreate = {
		LightingCfg.KeyLight,
		LightingCfg.FillLight,
		LightingCfg.BackLight,
	}

	for Index, LightDef in ipairs(LightsToCreate) do
		local LightPos = Center + LightDef.Offset
		local AnchorPart = Instance.new("Part")
		AnchorPart.Name         = LightDef.Name or ("LightAnchor_" .. tostring(Index))
		AnchorPart.Anchored     = true
		AnchorPart.CanCollide   = false
		AnchorPart.CanTouch     = false
		AnchorPart.CanQuery     = false
		AnchorPart.Transparency = 1
		AnchorPart.Size         = Vector3.new(1, 1, 1)
		-- Định hướng AnchorPart nhìn thẳng vào tâm buồng chụp (tâm Model)
		AnchorPart.CFrame       = CFrame.lookAt(LightPos, Center)
		AnchorPart.Parent       = StudioBoxFolder

		local Spot = Instance.new("SpotLight")
		Spot.Name       = LightDef.Name or ("SpotLight_" .. tostring(Index))
		Spot.Face       = Enum.NormalId.Front
		Spot.Angle      = LightDef.Angle or 60
		Spot.Brightness = LightDef.Brightness
		Spot.Range      = LightDef.Range
		Spot.Color      = LightDef.Color
		Spot.Shadows    = LightDef.Shadows or false
		Spot.Parent     = AnchorPart

		table.insert(LightInstances, Spot)
	end
end

--- Đổi màu toàn bộ vách buồng chụp và tấm phông Backdrop
--- @param TargetColor Color3
local function SetStudioBackgroundColor(TargetColor)
	for _, Wall in ipairs(WallParts) do
		Wall.Color = TargetColor
	end
	if BackdropPart then
		BackdropPart.Color = TargetColor
	end
end

--- Dọn dẹp buồng chụp và các instance phụ trợ
local function CleanupStudioBox()
	if StudioBoxFolder then
		StudioBoxFolder:Destroy()
		StudioBoxFolder = nil
	end
	WallParts = {}
	LightInstances = {}
	BackdropPart = nil
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

--- Tính toán Bounding Box an toàn cho Model hoặc BasePart đơn lẻ
--- @param TargetInstance Instance
--- @return CFrame, Vector3
local function GetSafeBoundingBox(TargetInstance)
	if TargetInstance:IsA("Model") then
		return TargetInstance:GetBoundingBox()
	elseif TargetInstance:IsA("BasePart") then
		return TargetInstance.CFrame, TargetInstance.Size
	end

	-- Fallback nếu là Folder chứa Parts
	local Parts = TargetInstance:GetDescendants()
	local MinPos = Vector3.new(math.huge, math.huge, math.huge)
	local MaxPos = Vector3.new(-math.huge, -math.huge, -math.huge)
	local HasValidPart = false

	for _, Child in ipairs(Parts) do
		if Child:IsA("BasePart") then
			HasValidPart = true
			local Half = Child.Size / 2
			local Corners = {
				Child.CFrame * Vector3.new(-Half.X, -Half.Y, -Half.Z),
				Child.CFrame * Vector3.new(Half.X, Half.Y, Half.Z),
			}
			for _, Pos in ipairs(Corners) do
				MinPos = Vector3.new(math.min(MinPos.X, Pos.X), math.min(MinPos.Y, Pos.Y), math.min(MinPos.Z, Pos.Z))
				MaxPos = Vector3.new(math.max(MaxPos.X, Pos.X), math.max(MaxPos.Y, Pos.Y), math.max(MaxPos.Z, Pos.Z))
			end
		end
	end

	if HasValidPart then
		local Center = (MinPos + MaxPos) / 2
		local Size   = MaxPos - MinPos
		return CFrame.new(Center), Size
	end

	return CFrame.new(IconPipelineConfig.StudioBoxPosition), Vector3.new(2, 2, 2)
end

--- Định vị Camera nhìn thẳng vào Model theo chuẩn ViewportConfig
--- @param TargetInstance Instance
--- @param ItemType       string
--- @param ItemId         string
local function SetupCamera(TargetInstance, ItemType, ItemId)
	local Camera = Workspace.CurrentCamera
	if not Camera then
		warn("[IconGenerator] Workspace.CurrentCamera không tồn tại.")
		return
	end

	local Config = ViewportConfig.Resolve(ItemType, ItemId)
	local ModelCFrame, ModelSize = GetSafeBoundingBox(TargetInstance)

	local CameraCFrame = ViewportManager.ComputeCameraCFrame(ModelCFrame, ModelSize, Config)

	Camera.CameraType   = Enum.CameraType.Scriptable
	Camera.FieldOfView  = Config.FieldOfView
	Camera.CFrame       = CameraCFrame
	Camera.Focus        = ModelCFrame

	-- Tự động căn chỉnh tấm phông vô cực Backdrop nằm vuông góc 100% phía sau lưng model
	-- Loại bỏ triệt để việc camera nhìn vào mép nối góc tường buồng chụp
	if BackdropPart then
		local LookDirection = (ModelCFrame.Position - CameraCFrame.Position).Unit
		local BackdropPosition = ModelCFrame.Position + (LookDirection * IconPipelineConfig.Backdrop.Distance)
		BackdropPart.CFrame = CFrame.lookAt(BackdropPosition, BackdropPosition + LookDirection)
	end
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

--- Thực thi pipeline chụp ảnh toàn bộ hoặc một phần danh mục item
--- @param FilterType   string|nil - Lọc theo loại ("Icicle", "Block", "Chest") hoặc nil để chụp tất cả
--- @param FilterItemId string|nil - Lọc theo ItemId cụ thể hoặc nil để chụp toàn bộ
function IconGenerator.Run(FilterType, FilterItemId)
	print("==================================================")
	print("[IconGenerator] KHỞI ĐỘNG PIPELINE TỰ ĐỘNG CHỤP ICON...")
	print("==================================================")

	-- Kiểm tra bật HttpService
	local HttpCheckSuccess, _ = pcall(function()
		return HttpService.HttpEnabled
	end)

	if not HttpCheckSuccess then
		warn("[IconGenerator] CẢNH BÁO: HttpService chưa được kích hoạt! Hãy bật 'Allow HTTP Requests' trong Game Settings.")
		return
	end

	-- Lưu CFrame camera ban đầu để khôi phục sau khi hoàn tất
	local OriginalCameraCFrame = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame
	local OriginalCameraType   = Workspace.CurrentCamera and Workspace.CurrentCamera.CameraType

	-- Dựng buồng chụp
	SetupStudioBox()

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
	local BoxCenter = IconPipelineConfig.StudioBoxPosition

	for Index, Entry in ipairs(TargetItems) do
		print(("[%d/%d] Đang xử lý: %s (%s)..."):format(Index, #TargetItems, Entry.Name, Entry.Type))

		local Template = FindPreviewModelTemplate(Entry.Type, Entry.Id)
		if not Template then
			warn(("[IconGenerator] Bỏ qua '%s' do không có model preview."):format(Entry.Id))
			continue
		end

		-- Clone model vào buồng chụp và dịch chuyển về tâm
		local ClonedModel = Template:Clone()
		ClonedModel.Parent = StudioBoxFolder

		if ClonedModel:IsA("Model") then
			ClonedModel:PivotTo(CFrame.new(BoxCenter))
		elseif ClonedModel:IsA("BasePart") then
			ClonedModel.CFrame = CFrame.new(BoxCenter)
		end

		-- Thiết lập Camera
		SetupCamera(ClonedModel, Entry.Type, Entry.Id)
		task.wait(IconPipelineConfig.RenderDelays.AfterModelLoaded)

		-- Pha 1: Nền ĐEN
		SetStudioBackgroundColor(IconPipelineConfig.BackgroundColors.Black)
		task.wait(IconPipelineConfig.RenderDelays.AfterColorChange)
		local BlackOk = RequestCaptureStep(Entry.Id, Entry.Type, "Black")

		-- Pha 2: Nền TRẮNG
		SetStudioBackgroundColor(IconPipelineConfig.BackgroundColors.White)
		task.wait(IconPipelineConfig.RenderDelays.AfterColorChange)
		local WhiteOk = RequestCaptureStep(Entry.Id, Entry.Type, "White")

		-- Xóa model tạm
		ClonedModel:Destroy()

		if BlackOk and WhiteOk then
			SuccessCount = SuccessCount + 1
		else
			warn(("[IconGenerator] Thất bại khi chụp '%s'."):format(Entry.Id))
		end

		task.wait(IconPipelineConfig.RenderDelays.BetweenItems)
	end

	-- Dọn dẹp buồng chụp
	CleanupStudioBox()

	-- Khôi phục Camera
	if Workspace.CurrentCamera and OriginalCameraCFrame then
		Workspace.CurrentCamera.CFrame     = OriginalCameraCFrame
		Workspace.CurrentCamera.CameraType = OriginalCameraType or Enum.CameraType.Custom
	end

	print("==================================================")
	print(("[IconGenerator] HOÀN TẤT PIPELINE! Thành công: %d/%d"):format(SuccessCount, #TargetItems))
	print("==================================================")
end

return IconGenerator
