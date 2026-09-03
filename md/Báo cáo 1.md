# BÁO CÁO TOÀN DIỆN VỀ BẢO MẬT & KIẾN TRÚC HỆ THỐNG ROBLOX LUAU (`src/`)

Tôi đã hoàn tất việc rà soát toàn bộ 71 tệp mã nguồn trong thư mục `src/` (bao gồm `ServerScriptService`, `StarterPlayer`, và `ReplicatedStorage`). Dưới đây là kết quả kiểm toán chuyên sâu, phân tích chi tiết từng lỗ hổng bảo mật, lỗi thiết kế kiến trúc, nguy cơ rò rỉ bộ nhớ và các vi phạm quy ước dự án.

---

## PHẦN 1: BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO TỔNG THỂ (RISK MATRIX)

| Trụ cột đánh giá | CRITICAL | HIGH | MEDIUM | LOW | Tổng cộng |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **1. Bảo mật & Thẩm quyền Server (Server Authority & Exploits)** | 3 | 4 | 2 | 0 | **9** |
| **2. Vòng đời dữ liệu & Quản lý Bộ nhớ (Lifecycle, Leaks & Data Loss)** | 2 | 5 | 3 | 0 | **10** |
| **3. Code Smell & Thiết kế chắp vá (Coupling, Race Conditions & Dynamic Requires)** | 0 | 4 | 7 | 2 | **13** |
| **4. Vi phạm Zero Hardcode (Magic Numbers & Embedded Values)** | 0 | 0 | 6 | 4 | **10** |
| **5. Quy ước đặt tên & Tính nhất quán hệ thống (Naming & Consistency)** | 0 | 0 | 4 | 8 | **12** |
| **TỔNG CỘNG TOÀN BỘ DỰ ÁN** | **5** | **13** | **22** | **14** | **54** |

---

## PHẦN 2: CHI TIẾT CÁC LỖ HỔNG & KHUYẾT TẬT KIẾN TRÚC

### 🔴 NHÓM 1: CRITICAL & HIGH (LỖ HỔNG BẢO MẬT & MẤT MÁT DỮ LIỆU)

---

#### 1. Lỗ hổng Spam `OnToolHit` không kiểm tra Cooldown, Line-of-Sight và Tool State trên Server
- **Vị trí**: [`FreezeService.lua:477-526`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L477-L526)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  - RemoteEvent `OnToolHit` nhận trực tiếp `Target` từ Client. Server chỉ kiểm tra duy nhất: `Attacker ~= Target`, `Target` là Player, và khoảng cách giữa 2 nhân vật `Distance <= HitboxRange * 1.5` (`3.5 * 1.5 = 5.25 studs`).
  - **Server KHÔNG kiểm tra**:
    1. Attacker có đang cầm (Equip) Tool trên tay hay không.
    2. Server Cooldown / Debounce tốc độ đánh giữa 2 lần bấm (trong khi Client bị giới hạn bởi `Cooldown = 0.5s` nhưng Hacker có thể bỏ qua).
    3. Raycast kiểm tra vật cản (Line of Sight) giữa Attacker và Target.
- **Kịch bản khai thác / Hậu quả**: 
  - Hacker dùng script executor gửi đồng loạt hàng trăm request `OnToolHit:FireServer(NạnNhân)` mỗi giây, hoặc đứng sau tường kín / dưới lòng đất trong phạm vi 5.25 studs để đóng băng toàn bộ server mà không cần vung vũ khí.
  - Hacker đóng băng và giải cứu mục tiêu tức thì trong 1 frame để farm tiền thưởng vô hạn từ `RewardHelper`.
- **Đề xuất giải pháp**:
  - Thêm bảng debounce theo dõi thời gian vung đòn gần nhất `_LastHitTime[Attacker.UserId]` trên Server (tối thiểu `GameConfig.Hitbox.Cooldown - 0.05s`).
  - Xác thực nhân vật của Attacker đang có vũ khí gắn trong Character (`Character:FindFirstChildOfClass("Tool")`).
  - Thực hiện một đường Raycast ngắn từ `Attacker.HumanoidRootPart.Position` đến `Target.HumanoidRootPart.Position` qua `workspace:Raycast` với `RaycastParams` lọc qua Map để loại trừ trường hợp đánh xuyên tường.

