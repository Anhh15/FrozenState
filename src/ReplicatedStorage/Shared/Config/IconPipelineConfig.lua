-- IconPipelineConfig.lua
-- Cấu hình tập trung cho Pipeline tự động hóa tạo Icon 2D từ Model 3D trong Roblox Studio
-- Tách biệt hoàn toàn tham số, tuyệt đối không hardcode trong script logic

local IconPipelineConfig = {
	-- Endpoint HTTP kết nối tới Python Local Worker
	ServerUrl = "http://127.0.0.1:5000/capture",

	-- Vị trí đặt Buồng Chụp (Photo Studio Box) - biệt lập hoàn toàn khỏi Map
	StudioBoxPosition = Vector3.new(0, 100000, 0),

	-- Kích thước buồng chụp hộp kín (mở rộng để tường cách xa tâm, triệt tiêu bounce light)
	StudioBoxSize = Vector3.new(120, 120, 120),

	-- Vật liệu của các vách buồng chụp (SmoothPlastic loại bỏ phản xạ nhám không mong muốn)
	BoxMaterial = Enum.Material.SmoothPlastic,

	-- Tấm phông phẳng độc lập đặt sau lưng Item theo góc nhìn của Camera (loại bỏ nẹp góc tường)
	Backdrop = {
		Distance = 35,                     -- Khoảng cách sau lưng model (studs)
		Size     = Vector3.new(80, 80, 2), -- Kích thước tấm phông che kín FOV camera
	},

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

	-- Cấu hình hệ thống đèn SpotLight định hướng gom chùm sáng, có tự đổ bóng (Self-Shadowing)
	Lighting = {
		AmbientLightColor = Color3.fromRGB(200, 200, 200),
		KeyLight = {
			Name       = "KeyLight",
			Offset     = Vector3.new(8, 10, 12),
			Brightness = 2,
			Range      = 25,
			Angle      = 60,
			Color      = Color3.fromRGB(255, 255, 255),
			Shadows    = true,
		},
		FillLight = {
			Name       = "FillLight",
			Offset     = Vector3.new(-10, 5, 8),
			Brightness = 0.8,
			Range      = 22,
			Angle      = 70,
			Color      = Color3.fromRGB(210, 225, 255),
			Shadows    = false,
		},
		BackLight = {
			Name       = "BackLight",
			Offset     = Vector3.new(0, 8, -12),
			Brightness = 1.0,
			Range      = 22,
			Angle      = 65,
			Color      = Color3.fromRGB(255, 245, 235),
			Shadows    = false,
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
