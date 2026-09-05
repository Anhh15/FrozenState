Searched for "function\s+[A-Za-z0-9_]+:(Init|Start)\(\)"
Viewed ScoreBoardController.lua:1-160
Viewed ScoreBoardController.lua:200-366
Viewed HotbarController.lua:1-150
Viewed HotbarController.lua:600-750
Searched for "PlaySwingSFX"
Searched for "UpdateFrozenState"
Searched for "PlayFreezeSFX"
Searched for "PlayThawSFX"
Searched for "NotifyAccolade"
Searched for "SyncPlayerData"
Searched for "EconomyConfig"
Searched for "PlayerStateConfig"
Searched for "ShopConfig"
Searched for "InventoryConfig"
Viewed InventoryConfig.lua:1-10
Searched for "SliderHelper"
Searched for "ItemCard"
Searched for "ViewportManager"
Viewed PlayerDataController.lua:1-209
Searched for "task\.wait"
Viewed SessionService.lua:1-150
Viewed SessionService.lua:400-465
Viewed TeamService.lua:1-83
Viewed MapService.lua:1-92

# 📊 BÁO CÁO TỔNG QUAN RÀ SOÁT TOÀN BỘ SRC

---

## 1. BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO

| Mức độ | Số lượng | Mô tả tóm tắt |
| :--- | :--- | :--- |
| 🔴 **CRITICAL** (Lỗ hổng bảo mật/Exploit) | 6 | Lỗ hổng Client-Trust trong `OnToolHit` (AoE exploit, bỏ qua vung kiếm), Raycast LoS bỏ qua vật thể `CanCollide=false`, thiếu Server Rate-limit trên các RemoteEvent (`RequestSpectateTarget`, `SaveSetting`), Exploit bypass match & cày Quest bằng `SetAfkState`, nguy cơ mất trắng dữ liệu khi Server Shutdown đột ngột (`BindToClose` race condition). |
| 🟠 **HIGH** (Lỗi kiến trúc/Race Condition/Leak) | 5 | Phá vỡ kiến trúc Lifecycle 2-pha trên Client (16/24 Controllers thiếu `Start()`), Rò rỉ kết nối `RBXScriptConnection` & RAM cache trong `HighlightController` / `MatchService`, Duplicate logic mở rương giữa `ShopService` và `QuestService`, lạm dụng polling mù quáng `task.wait(0.05)` thay vì Signal. |
| 🟡 **MEDIUM** (Hardcode/Thiếu nhất quán) | 7 | Vi phạm triết lý Zero Hardcode (hardcode TweenInfo, time delay, fallback Color3/offsets, magic numbers trong tính điểm & refund), Vi phạm quy ước đặt tên (hỗn hợp `_camelCase` và `_PascalCase`, biến loop chữ thường), Inline `require` trong event callback, Schema ProfileService dư thừa dữ liệu legacy. |
| 🟢 **LOW** (Code thừa/Format/Tối ưu nhỏ) | 4 | File cấu hình rỗng không sử dụng (`InventoryConfig.lua`), Section comment rác (`PRIVATE: Audio` trống trong `FreezeService`), gọi redundant RemoteEvent `UpdateMoney` gấp đôi, thừa listener lặp lại trong `ScoreBoardController`. |

---

## 2. CHI TIẾT CÁC ĐIỂM YẾU & NGUY CƠ BẢO MẬT (Xếp theo độ ưu tiên)

