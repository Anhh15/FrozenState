# MatchLifecycle
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về vòng đời trận đấu (State Machine, Player State, WinCondition, Special Round, Death/Disconnect Lifecycle và Map Management).
> Cập nhật lần cuối: 04-09-2026

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
- **Chi tiết:** Triết lý game **tuyệt đối không có kết quả Hòa (No-Draw)**. Toàn bộ logic kiểm tra điều kiện thắng được quy về Single Source of Truth tại `SessionService.CheckWinCondition()`, phát `SessionService.MatchEndSignal` với payload `{ WinTeam = "..." }` hoặc `{ WinPlayer = Player }`:
  - **TeamBased (Normal, EternalFreeze):** Wipe sạch đối phương (Team 1 wipe $\rightarrow$ Team 2 thắng, Team 2 wipe $\rightarrow$ Team 1 thắng). Nếu cả 2 đội cùng wipe $\rightarrow$ so tổng điểm Freeze + Thaw bảo toàn từ `_teamScores` $\rightarrow$ random 50/50. Khi hết giờ $\rightarrow$ so số người sống (chỉ bù `Alive + 1` khi `Alive > 0`) $\rightarrow$ so điểm `_teamScores` $\rightarrow$ random 50/50.
  - **FFA (Chaos):** Last Man Standing (còn 1 người sống) $\rightarrow$ Hết giờ ưu tiên lọc người còn `Normal` trước, nếu 0 ai `Normal` thì so điểm Freeze toàn bộ $\rightarrow$ Random 1 người trong nhóm điểm cao nhất nếu bằng điểm.
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
  5. Kích hoạt kiểm tra điều kiện thắng trận `SessionService.CheckWinCondition()`.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 6. Cơ chế Ngắt Sớm Trận Đấu (Early Termination & Idempotent MatchEndSignal)
