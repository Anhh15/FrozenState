# InGameExperience
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về trải nghiệm giao diện thi đấu trong trận (PlayerStatus, ScoreBoard, Accolades, FrozenStateAnnouncement, Custom Hotbar và Phân phối HUD theo GameMode).
> Cập nhật lần cuối: 03-09-2026

---

## Kiến trúc

### 1. Tách biệt Controller cho các Thành Phần HUD Thi Đấu
- **Chi tiết:** Chia giao diện in-game thành các controller độc lập:
  - `PlayerStatusController`: Hiển thị thanh danh sách đồng minh/kẻ địch thu nhỏ trên màn hình cùng trạng thái sống/đóng băng.
  - `ScoreBoardController`: Bảng điểm chi tiết thành tích toàn trận (Freezes, Thaws) và nút toggle `ScoreBoardButton`.
  - `AccoladesController`: Biểu ngữ thông báo danh hiệu hạ gục liên tiếp (Freezing Spree, Thawing Spree, First Blood...).
  - `FrozenStateAnnouncementController`: Biểu ngữ thông báo và SFX khi trận đấu chuyển sang trạng thái Frozen State.
- **Lợi ích:** Dễ bảo trì, tuân thủ chặt chẽ nguyên lý đơn nhiệm (Single Responsibility) và tối ưu hóa hiệu năng render.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua), [FrozenStateAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/FrozenStateAnnouncementController.lua)

### 2. Đồng bộ Dữ liệu ScoreBoard qua Payload Event Mở Rộng
- **Chi tiết:** Thay vì sử dụng một RemoteEvent riêng làm tăng traffic mạng, hệ thống mở rộng payload của sự kiện `UpdatePlayerState` truyền thêm dữ liệu `Freezes` và `Thaws`. Client tự cập nhật phần tử tương ứng trong ScoreBoard giúp tiết kiệm băng thông tối đa.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### 3. Thuật toán Sắp Xếp ScoreBoard Tự Động bằng Trọng Số LayoutOrder
- **Chi tiết:** Sắp xếp danh sách người chơi trên ScoreBoard theo thứ tự ưu tiên: Tổng `Freezes + Thaws` cao nhất đứng trên đầu bảng; nếu bằng nhau ưu tiên người có nhiều `Freezes` hơn.
- **Công thức trọng số:**
  $$\text{LayoutOrder} = -\left((\text{Freezes} + \text{Thaws}) \times 1000 + \text{Freezes}\right)$$
- **Hiệu năng:** Kết hợp với `UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder`, thẻ người chơi tự động đổi vị trí mượt mà trong thời gian thực mà không cần xóa và render lại danh sách.
- **File liên quan:** [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### 4. Phản ánh Trực quan Trạng thái Frozen/Dead trên PlayerStatus
- **Chi tiết:** Màu sắc trạng thái được quản lý tập trung trong `GuiConfig.PlayerStatus`. Khi nhận sự kiện `UpdatePlayerState`, controller tự động đổi `BackgroundColor3` và `ImageColor3` của `AvatarThumbnail` sang màu xám xỉn `#868686` khi người chơi `Frozen` hoặc `Dead`. Khi được giải cứu (`Normal`), màu nền và màu ảnh khôi phục về màu phe (`AllyColor` / `EnemyColor`) và màu ảnh gốc `#FFFFFF`.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 5. Chuẩn hóa Animation Pop và Sound Pool cho Accolades
- **Chi tiết:** Hoạt ảnh biểu ngữ danh hiệu sử dụng hiệu ứng `Pop` chuẩn hóa trên `UIScale` (`GuiHelper.PopOpen`/`PopClose`) với cấu hình trong `GuiConfig.Animations.Accolades` (`OpenDuration = 0.25s`, `DisplayDuration = 1.5s`, `CloseDuration = 0.2s`). Phát âm thanh danh hiệu qua Sound Pool tĩnh `GuiHelper.PlayGuiSound`, triệt tiêu hoàn toàn độ trễ âm thanh và không sinh rác bộ nhớ khi người chơi đạt spree liên tiếp.
- **File liên quan:** [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 6. Đồng bộ Phân phối HUD theo Cấu hình GameMode
- **Chi tiết:** `GameStateController` lắng nghe `SetGameMode` để lấy cấu hình hiển thị (`PlayerStatusType`, `ScoreboardType`). Khi hiển thị HUD thi đấu, controller áp dụng điều kiện kết hợp `ShowGameplayHud and (_type ~= "Disabled")` để tránh việc vô tình kích hoạt các UI con đã bị vô hiệu hóa bởi chế độ chơi (ví dụ: tắt PlayerStatus trong một số chế độ đặc thù).
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GameModeConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameModeConfig.lua)

### 7. Phân Quyền Hiển Thị & Tương Tác HUD Thi Đấu Theo IsInMatch SSOT
- **Chi tiết:** Phân định rạch ròi giữa HUD quan sát toàn cục (`PlayerStatus`) và HUD thi đấu chủ động (`InGameGui/Buttons`, `ScoreBoard`):
  - `PlayerStatus`: Hiển thị cho cả Spectator và người trong trận để theo dõi diễn biến 2 đội.
  - `ButtonsFrame` (`ScoreBoardButton`, `SpectateButton`) và `ScoreBoard`: Ràng buộc chặt chẽ theo `IsInMatch(LocalPlayer) == true`.
  - `ScoreBoardController` đăng ký `ObserveMatchState` để tự động đóng ScoreBoard ngay khi người chơi bị loại (`State == "Dead"`, `IsInMatch == false`) và chặn toàn bộ phím tắt (`Ctrl`, `R1`, Mobile button) khi không còn trong trận.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)

