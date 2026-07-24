# QuestSystem
> Tổng hợp kiến thức về hệ thống nhiệm vụ (Quest System) bao gồm Daily Quest và Milestone Quest trong dự án.
> Cập nhật lần cuối: 24-07-2026

---

## Kiến trúc

### Thiết kế Delta-progress cho Quests
- **Ngày:** 28-06-2026
- **Chi tiết:** Để theo dõi tiến trình nhiệm vụ dựa trên các chỉ số sẵn có (`TotalFreezes`, `TotalWins`, `PlayTime`) mà không cần tạo nhiều biến đếm độc lập hay reset stat gốc khi hoàn thành, hệ thống sử dụng cơ chế mốc bắt đầu (`BaseProgress`). Tiến trình thực tế = `CurrentStat - BaseProgress`. Khi người chơi claim Milestone Quest (lặp vô hạn), server chỉ cần tịnh tiến mốc này lên (`BaseProgress = BaseProgress + Requirement`). Đối với Daily Quest, `BaseProgress` được chụp lại (snapshot) tại thời điểm reset daily.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [DataService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/DataService.lua)

### Theo dõi PlayTime tối giản hiệu năng & Tính toán thời gian thực
- **Ngày:** 24-07-2026
- **Chi tiết:** Để đo đạc thời gian chơi của player phục vụ cho các quest thời gian mà không cần chạy loop cộng dồn liên tục vào DataStore, server lưu thời điểm join (`_sessionStart`). Khi tính toán `GetStatValue` cho `PlayTime`, server tự động cộng thêm thời gian session hiện tại `(os.time() - _sessionStart[Player])`. Đồng thời khi player rời game (`PlayerRemoving`), server mới cộng dồn hiệu số này vào DataStore để lưu trữ bền vững.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [DataService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/DataService.lua)

### Reset Daily 24h theo chu kỳ của từng Player
- **Ngày:** 28-06-2026
- **Chi tiết:** Chu kỳ 24h reset daily quest được tính toán độc lập cho mỗi người chơi dựa trên thời điểm join đầu tiên của họ. Mỗi khi dữ liệu quest được yêu cầu tải, server kiểm tra điều kiện `Now - ResetTimestamp >= 86400`. Nếu thỏa mãn, server thực hiện random 5 quest từ cấu hình bể nhiệm vụ, gán snapshot stat hiện tại làm `BaseProgress` cho từng quest và lưu timestamp mới.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [QuestConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

### Đồng bộ hóa cấu trúc phân cấp và tên gọi UI Quest
- **Ngày:** 24-07-2026
- **Chi tiết:** Khi tái cấu trúc cây thư mục GUI (`StarterGui/Menu/Quest`), như đổi tên thư mục chứa template thành `Templates`, di chuyển `QuestList` vào trong `MainFrame`, và đổi tên các TextLabel (`QuestText` -> `DescriptionText`, `Amount` -> `AmountText`), `QuestController` cần đồng bộ lại toàn bộ các phương thức `WaitForChild` và `FindFirstChild` tương ứng để tránh bị trỏ sai hoặc đứt gãy tham chiếu trong quá trình render/clone item.
- **File liên quan:** [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Tích hợp đếm ngược thời gian Daily Quest và thông báo tĩnh Milestone Quest trên UI (NotificationText)
- **Ngày:** 24-07-2026
- **Chi tiết:** Đơn giản hóa việc hiển thị thời gian reset Daily Quest bằng cách truyền `NextResetTimestamp` (`ResetTimestamp + ResetSeconds`) từ `QuestService` xuống Client trong payload `GetQuestData`. Phía `QuestController` sử dụng luồng `task.spawn` đếm ngược hiển thị `Time remain: [hh:mm:ss]` khi ở tab Daily, và dừng loop hiển thị text tĩnh `Repeatable quest` khi sang tab Milestone. Khi đếm ngược về `00:00:00`, Client tự động kích hoạt `RefreshQuestUI()` lấy dữ liệu chu kỳ 24h mới từ Server mà không cần người chơi đóng/mở lại GUI.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [QuestConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

---

## Bug & biện pháp

### Reset trạng thái UI khi Player Respawn
- **Ngày:** 28-06-2026
- **Vấn đề:** Khi nhân vật của người chơi bị chết và hồi sinh, giao diện menu Quest bị ẩn đi hoặc reset trạng thái, gây mất trải nghiệm người dùng.
- **Nguyên nhân:** Thuộc tính `ResetOnSpawn` của ScreenGui chứa Menu mặc định là `true`, khiến GUI bị nhân bản lại từ StarterGui mỗi khi spawn.
- **Fix:** Tại hàm khởi tạo của Client Controller (`QuestController:Init()`), đặt thuộc tính `ResetOnSpawn` của ScreenGui (Parent của Menu) thành `false`.
- **File liên quan:** [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Tiến trình Quest không cập nhật thời gian thực khi chơi và cuộn UI bị reset
- **Ngày:** 24-07-2026
- **Vấn đề:** Nhiệm vụ thời gian chơi (`PlayTime`) không nhảy số trên GUI khi mở lên, chỉ khi thoát game rồi vào lại mới thấy tiến trình. Ngoài ra việc xóa và render lại toàn bộ list khiến vị trí cuộn của ScrollingFrame bị nhảy về đầu.
- **Nguyên nhân:** `PlayTime` chỉ được ghi vào DataStore khi người chơi thoát server (`PlayerRemoving`). Đồng thời GUI client chỉ lấy dữ liệu `GetQuestData` 1 lần lúc mở và xóa sạch GUI rồi clone lại mỗi lần render.
- **Fix:** Server tính dồn thời gian session trực tiếp trong `GetStatValue` (`PlayTime + os.time() - _sessionStart`). Client bật `StartAutoRefreshLoop()` poll Server 1s/lần khi GUI đang mở và áp dụng in-place update UI (chỉ sửa thuộc tính Frame cũ nếu đã có) để giữ nguyên `CanvasPosition`.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)
