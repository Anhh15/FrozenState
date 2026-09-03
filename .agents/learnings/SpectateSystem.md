# SpectateSystem
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống quan sát trận đấu (ObserverGui, Phân biệt Lobby Spectator vs Frozen Spectator, Streaming ReplicationFocus và Camera Management).
> Cập nhật lần cuối: 03-09-2026

---

## Kiến trúc

### 1. Kiến trúc ObserverGui — ScreenGui Độc Lập cho Hệ Thống Quan Sát
- **Chi tiết:** Thay vì đặt `SpectateGui` trong `ScreenGui.Menu` (bị tắt khi người chơi đang trong trận) hoặc `ScreenGui.InGameGui` (chỉ dành riêng cho người thi đấu), hệ thống sử dụng một `ScreenGui` độc lập tên `ObserverGui`.
- **Mục tiêu:** Đóng vai trò vùng giao thoa tương tác — phục vụ hoàn hảo cho cả **Lobby Spectator** (người ngoài trận) lẫn **Frozen Spectator** (người đang bị đóng băng trong trận).
- **Phân định quyền sở hữu:**
  - `GameStateController`: Quản lý vòng đời `ObserverGui.Enabled` theo phase trận đấu (bật ở `Ready`, `InGame`, `GameOver`; tắt ở `Intermission`).
  - `SpectateController`: Là đơn vị duy nhất (Sole Owner) quản lý hiển thị `SpectateGui.Visible` và điều khiển Orbit Camera.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 2. Kiến trúc Phân Biệt 2 Loại Spectator (Lobby Spectator vs Frozen Spectator)
- **Chi tiết:** `SpectateController` phân biệt hành vi bằng cờ `_isFrozenSpectator`:
  - **Lobby Spectator** (`IsInMatch == false`):
    - Khóa di chuyển nhân vật tại Sảnh (`WalkSpeed = 0`, `JumpPower = 0`) để tránh bị rơi tự do khi vùng Sảnh bị stream out.
    - Ẩn thanh nút `NavigationButtons` khi bật spectate và khôi phục khi tắt.
    - Được phép quan sát tất cả người chơi đang thi đấu trong trận.
  - **Frozen Spectator** (`IsInMatch == true`, trạng thái `"Frozen"`):
    - Không can thiệp vào thuộc tính di chuyển (Server đã Anchor HRP khi đóng băng).
    - Không can thiệp vào thanh điều hướng Navigation.
    - Giới hạn mục tiêu quan sát: Trong chế độ có đội (`HasTeams == true`), chỉ được phép quan sát các đồng minh còn sống (`Normal`); trong chế độ FFA (`Chaos`), được phép quan sát bất kỳ ai còn sống.
    - Tự động tắt spectate và trả lại camera nhân vật khi được giải cứu (`Thaw`) hoặc bị loại (`Dead`).
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### 3. Điều phối Streaming qua ReplicationFocus và Camera Subject
- **Chi tiết:** Dưới chế độ `StreamingEnabled`, khi chuyển camera sang mục tiêu ở xa đấu trường, nhân vật mục tiêu có thể chưa được tải ở Client.
- **Cơ chế Server-Client:**
  1. Client gửi RemoteEvent `RequestSpectateTarget(TargetPlayer)` lên Server.
  2. Server gán `Player.ReplicationFocus = TargetHRP` để Roblox ưu tiên truyền tải dữ liệu khu vực xung quanh mục tiêu về cho Spectator.
  3. Client thiết lập `Camera.CameraType = Enum.CameraType.Custom` và `Camera.CameraSubject = TargetHumanoid`.
  4. Khi tắt spectate, Client gửi `RequestSpectateTarget(nil)` để Server khôi phục `ReplicationFocus` về lại HRP của chính spectator.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 4. Phân định Độc lập Nhạc nền cho Spectator (Decoupled MusicController)
