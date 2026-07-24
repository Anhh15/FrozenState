# QuestSystem
> Tổng hợp kiến thức về hệ thống nhiệm vụ (Quest System) bao gồm Daily Quest và Milestone Quest trong dự án.
> Cập nhật lần cuối: 24-07-2026

---

## Kiến trúc

### Thiết kế Delta-progress cho Quests
- **Ngày:** 28-06-2026
- **Chi tiết:** Để theo dõi tiến trình nhiệm vụ dựa trên các chỉ số sẵn có (`TotalFreezes`, `TotalWins`, `PlayTime`) mà không cần tạo nhiều biến đếm độc lập hay reset stat gốc khi hoàn thành, hệ thống sử dụng cơ chế mốc bắt đầu (`BaseProgress`). Tiến trình thực tế = `CurrentStat - BaseProgress`. Khi người chơi claim Milestone Quest (lặp vô hạn), server chỉ cần tịnh tiến mốc này lên (`BaseProgress = BaseProgress + Requirement`). Đối với Daily Quest, `BaseProgress` được chụp lại (snapshot) tại thời điểm reset daily.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [DataService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/DataService.lua)

### Theo dõi PlayTime tối giản hiệu năng
- **Ngày:** 28-06-2026
- **Chi tiết:** Để đo đạc thời gian chơi của player phục vụ cho các quest thời gian mà không gây tải cho server bởi các vòng lặp định kỳ (Heartbeat loop), hệ thống lưu thời điểm join vào bộ nhớ tạm của server (`_sessionStart`). Khi player rời game (`PlayerRemoving`), server tính toán hiệu số thời gian thực tế đã chơi trong session đó và cộng dồn trực tiếp vào thuộc tính `PlayTime` trong DataStore của người chơi.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [DataService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/DataService.lua)

### Reset Daily 24h theo chu kỳ của từng Player
- **Ngày:** 28-06-2026
- **Chi tiết:** Chu kỳ 24h reset daily quest được tính toán độc lập cho mỗi người chơi dựa trên thời điểm join đầu tiên của họ. Mỗi khi dữ liệu quest được yêu cầu tải, server kiểm tra điều kiện `Now - ResetTimestamp >= 86400`. Nếu thỏa mãn, server thực hiện random 5 quest từ cấu hình bể nhiệm vụ, gán snapshot stat hiện tại làm `BaseProgress` cho từng quest và lưu timestamp mới.
- **File liên quan:** [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/QuestService.lua), [QuestConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

### Đồng bộ hóa cấu trúc phân cấp và tên gọi UI Quest
- **Ngày:** 24-07-2026
- **Chi tiết:** Khi tái cấu trúc cây thư mục GUI (`StarterGui/Menu/Quest`), như đổi tên thư mục chứa template thành `Templates`, di chuyển `QuestList` vào trong `MainFrame`, và đổi tên các TextLabel (`QuestText` -> `DescriptionText`, `Amount` -> `AmountText`), `QuestController` cần đồng bộ lại toàn bộ các phương thức `WaitForChild` và `FindFirstChild` tương ứng để tránh bị trỏ sai hoặc đứt gãy tham chiếu trong quá trình render/clone item.
- **File liên quan:** [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

---

## Bug & biện pháp

### Reset trạng thái UI khi Player Respawn
- **Ngày:** 28-06-2026
- **Vấn đề:** Khi nhân vật của người chơi bị chết và hồi sinh, giao diện menu Quest bị ẩn đi hoặc reset trạng thái, gây mất trải nghiệm người dùng.
- **Nguyên nhân:** Thuộc tính `ResetOnSpawn` của ScreenGui chứa Menu mặc định là `true`, khiến GUI bị nhân bản lại từ StarterGui mỗi khi spawn.
- **Fix:** Tại hàm khởi tạo của Client Controller (`QuestController:Init()`), đặt thuộc tính `ResetOnSpawn` của ScreenGui (Parent của Menu) thành `false`.
- **File liên quan:** [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)