### [CRITICAL-01] Lỗ hổng Client-Trust trong `OnToolHit`: Bỏ qua Swing Animation & Exploit AoE diện rộng
- **Vị trí**: [FreezeService.lua:479-520](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L479-L520)
- **Mức độ**: 🔴 `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  1. `FreezeService` tiếp nhận `OnToolHit(Target)` trực tiếp từ Client. Server tự động khởi tạo phiên vung kiếm mới (`SwingStart = Now`) ngay khi nhận hit đầu tiên mà **HOÀN TOÀN KHÔNG KIỂM TRA** xem Client có vừa thực hiện vung kiếm (`OnToolSwing`) hay không!
  2. Trong khoảng thời gian `HitSwingWindow` (0.4 giây), Server cho phép nhận hit tiếp theo mà không giới hạn số lượng nạn nhân (để hỗ trợ chém lan).
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Hacker dùng Script Executor gọi trực tiếp `OnToolHit:FireServer(Victim)` mà không cần trang bị tool thực tế trên tay (hoặc chỉ cần cầm tool đứng yên, không hề chạy animation vung kiếm).
  - Hacker chỉ cần đứng giữa map, vòng lặp gửi `OnToolHit` cho toàn bộ người chơi đối phương trong bán kính 12 studs. Toàn bộ team địch sẽ bị đóng băng (hoặc giải cứu) ngay lập tức trong 1 frame duy nhất (Insta-Freeze AoE Hack).
- **Đề xuất giải pháp chuẩn**: 
  - Đưa cơ chế swing về đúng Server Authority: Khi Client bấm chuột, Client gửi `OnToolSwing`. Server kiểm tra Cooldown, ghi nhận `SwingStart = os.clock()` và cấp một `SwingToken` (hoặc mở cửa sổ tấn công hợp lệ trong RAM Server).
  - Khi `OnToolHit` gửi lên, Server bắt buộc phải kiểm tra: `(Now - SwingStart)` phải nằm chính xác trong khoảng `[HitStartTime, HitEndTime]` được định nghĩa trong `AnimationConfig`. Nếu chưa swing hoặc ngoài cửa sổ animation, drop ngay lập tức.
  - Giới hạn số lượng mục tiêu tối đa có thể trúng trong 1 cú vung kiếm (Max Targets Per Swing, ví dụ tối đa 2 hoặc 3 người).

---

### [CRITICAL-02] Raycast Line-of-Sight bỏ qua vật thể `CanCollide = false`: Đánh xuyên tường & xuyên kính
- **Vị trí**: [FreezeService.lua:531-538](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L531-L538)
- **Mức độ**: 🔴 `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  Đoạn kiểm tra Line-of-Sight (LoS) trên Server:
  ```lua
  local RayResult = workspace:Raycast(AttackerHRP.Position, RayDirection, RayParams)
  if RayResult and RayResult.Instance and RayResult.Instance.CanCollide then
      return
  end
  ```
  Server chỉ coi là bị cản nếu vật thể trúng phải có `CanCollide == true`.
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Trong thiết kế map Roblox, rất nhiều vật thể cản tầm nhìn như cửa sổ kính, cửa lưới, hàng rào laser, rèm cửa, hoặc các bức tường trang trí được bật `CanCollide = false` để tránh kẹt nhân vật.
  - Hacker lợi dụng điều này để đứng nấp sau các vách ngăn mờ/kính/lưới và chém xuyên qua địa hình để hạ gục đối thủ mà đối thủ không thể chạm tới mình.
  - Ngược lại, nếu giữa 2 người chơi có một `Part` vô hình dùng làm Trigger Zone nhưng vô tình bật `CanCollide = true`, đòn đánh hợp lệ của người chơi chân chính sẽ bị Server chặn oan uổng.
- **Đề xuất giải pháp chuẩn**: 
  - Sử dụng Collision Group chuyên biệt cho đòn đánh (ví dụ `RaycastCollisionGroup` hoặc `WeaponRaycast`).
  - Hoặc tạo whitelist kiểm tra `RayResult.Instance.Transparency < 0.9` và thuộc tính che chắn của Map Part thay vì dựa mù quáng vào thuộc tính vật lý `CanCollide`.

---

### [CRITICAL-03] Thiếu Rate-Limit trên các RemoteEvent: Nguy cơ Flood mạng & DDoS Server
- **Vị trí**: 
  - [MatchService.lua:820-872](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L820-L872) (`RequestSpectateTarget`)
  - [DataService.lua:801-809](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L801-L809) (`SaveSetting`)
- **Mức độ**: 🔴 `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  - `RequestSpectateTarget`: Bất kỳ Client nào cũng có thể bắn liên tục hàng nghìn request mỗi giây. Server phải thực hiện tìm kiếm Instance, kiểm tra trạng thái, và gán `ReplicationFocus`.
  - `SaveSetting`: Client bắn `{ Key, Value }`, Server thực hiện ghi trực tiếp vào `Profile.Data.Settings` mà không có bất kỳ bộ đệm hay debounce thời gian nào.
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Hacker dùng vòng lặp gửi liên tục 1,000 request `RequestSpectateTarget` hoặc `SaveSetting` mỗi giây. Server bị nghẽn Network Pipeline, CPU luồng chính của Server bị quá tải xử lý string/table parsing, gây tụt Heartbeat rate xuống dưới 20 FPS (Server Lag Spike) làm toàn bộ người chơi khác bị giật lag.
- **Đề xuất giải pháp chuẩn**: 
  - Bổ sung bảng debounce trên Server theo `UserId`:
    + `RequestSpectateTarget`: Tối đa 1 request mỗi 0.3s cho mỗi người chơi.
    + `SaveSetting`: Tối đa 1 request mỗi 1.0s cho mỗi người chơi (Client chỉ gửi khi người chơi nhả thanh kéo slider hoặc đóng menu).

---

### [CRITICAL-04] Lợi dụng `SetAfkState` để né trận & Farm tự động toàn bộ PlayTime Quest
- **Vị trí**: 
  - [MatchService.lua:67-71](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L67-L71), [MatchService.lua:766-786](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L766-L786)
  - [QuestService.lua:50-54](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L50-L54), [QuestService.lua:348-355](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L348-L355)
- **Mức độ**: 🔴 `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  - Khi người chơi gọi `SetAfkState(true)`, Server set attribute `IsAfk = true`. Trong `MatchService`, `GetAlivePlayers()` loại bỏ người chơi AFK, khiến họ không bao giờ bị dịch chuyển vào đấu trường.
  - Tuy nhiên, trong `QuestService`, sự kiện `OnPlayTime` được tính lũy kế thuần túy dựa trên thời gian kết nối server (`os.time() - _sessionStart[Player]`), hoàn toàn không phân biệt người chơi đang AFK ngoài sảnh hay đang thi đấu.
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Người chơi treo nick ở Lobby, bật AFK cả ngày mà không bị ai đóng băng, không chết, nhưng vẫn hoàn thành 100% các mốc Daily Quest và Milestone Quest liên quan đến PlayTime.
  - Nguy hiểm hơn: Nếu một server có 10 người nhưng 9 người bật AFK, trận đấu sẽ bị kẹt vĩnh viễn ở `Intermission` vì không bao giờ đủ người sống (`ActivePlayerCount < MinPlayers`). Server bị tê liệt gameplay.
