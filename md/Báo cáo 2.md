# 📊 BÁO CÁO TỔNG QUAN RÀ SOÁT TOÀN BỘ SRC

> **Phạm vi**: Toàn bộ `src/` — 11 Services, 24 Controllers, 12 Tools/Helpers, 20 Configs, 1 RemoteDefinitions  
> **Phương pháp**: Đọc toàn bộ source code, truy vết luồng dữ liệu Client→Server và Server→Client  
> **Ngày rà soát**: 2026-09-01

---

## 1. BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO

| Mức độ | Số lượng | Mô tả tóm tắt |
| :--- | :---: | :--- |
| 🔴 **CRITICAL** | **3** | Race condition BuyChest gây double-spend; `OnToolHit` không chặn Victim đang `Frozen` bị hit liên tiếp; `SetAfkState` không giới hạn tần suất gây AFK-spam |
| 🟠 **HIGH** | **5** | Race condition `ClaimQuest` Repeatable; dirty-require vòng tròn QuestService/FreezeService; `task.wait(2)` mù quáng khi player mới join; `MatchService` trực tiếp `require` RemoteDefinitions lại bên trong `PlayerRemoving`; Highlight instance leak khi Character remove |
| 🟡 **MEDIUM** | **6** | Hardcode `1.5` trong hitbox tolerance; hardcode `0.5` buffer và magic delays trong MatchService; `WeightedRandom` duplicate code giữa ShopService và QuestService; `DataConfig.ProfileLoadTimeout` dùng `task.wait(0.05)` poll loop; `STREAM_WAIT_TIMEOUT = 5` hardcode trong SpectateController; Max/MinQty 1-5 hardcode trong ShopService |
| 🟢 **LOW** | **4** | Comment tiếng Việt lẫn lộn trong code logic; `OwnedCosmetics`/`DailyQuestData`/`MilestoneQuestData` legacy field trong profile template không được dọn; `camelCase` lẫn `lowercase` trong một số biến cục bộ; `UpperContaier` typo tên trong GameLoadingController |

---

## 2. CHI TIẾT CÁC ĐIỂM YẾU & NGUY CƠ BẢO MẬT

---

### 🔴 CRITICAL-1 — Race Condition `BuyChest` gây Double-Spend

- **Vị trí**: [`ShopService.lua:120-125`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L120-L125)
- **Mức độ**: `CRITICAL`

**Hiện trạng & Vấn đề**:

```lua
-- Dòng 120: Kiểm tra tiền
if Data.Money < TotalPrice then
    return { Success = false, Reason = "NOT_ENOUGH_MONEY" }
end

-- Dòng 125: Trừ tiền
DataService.AddMoney(Player, -TotalPrice)
```

`BuyChest` là `RemoteFunction.OnServerInvoke`. Luau xử lý RemoteFunction **serial per connection** — nhưng nếu client gọi nhiều lần liên tiếp nhanh bằng coroutine hoặc exploit script, hoặc nếu có nhiều coroutine server-side khác yield trước đó, khoảng trống giữa dòng 120 (check) và 125 (deduct) đủ để một lần gọi thứ hai chui vào. Cụ thể hơn: bởi vì `DataService.AddMoney` không phải atomic lock — nó chỉ đọc `Profile.Data.Money` rồi set lại — nếu hai coroutine cùng đọc `Money = 1000`, cùng thấy `>= TotalPrice`, rồi cả hai cùng trừ, kết quả cuối là âm hoặc item bị trao hai lần.

**Kịch bản khai thác**: Hacker gửi 5 request `BuyChest` gần như đồng thời. Cả 5 đọc được `Money = 1000`, cả 5 pass check, cả 5 trừ tiền → số tiền xuống âm hoặc nhận 5× item.

**Đề xuất**: Dùng **mutex flag per player** (ví dụ `_buyLocks = {}`) trước khi check-deduct:

```lua
if _buyLocks[Player] then return { Success = false, Reason = "BUSY" } end
_buyLocks[Player] = true
-- ... check + deduct + open chest ...
_buyLocks[Player] = nil
```

