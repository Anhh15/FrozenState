# AudioAndAnimation
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống âm thanh và hoạt ảnh (AudioConfig, AnimationConfig, Sound Pooling, Client-Side Spatial Audio, Preload và Memory Cleanup).
> Cập nhật lần cuối: 30-08-2026

---

## Kiến trúc

### 1. Chuẩn Hóa Cấu Hình Audio theo Unified AudioEntry & Phân Tầng Overrides (Single Source of Truth)
- **Chi tiết:** 100% âm thanh trong game được chuẩn hóa theo schema **Unified AudioEntry** `{ Id = number, Volume = number, ... }` hoặc `{ Ids = { number, ... }, Volume = number, MaxDistance = number }`:
  - `AudioConfig.lua`: Quản lý tập trung toàn bộ âm thanh (BGM `Music.Tracks`, GUI `Gui.Default`/`Gui.Overrides`, Shop, Quest, Accolades, Stats, ItemReward, Special, Gameplay `Default`/`Overrides`).
  - **Hệ thống Overrides 2 tầng:** Cho phép ghi đè âm thanh theo từng `MenuName` trong UI hoặc theo `SkinId` của vũ khí/block trong Gameplay.
  - **Bộ API phân giải chuẩn hóa:** Cung cấp các hàm resolver tự động (`GetGuiAudio`, `GetMusicAudio`, `GetGameplayAudio`, `GetSwingAudios`, `GetFreezeAudio`, `GetThawAudio`) tự động hòa trộn `Overrides` với `Default`, triệt tiêu hoàn toàn magic numbers.
