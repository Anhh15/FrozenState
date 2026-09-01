-- AudioHelper.lua
-- Module tiện ích dùng chung (Shared) cho Client & Server để phát và quản lý vòng đời âm thanh
-- Đảm bảo tự động dọn dẹp Sound instance (chống memory leak), hỗ trợ AudioEntry đa hình và tối ưu độ trễ

local SoundService    = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players         = game:GetService("Players")

local AudioConfig     = require(ReplicatedStorage.Shared.Config.AudioConfig)

local AudioHelper = {}

-- Sound Pool tĩnh dùng lại cho các âm thanh 2D / GUI thường phát nhiều lần
local _guiSoundPool = {}

-- =========================================================
-- SOUND GROUPS (MASTER, MUSIC, SFX, UI)
-- =========================================================

local _soundGroups = {}

--- Đảm bảo cây SoundGroup đã được tạo trong SoundService
local function EnsureSoundGroups()
	if _soundGroups.Master and _soundGroups.Master.Parent then return end

	local Master = SoundService:FindFirstChild("MasterGroup")
	if not Master then
		Master = Instance.new("SoundGroup")
		Master.Name = "MasterGroup"
		Master.Volume = 1
		Master.Parent = SoundService
	end

	local Music = Master:FindFirstChild("MusicGroup")
	if not Music then
		Music = Instance.new("SoundGroup")
		Music.Name = "MusicGroup"
		Music.Volume = 1
		Music.Parent = Master
	end

	local SFX = Master:FindFirstChild("SFXGroup")
	if not SFX then
		SFX = Instance.new("SoundGroup")
		SFX.Name = "SFXGroup"
		SFX.Volume = 1
		SFX.Parent = Master
	end

	local UI = Master:FindFirstChild("UIGroup")
	if not UI then
		UI = Instance.new("SoundGroup")
		UI.Name = "UIGroup"
		UI.Volume = 1
		UI.Parent = Master
	end

	_soundGroups.Master = Master
	_soundGroups.Music  = Music
	_soundGroups.SFX    = SFX
	_soundGroups.UI     = UI
end

--- Lấy đối tượng SoundGroup theo tên
--- @param GroupName string -- "Master" | "Music" | "SFX" | "UI"
--- @return SoundGroup?
function AudioHelper.GetSoundGroup(GroupName)
	EnsureSoundGroups()
	return _soundGroups[GroupName]
end

--- Cập nhật âm lượng cho một kênh SoundGroup (0 -> 100%)
--- @param GroupName string -- "Master" | "Music" | "SFX" | "UI"
--- @param VolumePercent number -- 0 đến 100
function AudioHelper.SetVolume(GroupName, VolumePercent)
	EnsureSoundGroups()
	local Group = _soundGroups[GroupName]
	if Group and type(VolumePercent) == "number" then
		Group.Volume = math.clamp(VolumePercent / 100, 0, 1)
	end
