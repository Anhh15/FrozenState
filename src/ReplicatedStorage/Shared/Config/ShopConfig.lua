-- ShopConfig.lua
-- Tham số cấu hình cho Shop UI (client-side)
-- Chỉnh sửa các giá trị tại đây để điều chỉnh hành vi Shop mà không cần sửa code

local ShopConfig = {}

-- =========================================================
-- LAZY RENDER
-- =========================================================

--- Khoảng đệm (pixel) pre-load card trước khi card thực sự hiện ra trong vùng nhìn thấy.
--- Tăng giá trị này nếu muốn load sớm hơn, giảm nếu muốn tiết kiệm tài nguyên hơn.
ShopConfig.LazyRenderBuffer = 100

-- =========================================================
-- AMOUNT ALTER BUTTON
-- =========================================================

--- Số lượng tối thiểu có thể mua mỗi lần
ShopConfig.MinAmount = 1

--- Số lượng tối đa có thể mua mỗi lần
ShopConfig.MaxAmount = 5

return ShopConfig
