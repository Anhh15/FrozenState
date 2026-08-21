# InGameExperience
> Tổng hợp kiến thức về hệ thống HUD in-game (PlayerStatus, ScoreBoard, Accolades) và cơ chế thông báo danh hiệu.
> Cập nhật lần cuối: 20-08-2026

---

## Kiến trúc

### Tách biệt Controller cho các thành phần HUD
- **Ngày:** 12-07-2026
- **Chi tiết:** Chia giao diện in-game thành 3 controller độc lập (`PlayerStatusController`, `ScoreBoardController`, `AccoladesController`) giúp tối ưu hóa quản lý giao diện, dễ bảo trì độc lập và tuân thủ nguyên lý đơn nhiệm (Single Responsibility).
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua)

### Đồng bộ hóa dữ liệu ScoreBoard qua payload Event mở rộng
- **Ngày:** 12-07-2026
- **Chi tiết:** Thay vì sử dụng một remote event riêng hoặc broadcast toàn bộ bảng điểm, mở rộng payload của `UpdatePlayerState` truyền thêm dữ liệu `Freezes` và `Thaws` count của player thay đổi. Client-side tự cập nhật phần tử tương ứng trong ScoreBoard giúp tiết kiệm băng thông và tài nguyên xử lý.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### Chuẩn hóa Animation Pop và Sound Pool cho AccoladesAnnouncement
- **Ngày:** 20-08-2026 (Cập nhật từ 12-07-2026)
- **Chi tiết:** Thay thế toàn bộ hoạt ảnh zoom `UDim2.Size` và ghost label cũ bằng hiệu ứng `Pop` chuẩn hóa dựa trên `UIScale` (`GuiHelper.PopOpen`/`PopClose`) với cấu hình tập trung trong `GuiConfig.Animations.Accolades` (`OpenDuration = 0.25s`, `DisplayDuration = 1.5s`, `CloseDuration = 0.2s`). Phát âm thanh danh hiệu qua Sound Pool tĩnh `GuiHelper.PlayGuiSound` thay cho việc tạo `Sound` instance động, triệt tiêu độ trễ âm thanh về 0ms và không sinh rác bộ nhớ khi người chơi đạt spree liên tiếp.
- **File liên quan:** [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua)

### Phản ánh trực quan trạng thái Frozen/Dead trên PlayerStatus qua màu sắc
- **Ngày:** 20-08-2026
- **Chi tiết:** Thay vì phụ thuộc vào icon con `FrozenStatus` dễ bị khuất trên thumbnail nhỏ, toàn bộ màu sắc được quản lý tập trung trong `GuiConfig.PlayerStatus`. Khi nhận `UpdatePlayerState`, controller tự động đổi `BackgroundColor3` và `ImageColor3` của `AvatarThumbnail` sang màu xám `#868686` khi người chơi `Frozen` hoặc `Dead`. Khi được giải cứu (`Normal`), màu nền và màu ảnh lập tức khôi phục về màu phe (`AllyColor` / `EnemyColor`) và màu ảnh gốc `#FFFFFF`.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### Thuật toán sắp xếp tự động ScoreBoard theo thành tích (LayoutOrder Weighting)
- **Ngày:** 20-08-2026
- **Chi tiết:** Sắp xếp danh sách người chơi trên ScoreBoard theo thứ tự ưu tiên: người có tổng `Freezes + Thaws` cao nhất đứng trên đầu bảng, nếu bằng nhau thì ưu tiên người có nhiều `Freezes` hơn. Sử dụng công thức tính trọng số số nguyên: `LayoutOrder = -((Freezes + Thaws) * 1000 + Freezes)` kết hợp ép `SortOrder = Enum.SortOrder.LayoutOrder` trên `UIListLayout`/`UIGridLayout`. Thẻ người chơi tự động nhảy vị trí mượt mà thời gian thực mà không cần render lại danh sách.
- **File liên quan:** [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

---

## Bug & biện pháp

### Tránh nghẽn UI khi load nhiều ảnh Thumbnail người chơi
- **Ngày:** 12-07-2026
- **Vấn đề:** Khi bắt đầu trận đấu, tải đồng thời avatar thumbnail của nhiều người chơi qua `Players:GetUserThumbnailAsync` có thể làm nghẽn luồng xử lý chính của Client-side.
- **Nguyên nhân:** Hàm `GetUserThumbnailAsync` thực hiện gọi API web của Roblox và block luồng hiện tại cho đến khi có kết quả.
- **Fix:** Bọc lời gọi trong `task.spawn` để thực hiện bất đồng bộ (asynchronous), tránh block luồng giao diện chính.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### Lỗi không hiển thị Avatar khi clone Template trong Studio
- **Ngày:** 13-07-2026
- **Vấn đề:** PlayerStatus và ScoreBoard clone template thành công (background color hiển thị) nhưng AvatarThumbnail hoàn toàn trống (không có ảnh).
- **Nguyên nhân:** 
  1. `GetUserThumbnailAsync` trả về một tuple `(url, isReady)`. Code check `if Ok and Clone.Parent` nhưng luồng `task.spawn` khi yield có thể gặp tình trạng `Clone.Parent` bị đánh giá là nil nếu gán Parent trễ.
  2. Môi trường Roblox Studio Play Solo đôi khi không thể tải hoặc trả về chuỗi trống từ CDN thumbnail.
- **Fix:** Thiết lập `Clone.Parent` trước khi spawn luồng tải ảnh, đảm bảo gán `.Image` trực tiếp và hỗ trợ kiểm tra `IsReady` để retry nếu cần.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### PlayerStatus không phản ánh người chơi bị đóng băng hoặc bị loại
- **Ngày:** 20-08-2026
- **Vấn đề:** Trong lúc thi đấu, người chơi không biết ai trong đội hoặc đối thủ đang bị đóng băng hoặc đã chết nếu không chủ động mở ScoreBoard.
- **Nguyên nhân:** Thumbnail `PlayerStatus` có kích thước nhỏ, thiếu cơ chế đổi màu trực quan khi nhận tín hiệu thay đổi trạng thái từ server.
- **Fix:** Đưa bảng màu vào `GuiConfig.PlayerStatus`, lắng nghe `UpdatePlayerState` và cập nhật đồng bộ `BackgroundColor3` cùng `ImageColor3` sang `#868686` khi `Frozen`/`Dead`, khôi phục màu gốc khi `Normal`.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)