- **Đề xuất giải pháp chuẩn**: 
  - Trong `QuestService.DispatchEvent("OnPlayTime")`: Chỉ tính thời gian nếu `PlayerStateHelper.IsInMatch(Player) == true` và `not PlayerStateHelper.IsAfk(Player)`.
  - Giới hạn thời gian AFK tối đa ở sảnh (ví dụ sau 10 phút AFK liên tục thì tự động Kick khỏi server để nhường slot cho người chơi khác).

---

### [CRITICAL-05] Mất dữ liệu PlayTime & Quest Progress khi Server Shutdown đột ngột (`BindToClose` Gap)
- **Vị trí**: [DataService.lua:147-164](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L147-L164), [QuestService.lua:670-695](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L670-L695)
- **Mức độ**: 🔴 `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  - `QuestService` đăng ký `FlushSession` qua `DataService.RegisterBeforeProfileRelease` để lưu thời gian chơi `PlayTime` vào `Profile.Data` trước khi profile bị đóng.
  - Nhưng trong `DataService`, các callback này **CHỈ ĐƯỢC GỌI** bên trong sự kiện `Players.PlayerRemoving`!
  - Khi game server bị Shutdown đột ngột (Roblox Server Migration, Developer Restart Servers), `ProfileService` kích hoạt `game:BindToClose` của riêng thư viện để `Release()` ngay lập tức toàn bộ profile đang mở trong RAM. Lúc này `PlayerRemoving` có thể không được kích hoạt, hoặc chạy khi Profile đã bị Release mất rồi.
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Bất cứ khi nào nhà phát triển cập nhật game hoặc server đóng phiên, toàn bộ người chơi trong server sẽ bị mất trắng số phút chơi trong phiên đó và mất các tiến trình Quest vừa đạt được trước đó vài phút.
- **Đề xuất giải pháp chuẩn**: 
  - Trong `DataService`, cần đăng ký một `game:BindToClose` độc lập trước khi ProfileService shutdown:
    ```lua
    game:BindToClose(function()
        for Player, Profile in pairs(ActiveProfiles) do
            for _, Callback in ipairs(_BeforeProfileReleaseCallbacks) do
                pcall(Callback, Player)
            end
        end
    end)
    ```

---

### [CRITICAL-06] Lỗ hổng Trinh sát Địa hình (ReplicationFocus Abuse) cho Lobby Spectator
- **Vị trí**: [MatchService.lua:862-871](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L862-L871)
- **Mức độ**: 🔴 `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  Server cho phép Lobby Spectator (`not IsInMatch`) tự do đặt `ReplicationFocus` vào bất kỳ người chơi nào đang thi đấu trong map.
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Trong các trận đấu giải hoặc chế độ cạnh tranh, một người chơi dùng tài khoản phụ (Alt account) đứng ở Lobby làm Spectator, chọn xem đối thủ.
  - Khi `ReplicationFocus` được gán vào đối thủ, toàn bộ vị trí các bẫy, đồng minh xung quanh đối thủ sẽ được Roblox Engine stream trực tiếp về máy của tài khoản phụ. Hacker đọc dữ liệu bộ nhớ RAM để làm "Radar / ESP map hack" báo vị trí cho đồng đội trong trận qua Discord.
- **Đề xuất giải pháp chuẩn**: 
  - Chỉ cho phép Spectate khi người chơi đã bị loại trong trận (`Dead` hoặc `Frozen` cùng đội).
  - Khóa tính năng Spectate tự do từ Lobby hoặc chỉ cho phép Spectate từ một vị trí camera tĩnh cố định trên khán đài Lobby, tuyệt đối không di dời `ReplicationFocus` của người ngoài trận vào sâu trong đấu trường.

---

