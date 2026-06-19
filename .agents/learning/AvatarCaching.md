# AvatarCaching
> Tổng hợp kiến thức về tối ưu hiển thị mô hình 3D người chơi lên ViewportFrame bằng bộ nhớ đệm trong dự án.
> Cập nhật lần cuối: 11-06-2026

---

## Kiến trúc

### Hệ thống bộ đệm Avatar (Avatar Caching) trên Server
- **Ngày:** 11-06-2026
- **Chi tiết:** Để loại bỏ độ trễ và lỗi mạng khi gọi API `Players:CreateHumanoidModelFromUserId()` ở cuối trận đấu, Server chuẩn bị sẵn model tĩnh của mọi người chơi ngay khi họ tham gia game (`PlayerAdded`) và lưu trữ trong `ReplicatedStorage.PlayerAvatars`. Model được chuyển thành tĩnh bằng cách Anchor tất cả BasePart và xóa bỏ các component động (Script, Animator, Sound). Khi trận đấu kết thúc, Client chỉ việc clone tức thời từ thư mục này để đưa vào ViewportFrame. Dữ liệu đệm tự động bị dọn dẹp khi người chơi thoát (`PlayerRemoving`).
- **File liên quan:** [AvatarCacheService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/AvatarCacheService.lua), [ServiceLoader.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/ServiceLoader.lua)

---

## Bug & biện pháp

### Đồng hồ đếm ngược GameOver bị lỗi nhấp nháy, xen kẽ 6 và 0
- **Ngày:** 11-06-2026
- **Vấn đề:** Giai đoạn GameOver đếm ngược hiển thị bất thường, thời gian nhảy xen kẽ liên tục giữa thời gian còn lại thực tế và 0.
- **Nguyên nhân:** Do server chạy song song đếm ngược và tạo model Top Player ở cuối trận. Để tránh race condition khi model chưa tạo xong, server gửi tín hiệu giữ trạng thái GameOver ở 0 giây. Việc gửi song song này gây xung đột bộ đếm.
- **Fix:** Thay thế bằng cơ chế Avatar Caching từ lúc join game, giúp loại bỏ việc tải/tạo model ở cuối trận. Nhờ đó, khôi phục lại vòng lặp đếm ngược 6 giây tuyến tính tiêu chuẩn mà không cần cơ chế giữ thời gian (hold-at-zero) phức tạp.
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Không hiển thị mô hình Top Player trong Studio do ID âm
- **Ngày:** 11-06-2026
- **Vấn đề:** Khi thử nghiệm chế độ nhiều người chơi trong Studio (Local Server), khung ViewportFrame của các Top Player hoàn toàn trống.
- **Nguyên nhân:** Khách chơi thử trong Studio có `UserId` âm. Logic cũ chỉ gọi render khi `userId > 0` và API của Roblox không hỗ trợ tải model từ ID âm.
- **Fix:** Sửa điều kiện kiểm tra từ `userId > 0` thành `userId ~= 0`. Trong `AvatarCacheService.lua`, nếu phát hiện `UserId <= 0`, Server sẽ đợi Character tải xong (`HasAppearanceLoaded`), sau đó clone Character hiện tại làm model dự phòng.
- **File liên quan:** [AvatarCacheService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/AvatarCacheService.lua), [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)
