# QuestSystem
> Tổng hợp kiến thức về hệ thống nhiệm vụ (Quest System) bao gồm Daily Quest và Milestone Quest trong dự án.
> Cập nhật lần cuối: 27-07-2026

---

## Kiến trúc

### Thiết kế Delta-progress cho Quests
- **Ngày:** 28-06-2026
- **Chi tiết:** Để theo dõi tiến trình nhiệm vụ dựa trên các chỉ số sẵn có (`TotalFreezes`, `TotalWins`, `PlayTime`) mà không cần tạo nhiều biến đếm độc lập hay reset stat gốc khi hoàn thành, hệ thống sử dụng cơ chế mốc bắt đầu (`BaseProgress`). Tiến trình thực tế = `CurrentStat - BaseProgress`. Đối với Daily Quest, `BaseProgress` được chụp lại (snapshot) tại thời điểm reset daily.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### Cấu hình tùy chọn Reset tiến trình Milestone Quest (StackExcessProgress)
- **Ngày:** 25-07-2026
- **Chi tiết:** Mở rộng cơ chế mốc `BaseProgress` cho Milestone Quest với tùy chọn `StackExcessProgress` trong `QuestConfig.lua`. Khi `StackExcessProgress = false`, tại thời điểm claim, server gán `BaseProgress = CurrentStat` để reset tiến trình dôi dư về 0. Nếu `true`, server tịnh tiến `BaseProgress = BaseProgress + Requirement` để cộng dồn tiến trình dư vào chu kỳ tiếp theo.
- **File liên quan:** [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

### Quản lý trạng thái và hình nền động cho ClaimButton theo Config (ClaimButtonImages)
- **Ngày:** 25-07-2026
- **Chi tiết:** `ClaimButton` luôn hiển thị (`Visible = true`), quản lý hình nền động qua bảng cấu hình `QuestConfig.ClaimButtonImages` (`Uncompleted` và `Completed`). Khi chưa đạt chỉ tiêu: nền `Uncompleted`, khóa click; khi đạt chỉ tiêu: nền `Completed`, mở click; khi đã claim: nền `Completed`, khóa click, chữ hiển thị `"Claimed"`.
- **File liên quan:** [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Theo dõi PlayTime tối giản hiệu năng & Tính toán thời gian thực
- **Ngày:** 24-07-2026
- **Chi tiết:** Server lưu thời điểm join (`_sessionStart`). Khi tính toán `GetStatValue` cho `PlayTime`, server tự cộng thêm thời gian session hiện tại `(os.time() - _sessionStart[Player])`. Khi player rời game (`PlayerRemoving`), server mới cộng dồn hiệu số này vào DataStore để lưu trữ bền vững.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### Reset Daily 24h theo chu kỳ của từng Player
- **Ngày:** 28-06-2026
- **Chi tiết:** Chu kỳ 24h reset daily quest được tính toán độc lập cho mỗi người chơi dựa trên thời điểm join đầu tiên. Mỗi khi dữ liệu quest được yêu cầu, server kiểm tra `Now - ResetTimestamp >= 86400`. Nếu thỏa mãn, server random 5 quest từ bể cấu hình, snapshot stat hiện tại làm `BaseProgress` và lưu timestamp mới.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

### Đồng bộ hóa cấu trúc phân cấp và tên gọi UI Quest
- **Ngày:** 24-07-2026
- **Chi tiết:** Khi tái cấu trúc cây thư mục GUI (`StarterGui/Menu/Quest`), như đổi tên thư mục chứa template thành `Templates`, di chuyển `QuestList` vào trong `MainFrame`, và đổi tên các TextLabel, `QuestController` cần đồng bộ lại toàn bộ các phương thức `WaitForChild` và `FindFirstChild` tương ứng để tránh trỏ sai hoặc đứt gãy tham chiếu trong quá trình render/clone item.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Tích hợp đếm ngược thời gian Daily Quest và thông báo tĩnh Milestone Quest trên UI (NotificationText)
- **Ngày:** 24-07-2026
- **Chi tiết:** `NextResetTimestamp` được truyền từ `QuestService` xuống Client. `QuestController` dùng `task.spawn` đếm ngược `Time remain: [hh:mm:ss]` khi ở tab Daily, hiển thị text tĩnh `Repeatable quest` ở tab Milestone. Khi đếm ngược về `00:00:00`, Client tự động kích hoạt `RefreshQuestUI()` lấy dữ liệu mới mà không cần người chơi đóng/mở lại GUI.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

### Lưu kích thước GUI ban đầu thay vì hardcode (RewardAnnouncement)
- **Ngày:** 27-07-2026
- **Chi tiết:** Với các element GUI có animation zoom in/out, kích thước mục tiêu (TargetSize) phải được lấy từ GUI trong Studio, không hardcode trong code. Cách đúng: lưu `element.Size` vào biến riêng (`_originalSize`) ngay trong `Init()` trước khi ẩn element (`Visible = false`). Hàm animation đọc biến này thay vì gán cứng `UDim2.fromScale(...)`. Điều này cho phép designer thay đổi kích thước trong Studio mà không cần chỉnh code.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

---

## Bug & biện pháp

### Lỗi cú pháp thiếu đóng ngoặc nhọn table trong QuestConfig do chèn entry mới
- **Ngày:** 25-07-2026
- **Vấn đề:** Trình biên dịch Luau báo lỗi `Expected '}' (to close '{' at line 6), got 'return'` làm dừng quá trình require `QuestConfig` ở cả Client lẫn Server.
- **Nguyên nhân:** Khi thêm bảng `ClaimButtonImages` vào cuối `QuestConfig.lua`, phần ngoặc đóng `},` của bảng `Milestone` ở phía trước bị thiếu/ghi đè nhầm, khiến bảng chính chưa được đóng trước câu lệnh `return`.
- **Fix:** Bổ sung ngoặc đóng `},` cho bảng `Milestone` trước khi định nghĩa `ClaimButtonImages` để bảo toàn cấu trúc phân cấp table Luau.
- **File liên quan:** [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

### Reset trạng thái UI khi Player Respawn
- **Ngày:** 28-06-2026
- **Vấn đề:** Khi nhân vật bị chết và hồi sinh, giao diện menu Quest bị ẩn đi hoặc reset trạng thái, gây mất trải nghiệm người dùng.
- **Nguyên nhân:** Thuộc tính `ResetOnSpawn` của ScreenGui chứa Menu mặc định là `true`, khiến GUI bị nhân bản lại từ StarterGui mỗi khi spawn.
- **Fix:** Trong `QuestController:Init()`, đặt `ResetOnSpawn = false` cho ScreenGui parent của Menu.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Tiến trình Quest không cập nhật thời gian thực khi chơi và cuộn UI bị reset
- **Ngày:** 24-07-2026
- **Vấn đề:** Nhiệm vụ `PlayTime` không nhảy số trên GUI khi mở lên, chỉ khi thoát rồi vào lại mới thấy tiến trình. Ngoài ra xóa và render lại toàn bộ list khiến vị trí cuộn của ScrollingFrame nhảy về đầu.
- **Nguyên nhân:** `PlayTime` chỉ được ghi vào DataStore khi player thoát server. GUI client chỉ lấy dữ liệu 1 lần lúc mở và xóa sạch toàn bộ rồi clone lại mỗi lần render.
- **Fix:** Server tính dồn session trong `GetStatValue`. Client bật `StartAutoRefreshLoop()` poll 1s/lần khi GUI mở và áp dụng in-place update (chỉ sửa thuộc tính Frame cũ) để giữ nguyên `CanvasPosition`.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Kích thước RewardAnnouncement không thay đổi theo thiết kế trong Studio
- **Ngày:** 27-07-2026
- **Vấn đề:** Thay đổi kích thước `RewardAnnouncement` trong Studio không có tác dụng khi test — animation luôn zoom đến kích thước cố định.
- **Nguyên nhân:** `TargetSize` trong hàm `ShowRewardAnnouncement` bị hardcode là `UDim2.fromScale(0.4, 0.15)` thay vì đọc từ thuộc tính `Size` của element trong GUI.
- **Fix:** Lưu `_rewardOriginalSize = _rewardAnnouncement.Size` trong `Init()` trước khi ẩn element. Hàm animation sử dụng `_rewardOriginalSize` làm `TargetSize`. Sau khi animation zoom out hoàn tất, khôi phục lại `Size = TargetSize` để giữ trạng thái đúng cho các lần hiển thị tiếp theo.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)