Hoặc dùng `pcall + ProfileService:UpdateAsync` thay vì mutate trực tiếp `Profile.Data.Money` để đảm bảo atomic write.

---

### 🔴 CRITICAL-2 — `OnToolHit` không block re-freeze Victim đang `Frozen`

- **Vị trí**: [`FreezeService.lua:510-512`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L510-L512)
- **Mức độ**: `CRITICAL`

**Hiện trạng & Vấn đề**:

```lua
if TargetTeam ~= AttackerTeam then
    -- Kẻ địch → Freeze (chỉ khi đang Normal)
    if SessionService.GetState(Target) == "Normal" then
        FreezeService.FreezePlayer(Attacker, Target)
    end
```

Đây là check **đúng** cho trường hợp Freeze. Tuy nhiên, trong chế độ FFA (dòng 522):

```lua
if SessionService.GetStats(Target) and SessionService.GetState(Target) == "Normal" then
    FreezeService.FreezePlayer(Attacker, Target)
end
```

Vẫn đúng. **Vấn đề thực sự** nằm ở `FreezePlayer` không có mutex — nếu 2 attacker cùng hit 1 victim hầu như đồng thời (cả 2 đều đọc `State = "Normal"` trước khi cái nào set `"Frozen"`), cả 2 đều gọi `FreezePlayer`, dẫn đến `SpawnIceBlock` gọi 2 lần → 2 IceBlock trên cùng 1 victim, `_iceBlocks[Victim.UserId]` bị ghi đè bởi block thứ 2, block thứ nhất không được track để xóa → **IceBlock ghost tồn tại vĩnh viễn trong Workspace** cho đến khi game dọn cuối trận.

Ngoài ra: **Không có Raycast line-of-sight check**. Server chỉ kiểm tra khoảng cách (Magnitude), không kiểm tra có vật cản giữa Attacker và Victim không. Hacker có thể freeze xuyên tường.

**Kịch bản khai thác**: Tường dày, attacker đứng một bên, victim bên kia trong `HitboxRange * 1.5 = 30 studs` → hit hợp lệ theo server.

**Đề xuất**:
1. Thêm mutex flag `_freezeLocks = {}` trong FreezeService giống như CRITICAL-1.
2. Thêm Raycast validation từ Attacker HRP đến Victim HRP trước khi freeze (tùy thiết kế — có thể chấp nhận trade-off performance vs security).

---

### 🔴 CRITICAL-3 — `SetAfkState` không rate-limit, dễ bị spam flood

- **Vị trí**: [`MatchService.lua:757-768`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L757-L768)
- **Mức độ**: `CRITICAL`

**Hiện trạng & Vấn đề**:

```lua
SetAfkStateEvent.OnServerEvent:Connect(function(Player, Payload)
    if not Player then return end
    local IsAfk = false
    if type(Payload) == "table" then
        IsAfk = (Payload.IsAfk == true)
    ...
    PlayerStateHelper.SetAfk(Player, IsAfk)
    print(...)
end)
```

Không có bất kỳ cooldown nào. Client có thể fire `SetAfkState` liên tục 1000 lần/giây. Hệ quả:
1. **CPU Flood**: Mỗi lần fire đều gọi `print()` và `PlayerStateHelper.SetAfk()` (set Attribute).
2. **Griefing**: Hacker toggle AFK liên tục để giả vờ active (không bị loại khỏi trận do hệ thống check `IsAfk`) hoặc cứ spam để kéo lag server thread.

**Đề xuất**: Thêm cooldown giống `OnToolSwing`:

```lua
local _afkCooldowns = {}
SetAfkStateEvent.OnServerEvent:Connect(function(Player, Payload)
    local Now = os.clock()
    if (Now - (_afkCooldowns[Player] or 0)) < 1.0 then return end
    _afkCooldowns[Player] = Now
    ...
end)
```

---

### 🟠 HIGH-1 — Race Condition `ClaimQuest` cho Repeatable Quest

