-- AnimationHelper.lua
-- Module tiện ích dùng chung (Shared) cho Client & Server để quản lý vòng đời và nạp AnimationTrack
-- Luôn sử dụng Animator:LoadAnimation thay vì Humanoid:LoadAnimation (deprecated)
-- Đảm bảo quản lý Track an toàn và tránh rò rỉ bộ nhớ (Memory Leaks)

local ContentProvider = game:GetService("ContentProvider")

local AnimationHelper = {}

-- =========================================================
-- ANIMATOR RESOLUTION
-- =========================================================

--- Tìm hoặc khởi tạo Animator bên trong Humanoid của Character
--- @param CharacterOrHumanoid Instance
--- @return Animator?
function AnimationHelper.GetAnimator(CharacterOrHumanoid)
	if not CharacterOrHumanoid then return nil end

	local Humanoid = nil
	if CharacterOrHumanoid:IsA("Humanoid") then
		Humanoid = CharacterOrHumanoid
	elseif CharacterOrHumanoid:IsA("Model") then
		Humanoid = CharacterOrHumanoid:FindFirstChildOfClass("Humanoid")
	end

	if not Humanoid then return nil end

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end

	return Animator
end

-- =========================================================
-- TRACK MANAGEMENT
-- =========================================================

--- Nạp một AnimationTrack an toàn lên Animator
--- Tự động dọn dẹp instance Animation tạm sau khi load
--- @param CharacterOrHumanoid Instance
--- @param AnimationId number | string
--- @param Options table? -- { Looped: boolean?, Priority: Enum.AnimationPriority?, Speed: number? }
--- @return AnimationTrack?
function AnimationHelper.LoadTrack(CharacterOrHumanoid, AnimationId, Options)
	if not CharacterOrHumanoid or not AnimationId then return nil end

	local Animator = AnimationHelper.GetAnimator(CharacterOrHumanoid)
	if not Animator then return nil end

	local Anim = Instance.new("Animation")
	Anim.AnimationId = "rbxassetid://" .. tostring(AnimationId)

	local Success, Track = pcall(function()
		return Animator:LoadAnimation(Anim)
	end)

	Anim:Destroy()

	if not Success or not Track then
		warn(("[AnimationHelper] Lỗi khi load animation '%s'"):format(tostring(AnimationId)))
		return nil
	end

	if Options then
		if Options.Looped ~= nil then
			Track.Looped = Options.Looped
		end
		if Options.Priority ~= nil then
			Track.Priority = Options.Priority
		end
		if Options.Speed ~= nil then
			Track:AdjustSpeed(Options.Speed)
		end
	end

	return Track
end

--- Phát một AnimationTrack an toàn
--- @param Track AnimationTrack?
--- @param FadeTime number?
--- @param Weight number?
--- @param Speed number?
function AnimationHelper.PlayTrack(Track, FadeTime, Weight, Speed)
	if not Track then return end
	Track:Play(FadeTime, Weight, Speed)
end

--- Dừng và giải phóng một AnimationTrack
--- @param Track AnimationTrack?
--- @param FadeTime number?
function AnimationHelper.StopTrack(Track, FadeTime)
	if not Track then return end
	Track:Stop(FadeTime)
	pcall(function()
		Track:Destroy()
	end)
end

-- =========================================================
-- PRELOAD UTILITIES
-- =========================================================

--- Nạp trước danh sách Animation ID vào bộ nhớ Client
--- @param AnimIds table -- { number, ... }
function AnimationHelper.PreloadAnimations(AnimIds)
	if not AnimIds or #AnimIds == 0 then return end

	local InstancesToPreload = {}
	for _, AnimId in ipairs(AnimIds) do
		local Anim = Instance.new("Animation")
		Anim.AnimationId = "rbxassetid://" .. tostring(AnimId)
		table.insert(InstancesToPreload, Anim)
	end

	pcall(function()
		ContentProvider:PreloadAsync(InstancesToPreload)
	end)

	for _, Anim in ipairs(InstancesToPreload) do
		Anim:Destroy()
	end
end

return AnimationHelper
