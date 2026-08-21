# InGameExperience
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về trải nghiệm giao diện thi đấu trong trận (PlayerStatus, ScoreBoard, Accolades và Phân phối HUD theo GameMode).
> Cập nhật lần cuối: 21-08-2026

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
