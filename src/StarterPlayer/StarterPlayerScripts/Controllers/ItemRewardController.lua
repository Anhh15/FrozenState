-- ItemRewardController.lua (ModuleScript)
-- Điều phối hiệu ứng mở rương và hiển thị phần thưởng item
-- Có thể được kích hoạt từ Shop, Quest, hoặc event bất kỳ trong tương lai
-- Phần thưởng PHẢI được trao bởi server TRƯỚC khi gọi module này
--
-- GUI mong đợi (StarterGui/Special/ItemReward):
--   ItemReward    (Frame)              -- nền, BackgroundTransparency = 0.4, Visible = false
--     Effect      (Frame)              -- Pha 1: hiệu ứng rương
--       ChestViewport (ViewportFrame)  -- hiển thị model 3D của rương
--       EffectImage   (ImageLabel)     -- hình hào quang, xoay liên tục
--     ItemFrame   (Frame)              -- Pha 2: hiển thị item nhận được (có UIGridLayout bên trong)
--     ClickButton (ImageButton)        -- BackgroundTransparency = 1, phủ toàn màn hình

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local ItemRegistry    = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig    = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ChestConfig     = require(ReplicatedStorage.Shared.Config.ChestConfig)
local ViewportManager = require(ReplicatedStorage.Shared.Tools.ViewportManager)

-- =========================================================
-- GUI REFERENCES (set trong Init)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local SpecialGui    = nil
local ItemReward    = nil
local Effect        = nil
local ChestViewport = nil
local EffectImage   = nil
local ItemFrame     = nil
local ClickButton   = nil

-- =========================================================
-- ASSETS
-- =========================================================

local Assets            = ReplicatedStorage:FindFirstChild("Assets")
local GuiFolder         = Assets and (Assets:FindFirstChild("Gui") or Assets:FindFirstChild("GUI"))
local ItemTemplate      = GuiFolder  and GuiFolder:FindFirstChild("ItemTemplate")
local ChestsFolder      = Assets     and Assets:FindFirstChild("Chests")
local ItemPreviewFolder = Assets     and Assets:FindFirstChild("ItemPreview")

-- =========================================================
-- DEFAULTS (đọc từ GUI trong Init — không hardcode)
-- =========================================================

local _defaultBgColor        = nil  -- ItemReward.BackgroundColor3
local _defaultBgTransparency = nil  -- ItemReward.BackgroundTransparency
local _defaultViewportSize   = nil  -- ChestViewport.Size  (UDim2)
local _defaultEffectRot      = nil  -- EffectImage.Rotation (number)

-- =========================================================
-- STATE
-- =========================================================

-- "idle" | "phase1" | "phase2"
local _state      = "idle"
local _clickCount = 0        -- số click trong Pha 1 (tối đa 3)

local _activeTween = nil     -- Tween đang chạy (để cancel khi cần)
local _rotConn     = nil     -- RunService.Heartbeat connection xoay EffectImage

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Hủy Tween đang chạy (nếu có), không ảnh hưởng state
local function CancelActiveTween()
	if _activeTween then
		_activeTween:Cancel()
		_activeTween = nil
	end
end

--- Dừng vòng xoay EffectImage
local function StopRotation()
	if _rotConn then
		_rotConn:Disconnect()
		_rotConn = nil
	end
end

--- Bắt đầu xoay EffectImage liên tục (72°/s = 360° trong 5 giây)
local function StartRotation()
	StopRotation()
	if not EffectImage then return end
	local SPEED = 36  -- độ/giây
	_rotConn = RunService.Heartbeat:Connect(function(Dt)
		EffectImage.Rotation = EffectImage.Rotation + SPEED * Dt
	end)
end

--- Dọn sạch ChestViewport (model + camera)
local function ClearViewport()
	if ChestViewport then
		ViewportManager.CleanViewport(ChestViewport)
	end
end

--- Dọn sạch ItemFrame (xóa clone, giữ lại UIGridLayout / UIListLayout / UIPadding)
local function ClearItemFrame()
	if not ItemFrame then return end
	for _, Child in ipairs(ItemFrame:GetChildren()) do
		if not Child:IsA("UIGridLayout")
			and not Child:IsA("UIListLayout")
			and not Child:IsA("UIPadding") then
			Child:Destroy()
		end
	end