end

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Phân giải đầu vào đa hình (AudioEntry table hoặc SoundId thuần)
--- @param Input table | number | string
--- @param OverrideVolume number?
--- @param OverrideMaxDistance number?
--- @return number | string | nil, number, number
local function ResolveAudioEntry(Input, OverrideVolume, OverrideMaxDistance)
	if not Input then return nil, 1, 60 end

	local SoundId = nil
	local Volume = OverrideVolume
	local MaxDistance = OverrideMaxDistance

	if type(Input) == "table" then
		if Input.Id then
			SoundId = Input.Id
		elseif type(Input.Ids) == "table" and #Input.Ids > 0 then
			SoundId = Input.Ids[math.random(1, #Input.Ids)]
		end
		Volume = Volume or Input.Volume or 1
		MaxDistance = MaxDistance or Input.MaxDistance or 60
	else
		SoundId = Input
		Volume = Volume or 1
		MaxDistance = MaxDistance or 60
	end

	return SoundId, Volume, MaxDistance
end

-- =========================================================
-- 2D AUDIO (GUI / MUSIC / NOTIFICATION)
-- =========================================================

--- Phát âm thanh 2D (không phụ thuộc vị trí không gian)
--- Tự động dọn dẹp khi âm thanh kết thúc
--- @param AudioEntryOrId table | number | string
--- @param VolumeOverride number? -- Ghi đè âm lượng tùy chọn
--- @param Parent Instance? -- Mặc định là SoundService hoặc PlayerGui
--- @param SoundGroupName string? -- "UI" | "SFX" | "Music" (mặc định "SFX")
--- @return Sound?
function AudioHelper.Play2DSound(AudioEntryOrId, VolumeOverride, Parent, SoundGroupName)
	local SoundId, Volume = ResolveAudioEntry(AudioEntryOrId, VolumeOverride)
	if not SoundId then return nil end

	EnsureSoundGroups()

	local Sound = Instance.new("Sound")
	Sound.Name = "SFX_2D_" .. tostring(SoundId)
	Sound.SoundId = "rbxassetid://" .. tostring(SoundId)
	Sound.Volume = Volume
	Sound.SoundGroup = _soundGroups[SoundGroupName or "SFX"] or _soundGroups.SFX

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

-- Bảng lưu mốc thời gian phát âm thanh gần nhất để throttle (chống spam)
local _LastSoundPlayTimes = {}

--- Phát âm thanh GUI bằng cơ chế Sound Pool tái sử dụng để triệt tiêu độ trễ và không tạo rác bộ nhớ
--- @param AudioEntryOrId table | number | string
--- @param VolumeOverride number?
--- @return Sound?
function AudioHelper.PlayGuiSound(AudioEntryOrId, VolumeOverride)
	local SoundId, Volume = ResolveAudioEntry(AudioEntryOrId, VolumeOverride)
	if not SoundId then return nil end

	EnsureSoundGroups()

	local Sound = _guiSoundPool[SoundId]
	if not Sound or not Sound.Parent then
		Sound = Instance.new("Sound")
		Sound.Name = "SFX_GuiPool_" .. tostring(SoundId)
		Sound.SoundId = "rbxassetid://" .. tostring(SoundId)
		Sound.SoundGroup = _soundGroups.UI
		Sound.Parent = SoundService
		_guiSoundPool[SoundId] = Sound
	else
		Sound.SoundGroup = _soundGroups.UI
	end

	Sound.Volume = Volume
	Sound.TimePosition = 0
	Sound:Play()
	return Sound
end

--- Phát âm thanh GUI với cơ chế giới hạn tần suất (Throttle) để chống spam âm thanh khi lướt chuột nhanh
--- @param AudioEntryOrId table | number | string
--- @param ThrottleInterval number? Khoảng cách tối thiểu giữa 2 lần phát (giây)
--- @param VolumeOverride number?
--- @return Sound?
function AudioHelper.PlayThrottledGuiSound(AudioEntryOrId, ThrottleInterval, VolumeOverride)
	if not AudioEntryOrId then return nil end

	local SoundKey = (type(AudioEntryOrId) == "table" and AudioEntryOrId.Id) or tostring(AudioEntryOrId)
	local DefaultThrottle = (AudioConfig.Gui and AudioConfig.Gui.Default and AudioConfig.Gui.Default.HoverThrottle) or 0.045
	local MinInterval = ThrottleInterval or DefaultThrottle
	local Now = os.clock()

	local LastTime = _LastSoundPlayTimes[SoundKey] or 0
	if Now - LastTime < MinInterval then
		return nil
	end

	_LastSoundPlayTimes[SoundKey] = Now
	return AudioHelper.PlayGuiSound(AudioEntryOrId, VolumeOverride)
end

-- =========================================================
-- 3D SPATIAL AUDIO (CHARACTER / WORLD / HITBOX)
-- =========================================================

--- Phát âm thanh 3D Spatial tại một BasePart / Model trong thế giới
--- Roblox tự động replicate Sound instance nếu tạo từ Server đến Client
--- @param ParentInstance Instance
--- @param AudioEntryOrId table | number | string
--- @param VolumeOverride number?
--- @param MaxDistanceOverride number?
--- @return Sound?
function AudioHelper.PlaySpatialSound(ParentInstance, AudioEntryOrId, VolumeOverride, MaxDistanceOverride)
	if not ParentInstance then return nil end

	local SoundId, Volume, MaxDistance = ResolveAudioEntry(AudioEntryOrId, VolumeOverride, MaxDistanceOverride)
	if not SoundId then return nil end

	local TargetPart = ParentInstance
	if ParentInstance:IsA("Model") then
		TargetPart = ParentInstance.PrimaryPart or ParentInstance:FindFirstChildOfClass("BasePart")
	end

	if not TargetPart or not TargetPart:IsA("BasePart") then
		return nil
	end

	EnsureSoundGroups()

	local Sound = Instance.new("Sound")
	Sound.Name = "SpatialSFX_" .. tostring(SoundId)
	Sound.SoundId = "rbxassetid://" .. tostring(SoundId)
	Sound.Volume = Volume
	Sound.RollOffMaxDistance = MaxDistance
	Sound.SoundGroup = _soundGroups.SFX
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
--- @param AudioIdsOrEntry table -- { number, ... } hoặc { Ids = { number, ... }, Volume = 1, MaxDistance = 60 }
--- @param Config table? -- { Volume = 1, MaxDistance = 60 }
--- @return table -- { [AudioId] = Sound }
function AudioHelper.CreateSoundPool(ParentInstance, AudioIdsOrEntry, Config)
	if not ParentInstance or not AudioIdsOrEntry then return {} end

	EnsureSoundGroups()

	local Pool = {}
	local IdsList = {}
	local Volume = (Config and Config.Volume) or 1
	local MaxDistance = (Config and Config.MaxDistance) or 60

	if type(AudioIdsOrEntry) == "table" then
		if AudioIdsOrEntry.Ids then
			IdsList = AudioIdsOrEntry.Ids
			Volume = (Config and Config.Volume) or AudioIdsOrEntry.Volume or Volume
			MaxDistance = (Config and Config.MaxDistance) or AudioIdsOrEntry.MaxDistance or MaxDistance
		else
			IdsList = AudioIdsOrEntry
		end
	end

	for _, AudioId in ipairs(IdsList) do
		local Sound = Instance.new("Sound")
		Sound.Name = "PoolSFX_" .. tostring(AudioId)
		Sound.SoundId = "rbxassetid://" .. tostring(AudioId)
		Sound.Volume = Volume
		Sound.RollOffMaxDistance = MaxDistance
		Sound.SoundGroup = _soundGroups.SFX
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