- **Vị trí**: [`QuestService.lua:537-628`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L537-L628)
- **Mức độ**: `HIGH`

**Hiện trạng & Vấn đề**: `ClaimQuestFn.OnServerInvoke` không có mutex. Với Repeatable Milestone quest, flow là:

1. Đọc `CurrentProgress >= Requirement` → `IsCompleted = true`
2. `NewProgress = CurrentProgress - Requirement`
3. Ghi lại progress

Nếu client spam 2 claim request đồng thời cả 2 đọc `Progress = 10`, cả 2 thấy `>= 5 (Requirement)`, cả 2 xử lý reward → **phần thưởng cấp 2 lần**. Đây là lỗ hổng nhân bản item/tiền tương tự CRITICAL-1.

**Đề xuất**: Thêm `_claimLocks = { [Player] = { [QuestId] = true } }` mutex per player per quest.

---

### 🟠 HIGH-2 — Dirty `require` vòng tròn: FreezeService ↔ QuestService ↔ ShopService

- **Vị trí**: [`FreezeService.lua:277-289`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L277-L289), [`ShopService.lua:157-167`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L157-L167), [`MatchService.lua:388-394`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L388-L394)
- **Mức độ**: `HIGH`

**Hiện trạng & Vấn đề**: Cả `FreezeService`, `ShopService`, và `MatchService` đều dùng pattern này:

```lua
local QuestModule = script.Parent:FindFirstChild("QuestService")
if QuestModule then
    local QuestService = require(QuestModule)
    if QuestService and QuestService.DispatchEvent then
        QuestService.DispatchEvent(...)
    end
end
```

Đây là **lazy require tại runtime**, lặp lại 3 lần ở 3 file khác nhau. Tương tự, `QuestService` lazy-require `ShopService`. Đây là **coupling ngầm không rõ ràng** — không thể nhìn vào đầu file và biết dependency. Nếu một service load thất bại, các guard `if QuestModule then` sẽ silently skip mà không có error rõ ràng, khiến quest không được cập nhật mà không ai biết.

**Kịch bản hậu quả**: QuestService fail init (ví dụ lỗi config) → toàn bộ event dispatch bị bỏ qua silently → quest không tiến trình, người dùng báo bug nhưng không có log lỗi rõ ràng.

**Đề xuất**: Inject QuestService vào FreezeService/ShopService/MatchService thông qua một `EventBus` hoặc signal pattern rõ ràng hơn. Hoặc đơn giản nhất: `require` trực tiếp ở đầu file như các dependency khác — Luau handle circular require bằng cách return partial module, nên cần thiết kế DispatchEvent không gọi ngược lại FreezeService.

---

### 🟠 HIGH-3 — `task.wait(2)` mù quáng khi Player join giữa trận

- **Vị trí**: [`MatchService.lua:776`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L776)
- **Mức độ**: `HIGH`

**Hiện trạng & Vấn đề**:

```lua
Players.PlayerAdded:Connect(function(NewPlayer)
    ...
    task.wait(2)  -- <-- magic number, không lý giải tại sao 2 giây
    if _currentPhase == "InGame" and SessionService.IsMatchActive() then
        ...
    end
end)
```

Delay 2 giây để "chờ player load xong" là giả định cứng không có cơ sở. Trên kết nối chậm (mobile, SEA region), 2 giây có thể chưa đủ. Trên server nhanh, 2 giây là lãng phí. Không có gì đảm bảo `DataService` đã load profile của player xong sau 2 giây.

Hậu quả: Player mới join nhận được `UpdateSpectateList` nhưng `GetPlayerData` chưa sẵn sàng → client hiển thị thiếu data hoặc race condition với `PlayerDataController`.

**Đề xuất**: Thay bằng `DataService.WaitForProfile(NewPlayer)` để chờ profile thực sự sẵn sàng:

```lua
task.spawn(function()
    DataService.WaitForProfile(NewPlayer)  -- block cho đến khi data ready
    if _currentPhase == "InGame" and SessionService.IsMatchActive() then
        ...
    end
end)
```

