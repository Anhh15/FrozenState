-- SpectateController.lua (ModuleScript)
-- Quản lý chế độ Spectate: cho phép Spectator (không có team) quan sát
-- người chơi đang trong trận bằng Orbit Camera
-- Cycling qua danh sách target bằng Next/Back buttons
-- Tự động tắt khi phase rời InGame hoặc danh sách target rỗng

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- =========================================================
-- GUI REFERENCES
-- =========================================================

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Camera      = workspace.CurrentCamera

-- Menu GUI (Spectate nằm trong Menu)
local MenuGui     = PlayerGui:WaitForChild("Menu", 10)
local SpectateGui = MenuGui and MenuGui:WaitForChild("Spectate", 10)

-- NavigationButton GUI (ẩn khi spectate)
local NavGui      = PlayerGui:WaitForChild("NavigationButton", 10)

-- Spectate GUI elements
local CloseButton      = SpectateGui and SpectateGui:WaitForChild("CloseButton", 5)
local NextButton       = SpectateGui and SpectateGui:WaitForChild("NextButton", 5)
local BackButton       = SpectateGui and SpectateGui:WaitForChild("BackButton", 5)
local PlayerNameFrame  = SpectateGui and SpectateGui:WaitForChild("PlayerName", 5)
local PlayerNameText   = PlayerNameFrame and PlayerNameFrame:WaitForChild("PlayerNameText", 5)

-- Nút Spectate trong NavigationButton
local NavButtons       = NavGui and NavGui:WaitForChild("Button", 5)
local SpectateButton   = NavButtons and NavButtons:WaitForChild("Spectate", 5)

-- =========================================================
-- STATE
-- =========================================================

local _isSpectating       = false   -- Đang trong chế độ spectate?
local _targetList         = {}      -- Danh sách Player objects Normal (từ server)
local _currentIndex       = 1       -- Vị trí hiện tại trong vòng lặp
local _savedCameraSubject = nil     -- Lưu CameraSubject gốc để restore
local _currentPhase       = "Intermission"  -- Cache phase hiện tại

-- =========================================================
-- PRIVATE: Camera
-- =========================================================

--- Hướng camera Orbit vào target player
local function FocusOnTarget(TargetPlayer)
	if not TargetPlayer then return end

	local Character = TargetPlayer.Character
	if not Character then return end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	Camera.CameraSubject = Humanoid
end

--- Khôi phục camera về nhân vật của LocalPlayer
local function RestoreCamera()
	if _savedCameraSubject then
		Camera.CameraSubject = _savedCameraSubject
		_savedCameraSubject = nil
	else
		-- Fallback: khôi phục về Humanoid của LocalPlayer
		local Character = LocalPlayer.Character
		if Character then
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			if Humanoid then
				Camera.CameraSubject = Humanoid
			end
		end
	end
end

-- =========================================================
-- PRIVATE: Display
-- =========================================================

--- Cập nhật tên người đang được quan sát
local function UpdatePlayerNameDisplay()
	if not PlayerNameText then return end

	if #_targetList == 0 or _currentIndex > #_targetList then
		PlayerNameText.Text = ""
		return
	end

	local Target = _targetList[_currentIndex]
	if Target and Target:IsDescendantOf(Players) then
		PlayerNameText.Text = Target.DisplayName .. " (@" .. Target.Name .. ")"
	else
		PlayerNameText.Text = ""
	end
end

--- Chuyển camera sang target hiện tại
local function ApplyCurrentTarget()
	if #_targetList == 0 then return end

	-- Đảm bảo index hợp lệ
	if _currentIndex > #_targetList then
		_currentIndex = 1
	end
	if _currentIndex < 1 then
		_currentIndex = #_targetList
	end

	FocusOnTarget(_targetList[_currentIndex])
	UpdatePlayerNameDisplay()
end

-- =========================================================
-- PRIVATE: Cycling
-- =========================================================

