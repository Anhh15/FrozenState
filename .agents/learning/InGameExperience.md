# InGameExperience
> Tổng hợp kiến thức về hệ thống HUD in-game (PlayerStatus, ScoreBoard, Accolades) và cơ chế thông báo danh hiệu.
> Cập nhật lần cuối: 13-07-2026

---

## Kiến trúc

### Tách biệt Controller cho các thành phần HUD
- **Ngày:** 12-07-2026
- **Chi tiết:** Chia giao diện in-game thành 3 controller độc lập (`PlayerStatusController`, `ScoreBoardController`, `AccoladesController`) giúp tối ưu hóa quản lý giao diện, dễ bảo trì độc lập và tuân thủ nguyên lý đơn nhiệm (Single Responsibility).
- **File liên quan:** [PlayerStatusController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [AccoladesController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua)

### Đồng bộ hóa dữ liệu ScoreBoard qua payload Event mở rộng
- **Ngày:** 12-07-2026
- **Chi tiết:** Thay vì sử dụng một remote event riêng hoặc broadcast toàn bộ bảng điểm, mở rộng payload của `UpdatePlayerState` truyền thêm dữ liệu `Freezes` và `Thaws` count của player thay đổi. Client-side tự cập nhật phần tử tương ứng trong ScoreBoard giúp tiết kiệm băng thông và tài nguyên xử lý.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [ScoreBoardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### Giao tiếp thông báo danh hiệu cá nhân bằng NotifyAccolade
- **Ngày:** 12-07-2026
- **Chi tiết:** Sử dụng Remote Event `NotifyAccolade` truyền trực tiếp xuống client cụ thể (First Blood, Spree) thay vì broadcast. Client nhận thông báo này tự kích hoạt tween hiệu ứng (zoom thực và zoom ảo ghost song song) và phát âm thanh tại chỗ, giúp giảm thiểu tải mạng cho các người chơi khác không liên quan.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [AccoladesController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua)

---

## Bug & biện pháp

### Tránh nghẽn UI khi load nhiều ảnh Thumbnail người chơi
- **Ngày:** 12-07-2026
- **Vấn đề:** Khi bắt đầu trận đấu, tải đồng thời avatar thumbnail của nhiều người chơi qua `Players:GetUserThumbnailAsync` có thể làm nghẽn luồng xử lý chính của Client-side.
- **Nguyên nhân:** Hàm `GetUserThumbnailAsync` thực hiện gọi API web của Roblox và block luồng hiện tại cho đến khi có kết quả.
- **Fix:** Bọc lời gọi trong `task.spawn` để thực hiện bất đồng bộ (asynchronous), tránh block luồng giao diện chính.
- **File liên quan:** [PlayerStatusController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### Lỗi không hiển thị Avatar khi clone Template trong Studio
- **Ngày:** 13-07-2026
- **Vấn đề:** PlayerStatus và ScoreBoard clone template thành công (background color hiển thị) nhưng AvatarThumbnail hoàn toàn trống (không có ảnh).
- **Nguyên nhân:** 
  1. `GetUserThumbnailAsync` trả về một tuple `(url, isReady)`. Code check `if Ok and Clone.Parent` nhưng luồng `task.spawn` khi yield có thể gặp tình trạng `Clone.Parent` bị đánh giá là nil nếu gán Parent trễ.
  2. Môi trường Roblox Studio Play Solo đôi khi không thể tải hoặc trả về chuỗi trống từ CDN thumbnail.
- **Fix:** Thiết lập `Clone.Parent` trước khi spawn luồng tải ảnh, đảm bảo gán `.Image` trực tiếp và hỗ trợ kiểm tra `IsReady` để retry nếu cần.
- **File liên quan:** [PlayerStatusController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)
