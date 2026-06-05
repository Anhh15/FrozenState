-- IcicleService.lua
-- Tạo và cấp / thu hồi Tool Icicle cho người chơi
-- Tool bao gồm một Handle cơ bản + clone LocalScript từ ReplicatedStorage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SessionService = require(script.Parent.SessionService)

-- =========================================================
-- PRIVATE: Tool Creation
-- =========================================================

--- Tạo một Tool Icicle hoàn chỉnh sẵn sàng cho vào Backpack
local function CreateIcicleTool()
	local Tool           = Instance.new("Tool")
	Tool.Name            = "Icicle"
	Tool.RequiresHandle  = true
	Tool.CanBeDropped    = false
	Tool.ToolTip         = "Đóng băng kẻ địch / Giải cứu đồng minh"

	-- Handle (part bắt buộc của Tool)
	local Handle         = Instance.new("Part")
	Handle.Name          = "Handle"
	Handle.Size          = Vector3.new(0.25, 1.5, 0.25)
	Handle.BrickColor    = BrickColor.new("Cyan")
	Handle.Material      = Enum.Material.Ice
	Handle.Transparency  = 0.2
	Handle.CastShadow    = false
	Handle.Parent        = Tool

	-- Weld skin mặc định từ ServerStorage/Icicles/Default (nếu có)
	local IciclesFolder = ServerStorage:FindFirstChild("Icicles")
	if IciclesFolder then
		local DefaultSkin = IciclesFolder:FindFirstChild("Default")
		if DefaultSkin then
			local SkinClone = DefaultSkin:Clone()
			SkinClone.Name  = "Skin"
			SkinClone.Parent = Tool

			-- Weld tất cả Part trong skin vào Handle
			for _, Part in ipairs(SkinClone:GetDescendants()) do
				if Part:IsA("BasePart") then
					Part.Anchored = false
					local Weld  = Instance.new("WeldConstraint")
					Weld.Part0  = Handle
					Weld.Part1  = Part
					Weld.Parent = Handle
				end
			end
		end
	end

	-- Clone LocalScript điều khiển tool từ ReplicatedStorage
	local Shared = ReplicatedStorage:FindFirstChild("Shared")
	local ToolsFolder = Shared and Shared:FindFirstChild("Tools")
	local ScriptTemplate = ToolsFolder and ToolsFolder:FindFirstChild("IcicleScript")

	if ScriptTemplate then
		local ToolScript = ScriptTemplate:Clone()
		ToolScript.Parent = Tool
	else
		warn("[IcicleService] Không tìm thấy IcicleScript tại ReplicatedStorage.Shared.Tools")
	end

	return Tool
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local IcicleService = {}

--- Cấp Tool cho một player cụ thể
--- @param Player Player
function IcicleService.GiveTool(Player)
	IcicleService.RemoveTool(Player)  -- Xóa cũ nếu có

	local Tool  = CreateIcicleTool()
	Tool.Parent = Player.Backpack

	print(("[IcicleService] Đã cấp Icicle cho %s"):format(Player.Name))
end

--- Thu hồi Tool của một player
--- @param Player Player
function IcicleService.RemoveTool(Player)
	-- Xóa trong Backpack
	local Backpack = Player:FindFirstChild("Backpack")
	if Backpack then
		for _, Item in ipairs(Backpack:GetChildren()) do
			if Item.Name == "Icicle" and Item:IsA("Tool") then
				Item:Destroy()
			end
		end
	end

	-- Xóa nếu player đang cầm trên tay
	local Character = Player.Character
	if Character then
		for _, Item in ipairs(Character:GetChildren()) do
			if Item.Name == "Icicle" and Item:IsA("Tool") then
				Item:Destroy()
			end
		end
	end
end

--- Cấp Tool cho tất cả player đang có team (đang trong trận)
function IcicleService.GiveToolToAll()
	for _, Player in ipairs(Players:GetPlayers()) do
		if SessionService.GetTeam(Player) ~= nil then
			IcicleService.GiveTool(Player)
		end
	end
end

--- Thu hồi Tool của tất cả player
function IcicleService.RemoveToolFromAll()
	for _, Player in ipairs(Players:GetPlayers()) do
		IcicleService.RemoveTool(Player)
	end
end

-- =========================================================
-- KHỞI ĐỘNG SERVICE
-- =========================================================

function IcicleService:Init()
	print("[IcicleService] Đã khởi tạo.")
end

function IcicleService:Start()
	print("[IcicleService] Đang chạy.")
end

return IcicleService
