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

	-- =========================================================
	-- CÁC GÓI GAMEPASS (GAMEPASSES)
	-- =========================================================
	GamePasses = {
		DoubleMatchMoney = {
			PassId     = 1966153598,   -- Roblox GamePass Id (điền Id thật tại đây)
			RobuxPrice = 199, -- Giá Robux dự phòng khi chưa tải được từ MarketplaceService
			Multiplier = 2,   -- Hệ số nhân đôi tiền thưởng trận đấu
		},
		UpgradeDailyQuests = {
			PassId      = 1967652369,   -- Roblox GamePass Id (điền Id thật tại đây)
			RobuxPrice  = 149, -- Giá Robux dự phòng khi chưa tải được từ MarketplaceService
			ExtraSlots  = 2,   -- Số lượng quest daily cộng thêm (5 -> 7)
			RewardBonus = 0.5, -- Thưởng thêm +50% tiền khi claim quest daily
			DailyResets = 1,   -- Số lần được phép làm mới toàn bộ quest daily mỗi ngày
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

--- Tra cứu GamePass theo Key
--- @param PassKey string -- "DoubleMatchMoney" | "UpgradeDailyQuests"
--- @return table?
function ProductConfig.GetGamePassByKey(PassKey)
	if not PassKey then return nil end
	return ProductConfig.GamePasses[PassKey]
end

--- Tra cứu GamePass theo PassId
--- @param PassId number
--- @return table?, string? -- (PassEntry, PassKey)
function ProductConfig.GetGamePassById(PassId)
	if not PassId or PassId <= 0 then return nil, nil end
	for Key, PassEntry in pairs(ProductConfig.GamePasses) do
		if PassEntry.PassId == PassId then
			return PassEntry, Key
		end
	end
	return nil, nil
end

return ProductConfig
