# AudioAndAnimation
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống âm thanh và hoạt ảnh (AudioConfig, AnimationConfig, Sound Pooling, Client-Side Spatial Audio, Preload và Memory Cleanup).
> Cập nhật lần cuối: 21-08-2026

---

## Kiến trúc

### 1. Tập trung hóa Cấu hình Audio & Animation (Single Source of Truth)
- **Chi tiết:** Tách bạch hoàn toàn giữa hệ thống âm thanh và hoạt ảnh để tránh lai tạp cấu hình:
  - `AudioConfig.lua`: Tập trung 100% Sound IDs (BGM Lobby/InGame/GameOver, SFX trận đấu Freeze/Thaw/Swing, GUI SFX Click/Hover/Close, Shop/Chest/Quest/Accolades) và cấu hình âm lượng mặc định.
  - `AnimationConfig.lua`: Quản lý Animation IDs (Swing, Pose, Idle), Animation Priority (`Action`, `Movement`), và thời lượng cửa sổ quét va chạm (`HitStartTime`, `HitEndTime`) cho từng skin vũ khí.
- **File liên quan:** [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [AnimationConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnimationConfig.lua)

### 2. Client-Side 3D Spatial Audio & Broadcast RemoteEvent (Triệt tiêu độ trễ 0ms)
- **Chi tiết:** Thay vì Server tạo `Instance.new("Sound")` trong `Workspace` rồi replicate qua mạng cho toàn bộ client (gây độ trễ từ 0.3s - 0.7s do network RTT và buffer CDN), Server chỉ phát RemoteEvent gọn nhẹ (`PlayFreezeSFX`, `PlayThawSFX`) broadcast đến các Client.
- **Client Local Playback:** Client tự phát Spatial Sound cục bộ trên máy của mình gắn vào Part/Character tương ứng, triệt tiêu hoàn toàn độ trễ âm thanh.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### 3. UI Sound Pooling & Zero-Latency Preload
- **Chi tiết:** Nạp trước toàn bộ audio và animation vào bộ nhớ Client bằng `ContentProvider:PreloadAsync` khi vào game.
- **Sound Pool tĩnh:** Sử dụng Sound Pool tĩnh (`_guiSoundPool`) cho các âm thanh UI tần suất cao (Click, Hover, Close, Coin count) qua `AudioHelper.PlayGuiSound()` / `GuiHelper.PlayGuiSound()`. Tái sử dụng các instance Sound có sẵn bằng cách đặt `TimePosition = 0; :Play()`, loại bỏ hoàn toàn áp lực rác bộ nhớ (Garbage Collection).
- **File liên quan:** [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 4. Tự Dọn Dẹp Sound Instance Động bằng Sound.Ended:Once()
- **Chi tiết:** Với các âm thanh phát động 3D/2D một lần, `AudioHelper.PlaySpatialSound()` và `Play2DSound()` tạo instance và kết nối `Sound.Ended:Once(function() Sound:Destroy() end)` kết hợp timeout fallback phòng thủ (`task.delay(Length + 1)`). Pattern này đảm bảo Sound tự dọn dẹp ngay khi phát xong, loại bỏ hoàn toàn nguy cơ rò rỉ bộ nhớ âm thanh.
- **File liên quan:** [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### 5. Chuẩn hóa Animation Loading qua Animator
- **Chi tiết:** Loại bỏ phương thức lỗi thời `Humanoid:LoadAnimation()` (deprecated). Toàn bộ hoạt ảnh được nạp thông qua `Animator:LoadAnimation()` trên `Humanoid.Animator` hoặc `AnimationController.Animator`, kết hợp cache `AnimationTrack` để tái sử dụng và giải phóng khi nhân vật respawn.
- **File liên quan:** [AnimationHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AnimationHelper.lua), [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Âm thanh Freeze & Thaw Bị Trễ Nhịp (Latency Delay)
- **Vấn đề:** Khi người chơi đóng băng đối thủ hoặc giải cứu đồng minh, âm thanh phát ra trễ 0.3s - 0.7s so với lúc chém trúng.
- **Nguyên nhân:** Server tạo Sound instance mới mỗi lần chém rồi replicate qua mạng. Asset chưa được preload ở Client nên tốn thời gian mạng RTT cộng thêm thời gian tải audio từ CDN.
- **Giải pháp:** Preload toàn bộ Audio khi khởi động game, chuyển logic phát 3D Spatial Sound về `SoundController.lua` phía Client khi nhận Broadcast RemoteEvent từ `FreezeService.lua`.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua)

### 2. Mất Âm thanh Swing ở Lần Vung Vũ khí Đầu Tiên Do Khởi tạo Sound Động
- **Vấn đề:** Khi vào trận, lần vung chuột đầu tiên của người chơi không phát ra âm thanh chém của Icicle.
- **Nguyên nhân:** Mỗi lần vung chuột, script tạo mới `Instance.new("Sound")` và gọi `:Play()` ngay khi buffer audio chưa kịp nạp vào luồng xử lý của client.
- **Giải pháp:** Khởi tạo sẵn một Sound Pool (các instance `Sound` gắn cố định trong `Hitbox`), nạp trước bằng `ContentProvider:PreloadAsync` và giữ nguyên trong bộ nhớ. Khi vung chỉ cần reset `TimePosition = 0` và gọi `:Play()`.
- **File liên quan:** [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### 3. Lặp Vô Hạn Animation Swing trên Icicle
- **Vấn đề:** Animation swing của Icicle khi được kích hoạt thì lặp lại liên tục không dừng và vẫn tiếp tục chạy ngay cả khi đã cất (unequip) tool.
- **Nguyên nhân:** Animation trong Roblox Studio được xuất bản với thuộc tính `Looped = true`. Khi phát bằng `LoadAnimation()`, track không dừng tự nhiên dẫn đến sự kiện `Track.Stopped` không bao giờ được kích hoạt.
- **Giải pháp:** Ghi đè `Track.Looped = false` trên Client ngay sau khi load animation, lưu reference track hiện tại để gọi `Track:Stop()` khi `Tool.Unequipped`.
- **File liên quan:** [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)