- **File liên quan:** [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [AnimationConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnimationConfig.lua)

### 2. Client-Side 3D Spatial Audio & Broadcast RemoteEvent (Triệt tiêu độ trễ 0ms)
- **Chi tiết:** Thay vì Server tạo `Instance.new("Sound")` trong `Workspace` rồi replicate qua mạng cho toàn bộ client (gây độ trễ từ 0.3s - 0.7s do network RTT và buffer CDN), Server chỉ phát RemoteEvent gọn nhẹ (`PlayFreezeSFX`, `PlayThawSFX`) broadcast đến các Client.
- **Client Local Playback:** Client tự phát Spatial Sound cục bộ trên máy của mình gắn vào Part/Character tương ứng, triệt tiêu hoàn toàn độ trễ âm thanh.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### 3. UI Sound Pooling, Polymorphic Input & Tự Động Hóa Qua AutoBindButtons
- **Chi tiết:** Nạp trước toàn bộ audio và animation vào bộ nhớ Client bằng `ContentProvider:PreloadAsync` khi vào game.
- **Sound Pool tĩnh & Nạp đa hình:** `AudioHelper.PlayGuiSound`, `Play2DSound`, `PlaySpatialSound` hỗ trợ nạp đa hình (nhận cả `AudioEntry` table lẫn `number` SoundId), tự động cập nhật `Sound.Volume` chính xác theo từng entry trong pool tĩnh `_guiSoundPool`.
- **Tự động hóa GUI Button:** `GuiHelper.AutoBindButtons(Container, Options)` tự động quét toàn bộ `GuiButton`, gán đồng bộ Scale Animation và SFX (Click, CloseButtonClick, MouseEnter), lắng nghe `DescendantAdded` kèm cache `_BoundButtons[Button] = true` để tự động hỗ trợ toàn bộ phần tử sinh ra động trong thời gian thực.
- **File liên quan:** [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 4. Tự Dọn Dẹp Sound Instance Động bằng Sound.Ended:Once()
- **Chi tiết:** Với các âm thanh phát động 3D/2D một lần, `AudioHelper.PlaySpatialSound()` và `Play2DSound()` tạo instance và kết nối `Sound.Ended:Once(function() Sound:Destroy() end)` kết hợp timeout fallback phòng thủ (`task.delay(Length + 1)`). Pattern này đảm bảo Sound tự dọn dẹp ngay khi phát xong, loại bỏ hoàn toàn nguy cơ rò rỉ bộ nhớ âm thanh.
- **File liên quan:** [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### 5. Chuẩn hóa Animation Loading qua Animator
- **Chi tiết:** Loại bỏ phương thức lỗi thời `Humanoid:LoadAnimation()` (deprecated). Toàn bộ hoạt ảnh được nạp thông qua `Animator:LoadAnimation()` trên `Humanoid.Animator` hoặc `AnimationController.Animator`, kết hợp cache `AnimationTrack` để tái sử dụng và giải phóng khi nhân vật respawn.
- **File liên quan:** [AnimationHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AnimationHelper.lua), [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### 6. Điều phối Nhạc nền Đa trạng thái & Cân Bằng Âm Lượng Từng Track (State-Driven BGM & Track Balancing)
- **Chi tiết:** `MusicController` điều phối BGM duy nhất theo máy trạng thái: $\text{GameLoading} \rightarrow \text{Lobby} \rightarrow \text{Ready} \rightarrow \text{InGame/FrozenState} \rightarrow \text{GameOver}$.
- **Per-Track Volume:** Cân bằng âm lượng gốc giữa các bản nhạc qua `AudioConfig.Music.Tracks` và `AudioConfig.GetMusicAudio(MusicKey)`.
- **Linh hoạt Loading & Ready:** Tự động giữ im lặng hoặc phát BGM riêng khi tải game; phát BGM `Ready` khi đếm ngược chuẩn bị vào trận.
- **Phòng thủ âm thanh:** Hỗ trợ dừng nhạc an toàn (`:Stop()`) khi Sound ID là `nil`/`0`.
### 7. Kiến Trúc Cây Âm Thanh Đa Kênh Phân Cấp & Điều Khiển Âm Lượng Phần Cứng (SoundGroup Hierarchy & Real-time Hardware Scaling)
- **Chi tiết:** Thay vì cập nhật thủ công volume của từng Sound instance đang phát bằng code (dễ bỏ sót và gây lag), toàn bộ âm thanh game được định tuyến qua cây `SoundGroup` phân cấp trong `SoundService`:
  $$\text{SoundService} \rightarrow \text{MasterGroup} \rightarrow \{\text{MusicGroup}, \text{SFXGroup}, \text{UIGroup}\}$$
- **Định tuyến tự động:**
  - `_BgmSound.SoundGroup = MusicGroup`
  - `AudioHelper.PlaySpatialSound` & `CreateSoundPool`: Gán `SFXGroup`
  - `AudioHelper.PlayGuiSound`: Gán `UIGroup`
  - `AudioHelper.Play2DSound`: Nhận tham số chọn group (`SFX`/`UI`)
- **Real-time Scaling:** Khi người chơi điều chỉnh slider trong Setting, `AudioHelper.SetVolume(Group, Percent)` can thiệp trực tiếp `SoundGroup.Volume = Percent / 100`. Roblox Engine tự động nhân tỷ lệ âm lượng phần cứng ngay lập tức cho cả âm thanh đang phát dở lẫn âm thanh phát mới.
- **File liên quan:** [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua)

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

### 4. Thu Thập Asset ID Sạch & Loại Bỏ Lọc Đoán Số
- **Vấn đề:** Các hàm thu thập ID duyệt đệ quy dễ bị nhầm lẫn giữa hằng số âm lượng (như `0.3`, `0.6`) và Sound ID, hoặc phải dùng điều kiện lọc số $\ge 1000$.
- **Nguyên nhân:** Cấu trúc dữ liệu phân tán, thiếu quy chuẩn rõ ràng cho từng entry âm thanh.
- **Giải pháp:** Chuẩn hóa toàn bộ schema sang `AudioEntry` có thuộc tính `.Id` hoặc mảng `.Ids`. Hàm `AudioConfig.GetAllAudioIds()` chỉ bóc tách đúng các trường định danh này, đảm bảo thu thập đủ 100% asset ID mà không bao giờ nhầm lẫn.
- **File liên quan:** [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [GameLoadingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua)

### 5. Âm thanh Lobby Phát Đè lên Màn hình Tải Game Do Khởi tạo Sớm
- **Vấn đề:** `MusicController` tự động phát BGM `Lobby` ngay khi `Init()`, gây xung đột âm thanh trong lúc người chơi vẫn đang ở màn hình `GameLoadingScreen`.
- **Nguyên nhân:** Khởi tạo phát nhạc tĩnh không ràng buộc với trạng thái tải dữ liệu thực tế của Client.
- **Giải pháp:** Chuyển sang cơ chế quan sát trạng thái `PlayerStateHelper.ObserveGameLoaded(LocalPlayer)`. Giữ im lặng hoặc phát BGM tải game riêng trong lúc nạp, chỉ kích hoạt nhạc `Lobby` khi màn hình tải hoàn tất (mở rèm hoặc bấm Skip).
- **File liên quan:** [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [GameLoadingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)

### 6. Lệch Mức Âm Lượng Giữa Các Bản Nhạc Do Thiếu Cấu Hình Per-Track Base Volume
- **Vấn đề:** Các bản audio tải lên Roblox có mức độ to gốc (loudness dBFS) không đồng đều. Dùng chung một hằng số volume làm nhạc ở một số phase (như Ready/InGame) bị quá to trong khi Lobby/GameLoading lại quá nhỏ.
- **Nguyên nhân:** Thiếu lớp trừu tượng cấu hình âm lượng cơ sở theo từng track trước khi đưa ra Sound instance.
- **Giải pháp:** Tích hợp `Volume` vào từng track trong `AudioConfig.Music.Tracks` và hàm `AudioConfig.GetMusicAudio(MusicKey)`. `MusicController` tự động cập nhật `_BgmSound.Volume` tương ứng khi đổi bài.
- **File liên quan:** [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua)

### 7. Phân Mảnh Kết Nối Sự Kiện GUI Audio & Mất Cân Bằng Âm Lượng Hover
- **Vấn đề:** Logic bắt sự kiện `MouseEnter` và `Click` nằm rải rác khắp các Controller gây lặp code, thiếu nhất quán và âm lượng hover mặc định (1.0) quá lớn gây cảm giác chói tai khi tương tác nhanh qua danh sách phần tử.
- **Nguyên nhân:** Thiếu tiện ích tự động hóa tập trung cho UI buttons và thiếu trường cấu hình âm lượng riêng cho `MouseEnter`.
- **Giải pháp:** Thiết lập `GuiHelper.AutoBindButtons(Container, Options)` để tự động hóa toàn bộ việc gắn Scale và SFX cho các nút bấm (kể cả các nút sinh ra động), đồng thời đưa âm lượng `MouseEnter` về `0.35` trong `AudioConfig.Gui.Default`.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### 8. Lệch Kênh Điều Khiển Âm Lượng Do Thiếu Định Tuyến Tường Minh SoundGroup Trong 2D Sound
- **Vấn đề:** Các âm thanh hiệu ứng giao diện (như tiếng đập rương 3 lần và tiếng nổ flash nhận quà trong `ItemReward`) không chịu sự chi phối của thanh trượt `UI Volume`, mà lại bị tăng/giảm theo thanh `SFX Volume`.
- **Nguyên nhân:** Hàm `AudioHelper.Play2DSound` nhận tham số `SoundGroupName` tùy chọn và mặc định fallback về `"SFX"` nếu `nil`. Khi controller UI gọi phát âm thanh mà không chỉ định rõ kênh, âm thanh tự động bị gắn vào `SFXGroup`.
- **Giải pháp:**
  1. Với các âm thanh UI phát động, bắt buộc truyền tường minh tham số `"UI"` khi gọi `AudioHelper.Play2DSound(AudioEntry, Volume, SoundService, "UI")`.
  2. Ưu tiên sử dụng `GuiHelper.PlayGuiSound(AudioEntry, Volume)` hoặc `AudioHelper.PlayGuiSound` để vừa tự động gắn `UIGroup`, vừa tận dụng Sound Pool triệt tiêu độ trễ.
- **File liên quan:** [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)
