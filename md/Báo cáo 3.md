# 📊 BÁO CÁO TỔNG QUAN RÀ SOÁT TOÀN BỘ SRC

> **Phiên bản:** 2026-09-01 | **Phạm vi:** `src/ServerScriptService`, `src/StarterPlayer`, `src/ReplicatedStorage` | **47 files, ~350KB code**

---

## 1. BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO

| Mức độ | Số lượng | Mô tả tóm tắt |
| :--- | :---: | :--- |
| 🔴 **CRITICAL** | **5** | Lỗ hổng bảo mật cho phép hacker exploit: thiếu Raycast/LOS validation, thiếu cooldown OnToolHit, IceBlock orphan leak khi player out, SaveSetting type injection, RequestSpectateTarget type injection |
| 🟠 **HIGH** | **7** | Rò rỉ kết nối client nghiêm trọng, scan Workspace O(N*M), code chắp vá lazy-require QuestService, logic trùng lặp WeightedRandom, Client thiếu lifecycle `Start()`, task.wait duct-tape |
| 🟡 **MEDIUM** | **14** | Hardcode magic number/string trong Services & Controllers, vi phạm naming convention UPPER_SNAKE_CASE |
| 🟢 **LOW** | **4** | Dead code, hiệu năng spatial lookup, code trùng lặp nhỏ |

---

## 2. CHI TIẾT CÁC ĐIỂM YẾU & NGUY CƠ (Xếp theo độ ưu tiên)

---

### 🔴 CRITICAL-01: OnToolHit thiếu Raycast / Line of Sight Validation

- **Vị trí:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L477-L526)
- **Mức độ:** `CRITICAL`
- **Hiện trạng & Vấn đề:**
  Server chỉ kiểm tra `Magnitude` (dòng 497-498) để validate khoảng cách giữa Attacker và Victim. **Không có Raycast/Line of Sight check**. Hacker chỉ cần gửi `OnToolHit(TargetPlayer)` từ client — server sẽ chấp nhận miễn khoảng cách ≤ `HitboxRange * 1.5` (30 studs), kể cả khi có **tường chắn** giữa hai người.
- **Kịch bản khai thác:**
  Exploit script gửi `OnToolHit:FireServer(VictimPlayer)` liên tục cho bất kỳ ai trong bán kính 30 studs mà không cần line of sight. Hacker đứng sau tường freeze toàn bộ đối thủ.
- **Đề xuất giải pháp:**
  Thêm `workspace:Raycast()` từ `AttackerHRP.Position` đến `TargetHRP.Position` với `RaycastParams` bỏ qua character Attacker. Nếu ray bị chặn bởi vật thể solid → reject hit.

---

### 🔴 CRITICAL-02: OnToolHit thiếu Cooldown / Rate Limiting

