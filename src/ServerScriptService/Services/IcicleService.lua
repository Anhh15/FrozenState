-- IcicleService.lua
-- Tạo và cấp / thu hồi Tool Icicle cho người chơi
-- Tool được clone từ ServerStorage/Icicles/Default (do designer tạo trong Studio)
-- IcicleScript được inject vào tool sau khi clone

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SessionService = require(script.Parent.SessionService)

-- =========================================================
-- PRIVATE: Tool Creation
-- =========================================================

--- Clone Tool Icicle từ template trong ServerStorage và inject LocalScript
local function CloneIcicleTool()
	local IciclesFolder = ServerStorage:FindFirstChild("Icicles")
	local Template      = IciclesFolder and IciclesFolder:FindFirstChild("Default")

	if not Template then
		warn("[IcicleService] Không tìm thấy ServerStorage/Icicles/Default — hãy tạo template trong Studio")
		return nil
	end

	local Tool = Template:Clone()
	Tool.Name  = "Icicle"

	-- Inject LocalScript điều khiển vào tool sau khi clone
	local Shared         = ReplicatedStorage:FindFirstChild("Shared")
	local ToolsFolder    = Shared and Shared:FindFirstChild("Tools")
	local ScriptTemplate = ToolsFolder and ToolsFolder:FindFirstChild("IcicleScript")

	if ScriptTemplate then
		local ToolScript  = ScriptTemplate:Clone()
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

	local Tool = CloneIcicleTool()
	if not Tool then return end

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
