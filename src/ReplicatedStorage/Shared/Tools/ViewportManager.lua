-- ViewportManager.lua
-- Module dùng chung để render vật phẩm 3D vào bất kỳ ViewportFrame nào
-- KHÔNG áp dụng cho PlayerViewport (avatar 3D — xem ProfileController)
--
-- API công khai:
--   ViewportManager.RenderItem(Viewport, Model, ItemType, ItemId)
--   ViewportManager.CleanViewport(Viewport)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewportConfig = require(ReplicatedStorage.Shared.Config.ViewportConfig)

local ViewportManager = {}

-- =========================================================
-- INTERNAL HELPERS
-- =========================================================

--- Tính toán CFrame camera hướng về tâm model với khoảng cách phù hợp
--- Thuật toán: Bounding Box → Radius → Distance qua lượng giác → CFrame từ Pitch/Yaw
--- @param ModelCFrame CFrame  — Tâm của model (từ GetBoundingBox)
--- @param ModelSize   Vector3 — Kích thước bao ngoài model (từ GetBoundingBox)
--- @param Config      table   — Bảng tham số từ ViewportConfig.Resolve()
--- @return CFrame — CFrame vị trí camera
local function ComputeCameraCFrame(ModelCFrame, ModelSize, Config)
	-- Bán kính của hình cầu bao quanh model
	local Radius = ModelSize.Magnitude / 2

	-- Khoảng cách tối thiểu để model vừa khít trong FOV
	-- Công thức: d = r / sin(FOV/2)
	local HalfFovRad = math.rad(Config.FieldOfView / 2)
	local BaseDistance = Radius / math.sin(HalfFovRad)

	-- Áp dụng hệ số padding để có khoảng thoáng
	local FinalDistance = BaseDistance * Config.PaddingFactor

	-- Tính CFrame camera từ góc Pitch (dọc) và Yaw (ngang)
	-- Camera bắt đầu từ tâm model, xoay theo góc chỉ định, rồi lùi ra theo trục Z
	local RotationCFrame = CFrame.Angles(math.rad(Config.PitchAngle), math.rad(Config.YawAngle), 0)
	local CameraCFrame = CFrame.new(ModelCFrame.Position)
		* RotationCFrame
		* CFrame.new(0, 0, FinalDistance)

	return CameraCFrame
end

-- =========================================================
-- PUBLIC API
-- =========================================================

--- Dọn dẹp toàn bộ nội dung trong ViewportFrame (Model + Camera)
--- Gọi trước khi render item mới để tránh memory leak
--- @param Viewport ViewportFrame
function ViewportManager.CleanViewport(Viewport)
	if not Viewport then return end
	for _, Child in ipairs(Viewport:GetChildren()) do
		Child:Destroy()
	end
end

--- Tạo Camera tự động và gắn vào ViewportFrame để hiển thị vật phẩm
--- Model phải đã được clone và là con của Viewport trước khi gọi hàm này
--- @param Viewport  ViewportFrame — Frame cần hiển thị
--- @param Model     Model         — Model đã được parent vào Viewport
--- @param ItemType  string|nil    — "Icicle", "Block", "Chest" (để lookup TypeOverride)
--- @param ItemId    string|nil    — Id cụ thể trong ItemRegistry (để lookup ItemOverride)
function ViewportManager.RenderItem(Viewport, Model, ItemType, ItemId)
	if not Viewport or not Model then
		warn("[ViewportManager] RenderItem: Viewport hoặc Model bị nil.")
		return
	end

	-- Lấy tham số camera đã merge từ config
	local Config = ViewportConfig.Resolve(ItemType, ItemId)

	-- Tính Bounding Box của model để xác định tâm và kích thước
	local ModelCFrame, ModelSize = Model:GetBoundingBox()

	-- Guard: nếu model không có kích thước hợp lệ thì bỏ qua
	if ModelSize.Magnitude < 0.001 then
		warn(("[ViewportManager] RenderItem: Model '%s' có kích thước quá nhỏ hoặc bằng 0."):format(Model.Name))
		return
	end

	-- Tính toán vị trí và hướng camera
	local CameraCFrame = ComputeCameraCFrame(ModelCFrame, ModelSize, Config)

	-- Tạo Camera và gắn vào Viewport
	local Camera = Instance.new("Camera")
	Camera.FieldOfView = Config.FieldOfView
	Camera.CFrame      = CameraCFrame
	Camera.Focus       = ModelCFrame  -- Camera luôn nhìn vào tâm model
	Camera.Parent      = Viewport

	Viewport.CurrentCamera = Camera
end

return ViewportManager
