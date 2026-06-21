-- RarityConfig.lua
-- Tập trung toàn bộ tham số hiển thị theo Rarity cho ItemFrame trong GUI
-- Không hardcode ImageId hay màu sắc trực tiếp trong logic code
-- Thêm rarity mới: thêm entry tại đây + đảm bảo GameConfig.Rarity cũng có entry tương ứng

-- ImageId placeholder: thay bằng Roblox Asset Id thực khi có asset đã upload
-- Ví dụ: "rbxassetid://12345678"

local RarityConfig = {
	Common = {
		Color         = Color3.fromHex("FFFFFF"),  -- Trắng
		ImageId       = "rbxassetid://96508573886609",
		RefundPercent = 0.10,  -- Hoàn 10% giá rương khi trùng
	},
	Uncommon = {
		Color         = Color3.fromHex("00FF00"),  -- Xanh lá
		ImageId       = "rbxassetid://121610238787098",
		RefundPercent = 0.15,  -- Hoàn 15% giá rương khi trùng
	},
	Rare = {
		Color         = Color3.fromHex("009DFF"),  -- Xanh lam
		ImageId       = "rbxassetid://124396943640656",
		RefundPercent = 0.20,  -- Hoàn 20% giá rương khi trùng
	},
	Epic = {
		Color         = Color3.fromHex("FF9500"),  -- Cam
		ImageId       = "rbxassetid://114882765110778",
		RefundPercent = 0.30,  -- Hoàn 30% giá rương khi trùng
	},
	Legendary = {
		Color         = Color3.fromHex("FF0000"),  -- Đỏ
		ImageId       = "rbxassetid://79785654239789",
		RefundPercent = 0.50,  -- Hoàn 50% giá rương khi trùng
	},
}

return RarityConfig
