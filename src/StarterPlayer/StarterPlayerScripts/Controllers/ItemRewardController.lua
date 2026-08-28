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
local SoundService      = game:GetService("SoundService")

local ItemRegistry    = require(ReplicatedStorage.Shared.Config.ItemRegistry)
local RarityConfig    = require(ReplicatedStorage.Shared.Config.RarityConfig)
local ChestConfig     = require(ReplicatedStorage.Shared.Config.ChestConfig)
local AudioConfig     = require(ReplicatedStorage.Shared.Config.AudioConfig)
local AudioHelper     = require(ReplicatedStorage.Shared.Tools.AudioHelper)
local ViewportManager = require(ReplicatedStorage.Shared.Tools.ViewportManager)
local GuiHelper       = require(ReplicatedStorage.Shared.Tools.GuiHelper)
local ItemCard        = require(ReplicatedStorage.Shared.Tools.ItemCard)

-- =========================================================
-- GUI REFERENCES (set trong Init)
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local SpecialGui    = nil
local ItemReward    = nil
local Background    = nil
local Effect        = nil
local ChestViewport = nil
local EffectImage   = nil
local ItemFrame     = nil
local ClickButton   = nil

-- =========================================================
-- ASSETS
-- =========================================================

local Assets            = ReplicatedStorage:FindFirstChild("Assets")
local ChestsFolder      = Assets and Assets:FindFirstChild("Chests")

-- =========================================================
-- DEFAULTS (đọc từ GUI trong Init — không hardcode)
-- =========================================================

local _DefaultBgColor        = nil  -- ItemReward.BackgroundColor3
local _DefaultBgTransparency = nil  -- ItemReward.BackgroundTransparency
local _DefaultViewportSize   = nil  -- ChestViewport.Size  (UDim2)
local _DefaultEffectRot      = nil  -- EffectImage.Rotation (number)

-- =========================================================
-- STATE
-- =========================================================

-- "idle" | "phase1" | "phase2"
local _State          = "idle"
local _ClickCount     = 0        -- số click trong Pha 1 (tối đa 3)
local _CurrentChestId = nil      -- Id của rương hiện tại đang mở

local _ActiveTween = nil     -- Tween đang chạy (để cancel khi cần)
local _RotConn     = nil     -- RunService.Heartbeat connection xoay EffectImage

-- =========================================================
-- PRIVATE HELPERS
-- =========================================================

--- Phát hiệu ứng âm thanh 2D qua AudioHelper
--- @param SoundId number | string  -- ID âm thanh
--- @param Volume number?           -- Âm lượng (mặc định 1 nếu nil)
local function PlaySound(SoundId, Volume)
	AudioHelper.Play2DSound(SoundId, Volume, SoundService)
end

--- Hủy Tween đang chạy (nếu có), không ảnh hưởng state
local function CancelActiveTween()
	if _ActiveTween then
		_ActiveTween:Cancel()
		_ActiveTween = nil
	end
end

--- Dừng vòng xoay EffectImage
local function StopRotation()
	if _RotConn then
		_RotConn:Disconnect()
		_RotConn = nil
	end
end

