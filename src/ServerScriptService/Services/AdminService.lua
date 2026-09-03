-- AdminService.lua
-- Xử lý toàn bộ logic Admin CLI & Live Operations phía Server
-- Lắng nghe trực tiếp qua Player.Chatted trên Server (100% Server Authority)
-- Tuyệt đối không mở Remote thực thi từ Client để ngăn ngừa lỗ hổng bảo mật

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local DataService       = require(script.Parent.DataService)
local AdminConfig       = require(ServerScriptService.Config.AdminConfig)
local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
local ItemRegistry      = require(ReplicatedStorage.Shared.Config.ItemRegistry)

local SyncPlayerDataEv  = nil
local UpdateMoneyEv     = nil

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Ghi log bảo mật (Audit Log) cho mọi thao tác của Admin
local function LogAudit(AdminPlayer, CommandName, RawMessage, Success, Detail)
	local AdminName = AdminPlayer and AdminPlayer.Name or "Console"
	local AdminId   = AdminPlayer and AdminPlayer.UserId or 0
	local StatusStr = Success and "SUCCESS" or "FAILED"

	print(("[AdminService] [AUDIT] [%s] Admin: %s (%d) | Cmd: '%s' | Detail: %s | Raw: '%s'"):format(
		StatusStr,
		AdminName,
		AdminId,
		CommandName,
		tostring(Detail or "N/A"),
		tostring(RawMessage)
	))
end