- **Chi tiết:** `MatchService` kết nối `SessionService.MatchEndSignal` ngay từ khi khởi tạo `Init()`. Khi nhận được tín hiệu thắng/thua sớm (do đối thủ bị loại hết trong `Setup` hoặc `Ready`), hệ thống lưu lại `_earlyResult`. Listener áp dụng cơ chế Idempotent Guard: `if _earlyResult ~= nil then return end` để bảo vệ kết quả, triệt tiêu nguy cơ các sự kiện disconnect/chết muộn phát sinh sau đó ghi đè làm đảo ngược đội thắng cuộc. Vòng lặp `RunReady` sẽ ngắt sớm (`break`) và `RunInGame` kiểm tra `_earlyResult` để return ngay lập tức (không cấp vũ khí, không đếm ngược vô ích), chuyển thẳng sang phase `GameOver`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 7. Phân tách Map & Phân bổ Spawn Point Độc nhất (Unique Spawn Assignment)
- **Chi tiết:** Cấu trúc map chuẩn hóa thành `SpawnPoint/TeamBase/T1SpawnPoint[1-8]`, `T2SpawnPoint[1-8]` và `SpawnPoint/FFA/SpawnPoint[1-16]`. Hằng số chiều cao spawn được lưu tại `MapConfig.Spawn.DefaultYOffset`. `MapHelper.AssignSpawnPoints` sử dụng thuật toán Fisher-Yates Shuffle để phân bổ 1-1 không trùng lặp cho danh sách người chơi (FFA lẫn TeamBased), tự động wrap-around $\left(((i - 1) \pmod M) + 1\right)$ khi số người chơi $N > M$ (số spawn point).
- **File liên quan:** [MapConfig.lua](../../src/ReplicatedStorage/Shared/Config/MapConfig.lua), [MapHelper.lua](../../src/ReplicatedStorage/Shared/Tools/MapHelper.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [MapService.lua](../../src/ServerScriptService/Services/MapService.lua)

### 8. Tập trung Hằng số Di chuyển vào GameConfig.Player
- **Chi tiết:** Toàn bộ thông số di chuyển của nhân vật (`DefaultWalkSpeed`, `DefaultJumpPower`, `DefaultJumpHeight`) được lưu trữ tại một nơi duy nhất trong `GameConfig.Player`. Tất cả các service và controller (`MatchService`, `FreezeService`, `SpectateController`) chỉ được đọc từ cấu hình này khi khóa hoặc khôi phục di chuyển.
- **File liên quan:** [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### 9. Quản lý Người Tham gia Trận đấu (Participant Management)
- **Chi tiết:** Độc lập với `Team` và `InMatch`, `SessionService` duy trì danh sách `_participants` được gán lúc `RunSetup()`. Cơ chế này phân tách hoàn toàn người chơi thực sự với Spectator (người mới vào lobby giữa trận): Spectator không bị đưa vào tính điểm (`GetTopScorerFFA`), không nhận thưởng oan (`MatchLose`), không hiện GUI thống kê cuối trận và không bị chọn nhầm làm Winner khi hòa điểm.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 10. Chủ đích Thiết kế Cơ chế Cân bằng và Phân định Thắng Thua (Game Design Intentions)
- **Chi tiết:** Ghi nhận các quyết định thiết kế cốt lõi (tránh nhầm lẫn là lỗi kỹ thuật):
  - **Bù mạng sống ảo khi Hết giờ (`Alive + 1`):** Trong các trận đấu không cân bằng quân số (ví dụ 2v1), nếu đội ít người hơn vẫn trụ vững đến hết giờ (`Alive > 0`), hệ thống cộng `+1 Alive` để cân bằng tỷ lệ sống sót, đẩy kết quả về hòa người sống và xét điểm đóng góp (`Freeze + Thaw`). Đây là cơ chế bảo vệ nỗ lực của đội ít người.
  - **Đồng thời bị Loại trong FFA (`Simultaneous Elimination`):** Khi 2 người cuối cùng cùng rơi void/chết gần như đồng thời (cách nhau phân giây), hệ thống không coi người sống sót thêm 0.05s là người chiến thắng tuyệt đối, mà chuyển về xét `NormalCount == 0` để trao cúp cho người có điểm Freeze cao nhất toàn trận (`GetTopScorerFFA`).
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 11. Bộ Lọc Người Chơi Tham Chiến AFK & Quản Lý Tính Hợp Lệ Trận Đấu (AFK State & Match Eligibility Filter)
- **Chi tiết:** Tích hợp trạng thái `IsAfk` vào Attribute trên Player (`PlayerStateConfig.Attributes.IsAfk`), quản lý qua `PlayerStateHelper`:
  - *Runtime State:* Mặc định `IsAfk = false` khi người chơi kết nối vào server. Client gửi RemoteEvent `SetAfkState` lên Server khi thay đổi thiết lập.
  - *Lọc Ghép Trận Tập Trung:* `MatchService.GetAlivePlayers()` tích hợp điều kiện bắt buộc:
    $$\text{Eligible} = \text{Character} \land (\text{Health} > 0) \land \text{GameLoaded} \land (\neg \text{IsAfk})$$
  - Loại bỏ hoàn toàn người chơi AFK khỏi danh sách được phân đội, teleport và cấp vũ khí khi bắt đầu `Setup`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua), [PlayerStateConfig.lua](../../src/ReplicatedStorage/Shared/Config/PlayerStateConfig.lua)

### 12. Cơ Chế Kiểm Soát Tần Suất Chuyển Đổi Trạng Thái AFK (AFK Rate-Limit Guard)
- **Chi tiết:** Mọi RemoteEvent cho phép Client thông báo thay đổi trạng thái người chơi lên Server (SetAfkState) phải được kiểm soát tần suất chặt chẽ nhằm triệt tiêu nguy cơ kẻ xấu spam request gây quá tải CPU Server (DDoS / Flood Remote).
- **Cơ chế Triển khai:** Cấu hình GameConfig.Player.AfkCooldown = 1.5 (giây). Server duy trì bảng tra cứu _LastAfkToggleTimes[Player.UserId]. Nếu khoảng cách giữa 2 lần bấm chuyển AFK nhỏ hơn thời gian hồi, Server lập tức từ chối xử lý (early return). Dọn dẹp key khỏi bảng trong Players.PlayerRemoving để tránh rò rỉ RAM.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

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

### 6. Trùng lặp điểm spawn khi vào trận do chọn ngẫu nhiên có hoàn lại (Sampling with Replacement)
- **Vấn đề:** Người chơi xuất hiện đè lên nhau tại cùng một tọa độ spawn ở phase Ready, gây hiện tượng kẹt nhân vật và va chạm vật lý (physics jitter/glitch).
- **Nguyên nhân:** Hàm `TeleportToSpawn` gọi `math.random(1, #SpawnPoints)` độc lập cho từng người chơi. Theo nghịch lý ngày sinh nhật (Birthday Paradox), xác suất trùng ít nhất 2 người khi có $N$ player trên $M$ spawn là $1 - \prod_{k=0}^{N-1} \frac{M-k}{M}$ (với 4 người trong 16 spawn FFA, tỷ lệ trùng lên tới $\approx 33.4\%$).
- **Giải pháp:** Chuyển sang cơ chế phân bổ độc nhất trong `MapHelper.AssignSpawnPoints`. Xáo trộn mảng spawn bằng Fisher-Yates Shuffle $O(M)$ trước khi gán 1-1 cho danh sách người chơi.
- **File liên quan:** [MapHelper.lua](../../src/ReplicatedStorage/Shared/Tools/MapHelper.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [MapConfig.lua](../../src/ReplicatedStorage/Shared/Config/MapConfig.lua)

### 7. Lỗi bù mạng sống ảo vô điều kiện làm đội 0 người sống thắng đội có người sống
- **Vấn đề:** Khi hết giờ, đội ít người hơn có `Alive = 0` (đã bị đóng băng/chết sạch) vẫn được `+1` thành 1, dẫn đến hòa số người sống và có thể thắng random một đội đang có người sống thực tế.
- **Giải pháp:** Chỉ áp dụng `Alive + 1` khi đội ít người hơn có `Alive > 0`. Đội có `0` người sống không được cộng điểm ảo.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 8. Lỗi trao nhầm danh hiệu LastStanding cho người đã chết ở chế độ FFA
- **Vấn đề:** Khi tất cả người chơi cùng chết (`NormalCount = 0`) và thắng bằng điểm Freeze, điều kiện `NormalCount <= 1` trả về true khiến người thắng (đang `Dead` hoặc `Frozen`) vẫn nhận danh hiệu và tiền thưởng "Người sống sót cuối cùng".
- **Giải pháp:** Siết chặt điều kiện thành `NormalCount == 1 and SessionService.GetState(WinPlayer) == "Normal"`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 9. Lỗi cả 2 đội cùng bị Wipe trong TeamBased dẫn tới trao cúp sai hoặc trao cho đội rỗng
- **Vấn đề:** 2 người cuối cùng cùng chết hoặc rơi void khiến event xử lý sau lật ngược kết quả, hoặc khi 1 đội out game hết thì đội rỗng (0 người) lại được tính là thắng.
- **Giải pháp:** Kiểm tra đồng thời cả 2 đội (`IsTeamWiped("Team1")` và `IsTeamWiped("Team2")`). Nếu cả 2 cùng wipe $\rightarrow$ so điểm tổng `GetTeamTotalScore` $\rightarrow$ random 50/50. Không bao giờ trao cúp cho đội rỗng.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 10. Lỗi nghịch đảo đội thắng do xóa phân đội sớm khi Disconnect
- **Vấn đề:** Khi toàn bộ thành viên của một đội thoát game, đội đã thoát sạch lại được hệ thống tuyên bố chiến thắng thay vì đội còn lại.
- **Nguyên nhân:** Sự kiện `PlayerRemoving` gọi `SessionService.ClearTeam(Player)` trước khi check WinCondition làm `#Team1Players` giảm về 0, khiến toán tử ternary `(#Team2Players > 0) and "Team2" or "Team1"` trả về `"Team1"`.
- **Giải pháp:** Đảo thứ tự xử lý trong `PlayerRemoving`: Đặt trạng thái `"Dead"`, kiểm tra `WinCondition` và bắn `MatchEndSignal` trước; sau đó mới gọi `ClearTeam` và dọn dẹp bộ nhớ session.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 11. Người bị đóng băng thắng ván đấu khi hết giờ trong chế độ FFA
- **Vấn đề:** Khi hết thời gian thi đấu FFA, người chơi đã bị đóng băng hoặc đã chết từ trước lại được trao chiến thắng chỉ vì có số lần Freeze cao hơn người chơi sống sót cuối cùng.
- **Nguyên nhân:** Hàm `ResolveWinnerFFA` gọi `GetTopScorerFFA()` trực tiếp trên toàn bộ `_participants` mà không phân loại trạng thái sinh tồn.
- **Giải pháp:** Nâng cấp `GetTopScorerFFA(CandidatePool)` nhận pool ứng viên tùy chọn. Trong `ResolveWinnerFFA`, lọc `GetAllNormalPlayers()` trước; chỉ khi không còn ai `Normal` mới xét điểm toàn bộ người chơi tham gia.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 12. Mất dữ liệu điểm Tie-break khi thành viên Disconnect & Gom kiểm tra WinCondition
- **Vấn đề:** Khi cả 2 đội cùng Wipe hoặc hết giờ hòa mạng sống, `GetTeamTotalScore` phụ thuộc vào `GetTeamPlayers` (chỉ lọc người online), làm mất toàn bộ điểm số `Freeze + Thaw` mà người chơi đã đóng góp nếu họ bị rớt mạng/thoát game. Đồng thời logic `CheckWinCondition` bị duplicate giữa `FreezeService` và `PlayerRemoving`.
- **Giải pháp:** Tích lũy trực tiếp điểm đội vào `_teamScores = { Team1 = 0, Team2 = 0 }` trong `SessionService.IncrementStat` để lấy $O(1)$ và bảo toàn điểm suốt ván đấu. Đồng thời đưa toàn bộ logic kiểm tra vào `SessionService.CheckWinCondition()`, loại bỏ biểu thức ternary dư thừa khi wipe.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### 13. Khóa Thao Tác Vũ Khí Sau Trận Đấu Do Thiếu Broadcast Trạng Thái Normal Đầu Ván Mới
- **Vấn đề:** Người chơi bị đóng băng (`Frozen`) hoặc bị loại (`Dead`) ở trận trước không thể bấm phím 1..9 hay click chuột để trang bị vũ khí ở các trận kế tiếp dù đã được cấp Tool.
- **Nguyên nhân:** Trong `RunSetup()`, Server chỉ gán `SessionService.SetState(Player, "Normal")` trong bộ nhớ Server mà không phát RemoteEvent `UpdatePlayerStateEvent` xuống Client. Các controller ở Client (`HotbarController`) vẫn lưu cờ `_IsFrozen = true` hoặc `_IsDead = true`, khóa toàn bộ tương tác vũ khí qua `ToggleEquipTool`.
- **Giải pháp:** Trong `MatchService.RunSetup()`, Server duyệt qua toàn bộ `ActivePlayers` và phát `UpdatePlayerStateEvent:FireAllClients(...)` với `State = "Normal"` để xóa sạch cờ đóng băng/chết trên toàn bộ Client.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua)

### 14. Bắt Đầu Trận Đấu 1 Mình Do Đếm Sai Số Lượng Người Chơi Sẵn Sàng Tại Intermission Khi Có Player AFK
- **Vấn đề:** Khi server chỉ có 2 người chơi nhưng 1 người bật AFK, phase `Intermission` vẫn đếm ngược và bắt đầu ván đấu với chỉ 1 người duy nhất, gây lỗi thiếu người trong mode thi đấu đối kháng.
- **Nguyên nhân:** Vòng lặp `RunIntermission()` và `GameLoop()` kiểm tra điều kiện `#Players:GetPlayers() >= MinPlayers` (đếm toàn bộ người có trong server bất kể trạng thái AFK).
- **Giải pháp:** Chuyển toàn bộ điều kiện kiểm tra số lượng sang `#GetAlivePlayers() >= GameConfig.Match.MinPlayers`. Nếu số người sẵn sàng không AFK $< \text{MinPlayers}$, hệ thống tự động reset `TimeLeft = Duration` và duy trì trạng thái chờ ở `Intermission`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### 15. Kẻ Tấn Công Spam RemoteEvent SetAfkState Gây Quá Tải CPU Server
- **Vấn đề:** Sự kiện SetAfkState.OnServerEvent trước đây không có debounce kiểm tra thời gian giữa các lần gọi. Client gian lận có thể kích hoạt vòng lặp gửi hàng nghìn request/giây, ép Server liên tục ghi đè Attribute IsAfk và in log console, làm tụt tick-rate của Server và lag toàn bộ người chơi khác.
- **Giải pháp:** Bổ sung kiểm tra rate-limit per-player (os.clock() - LastToggle) < Cooldown với GameConfig.Player.AfkCooldown (1.5s), đồng thời kiểm tra tính hợp lệ của Player instance trước khi cập nhật PlayerStateHelper.SetAfk.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### 16. Xung Đột Tín Hiệu MatchEndSignal Do Disconnect/Death Muộn Làm Ghi Đè Đội Thắng (Idempotent Early Result Guard)
- **Vấn đề:** Khi một đội vừa bị wipe hoặc đạt điều kiện thắng, `SessionService.CheckWinCondition()` phát tín hiệu `MatchEndSignal`. Nếu ngay sau đó một người chơi khác tiếp tục disconnect (`PlayerRemoving`) hoặc rơi void (`Humanoid.Died`) trong lúc phase `GameOver` đang chuẩn bị kích hoạt, `CheckWinCondition()` bị gọi lại và phát thêm một `MatchEndSignal` mới, ghi đè biến `_earlyResult` làm thay đổi kết quả ván đấu hoặc gây crash luồng xử lý.
- **Giải pháp:** Bổ sung Idempotent Guard ngay tại listener của `MatchService`:
  ```lua
  SessionService.MatchEndSignal.Event:Connect(function(Result)
      if _earlyResult ~= nil then return end
      _earlyResult = Result
  end)
  ```
  Chỉ ghi nhận kết quả đầu tiên được phát ra và bỏ qua mọi tín hiệu thừa kế tiếp cho đến khi `RunSetup` reset `_earlyResult = nil` ở ván mới.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 17. Chuẩn Hóa Vòng Đời 2 Pha (Init -> Start) và Triệt Tiêu Hoàn Toàn Lazy-Require Giữa Các Service
- **Vấn đề:** Để tránh vòng lặp phụ thuộc (Circular Dependency) khi các service cần gọi nhau (`FreezeService`, `MatchService`, `ShopService`, `QuestService`), lập trình viên thường dùng giải pháp chắp vá `script.Parent:FindFirstChild(...)` và `require` động lặp đi lặp lại giữa thân hàm. Cách làm này che giấu lỗi runtime, làm chậm hiệu năng do phải tra cứu hierarchy liên tục và vi phạm tính toàn vẹn kiến trúc.
- **Giải pháp:** Thực thi triệt để mô hình Vòng đời 2 Pha chuẩn hóa:
  1. *Pha 1 (`Init`)*: Các Service chỉ thiết lập state nội bộ, bind RemoteDefinitions, gán biến tham chiếu service bằng `nil` ở module scope.
  2. *Pha 2 (`Start`)*: Sau khi toàn bộ Service đã `Init` xong, `ServiceLoader` gọi `Start()`. Tại đây các Service an toàn thực hiện `require(script.Parent.XxxService)` và gán vào biến module scope. Toàn bộ logic nghiệp vụ gọi trực tiếp biến này mà không dùng `FindFirstChild`.
- **File liên quan:** [ServiceLoader.lua](../../src/ServerScriptService/Services/ServiceLoader.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 18. Cơ Chế Ngắt Sớm Trạng Thái Hoạt Động Trận Đấu (Immediate Match Active Teardown Guard)
- **Vấn đề:** Khi `SessionService.CheckWinCondition()` phát hiện điều kiện thắng và phát `MatchEndSignal`, biến `_isMatchActive` vẫn giữ giá trị `true`. Cờ này chỉ được chuyển thành `false` khi vòng lặp 1 giây của `RunInGame` bước sang giây tiếp theo để chuyển phase `RunGameOver`. Trong khoảng trễ này (~1s), người chơi vẫn có thể vung kiếm chém trúng hoặc kích hoạt đóng băng đối thủ ngoài ý muốn.
- **Giải pháp:** Thiết lập `_isMatchActive = false` ngay tại thời điểm điều kiện thắng được xác nhận trong `CheckWinCondition()`, trước khi gọi `MatchEndSignal:Fire(...)`. Đảm bảo toàn bộ logic kiểm tra `HandleToolHit` lập tức từ chối mọi đòn đánh phát sinh sau khi trận đấu đã ngã ngũ.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)