### 8. Kiến trúc Custom Hotbar & Vô Hiệu Hóa CoreGui Backpack Mặc Định
- **Chi tiết:** Tắt hoàn toàn CoreGui Backpack của Roblox bằng pcall retry (`StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)`) để ngăn chặn việc người chơi mở kho đồ mặc định kéo thả/vứt vũ khí làm vỡ logic gameplay. Xây dựng controller độc lập `HotbarController` quản lý thanh hotbar trong `InGameGui`.
- **Quản lý Vòng đời & Tương tác:** Tự động clone `ItemSlot` từ folder `Templates` cục bộ cho từng Tool trong Backpack/Character. Hỗ trợ phím tắt 1..9 (`UserInputService`) và Click/Touch để Toggle Equip/Unequip qua `Humanoid:EquipTool()` / `Humanoid:UnequipTools()`. Khi người chơi bị `Frozen` hoặc `Dead`, hệ thống khóa toàn bộ tương tác và tự động thu hồi vũ khí trên tay.
- **Render Model 3D:** Sử dụng `ViewportManager.RenderItem()` để tự động render model 3D vào `ItemViewport` của từng slot, đồng bộ theo skin trang bị hiện tại.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua)

### 9. Phân Tách Thuộc Tính Thẩm Mỹ GUI (Studio First) và Đồng Bộ Hoạt Ảnh Cooldown
- **Chi tiết:** Tuân thủ nguyên lý tách biệt trách nhiệm: 100% thuộc tính thẩm mỹ tĩnh (màu nền `BackgroundColor3`, màu rèm `CooldownCurtain`, viền `UIStroke`, bo góc `UICorner`, font chữ) được định hình trực tiếp trong Roblox Studio trên template `ItemSlot`. Code và `GuiConfig` chỉ quản lý tham số hoạt ảnh động (`InactiveScale = 1.0`, `ActiveScale = 1.3`, `ScaleDuration = 0.15s`, `InactiveBackgroundTrans = 0.8`, `ActiveBackgroundTrans = 0.4`).
- **Cơ chế Cooldown Decoupled:** `IcicleScript` gán thuộc tính `IsOnCooldown` và `CooldownEndTime` lên Tool khi kích hoạt. `HotbarController` lắng nghe reactive qua `GetAttributeChangedSignal("IsOnCooldown")` để kích hoạt rèm `CooldownCurtain` neo ở đáy (`Size.Y.Scale = 1.0 -> 0.0`) kèm chữ đếm ngược số giây `CooldownText`.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 10. Điều Phối Thông Báo Frozen State & State Transition Guard
- **Chi tiết:** Quản lý hiệu ứng biểu ngữ và âm thanh khi trận đấu bước vào trạng thái Frozen State qua `FrozenStateAnnouncementController`:
  - Hoạt ảnh `Pop` trên `UIScale` (`GuiHelper.PopOpen`/`PopClose`) với cấu hình trong `GuiAnimConfig.Animations.FrozenStateAnnouncement` (`OpenDuration = 0.25s`, `DisplayDuration = 1.5s`, `CloseDuration = 0.2s`).
  - Phát SFX qua `AudioHelper.PlayGuiSound(AudioConfig.Special.FrozenStateAnnouncement)` nạp từ Sound Pool.
  - **State Transition Guard:** Client lắng nghe `UpdateGameStateEvent` nhưng chỉ kích hoạt visual/SFX khi có bước chuyển trạng thái thực sự (`CurrentIsFrozenState == true and not _LastIsFrozenState`), tránh hoàn toàn việc bị kích hoạt lại theo chu kỳ đếm giây (1s/lần) của server.
