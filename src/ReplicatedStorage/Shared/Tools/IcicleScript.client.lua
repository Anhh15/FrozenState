-- IcicleScript (LocalScript)
-- Nằm trong ReplicatedStorage.Shared.Tools — được IcicleService clone vào Tool khi cấp
-- Chạy khi player cầm Tool (context: Backpack / Character)
-- Xử lý: Activated → Raycast → FireServer(OnToolHit, targetPlayer)

local Tool          = script.Parent
local Player        = game.Players.LocalPlayer
local Camera        = workspace.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Chờ các dependency sẵn sàng
local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local OnToolHit     = Remotes:WaitForChild("OnToolHit")
local GameConfig    = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("GameConfig")
)

local RANGE    = GameConfig.Tool.IcicleRange
local COOLDOWN = GameConfig.Tool.IcicleCooldown

local LastFireTime = 0

-- =========================================================
-- TOOL ACTIVATED
-- =========================================================

Tool.Activated:Connect(function()
	-- Cooldown check
	local Now = os.clock()
	if Now - LastFireTime < COOLDOWN then return end
	LastFireTime = Now

	-- Raycast từ Camera theo hướng nhìn
	local Origin    = Camera.CFrame.Position
	local Direction = Camera.CFrame.LookVector * RANGE

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Player.Character or workspace }

	local Result = workspace:Raycast(Origin, Direction, Params)
	if not Result then return end

	-- Tìm character từ part bị hit
	local HitInstance  = Result.Instance
	local TargetChar   = HitInstance:FindFirstAncestorOfClass("Model")
	if not TargetChar then return end

	local TargetPlayer = game.Players:GetPlayerFromCharacter(TargetChar)
	if not TargetPlayer or TargetPlayer == Player then return end

	-- Fire lên server để validate và xử lý
	OnToolHit:FireServer(TargetPlayer)
end)
