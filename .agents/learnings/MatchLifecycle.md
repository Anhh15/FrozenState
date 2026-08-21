# MatchLifecycle
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về vòng đời trận đấu (State Machine, Player State, WinCondition, Special Round, Death/Disconnect Lifecycle và Map Management).
> Cập nhật lần cuối: 21-08-2026

---

## Kiến trúc

### 1. Vòng lặp Trận đấu Khép kín (Match State Machine)
- **Chi tiết:** Luồng trận đấu được điều phối tập trung bởi `MatchService` trên Server qua các phase tuần tự:
  $$\text{Intermission} \longrightarrow \text{Setup} \longrightarrow \text{Ready} \longrightarrow \text{InGame} \longrightarrow \text{GameOver} \longrightarrow \text{Intermission}$$
- **Phân bổ trách nhiệm theo phase:**
  - `Intermission`: Đếm ngược tại Lobby, tập hợp danh sách người chơi sẵn sàng.
  - `Setup`: Tải Map ngẫu nhiên, phân chia đội (`SessionService`), phát thông báo Special Round (nếu có), màn hình chuyển cảnh fade-in che phủ.
  - `Ready`: Teleport người chơi vào điểm spawn, khóa di chuyển, đếm ngược 3-2-1, fade-out màn hình tải.
  - `InGame`: Mở khóa di chuyển, cấp phát Icicle Tool, kích hoạt gameplay đếm ngược và kiểm tra điều kiện thắng/thua.
  - `GameOver`: Thu hồi tool, rã đông tất cả (`ThawAll`), chụp snapshot dữ liệu thống kê (`PrepareGameOverPayloads`), đếm ngược kết thúc, teleport người chơi về Lobby, dọn dẹp map và phát sóng kết quả (`SendGameOverPayloads`).
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 2. Single Source of Truth cho Player State (PlayerStateConfig & PlayerStateHelper)
- **Chi tiết:** Đóng gói toàn bộ logic đọc/ghi và quan sát trạng thái người chơi (`InMatch`, `Team`, `VictimUserId`, `EquippedIcicleSkinId`) vào bộ đôi `PlayerStateConfig` và `PlayerStateHelper` tại `ReplicatedStorage/Shared`.
- **Tách biệt InMatch và Team:**
  - `PlayerStateHelper.IsInMatch(Player)`: Chỉ kiểm tra duy nhất Attribute `InMatch == true` (Single Source of Truth xác nhận player đang sống và thi đấu trong trận).
  - Phân đội `Team`: Thuộc tính `Team` và gán đội trong `SessionService` được giữ nguyên vẹn suốt ván đấu kể cả khi người chơi bị loại (`Dead`). Không xóa `Team` giữa chừng để bảo toàn dữ liệu phục vụ tính điểm, phân định thắng thua theo đội gốc (`ResolveWinnerTeamBased`) và trao thưởng cuối trận.
- **File liên quan:** [PlayerStateConfig.lua](../../src/ReplicatedStorage/Shared/Config/PlayerStateConfig.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 3. Trừu tượng hóa WinCondition Đa tầng (TeamBased vs FFA)
- **Chi tiết:** `SessionService.MatchEndSignal` truyền payload thống nhất dạng table `{ WinTeam = "..." }` hoặc `{ WinPlayer = Player }`.
  - **TeamBased (Normal, EternalFreeze):** Xử lý wipe sạch đội -> Hết giờ so số người sống sót -> So tổng điểm Freeze + Thaw -> Random nếu hòa.
  - **FFA (Chaos):** Xử lý Last Man Standing (chỉ còn 1 người sống sót duy nhất) -> Hết giờ so số lượt Freeze -> Random giữa các người chơi đồng hạng nhất.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameModeConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameModeConfig.lua)

