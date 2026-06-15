-- RarityConfig.lua
-- Tập trung toàn bộ tham số hiển thị theo Rarity cho ItemFrame trong GUI
-- Không hardcode ImageId hay màu sắc trực tiếp trong logic code
-- Thêm rarity mới: thêm entry tại đây + đảm bảo GameConfig.Rarity cũng có entry tương ứng

-- ImageId placeholder: thay bằng Roblox Asset Id thực khi có asset đã upload
-- Ví dụ: "rbxassetid://12345678"

local RarityConfig = {
	Common = {
		Color   = Color3.fromHex("FFFFFF"),  -- Trắng
		ImageId = "rbxassetid://96508573886609",          -- TODO: thay bằng asset id thực
	},
	Uncommon = {
		Color   = Color3.fromHex("00FF00"),  -- Xanh lam
		ImageId = "rbxassetid://121610238787098",          -- TODO: thay bằng asset id thực
	},
	Rare = {
		Color   = Color3.fromHex("009DFF"),  -- Xanh lam
		ImageId = "rbxassetid://124396943640656",          -- TODO: thay bằng asset id thực
	},
	Epic = {
		Color   = Color3.fromHex("FF9500"),  -- Tím
		ImageId = "rbxassetid://114882765110778",          -- TODO: thay bằng asset id thực
	},
	Legendary = {
		Color   = Color3.fromHex("FF0000"),  -- Vàng
		ImageId = "rbxassetid://79785654239789",          -- TODO: thay bằng asset id thực
	},
}

return RarityConfig