--- Bắt đầu xoay EffectImage liên tục theo RotationSpeed trong cấu hình
local function StartRotation()
	StopRotation()
	if not EffectImage then return end
	local AnimConfig = GuiHelper.GetItemRewardAnimConfig(_CurrentChestId)
	local Speed = AnimConfig.RotationSpeed or 36
	_RotConn = RunService.Heartbeat:Connect(function(Dt)
		EffectImage.Rotation = EffectImage.Rotation + Speed * Dt
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
			ItemCard.Destroy(Child)
		end
	end
end

--- Khôi phục các thuộc tính GUI về mặc định (tức thì, không Tween)
local function RestoreDefaults()
	if not ItemReward then return end
	ItemReward.BackgroundTransparency = 1
	if Background then
		Background.BackgroundColor3       = _DefaultBgColor
		Background.BackgroundTransparency = _DefaultBgTransparency
	end
	if ChestViewport then
		ChestViewport.Size = _DefaultViewportSize
	end
	if EffectImage then
		EffectImage.Rotation = _DefaultEffectRot
	end
end

--- Clone và render danh sách item vào ItemFrame
--- @param Items table  -- array of { ItemId: string, Type: string, ... }
local function RenderItems(Items)
	ClearItemFrame()
	if not ItemFrame then return end

	for _, Entry in ipairs(Items) do
		local ItemId   = Entry.ItemId
		local ItemType = Entry.Type
		if not ItemId or not ItemType then
			warn("[ItemRewardController] Item thiếu ItemId hoặc Type, bỏ qua.")
			continue
		end

		ItemCard.Create(ItemFrame, ItemId, ItemType, {
			ShowEquipped = false,
			ShowDropRate = false,
			EnableHover  = false,
		})
	end
end

-- =========================================================
-- PHASE TRANSITIONS
-- =========================================================

--- Chuyển sang Pha 2: flash trắng → hiện ItemFrame → fade về mặc định
local function TransitionToPhase2()
	_State = "phase2"

	-- Phát âm thanh chuyển pha 2
	PlaySound(AudioConfig.ItemReward.Phase2Transition)

	-- Dừng xoay, ẩn Effect (rương)
	StopRotation()
	if Effect then Effect.Visible = false end

	local AnimCfg = GuiHelper.GetItemRewardAnimConfig(_CurrentChestId)

	-- Flash: Background → nền trắng hoàn toàn trong FlashDuration
	local TweenTarget = Background or ItemReward
	local FlashTweenInfo = TweenInfo.new(AnimCfg.FlashDuration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	CancelActiveTween()
	local FlashTween = TweenService:Create(TweenTarget, FlashTweenInfo, {
		BackgroundColor3       = Color3.fromHex("FFFFFF"),
		BackgroundTransparency = 0,
	})
	_ActiveTween = FlashTween
	FlashTween:Play()

	FlashTween.Completed:Connect(function(Pb)
		if Pb ~= Enum.PlaybackState.Completed then return end

		-- Hiện ItemFrame
		if ItemFrame then ItemFrame.Visible = true end

		-- Fade về màu mặc định trong FadeDuration
		local FadeTweenInfo = TweenInfo.new(AnimCfg.FadeDuration or 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local FadeTween = TweenService:Create(TweenTarget, FadeTweenInfo, {
			BackgroundColor3       = _DefaultBgColor,
			BackgroundTransparency = _DefaultBgTransparency,
		})
		_ActiveTween = FadeTween
		FadeTween:Play()

		FadeTween.Completed:Connect(function(Pb2)
			if Pb2 ~= Enum.PlaybackState.Completed then return end
			_ActiveTween = nil
		end)
	end)
end

--- Animation mỗi lần bấm trong Pha 1: thu nhỏ → phóng to
--- Sau khi animation xong, nếu đủ 3 lần → chuyển Pha 2
local function PlayClickAnimation()
	CancelActiveTween()

	-- Tính 50% size mặc định
	local HalfSize = UDim2.new(
		_DefaultViewportSize.X.Scale  * 0.5,
		_DefaultViewportSize.X.Offset * 0.5,
		_DefaultViewportSize.Y.Scale  * 0.5,
		_DefaultViewportSize.Y.Offset * 0.5
	)

	local AnimCfg = GuiHelper.GetItemRewardAnimConfig(_CurrentChestId)

	-- Shrink: size hiện tại → 50%
	local ShrinkTween = TweenService:Create(
		ChestViewport,
		TweenInfo.new(
			AnimCfg.ChestShrinkDuration or 0.15,
			AnimCfg.ShrinkEasingStyle   or Enum.EasingStyle.Quad,
			AnimCfg.ShrinkEasingDir     or Enum.EasingDirection.Out
		),
		{ Size = HalfSize }
	)
	_ActiveTween = ShrinkTween
	ShrinkTween:Play()

	ShrinkTween.Completed:Connect(function(Pb)
		if Pb ~= Enum.PlaybackState.Completed then return end

		-- Expand: 50% → size mặc định (tạo hiệu ứng "bật lại")
		local ExpandTween = TweenService:Create(
			ChestViewport,
			TweenInfo.new(
				AnimCfg.ChestExpandDuration or 0.25,
				AnimCfg.ExpandEasingStyle   or Enum.EasingStyle.Back,
				AnimCfg.ExpandEasingDir     or Enum.EasingDirection.Out
			),
			{ Size = _DefaultViewportSize }
		)
		_ActiveTween = ExpandTween
		ExpandTween:Play()

		ExpandTween.Completed:Connect(function(Pb2)
			if Pb2 ~= Enum.PlaybackState.Completed then return end
			_ActiveTween = nil
			-- Kiểm tra xem có đủ 3 lần không để chuyển sang Pha 2
			if _State == "phase1" and _ClickCount >= 3 then
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

	_State          = "idle"
	_ClickCount     = 0
	_CurrentChestId = nil
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
	if _State ~= "idle" then DoReset() end

	local ChestEntry = ChestConfig.GetChest(ChestId)
	if not ChestEntry then
		warn(("[ItemRewardController] Không tìm thấy ChestId '%s' trong ChestConfig."):format(tostring(ChestId)))
		return
	end

	_CurrentChestId = ChestId

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
	_State      = "phase1"
	_ClickCount = 0

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

	local AnimCfg = GuiHelper.GetItemRewardAnimConfig(ChestId)

	-- Zoom-in ban đầu: 0 → size mặc định
	CancelActiveTween()
	local ZoomTween = TweenService:Create(
		ChestViewport,
		TweenInfo.new(
			AnimCfg.ChestZoomDuration or 0.4,
			AnimCfg.ZoomEasingStyle   or Enum.EasingStyle.Back,
			AnimCfg.ZoomEasingDir     or Enum.EasingDirection.Out
		),
		{ Size = _DefaultViewportSize }
	)
	_ActiveTween = ZoomTween
	ZoomTween:Play()
	ZoomTween.Completed:Connect(function(Pb)
		if Pb == Enum.PlaybackState.Completed then
			_ActiveTween = nil
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
	if _State ~= "idle" then DoReset() end

	_CurrentChestId = nil

	-- Clone items vào ItemFrame
	RenderItems(Items)

	-- Bỏ qua Pha 1, vào thẳng Pha 2
	_State      = "phase2"
	_ClickCount = 0

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
	Background    = IR:FindFirstChild("Background") or IR:WaitForChild("Background", 5)
	Effect        = IR:WaitForChild("Effect")
	ChestViewport = Effect:WaitForChild("ChestViewport")
	EffectImage   = Effect:WaitForChild("EffectImage")
	ItemFrame     = IR:WaitForChild("ItemFrame")
	ClickButton   = IR:WaitForChild("ClickButton")

	-- Ngăn GUI reset khi character chết/respawn
	SpecialGui.ResetOnSpawn = false

	-- Cache giá trị mặc định từ GUI instance (đọc từ Background nếu có, fallback ItemReward)
	_DefaultBgColor        = (Background and Background.BackgroundColor3) or ItemReward.BackgroundColor3
	_DefaultBgTransparency = (Background and Background.BackgroundTransparency) or ItemReward.BackgroundTransparency
	_DefaultViewportSize   = ChestViewport.Size
	_DefaultEffectRot      = EffectImage.Rotation

	-- Đặt trạng thái ban đầu
	ItemReward.BackgroundTransparency = 1
	if Background then
		Background.BackgroundColor3       = _DefaultBgColor
		Background.BackgroundTransparency = _DefaultBgTransparency
	end
	ItemReward.Visible = false
	Effect.Visible     = false
	ItemFrame.Visible  = false
	ClickButton.Active = false

	-- Kết nối ClickButton — lắng nghe suốt vòng đời, điều phối theo _State
	ClickButton.MouseButton1Click:Connect(function()
		if _State == "phase1" then
			-- Chặn click thứ 4+ trong Pha 1
			if _ClickCount >= 3 then return end
			_ClickCount = _ClickCount + 1

			-- Phát âm thanh click rương với âm lượng tăng dần theo từng lần click
			local ChestClickEntry = AudioConfig.ItemReward.ChestClick
			local Volumes = (ChestClickEntry and ChestClickEntry.Volumes) or AudioConfig.ItemReward.ChestClickVolumes
			local SoundVolume = (Volumes and Volumes[_ClickCount]) or 1
			PlaySound(ChestClickEntry, SoundVolume)

			-- Nếu đang animation thì reset animation (bắt đầu lại từ đầu shrink)
			PlayClickAnimation()

		elseif _State == "phase2" then
			-- Một click để đóng toàn bộ
			DoReset()
		end
		-- State == "idle": ClickButton.Active = false nên không kích hoạt được
	end)

	print("[ItemRewardController] Đã khởi tạo.")
end

return ItemRewardController