### [HIGH-01] Phá vỡ kiến trúc Lifecycle 2-Pha trên Client: 16/24 Controllers thiếu `Start()`
- **Vị trí**: [Main.client.lua:41-90](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Main.client.lua#L41-L90) và 16 Controller modules
- **Mức độ**: 🟠 `HIGH`
- **Hiện trạng & Vấn đề**: 
  - `Main.client.lua` định nghĩa quy trình khởi động 2 pha:
    + Pha 1: `Init()` để cô lập lỗi, thiết lập nội bộ GUI.
    + Pha 2: `Start()` để bắt đầu lắng nghe mạng và tương tác liên Controller.
  - Tuy nhiên, chỉ có **8 Controller** có `Start()` (`InventoryController`, `GameStateController`, `NavigationController`, `ProfileController`, `SpectateController`, `QuestController`, `ShopController`, `SettingController`).
  - **16 Controller còn lại** (`HighlightController`, `HotbarController`, `MusicController`, `SoundController`, `ScoreBoardController`, `PlayerStatusController`, v.v.) **KHÔNG CÓ hàm `Start()`**. Tất cả đều nhồi nhét kết nối `RemoteEvent.OnClientEvent`, `UserInputService`, `PlayerAdded` vào ngay trong `Init()`!
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Khi Controller chạy ở đầu danh sách (như `HighlightController`) kết nối mạng ngay trong `Init()`, nếu server bắn event ngay lúc đó, nó sẽ gọi sang các Controller nằm sau (như `ScoreBoardController`, `PlayerStatusController`) khi các Controller này còn chưa kịp chạy xong hàm `Init()`.
  - Dẫn đến lỗi `attempt to index nil with ...` do GUI references chưa được khởi tạo.
- **Đề xuất giải pháp chuẩn**: 
  - Refactor toàn bộ 16 Controller: Chuyển toàn bộ các kết nối `RemoteEvent:Connect()`, `UserInputService:Connect()`, và tương tác chéo sang hàm `Start()`. Hàm `Init()` chỉ được phép resolve GUI hierarchy và tạo biến state nội bộ.

---

### [HIGH-02] Rò rỉ kết nối `CharacterAdded` & RAM Leak trong `HighlightController`
- **Vị trí**: [HighlightController.lua:174-202](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L174-L202), [HighlightController.lua:288-295](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L288-L295)
- **Mức độ**: 🟠 `HIGH`
- **Hiện trạng & Vấn đề**: 
  - Hàm `WatchPlayer(Player)` kết nối `Player.CharacterAdded:Connect(...)`. Khi người chơi rời game, kết nối này không được lưu trữ và không được disconnect.
  - Các bảng lưu trữ trạng thái `KnownTeams`, `_frozenPlayers`, `_playerStates` lưu key là `tostring(UserId)`. Khi người chơi rời game, không hề có sự kiện `Players.PlayerRemoving` để xóa các key này khỏi bộ nhớ.
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Trong các server công cộng chạy liên tục nhiều giờ (nơi hàng trăm người chơi ra vào liên tục), bộ nhớ Client sẽ bị phình to (Memory Leak), các closure giữ reference của Character cũ gây rác RAM và giảm hiệu năng render trên các thiết bị Mobile cấu hình yếu.
- **Đề xuất giải pháp chuẩn**: 
  - Lưu trữ connection của từng player vào bảng `_playerConnections[Player] = Connection`.
  - Lắng nghe `Players.PlayerRemoving` trên Client để disconnect toàn bộ listener và giải phóng `KnownTeams[UserIdStr] = nil`, `_frozenPlayers[UserIdStr] = nil`, `_playerStates[UserIdStr] = nil`.

---

### [HIGH-03] Trùng lặp & Không nhất quán Logic Mở Rương giữa `ShopService` và `QuestService`
- **Vị trí**: 
  - [ShopService.lua:29-60](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L29-L60), [ShopService.lua:125-154](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L125-L154)
  - [QuestService.lua:143-193](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L143-L193)
- **Mức độ**: 🟠 `HIGH`
- **Hiện trạng & Vấn đề**: 
  - Hai service cùng làm chung một việc là "mở rương, trao item, hoàn tiền nếu trùng" nhưng lại viết bằng 2 cách hoàn toàn khác nhau:
    + `ShopService`: Áp dụng kiến trúc 2 pha chuẩn: Pha 1 mô phỏng rút thưởng trong RAM với bảng `TemporaryOwned` để chống trùng trong phiên, Pha 2 Commit nguyên tử vào DataStore.
    + `QuestService`: Viết một hàm `ProcessChestReward` riêng biệt, không có `TemporaryOwned`, và gọi trực tiếp `DataService.AddIcicle` / `DataService.AddBlock` ngay trong vòng lặp quay thưởng!
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Nếu một phần thưởng Quest cho mở 3 rương cùng lúc: Logic của QuestService có thể bị lỗi tính toán tỷ lệ hoàn tiền hoặc ghi dữ liệu chắp vá nhiều lần vào Profile thay vì commit nguyên tử.
  - Vi phạm nghiêm trọng nguyên tắc DRY (Don't Repeat Yourself) và tính nhất quán cấu trúc hệ thống.
- **Đề xuất giải pháp chuẩn**: 
  - Tách logic mở rương thành một Module dùng chung trên Server: `ServerScriptService/Services/Helpers/ChestOpener.lua` (hoặc chuyển vào `RewardHelper`). Cả `ShopService` và `QuestService` đều phải gọi qua module này.

---

### [HIGH-04] Lạm dụng Polling mù quáng `task.wait(0.05)` trong `PlayerDataController`
- **Vị trí**: [PlayerDataController.lua:117-120](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua#L117-L120), [PlayerDataController.lua:136-139](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua#L136-L139)
- **Mức độ**: 🟠 `HIGH`
- **Hiện trạng & Vấn đề**: 
  - Trong `WaitForData()` và `RefreshData()`:
    ```lua
    while not _isDataLoaded and (os.clock() - StartTime < Timeout) do
        task.wait(0.05)
    end
    ```
  - Đoạn code sử dụng vòng lặp bận (Busy-waiting loop) kiểm tra liên tục mỗi 50ms, trong khi ngay tại dòng 22 đã khởi tạo sẵn `_dataLoadedBindable = Instance.new("BindableEvent")`!
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Gây lãng phí CPU thread trên client một cách vô nghĩa, tạo code smell nghiêm trọng về kỹ năng tối ưu Luau.
- **Đề xuất giải pháp chuẩn**: 
  - Sử dụng Event-driven chuẩn:
    ```lua
    if not _isDataLoaded then
        local Connection
        local Thread = coroutine.running()
        local DelayTask = task.delay(Timeout, function()
            if Connection then Connection:Disconnect() end
            task.spawn(Thread)
        end)
        Connection = _dataLoadedBindable.Event:Connect(function()
            task.cancel(DelayTask)
            Connection:Disconnect()
            task.spawn(Thread)
        end)
        coroutine.yield()
    end
    return _localData
    ```

---

### [HIGH-05] Rò rỉ `CharacterAdded` và lặp kết nối `Humanoid.Died` trong `MatchService`
- **Vị trí**: [MatchService.lua:730-749](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L730-L749)
- **Mức độ**: 🟠 `HIGH`
- **Hiện trạng & Vấn đề**: 
  - Trong `BindPlayer(Player)`:
    ```lua
    Player.CharacterAdded:Connect(function(Char)
        BindCharacterDeath(Player, Char)
    end)
    ```
  - Kết nối `CharacterAdded` được tạo ra khi Player join nhưng không bao giờ được lưu vào biến quản lý để ngắt kết nối khi player thoát game.
- **Kịch bản khai thác / Hậu quả thực tế**: 
  - Nếu kết nối Player giữ tham chiếu tới Player instance trong closure, nó sẽ ngăn chặn việc thu hồi bộ nhớ của Engine đối với Player đã rời game.
- **Đề xuất giải pháp chuẩn**: 
  - Lưu kết nối vào bảng `_PlayerConnections[Player.UserId]` và thực hiện `:Disconnect()` đầy đủ trong `Players.PlayerRemoving`.

---

### [MEDIUM-01] Vi phạm Triết lý Zero Hardcode: TweenInfo & Delay bị gán cứng trong Controllers
- **Vị trí**: 
  - [QuestController.lua:66-67](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua#L66-L67): `TweenInfo.new(0.25, ...)`, `TweenInfo.new(0.2, ...)`
  - [SettingController.lua:98, 114](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua#L98): `TweenInfo.new(0.15, ...)`
  - [HighlightController.lua:187](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L187): `task.wait(0.1)`
  - [MatchService.lua:469, 663, 799](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L469): `task.wait(0.5)`, `task.wait(0.2)`, `task.wait(2)`
- **Mức độ**: 🟡 `MEDIUM`
- **Hiện trạng & Vấn đề**: 
  - Mặc dù dự án đã có hẳn file [GuiAnimConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GuiAnimConfig.lua), nhưng các Controller trên vẫn tự ý tạo mới `TweenInfo.new` với các con số ma thuật (`0.25`, `0.2`, `0.15`) hoặc dùng `task.wait(0.1)`, `task.wait(0.5)`.
- **Hậu quả**: Khi designer muốn tinh chỉnh tốc độ UI mượt hơn hoặc thay đổi nhịp độ game, họ không thể chỉnh tập trung trong file Config mà phải đào bới từng dòng code trong các file Controller.
- **Đề xuất giải pháp chuẩn**: Đưa toàn bộ các cấu hình Tween này vào `GuiAnimConfig.Quest` và `GuiAnimConfig.Settings`. Đưa các khoảng delay buffer vào `GameConfig.Match`.

---

### [MEDIUM-02] Vi phạm Quy ước Đặt tên: Hỗn hợp `_camelCase` và Biến Loop Chữ thường
- **Vị trí**: 
  - `MatchService.lua`: `_currentPhase`, `_earlyResult`, `_roundCounter`
  - `FreezeService.lua`: `_firstBloodClaimed`, `_iceBlocks` (nhưng dòng dưới lại viết `_AttackSessions`!)
  - `QuestService.lua`: `_sessionStart`, `_lastPlayTimeSync`, `_matchProgress` (nhưng dòng dưới lại viết `_ResetLocks`!)
  - `SessionService.lua:129-140`: `for _, p in ...`, `for i = ...`, `local j = math.random(...)`
  - `MatchService.lua:529, 565, 640`: `for t = Duration, 0, -1 do`
- **Mức độ**: 🟡 `MEDIUM`
- **Hiện trạng & Vấn đề**: 
  - Quy ước dự án bắt buộc: **100% PascalCase và tiếng Anh cho tất cả biến, hàm**.
  - Việc đặt biến private bắt đầu bằng `_` kết hợp `camelCase` là sự thiếu nhất quán nội bộ rõ rệt: cùng một file lại tồn tại cả `_iceBlocks` lẫn `_AttackSessions`, cùng có cả `_sessionStart` lẫn `_ResetLocks`.
- **Đề xuất giải pháp chuẩn**: Chuẩn hóa 100% về PascalCase: `_CurrentPhase`, `_EarlyResult`, `_RoundCounter`, `_FirstBloodClaimed`, `_IceBlocks`, `_SessionStart`, `_LastPlayTimeSync`, `_MatchProgress`. Biến loop đổi thành `for Index = ...`, `for TimeLeft = ...`.

---

### [MEDIUM-03] Inline `require` trong Event Callback của `SessionService`
- **Vị trí**: [SessionService.lua:424-426](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua#L424-L426)
- **Mức độ**: 🟡 `MEDIUM`
- **Hiện trạng & Vấn đề**: 
  Trong sự kiện `Players.PlayerRemoving`, xuất hiện đoạn code:
  ```lua
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)
  local UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
  ```
  Trong khi `ReplicatedStorage` đã được khai báo ở dòng 2 của file, nhưng `RemoteDefinitions` lại được require inline ngay bên trong callback của PlayerRemoving.
- **Hậu quả**: Vi phạm cấu trúc chuẩn (Imports luôn ở đầu file), gây tốn chi phí lookup bảng và vi phạm tính nhất quán với các Service khác.
- **Đề xuất giải pháp chuẩn**: Chuyển `RemoteDefinitions` lên đầu file cùng các import khác, và lấy reference của `UpdatePlayerStateEvent` trong `Init()`.

---

### [MEDIUM-04] Magic Numbers trong Tính điểm ScoreBoard & Tỷ lệ Hoàn tiền
- **Vị trí**: 
  - [ScoreBoardController.lua:55](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua#L55): `local TotalScore = (F + T) * 1000 + F`
  - [QuestService.lua:151, 208](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L151): `local RefundBasePrice = Chest.Price1 or 1000`, `local BasePrice = 1000`
- **Mức độ**: 🟡 `MEDIUM`
- **Hiện trạng & Vấn đề**: 
  - Con số trọng số `1000` trong `ScoreBoardController` là một magic number không có chú thích ngữ cảnh hay cấu hình.
  - Con số `1000` giá trị mặc định cho `BasePrice` hoàn tiền trong `QuestService` là một con số hardcode độc đoán, không lấy từ `EconomyConfig` hay `ChestConfig`.
- **Đề xuất giải pháp chuẩn**: Đưa trọng số hiển thị vào `GuiConfig.ScoreBoard.FreezePriorityWeight = 1000`. Đưa giá sàn hoàn tiền vào `EconomyConfig.DefaultRefundBasePrice = 1000`.

---

### [MEDIUM-05] Dữ liệu Legacy & Duplicate Schema trong `ProfileService`
- **Vị trí**: [DataService.lua:30, 48-52](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L30)
- **Mức độ**: 🟡 `MEDIUM`
- **Hiện trạng & Vấn đề**: 
  Schema lưu trữ DataStore đang duy trì song song cả trường dữ liệu mới lẫn trường dữ liệu cũ đã lỗi thời:
  - `OwnedCosmetics` (cũ) song song với `OwnedIcicles` và `OwnedBlocks` (mới).
  - `DailyQuestData` và `MilestoneQuestData` (cũ) song song với `QuestData.Daily` và `QuestData.Milestone` (mới).
  - Khi cập nhật Daily Quest ở dòng 604, code phải ghi đúp vào cả `Profile.Data.QuestData.Daily` lẫn `Profile.Data.DailyQuestData`.
- **Hậu quả**: Làm tăng dung lượng mỗi bản ghi Profile, tiến tới giới hạn 4MB DataStore vô ích và gây nhầm lẫn nghiêm trọng cho bất kỳ lập trình viên nào bảo trì hệ thống sau này.
- **Đề xuất giải pháp chuẩn**: Viết logic Data Migration 1 chiều trong `OnProfileLoaded`: Đọc dữ liệu từ trường cũ sang trường mới nếu có, sau đó gán `Profile.Data.DailyQuestData = nil`, `Profile.Data.MilestoneQuestData = nil`, `Profile.Data.OwnedCosmetics = nil`.

---

### [MEDIUM-06] Kiểm tra Chat Admin bằng API cũ `Player.Chatted`
- **Vị trí**: [AdminService.lua:429-440](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/AdminService.lua#L429-L440)
- **Mức độ**: 🟡 `MEDIUM`
- **Hiện trạng & Vấn đề**: 
  `AdminService` lắng nghe dòng lệnh quản trị qua `Player.Chatted`.
- **Hậu quả**: Kể từ năm 2023, Roblox đã nâng cấp toàn bộ hệ thống trò chuyện sang `TextChatService` làm mặc định. Nếu Place cài đặt `TextChatService.ChatVersion = Enum.ChatVersion.TextChatService`, sự kiện `Player.Chatted` phía Server **SẼ KHÔNG HOẠT ĐỘNG HOẶC HOẠT ĐỘNG KHÔNG ỔN ĐỊNH**.
- **Đề xuất giải pháp chuẩn**: Tích hợp thêm handler cho `TextChatService`:
  ```lua
  local TextChatService = game:GetService("TextChatService")
  -- Đăng ký TextChatCommand hoặc lắng nghe OnIncomingMessageCallback
  ```

---

### [MEDIUM-07] Mua rương: Gọi `AddMoney` 2 lần liên tiếp thay vì tính số tiền thực nhận
- **Vị trí**: [ShopService.lua:139-142](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L139-L142)
- **Mức độ**: 🟡 `MEDIUM`
- **Hiện trạng & Vấn đề**: 
  Trong Pha 2 Commit của `BuyChest`:
  ```lua
  DataService.AddMoney(Player, -TotalPrice)
  if TotalRefund > 0 then
      DataService.AddMoney(Player, TotalRefund)
  end
  ```
  Server thực hiện 2 lần ghi liên tiếp vào Profile: trừ toàn bộ tiền, rồi ngay lập tức cộng lại tiền hoàn lại.
- **Hậu quả**: Không đảm bảo tính toàn vẹn giao dịch (Transaction Atomicity). Nếu có lỗi xảy ra ở giữa, người chơi sẽ bị mất tiền mà không được nhận hoàn tiền.
- **Đề xuất giải pháp chuẩn**: Tính toán biến động tiền tệ ròng:
  ```lua
  local NetCost = TotalPrice - TotalRefund
  if NetCost > 0 then
      DataService.AddMoney(Player, -NetCost)
  end
  ```

---

### [LOW-01] File cấu hình rác không được sử dụng: `InventoryConfig.lua`
- **Vị trí**: [InventoryConfig.lua:1-10](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/InventoryConfig.lua#L1-L10)
- **Mức độ**: 🟢 `LOW`
- **Hiện trạng & Vấn đề**: File cấu hình rỗng `local InventoryConfig = {}`, không chứa tham số nào và không được bất kỳ Service, Controller hay Helper nào trong dự án `require`.
- **Đề xuất giải pháp chuẩn**: Xóa bỏ file hoặc di chuyển các tham số liên quan đến Inventory UI (hiện đang nằm rải rác trong `GuiConfig`) vào đây.

---

### [LOW-02] Comment rác để lại sau khi xóa code trong `FreezeService`
- **Vị trí**: [FreezeService.lua:159-163](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L159-L163)
- **Mức độ**: 🟢 `LOW`
- **Hiện trạng & Vấn đề**: 
  ```lua
  -- =========================================================
  -- PRIVATE: Audio
  -- =========================================================
  ```
  Phần tiêu đề còn nguyên nhưng bên dưới không có bất kỳ dòng code nào.
- **Đề xuất giải pháp chuẩn**: Xóa bỏ tiêu đề thừa để giữ code sạch sẽ.

---

### [LOW-03] Bắn trùng lặp RemoteEvent `UpdateMoney` gây lãng phí băng thông
- **Vị trí**: [QuestService.lua:609, 615](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L609)
- **Mức độ**: 🟢 `LOW`
- **Hiện trạng & Vấn đề**: Khi Claim Quest loại tiền tệ, `RewardHelper.RewardAndSync` đã tự động fire `UpdateMoneyEvent` về Client. Tuy nhiên, ở dòng 615, `QuestService` lại tiếp tục gọi `UpdateMoneyEvent:FireClient(Player, NewMoney)` một lần nữa, và đồng thời trả về `NewMoney` trong kết quả của `RemoteFunction`.
- **Đề xuất giải pháp chuẩn**: Xóa bỏ lệnh gọi thừa ở dòng 615.

---

### [LOW-04] Lặp Listener `UserInputService` trong `ScoreBoardController`
- **Vị trí**: [ScoreBoardController.lua:290, 308](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua#L290)
- **Mức độ**: 🟢 `LOW`
- **Hiện trạng & Vấn đề**: Code chia làm 2 block `UserInputService.InputBegan` riêng biệt: 1 cái cho Ctrl (PC) và 1 cái cho R1 (Console), tương tự với `InputEnded`.
- **Đề xuất giải pháp chuẩn**: Gộp chung thành 1 listener duy nhất kiểm tra phím để giảm số lượng callback được engine gọi mỗi khi có input.

---

## 3. DANH SÁCH CÁC ĐIỂM MÂU THUẪN CẦN PHẢN BIỆN (DEBATE LIST)

Dưới đây là các mâu thuẫn cốt lõi về mặt thiết kế giữa Client - Server đang xung đột logic. Cần người quyết định kiến trúc dự án chốt hướng đi:

### 1. Tranh luận về Thẩm quyền Tấn công (Hit Authority): Client-Authoritative vs Server-Authoritative?
- **Vấn đề**: Hiện tại dự án đang chọn giải pháp *Client-side detection* (`GetPartsInPart` trên máy client) rồi gửi `OnToolHit` lên Server để Server validate khoảng cách.
- **Phản biện sắc bén**: Mô hình này sinh ra lỗ hổng nghiêm trọng: **Server tin tưởng mục tiêu do Client chọn**. Dù Server có kiểm tra khoảng cách và Raycast, Hacker vẫn có thể gửi target trúng 100% mà không cần ngắm, không cần vung kiếm.
- **Hai hướng lựa chọn**:
  - *Phương án A (Bảo mật tuyệt đối - Khuyên dùng cho game thi đấu)*: **Server-Side Cast**. Client bấm chuột chỉ gửi yêu cầu `Swing`. Server tự chạy Raycast / Shapecast từ vị trí nhân vật Attacker trên Server. Client chỉ hiển thị hình ảnh minh họa. Không có bất kỳ remote `OnToolHit` nào tồn tại.
  - *Phương án B (Bù trễ mạng mượt mà - Giữ nguyên kiến trúc hiện tại)*: Tiếp tục cho Client gửi `OnToolHit`, **NHƯNG Server phải tạo Session State nghiêm ngặt**: Chỉ chấp nhận `OnToolHit` nếu Client ĐÃ GỬI `OnToolSwing` trước đó từ 0.1s - 0.4s. Nếu không có `OnToolSwing` đi kèm token hợp lệ, coi như Exploit.

---

### 2. Tranh luận về Trạng thái AFK và Cơ chế Tính giờ chơi (AFK vs PlayTime Quests)
- **Vấn đề**: Dự án cho phép người chơi gạt toggle AFK trong Settings để không bị kéo vào trận. Nhưng hệ thống nhiệm vụ lại tính `PlayTime` theo thời gian thực kết nối vào Server.
- **Phản biện sắc bén**: Đây là thiết kế tự mâu thuẫn. Nếu cho phép AFK tự do mà vẫn thưởng Quest, người chơi sẽ biến game thành game "treo máy giả lập" (Idle game). Ngược lại, nếu tắt hoàn toàn AFK thì người chơi muốn xem đồ trong shop hay bận việc riêng sẽ bị chết oan trong trận.
- **Hướng giải quyết**:
  - Chỉ tính `PlayTime` cho Quest khi người chơi **thực sự tham gia trận đấu** (`IsInMatch == true` và đang ở trạng thái `Normal`/`Frozen`).
  - Nếu ở sảnh quá 5 phút mà không tham gia trận đấu nào, ngắt kết nối hoặc tạm dừng toàn bộ tích lũy phần thưởng.

---

### 3. Tranh luận về Chuẩn hóa Lifecycle Client: Xóa bỏ hoàn toàn việc gọi Mạng trong `Init()`
- **Vấn đề**: 16/24 Controller đang tiện tay kết nối mạng và gán sự kiện ngay trong `Init()`. Một số Controller thì tuân thủ tách ra `Start()`.
- **Phản biện sắc bén**: Không thể tồn tại một dự án chuyên nghiệp mà một nửa làm theo chuẩn này, một nửa làm theo chuẩn khác. Việc chạy code mạng trong `Init()` phá hủy toàn bộ giá trị của `ServiceLoader` / `Main.client.lua`.
- **Yêu cầu thống nhất**:
  - Bắt buộc **100% Controller phải có cả 2 hàm `Init()` và `Start()`**.
  - Quy tắc bất di bất dịch: Trong `Init()`, không được phép gọi `RemoteDefinitions.GetEvent()`, không được kết nối `OnClientEvent`, không được gọi sang Controller khác. Tất cả việc đó phải chuyển 100% sang `Start()`.

---

### 4. Tranh luận về Quy ước đặt tên: Khái niệm "100% PascalCase"
- **Vấn đề**: Quy ước ghi "100% PascalCase cho mọi biến", nhưng lập trình viên lại dùng tiền tố `_` kèm camelCase cho biến private (như `_currentPhase`, `_isSpectating`).
- **Phản biện sắc bén**:
  - Nếu chấp nhận biến private có tiền tố `_`, thì từ ngữ phía sau `_` phải viết hoa theo chuẩn Luau PascalCase (`_CurrentPhase`, `_IsSpectating`) để đồng nhất với `_AttackSessions` và `_ResetLocks`.
  - Việc tồn tại song song cả `_iceBlocks` lẫn `_AttackSessions` trong cùng một file chứng tỏ sự cẩu thả trong khâu kiểm soát chất lượng code (Code Style Enforcing).
- **Yêu cầu thống nhất**: Toàn bộ biến private có tiền tố `_` đều phải viết dạng `_PascalCase`. Biến loop đổi sang `Index`, `Key`, `Value`, `TimeRemaining`.