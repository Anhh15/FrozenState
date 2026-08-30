-- ProductConfig.lua
-- Cấu hình tập trung toàn bộ sản phẩm mua bằng Robux (Developer Products & GamePasses)
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local ProductConfig = {

	-- =========================================================
	-- CÁC GÓI TIỀN TỆ (DEVELOPER PRODUCTS)
	-- =========================================================
	CurrencyPackages = {
		Small1 = {
			ProductId      = 3710587351,
			DisplayName    = "A FEW",
			RobuxPrice     = 100,
			CurrencyAmount = 10000,
		},
		Small2 = {
			ProductId      = 3710587516,
			DisplayName    = "A COUPLE",
			RobuxPrice     = 100,
			CurrencyAmount = 20000,
		},
		Small3 = {
			ProductId      = 3710587570,
			DisplayName    = "A BUNCH",
			RobuxPrice     = 100,
			CurrencyAmount = 30000,
		},
		Small4 = {
			ProductId      = 3710587643,
			DisplayName    = "A LOT",
			RobuxPrice     = 100,
			CurrencyAmount = 40000,
		},
		Medium = {
			ProductId      = 3710587681,
			DisplayName    = "A CART FULL!",
			RobuxPrice     = 100,
			CurrencyAmount = 50000,
		},
		Large = {
			ProductId      = 3710587730,
			DisplayName    = "A CAVE FULL!",
			RobuxPrice     = 100,
			CurrencyAmount = 60000,
		},
	},

}

-- =========================================================
-- PUBLIC GETTERS
-- =========================================================

--- Tra cứu gói tiền tệ theo ProductId
--- @param ProductId number
--- @return table?, string? -- (PackageEntry, PackageKey)
function ProductConfig.GetPackageByProductId(ProductId)
	if not ProductId then return nil, nil end
	for Key, Package in pairs(ProductConfig.CurrencyPackages) do
		if Package.ProductId == ProductId then
			return Package, Key
		end
	end
	return nil, nil
end

return ProductConfig