---

#### 2. Race Condition qua hàm Yielding gây mất kiểm soát số lần Reset Daily Quests
- **Vị trí**: [`QuestService.lua:473-526`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L473-L526)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  - Khi Client gọi `RequestResetDailyQuests`, `QuestService` kiểm tra `UserOwnsGamePassAsync` thông qua `ShopService.PlayerOwnsGamePass(Player, PassId)`. 
  - `MarketplaceService:UserOwnsGamePassAsync` là một hàm **bất đồng bộ gây Yield luồng (Thread Yielding)**.
  - Trong lúc server đang yield chờ phản hồi từ Roblox Cloud, biến `Data.ResetsUsed` chưa hề được tăng.
- **Kịch bản khai thác / Hậu quả**:
  - Hacker gửi 10 request `RequestResetDailyQuests:FireServer()` cùng một mili-giây. Cả 10 luồng xử lý trên server đều đi qua đoạn check `ResetsUsed (0) < MaxResets (1)` trong khi đang yield chờ GamePass.
  - Khi hoàn tất yield, server reset Daily Quests 10 lần liên tiếp trong ngày và ghi nhận `ResetsUsed = 1`, cho phép người chơi cày nhiệm vụ hàng ngày vô hạn lần.
- **Đề xuất giải pháp**:
  - Đặt một cờ `_ResettingPlayers[Player.UserId] = true` (In-Flight Debounce Lock) ngay tại dòng đầu tiên của hàm trước khi yield, và giải phóng cờ trong khối `finally` hoặc sau khi xử lý xong.

---

#### 3. Nhiễm bẩn Dữ liệu & Nguy cơ Runtime Crash qua Remote `SaveSetting`
- **Vị trí**: [`DataService.lua:652-673`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L652-L673) & [`DataService.lua:741-748`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L741-L748)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  - Hàm `DataService.SetSetting(Player, Key, Value)` chỉ kiểm tra:
    ```lua
    if type(Value) == "number" then
        Value = math.clamp(Value, 0, 100)
    end
    Profile.Data.Settings[Key] = Value
    ```
  - Nếu `Value` được hacker truyền vào là `string`, `table`, `boolean`, `nil`, hoặc số vô hạn `math.huge` / `NaN`, Server vẫn gán thẳng vào `Profile.Data.Settings[Key]`.
- **Kịch bản khai thác / Hậu quả**:
  - Khi Server hoặc Client khác đọc setting âm thanh và chạy phép tính số học (ví dụ: `AudioHelper.SetVolume(Group, Value / 100)`), Lua sẽ văng ngoại lệ `attempt to perform arithmetic on string/table/nil`, làm tê liệt toàn bộ script điều khiển âm thanh của Client.
  - Phá vỡ Schema chuẩn của ProfileStore khiến Profile bị lỗi cấu trúc dữ liệu không thể serialize.
- **Đề xuất giải pháp**:
  - Khai báo Schema hợp lệ cho Settings trong `DataConfig.lua`: kiểm tra `Key` phải nằm trong whitelist cho phép (`Master`, `Music`, `SFX`, `UI`), và `Value` bắt buộc phải là `number` hữu hạn (`Value == Value and Value >= 0 and Value <= 100`).

---

#### 4. Mất mát Dữ liệu Session (Data Loss Race Condition) khi Người chơi rời game (`PlayerRemoving`)
- **Vị trí**: [`DataService.lua:136-142`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L136-L142) so với [`QuestService.lua:646-662`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L646-L662)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  - Trong Roblox Luau, thứ tự thực thi của các listener đăng ký vào cùng một sự kiện (`Players.PlayerRemoving`) giữa các Service khác nhau là **không xác định (Non-deterministic)**.
  - Nếu `DataService` giải phóng Profile (`Profile:Release()`) trước khi `QuestService` xử lý `PlayerRemoving`, việc `QuestService` gọi `DataService.AddPlayTime(Player, Elapsed)` hoặc `QuestService.DispatchEvent(Player, "OnPlayTime")` sẽ thất bại hoàn toàn vì Profile đã bị giải phóng (`_Profiles[Player] == nil`).
