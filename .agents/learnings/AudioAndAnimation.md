# AudioAndAnimation
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống âm thanh và hoạt ảnh (AudioConfig, AnimationConfig, Sound Pooling, Client-Side Spatial Audio, Preload và Memory Cleanup).
> Cập nhật lần cuối: 26-08-2026

---

## Kiến trúc

### 1. Tập trung hóa Cấu hình Audio & Animation (Single Source of Truth)
- **Chi tiết:** Tách bạch hoàn toàn giữa hệ thống âm thanh và hoạt ảnh để tránh lai tạp cấu hình:
  - `AudioConfig.lua`: Tập trung 100% Sound IDs (BGM Lobby/InGame/FrozenState/GameOver/GameLoading, SFX trận đấu Freeze/Thaw/Swing, GUI SFX Click/Hover/Close, Shop/Chest/Quest/Accolades) và cấu hình âm lượng mặc định `DefaultVolume`.
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

### 6. Điều phối Nhạc nền Đa trạng thái Theo Vòng đời Trận & Tải Game (State-Driven BGM)
- **Chi tiết:** `MusicController` điều phối BGM duy nhất theo máy trạng thái: $\text{GameLoading} \rightarrow \text{Lobby} \rightarrow \text{InGame/FrozenState} \rightarrow \text{GameOver}$.
  - Hỗ trợ linh hoạt trạng thái `GameLoading`: phát BGM riêng nếu có ID, hoặc giữ im lặng an toàn (`_BgmSound:Stop()`) nếu là `nil`/`0`.
  - Tự động chuyển BGM `GameOver` khi hết trận và quay lại `Lobby` khi về Sảnh.
  - Hỗ trợ dừng nhạc phòng thủ khi Sound ID không hợp lệ, đồng bộ âm lượng từ `AudioConfig.Music.DefaultVolume`.
- **File liên quan:** [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)

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

### 4. Tiền tải Nhầm Hằng số Âm lượng Thành Sound ID trong PreloadAsync
- **Vấn đề:** Khi `AudioConfig.GetAllAudioIds()` duyệt đệ quy các bảng cấu hình, các hằng số âm lượng (như `DefaultVolume = 0.5`, `ChestClickVolumes = {1, 3, 5}`) bị thu thập nhầm thành các Asset ID `"rbxassetid://0.5"`, `"rbxassetid://1"`, gây lỗi 404 và lãng phí băng thông preload mạng.
- **Nguyên nhân:** Bộ thu thập `Collect(Value)` chỉ kiểm tra `type(Value) == "number"` mà không phân biệt giữa Sound ID và hằng số cấu hình.
- **Giải pháp:** Bổ sung điều kiện lọc nghiêm ngặt `type(Value) == "number" and Value >= 1000 and math.floor(Value) == Value` để chỉ gom các Sound ID hợp lệ (số nguyên $\ge 1000$).
- **File liên quan:** [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [GameLoadingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua)

### 5. Âm thanh Lobby Phát Đè lên Màn hình Tải Game Do Khởi tạo Sớm
- **Vấn đề:** `MusicController` tự động phát BGM `Lobby` ngay khi `Init()`, gây xung đột âm thanh trong lúc người chơi vẫn đang ở màn hình `GameLoadingScreen`.
- **Nguyên nhân:** Khởi tạo phát nhạc tĩnh không ràng buộc với trạng thái tải dữ liệu thực tế của Client.
- **Giải pháp:** Chuyển sang cơ chế quan sát trạng thái `PlayerStateHelper.ObserveGameLoaded(LocalPlayer)`. Giữ im lặng hoặc phát BGM tải game riêng trong lúc nạp, chỉ kích hoạt nhạc `Lobby` khi màn hình tải hoàn tất (mở rèm hoặc bấm Skip).
- **File liên quan:** [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [GameLoadingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)