end

--- Khôi phục các thuộc tính GUI về mặc định (tức thì, không Tween)
local function RestoreDefaults()
	if not ItemReward then return end
	ItemReward.BackgroundColor3      = _defaultBgColor
	ItemReward.BackgroundTransparency = _defaultBgTransparency
	if ChestViewport then
		ChestViewport.Size = _defaultViewportSize
	end
	if EffectImage then
		EffectImage.Rotation = _defaultEffectRot
	end
end

--- Clone và render danh sách item vào ItemFrame
--- @param Items table  -- array of { ItemId: string, Type: string, ... }
local function RenderItems(Items)
	ClearItemFrame()
	if not ItemTemplate then
		warn("[ItemRewardController] Không tìm thấy ItemTemplate trong Assets — bỏ qua render item.")
		return
	end
	for _, Entry in ipairs(Items) do
		local ItemId   = Entry.ItemId
		local ItemType = Entry.Type
		if not ItemId or not ItemType then
			warn("[ItemRewardController] Item thiếu ItemId hoặc Type, bỏ qua.")
			continue
		end

		local FullEntry = ItemRegistry.GetItem(ItemId, ItemType)
		if not FullEntry then
			warn(("[ItemRewardController] Không tìm thấy item '%s'/'%s' trong ItemRegistry."):format(
				tostring(ItemId), tostring(ItemType)
			))
			continue
		end

		local RarityEntry = RarityConfig[FullEntry.Rarity]
		local Frame       = ItemTemplate:Clone()
		Frame.Visible     = true

		-- Cập nhật các label
		local NameText   = Frame:FindFirstChild("NameText",     true)
		local RarityText = Frame:FindFirstChild("RarityText",   true)
		local DropText   = Frame:FindFirstChild("DropRateText", true)
		local Background = Frame:FindFirstChild("Background",   true)

		if NameText   then NameText.Text     = FullEntry.Name end
		if RarityText then
			RarityText.Text = FullEntry.Rarity
			if RarityEntry then RarityText.TextColor3 = RarityEntry.Color end
		end
		if DropText   then DropText.Visible  = false end  -- Ẩn DropRate trong màn hình reward
		if Background and RarityEntry then
			Background.Image = RarityEntry.ImageId
		end

		-- Render item 3D preview (nếu template có ItemViewport)
		local ItemViewport = Frame:FindFirstChild("ItemViewport", true)
		if ItemViewport then
			ViewportManager.CleanViewport(ItemViewport)
			local TypeSubFolder = ItemPreviewFolder and ItemPreviewFolder:FindFirstChild(
				ItemType == "Icicle" and "Icicles" or "Blocks"
			)
			if TypeSubFolder then
				local ItemModel = TypeSubFolder:FindFirstChild(FullEntry.Id)
				if ItemModel then
					local ModelClone = ItemModel:Clone()
					ModelClone.Parent = ItemViewport
					ViewportManager.RenderItem(ItemViewport, ModelClone, FullEntry.Type, FullEntry.Id)
				end
			end
		end

		Frame.Parent = ItemFrame
	end
end

-- =========================================================
-- PHASE TRANSITIONS
-- =========================================================

--- Chuyển sang Pha 2: flash trắng → hiện ItemFrame → fade về mặc định
local function TransitionToPhase2()
	_state = "phase2"

	-- Dừng xoay, ẩn Effect (rương)
	StopRotation()
	if Effect then Effect.Visible = false end

	-- Flash: ItemReward → nền trắng hoàn toàn trong 0.4s
	local TweenInfo04 = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	CancelActiveTween()
	local FlashTween = TweenService:Create(ItemReward, TweenInfo04, {
		BackgroundColor3      = Color3.fromHex("FFFFFF"),
		BackgroundTransparency = 0,
	})
	_activeTween = FlashTween
	FlashTween:Play()

	FlashTween.Completed:Connect(function(Pb)
		if Pb ~= Enum.PlaybackState.Completed then return end

		-- Hiện ItemFrame
		if ItemFrame then ItemFrame.Visible = true end

		-- Fade về màu mặc định trong 0.4s
		local FadeTween = TweenService:Create(ItemReward, TweenInfo04, {
			BackgroundColor3      = _defaultBgColor,
			BackgroundTransparency = _defaultBgTransparency,
		})
		_activeTween = FadeTween
		FadeTween:Play()

		FadeTween.Completed:Connect(function(Pb2)
			if Pb2 ~= Enum.PlaybackState.Completed then return end
			_activeTween = nil
		end)
	end)