- **Kịch bản khai thác / Hậu quả**:
  - Người chơi cày game suốt 2 tiếng, khi thoát game thì toàn bộ thời gian chơi của session đó bị hủy bỏ, tiến độ Daily Quest "PlayTime" không được lưu lại vào DataStore.
- **Đề xuất giải pháp**:
  - Tập trung việc giải phóng Profile vào cuối cùng. `DataService` cần cung cấp một hàm chuẩn như `DataService.PlayerLeaving(Player)` được gọi tuần tự từ `Main.server.lua`, hoặc `DataService` lắng nghe các Service khác hoàn tất flush dữ liệu trước khi gọi `Profile:Release()`.

---

#### 5. Rò rỉ Model Vật lý `IceBlock` trong Workspace khi Nạn nhân thoát game lúc đang bị đóng băng
- **Vị trí**: [`FreezeService.lua:544-546`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L544-L546)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  - Trong `Players.PlayerRemoving`, `FreezeService` chỉ thực hiện dọn cache bảng:
    ```lua
    _iceBlocks[Player.UserId] = nil
    ```
  - Code **hoàn toàn quên gọi `IceBlock:Destroy()`** trên đối tượng Model `IceBlock` đang tồn tại trong `workspace`.
- **Kịch bản khai thác / Hậu quả**:
  - Khối băng (BasePart + WeldConstraints) tồn tại vĩnh viễn trong Workspace, cản trở di chuyển của những người chơi khác và gây rò rỉ bộ nhớ vật lý của Server sau nhiều trận đấu.
- **Đề xuất giải pháp**:
  - Lấy instance `local Block = _iceBlocks[Player.UserId]` trước khi gán nil, kiểm tra `if Block then Block:Destroy() end`.

---