--- Tìm danh sách người chơi theo chuỗi định danh (me, all, username, displayname, prefix)
--- @param AdminPlayer Player
--- @param TargetStr string
--- @return Player[]
local function FindTargetPlayers(AdminPlayer, TargetStr)
	if not TargetStr or TargetStr == "" then return {} end
	TargetStr = string.lower(TargetStr)

	if TargetStr == "me" or TargetStr == "." then
		return { AdminPlayer }
	end

	if TargetStr == "all" or TargetStr == "*" then
		return Players:GetPlayers()
	end

	local AllPlayers = Players:GetPlayers()

	-- 1. Exact Username match
	for _, Player in ipairs(AllPlayers) do
		if string.lower(Player.Name) == TargetStr then
			return { Player }
		end
	end

	-- 2. Exact DisplayName match
	for _, Player in ipairs(AllPlayers) do
		if string.lower(Player.DisplayName) == TargetStr then
			return { Player }
		end
	end

	-- 3. Prefix match (Username hoặc DisplayName bắt đầu bằng TargetStr)
	local Matches = {}
	for _, Player in ipairs(AllPlayers) do
		local NameLower = string.lower(Player.Name)
		local DisplayLower = string.lower(Player.DisplayName)
		if string.sub(NameLower, 1, #TargetStr) == TargetStr
			or string.sub(DisplayLower, 1, #TargetStr) == TargetStr
		then
			table.insert(Matches, Player)
		end
	end

	return Matches
end

--- Đồng bộ dữ liệu mới nhất về Client của mục tiêu để UI cập nhật tức thì
--- @param TargetPlayer Player
local function SyncTargetData(TargetPlayer)
	if not TargetPlayer or not TargetPlayer:IsDescendantOf(Players) then return end

	local FullData = DataService.GetFullDataCopy(TargetPlayer)
	if FullData and SyncPlayerDataEv then
		SyncPlayerDataEv:FireClient(TargetPlayer, FullData)
	end

	if FullData and UpdateMoneyEv then
		UpdateMoneyEv:FireClient(TargetPlayer, FullData.Money)
	end
end

-- =========================================================
-- COMMAND HANDLERS
-- =========================================================

local Commands = {}

--- /givemoney <target> <amount>
Commands["givemoney"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	local Amount    = tonumber(Args[2])
	if not TargetStr or not Amount then return false, "Cú pháp: /givemoney <target> <amount>" end

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		DataService.AddMoney(Target, Amount)
		SyncTargetData(Target)
	end
	return true, ("Đã cộng %d tiền cho %d người chơi."):format(Amount, #Targets)
end
Commands["givecash"] = Commands["givemoney"]
Commands["addmoney"] = Commands["givemoney"]

--- /setmoney <target> <amount>
Commands["setmoney"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	local Amount    = tonumber(Args[2])
	if not TargetStr or not Amount then return false, "Cú pháp: /setmoney <target> <amount>" end

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		DataService.SetMoney(Target, Amount)
		SyncTargetData(Target)
	end
	return true, ("Đã set tiền = %d cho %d người chơi."):format(Amount, #Targets)
end

--- /setstat <target> <statName> <value>
Commands["setstat"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	local StatName  = Args[2]
	local RawValue  = Args[3]
	if not TargetStr or not StatName or RawValue == nil then
		return false, "Cú pháp: /setstat <target> <statName> <value>"
	end

	local ParsedValue = tonumber(RawValue)
	if ParsedValue == nil then
		if RawValue == "true" then ParsedValue = true
		elseif RawValue == "false" then ParsedValue = false
		else ParsedValue = RawValue end
	end

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		local Success = DataService.SetStat(Target, StatName, ParsedValue)
		if Success then
			SyncTargetData(Target)
		end
	end
	return true, ("Đã set %s = %s cho %d người chơi."):format(StatName, tostring(ParsedValue), #Targets)
end

--- /addstat <target> <statName> <amount>
Commands["addstat"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	local StatName  = Args[2]
	local Amount    = tonumber(Args[3]) or 1
	if not TargetStr or not StatName then
		return false, "Cú pháp: /addstat <target> <statName> [amount]"
	end

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		DataService.IncrementStat(Target, StatName, Amount)
		SyncTargetData(Target)
	end
	return true, ("Đã tăng %s thêm %d cho %d người chơi."):format(StatName, Amount, #Targets)
end

--- /giveskin <target> <icicle|block> <skinId>
Commands["giveskin"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	local SkinType  = Args[2]
	local SkinId    = Args[3]
	if not TargetStr or not SkinType or not SkinId then
		return false, "Cú pháp: /giveskin <target> <icicle|block> <skinId>"
	end

	local NormalizedType = string.lower(SkinType)
	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		if NormalizedType == "icicle" then
			DataService.AddIcicle(Target, SkinId)
		elseif NormalizedType == "block" then
			DataService.AddBlock(Target, SkinId)
		end
		SyncTargetData(Target)
	end
	return true, ("Đã trao skin %s '%s' cho %d người chơi."):format(SkinType, SkinId, #Targets)
end

--- /removeskin <target> <icicle|block> <skinId>
Commands["removeskin"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	local SkinType  = Args[2]
	local SkinId    = Args[3]
	if not TargetStr or not SkinType or not SkinId then
		return false, "Cú pháp: /removeskin <target> <icicle|block> <skinId>"
	end

	local NormalizedType = string.lower(SkinType)
	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		if NormalizedType == "icicle" then
			DataService.RemoveIcicle(Target, SkinId)
		elseif NormalizedType == "block" then
			DataService.RemoveBlock(Target, SkinId)
		end
		SyncTargetData(Target)
	end
	return true, ("Đã xóa skin %s '%s' của %d người chơi."):format(SkinType, SkinId, #Targets)
end

--- /clearskins <target> [icicle|block]
Commands["clearskins"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	local SkinType  = Args[2]
	if not TargetStr then return false, "Cú pháp: /clearskins <target> [icicle|block]" end

	local TypeParam = nil
	if SkinType then
		local Lower = string.lower(SkinType)
		if Lower == "icicle" then TypeParam = "Icicle"
		elseif Lower == "block" then TypeParam = "Block" end
	end

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		DataService.ClearSkins(Target, TypeParam)
		SyncTargetData(Target)
	end
	return true, ("Đã xóa sạch skin của %d người chơi."):format(#Targets)
end

--- /giveallskins <target>
Commands["giveallskins"] = function(AdminPlayer, Args)
	local TargetStr = Args[1] or "me"
	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		DataService.GiveAllSkins(Target)
		SyncTargetData(Target)
	end
	return true, ("Đã cấp toàn bộ skin trong game cho %d người chơi."):format(#Targets)
end

--- /resetdata <target>
Commands["resetdata"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	if not TargetStr then return false, "Cú pháp: /resetdata <target>" end

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		DataService.ResetProfileData(Target)
		SyncTargetData(Target)
	end
	return true, ("Đã reset dữ liệu của %d người chơi về mặc định."):format(#Targets)
end

--- /resetreceipts <target>
Commands["resetreceipts"] = function(AdminPlayer, Args)
	local TargetStr = Args[1] or "me"
	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		DataService.ClearPurchaseHistory(Target)
	end
	return true, ("Đã xóa lịch sử mua Robux của %d người chơi."):format(#Targets)
end

--- /kick <target> [reason]
Commands["kick"] = function(AdminPlayer, Args)
	local TargetStr = Args[1]
	if not TargetStr then return false, "Cú pháp: /kick <target> [reason]" end

	-- Bỏ phần target ra khỏi lý do
	local ReasonParts = {}
	for i = 2, #Args do
		table.insert(ReasonParts, Args[i])
	end
	local Reason = #ReasonParts > 0 and table.concat(ReasonParts, " ") or "[Admin] Bạn đã bị ngắt kết nối bởi Quản trị viên."

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	for _, Target in ipairs(Targets) do
		if Target ~= AdminPlayer then
			Target:Kick(Reason)
		end
	end
	return true, ("Đã kick %d người chơi."):format(#Targets)
end

--- /ban <target> [durationHours] [reason]
Commands["ban"] = function(AdminPlayer, Args)
	local TargetStr     = Args[1]
	local DurationHours = tonumber(Args[2]) or -1
	if not TargetStr then return false, "Cú pháp: /ban <target> [durationHours] [reason]" end

	local ReasonParts = {}
	for i = 3, #Args do
		table.insert(ReasonParts, Args[i])
	end
	local Reason = #ReasonParts > 0 and table.concat(ReasonParts, " ") or "Tài khoản bị cấm chơi do vi phạm quy định."

	local Targets = FindTargetPlayers(AdminPlayer, TargetStr)
	if #Targets == 0 then return false, "Không tìm thấy người chơi: " .. TargetStr end

	local DurationSeconds = (DurationHours > 0) and (DurationHours * 3600) or -1

	for _, Target in ipairs(Targets) do
		if Target ~= AdminPlayer then
			local BanSuccess, BanErr = pcall(function()
				Players:BanAsync({
					UserIds       = { Target.UserId },
					Duration      = DurationSeconds,
					DisplayReason = Reason,
					PrivateReason = ("Banned by %s (UserId: %d)"):format(AdminPlayer.Name, AdminPlayer.UserId),
					ApplyToUniverse = true,
				})
			end)

			if not BanSuccess then
				warn(("[AdminService] BanAsync thất bại: %s. Fallback sang Kick."):format(tostring(BanErr)))
				Target:Kick("[Banned] " .. Reason)
			end
		end
	end
	return true, ("Đã cấm chơi (Ban) %d người chơi."):format(#Targets)
end

--- /unban <userId>
Commands["unban"] = function(AdminPlayer, Args)
	local UserIdStr = Args[1]
	local UserId    = tonumber(UserIdStr)
	if not UserId then return false, "Cú pháp: /unban <userId>" end

	local Success, Err = pcall(function()
		Players:UnbanAsync({
			UserIds         = { UserId },
			ApplyToUniverse = true,
		})
	end)

	if Success then
		return true, ("Đã gỡ cấm (Unban) cho UserId: %d"):format(UserId)
	else
		return false, ("Unban thất bại: %s"):format(tostring(Err))
	end
end

-- =========================================================
-- CHAT PROCESSOR
-- =========================================================

local function ProcessChatMessage(Player, RawMessage)
	if not AdminConfig.IsAdmin(Player) then return end
	if type(RawMessage) ~= "string" then return end

	local Prefix = AdminConfig.Prefix or "/"
	if string.sub(RawMessage, 1, #Prefix) ~= Prefix then return end

	-- Cắt bỏ prefix và tách arguments
	local Content = string.sub(RawMessage, #Prefix + 1)
	local Tokens  = {}
	for Token in string.gmatch(Content, "%S+") do
		table.insert(Tokens, Token)
	end

	if #Tokens == 0 then return end

	local CmdName = string.lower(Tokens[1])
	local Args    = {}
	for i = 2, #Tokens do
		table.insert(Args, Tokens[i])
	end

	local Handler = Commands[CmdName]
	if Handler then
		local Success, Message = Handler(Player, Args)
		LogAudit(Player, CmdName, RawMessage, Success, Message)
	else
		-- Lệnh không tồn tại trong danh sách admin commands
		-- Không in warn nếu người chơi chat bình thường bắt đầu bằng / (ví dụ /w, /team)
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local AdminService = {}

function AdminService:Init()
	assert(RunService:IsServer(), "AdminService chỉ được chạy trên Server")

	SyncPlayerDataEv = RemoteDefinitions.GetEvent("SyncPlayerData")
	UpdateMoneyEv    = RemoteDefinitions.GetEvent("UpdateMoney")

	Players.PlayerAdded:Connect(function(Player)
		Player.Chatted:Connect(function(Message)
			ProcessChatMessage(Player, Message)
		end)
	end)

	-- Xử lý player đã join trước khi service Init
	for _, Player in ipairs(Players:GetPlayers()) do
		Player.Chatted:Connect(function(Message)
			ProcessChatMessage(Player, Message)
		end)
	end

	print("[AdminService] Đã khởi tạo. (100% Server Authority CLI Engine)")
end

function AdminService:Start()
	print("[AdminService] Đang chạy.")
end

return AdminService
