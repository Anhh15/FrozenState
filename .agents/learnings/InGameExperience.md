# InGameExperience
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về trải nghiệm giao diện thi đấu trong trận (PlayerStatus, ScoreBoard, Accolades, Custom Hotbar và Phân phối HUD theo GameMode).
> Cập nhật lần cuối: 28-08-2026

---

## Kiến trúc

### 1. Tách biệt Controller cho các Thành Phần HUD Thi Đấu
- **Chi tiết:** Chia giao diện in-game thành các controller độc lập:
  - `PlayerStatusController`: Hiển thị thanh danh sách đồng minh/kẻ địch thu nhỏ trên màn hình cùng trạng thái sống/đóng băng.
  - `ScoreBoardController`: Bảng điểm chi tiết thành tích toàn trận (Freezes, Thaws) và nút toggle `ScoreBoardButton`.
  - `AccoladesController`: Biểu ngữ thông báo danh hiệu hạ gục liên tiếp (Freezing Spree, Thawing Spree, First Blood...).
- **Lợi ích:** Dễ bảo trì, tuân thủ chặt chẽ nguyên lý đơn nhiệm (Single Responsibility) và tối ưu hóa hiệu năng render.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua)

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

### 7. Lỗi Giật Cục / Nhấp Nháy Hotbar Do Chu Kỳ UpdateDisplay 1s & Equip Transition
- **Vấn đề:** Hotbar liên tục bị xóa và tạo lại mỗi giây, gây nhấp nháy, giật cục scale (1.0 $\rightarrow$ 1.3) và làm kẹt rèm/chữ Cooldown trên màn hình.
- **Nguyên nhân:**
  1. Khi Equip/Unequip, Tool đổi container giữa `Backpack` và `Character`, kích hoạt `ChildAdded`/`ChildRemoved` khiến toàn bộ Slot bị xóa và dựng lại liên tục.
  2. Template trong Studio đang để `Visible = true` cho CooldownCurtain/Text nhưng code không ép ẩn ban đầu lúc clone.
- **Giải pháp:**
  1. Thiết lập hàm `SyncTools()` chỉ tái tạo Hotbar khi danh sách Tool thực tế thay đổi (thêm mới/xóa hẳn). Chuyển động Equip/Unequip chỉ thuần túy kích hoạt `UpdateSlotActiveVisual` qua `Tool.AncestryChanged`.
  2. Ép ẩn `CooldownCurtain.Visible = false`, `CooldownCurtain.Size = UDim2.new(1, 0, 0, 0)` và `CooldownText.Visible = false` ngay khi tạo slot.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### 8. Lỗi Mất Hotbar Slot & Rò Rỉ Event Listener Giữa Các Vòng Đấu
- **Vấn đề:** Sang trận thứ 2, Hotbar không render Slot dù Tool đã được cấp vào Balo, hoặc sau khi nhân vật respawn thì Hotbar bị mất kết nối.
- **Nguyên nhân:**
  1. `HotbarController` bật từ phase `Ready` khi Balo rỗng. Đến phase `InGame`, cờ debounce `_isVisible == true` chặn `SetVisible` quét lại Tool.
  2. `_InGameGui` thiếu `ResetOnSpawn = false` khiến tham chiếu GUI bị hỏng khi nhân vật hồi sinh.
  3. `BindCharacter` không dọn dẹp kết nối `Backpack.ChildAdded` cũ khi nhân vật hồi sinh, gây duplicate listener hoặc mất kết nối.
- **Giải pháp:**
  1. Luôn thực thi `RefreshHotbar()` khi `SetVisible(true)` và tự động refresh khi Tool xuất hiện trong `Backpack.ChildAdded` / `Character.ChildAdded`.
  2. Thêm `_InGameGui.ResetOnSpawn = false` và hàm `HotbarController.ResetState()` tự động gọi khi đổi phase (`Setup`, `Ready`, `InGame`, `Intermission`).
  3. Quản lý toàn bộ listeners của `Backpack`/`Character` qua mảng `_characterConnections` và ngắt kết nối an toàn (`Disconnect`) trước khi bind nhân vật mới.
- **File liên quan:** [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