- **Vị trí:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L477-L526)
- **Mức độ:** `CRITICAL`
- **Hiện trạng & Vấn đề:**
  `OnToolSwing` trong [IcicleService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/IcicleService.lua#L156-L163) **CÓ** cooldown chống spam (`_lastSwingTimes`). Nhưng `OnToolHit` trong `FreezeService` lại **KHÔNG CÓ** cooldown tương tự. Hacker có thể bỏ qua client hoàn toàn, gửi hàng trăm `OnToolHit` event mỗi giây.
- **Kịch bản khai thác:**
  Exploit gửi `OnToolHit:FireServer(target)` ở tốc độ cao → mỗi lần target vừa được thaw, lập tức bị freeze lại. Trong FFA mode, hacker spam freeze toàn bộ lobby trong tích tắc.
- **Đề xuất giải pháp:**
  Thêm `_lastHitTimes = {}` cache trong `FreezeService` tương tự `_lastSwingTimes` trong `IcicleService`. Reject hit nếu `(Now - LastHit) < GameConfig.Tool.IcicleCooldown`.

---

### 🔴 CRITICAL-03: PlayerRemoving không Destroy IceBlock → Instance Leak vĩnh viễn

- **Vị trí:** [FreezeService.lua:544-546](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L544-L546)
- **Mức độ:** `CRITICAL`
- **Hiện trạng & Vấn đề:**
  Khi player đang bị **Frozen** rời game, listener `PlayerRemoving` chỉ set `_iceBlocks[Player.UserId] = nil` mà **không gọi `:Destroy()`** trên IceBlock Model. Kết quả: Model IceBlock mồ côi nằm vĩnh viễn trong `Workspace`, tích lũy qua nhiều trận, gây rò rỉ bộ nhớ server và tải physics không cần thiết.
- **Kịch bản khai thác:**
  Không cần hacker — đây là bug tự nhiên. Mỗi khi player frozen disconnect, server dính thêm 1 IceBlock orphan. Qua hàng trăm trận, server lag nghiêm trọng.
- **Đề xuất giải pháp:**
  Thay dòng 545 bằng `RemoveIceBlock(Player)` (đã có sẵn hàm này, sẽ Destroy + clear cache).

---

### 🔴 CRITICAL-04: SaveSetting thiếu Sanity Check cho Value

- **Vị trí:** [DataService.lua:741-748](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L741-L748)
- **Mức độ:** `CRITICAL`
- **Hiện trạng & Vấn đề:**
  Handler `SaveSetting` nhận `Payload.Value` từ client, kiểm tra `Key` qua whitelist `VALID_SETTING_KEYS` (tốt), nhưng `Value` chỉ được clamp khi `type(Value) == "number"`. Nếu hacker gửi `Value = "hack"`, `Value = {}` (bảng lồng), `Value = Instance.new(...)` hoặc `Value = string.rep("A", 1000000)` — giá trị đó sẽ được **ghi thẳng vào Profile.Data.Settings** và persist vào DataStore.
- **Kịch bản khai thác:**
  Hacker gửi `SaveSetting:FireServer({Key = "MasterVolume", Value = string.rep("X", 100000)})` → DataStore bị ghi chuỗi khổng lồ → profile bloat → potential DataStore budget exceeded → player bị mất dữ liệu.
- **Đề xuất giải pháp:**
  Thêm type guard cứng: `if type(Value) ~= "number" then return end` trước khi gọi `DataService.SetSetting()`. Settings hiện tại chỉ có Volume → chỉ chấp nhận number.

---

### 🔴 CRITICAL-05: RequestSpectateTarget không validate kiểu Target

- **Vị trí:** [MatchService.lua:794](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L794-L845)
- **Mức độ:** `CRITICAL`
- **Hiện trạng & Vấn đề:**
  `TargetPlayer` được nhận trực tiếp từ client mà không kiểm tra `type(TargetPlayer)` hay `TargetPlayer:IsA("Player")` trước khi gọi `TargetPlayer:IsDescendantOf()` (dòng 815). Hacker gửi `TargetPlayer = { IsDescendantOf = function() return true end, Character = ... }` → có thể crash handler hoặc bypass validation.
- **Kịch bản khai thác:**
  Inject userdata giả → crash server thread hoặc set `ReplicationFocus` vào instance tùy ý.
- **Đề xuất giải pháp:**
  Thêm `if TargetPlayer ~= nil and (typeof(TargetPlayer) ~= "Instance" or not TargetPlayer:IsA("Player")) then return end` ngay đầu handler.

---

### 🟠 HIGH-01: IcicleScript.client — Track.Stopped Connection Tích Lũy

- **Vị trí:** [IcicleScript.client.lua:237](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua#L237)
- **Mức độ:** `HIGH`
- **Hiện trạng & Vấn đề:**
  Mỗi lần `Tool.Activated`, script connect `Track.Stopped:Connect(...)` mà không disconnect connection cũ. Track được cache và reuse → mỗi swing thêm 1 connection mới. Qua hàng trăm swing trong 1 trận: hàng trăm orphaned connection → **client memory leak + lag tăng dần**.
- **Đề xuất giải pháp:**
  Đổi `:Connect(...)` thành `:Once(...)` để tự cleanup sau 1 lần fire.

---

### 🟠 HIGH-02: HighlightController Workspace Scan O(N*M)

- **Vị trí:** [HighlightController.lua:57-61](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L57-L61)
- **Mức độ:** `HIGH`
- **Hiện trạng & Vấn đề:**
  `FindIceBlockForPlayer` fallback loop qua `Workspace:GetChildren()`. Hàm này được gọi từ `RefreshAll()`, mà `RefreshAll()` connect với `Workspace.ChildAdded`. **Mỗi khi bất kỳ Instance nào được thêm vào Workspace**, client scan toàn bộ `Workspace` × số lượng players → O(N*M) — gây **micro-freeze client nghiêm trọng** trên map phức tạp.
- **Đề xuất giải pháp:**
  Loại bỏ fallback `Workspace:GetChildren()`. Dùng `CollectionService:GetTagged()` (đã có `TagHelper`) để tìm IceBlock trực tiếp.

---

### 🟠 HIGH-03: Lazy-Require QuestService Pattern — Duct-Tape Hack

- **Vị trí:**
  - [FreezeService.lua:277-289](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L277-L289), [380-391](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L380-L391)
  - [ShopService.lua:157-167](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L157-L167)
  - [MatchService.lua:389-395](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L389-L395), [597-617](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L597-L617)
- **Mức độ:** `HIGH`
- **Hiện trạng & Vấn đề:**
  Boilerplate `script.Parent:FindFirstChild("QuestService") → require()` lặp lại ở **5 vị trí** trong 3 service khác nhau. Đây là hack để bypass circular dependency, phá vỡ static analysis và gây overhead runtime.
- **Đề xuất giải pháp:**
  Triển khai **Event Bus / Signal Hub** trung tâm (Observer pattern). Các service fire event (`EventBus.Fire("OnFreeze", data)`), QuestService subscribe tại `Init()`. Hoặc thêm `ServiceLoader.GetService("QuestService")` dạng Service Locator.

---

### 🟠 HIGH-04: WeightedRandom Duplicated Logic

- **Vị trí:**
  - [ShopService.lua:26-37](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L26-L37)
  - [QuestService.lua:149-159](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L149-L159)
- **Mức độ:** `HIGH`
- **Hiện trạng & Vấn đề:**
  Hai hàm `WeightedRandom()` và `WeightedRandomItem()` **sao chép y hệt** giữa `ShopService` và `QuestService`. Vi phạm nghiêm trọng DRY — nếu fix bug random ở 1 chỗ, chỗ kia vẫn lỗi.
- **Đề xuất giải pháp:**
  Extract ra `ReplicatedStorage/Shared/Tools/MathHelper.lua` hoặc thêm vào `RewardHelper.lua`.

---

### 🟠 HIGH-05: Client Controllers Thiếu Lifecycle `Start()`

- **Vị trí:** [Main.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Main.client.lua#L40-L69) + Toàn bộ 24 Controllers
- **Mức độ:** `HIGH`
- **Hiện trạng & Vấn đề:**
  **Tất cả 24 Controllers** chỉ có `Init()`, không có `Start()`. Server có mô hình 2 pha rõ ràng (`Init` → `Start`) qua `ServiceLoader`, nhưng Client gộp tất cả vào `Init()`. Khi Controller A cần gọi Controller B trong `Init()` mà B chưa `Init()` xong → **race condition ẩn**.
  
  Vi phạm trực tiếp triết lý: *"Các hệ thống tương tự nhau phải ưu tiên sự nhất quán về cấu trúc"*.
- **Đề xuất giải pháp:**
  Thêm `Start()` cho toàn bộ Controller. Tạo `ControllerLoader.lua` tương đương `ServiceLoader.lua`. `Main.client.lua` gọi 2 pha: loop `Init()` → loop `Start()`.

---

### 🟠 HIGH-06: task.wait() Duct-Tape Delays

- **Vị trí:**
  - [MatchService.lua:457](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L457): `task.wait(0.5)` — buffer map load
  - [MatchService.lua:655](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L655): `task.wait(0.2)` — physics sync
  - [MatchService.lua:776](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L776): `task.wait(2)` — player join mid-match
- **Mức độ:** `HIGH`
- **Hiện trạng & Vấn đề:**
  3 chỗ dùng delay mù quáng thay vì lắng nghe Signal/Event:
  - `task.wait(0.5)` giả định map load xong trong 0.5s → nếu map nặng, player rơi vào void.
  - `task.wait(2)` giả định client ready trong 2s → nếu client chậm, data sync bị miss; nếu client nhanh, phí 2s.
- **Đề xuất giải pháp:**
  - Map load: dùng `MapService.OnMapLoaded` Signal.
  - Player join: chờ `FinishGameLoading` event (đã có sẵn ở dòng 749!).
  - Physics: dùng `RunService.Heartbeat:Wait()`.

---

### 🟠 HIGH-07: DataService.WaitForProfile Busy-Wait Loop

- **Vị trí:** [DataService.lua:175-177](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L175-L177)
- **Mức độ:** `HIGH`
- **Hiện trạng & Vấn đề:**
  `while not ProfileResult ... task.wait(0.05) end` — polling loop mỗi 50ms dù `_ProfileLoadedBindable.Event` đã connected ngay phía trên. Tốn CPU không cần thiết.
- **Đề xuất giải pháp:**
  Sử dụng yield trực tiếp trên `_ProfileLoadedBindable.Event:Wait()` thay vì polling loop.

---

### 🟡 MEDIUM-01 → 07: Hardcode Magic Numbers

| # | File | Dòng | Giá trị | Config nên dùng |
|:--|:-----|:-----|:--------|:----------------|
| 01 | [QuestService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L231) | 231 | `BasePrice = 1000` | `EconomyConfig.RefundBasePrice` |
| 02 | [ShopService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L101-L102) | 101-102 | `MinQty = 1`, `MaxQty = 5` | `ShopConfig.MinAmount`, `ShopConfig.MaxAmount` (đã có!) |
| 03 | [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L498) | 498 | `* 1.5` (lag tolerance) | `GameConfig.Tool.HitLagTolerance` |
| 04 | [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L647) | 647 | `Vector3.new(0, 4, 0)` | `MapConfig.LobbySpawnOffset` |
| 05 | [AudioHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AudioHelper.lua#L152) | 152, 231 | `task.delay(10, ...)`, `task.delay(8, ...)` | `AudioConfig.CleanupDelay` |
| 06 | [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua#L61-L66) | 61-66 | `COLOR_ACTIVE`, `COLOR_INACTIVE`, `TWEEN_INFO` | `GuiConfig` / `GuiAnimConfig` |
| 07 | [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua#L24-L25) | 24-25 | `TEXT_MILESTONE`, `FORMAT_DAILY_TIME` | `GuiConfig` hoặc `QuestConfig` |

---

### 🟡 MEDIUM-08 → 11: Hardcode Magic Strings & Tween trong Controllers

| # | File | Dòng | Giá trị | Config nên dùng |
|:--|:-----|:-----|:--------|:----------------|
| 08 | [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L20-L21) | 20-21 | `"TeamHighlight"`, `"HighlightHelper"` | `GuiConfig` hoặc `TagConfig` |
| 09 | [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua#L187) | 187, 203 | Hardcoded `EasingStyle.Quad` | Lấy từ `GuiAnimConfig` |
| 10 | [HotbarController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua#L195) | 195 | Hardcoded Tween Background | Lấy từ `GuiAnimConfig` |
| 11 | [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua#L178) | 178, 242 | `task.delay(3, ...)`, `task.wait(1)` | `GuiAnimConfig` |

---

### 🟡 MEDIUM-12 → 14: Vi Phạm Naming Convention

- **Vị trí:** Nhiều file
- **Mức độ:** `MEDIUM`
- **Hiện trạng & Vấn đề:**
  Quy tắc dự án yêu cầu **100% PascalCase** cho biến, nhưng nhiều hằng số dùng `UPPER_SNAKE_CASE`:
  - `PROFILE_TEMPLATE` ([DataService.lua:20](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L20))
  - `ACCOLADE_TEXT` ([AccoladesController.lua:18](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua#L18))
  - `HIGHLIGHT_NAME` ([HighlightController.lua:20](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L20))
  - `PHASE_DISPLAY`, `GAMEPLAY_PHASES` ([GameStateController.lua:85,94](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua#L85))
  - `REMOTE_EVENTS`, `REMOTE_FUNCTIONS` ([RemoteDefinitions.lua:15,82](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Remotes/RemoteDefinitions.lua#L15))
  - Biến vòng lặp `i`, `j` ([SessionService.lua:133](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua#L133))
- **Đề xuất giải pháp:**
  Cần quyết định: **(A)** Nới lỏng quy tắc cho phép `UPPER_SNAKE_CASE` cho hằng số, hoặc **(B)** Đổi toàn bộ về PascalCase (VD: `ProfileTemplate`, `AccoladeText`). Xem mục **DEBATE** bên dưới.

---

### 🟢 LOW-01: Dead Code — Empty Audio Section

- **Vị trí:** [FreezeService.lua:153-158](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L153-L158)
- **Mức độ:** `LOW`
- **Hiện trạng:** Section `-- PRIVATE: Audio` hoàn toàn trống, không có code hay biến nào. Gây confusion khi đọc.
- **Đề xuất:** Xóa bỏ.

---

### 🟢 LOW-02: TeamService Duplicated Team-Building Loop

- **Vị trí:** [TeamService.lua:28-57](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/TeamService.lua#L28-L57)
- **Mức độ:** `LOW`
- **Hiện trạng:** `BroadcastTeamAssignment()` và `BroadcastTeamAssignmentTo()` duplicate cùng 1 loop xây dựng bảng Teams.
- **Đề xuất:** Extract helper `local function BuildTeamTable()`.

---

### 🟢 LOW-03: IcicleService RemoveTool Duplicated Loop

- **Vị trí:** [IcicleService.lua:96-114](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/IcicleService.lua#L96-L114)
- **Mức độ:** `LOW`
- **Hiện trạng:** Loop xóa Tool lặp 2 lần (Backpack + Character) với code y hệt.
- **Đề xuất:** Extract `local function DestroyToolIn(Parent)`.

---

### 🟢 LOW-04: IcicleScript.client Repeated Spatial Lookups per Frame

- **Vị trí:** [IcicleScript.client.lua:168-172](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua#L168-L172)
- **Mức độ:** `LOW`
- **Hiện trạng:** `Heartbeat` loop gọi `FindFirstAncestorOfClass("Model")` + `GetPlayerFromCharacter()` cho mỗi Part trả về từ `GetPartsInPart()`, nhiều Part cùng Character → tính toán lặp.
- **Đề xuất:** Dùng hash map `CheckedModels = {}` để skip model đã xử lý trong frame hiện tại.

---

## 3. DANH SÁCH CÁC ĐIỂM MÂU THUẪN CẦN PHẢN BIỆN (DEBATE LIST)

### DEBATE-01: Naming Convention — UPPER_SNAKE_CASE cho hằng số?

> **Mâu thuẫn:** Quy tắc dự án nói *"100% PascalCase cho mọi biến"*, nhưng chuẩn Roblox/Luau phổ biến dùng `UPPER_SNAKE_CASE` cho hằng số bất biến. Codebase hiện tại trộn lẫn cả hai.
>
> **Câu hỏi:** Có nên nới lỏng quy tắc PascalCase cho hằng số module-level (`local PROFILE_TEMPLATE = ...`) hay buộc đổi toàn bộ về `ProfileTemplate`?
>
> **Quan điểm của tôi:** Nên cho phép `UPPER_SNAKE_CASE` cho hằng số module-level vì nó cung cấp **tín hiệu ngữ nghĩa** quan trọng: nhìn vào tên biến biết ngay đó là hằng số không được phép sửa. Viết PascalCase cho hằng sẽ lẫn với biến thường, gây nhầm lẫn.

---

### DEBATE-02: Client Lifecycle — 1 pha hay 2 pha?

> **Mâu thuẫn:** Server dùng `Init() → Start()` (2 pha), Client chỉ dùng `Init()` (1 pha). Về nguyên tắc nhất quán, Client phải giống Server.
>
> **Câu hỏi:** Có thực sự cần `Start()` cho Client không? Hiện tại Client chưa gặp bug vì không có Controller nào phụ thuộc chéo trong Init. Nhưng khi dự án mở rộng, rủi ro race condition tăng.
>
> **Quan điểm của tôi:** **Phải thêm `Start()`**. Việc giữ 1 pha là nợ kỹ thuật. Khi thêm tính năng mới (VD: SettingController cần đọc dữ liệu từ PlayerDataController trong Init), sẽ bùng nổ bug. Refactor bây giờ rẻ hơn nhiều so với sau này.

---

### DEBATE-03: QuestService Event Dispatch — Event Bus vs Lazy Require?

> **Mâu thuẫn:** Hiện tại `FreezeService`, `ShopService`, `MatchService` đều phải biết sự tồn tại cụ thể của `QuestService` để `FindFirstChild + require` mỗi lần dispatch. Đây là coupling ngược (service cấp thấp phụ thuộc vào service cấp cao).
>
> **Câu hỏi:** Chuyển sang Event Bus (loose coupling) hay Service Locator (medium coupling)?
>
> **Quan điểm của tôi:** **Event Bus** là giải pháp đúng kiến trúc. Tạo `Shared/Lib/EventBus.lua` với API `EventBus.Fire(EventName, ...)` / `EventBus.On(EventName, Callback)`. `FreezeService` chỉ cần `EventBus.Fire("OnFreeze", Attacker, data)` — hoàn toàn không biết ai lắng nghe. `QuestService` subscribe tại `Init()`. Clean, testable, extensible.

---

### DEBATE-04: OnToolHit — Server Authority Level

> **Mâu thuẫn:** Comment trong `RemoteDefinitions.lua` dòng 28 viết *"Raycast đã xử lý client-side"*, ngụ ý server tin tưởng client đã làm raycast. Nhưng server chỉ validate distance. Đây là **xung đột logic thiết kế**: comment nói 1 đường, code làm 1 nẻo.
>
> **Câu hỏi:** Server có nên tự raycast không? Nếu raycast phía server, liệu có gây desync do network latency?
>
> **Quan điểm của tôi:** **Server PHẢI tự raycast.** Latency tolerance đã được xử lý bằng hệ số 1.5x distance. Thêm 1 lần `workspace:Raycast()` chỉ tốn ~0.01ms, hoàn toàn chấp nhận được. Game Freeze Tag không cần sub-frame precision, LOS check đủ ngăn chặn wallhack mà không ảnh hưởng trải nghiệm.

---

### DEBATE-05: ProcessChestReward Duplicated giữa ShopService và QuestService

> **Mâu thuẫn:** Cả `ShopService.ProcessOneDraw` và `QuestService.ProcessChestReward` đều implement logic: random item → check owned → add/refund. Code gần như giống nhau nhưng nằm ở 2 nơi.
>
> **Câu hỏi:** Gộp thành 1 shared function ở đâu?
>
> **Quan điểm của tôi:** Gộp vào `ShopService.ProcessOneDraw()` (đã có sẵn, đặt thành public API). `QuestService` gọi `ShopService.ProcessOneDraw()` khi thưởng Chest. Loại bỏ `ProcessChestReward` trong QuestService.

---

> [!IMPORTANT]
> **Ưu tiên xử lý ngay:** 5 lỗi CRITICAL (đặc biệt CRITICAL-01, 02, 03) là các lỗ hổng bảo mật có thể bị exploit **ngay lập tức** trên production. Cần hotfix trước khi deploy.
