-- IconPipelineConfig.lua
-- Cấu hình tập trung cho Pipeline tự động hóa tạo Icon 2D từ Model 3D trong Roblox Studio
-- Tách biệt hoàn toàn tham số, tuyệt đối không hardcode trong script logic

local IconPipelineConfig = {
	-- Endpoint HTTP kết nối tới Python Local Worker
	ServerUrl = "http://127.0.0.1:5000/capture",

	-- Vị trí đặt Buồng Chụp (Photo Studio Box) - biệt lập hoàn toàn khỏi Map
	StudioBoxPosition = Vector3.new(0, 100000, 0),

	-- Kích thước buồng chụp hộp kín
	StudioBoxSize = Vector3.new(50, 50, 50),

	-- Vật liệu của các vách buồng chụp (SmoothPlastic giảm thiểu phản xạ specular không mong muốn)
	BoxMaterial = Enum.Material.Plastic,

	-- Màu sắc cho 2 pha chụp Dual-Shot Matte
	BackgroundColors = {
		Black = Color3.new(0, 0, 0),
		White = Color3.new(1, 1, 1),
	},

	-- Thời gian chờ (giây) giữa các thao tác để Roblox Studio hoàn tất vẽ frame
	RenderDelays = {
		AfterColorChange = 0.25, -- Chờ engine cập nhật màu nền
		AfterModelLoaded = 0.15, -- Chờ model render hoàn chỉnh
		BetweenItems     = 0.10, -- Giãn cách giữa 2 item liên tiếp
	},

	-- Cấu hình hệ thống đèn chiếu sáng trung tính trong buồng chụp
	Lighting = {
		AmbientLightColor = Color3.fromRGB(200, 200, 200),
		KeyLight = {
			Offset     = Vector3.new(8, 12, 12),
			Brightness = 2.0,
			Range      = 40,
			Color      = Color3.fromRGB(255, 255, 255),
		},
		FillLight = {
			Offset     = Vector3.new(-10, 6, 8),
			Brightness = 1.0,
			Range      = 35,
			Color      = Color3.fromRGB(220, 230, 255),
		},
		BackLight = {
			Offset     = Vector3.new(0, 8, -12),
			Brightness = 1.2,
			Range      = 35,
			Color      = Color3.fromRGB(255, 240, 230),
		},
	},

	-- Thư mục gốc chứa model preview theo kiến trúc dự án
	PreviewFolderNames = {
		Icicle = "Icicles",
		Block  = "Blocks",
		Chest  = "Chests",
	},
}

return IconPipelineConfig
