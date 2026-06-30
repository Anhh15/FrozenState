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

-- Chờ Hitbox từ template
local Hitbox        = Tool:WaitForChild("Hitbox")
local COOLDOWN      = GameConfig.Tool.IcicleCooldown

local _IsOnCooldown = false

-- =========================================================
-- TOOL ACTIVATED
-- =========================================================

Tool.Activated:Connect(function()
	-- Cooldown check
	if _IsOnCooldown then return end
	_IsOnCooldown = true

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
