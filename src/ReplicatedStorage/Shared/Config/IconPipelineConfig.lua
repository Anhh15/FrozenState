-- IconPipelineConfig.lua
-- Cấu hình tập trung cho Pipeline tự động hóa tạo Icon 2D từ Model 3D trong Roblox Studio qua GUI ViewportFrame
-- Tách biệt hoàn toàn tham số, tuyệt đối không hardcode trong script logic

local IconPipelineConfig = {
	-- Endpoint HTTP kết nối tới Python Local Worker
	ServerUrl = "http://127.0.0.1:5000/capture",

	-- Cấu hình buồng chụp ScreenGui ViewportFrame
	GuiConfig = {
		ScreenGuiName = "IconCaptureGui",
		ViewportSize  = Vector2.new(500, 500), -- Kích thước pixel vuông 1:1 chuẩn xác
		DisplayOrder  = 999999,               -- Luôn nằm trên tất cả UI game khác
	},

	-- Màu sắc cho 2 pha chụp Dual-Shot Matte
	BackgroundColors = {
		Black = Color3.new(0, 0, 0),
		White = Color3.new(1, 1, 1),
	},

	-- Thời gian chờ (giây) giữa các thao tác để Roblox Studio hoàn tất vẽ frame
	RenderDelays = {
		AfterColorChange = 0.25, -- Thời gian đệm tối thiểu sau khi đổi màu
		AfterModelLoaded = 0.35, -- Thời gian đệm tối thiểu sau khi nạp model
		BetweenItems     = 0.25, -- Giãn cách giữa 2 item liên tiếp
	},

	-- Số nhịp frame Engine (RenderStepped/Heartbeat) chờ GPU flush hoàn tất
	RenderWarmupFrames = {
		AfterModelLoaded = 5,
		AfterColorChange = 3,
	},

	-- Bật gửi kèm tọa độ tuyệt đối của ViewportFrame để Python crop chuẩn xác
	SendViewportBounds = true,

	-- Thư mục gốc chứa model preview theo kiến trúc dự án
	PreviewFolderNames = {
		Icicle = "Icicles",
		Block  = "Blocks",
		Chest  = "Chests",
	},
}

return IconPipelineConfig
