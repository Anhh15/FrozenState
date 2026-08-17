-- AudioHelper.lua
-- Module tiện ích dùng chung (Shared) cho Client & Server để phát và quản lý vòng đời âm thanh
-- Đảm bảo tự động dọn dẹp Sound instance (chống memory leak) và tối ưu độ trễ âm thanh

local SoundService    = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players         = game:GetService("Players")

local AudioConfig     = require(ReplicatedStorage.Shared.Config.AudioConfig)

local AudioHelper = {}

-- Sound Pool tĩnh dùng lại cho các âm thanh 2D / GUI thường phát nhiều lần
local _guiSoundPool = {}

-- =========================================================
-- 2D AUDIO (GUI / MUSIC / NOTIFICATION)
-- =========================================================

--- Phát âm thanh 2D (không phụ thuộc vị trí không gian)
--- Tự động dọn dẹp khi âm thanh kết thúc
--- @param SoundId number | string
--- @param Volume number? -- Mặc định là 1
--- @param Parent Instance? -- Mặc định là SoundService hoặc PlayerGui
--- @return Sound?
function AudioHelper.Play2DSound(SoundId, Volume, Parent)
	if not SoundId then return nil end

	local Sound = Instance.new("Sound")
	Sound.Name = "SFX_2D_" .. tostring(SoundId)
	Sound.SoundId = "rbxassetid://" .. tostring(SoundId)
	Sound.Volume = Volume or 1

	local TargetParent = Parent or SoundService
	if not TargetParent then
		local LocalPlayer = Players.LocalPlayer
		TargetParent = (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")) or SoundService
	end
	Sound.Parent = TargetParent

	Sound.Ended:Once(function()
		Sound:Destroy()
	end)

	-- Fallback dọn dẹp phòng trường hợp Sound bị kẹt hoặc ngắt ngang
	task.delay(10, function()
		if Sound and Sound.Parent then
			Sound:Destroy()
		end
	end)

	Sound:Play()
	return Sound
end

--- Phát âm thanh GUI bằng cơ chế Sound Pool tái sử dụng để triệt tiêu độ trễ và không tạo rác bộ nhớ
--- @param SoundId number | string
--- @param Volume number?
--- @return Sound?
function AudioHelper.PlayGuiSound(SoundId, Volume)
	if not SoundId then return nil end

	local Sound = _guiSoundPool[SoundId]
	if not Sound or not Sound.Parent then
		Sound = Instance.new("Sound")
		Sound.Name = "SFX_GuiPool_" .. tostring(SoundId)
		Sound.SoundId = "rbxassetid://" .. tostring(SoundId)
		Sound.Parent = SoundService
		_guiSoundPool[SoundId] = Sound
	end

	Sound.Volume = Volume or 1
	Sound.TimePosition = 0
	Sound:Play()
	return Sound
end

-- =========================================================
-- 3D SPATIAL AUDIO (CHARACTER / WORLD / HITBOX)
-- =========================================================

--- Phát âm thanh 3D Spatial tại một BasePart / Model trong thế giới
--- Roblox tự động replicate Sound instance nếu tạo từ Server đến Client
--- @param ParentInstance Instance
--- @param SoundId number | string
--- @param Volume number? -- Mặc định là 1
--- @param MaxDistance number? -- Mặc định là 60 studs
--- @return Sound?
function AudioHelper.PlaySpatialSound(ParentInstance, SoundId, Volume, MaxDistance)
	if not ParentInstance or not SoundId then return nil end

	local TargetPart = ParentInstance
	if ParentInstance:IsA("Model") then
		TargetPart = ParentInstance.PrimaryPart or ParentInstance:FindFirstChildOfClass("BasePart")
	end

	if not TargetPart or not TargetPart:IsA("BasePart") then
		return nil
	end

	local Sound = Instance.new("Sound")
	Sound.Name = "SpatialSFX_" .. tostring(SoundId)
	Sound.SoundId = "rbxassetid://" .. tostring(SoundId)
	Sound.Volume = Volume or 1
	Sound.RollOffMaxDistance = MaxDistance or 60
	Sound.Parent = TargetPart

	Sound.Ended:Once(function()
		Sound:Destroy()
	end)

	-- Fallback dọn dẹp sau 8 giây
	task.delay(8, function()
		if Sound and Sound.Parent then
			Sound:Destroy()
		end
	end)

	Sound:Play()
	return Sound
end

-- =========================================================
-- SOUND POOLING (REUSABLE SOUNDS)
-- =========================================================

--- Tạo một bảng Sound Pool cố định trong Parent để tái sử dụng mà không tạo/xóa liên tục
--- @param ParentInstance Instance
--- @param AudioIds table -- { number, ... }
--- @param Config table? -- { Volume = 1, MaxDistance = 60 }
--- @return table -- { [AudioId] = Sound }
function AudioHelper.CreateSoundPool(ParentInstance, AudioIds, Config)
	if not ParentInstance or not AudioIds then return {} end

	local Pool = {}
	local Volume = (Config and Config.Volume) or 1
	local MaxDistance = (Config and Config.MaxDistance) or 60

	for _, AudioId in ipairs(AudioIds) do
		local Sound = Instance.new("Sound")
		Sound.Name = "PoolSFX_" .. tostring(AudioId)
		Sound.SoundId = "rbxassetid://" .. tostring(AudioId)
		Sound.Volume = Volume
		Sound.RollOffMaxDistance = MaxDistance
		Sound.Parent = ParentInstance
		Pool[AudioId] = Sound
	end

	return Pool
end

--- Phát một sound từ Sound Pool đã có sẵn
--- @param SoundInstance Sound?
function AudioHelper.PlayPooledSound(SoundInstance)
	if not SoundInstance or not SoundInstance.Parent then return end
	SoundInstance.TimePosition = 0
	SoundInstance:Play()
end

-- =========================================================
-- PRELOAD UTILITIES
-- =========================================================

--- Nạp trước danh sách Audio ID vào bộ nhớ Client
--- @param AudioIds table -- { number, ... }
function AudioHelper.PreloadAudios(AudioIds)
	if not AudioIds or #AudioIds == 0 then return end

	local InstancesToPreload = {}
	for _, AudioId in ipairs(AudioIds) do
		local Sound = Instance.new("Sound")
		Sound.SoundId = "rbxassetid://" .. tostring(AudioId)
		table.insert(InstancesToPreload, Sound)
	end

	pcall(function()
		ContentProvider:PreloadAsync(InstancesToPreload)
	end)

	for _, Sound in ipairs(InstancesToPreload) do
		Sound:Destroy()
	end
end

--- Nạp trước toàn bộ Audio trong game vào bộ nhớ Client để đảm bảo 0ms độ trễ
function AudioHelper.PreloadAllGameAudios()
	task.spawn(function()
		local AllAudioIds = AudioConfig.GetAllAudioIds()
		AudioHelper.PreloadAudios(AllAudioIds)
		print(string.format("[AudioHelper] Đã preload thành công %d asset âm thanh.", #AllAudioIds))
	end)
end

return AudioHelper
