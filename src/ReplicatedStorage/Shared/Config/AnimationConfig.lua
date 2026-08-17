-- AnimationConfig.lua
-- Cấu hình Animation và timing va chạm toàn game FrozenState
-- Hệ thống 2 tầng: Default (mặc định) + Overrides (theo SkinId của Icicle hoặc Block)
-- Nằm trong ReplicatedStorage để cả Server lẫn Client đều require được

local AnimationConfig = {

	-- =========================================================
	-- ANIMATION MẶC ĐỊNH
	-- Dùng khi item trang bị không có override riêng
	-- =========================================================
	Default = {
		-- Swing: Animation khi vung Icicle
		SwingAnimation = 128425806238119,

		-- Cửa sổ Hitbox active (giây) — khớp với giai đoạn 'vung' trong animation
		-- HitStartTime: thời điểm bắt đầu đập xuống | HitEndTime: thời điểm tay chạm đáy
		HitStartTime   = 0.25,
		HitEndTime     = 0.33,

		-- Pose: Animation của nạn nhân khi bị đóng băng
		PoseAnimation  = 127604545127643,
	},

	-- =========================================================
	-- OVERRIDE THEO SKIN
	-- Key là SkinId của Icicle hoặc Block (vd: "GoldenIcicle", "CrystalBlock")
	-- Chỉ cần khai báo trường cần ghi đè
	--
	-- Icicle skin ghi đè:  SwingAnimation, HitStartTime, HitEndTime
	-- Block skin ghi đè:   PoseAnimation
	-- =========================================================
	Overrides = {
		-- Ví dụ:
		-- ["GoldenIcicle"] = {
		--     SwingAnimation = 444444444,
		--     HitStartTime   = 0.2,
		--     HitEndTime     = 0.4,
		-- },
		-- ["CrystalBlock"] = {
		--     PoseAnimation  = 777777777,
		-- },
	},

}

-- =========================================================
-- PUBLIC GETTERS
-- =========================================================

--- Lấy animation swing theo SkinId (Icicle)
--- @param IcicleSkinId string?
--- @return number
function AnimationConfig.GetSwingAnimation(IcicleSkinId)
	local Override = IcicleSkinId and AnimationConfig.Overrides[IcicleSkinId]
	if Override and Override.SwingAnimation then
		return Override.SwingAnimation
	end
	return AnimationConfig.Default.SwingAnimation
end

--- Lấy thời điểm bắt đầu cửa sổ Hitbox theo SkinId (Icicle)
--- @param IcicleSkinId string?
--- @return number
function AnimationConfig.GetHitStartTime(IcicleSkinId)
	local Override = IcicleSkinId and AnimationConfig.Overrides[IcicleSkinId]
	if Override and Override.HitStartTime then
		return Override.HitStartTime
	end
	return AnimationConfig.Default.HitStartTime
end

--- Lấy thời điểm kết thúc cửa sổ Hitbox theo SkinId (Icicle)
--- @param IcicleSkinId string?
--- @return number
function AnimationConfig.GetHitEndTime(IcicleSkinId)
	local Override = IcicleSkinId and AnimationConfig.Overrides[IcicleSkinId]
	if Override and Override.HitEndTime then
		return Override.HitEndTime
	end
	return AnimationConfig.Default.HitEndTime
end

--- Lấy pose animation theo SkinId (Block)
--- @param BlockSkinId string?
--- @return number
function AnimationConfig.GetPoseAnimation(BlockSkinId)
	local Override = BlockSkinId and AnimationConfig.Overrides[BlockSkinId]
	if Override and Override.PoseAnimation then
		return Override.PoseAnimation
	end
	return AnimationConfig.Default.PoseAnimation
end

--- Thu thập tất cả Animation ID trong config để preload vào RAM
--- @return table -- { number, ... }
function AnimationConfig.GetAllAnimationIds()
	local AnimIdSet = {}
	local AnimIdList = {}

	local function AddId(Id)
		if type(Id) == "number" and not AnimIdSet[Id] then
			AnimIdSet[Id] = true
			table.insert(AnimIdList, Id)
		end
	end

	if AnimationConfig.Default.SwingAnimation then
		AddId(AnimationConfig.Default.SwingAnimation)
	end
	if AnimationConfig.Default.PoseAnimation then
		AddId(AnimationConfig.Default.PoseAnimation)
	end

	for _, Override in pairs(AnimationConfig.Overrides) do
		if Override.SwingAnimation then
			AddId(Override.SwingAnimation)
		end
		if Override.PoseAnimation then
			AddId(Override.PoseAnimation)
		end
	end

	return AnimIdList
end

return AnimationConfig
