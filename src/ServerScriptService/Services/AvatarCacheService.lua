local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AvatarCacheService = {}

local AvatarCacheFolder

function AvatarCacheService:Init()
	AvatarCacheFolder = Instance.new("Folder")
	AvatarCacheFolder.Name = "PlayerAvatars"
	AvatarCacheFolder.Parent = ReplicatedStorage
end

local function StripAndAnchorModel(model)
	-- Xóa các thành phần động để làm nhẹ mô hình
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") or desc:IsA("Sound") or desc:IsA("Animator") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end
	return model
end

local function CacheAvatar(player)
	local userId = player.UserId
	
	-- Không cache lại nếu đã có
	if AvatarCacheFolder:FindFirstChild(tostring(userId)) then return end

	local model = nil

	if userId > 0 then
		local success, result = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if success and result then
			model = result
		end
	end

	-- Fallback hoặc trường hợp ID âm (Studio)
	if not model then
		local character = player.Character or player.CharacterAdded:Wait()
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		
		-- Dùng Archivable = true để clone
		character.Archivable = true
		model = character:Clone()
		character.Archivable = false
	end

	if model then
		model.Name = tostring(userId)
		StripAndAnchorModel(model)
		model.Parent = AvatarCacheFolder
	end
end

local function RemoveCache(player)
	local userId = tostring(player.UserId)
	local cached = AvatarCacheFolder:FindFirstChild(userId)
	if cached then
		cached:Destroy()
	end
end

function AvatarCacheService:Start()
	Players.PlayerAdded:Connect(function(player)
		-- Đẩy ra một thread mới để không block luồng xử lý PlayerAdded của service khác
		task.spawn(function()
			CacheAvatar(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		RemoveCache(player)
	end)

	-- Xử lý những player đã join trước khi service Start
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			CacheAvatar(player)
		end)
	end
end

return AvatarCacheService