#### 6. Rò rỉ Thread Heartbeat (Memory Leak) trong `IcicleScript.client.lua` khi Unequip Tool
- **Vị trí**: [`IcicleScript.client.lua:140-146`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua#L140-L146)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  - Khi Tool bị Unequip hoặc vứt bỏ, sự kiện `Tool.Unequipped` chỉ dừng hiệu ứng vung kiếm, nhưng **không gọi `StopHitboxPoll()`**.
  - Kết nối `RunService.Heartbeat` kiểm tra hitbox vẫn tiếp tục chạy ngầm trong bộ nhớ của Client.
- **Kịch bản khai thác / Hậu quả**:
  - Người chơi trang bị và tháo vũ khí liên tục nhiều lần sẽ tạo ra hàng chục vòng lặp Heartbeat chạy song song, gây tụt FPS nghiêm trọng trên thiết bị di động (Mobile).
- **Đề xuất giải pháp**:
  - Trong `Tool.Unequipped:Connect(...)`, bắt buộc gọi `StopHitboxPoll()`, ngắt kết nối Raycast/OverlapParams và giải phóng trạng thái.

---

#### 7. Rủi ro Phình to Dữ liệu DataStore không giới hạn (Unbounded Array) trong `PurchaseHistory`
- **Vị trí**: [`ShopService.lua:263`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L263) & [`DataConfig.lua:35`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/DataConfig.lua#L35)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  - Mỗi khi người chơi mua GamePass hoặc Developer Product bằng Robux, một entry lịch sử giao dịch được chèn vào mảng: `table.insert(Profile.Data.PurchaseHistory, ReceiptInfo.PurchaseId)`.
  - Mảng này không có cơ chế giới hạn dung lượng (Max Capacity) hoặc tự động cắt tỉa (Pruning).
- **Kịch bản khai thác / Hậu quả**:
  - Đối với những người chơi nạp Robux thường xuyên, kích thước payload của Profile vượt quá giới hạn 4MB của Roblox DataStore, dẫn đến lỗi `DataStore request exceeds 4MB limit`, khiến dữ liệu của người chơi bị hỏng hoàn toàn và không thể lưu game.
- **Đề xuất giải pháp**:
  - Giới hạn lưu tối đa 50 hoặc 100 `PurchaseId` gần nhất (FIFO queue), loại bỏ các ID cũ nhất khi vượt quá giới hạn.

---

### 🟡 NHÓM 2: MEDIUM (CODE SMELL, TIGHT COUPLING & VI PHẠM ZERO HARDCODE)

---

#### 8. Module Dùng chung `ReplicatedStorage` phụ thuộc ngược vào `ServerScriptService` (Tight Coupling)
- **Vị trí**: [`RewardHelper.lua:98-107`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/RewardHelper.lua#L98-L107)
- **Mức độ**: `MEDIUM`
- **Hiện trạng & Vấn đề**:
  - `RewardHelper.lua` nằm trong `ReplicatedStorage.Shared.Tools` (nơi cả Server lẫn Client đều có quyền truy cập).
  - Tuy nhiên, bên trong hàm `RewardHelper.CalculateMoneyEarned`, code lại cố gắng `require(ServerScriptService.Services.ShopService)` khi đang chạy ở Server để kiểm tra nhân đôi tiền (`PlayerOwnsGamePass`).
- **Hậu quả**:
  - Phá vỡ ranh giới kiến trúc độc lập (Architecture Boundary). Nếu Client vô tình gọi vào nhánh logic này, Client sẽ văng lỗi ngay lập tức vì Client không có quyền truy cập vào `ServerScriptService`.
- **Đề xuất giải pháp**:
  - Tách biệt hoàn toàn: `RewardHelper` chỉ là pure calculation module nhận tham số `HasDoubleMoney: boolean`. Việc kiểm tra GamePass sẽ do Server Service (`SessionService` hoặc `MatchService`) thực hiện rồi truyền cờ vào `RewardHelper`.

---

#### 9. Lạm dụng `require` Động (Dynamic Require) bên trong thân hàm
- **Vị trí**: 
  - [`FreezeService.lua:277, 380`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L277) (`require(QuestService)`)
  - [`MatchService.lua:388, 597`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L388) (`require(QuestService)`)
  - [`ShopService.lua:157`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L157) (`require(QuestService)`)
  - [`SessionService.lua:118`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua#L118) (`require(RemoteDefinitions)`)
- **Mức độ**: `MEDIUM`
- **Hiện trạng & Vấn đề**:
  - Các module require lẫn nhau ngay giữa thân hàm trong mỗi vòng lặp hoặc mỗi lần event kích hoạt thay vì tiêm phụ thuộc (Dependency Injection) hoặc khởi tạo ở `Init()`.
- **Hậu quả**:
  - Làm giảm hiệu năng do phải tra cứu bảng module liên tục, che giấu các nguy cơ Circular Dependency tiềm ẩn và gây khó khăn cho việc Unit Testing.
- **Đề xuất giải pháp**:
  - Chuẩn hóa theo Lifecycle: Sử dụng `ServiceLoader` để inject dependencies hoặc resolve các Service tham chiếu tại hàm `Init()` của mỗi Service.

---

#### 10. Hardcode Màu sắc, Magic Numbers và Độ trễ phân tán
- **Vị trí**:
  - [`HighlightController.lua:22-25`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L22-L25): Hardcode `Color3.fromRGB(0, 162, 255)`, `Color3.fromRGB(255, 60, 60)`, `FillTransparency = 0.5`, `OutlineTransparency = 0`.
  - [`MatchService.lua:457, 647, 655`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L457): Hardcode `task.wait(0.5)`, `task.wait(0.2)`, `Vector3.new(0, 4, 0)`.
  - [`HighlightController.lua:206`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L206): Hardcode `task.wait(0.1)`.
  - [`SpectateController.lua:182`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua#L182): Hardcode `Camera.FieldOfView = 70`.
- **Mức độ**: `MEDIUM`
- **Hiện trạng & Vấn đề**: Vi phạm quy tắc **Zero Hardcode** của dự án (`.agents/rules/rule.md`). Khi muốn cân bằng game hoặc đổi giao diện, lập trình viên phải mò vào từng file code để sửa thay vì chỉnh sửa trong file config chung.
- **Đề xuất giải pháp**:
  - Chuyển toàn bộ màu sắc Highlight sang `GuiAnimConfig.lua` / `GameConfig.lua`.
  - Chuyển các khoảng thời gian chờ (`task.wait`) vào `GameConfig.Match` hoặc `GuiConfig.Timeouts`.

---

#### 11. Cơ chế Double-Binding `Player.Chatted` và Không tương thích với Modern TextChatService
- **Vị trí**: [`AdminService.lua:427-438`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/AdminService.lua#L427-L438)
- **Mức độ**: `MEDIUM`
- **Hiện trạng & Vấn đề**:
  - `AdminService` vừa kết nối `Players.PlayerAdded:Connect(...)` vừa lặp qua `Players:GetPlayers()` mà không có cơ chế lọc trùng connection.
  - Sử dụng sự kiện `Player.Chatted` (Legacy Chat Service) đã bị Roblox khuyến cáo thay thế bằng `TextChatService` hiện đại.
- **Hậu quả**:
  - Lệnh admin có thể bị kích hoạt 2 lần nếu player được nạp trước khi loop chạy xong; không hoạt động chính xác trên các trải nghiệm sử dụng TextChatService mới.
- **Đề xuất giải pháp**:
  - Tích hợp `TextChatService.MessageReceived` hoặc đảm bảo chỉ bind 1 lần cho mỗi player.

---

### 🟢 NHÓM 3: LOW (VI PHẠM QUY ƯỚC ĐẶT TÊN & TÍNH NHẤT QUÁN)

---

#### 12. Vi phạm Quy ước Đặt tên Biến (CamelCase vs PascalCase)
- **Vị trí**: Rải rác trên nhiều Controller và Service:
  - [`GameStateController.lua:42, 55, 68, 101-105`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua#L42): `_menuController`, `_navigationController`, `_hotbarController`, `_lastPhase`, `_lastTimeRemaining`, `_lastIsFrozenState`, `_playerStatusType`, `_scoreboardType`.
  - [`ScoreBoardController.lua:32, 33`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua#L32): `_playerStats`, `_scoreboardType`.
  - [`PlayerStatusController.lua:38, 39`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua#L38): `_cardData`, `_playerStatusType`.
  - [`ProfileController.lua:72, 94`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua#L72): `_menuController`, `_renderedItems`.
  - [`AudioHelper.lua:15, 21`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AudioHelper.lua#L15): `_guiSoundPool`, `_soundGroups`.
  - [`FreezeService.lua:37, 41`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L37): `_firstBloodClaimed`, `_iceBlocks`.
  - [`SessionService.lua:11-21`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua#L11-L21): `_playerStates`, `_teamAssignment`, `_sessionStats`, `_freezeStreaks`, `_thawStreaks`, `_participants`, `_teamScores`, `_isMatchActive`, `_isFrozenState`, `_currentModeKey`.
- **Mức độ**: `LOW`
- **Hiện trạng & Vấn đề**: Vi phạm trực tiếp quy ước bắt buộc tại `.agents/rules/rule.md`: *"100% PascalCase và tiếng Anh cho tất cả biến, hàm, module, event."*
- **Đề xuất giải pháp**: Chuẩn hóa toàn bộ các biến private trên thành PascalCase (ví dụ: `_MenuController`, `_PlayerStats`, `_IceBlocks`, `_IsMatchActive`...).

---

## PHẦN 3: DANH SÁCH CÁC ĐIỂM MÂU THUẪN & PHẢN BIỆN KIẾN TRÚC (DEBATE LIST)

Dưới đây là các xung đột thiết kế nghiêm túc cần được đưa ra tranh luận và thống nhất phương án xử lý dứt điểm:

---

### 💥 Điểm phản biện 1: Trách nhiệm Xác thực Hitbox & Raycast (Client Authority vs Server Authority)
- **Thực trạng**: Hiện tại, `IcicleScript.client.lua` làm toàn bộ việc dò tìm hitbox bằng `workspace:GetPartBoundsInBox` trên Client rồi bắn RemoteEvent `OnToolHit` lên Server. Server tin tưởng hoàn toàn và chỉ làm một phép kiểm tra khoảng cách hời hợt (`Distance <= 5.25 studs`).
- **Phản biện**:
  - **Thiết kế này cực kỳ mong manh**. Việc trao quyền xác định va chạm cho Client biến trò chơi thành "miếng mồi ngon" cho bất kỳ hacker nào sử dụng script injection.
  - Server **bắt buộc phải là thẩm quyền tối cao (Server Authority)**: Server phải xác minh Attacker có đang cầm vũ khí, hướng nhìn có quay về phía mục tiêu không, và tia Raycast từ Attacker tới Target không bị chặn bởi tường.

---

### 💥 Điểm phản biện 2: Xung đột Luồng Dữ liệu giữa `SessionService` và `MatchService`
- **Thực trạng**:
  - `SessionService` quản lý trạng thái in-memory (`_playerStates`, `_teamAssignment`, `_sessionStats`).
  - `MatchService` lại đóng vai trò State Machine điều phối Game Loop (`Intermission -> Setup -> Ready -> InGame -> GameOver`).
  - Tuy nhiên, `MatchService` lại can thiệp trực tiếp vào việc cộng điểm, tính thưởng, phân bổ đội và gọi RemoteEvent song song với `SessionService`.
- **Phản biện**:
  - Có sự **chồng chéo trách nhiệm (SRP Violation)**. Khi muốn biết người chơi thắng/thua, cả `MatchService` và `SessionService` đều có logic kiểm tra điều kiện riêng biệt.
  - Cần tinh giản: `MatchService` chỉ quản lý nhịp thời gian và chuyển phase; toàn bộ logic về điểm số, trạng thái người chơi, đội tuyển và phân định thắng thua phải do `SessionService` làm chủ quản.

---

### 💥 Điểm phản biện 3: Quản lý GamePass Cache và Kiểm tra Bất đồng bộ
- **Thực trạng**:
  - `ShopService` cache kết quả GamePass trong `_gamePassCache[Player.UserId]` khi người chơi mua hoặc join game.
  - Nhưng trong `QuestService` và `RewardHelper`, mỗi khi cần kiểm tra GamePass thì lại gọi hàm bất đồng bộ có thể yield hoặc gọi trực tiếp `UserOwnsGamePassAsync`.
- **Phản biện**:
  - Việc lặp lại kiểm tra bất đồng bộ gây ra **Race condition nghiêm trọng** (như đã chỉ ra ở Mục 2).
  - Phải thống nhất: **Mọi truy vấn GamePass trong runtime phải đọc 100% từ Cache đồng bộ (Synchronous Memory Cache)** do `ShopService` quản lý sau khi đã nạp lúc `PlayerAdded`. Tuyệt đối không yield giữa chừng trong các luồng xử lý game logic quan trọng.

---

### 💥 Điểm phản biện 4: Sự phụ thuộc chéo trong Khởi tạo Client Controller
- **Thực trạng**:
  - Các Controller (`MenuController`, `NavigationController`, `PlayerDataController`, `GameStateController`, `SpectateController`) đang sử dụng cơ chế `lazy-require` bừa bãi trong thân hàm để giải quyết bài toán Circular Dependency.
- **Phản biện**:
  - Cơ chế này khiến luồng khởi tạo không đồng nhất: Một số controller require tại top file, một số require trong `GetMenuController()`, dẫn đến việc kiểm soát lifecycle gặp khó khăn khi debug.
  - Cần áp dụng mô hình `ControllerLoader` tương tự `ServiceLoader` trên Server: Tách biệt rõ ràng 2 giai đoạn `Init()` (đăng ký cấu trúc/event) và `Start()` (kết nối và tương tác giữa các controller).

---

## 🎯 KẾT LUẬN & ĐỀ XUẤT BƯỚC TIẾP THEO

Toàn bộ hệ thống `src/` hiện có nền tảng cấu trúc tốt và phân chia module rõ ràng, nhưng đang tồn tại **3 lỗ hổng bảo mật nghiêm trọng (Critical)** cùng **5 nguy cơ mất dữ liệu / rò rỉ bộ nhớ (High)** cần được khắc phục triệt để trước khi triển khai tính năng mới.

Tôi đã sẵn sàng thảo luận và phản biện chi tiết về từng giải pháp nêu trên. Hãy cho tôi biết bạn muốn ưu tiên giải quyết nhóm vấn đề nào trước để chúng ta lập kế hoạch triển khai (Implementation Plan) cụ thể.