### 4. Điều phối Chu kỳ Special Round theo Cấu hình (SpecialRoundInterval)
- **Chi tiết:** `MatchService` duy trì biến đếm `_roundCounter`. Mỗi khi `_roundCounter % SpecialRoundInterval == 0`, hệ thống kích hoạt vòng đặc biệt (Special Round), tự động chọn ngẫu nhiên từ danh sách mode có cờ `IsSpecialRound = true` trong `GameModeConfig`. Chu kỳ được cấu hình tại `GameConfig.Match.SpecialRoundInterval`.
- **File liên quan:** [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua), [GameModeConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameModeConfig.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 5. Chuẩn hóa Xử lý Chết & Thoát game (Unified Death & Disconnect Lifecycle)
- **Chi tiết:** Bất kỳ người chơi nào chết (Reset character / Rơi xuống void) hoặc thoát game (`PlayerRemoving`) trong lúc trận đấu đang diễn ra (`Setup`, `Ready`, `InGame`) đều được xử lý tập trung qua `FreezeService.EliminatePlayer(Player)`:
  1. Đặt trạng thái `"Dead"`.
  2. Gỡ cờ `InMatch = false`.
  3. Thu hồi Icicle Tool.
  4. Xóa Model khối băng (nếu đang bị đóng băng).
  5. Kích hoạt kiểm tra điều kiện thắng trận `CheckWinCondition()`.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 6. Cơ chế Ngắt Sớm Trận Đấu (Early Termination)
- **Chi tiết:** `MatchService` kết nối `SessionService.MatchEndSignal` ngay từ khi khởi tạo `Init()`. Khi nhận được tín hiệu thắng/thua sớm (do đối thủ bị loại hết trong `Setup` hoặc `Ready`), hệ thống lưu lại `_earlyResult`. Vòng lặp `RunReady` sẽ ngắt sớm (`break`) và `RunInGame` kiểm tra `_earlyResult` để return ngay lập tức (không cấp vũ khí, không đếm ngược vô ích), chuyển thẳng sang phase `GameOver`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 7. Phân tách Map & Spawn Point Đa hình (TeamBase vs FFA)
- **Chi tiết:** Cấu trúc map được chuẩn hóa thành `SpawnPoint/TeamBase/T1SpawnPoint[1-8]`, `T2SpawnPoint[1-8]` và `SpawnPoint/FFA/SpawnPoint[1-16]`. `MapConfig` quản lý cấu trúc tên thư mục, `MapHelper` cung cấp các hàm lọc Part spawn theo mode và tính toán CFrame spawn an toàn phía trên mặt sàn cho nhân vật.
- **File liên quan:** [MapConfig.lua](../../src/ReplicatedStorage/Shared/Config/MapConfig.lua), [MapHelper.lua](../../src/ReplicatedStorage/Shared/Tools/MapHelper.lua), [MapService.lua](../../src/ServerScriptService/Services/MapService.lua)

### 8. Tập trung Hằng số Di chuyển vào GameConfig.Player
- **Chi tiết:** Toàn bộ thông số di chuyển của nhân vật (`DefaultWalkSpeed`, `DefaultJumpPower`, `DefaultJumpHeight`) được lưu trữ tại một nơi duy nhất trong `GameConfig.Player`. Tất cả các service và controller (`MatchService`, `FreezeService`, `SpectateController`) chỉ được đọc từ cấu hình này khi khóa hoặc khôi phục di chuyển.
- **File liên quan:** [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Tránh Circular Dependency giữa các Core Services bằng BindableEvent
- **Vấn đề:** `MatchService` require `FreezeService` để điều phối trận đấu. Khi `FreezeService` phát hiện một đội bị loại sạch và cần kết thúc trận, nếu require ngược lại `MatchService` sẽ tạo vòng lặp phụ thuộc (Circular Dependency).
- **Giải pháp:** Sử dụng một BindableEvent trung gian (`MatchEndSignal`) đặt tại `SessionService`. `FreezeService` bắn event này khi thỏa mãn điều kiện kết thúc, và `MatchService` chỉ việc lắng nghe để chuyển phase sang `GameOver`.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### 2. Lỗi thứ tự Broadcast RemoteEvent làm mất dữ liệu phân đội trên Client
- **Vấn đề:** Khi vào trận, Highlight đồng minh/kẻ địch không xuất hiện trên Client.
- **Nguyên nhân:** Server phát `SetTeamAssignment` trước rồi mới phát `SetGameMode`. Khi Client nhận `SetGameMode`, controller thực hiện dọn dẹp state và gán `KnownTeams = {}`, xóa sạch dữ liệu team vừa nhận được.
- **Giải pháp:** Đảo thứ tự phát RemoteEvent trong `MatchService.RunSetup`: Broadcast `SetGameMode` trước để Client cập nhật mode và dọn state cũ, sau đó mới broadcast `SetTeamAssignment`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [HighlightController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua)

### 3. Người chơi kẹt ở Lobby nhưng vẫn nhận InMatch và vũ khí khi chết ở giây cuối Intermission
- **Vấn đề:** Người chơi chết đúng thời điểm chuyển giao giữa Intermission và Setup vẫn được tính `InMatch = true`, sang phase Ready không được teleport vào map mà đứng ở Sảnh, đến phase InGame vẫn nhận vũ khí và chạy lại tự do ở Sảnh.
- **Nguyên nhân:** `Humanoid.Died` không xử lý loại người chơi ngoài phase InGame, và `RunSetup` đưa toàn bộ `Players:GetPlayers()` vào trận kể cả nhân vật đang chết chờ respawn.
- **Giải pháp:** Xây dựng hàm `GetAlivePlayers()` lọc những người có `Health > 0` và có `HumanoidRootPart` trước khi cho vào `ActivePlayers` của `RunSetup()`. Đồng thời bind sự kiện chết trong toàn bộ thời gian `IsMatchActive = true`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 4. Tính sai lệch điểm bù cuối trận do xóa phân đội khi loại người chơi
- **Vấn đề:** Khi hết giờ trận đấu, đội có thành viên bị loại giữa trận bị hệ thống hiểu lầm là đội ít người từ đầu trận và kích hoạt cộng điểm bù sai luật.
- **Nguyên nhân:** `FreezeService.EliminatePlayer` gọi `SessionService.ClearTeam(Player)`, làm giảm số lượng đếm `#TeamPlayers` trong `ResolveWinnerTeamBased`.
- **Giải pháp:** Không xóa `Team` trong `EliminatePlayer`. Giữ nguyên phân đội trong suốt ván đấu và chỉ dọn dẹp tại `RunGameOver` khi trận đấu kết thúc hoàn toàn.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 5. Khóa di chuyển nhầm lẫn ở Phase Ready cho người chơi ở Sảnh
- **Vấn đề:** Người chơi ở Sảnh (Spectator hoặc người chết ở Setup) bị khóa `WalkSpeed = 0` ở phase Ready và bị kẹt đứng yên vĩnh viễn ở Sảnh.
- **Nguyên nhân:** Lệnh khóa tốc độ `SetMovementLocked` trong `RunReady` đặt ngoài khối điều kiện kiểm tra người tham gia trận.
- **Giải pháp:** Bổ sung điều kiện kiểm tra `SessionService.GetState(Player) == "Normal"` và `PlayerStateHelper.IsInMatch(Player)` trước khi gọi khóa hoặc mở khóa di chuyển trong `RunReady()`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)
