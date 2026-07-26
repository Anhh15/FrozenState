# ItemRewardSystem
> Tổng hợp kiến thức về hệ thống hiệu ứng mở rương và hiển thị phần thưởng item trong dự án.
> Cập nhật lần cuối: 27-07-2026

---

## Kiến trúc

### Module độc lập ItemRewardController — tách khỏi ShopController
- **Ngày:** 27-07-2026
- **Chi tiết:** Toàn bộ logic hiệu ứng mở rương được đặt trong `ItemRewardController.lua` riêng biệt thay vì gộp vào ShopController. Điều này cho phép tái sử dụng từ nhiều nguồn (Shop, Quest, Event) mà không sửa controller nguồn. ShopController và QuestController chỉ cần lazy-require để gọi API công khai.
- **File liên quan:** [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [ShopController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### API 2 pha: ShowChestReward vs ShowItemReward
- **Ngày:** 27-07-2026
- **Chi tiết:** Hệ thống chia làm 2 API riêng. `ShowChestReward(ReceivedItems, ChestId)` chạy Pha 1 (hiệu ứng rương + click x3) + Pha 2 (hiển thị item). `ShowItemReward(Items)` bỏ qua Pha 1, vào thẳng Pha 2 — dùng khi nhận item trực tiếp từ quest hoặc event, không cần hiệu ứng mở rương. Cả hai API đều nhận Items với format tối thiểu `{ ItemId, Type }`.
- **File liên quan:** [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### Phần thưởng trao trước hiệu ứng (Reward-First Pattern)
- **Ngày:** 27-07-2026
- **Chi tiết:** Server trao vật phẩm/tiền ngay khi nhận request mua rương, TRƯỚC khi client kích hoạt hiệu ứng. `ShowChestReward` nhận `Result.ReceivedItems` (đã có vật phẩm thực tế) và chỉ đóng vai trò thẩm mĩ. Nếu người chơi thoát giữa chừng hoặc vào trận, vật phẩm vẫn an toàn do đã được trao. Response từ `BuyChest` RemoteFunction: `{ Success, ReceivedItems: [{ItemId, WasDuplicate, Refund}], RefundAmount, NewMoney }`.
- **File liên quan:** [ShopService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/ShopService.lua), [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### Đọc defaults từ GUI instance, không hardcode
- **Ngày:** 27-07-2026
- **Chi tiết:** Các tham số `BackgroundColor3`, `BackgroundTransparency` của ItemReward Frame và `Size` của ChestViewport được đọc và cache trong `Init()` từ GUI instance thực tế. Khi Reset(), giá trị được khôi phục từ cache này. Chỉ cần chỉnh Studio để thay đổi thông số, không cần đụng code.
- **File liên quan:** [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### State machine và logic click Pha 1
- **Ngày:** 27-07-2026
- **Chi tiết:** State machine: `idle → phase1 → phase2 → idle`. Trong Pha 1, người chơi bấm tối đa 3 lần, mỗi lần kích hoạt animation shrink (50% size, 0.15s Quad) → expand (100% size, 0.25s Back Out). Nếu click trong lúc animation đang chạy → `CancelActiveTween()` rồi bắt đầu lại từ shrink. Lần thứ 4+ bị block (`_clickCount >= 3`). Sau khi animation lần 3 hoàn thành → sang Pha 2. Xoay `EffectImage` bằng `RunService.Heartbeat` (72°/s), disconnect trong `Reset()`.
- **File liên quan:** [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### Reset khẩn cấp qua GameStateController khi vào trận
- **Ngày:** 27-07-2026
- **Chi tiết:** `GameStateController.SetLobbyGuisVisible(false)` lazy-require `ItemRewardController` và gọi `Reset()` — nhất quán với cách đóng Inventory/Shop/Profile. `Reset()` hủy tất cả Tween, disconnect RunService, xóa clone trong ViewportFrame và ItemFrame, khôi phục defaults, đặt lại state về `idle`. Không ảnh hưởng đến vật phẩm đã được trao trước đó.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### Items format và suy diễn Type từ ChestConfig
- **Ngày:** 27-07-2026
- **Chi tiết:** Mảng `ReceivedItems` từ `ShopService` không chứa `Type` của item (chỉ có `ItemId`, `WasDuplicate`, `Refund`). `ShowChestReward` tra cứu `ChestConfig.GetChest(ChestId)` để lấy `ChestEntry.Type` và gắn vào từng item trước khi render. Với `ShowItemReward`, caller phải cung cấp `Type` trong mỗi item entry vì không có ChestId tham chiếu. Format tối thiểu: `{ ItemId: string, Type: string }`.
- **File liên quan:** [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [ChestConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/ChestConfig.lua)

---

## Bug & biện pháp

_(Không có bug gặp phải trong quá trình triển khai — hệ thống hoạt động trơn tru)_
