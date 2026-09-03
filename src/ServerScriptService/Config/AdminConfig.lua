-- AdminConfig.lua
-- Cấu hình tập trung cho hệ thống quản trị và kiểm thử (Admin CLI & Live Operations)
-- Chỉnh sửa tại đây để thêm/bớt Admin UserIds hoặc thay đổi tiền tố lệnh mà không cần sửa Service

local RunService = game:GetService("RunService")

local AdminConfig = {

	-- =========================================================
	-- TIỀN TỐ LỆNH (COMMAND PREFIX)
	-- =========================================================
	Prefix = "//",

	-- =========================================================
	-- DANH SÁCH QUẢN TRỊ VIÊN (ADMIN USER IDS)
	-- Cấu trúc: [UserId] = "Role" ("Owner" | "Admin" | "Moderator")
	-- =========================================================
	AdminUserIds = {
		[10992501899] = "Owner",
		[-1] = "Owner",
		-- Ví dụ: [12345678] = "Owner",
	},

}

-- =========================================================
-- PUBLIC HELPERS
-- =========================================================

--- Kiểm tra một người chơi có quyền Admin hay không
--- Mặc định luôn cấp quyền khi chạy trong môi trường Roblox Studio
--- @param Player Player
--- @return boolean
function AdminConfig.IsAdmin(Player)
	if not Player then return false end
	if RunService:IsStudio() then
		return true
	end
	return AdminConfig.AdminUserIds[Player.UserId] ~= nil
end

--- Lấy quyền (Role) của người chơi
--- @param Player Player
--- @return string?
function AdminConfig.GetRole(Player)
	if not Player then return nil end
	if RunService:IsStudio() then
		return "Owner"
	end
	return AdminConfig.AdminUserIds[Player.UserId]
end

return AdminConfig