end

--- Animation mỗi lần bấm trong Pha 1: thu nhỏ → phóng to
--- Sau khi animation xong, nếu đủ 3 lần → chuyển Pha 2
local function PlayClickAnimation()
	CancelActiveTween()

	-- Tính 50% size mặc định
	local HalfSize = UDim2.new(
		_defaultViewportSize.X.Scale  * 0.5,
		_defaultViewportSize.X.Offset * 0.5,
		_defaultViewportSize.Y.Scale  * 0.5,
		_defaultViewportSize.Y.Offset * 0.5
	)

	-- Shrink: size hiện tại → 50% (0.15s, Quad Out)
	local ShrinkTween = TweenService:Create(
		ChestViewport,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = HalfSize }
	)
	_activeTween = ShrinkTween
	ShrinkTween:Play()

	ShrinkTween.Completed:Connect(function(Pb)
		if Pb ~= Enum.PlaybackState.Completed then return end

		-- Expand: 50% → size mặc định (0.25s, Back Out — tạo hiệu ứng "bật lại")
		local ExpandTween = TweenService:Create(
			ChestViewport,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = _defaultViewportSize }
		)
		_activeTween = ExpandTween
		ExpandTween:Play()

		ExpandTween.Completed:Connect(function(Pb2)
			if Pb2 ~= Enum.PlaybackState.Completed then return end
			_activeTween = nil
			-- Kiểm tra xem có đủ 3 lần không để chuyển sang Pha 2
			if _state == "phase1" and _clickCount >= 3 then
				TransitionToPhase2()
			end
		end)
	end)
end

-- =========================================================
-- PRIVATE: RESET
-- =========================================================

local function DoReset()
	CancelActiveTween()
	StopRotation()
	ClearViewport()
	ClearItemFrame()
	RestoreDefaults()

	if ItemReward  then ItemReward.Visible  = false end
	if Effect      then Effect.Visible      = false end
	if ItemFrame   then ItemFrame.Visible   = false end
	if ClickButton then ClickButton.Active  = false end

	_state      = "idle"
	_clickCount = 0
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local ItemRewardController = {}

--- Hiệu ứng đầy đủ: Pha 1 (mở rương với click x3) + Pha 2 (hiển thị item)
--- Gọi sau khi server đã trao phần thưởng thành công
--- @param ReceivedItems table  -- array of { ItemId: string, Type?: string, WasDuplicate?: bool, Refund?: number }
--- @param ChestId string       -- Id của rương (để load model và suy ra Type nếu item thiếu Type)
function ItemRewardController.ShowChestReward(ReceivedItems, ChestId)
	if _state ~= "idle" then DoReset() end

	local ChestEntry = ChestConfig.GetChest(ChestId)
	if not ChestEntry then
		warn(("[ItemRewardController] Không tìm thấy ChestId '%s' trong ChestConfig."):format(tostring(ChestId)))
		return
	end

	-- Gắn Type vào mỗi item (lấy từ ChestEntry.Type nếu item chưa có)
	local ItemsWithType = {}
	for _, Entry in ipairs(ReceivedItems) do
		table.insert(ItemsWithType, {
			ItemId       = Entry.ItemId,
			Type         = Entry.Type or ChestEntry.Type,
			WasDuplicate = Entry.WasDuplicate,
			Refund       = Entry.Refund,
		})
	end

	-- Clone items vào ItemFrame trước (ẩn — sẽ hiện ở Pha 2)
	RenderItems(ItemsWithType)

	-- Khởi tạo Pha 1
	_state      = "phase1"
	_clickCount = 0

	ItemReward.Visible = true
	Effect.Visible     = true
	ItemFrame.Visible  = false

	-- Đặt ChestViewport về size 0 để bắt đầu animation zoom-in
	ChestViewport.Size = UDim2.new(0, 0, 0, 0)

	-- Load model rương vào ChestViewport
	ClearViewport()
	if ChestsFolder then
		local ChestModel = ChestsFolder:FindFirstChild(ChestId)
		if ChestModel then
			local Clone = ChestModel:Clone()
			Clone.Parent = ChestViewport
			ViewportManager.RenderItem(ChestViewport, Clone, "Chest", ChestId)
		else
			warn(("[ItemRewardController] Không tìm thấy model '%s' trong Assets/Chests."):format(ChestId))
		end
	end

	-- Zoom-in ban đầu: 0 → size mặc định (0.4s, Back Out — cảm giác "bật ra")
	CancelActiveTween()
	local ZoomTween = TweenService:Create(
		ChestViewport,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = _defaultViewportSize }
	)
	_activeTween = ZoomTween
	ZoomTween:Play()
	ZoomTween.Completed:Connect(function(Pb)
		if Pb == Enum.PlaybackState.Completed then
			_activeTween = nil
		end
	end)

	-- Bắt đầu xoay EffectImage
	StartRotation()

	-- Kích hoạt ClickButton
	ClickButton.Active = true