---

### 🟠 HIGH-4 — `SessionService.PlayerRemoving` re-require RemoteDefinitions mỗi lần

- **Vị trí**: [`SessionService.lua:419-421`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua#L419-L421)
- **Mức độ**: `HIGH`

**Hiện trạng & Vấn đề**:

```lua
Players.PlayerRemoving:Connect(function(Player)
    if _isMatchActive then
        ...
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RemoteDefinitions = require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)  -- re-require mỗi lần!
        local UpdatePlayerStateEvent = RemoteDefinitions.GetEvent("UpdatePlayerState")
```

`require` ở Luau có cache, nên re-require không re-execute module. **Nhưng** đây là code smell rõ ràng: gọi `require` bên trong callback event mỗi khi player rời game là không cần thiết. Đồng thời, pattern này **phá vỡ nguyên tắc thiết kế** của các service khác — tất cả service đều lấy Event reference trong `Init()`, SessionService lại giấu dependency bên trong callback. Điều này làm khó debug và inconsistent với codebase.

**Đề xuất**: Kéo `UpdatePlayerStateEvent` lên làm upvalue module-level trong SessionService, gán trong `Init()` giống FreezeService.

---

### 🟠 HIGH-5 — Highlight instance leak khi Character respawn/remove

- **Vị trí**: [`HighlightController.lua:203-215`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L203-L215)
- **Mức độ**: `HIGH`

**Hiện trạng & Vấn đề**:

```lua
Player.CharacterAdded:Connect(function(Character)
    Character:WaitForChild("HumanoidRootPart")
    task.wait(0.1)  -- magic delay
    local IsInMatch = ...
    if not IsInMatch then
        RemoveHighlight(Character)
    else
        RefreshAll()
    end
end)
```

Khi player respawn, Character cũ bị destroy — Highlight instance bên trong Character cũ tự bị Destroy theo (Roblox garbage collect). Đây ổn. **Nhưng** `task.wait(0.1)` là một magic delay chặn coroutine. Vấn đề lớn hơn: **`Players.PlayerRemoving` không được lắng nghe** trong `HighlightController` để disconnect `CharacterAdded` connection. Mỗi lần player join rồi rời, connection tồn tại nhưng player object bị garbage collect → technically Roblox sẽ clean up nhưng trong một session dài với nhiều player join/leave, đây là resource không được quản lý tường minh.

Ngoài ra `Workspace.ChildAdded` và `Workspace.ChildRemoved` được bind **toàn bộ workspace** chỉ để theo dõi IceBlock — mỗi khi bất kỳ object nào được thêm/xóa khỏi workspace đều trigger `RefreshAll()` — hàm này iterate toàn bộ `Players:GetPlayers()` và gọi `ApplyHighlightForPlayer` cho từng người. Với nhiều object được thêm vào workspace (particles, sounds, vật lý), đây là **performance bottleneck**.

**Đề xuất**:
1. Dùng `CollectionService:GetInstanceAddedSignal(TagConfig.Tags.IceBlock)` thay vì `Workspace.ChildAdded`.
2. Kết nối `Players.PlayerRemoving` để dọn dẹp connection.

---

### 🟡 MEDIUM-1 — Hardcode `1.5x` tolerance trong `HandleToolHit`

- **Vị trí**: [`FreezeService.lua:498`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L498)
- **Mức độ**: `MEDIUM`

**Hiện trạng**:

```lua
if Distance > GameConfig.Tool.HitboxRange * 1.5 then return end  -- 1.5x tolerance lag
```

`1.5` là magic number hardcode. `HitboxRange = 20`, vậy threshold thực tế là **30 studs**. Đây là giá trị quan trọng cho game balance và security nhưng không có trong `GameConfig`. Nếu ai muốn tune, phải vào sâu FreezeService tìm.

**Đề xuất**: Thêm `HitboxTolerance = 1.5` vào `GameConfig.Tool`.

---

### 🟡 MEDIUM-2 — Nhiều Magic Delay trong MatchService

- **Vị trí**: [`MatchService.lua:457`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L457), [`MatchService.lua:655`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L655)
- **Mức độ**: `MEDIUM`

**Hiện trạng**:

```lua
task.wait(0.5)  -- buffer nhỏ để map load xong  (dòng 457)
task.wait(0.2)  -- buffer đảm bảo physics       (dòng 655)
```

Hai giá trị này là magic number không có trong `GameConfig.Phase`. Nếu map phức tạp hơn cần 1 giây buffer, phải vào tận MatchService tìm.

**Đề xuất**: Thêm `MapLoadBuffer = 0.5` và `PhysicsSyncBuffer = 0.2` vào `GameConfig.Phase`.

---

### 🟡 MEDIUM-3 — `WeightedRandom` duplicate code

- **Vị trí**: [`ShopService.lua:26-37`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L26-L37) và [`QuestService.lua:149-159`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L149-L159)
- **Mức độ**: `MEDIUM`

**Hiện trạng**: Hàm `WeightedRandom`/`WeightedRandomItem` có logic **hoàn toàn giống nhau** được copy-paste giữa `ShopService` và `QuestService`. Nếu có bug trong thuật toán (ví dụ tổng DropRate < 100 do làm tròn), phải sửa ở 2 chỗ.

**Đề xuất**: Extract ra `RewardHelper.WeightedRandom(Items)` hoặc tạo `GachaHelper.lua` dùng chung.

---

### 🟡 MEDIUM-4 — `DataConfig.ProfileLoadTimeout` dùng busy-wait loop

- **Vị trí**: [`DataService.lua:175-177`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L175-L177)
- **Mức độ**: `MEDIUM`

**Hiện trạng**:

```lua
while not ProfileResult and (os.clock() - StartTime < Timeout) and Player:IsDescendantOf(Players) do
    task.wait(0.05)  -- poll mỗi 50ms
end
```

Đây là polling loop với `task.wait(0.05)` — 20 lần/giây. Đã có `_ProfileLoadedBindable` event ở trên, nhưng lại dùng thêm loop poll để fallback. Vấn đề: nếu nhiều service gọi `WaitForData` cùng lúc cho cùng 1 player (ví dụ DataService + QuestService + SessionService trong cùng một tick), có nhiều coroutine đang poll đồng thời — không hiệu quả.

**Đề xuất**: Thay bằng `_ProfileLoadedBindable.Event:Wait()` kết hợp timeout dùng `task.delay`:

```lua
local TimeoutThread = task.delay(Timeout, function()
    -- signal timeout
end)
_ProfileLoadedBindable.Event:Wait()
task.cancel(TimeoutThread)
```

---

### 🟡 MEDIUM-5 — `STREAM_WAIT_TIMEOUT` và `STREAM_POLL_INTERVAL` hardcode trong SpectateController

- **Vị trí**: [`SpectateController.lua:85-86`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua#L85-L86)
- **Mức độ**: `MEDIUM`

**Hiện trạng**:

```lua
local STREAM_WAIT_TIMEOUT  = 5    -- hardcode
local STREAM_POLL_INTERVAL = 0.1  -- hardcode
```

Những giá trị streaming-related nên nằm trong `GameConfig` (server-side streaming config) hoặc ít nhất là `GuiConfig` (client-side UX parameters).

**Đề xuất**: Chuyển vào `GameConfig.Spectate = { StreamWaitTimeout = 5, StreamPollInterval = 0.1 }`.

---

### 🟡 MEDIUM-6 — `MinQty = 1`, `MaxQty = 5` hardcode trong ShopService

- **Vị trí**: [`ShopService.lua:101-106`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L101-L106)
- **Mức độ**: `MEDIUM`

**Hiện trạng**:

```lua
local MinQty = 1
local MaxQty = 5
```

Giới hạn số lượng mua rương là tham số game balance nhưng hardcode ngay trong handler. Phải vào ShopService để đổi khi muốn thêm gói mua 10.

**Đề xuất**: Thêm vào `ChestConfig` hoặc `EconomyConfig`: `MaxChestPurchaseQuantity = 5`.

---

### 🟢 LOW-1 — Legacy fields không cần thiết trong `PROFILE_TEMPLATE`

- **Vị trí**: [`DataService.lua:29,47-51`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L29)
- **Mức độ**: `LOW`

**Hiện trạng**: `OwnedCosmetics`, `DailyQuestData`, `MilestoneQuestData` được giữ "để tương thích ngược" nhưng code đã chuyển hoàn toàn sang `OwnedIcicles`/`OwnedBlocks` và `QuestData`. Những field này vẫn được `Reconcile()` tạo ra cho mọi player mới → tốn DataStore bandwidth.

**Đề xuất**: Khi không còn player nào có data cũ (hoặc sau migration script), xóa khỏi `PROFILE_TEMPLATE` và xóa các hàm deprecated `AddCosmetic`, `SetMilestoneBase`.

---

### 🟢 LOW-2 — Typo tên trong `GameLoadingController`

- **Vị trí**: [`GameLoadingController.lua:65`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua#L65)
- **Mức độ**: `LOW`

**Hiện trạng**:

```lua
local UpperContainer = ScreenFrame:FindFirstChild(UpperName) or ScreenFrame:FindFirstChild("UpperContaier")
```

`"UpperContaier"` là typo của `"UpperContainer"`. Fallback này chỉ tồn tại vì có lúc nào đó tên trong Studio bị sai, sau đó sửa GUI nhưng không xóa fallback. Dead code, gây confusion.

---

### 🟢 LOW-3 — `camelCase` biến cục bộ lẫn lộn với `PascalCase`

- **Vị trí**: Rải rác trong SpectateController, HighlightController
- **Mức độ**: `LOW`

**Hiện trạng**: `_isSpectating`, `_isFrozen`, `_hasTeams`, `_currentIndex` trong SpectateController; `_isFrozenState`, `_frozenPlayers`, `_playerStates` trong HighlightController — tất cả đều `camelCase`. Theo quy tắc dự án **PascalCase cho tất cả biến**, những biến module-level này vi phạm quy ước.

**Đề xuất**: Đổi thành `_IsSpectating`, `_IsFrozen`, `_HasTeams`, v.v. Áp dụng nhất quán cho toàn bộ `_`-prefixed module state variables.

---

### 🟢 LOW-4 — Comment tiếng Việt inline lẫn trong code logic

- **Vị trí**: Rải rác toàn bộ `src/`
- **Mức độ**: `LOW`

**Hiện trạng**: Comment block (`-- Khai báo`, `-- Kiểm tra`, v.v.) là tiếng Việt hoàn toàn — không vi phạm gì về mặt kỹ thuật. Tuy nhiên, theo quy tắc dự án "PascalCase và tiếng Anh cho mọi biến và hàm", comment là một vùng xám. Nhất quán với quy tắc thì nên quyết định: **toàn bộ comment dùng tiếng Anh hoặc toàn bộ tiếng Việt**, không lẫn lộn.

---

## 3. DANH SÁCH CÁC ĐIỂM MÂU THUẪN CẦN PHẢN BIỆN (DEBATE LIST)

### Debate A — Kiến trúc `OnToolHit` Client-Side Hit Detection

**Xung đột**: Client dùng `GetPartsInPart(Hitbox)` với Heartbeat poll để detect hit rồi `FireServer(OnToolHit, TargetPlayer)`. Server chỉ validate khoảng cách, không validate hitbox geometry thực tế.

- **Bên A (Client Authority - giữ nguyên)**: Latency thấp hơn, animation đồng bộ hơn với gameplay feel. Hầu hết competitive Roblox game dùng cách này.
- **Bên B (Server Authority - refactor)**: Client có thể sửa `Hitbox` size bằng exploit, hoặc fire `OnToolHit` mà không cần swing animation thật. Phải có Server-side hitbox simulation dù rough.

**Quan điểm của tôi**: Cách hiện tại **chấp nhận được** cho Roblox game casual-competitive nếu giữ nguyên distance check. Tuy nhiên cần thêm **rate limit**: mỗi player không thể fire `OnToolHit` quá X lần/giây (bằng cooldown cache tương tự `OnToolSwing`). Hiện tại `OnToolHit` không có rate limit server-side — chỉ bị chặn bởi `IsMatchActive` và `GetState == Normal`, nhưng một hacker có thể fire liên tục để exploit first-blood timing.

---

### Debate B — `FreezePlayer`/`ThawPlayer` double-read DataService

**Xung đột**: Trong `FreezePlayer`, DataService được đọc 2 lần để lấy `BlockSkinId` (dòng 67-71 và 225-228). Hai lần đọc gần nhau không gây bug nhưng vi phạm DRY.

```lua
-- Lần 1 (SpawnIceBlock):
local AttackerData = DataService.GetData(Attacker)
local SkinId = AttackerData.EquippedIceBlock...

-- Lần 2 (SFX):
local AttackerData = DataService.GetData(Attacker)
local BlockSkinId = AttackerData.EquippedIceBlock...
```

**Đề xuất**: `SpawnIceBlock` nên return `BlockSkinId` đã đọc để `FreezePlayer` không cần đọc lại.

---

### Debate C — `MatchService` lifecycle `MatchEndSignal` không reset đúng lúc

**Xung đột**: `_earlyResult` được set khi `MatchEndSignal` fire (trong `Init`), nhưng `_earlyResult = nil` chỉ được reset trong `RunSetup()`. Nếu `CheckWinCondition()` được gọi nhiều lần nhanh (ví dụ 2 player thoát game đồng thời), `MatchEndSignal` có thể fire 2 lần → `_earlyResult` bị ghi đè bởi cái thứ 2, nhưng game loop chỉ xử lý kết quả đầu tiên.

Thực tế Luau single-thread giảm nguy cơ này, nhưng signal fire trong `PlayerRemoving` và `CheckWinCondition` cùng thread → có thể fire 2 lần trong cùng một frame.

**Đề xuất**: Thêm guard `if _earlyResult then return end` trong `MatchEndSignal` handler:

```lua
SessionService.MatchEndSignal.Event:Connect(function(Result)
    if _earlyResult then return end  -- chỉ nhận kết quả đầu tiên
    _earlyResult = Result
end)
```

---

### Debate D — `PlayerRemoving` trong SessionService có thể trigger `CheckWinCondition` sau khi match đã kết thúc

**Xung đột**: Trong `SessionService.PlayerRemoving`:

```lua
if _isMatchActive then
    ...
    SessionService.CheckWinCondition()
    SessionService.ClearTeam(Player)
```

Nếu match đã kết thúc (MatchEndSignal đã fire, `RunGameOver` đang chạy), `_isMatchActive` vẫn có thể là `true` (chỉ được set `false` trong `RunGameOver` ở dòng 585). Nếu player rời trong khoảng thời gian từ lúc MatchEndSignal fire đến lúc `SetMatchActive(false)` được gọi, `CheckWinCondition` sẽ fire `MatchEndSignal` thêm lần nữa → duplicate GameOver processing.

**Đề xuất**: Set `_isMatchActive = false` ngay khi `_earlyResult` được gán, hoặc thêm `_isGameOverPending` flag.

---

> **Kết luận tổng thể**: Kiến trúc tổng thể của dự án **tốt** — lifecycle `Init/Start` nhất quán, không có logic chạy ngay khi `require`, RemoteDefinitions tập trung, Config tách biệt. Các vấn đề phát hiện chủ yếu là **race condition** trong flow thanh toán/claim (CRITICAL), **coupling ngầm** qua lazy-require, và **magic numbers** rải rác. Không có vấn đề naming convention nghiêm trọng ở phần Server — phía Client (Controllers) có một số biến `camelCase` prefix `_` cần chuẩn hóa.
