# AudioSystem
> Tổng hợp kiến thức về hệ thống âm thanh, hoạt ảnh, tối ưu hóa độ trễ (zero-latency) và quản lý tài nguyên âm thanh trong dự án.
> Cập nhật lần cuối: 18-08-2026

---

## Kiến trúc

### Tập trung hóa cấu hình Audio & Animation (Single Source of Truth)
- **Ngày:** 18-08-2026
- **Chi tiết:** Tập trung toàn bộ ID âm thanh (BGM, GUI, SFX trận đấu, Shop, Quest, Accolades) vào `AudioConfig.lua` và hoạt ảnh vào `AnimationConfig.lua`. Loại bỏ hoàn toàn việc hardcode trong các controller, giúp dễ dàng điều chỉnh ID và mở rộng override theo skin.
- **File liên quan:** [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [AnimationConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnimationConfig.lua)

### Cơ chế Client-Side 3D Spatial Audio & Broadcast RemoteEvent
- **Ngày:** 18-08-2026
- **Chi tiết:** Thay vì Server tạo `Instance.new("Sound")` trong `workspace` rồi replicate qua mạng, Server chỉ gửi RemoteEvent gọn nhẹ (`PlayFreezeSFX`, `PlayThawSFX`) broadcast đến tất cả Client. Client tự phát Spatial Sound cục bộ trên máy của mình, triệt tiêu độ trễ mạng RTT (từ 0.3s - 0.7s về 0ms).
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### UI Sound Pooling & Zero-Latency Preload
- **Ngày:** 18-08-2026
- **Chi tiết:** Nạp trước 100% audio và animation vào RAM bằng `ContentProvider:PreloadAsync` khi vào game. Sử dụng Sound Pool tĩnh cho các âm thanh UI tần suất cao (Click, Hover, Close) bằng cách tái sử dụng Sound instance (`TimePosition = 0; :Play()`), loại bỏ áp lực rác bộ nhớ (Garbage Collection).
- **File liên quan:** [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [AnimationHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AnimationHelper.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua)

---

## Bug & biện pháp

### Âm thanh Freeze & Thaw bị trễ (Latency Delay)
- **Ngày:** 18-08-2026
- **Vấn đề:** Khi người chơi đóng băng đối thủ hoặc rã đông đồng minh, âm thanh phát ra trễ 0.3s - 0.7s so với lúc chém trúng.
- **Nguyên nhân:** Server tạo Sound instance mới mỗi lần chém rồi replicate qua mạng. Asset chưa được preload ở Client nên Client phải mất thời gian mạng RTT cộng thêm thời gian buffer audio từ CDN.
- **Fix:** Preload toàn bộ Audio khi khởi động game, chuyển logic phát 3D Spatial Sound về `SoundController.lua` phía Client khi nhận Broadcast RemoteEvent từ `FreezeService.lua`.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua)

### Crash Client do thiếu import Service trong Module Helper
- **Ngày:** 18-08-2026
- **Vấn đề:** Client crash với lỗi `attempt to index nil with 'Shared'` tại `AudioHelper.lua:7` và cascade lỗi sang `GuiHelper.lua`.
- **Nguyên nhân:** File helper gọi `require(ReplicatedStorage.Shared...)` nhưng quên khởi tạo biến `local ReplicatedStorage = game:GetService("ReplicatedStorage")`.
- **Fix:** Luôn khai báo đầy đủ các dịch vụ Roblox (`game:GetService`) ở đầu file trước khi gọi bất kỳ require nào từ service đó.
- **File liên quan:** [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### Hardcode SFX và lặp code phát Sound ở nhiều Controller
- **Ngày:** 18-08-2026
- **Vấn đề:** 8 Controller khác nhau tự khai báo biến `SFX_...` và tự viết hàm `PlayGuiSound` bằng `Instance.new("Sound")` + `Debris:AddItem`, gây rò rỉ và rác bộ nhớ.
- **Nguyên nhân:** Thiếu chuẩn hóa cấu hình tập trung và không tận dụng module dùng chung.
- **Fix:** Gom toàn bộ ID về `AudioConfig.lua`, chuẩn hóa các Controller gọi qua `AudioHelper.PlayGuiSound()` / `GuiHelper.PlayGuiSound()`.
- **File liên quan:** [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua)
