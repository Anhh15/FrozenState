-- DataConfig.lua
-- Tham số cấu hình tập trung cho hệ thống dữ liệu người chơi (DataStore & ProfileService)
-- Chỉnh sửa tại đây để điều chỉnh thời gian chờ, số lần thử lại mà không hardcode trong service/controller

local DataConfig = {

	-- =========================================================
	-- PROFILE STORE CONFIGURATION
	-- =========================================================
	ProfileStoreName = "PlayerData_v1",

	-- =========================================================
	-- TIMEOUTS & RETRIES (đơn vị: giây)
	-- =========================================================
	ProfileLoadTimeout = 10,   -- Thời gian tối đa Server yield chờ ProfileService nạp xong Profile
	ClientLoadTimeout  = 10,   -- Thời gian tối đa Client yield chờ dữ liệu từ Server
	MaxLoadRetries     = 3,    -- Số lần tối đa Client thử lại nếu InvokeServer bị lỗi mạng
	RetryDelay         = 1,    -- Khoảng thời gian nghỉ giữa các lần thử lại

	-- =========================================================
	-- THIẾT LẬP MẶC ĐỊNH CHO NGƯỜI CHƠI MỚI (SETTINGS)
	-- =========================================================
	DefaultSettings = {
		MasterVolume = 100,
		MusicVolume  = 100,
		SFXVolume    = 100,
		UIVolume     = 100,
	},

}

return DataConfig
