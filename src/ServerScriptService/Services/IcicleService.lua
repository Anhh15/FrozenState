-- IcicleService.lua
-- Tạo và cấp / thu hồi Tool Icicle cho người chơi
-- Tool được clone từ ServerStorage/Icicles/<SkinId> (do designer tạo trong Studio)
-- IcicleScript được inject vào tool sau khi clone
-- Phase 2: Đọc skin động từ DataService theo EquippedIcicle của người chơi

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SessionService    = require(script.Parent.SessionService)
local DataService       = require(script.Parent.DataService)
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

-- =========================================================
-- PRIVATE: Tool Creation
-- =========================================================

--- Clone Tool Icicle từ template trong ServerStorage và inject LocalScript
--- @param SkinId string — Id của skin Icicle (vd: "Default", "GoldenIcicle")
local function CloneIcicleTool(SkinId)
	local IciclesFolder = ServerStorage:FindFirstChild("Icicles")
	if not IciclesFolder then
		warn("[IcicleService] Không tìm thấy folder ServerStorage/Icicles")
		return nil
	end

	-- Thử load đúng skin, fallback về Default nếu không tìm thấy
	local Template = IciclesFolder:FindFirstChild(SkinId)
	if not Template then
		warn(("[IcicleService] Không tìm thấy Icicle skin '%s', fallback về Default."):format(SkinId))
		Template = IciclesFolder:FindFirstChild("Default")
	end

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

--- Cấp Tool cho một player cụ thể, đọc skin từ DataService
--- @param Player Player
function IcicleService.GiveTool(Player)
	IcicleService.RemoveTool(Player)  -- Xóa cũ nếu có

	-- Đọc skin đang trang bị từ DataService (Phase 2)
	local SkinId = "Default"
	local Data = DataService.GetData(Player)
	if Data and Data.EquippedIcicle then
		local Entry = ItemRegistry.GetItem(Data.EquippedIcicle, "Icicle")
		SkinId = Entry and Entry.Id or "Default"
	end

	local Tool = CloneIcicleTool(SkinId)
	if not Tool then return end

	Tool.Parent = Player.Backpack

	-- Gán SkinId lên Player attribute để IcicleScript.client đọc khi play audio/animation
	PlayerStateHelper.SetEquippedIcicleSkinId(Player, SkinId)

	print(("[IcicleService] Đã cấp Icicle '%s' cho %s"):format(SkinId, Player.Name))
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

--- Cấp Tool cho tất cả player đang trong trận (IsInMatch = true)
--- Hỗ trợ cả chế độ có team và FFA (không có team)
function IcicleService.GiveToolToAll()
	for _, Player in ipairs(Players:GetPlayers()) do
		if PlayerStateHelper.IsInMatch(Player) then
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