- **Chi tiết:** Người chơi ở vị trí Spectator (ngoài trận) luôn nghe nhạc nền Sảnh (`AudioConfig.Music.Lobby`), không thay đổi phụ thuộc vào phase thi đấu hay mục tiêu mà họ đang theo dõi. Loại bỏ hoàn toàn callback chéo `OnSpectateChanged`, giúp hai hệ thống độc lập hoàn toàn.
- **File liên quan:** [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Lỗi SpectateGui Hiện rồi Tắt Ngay (Flickering) do GameStateController Ghi Đè
- **Vấn đề:** Khi người chơi bấm nút `SpectateButton` lúc đang bị đóng băng trong trận, giao diện Spectate hiện lên ~1 giây rồi lập tức biến mất.
- **Nguyên nhân:** Trước đây `SpectateGui` nằm trong `ScreenGui.Menu`. `GameStateController` nhận broadcast `UpdateGameState` mỗi giây từ Server và gọi `MenuCtrl.SetVisible(false)`, khiến toàn bộ Frame trong Menu bị tắt theo.
- **Giải pháp:** Tách hoàn toàn `SpectateGui` sang `ObserverGui` độc lập, không còn bị ảnh hưởng bởi vòng lặp tắt menu của `GameStateController`.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### 2. Spectator Bị Lơ Lửng và Mất Di Chuyển Sau Khi Tắt Spectate
- **Vấn đề:** Khi tắt Spectate, camera quay lại Sảnh nhưng nhân vật bị đóng băng tại chỗ, không thể đi lại.
- **Nguyên nhân:** `ReplicationFocus` dời sang mục tiêu ở xa khiến vùng Sảnh bị stream out (mất mô phỏng vật lý). Khi tắt Spectate, `ReplicationFocus` không được reset về Sảnh.
- **Giải pháp:** Bắt buộc gửi yêu cầu `RequestSpectateTarget(nil)` lên Server khi tắt spectate để trả `ReplicationFocus` về HRP của người chơi, đồng thời khôi phục tốc độ di chuyển gốc từ `GameConfig.Player`.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 3. Mất NavigationButtons Vĩnh Viễn và Kẹt Camera Sau Khi Reset Nhân Vật Trong Lúc Spectate
- **Vấn đề:** Người chơi bật Spectate rồi reset nhân vật (hoặc chết) thì thanh nút điều hướng không bao giờ hiện lại, và khi hết trận camera bị kẹt tại tọa độ cũ.
- **Nguyên nhân:** Controller không lắng nghe sự kiện `LocalPlayer.CharacterAdded`, khiến cờ `_isSpectating` vẫn giữ giá trị `true` sau khi chết; `RestoreCamera` cố gán `CameraSubject` vào instance `Humanoid` cũ đã bị hủy.
- **Giải pháp:** Lắng nghe `CharacterAdded` để tự động tắt spectate, giải phóng camera, khôi phục thanh điều hướng và tốc độ di chuyển. Hàm `RestoreCamera` kiểm tra nếu Humanoid cũ đã hủy thì fallback bám theo nhân vật mới ở Sảnh.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua)

### 4. Người Chơi Tham Gia Muộn (Late-Joiner) Nhận Danh Sách Spectate Trống
- **Vấn đề:** Người chơi kết nối vào server sau khi trận đấu đã bắt đầu có thể mở giao diện Spectate nhưng danh sách mục tiêu hoàn toàn trống rỗng.
- **Nguyên nhân:** Server chỉ broadcast danh sách mục tiêu tại thời điểm bắt đầu phase `InGame` hoặc khi có thay đổi trạng thái đóng băng/rã đông.
- **Giải pháp:** Trong `MatchService:Init()`, lắng nghe `Players.PlayerAdded`. Nếu game đang trong phase `InGame`, Server gửi riêng danh sách người chơi còn sống hiện tại cho người mới tham gia qua `FireClient`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 5. Lỗ Hổng Crash Server Do Type Injection Qua Remote RequestSpectateTarget
- **Vấn đề:** Listener `RequestSpectateTargetEvent.OnServerEvent` không kiểm tra kiểu dữ liệu của đối số `TargetPlayer` mà trực tiếp gọi phương thức `:IsDescendantOf(Players)`. Kẻ tấn công có thể cố ý gửi payload sai kiểu (string, number, table, boolean) khiến server phát sinh ngoại lệ không được bắt (unhandled runtime exception), gây crash luồng xử lý hoặc nghẽn Event Loop.
- **Giải pháp:** Bổ sung type guard ngay tại đầu listener kiểm tra nghiêm ngặt: `if TargetPlayer ~= nil and (typeof(TargetPlayer) ~= "Instance" or not TargetPlayer:IsA("Player")) then return end`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)