- **File liên quan:** [FrozenStateAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/FrozenStateAnnouncementController.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [GuiAnimConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiAnimConfig.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 11. Kiến trúc Bọc Nút Đa Nền Tảng Tàng Hình (Transparent Button Wrapper Pattern) Cho Hotbar Slot
- **Chi tiết:** Chuyển đổi `ItemSlot` từ `Frame` sang `ImageButton` hoàn toàn tàng hình (`BackgroundTransparency = 1`, `ImageTransparency = 1`), đóng vai trò như một wrapper bắt tương tác độc quyền cho ô phím tắt:
  - Cho phép lắng nghe trực tiếp sự kiện `Activated`, tối ưu hóa nhận diện thao tác tap trên màn hình cảm ứng Mobile (không bị trượt ngón tay/camera drag) và hỗ trợ điều hướng tay cầm Gamepad (`Selectable = true`).
  - Bảo toàn 100% cấu trúc phân tầng thẩm mỹ Studio bên trong: Frame con `Background` vẫn đảm nhận tween độ mờ khi rút vũ khí (`BackgroundTransparency = 0.8 -> 0.4`), tách biệt hoàn toàn giữa layer nhận sự kiện (Wrapper) và layer hiển thị (Visual).
  - Áp dụng cơ chế truy xuất đa hình `GuiObject` (`FindFirstChildWhichIsA("GuiObject")`) trong `ResolveGuiReferences` để tương thích linh hoạt dù template là `Frame` hay `ImageButton`.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Tránh Nghẽn UI Luồng Chính Khi Nạp Nhiều Ảnh Thumbnail Người Chơi
- **Vấn đề:** Khi bắt đầu trận đấu, việc tải đồng thời avatar thumbnail của nhiều người chơi qua `Players:GetUserThumbnailAsync` làm nghẽn luồng xử lý chính của Client.
- **Nguyên nhân:** Hàm `GetUserThumbnailAsync` thực hiện gọi API web của Roblox và block luồng hiện tại cho đến khi nhận được kết quả.
- **Giải pháp:** Bọc toàn bộ lời gọi trong `task.spawn` để thực hiện bất đồng bộ (asynchronous), giải phóng luồng giao diện chính.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### 2. Lỗi Không Hiển Thị Avatar Khi Clone Template Trong Môi Trường Studio
- **Vấn đề:** PlayerStatus và ScoreBoard clone template thành công nhưng AvatarThumbnail bị trống ảnh.
- **Nguyên nhân:** Khối `task.spawn` tải ảnh bất đồng bộ được gọi trước khi gán `Clone.Parent`. Khi luồng tải xong, `Clone.Parent` có thể chưa được gắn vào GUI cha. Ngoài ra, trong môi trường Studio test, `UserId` có giá trị âm (`-1`, `-2`) khiến CDN Roblox từ chối phục vụ ảnh.
- **Giải pháp:** Luôn gán `Clone.Parent` trước khi spawn luồng tải ảnh và bổ sung fallback gán `TargetUserId = 1` khi `UserId <= 0` cho môi trường Studio.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### 3. Lỗi ScoreBoard Trống Trơn ở Trận Đấu Đầu Tiên Do Race Condition
- **Vấn đề:** ScoreBoard bị trống hoàn toàn và HUD hiển thị avatar xếp sai đội cho người chơi ở trận đầu tiên.
- **Nguyên nhân:** Race condition giữa sự kiện RemoteEvent `SetTeamAssignment` và việc đồng bộ thuộc tính `"Team"` (Property Replication), dẫn đến việc Client kiểm tra `LocalPlayer:GetAttribute("Team")` trả về `nil` ngay tại thời điểm nhận event.
- **Giải pháp:** Lấy thông tin team của LocalPlayer trực tiếp từ payload `Teams` gửi kèm trong sự kiện (`Teams[tostring(LocalPlayer.UserId)]`) thay vì đọc qua attribute.
- **File liên quan:** [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua)

### 4. Rò rỉ Nút HUD Thi Đấu cho Spectator và Lỗi Người Chết Vẫn Bật Được ScoreBoard
- **Vấn đề:** Spectator ở Sảnh bị hiện cụm nút `InGameGui/Buttons` nhưng không thể tương tác; người chơi trong trận sau khi chết/bị loại vẫn bấm được phím tắt để mở `ScoreBoard`.
- **Nguyên nhân:**
  1. `GameStateController` chỉ kiểm tra phase (`IsInGamePhase`) mà bỏ qua `IsInMatch` khi bật `ButtonsFrame` và `ScoreBoardButton`.
  2. `ScoreBoardController` kiểm tra `GetTeam` thay vì `IsInMatch`. Khi player chết, server set `InMatch = false` nhưng giữ `Team` attribute để tổng kết cuối trận, khiến người chết lọt qua kiểm tra.
- **Giải pháp:**
  1. Gán điều kiện hiển thị `ShowGameplayHud and IsInMatch` cho `ButtonsFrame` và `ScoreBoardButton`.
  2. Dùng `PlayerStateHelper.IsInMatch(LocalPlayer)` làm điều kiện tiên quyết duy nhất cho `SetScoreBoardVisible` và tự động đóng board qua `ObserveMatchState`.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)

### 5. Đóng Gói Template Cục Bộ (Frame Templates) Thay Vì Gom Chung Vào ScreenGui
- **Vấn đề:** Phân vân giữa việc gom tất cả template của các frame trong `InGameGui` vào chung 1 folder `Templates` cấp ScreenGui hay giữ phân tán trong từng Frame.
- **Nguyên nhân:** Gom chung vào ScreenGui làm mất tính đóng gói component (khi di chuyển/ẩn/hiện Frame thì template bị thất lạc), tăng nguy cơ xung đột tên (Name Collision giữa các thẻ generic như `ItemTemplate`) và phá vỡ cấu trúc của các controller hiện hữu (`PlayerStatus`, `ScoreBoard`).
- **Giải pháp:** Mỗi Frame (`Hotbar`, `PlayerStatus`, `ScoreBoard`) tự quản lý folder `Templates`/`Template` cục bộ của riêng nó. Folder không phải là `GuiObject` nên `UIListLayout` tự động bỏ qua, không gây xáo trộn bố cục.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### 6. Xung Đột Bố Cục UIListLayout và Thứ Tự Hiển Thị Khi Zoom Scale 1.3x
- **Vấn đề:** Khi ô Hotbar chuyển sang trạng thái Active và zoom phóng to 1.3x (tăng 30% kích thước), ô có nguy cơ chèn đè lên mép các slot lân cận và bị các ô bên cạnh che khuất viền.
- **Giải pháp:** Thiết lập `AnchorPoint = Vector2.new(0.5, 0.5)` cho `ItemSlot` để khi scale nở đều từ tâm mà không lệch trục; đặt `Padding` trong `UIListLayout` đủ rộng (tối thiểu 16px) và tự động nâng `ZIndex = 10` cho ô đang active (khôi phục `ZIndex = 1` khi Inactive).
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 7. Lỗi Giật Cục / Nhấp Nháy Hotbar Do Chu Kỳ UpdateDisplay 1s, Phase Tick & Equip Transition
- **Vấn đề:** Hotbar liên tục bị xóa và tạo lại mỗi giây, gây nhấp nháy, giật cục scale ($1.0 \to 1.3$) khi trang bị hoặc khi đang cầm/sử dụng vũ khí và ngắt quãng hoạt ảnh rèm/chữ Cooldown trên màn hình.
- **Nguyên nhân:**
  1. *Lặp theo chu kỳ 1 giây*: `GameStateController:UpdateDisplay` được gọi mỗi giây theo sự kiện `UpdateGameState`. `HotbarController.SetVisible` thiếu Idempotency Guard kết hợp `ShouldShow` nên mỗi giây đều thực thi `RefreshHotbar()`, xóa sạch toàn bộ slot (`ClearAllSlots`), hủy mọi tween và Cooldown thread.
  2. *Lặp theo Phase Tick*: Listener `UpdateGameState` trong `HotbarController` không lọc theo `_lastPhase`, dẫn đến việc re-render mỗi giây khi nhận phase `InGame`.
  3. *Equip/Unequip Transition*: Khi Tool đổi container giữa `Backpack` và `Character`, các listener `ChildAdded` gọi `RefreshHotbar()` trực tiếp thay vì chỉ để `SyncTools` và `Tool.AncestryChanged` xử lý tween Active Visual mượt mà.
  4. *Đứt đoạn Cooldown & Animation lặp*: Khi slot bị xóa và dựng lại giữa chừng, `IsOnCooldown` attribute không thay đổi khiến animation không tự kích hoạt lại và không có cơ chế khôi phục thời gian còn lại. Ngoài ra, thiếu bộ lọc `LastIsEquipped` khiến animation scale $1.3$ bị phát lại liên tục khi kiểm tra trạng thái.
- **Giải pháp triệt để:**
  1. Thêm Idempotency Guard chặt chẽ trong `SetVisible(Visible)`: `if _isVisible == Visible and _HotbarFrame and _HotbarFrame.Visible == ShouldShow then return end`.
  2. Thiết lập bộ lọc chuyển phase `_lastPhase` trong `UpdateGameStateEvent`: chỉ thực thi khi phase thực sự thay đổi.
  3. Bổ sung bộ lọc `LastIsEquipped` trong `UpdateSlotActiveVisual`: nếu trạng thái trang bị không thay đổi và scale đã đạt đích thì không phát lại tween.
  4. Loại bỏ hoàn toàn `RefreshHotbar()` trực tiếp trong `ChildAdded`/`ChildRemoved` của `Backpack` và `Character`; chỉ kích hoạt `task.defer(SyncTools)` để nhận diện tool mới hoặc tool bị xóa.
  5. Trong `PlayCooldownAnimation()`, tính toán chiều cao rèm `CurrentScaleY = math.clamp(Remaining / CooldownDuration, 0, 1)` và tween mượt mà theo `Remaining`.
  6. Trong `CreateSlotForTool()`, tự động kiểm tra `IsOnCooldown == true` và `CooldownEndTime > os.clock()` để khôi phục ngay hoạt ảnh Cooldown còn lại.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### 8. Lỗi Mất Hotbar Slot & Rò Rỉ Event Listener Giữa Các Vòng Đấu & Xử lý Trạng thái Frozen/Thaw
- **Vấn đề:** 
  1. Khi bị `Frozen`, Hotbar vẫn hiển thị nguyên vẹn gây nhầm lẫn là có thể dùng; sau khi được `Thaw`, người chơi không thể rút vũ khí ra tay dù Balo có Tool.
  2. Sang trận thứ 2, Hotbar không render Slot dù Tool đã được cấp vào Balo khi chuyển sang `InGame`.
- **Nguyên nhân:**
  1. *Frozen/Thaw Lifecycle*: Khi bị Freeze, Tool cũ bị destroy trên Server và Tool mới được cấp khi Thaw. HotbarController không ẩn giao diện lúc Freeze và không tự động re-bind tham chiếu ô Slot cho Tool mới khi nhận trạng thái `Normal`.
  2. *Multi-Round Phase Tick*: `HotbarController` bật từ phase `Ready` khi Balo rỗng. Đến phase `InGame`, cờ debounce `_isVisible == true` chặn `SetVisible` quét lại Tool, trong khi Tool vừa được cấp chưa kịp replication tại frame đầu của event `InGame`.
- **Giải pháp:**
  1. *Quản lý hiển thị tổng hợp theo trạng thái*: `SetVisible(Visible)` tính toán `ShouldShow = Visible and (not _IsFrozen) and (not _IsDead)`. Khi `State == "Frozen"` hoặc `"Dead"`, tự động cất vũ khí và ẩn `_HotbarFrame.Visible = false`. Khi nhận `State == "Normal"` trong trận, tự động bật lại `_HotbarFrame.Visible = true` và kích hoạt `task.defer(HotbarController.RefreshHotbar)`.
  2. *Nạp vũ khí đầu trận 2*: Trong `UpdateGameStateEvent` tại phase `InGame`, tự động kích hoạt `RefreshHotbar()` và kết nối `Backpack.ChildAdded` gọi `SyncTools()` để phát hiện và nạp ngay khi Tool xuất hiện từ Server.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### 9. Lỗi Lặp SFX & Hoạt Ảnh Pop Do Chu Kỳ Server Broadcast GameState 1 Giây
- **Vấn đề:** Khi trận đấu kích hoạt Frozen State, âm thanh SFX và hiệu ứng Pop của TextLabel thông báo bị kích hoạt lặp đi lặp lại liên tục mỗi 1 giây làm giật UI và chói tai người chơi.
- **Nguyên nhân:** `MatchService` chạy vòng lặp đếm ngược mỗi giây (`for t = Duration, 0, -1 do BroadcastGameState("InGame", t, FrozenStateOn) task.wait(1) end`). Trong suốt thời gian Frozen State diễn ra, mỗi giây Server đều broadcast gói tin có `IsFrozenState = true`. Client nếu chỉ kiểm tra `if Data.IsFrozenState then` sẽ bị trigger liên tục theo từng nhịp tick.
- **Giải pháp:** Thiết lập State Transition Guard với bộ đệm `_LastIsFrozenState = false`. Chỉ kích hoạt visual/SFX khi phát hiện bước chuyển trạng thái `CurrentIsFrozenState == true and not _LastIsFrozenState` trong phase `InGame`. Tự động khôi phục `_LastIsFrozenState = false` khi trạng thái tắt hoặc khi ván đấu kết thúc / chuyển phase.
- **File liên quan:** [FrozenStateAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/FrozenStateAnnouncementController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 10. Bẫy Nuốt Input của Phần Tử Con (Child Input Sinking) và Xung Đột Tag Hoạt Ảnh Trên Custom Hotbar
- **Vấn đề:** 
  1. Khi `ItemSlot` chuyển sang `GuiButton`, người chơi click vào slot nhưng không thể rút vũ khí, đặc biệt là khi đang trong thời gian Cooldown hoặc nhấp trúng icon/chữ số.
  2. Nếu gán Tag interaction của `CollectionService` (`GuiConfig.Tags`), slot bị tụt scale về $1.0\text{x}$ sau khi rê chuột ra ngoài dù vũ khí vẫn đang trang bị ($1.3\text{x}$).
  3. Khi click nút, Roblox tự động áp một lớp filter màu xám tối làm biến dạng màu sắc thiết kế của slot.
- **Nguyên nhân:**
  1. Các phần tử con đè lên trên (`ItemImage`, `CooldownCurtain`, `IndexLabel`) có thuộc tính `Active = true` mặc định, khiến chúng nuốt chửng sự kiện chuột/chạm trước khi tới `ImageButton` cha.
  2. `GuiHelper.InitTagInteractions` can thiệp tween `UIScale` khi `MouseEnter`/`MouseLeave`, xung đột trực tiếp với Active Zoom ($1.3\text{x}$) do `HotbarController` kiểm soát.
  3. `ImageButton` mặc định bật `AutoButtonColor = true`.
- **Giải pháp:**
  1. Trong `CreateSlotForTool()`, tự động ép `Active = false` cho toàn bộ các phần tử con (`IndexLabel`, `CooldownCurtain`, `CooldownText`, `ItemImage`).
  2. Cách ly hoàn toàn `ItemSlot` khỏi hệ thống Tag chung của `GuiHelper`, giữ quyền quản lý `UIScale` độc quyền cho `HotbarController`.
  3. Tự động thiết lập `ClickTarget.AutoButtonColor = false` ngay khi khởi tạo slot.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

