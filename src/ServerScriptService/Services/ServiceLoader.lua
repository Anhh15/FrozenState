-- ServiceLoader.lua
-- Khởi tạo và chạy tất cả server service theo thứ tự ưu tiên
-- Thêm service mới vào danh sách SERVICES bên dưới, theo thứ tự dependency

local RunService = game:GetService("RunService")

assert(RunService:IsServer(), "ServiceLoader chỉ được chạy trên Server")

-- =========================================================
-- DANH SÁCH SERVICE — Thứ tự quan trọng! Dependency trước
-- =========================================================

local SERVICES = {
	-- DataService phải lên đầu tiên vì các service khác phụ thuộc vào nó
	require(script.Parent.DataService),

	-- Thêm service mới ở đây theo thứ tự:
	-- require(script.Parent.MatchService),
	-- require(script.Parent.TeamService),
	-- ...
}

-- =========================================================
-- KHỞI TẠO
-- =========================================================

local ServiceLoader = {}

function ServiceLoader.LoadAll()
	-- Pha 1: Init tất cả (setup nội bộ, không gọi service khác)
	for _, Service in ipairs(SERVICES) do
		if type(Service.Init) == "function" then
			local Success, Error = pcall(function()
				Service:Init()
			end)
			if not Success then
				error(("[ServiceLoader] Init thất bại: %s"):format(tostring(Error)))
			end
		end
	end

	-- Pha 2: Start tất cả (có thể gọi sang service khác vì Init đã xong hết)
	for _, Service in ipairs(SERVICES) do
		if type(Service.Start) == "function" then
			local Success, Error = pcall(function()
				Service:Start()
			end)
			if not Success then
				warn(("[ServiceLoader] Start thất bại: %s"):format(tostring(Error)))
			end
		end
	end

	print(("[ServiceLoader] Đã khởi động %d service."):format(#SERVICES))
end

return ServiceLoader
