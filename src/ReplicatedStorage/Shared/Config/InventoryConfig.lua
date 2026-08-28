-- InventoryConfig.lua
-- Tham số cấu hình cho Inventory UI (client-side)
-- Chỉnh sửa các giá trị tại đây để điều chỉnh hành vi Inventory mà không cần sửa code

local InventoryConfig = {}

-- =========================================================
-- LAZY RENDER
-- =========================================================

--- Khoảng đệm (pixel) pre-load item card trước khi card thực sự hiện ra trong vùng nhìn thấy.
--- Tăng giá trị này nếu muốn load sớm hơn, giảm nếu muốn tiết kiệm tài nguyên hơn.
InventoryConfig.LazyRenderBuffer = 100

return InventoryConfig