end

--- Chỉ Pha 2: hiển thị item trực tiếp không qua hiệu ứng mở rương
--- Dùng khi nhận phần thưởng là item cụ thể (icicle, block) mà không phải rương
--- @param Items table  -- array of { ItemId: string, Type: string, ... }
function ItemRewardController.ShowItemReward(Items)
	if _state ~= "idle" then DoReset() end

	-- Clone items vào ItemFrame
	RenderItems(Items)

	-- Bỏ qua Pha 1, vào thẳng Pha 2
	_state      = "phase2"
	_clickCount = 0

	ItemReward.Visible = true
	Effect.Visible     = false
	ItemFrame.Visible  = false

	TransitionToPhase2()

	ClickButton.Active = true
end

--- Reset toàn bộ hiệu ứng và dọn dẹp — gọi khi vào trận hoặc gián đoạn khẩn cấp
function ItemRewardController.Reset()
	DoReset()
end

function ItemRewardController:Init()
	-- Lấy GUI references
	SpecialGui    = PlayerGui:WaitForChild("Special")
	local IR      = SpecialGui:WaitForChild("ItemReward")
	ItemReward    = IR
	Effect        = IR:WaitForChild("Effect")
	ChestViewport = Effect:WaitForChild("ChestViewport")
	EffectImage   = Effect:WaitForChild("EffectImage")
	ItemFrame     = IR:WaitForChild("ItemFrame")
	ClickButton   = IR:WaitForChild("ClickButton")

	-- Ngăn GUI reset khi character chết/respawn
	SpecialGui.ResetOnSpawn = false

	-- Cache giá trị mặc định từ GUI instance (đọc trực tiếp, không hardcode)
	_defaultBgColor        = ItemReward.BackgroundColor3
	_defaultBgTransparency = ItemReward.BackgroundTransparency
	_defaultViewportSize   = ChestViewport.Size
	_defaultEffectRot      = EffectImage.Rotation

	-- Đặt trạng thái ban đầu
	ItemReward.Visible = false
	Effect.Visible     = false
	ItemFrame.Visible  = false
	ClickButton.Active = false

	-- Kết nối ClickButton — lắng nghe suốt vòng đời, điều phối theo _state
	ClickButton.MouseButton1Click:Connect(function()
		if _state == "phase1" then
			-- Chặn click thứ 4+ trong Pha 1
			if _clickCount >= 3 then return end
			_clickCount = _clickCount + 1
			-- Nếu đang animation thì reset animation (bắt đầu lại từ đầu shrink)
			PlayClickAnimation()

		elseif _state == "phase2" then
			-- Một click để đóng toàn bộ
			DoReset()
		end
		-- state == "idle": ClickButton.Active = false nên không kích hoạt được
	end)

	print("[ItemRewardController] Đã khởi tạo.")
end

return ItemRewardController
