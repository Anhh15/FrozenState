-- TagHelper.lua
-- Module tiện ích dùng chung (Shared) cho Client & Server để gắn và theo dõi CollectionService Tags
-- Sử dụng TagConfig làm Single Source of Truth

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TagConfig         = require(ReplicatedStorage.Shared.Config.TagConfig)

local TagHelper = {}

-- =========================================================
-- TAG MUTATIONS
-- =========================================================

--- Gắn tag cho một Instance
--- @param TargetInstance Instance?
--- @param TagName string
function TagHelper.AddTag(TargetInstance, TagName)
	if not TargetInstance or not TagName then return end
	CollectionService:AddTag(TargetInstance, TagName)
end

--- Gỡ tag khỏi một Instance
--- @param TargetInstance Instance?
--- @param TagName string
function TagHelper.RemoveTag(TargetInstance, TagName)
	if not TargetInstance or not TagName then return end
	CollectionService:RemoveTag(TargetInstance, TagName)
end

--- Kiểm tra xem Instance có chứa tag hay không
--- @param TargetInstance Instance?
--- @param TagName string
--- @return boolean
function TagHelper.HasTag(TargetInstance, TagName)
	if not TargetInstance or not TagName then return false end
	return CollectionService:HasTag(TargetInstance, TagName)
end

--- Lấy danh sách tất cả Instance đang có tag
--- @param TagName string
--- @return table -- { Instance, ... }
function TagHelper.GetTagged(TagName)
	if not TagName then return {} end
	return CollectionService:GetTagged(TagName)
end

-- =========================================================
-- TAG OBSERVERS
-- =========================================================

--- Lắng nghe sự kiện khi một Instance được gắn tag
--- Tự động gọi callback cho tất cả Instance đã có tag từ trước
--- @param TagName string
--- @param Callback (Instance: Instance) -> ()
--- @return RBXScriptConnection?
function TagHelper.ObserveTagAdded(TagName, Callback)
	if not TagName or not Callback then return nil end

	-- Lắng nghe các instance mới được gán tag
	local Connection = CollectionService:GetInstanceAddedSignal(TagName):Connect(Callback)

	-- Gọi callback cho các instance đã tồn tại sẵn
	for _, ExistingInstance in ipairs(CollectionService:GetTagged(TagName)) do
		task.spawn(Callback, ExistingInstance)
	end

	return Connection
end

--- Lắng nghe sự kiện khi một Instance bị gỡ tag
--- @param TagName string
--- @param Callback (Instance: Instance) -> ()
--- @return RBXScriptConnection?
function TagHelper.ObserveTagRemoved(TagName, Callback)
	if not TagName or not Callback then return nil end
	return CollectionService:GetInstanceRemovedSignal(TagName):Connect(Callback)
end

return TagHelper
