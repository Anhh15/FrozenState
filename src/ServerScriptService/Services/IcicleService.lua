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
local GameConfig        = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local PlayerStateHelper = require(ReplicatedStorage.Shared.Tools.PlayerStateHelper)

local _lastSwingTimes   = {} -- Cache cooldown chống spam remote: { [UserId] = os.clock() }

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
	local OnToolSwingEvent  = RemoteDefinitions.GetEvent("OnToolSwing")
	local PlaySwingSFXEvent = RemoteDefinitions.GetEvent("PlaySwingSFX")

	-- Lắng nghe tín hiệu vung kiếm từ client để broadcast 3D Spatial SFX
	OnToolSwingEvent.OnServerEvent:Connect(function(Player)
		if not Player or not Player:IsA("Player") then return end

		local Character = Player.Character
		if not Character or not Character.Parent then return end

		-- Kiểm tra người chơi có đang trong trận đấu không
		if not PlayerStateHelper.IsInMatch(Player) then return end

		-- Chỉ cho phép phát âm thanh khi ở trạng thái Normal (không bị đóng băng hay chết)
		if SessionService.GetState(Player) ~= "Normal" then return end

		-- Kiểm tra Cooldown chống spam mạng
		local Now = os.clock()
		local LastSwing = _lastSwingTimes[Player.UserId] or 0
		local Cooldown = GameConfig.Tool.IcicleCooldown or 0.5

		if (Now - LastSwing) < (Cooldown - 0.05) then
			return
		end
		_lastSwingTimes[Player.UserId] = Now

		-- Lấy SkinId đang trang bị
		local SkinId = PlayerStateHelper.GetEquippedIcicleSkinId(Player) or "Default"

		-- Broadcast đến tất cả Client khác để phát 3D Spatial Sound
		PlaySwingSFXEvent:FireAllClients({
			Player       = Player,
			Character    = Character,
			IcicleSkinId = SkinId,
		})
	end)

	-- Dọn dẹp cache cooldown khi player thoát game
	Players.PlayerRemoving:Connect(function(Player)
		_lastSwingTimes[Player.UserId] = nil
	end)

	print("[IcicleService] Đã khởi tạo.")
end

function IcicleService:Start()
	print("[IcicleService] Đang chạy.")
end

return IcicleService
