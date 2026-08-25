-- PlayerStateHelper.lua
-- Module tiện ích dùng chung (Shared) cho Client & Server để đọc/ghi và theo dõi trạng thái Player
-- Sử dụng PlayerStateConfig làm Single Source of Truth

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerStateConfig = require(ReplicatedStorage.Shared.Config.PlayerStateConfig)

local Attributes = PlayerStateConfig.Attributes

local PlayerStateHelper = {}

-- =========================================================
-- READ METHODS (Client & Server)
-- =========================================================

--- Kiểm tra xem Player có đang trong trận hay không (bất kể mode có team hay FFA)
--- @param Player Player?
--- @return boolean
function PlayerStateHelper.IsInMatch(Player)
	if not Player then return false end
	return Player:GetAttribute(Attributes.InMatch) == true
end

--- Kiểm tra xem Player đã hoàn tất GameLoadingScreen hay chưa
--- @param Player Player?
--- @return boolean
function PlayerStateHelper.IsGameLoaded(Player)
	if not Player then return false end
	return Player:GetAttribute(Attributes.GameLoaded) == true
end

--- Lấy Team hiện tại của Player
--- @param Player Player?
--- @return string?
function PlayerStateHelper.GetTeam(Player)
	if not Player then return nil end
	return Player:GetAttribute(Attributes.Team)
end

--- Kiểm tra xem Player có phải là Spectator hay không (không trong trận)
--- @param Player Player?
--- @return boolean
function PlayerStateHelper.IsSpectator(Player)
	return not PlayerStateHelper.IsInMatch(Player)
end

--- Lấy SkinId của Icicle đang trang bị
--- @param Player Player?
--- @return string
function PlayerStateHelper.GetEquippedIcicleSkinId(Player)
	if not Player then return "Default" end
	return Player:GetAttribute(Attributes.EquippedIcicleSkinId) or "Default"
end

--- Lấy VictimUserId từ BlockModel hoặc Character
--- @param TargetInstance Instance?
--- @return number?
function PlayerStateHelper.GetVictimUserId(TargetInstance)
	if not TargetInstance then return nil end
	return TargetInstance:GetAttribute(Attributes.VictimUserId)
end

-- =========================================================
-- WRITE METHODS (Server-Side)
-- =========================================================

--- Đặt trạng thái GameLoaded cho Player (chỉ chạy từ Server)
--- @param Player Player?
--- @param IsLoaded boolean
function PlayerStateHelper.SetGameLoaded(Player, IsLoaded)
	if not Player then return end
	Player:SetAttribute(Attributes.GameLoaded, IsLoaded == true)
end

--- Đặt trạng thái InMatch cho Player (chỉ chạy từ Server)
--- @param Player Player?
--- @param InMatch boolean
function PlayerStateHelper.SetInMatch(Player, InMatch)
	if not Player then return end
	if InMatch then
		Player:SetAttribute(Attributes.InMatch, true)
	else
		Player:SetAttribute(Attributes.InMatch, nil)
	end
end

--- Đặt Team cho Player (chỉ chạy từ Server)
--- @param Player Player?
--- @param TeamName string?
function PlayerStateHelper.SetTeam(Player, TeamName)
	if not Player then return end
	Player:SetAttribute(Attributes.Team, TeamName)
end

--- Gán SkinId Icicle cho Player (chỉ chạy từ Server)
--- @param Player Player?
--- @param SkinId string
function PlayerStateHelper.SetEquippedIcicleSkinId(Player, SkinId)
	if not Player then return end
	Player:SetAttribute(Attributes.EquippedIcicleSkinId, SkinId)
end

--- Gán VictimUserId lên IceBlock Model (chỉ chạy từ Server)
--- @param BlockModel Instance?
--- @param UserId number?
function PlayerStateHelper.SetVictimUserId(BlockModel, UserId)
	if not BlockModel then return end
	BlockModel:SetAttribute(Attributes.VictimUserId, UserId)
end

-- =========================================================
-- OBSERVER METHODS (Client-Side & Server-Side)
-- =========================================================

--- Lắng nghe sự kiện thay đổi trạng thái tham gia trận (InMatch/Team) của Player
--- Tự động gọi callback 1 lần ban đầu (Option A) và trả về object có Disconnect()
--- @param Player Player
--- @param Callback (IsInMatch: boolean) -> ()
--- @return { Disconnect: () -> () }
function PlayerStateHelper.ObserveMatchState(Player, Callback)
	if not Player or not Callback then
		return { Disconnect = function() end }
	end

	local function FireCallback()
		local IsInMatch = PlayerStateHelper.IsInMatch(Player)
		Callback(IsInMatch)
	end

	-- Lắng nghe cả 2 attribute
	local ConnInMatch = Player:GetAttributeChangedSignal(Attributes.InMatch):Connect(FireCallback)
	local ConnTeam    = Player:GetAttributeChangedSignal(Attributes.Team):Connect(FireCallback)

	-- Tự động gọi 1 lần ngay lập tức với state hiện tại (Option A)
	task.spawn(FireCallback)

	return {
		Disconnect = function()
			if ConnInMatch then
				ConnInMatch:Disconnect()
				ConnInMatch = nil
			end
			if ConnTeam then
				ConnTeam:Disconnect()
				ConnTeam = nil
			end
		end,
	}
end

--- Lắng nghe sự kiện thay đổi trạng thái GameLoaded của Player
--- Tự động gọi callback 1 lần ban đầu (Option A) và trả về object có Disconnect()
--- @param Player Player
--- @param Callback (IsLoaded: boolean) -> ()
--- @return { Disconnect: () -> () }
function PlayerStateHelper.ObserveGameLoaded(Player, Callback)
	if not Player or not Callback then
		return { Disconnect = function() end }
	end

	local function FireCallback()
		local IsLoaded = PlayerStateHelper.IsGameLoaded(Player)
		Callback(IsLoaded)
	end

	local Conn = Player:GetAttributeChangedSignal(Attributes.GameLoaded):Connect(FireCallback)
	task.spawn(FireCallback)

	return {
		Disconnect = function()
			if Conn then
				Conn:Disconnect()
				Conn = nil
			end
		end,
	}
end

return PlayerStateHelper