local function CycleNext()
	if not _isSpectating or #_targetList == 0 then return end
	_currentIndex = (_currentIndex % #_targetList) + 1
	ApplyCurrentTarget()
end

local function CycleBack()
	if not _isSpectating or #_targetList == 0 then return end
	_currentIndex = ((_currentIndex - 2) % #_targetList) + 1
	ApplyCurrentTarget()
end

-- =========================================================
-- PRIVATE: Target List Update
-- =========================================================

--- Xử lý khi server gửi danh sách Spectate mới
local function OnSpectateListUpdated(NormalPlayers)
	_targetList = NormalPlayers or {}

	if not _isSpectating then return end

	-- Nếu danh sách rỗng → tự động tắt spectate
	if #_targetList == 0 then
		-- Gọi SetVisible qua pcall để tránh stack overflow nếu có edge case
		task.defer(function()
			local SpectateController = require(script)
			SpectateController.SetVisible(false)
		end)
		return
	end

	-- Kiểm tra target hiện tại còn trong danh sách không
	local CurrentTarget = nil
	if _currentIndex >= 1 and _currentIndex <= #_targetList then
		-- Index cũ có thể đã shift, cần tìm lại
	end

	-- Tìm player đang focus trong danh sách mới
	local CurrentSubject = Camera.CameraSubject
	local FoundIndex = nil

	if CurrentSubject then
		for i, Player in ipairs(_targetList) do
			local Character = Player.Character
			if Character then
				local Humanoid = Character:FindFirstChildOfClass("Humanoid")
				if Humanoid == CurrentSubject then
					FoundIndex = i
					break
				end
			end
		end
	end

	if FoundIndex then
		-- Target vẫn còn, cập nhật index
		_currentIndex = FoundIndex
		UpdatePlayerNameDisplay()
	else
		-- Target đã biến mất → chuyển sang người kế tiếp
		if _currentIndex > #_targetList then
			_currentIndex = 1
		end
		ApplyCurrentTarget()
	end
end

-- =========================================================
-- PUBLIC API
-- =========================================================

local SpectateController = {}

--- Bật/tắt chế độ Spectate
--- @param Visible boolean
function SpectateController.SetVisible(Visible)
	if Visible then
		-- Kiểm tra điều kiện bật
		local MyTeam = LocalPlayer:GetAttribute("Team")
		if MyTeam then
			-- Đang trong trận (có team) → không thể spectate
			return
		end

		if _currentPhase ~= "InGame" then
			-- Không phải phase InGame → không thể spectate
			return
		end

		if #_targetList == 0 then
			-- Không có ai để quan sát
			return
		end

		-- Bật spectate
		_isSpectating = true
		_currentIndex = 1

		-- Lưu camera hiện tại
		_savedCameraSubject = Camera.CameraSubject

		-- Hiện Spectate GUI, ẩn NavigationButton
		if SpectateGui then SpectateGui.Visible = true end
		if NavGui then NavGui.Enabled = false end

		-- Ẩn các Frame khác trong Menu (Inventory, Profile, Shop)
		if MenuGui then
			for _, Child in ipairs(MenuGui:GetChildren()) do
				if Child:IsA("Frame") or Child:IsA("ScreenGui") then
					if Child ~= SpectateGui then
						Child.Visible = false
					end
				end
			end
		end

		-- Focus vào target đầu tiên
		ApplyCurrentTarget()

		print("[SpectateController] Chế độ Spectate đã bật.")
	else
		-- Tắt spectate
		if not _isSpectating and not (SpectateGui and SpectateGui.Visible) then
			return
		end

		_isSpectating = false

		-- Ẩn Spectate GUI, hiện lại NavigationButton
		if SpectateGui then SpectateGui.Visible = false end
		if NavGui then NavGui.Enabled = true end

		-- Khôi phục camera
		RestoreCamera()

		print("[SpectateController] Chế độ Spectate đã tắt.")
	end
end

-- =========================================================
-- INIT
-- =========================================================

function SpectateController:Init()
	-- Đảm bảo Spectate GUI ẩn lúc khởi tạo
	if SpectateGui then SpectateGui.Visible = false end

	-- Kết nối nút Spectate trong NavigationButton
	if SpectateButton then
		if SpectateButton:IsA("GuiButton") then
			SpectateButton.MouseButton1Click:Connect(function()
				SpectateController.SetVisible(true)
			end)
		end
	end

	-- Kết nối các nút điều khiển
	if CloseButton then
		CloseButton.MouseButton1Click:Connect(function()
			SpectateController.SetVisible(false)
		end)
	end

	if NextButton then
		NextButton.MouseButton1Click:Connect(function()
			CycleNext()
		end)
	end

	if BackButton then
		BackButton.MouseButton1Click:Connect(function()
			CycleBack()
		end)
	end

	-- Lắng nghe danh sách Spectate từ server
	local UpdateSpectateListEvent = RemoteDefinitions.GetEvent("UpdateSpectateList")
	UpdateSpectateListEvent.OnClientEvent:Connect(OnSpectateListUpdated)

	-- Lắng nghe phase game để auto-close khi rời InGame
	local UpdateGameStateEvent = RemoteDefinitions.GetEvent("UpdateGameState")
	UpdateGameStateEvent.OnClientEvent:Connect(function(Data)
		if not Data then return end
		local Phase = Data.Phase or "Intermission"
		_currentPhase = Phase

		-- Tự động tắt spectate khi phase rời InGame
		if _isSpectating and Phase ~= "InGame" then
			SpectateController.SetVisible(false)
		end
	end)

	-- Tự động tắt spectate khi player được phân team
	LocalPlayer:GetAttributeChangedSignal("Team"):Connect(function()
		local MyTeam = LocalPlayer:GetAttribute("Team")
		if MyTeam and _isSpectating then
			SpectateController.SetVisible(false)
		end
	end)

	print("[SpectateController] Đã khởi tạo.")
end

return SpectateController
