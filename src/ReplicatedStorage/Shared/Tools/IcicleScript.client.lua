-- IcicleScript (LocalScript)
-- Nằm trong ReplicatedStorage.Shared.Tools — được IcicleService inject vào Tool khi cấp
-- Chạy khi player cầm Tool (context: Backpack / Character)
--
-- Cơ chế hit detection:
--   Tool.Activated → GetPartsInPart(Hitbox) → FireServer(OnToolHit, TargetPlayer)
--   Không dùng Raycast. Hitbox là Part vô hình trong Tool template (tạo trong Studio).
--   Một lần swing có thể đóng băng/giải cứu nhiều người cùng lúc (AoE).
--
-- Phase 3: phát hiện Block Model (VictimUserId attribute) → signal Thaw đồng đội
-- Phase 8.2: play swing audio (random 1/3) + swing animation phía client mỗi lần Activated

local Tool          = script.Parent
local Player        = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Chờ các dependency sẵn sàng
local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local OnToolHit     = Remotes:WaitForChild("OnToolHit")
local GameConfig    = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("GameConfig")
)
local AudioConfig   = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("AudioConfig")
)

-- Chờ Hitbox từ template
local Hitbox        = Tool:WaitForChild("Hitbox")
local COOLDOWN      = GameConfig.Tool.IcicleCooldown

local _IsOnCooldown = false

-- =========================================================
-- PRIVATE: Audio & Animation
-- =========================================================

--- Phát swing audio ngẫu nhiên tại Character của local player (spatial)
--- Các player xung quanh sẽ nghe được nhờ Roblox replication Sound trong Character
local function PlaySwingAudio(IcicleSkinId)
	local Character = Player.Character
	if not Character then return end
	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if not HRP then return end

	local Audios = AudioConfig.GetSwingAudios(IcicleSkinId)
	local ChosenId = Audios[math.random(1, #Audios)]

	local Sound = Instance.new("Sound")
	Sound.SoundId            = "rbxassetid://" .. tostring(ChosenId)
	Sound.RollOffMaxDistance = 60
	Sound.Volume             = 1
	Sound.Parent             = HRP
	Sound:Play()

	-- Tự dọn sau khi phát xong (tối đa 5 giây)
	task.delay(5, function()
		if Sound and Sound.Parent then
			Sound:Destroy()
		end
	end)
end

--- Play swing animation trên Humanoid của local player
--- Animation tự destroy sau khi kết thúc (không loop)
local function PlaySwingAnimation(IcicleSkinId)
	local Character = Player.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	local AnimId = AudioConfig.GetSwingAnimation(IcicleSkinId)
	local Anim = Instance.new("Animation")
	Anim.AnimationId = "rbxassetid://" .. tostring(AnimId)

	local Track = Humanoid:LoadAnimation(Anim)
	Track:Play()

	-- Dọn dẹp sau khi animation xong
	Track.Stopped:Connect(function()
		Track:Destroy()
		Anim:Destroy()
	end)
end

-- =========================================================
-- TOOL ACTIVATED
-- =========================================================

Tool.Activated:Connect(function()
	-- Cooldown check
	if _IsOnCooldown then return end
	_IsOnCooldown = true

	-- Đọc SkinId của Icicle đang trang bị (gán bởi server qua Attribute)
	local IcicleSkinId = Player:GetAttribute("EquippedIcicleSkinId") or "Default"

	-- Play swing audio + animation ngay lập tức (không chờ server)
	PlaySwingAudio(IcicleSkinId)
	PlaySwingAnimation(IcicleSkinId)

	-- Kiểm tra tất cả Part đang nằm trong vùng Hitbox tại thời điểm swing
	local Params = OverlapParams.new()
	Params.FilterType                 = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Player.Character }

	local TouchingParts = workspace:GetPartsInPart(Hitbox, Params)

	-- Tập hợp các TargetPlayer đã hit (tránh fire nhiều lần cùng 1 người)
	local HitPlayers = {}

	for _, Part in ipairs(TouchingParts) do
		-- Tìm Model chứa Part
		local TargetChar = Part:FindFirstAncestorOfClass("Model")
		if not TargetChar then continue end

		-- Thử resolve player từ character (thường dùng để Freeze)
		local TargetPlayer = game.Players:GetPlayerFromCharacter(TargetChar)

		-- Fallback: nếu không phải character, kiểm tra xem Model có phải Block Model không
		-- Block Model được đánh dấu bằng attribute VictimUserId (set bởi FreezeService)
		if not TargetPlayer then
			local VictimUserId = TargetChar:GetAttribute("VictimUserId")
			if VictimUserId then
				TargetPlayer = game.Players:GetPlayerByUserId(VictimUserId)
			end
		end

		if not TargetPlayer or TargetPlayer == Player then continue end

		-- Tránh hit cùng 1 player nhiều lần trong 1 swing
		if HitPlayers[TargetPlayer] then continue end
		HitPlayers[TargetPlayer] = true

		-- Fire lên server để validate và xử lý (server tự phân biệt Freeze/Thaw dựa vào team)
		OnToolHit:FireServer(TargetPlayer)
	end

	-- Hồi chiêu
	task.wait(COOLDOWN)
	_IsOnCooldown = false
end)
