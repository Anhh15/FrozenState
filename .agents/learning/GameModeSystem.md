# GameModeSystem
> Tổng hợp kiến thức về hệ thống chế độ chơi (GameMode System, Chaos FFA, chu kỳ Special Round, đồng bộ InMatch/Team) trong dự án.
> Cập nhật lần cuối: 15-08-2026

---

## Kiến trúc

### Kiến trúc Config-Driven GameMode trung tâm
- **Ngày:** 14-08-2026
- **Chi tiết:** Tách toàn bộ cơ chế, luật thắng/thua, map spawn, UI display, và thời lượng trận đấu thành các tham số per-mode trong `GameModeConfig` (`ReplicatedStorage/Shared/Config`). Server và Client đọc cấu hình này để quyết định hành vi thay vì hardcode tên mode trong logic nghiệp vụ.
- **File liên quan:** [GameModeConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GameModeConfig.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua)

### Tránh Circular Dependency khi GameMode được truy xuất bởi nhiều Services
- **Ngày:** 14-08-2026
- **Chi tiết:** `FreezeService` cần đọc mode (để check `AllowThaw`, `WinCondition`), nhưng `MatchService` lại đang require `FreezeService`. Giải pháp: Lưu `_currentModeKey` tập trung trong `SessionService` (`SetCurrentModeKey`/`GetCurrentModeKey`). Cả `MatchService` và `FreezeService` đều require `SessionService` nên chia sẻ được mode hiện tại mà không tạo tham chiếu vòng.
- **File liên quan:** [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Điều phối chu kỳ Special Round theo cấu hình (SpecialRoundInterval)
- **Ngày:** 14-08-2026
- **Chi tiết:** `MatchService` duy trì biến đếm `_roundCounter`. Mỗi khi `_roundCounter % SpecialRoundInterval == 0` sẽ kích hoạt vòng đặc biệt (Special Round), tự động lấy ngẫu nhiên từ danh sách mode có `IsSpecialRound = true` (`GameModeConfig.GetSpecialModeKeys()`). Tham số chu kỳ được lưu trong `GameConfig.Match.SpecialRoundInterval` để dễ dàng tinh chỉnh.
- **File liên quan:** [GameConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GameConfig.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [GameModeConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GameModeConfig.lua)

### Trừu tượng hóa WinCondition đa tầng (TeamBased vs FFA)
- **Ngày:** 14-08-2026
- **Chi tiết:** `MatchEndSignal` truyền payload thống nhất dạng table `{ WinTeam = "..." }` hoặc `{ WinPlayer = Player }`. TeamBased xử lý wipe đội -> so người sống -> so điểm Freeze+Thaw -> random. FFA (Chaos) xử lý Last Man Standing (còn 1 Normal) -> hết giờ so Freeze count -> random giữa các player đồng điểm cao nhất.
- **File liên quan:** [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Phân tách Spawn Point đa hình theo Map (TeamBase vs FFA)
- **Ngày:** 14-08-2026
- **Chi tiết:** Cấu trúc map chuẩn hóa thành `SpawnPoint/TeamBase/T1SpawnPoint[1-8]`, `T2SpawnPoint[1-8]` và `SpawnPoint/FFA/SpawnPoint[1-16]`. `MapService.GetSpawnPoints(TeamName, SpawnType)` nhận `SpawnType` từ mode config để tự động truy xuất đúng thư mục spawn point tương ứng.
- **File liên quan:** [MapService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MapService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Chuẩn hóa vòng đời và quy ước Attribute InMatch vs Team
- **Ngày:** 15-08-2026
- **Chi tiết:** Đồng bộ toàn diện quy ước trạng thái: Attribute `InMatch` (boolean) là nguồn chân lý duy nhất xác định người chơi đang trực tiếp tham chiến (cả Team-based và FFA), trong khi `Team` chỉ mang ý nghĩa phân chia phe phái. Vòng đời `InMatch` được quản lý chặt chẽ: thiết lập khi vào trận (`RunSetup`), và bắt buộc thu hồi (`nil`) khi bị loại (`EliminatePlayer`), khi hết trận (`RunGameOver` / `ResetSession`), hoặc khi rời game (`PlayerRemoving`).
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Đồng bộ phân phối HUD và điều phối GameMode xuống Client
- **Ngày:** 15-08-2026
- **Chi tiết:** `GameStateController` lắng nghe `SetGameMode` để lưu cấu hình hiển thị (`PlayerStatusType`, `ScoreboardType`). Trong vòng lặp hiển thị HUD theo phase, controller áp dụng điều kiện kết hợp `ShowGameplayHud and (_type ~= "Disabled")` để tránh việc ghi đè ép hiển thị các UI con (như `PlayerStatus` hoặc `ScoreBoardButton`) khi chế độ chơi đã vô hiệu hóa chúng.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [PlayerStatusController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

---

## Bug & biện pháp

### Lỗi thứ tự Broadcast RemoteEvent làm mất Highlight ở Normal Mode
- **Ngày:** 14-08-2026
- **Vấn đề:** Khi vào trận Normal, Highlight đồng minh/kẻ địch không xuất hiện trên nhân vật người chơi khác.
- **Nguyên nhân:** Server phát `SetTeamAssignment` trước rồi mới phát `SetGameMode`. Khi client nhận `SetGameMode`, controller reset `KnownTeams = {}` dẫn đến xóa sạch dữ liệu team vừa nhận được.
- **Fix:** Đảo thứ tự phát RemoteEvent trong `MatchService.RunSetup`: phát `SetGameMode` trước để client cập nhật mode và dọn dẹp state cũ, sau đó mới phát `SetTeamAssignment`.
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua)

### Lỗi kiểm tra Team khiến người chơi FFA không thể Freeze đối thủ
- **Ngày:** 14-08-2026
- **Vấn đề:** Trong chế độ Chaos (FFA), người chơi vung Icicle trúng nhau nhưng không ai bị đóng băng.
- **Nguyên nhân:** `FreezeService.HandleToolHit` có điều kiện guard yêu cầu cả Attacker và Target phải có `Team` attribute. Trong FFA không có team nào được gán nên sự kiện luôn bị return sớm.
- **Fix:** Phân nhánh logic trong `HandleToolHit`: nếu `Mode.HasTeams == true` thì kiểm tra theo team; nếu `Mode.HasTeams == false` (FFA) thì coi tất cả player có stats là kẻ địch và thực hiện Freeze nếu target đang Normal.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Lỗi NavigationButton vẫn hiển thị trong trận đấu Chaos
- **Ngày:** 14-08-2026
- **Vấn đề:** Khi vào trận Chaos, GUI NavigationButton (Menu lobby) không bị ẩn đi mà vẫn hiển thị trên màn hình.
- **Nguyên nhân:** `GameStateController.UpdateDisplay` kiểm tra `LocalPlayer:GetAttribute("Team")`. Ở chế độ FFA không có team nên controller coi LocalPlayer là Spectator và kích hoạt hiển thị GUI lobby.
- **Fix:** Chuyển sang kiểm tra `LocalPlayer:GetAttribute("InMatch") == true` để ẩn/hiện lobby GUI chính xác cho cả mode có team và không có team.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Lỗi Icicle Tool không được cấp phát trong chế độ FFA
- **Ngày:** 14-08-2026
- **Vấn đề:** Khi trận đấu Chaos bắt đầu, người chơi không nhận được Icicle trong Backpack.
- **Nguyên nhân:** `IcicleService.GiveToolToAll` lọc cấp tool bằng điều kiện `SessionService.GetTeam(Player) ~= nil`. Do Chaos không phân đội nên vòng lặp bỏ qua tất cả người chơi.
- **Fix:** Thay đổi điều kiện lọc trong `GiveToolToAll` sang kiểm tra `Player:GetAttribute("InMatch") == true`.
- **File liên quan:** [IcicleService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/IcicleService.lua)

### Lỗi LoadingScreen không hiển thị ở vòng đặc biệt FFA / Chaos
- **Ngày:** 15-08-2026
- **Vấn đề:** Khi bắt đầu trận đấu chế độ đặc biệt `Chaos`, màn hình đen chuyển cảnh `LoadingScreen` không xuất hiện.
- **Nguyên nhân:** `LoadingScreenController.StartFadeIn` kiểm tra `LocalPlayer:GetAttribute("Team")`. Chế độ `Chaos` không phân đội nên `Team` là `nil`, khiến hàm return sớm.
- **Fix:** Thay đổi điều kiện kiểm tra sang `(LocalPlayer:GetAttribute("InMatch") == true) or (LocalPlayer:GetAttribute("Team") ~= nil)`.
- **File liên quan:** [LoadingScreenController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/LoadingScreenController.lua)

### Lỗi phát sai nhạc nền và cho phép người chơi FFA mở Spectate
- **Ngày:** 15-08-2026
- **Vấn đề:** Người chơi trong trận FFA chỉ nghe nhạc Lobby thay vì nhạc InGame/FrozenState, và có thể mở Spectate Mode để theo dõi người khác khi đang thi đấu.
- **Nguyên nhân:** `MusicController` và `SpectateController` kiểm tra `Team ~= nil` để phân biệt Player và Spectator. Thiếu `Team` khiến hệ thống nhận định nhầm họ là Spectator.
- **Fix:** Chuyển điều kiện kiểm tra sang `InMatch == true`, đồng thời lắng nghe sự kiện `GetAttributeChangedSignal("InMatch")` để cập nhật trạng thái tức thời.
- **File liên quan:** [MusicController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Lỗi không loại bỏ người chơi chết và xử lý thoát game ở chế độ FFA
- **Ngày:** 15-08-2026
- **Vấn đề:** Trong trận FFA, người chơi chết/rơi vực không bị loại (không thu tool, không chuyển state Dead), và người chơi thoát game không kích hoạt kết thúc trận khi chỉ còn 1 người sống sót.
- **Nguyên nhân:** `FreezeService.EliminatePlayer` và `SessionService.PlayerRemoving` có điều kiện chặn `if not OldTeam then return end` hoặc chỉ kiểm tra `IsTeamWiped(Team)`.
- **Fix:** Bỏ điều kiện chặn `OldTeam`, xóa `InMatch`, kiểm tra điều kiện thắng `WinCondition == "FFA"` (`#GetAllNormalPlayers() <= 1`).
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua)

### Lỗi Runtime Reference biến cũ trong GameStatisticController
- **Ngày:** 15-08-2026
- **Vấn đề:** Khi nhấn nút `NextButton` ở bảng kết quả cuối trận, giao diện bị đơ và sinh lỗi script.
- **Nguyên nhân:** Hàm `ShowPlayerStats` truy xuất biến cũ `TeamWonStats` đã bị đổi tên thành `TopPlayersStats`.
- **Fix:** Sửa `TeamWonStats.Visible = false` thành `TopPlayersStats.Visible = false`.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)
