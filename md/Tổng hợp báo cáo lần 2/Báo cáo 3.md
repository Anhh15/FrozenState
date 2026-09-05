Searched for "ShopController"
Viewed ShopController.lua:690-726
Viewed ShopController.lua:650-690
Viewed ShopController.lua:630-655
Viewed GuiHelper.lua:1-60
Viewed InventoryController.lua:1-60
Viewed GuiConfig.lua:1-100
Viewed GuiConfig.lua:101-249
Viewed ProfileController.lua:40-80
Viewed ScoreBoardController.lua:1-60
Viewed ScoreBoardController.lua:250-320
Viewed PlayerStatusController.lua:1-100
Viewed PlayerStatusController.lua:180-239
Searched for "local [a-zA-Z0-9_]*[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđĐ]"
Viewed SettingController.lua:190-250
Searched for "BindToClose"
Viewed GameLoadingController.lua:170-250
Viewed GameLoadingController.lua:440-520
Viewed GameLoadingController.lua:300-340
Viewed ItemRewardController.lua:80-140
Viewed ItemRewardController.lua:440-483
Viewed ShopConfig.lua:1-26
Viewed HotbarController.lua:20-60
Viewed HotbarController.lua:140-220
Viewed SettingController.lua:1-100

# 📊 BÁO CÁO TỔNG QUAN RÀ SOÁT TOÀN BỘ SRC

Dưới vai trò **Senior Roblox System & Security Auditor**, tôi đã hoàn thành việc rà soát độc lập toàn bộ mã nguồn bên trong thư mục `src/` (bao gồm `ServerScriptService`, `StarterPlayer`, `ReplicatedStorage`). 

Kiến trúc hiện tại có sự cố gắng phân tách module (Service/Controller, Config, Helper), tuy nhiên đang tồn tại **nhiều lỗ hổng bảo mật nghiêm trọng (đặc biệt là lỗ hổng tài chính Robux và gian lận chiến đấu)**, **nhiều đoạn code chắp vá (duct-tape hacks)**, **lạm dụng polling mù quáng** và **sự thiếu nhất quán trầm trọng về quy ước đặt tên cũng như vòng đời khởi tạo (Lifecycle)**.

---

## 1. BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO

| Mức độ | Số lượng | Mô tả tóm tắt |
| :--- | :---: | :--- |
| 🔴 **CRITICAL** (Lỗ hổng bảo mật/Exploit) | **4** | Mất trắng giao dịch Robux do Race Condition khi người chơi thoát game; Đánh trước khi trận bắt đầu (Setup/Ready phase exploit); Bỏ qua hoàn toàn animation vung kiếm (Bypass Swing) trên Server; Đóng băng người chết/người chết đóng băng người sống. |
| 🟠 **HIGH** (Lỗi kiến trúc/Race Condition/Leak) | **6** | Lỗi Raycast chặn đòn đánh hợp lệ bởi người chơi thứ ba; Lỗ hổng DDoS/Flooding network không giới hạn tần suất (`RequestSpectateTarget`, `SaveSetting`); Khởi tạo GUI chết lúc `require` (Top-level nil references); Vỡ chuẩn vòng đời (16/24 Controller thiếu `Start()`); Rò rỉ sự kiện và đăng ký lặp (`FlushSession` chạy trùng lặp). |
| 🟡 **MEDIUM** (Hardcode/Thiếu nhất quán) | **5** | Vi phạm triệt để triết lý No Hardcode: Bỏ qua `ShopConfig`, hardcode giá rương, fallback magic numbers; Thiếu config tập trung cho UI của Inventory/Profile/ScoreBoard; Lạm dụng vòng lặp `task.wait(0.05)` thay vì Event/Signal; Phụ thuộc vòng (Circular dependency) giải quyết bằng getter lười rải rác. |
| 🟢 **LOW** (Code thừa/Format/Tối ưu nhỏ) | **3** | Vi phạm 100% quy ước PascalCase cho biến private/cục bộ; Dead code không sử dụng (`LockSpectatorMovement`, biến `Team` thừa); Controller tự `require(script)` bên trong chính nó. |

---

## 2. CHI TIẾT CÁC ĐIỂM YẾU & NGUY CƠ BẢO MẬT (Xếp theo độ ưu tiên)

### 🔴 NHÓM CRITICAL (RỦI RO BẢO MẬT & NGUY CƠ EXPLOIT CAO NHẤT)

#### 1. Lỗ hổng nuốt tiền Robux do Race Condition giữa `ProcessReceipt` và `PlayerRemoving`
- **Vị trí**: [`ShopService.lua:214-247`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L214-L247) và [`DataService.lua:147-164`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L147-L164)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**: 
  Trong `ShopService.lua`, `MarketplaceService.ProcessReceipt` lấy `Profile` từ `DataService.WaitForProfile(Player)`. Ngay sau đó, hàm gọi `DataService.AddMoney(Player, ...)` và `DataService.RecordPurchase(Player, PurchaseId)`. 
  Tuy nhiên, trong `DataService.lua`, các hàm `AddMoney` và `RecordPurchase` chỉ kiểm tra `ActiveProfiles[Player]`. Nếu người chơi ngắt kết nối (Disconnect/Alt+F4/Crash) đúng vào thời điểm này, `OnPlayerRemoving` chạy, gọi `Profile:Release()` và gán `ActiveProfiles[Player] = nil`. Lúc này, `AddMoney` và `RecordPurchase` gặp `ActiveProfiles[Player] == nil` nên chỉ in cảnh báo (`warn`) rồi âm thầm bỏ qua mà **không hề phát sinh lỗi (không throw error)**. Do đó, `pcall` trong `ProcessReceipt` vẫn trả về `Success = true`, và server báo về cho Roblox engine: `Enum.ProductPurchaseDecision.PurchaseGranted`!
- **Kịch bản khai thác / Hậu quả thực tế**: 
  Người chơi bỏ tiền thật mua gói Robux tiền tệ. Nếu mạng bị giật hoặc người chơi thoát game ngay khi giao dịch đang được xử lý: Roblox trừ tiền của người chơi và đánh dấu giao dịch đã hoàn tất vĩnh viễn, nhưng người chơi nhận được **0 đồng** trong game và biên lai không bao giờ được ghi vào DataStore. Đây là lỗi vi phạm chính sách thanh toán nghiêm trọng của Roblox.
- **Đề xuất giải pháp chuẩn**:
  - Không bao giờ trả về `PurchaseGranted` nếu `Profile` không còn active hoặc việc ghi DataStore không thành công.
  - Phải kiểm tra trạng thái `Profile:IsActive()` trực tiếp trước và sau khi cộng tiền. Nếu Profile đã bị release trong lúc đang xử lý, bắt buộc phải trả về `Enum.ProductPurchaseDecision.NotProcessedYet` để Roblox tự động retry khi người chơi vào lại game:
    ```lua
    if not Profile:IsActive() then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    ```

---

#### 2. Cho phép tấn công và đóng băng đối thủ ngay trong lúc Setup và Ready (Game Phase Bypass)
- **Vị trí**: [`MatchService.lua:453`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L453) kết hợp [`FreezeService.lua:485`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L485)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  Trong `MatchService.lua`, hàm `RunSetup()` gọi `SessionService.SetMatchActive(true)` ngay từ dòng 453. Sau đó, server phải đợi tải Map, đợi chạy hoạt ảnh màn hình đen (`FadeInDuration`), đợi thông báo chế độ (`AnnouncementDuration`), rồi mới bước vào `RunReady()` (đếm ngược 4 giây chuẩn bị). Tổng thời gian từ lúc này đến khi trận thực sự bắt đầu là khoảng 6–10 giây.
  Trong khi đó, điều kiện duy nhất để `FreezeService.HandleToolHit` chấp nhận đòn đánh là:
  ```lua
  if not SessionService.IsMatchActive() then return end
  ```
- **Kịch bản khai thác / Hậu quả thực tế**:
  Kẻ gian (exploiter) sử dụng script inject tool hoặc giữ vũ khí từ trước có thể bắn RemoteEvent `OnToolHit` ngay khi vừa bước vào map (lúc màn hình loading hoặc lúc đang đếm ngược Ready 4 giây, mọi người đang bị khóa chân `WalkSpeed = 0`). Toàn bộ đội đối phương sẽ bị đóng băng ngay tại điểm spawn trước khi trận đấu kịp đếm về 0! Trận đấu kết thúc ngay lập tức mà nạn nhân không thể làm gì.
- **Đề xuất giải pháp chuẩn**:
  - Không được dùng cờ gộp `IsMatchActive` cho cả Setup/Ready.
  - `FreezeService.HandleToolHit` bắt buộc phải kiểm tra chính xác phase của trận đấu:
    ```lua
    if MatchService.GetCurrentPhase() ~= "InGame" then return end
    ```
  - Chỉ gọi `SessionService.SetMatchActive(true)` tại thời điểm bắt đầu `RunInGame()`, và tắt ngay khi chuyển sang `GameOver`.

---

#### 3. Phê duyệt đòn đánh Client-side không đồng bộ với Swing (Bypass Swing Animation & Desync Action)
- **Vị trí**: [`FreezeService.lua:498-520`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L498-L520) và [`IcicleService.lua:143-174`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/IcicleService.lua#L143-L174)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  Hệ thống thiết kế 2 RemoteEvent riêng rẽ: `OnToolSwing` (gửi lên `IcicleService` chỉ để phát âm thanh SFX) và `OnToolHit` (gửi lên `FreezeService` để ghi nhận đòn đánh).
  Trong `FreezeService.lua`, khi nhận được `OnToolHit`, server tự động tạo ra một `AttackSession` mới bằng `Now`:
  ```lua
  if not Session or (Now - Session.SwingStart) >= DebounceWindow then
      _AttackSessions[Attacker.UserId] = {
          SwingStart = Now,
          HitTargets = { [Target.UserId] = true },
      }
  ```
- **Kịch bản khai thác / Hậu quả thực tế**:
  Client không hề bị ràng buộc phải vung kiếm trước khi gửi đòn đánh. Exploiter hoàn toàn có thể **không cần gọi `OnToolSwing`**, không cần chạy hoạt ảnh vung kiếm, chỉ cần đứng cạnh đối thủ và gửi `OnToolHit` thẳng lên server theo đúng chu kỳ cooldown (0.8s). Server vẫn chấp nhận 100% vì tự khởi tạo `SwingStart = Now`. Điều này biến đòn đánh thành "Silent Instant Hit" vô hình, đối thủ bị đóng băng mà không thấy bất kỳ động tác tấn công nào.
- **Đề xuất giải pháp chuẩn**:
  - Hợp nhất quy trình tấn công thành State Machine 2 bước có xác thực thời gian:
    1. Khi click, Client gửi `OnToolSwing`. Server lưu lại `LastSwingTime = os.clock()` và xác thực người chơi đang cầm kiếm.
    2. Khi Hitbox chạm (sau một khoảng delay hoạt ảnh `HitStartTime`), Client gửi `OnToolHit`.
    3. Server kiểm tra: `(Now - LastSwingTime)` phải nằm chính xác trong khoảng `[HitStartTime - DungSai, HitEndTime + DungSai]`. Nếu chưa từng vung kiếm hoặc vung kiếm quá lâu trước đó -> Từ chối đòn đánh.

---

#### 4. Bỏ sót kiểm tra trạng thái sống chết của nhân vật (`Humanoid.Health`) khi thực hiện đòn đánh
- **Vị trí**: [`FreezeService.lua:490-496`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L490-L496)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  Trong `HandleToolHit`:
  ```lua
  local AttackerChar = Attacker.Character
  local TargetChar   = Target.Character
  if not AttackerChar or not TargetChar then return end
  local Tool = AttackerChar:FindFirstChild("Icicle") or AttackerChar:FindFirstChildOfClass("Tool")
  if not Tool then return end
  ```
  Hoàn toàn không có dòng code nào kiểm tra `Humanoid.Health > 0` của cả `Attacker` lẫn `Target`!
- **Kịch bản khai thác / Hậu quả thực tế**:
  - Khi `Attacker` đã bị rơi xuống vực hoặc bị reset nhân vật (`Health = 0`), trong 1-2 giây đang chạy hoạt ảnh chết (Ragdoll/Death animation) trước khi Character biến mất, client của Attacker vẫn gửi được `OnToolHit` để đóng băng người khác từ cõi chết.
  - Tương tự, nếu `Target` vừa chết do rơi khỏi bản đồ hoặc chết do reset, `OnToolHit` gửi đến trước khi sự kiện `Humanoid.Died` kịp cập nhật state sang "Dead". Server sẽ thực hiện `SpawnIceBlock`, anchor một cái xác chết, hàn `WeldConstraint` khối băng vào xác chết trôi nổi trong không gian và tính điểm Freeze sai lệch.
- **Đề xuất giải pháp chuẩn**:
  Bắt buộc kiểm tra `Humanoid` và lượng máu của cả 2 phía trước khi xử lý bất kỳ logic nào:
  ```lua
  local AttackerHumanoid = AttackerChar:FindFirstChildOfClass("Humanoid")
  local TargetHumanoid = TargetChar:FindFirstChildOfClass("Humanoid")
  if not AttackerHumanoid or AttackerHumanoid.Health <= 0 then return end
  if not TargetHumanoid or TargetHumanoid.Health <= 0 then return end
  ```

---

### 🟠 NHÓM HIGH (LỖI KIẾN TRÚC, RACE CONDITION, LEAK BỘ NHỚ)

#### 5. Thuật toán Raycast Line-of-Sight bị chặn sai bởi người chơi thứ ba và bỏ lọt tường `CanCollide = false`
- **Vị trí**: [`FreezeService.lua:530-538`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L530-L538)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  ```lua
  local RayParams = RaycastParams.new()
  RayParams.FilterType = Enum.RaycastFilterType.Exclude
  RayParams.FilterDescendantsInstances = { AttackerChar, TargetChar }
  local RayDirection = TargetHRP.Position - AttackerHRP.Position
  local RayResult = workspace:Raycast(AttackerHRP.Position, RayDirection, RayParams)
  if RayResult and RayResult.Instance and RayResult.Instance.CanCollide then
      return
  end
  ```
  - `FilterDescendantsInstances` chỉ loại trừ duy nhất `AttackerChar` và `TargetChar`.
  - Bộ lọc kiểm tra `RayResult.Instance.CanCollide`.
- **Kịch bản khai thác / Hậu quả thực tế**:
  1. **Đánh trúng nhưng bị mất đòn (False Negative)**: Trong một pha giao tranh đông người hoặc khi đồng đội đứng chen ngang ở giữa, tia Raycast từ Attacker tới Target sẽ bắn trúng người chơi thứ 3 này (vì nhân vật người chơi thứ 3 có `CanCollide = true` ở phần thân). Kết quả: Đòn đánh bị server hủy bỏ vô lý mặc dù giữa 2 người không hề có bức tường nào!
  2. **Đánh xuyên vật thể (False Positive)**: Nếu Map designer tạo ra các bức tường kính trong suốt, cửa sổ hoặc vật cản ngăn cách mà lỡ tắt thuộc tính `CanCollide` (dùng invisible wall riêng), Raycast kiểm tra `CanCollide` sẽ bỏ qua vật cản này, cho phép người chơi đánh xuyên qua cửa kính/vật cản.
- **Đề xuất giải pháp chuẩn**:
  - Đưa toàn bộ thư mục nhân vật (`workspace`) hoặc danh sách tất cả Character trong trận vào danh sách bỏ qua của Raycast.
  - Sử dụng Collision Group chuyên dụng dành riêng cho Raycast kiểm tra tầm nhìn (Line of Sight), hoặc kiểm tra Tag của địa hình/map thay vì dựa vào thuộc tính `CanCollide` đơn thuần.

---

#### 6. Không có Rate-Limiting trên các RemoteEvent nhạy cảm (`RequestSpectateTarget`, `SaveSetting`)
- **Vị trí**: [`MatchService.lua:820-872`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L820-L872) và [`DataService.lua:801-809`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L801-L809)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  Trong khi `SetAfkState` và `OnToolSwing` đã được trang bị bảng lưu thời gian để Debounce (`_LastAfkToggleTimes`, `_lastSwingTimes`), thì `RequestSpectateTarget` và `SaveSetting` lại **hoàn toàn không có bất kỳ bộ đếm thời gian (Rate Limiter) nào**.
- **Kịch bản khai thác / Hậu quả thực tế**:
  Một Client gian lận có thể viết vòng lặp `while task.wait() do` bắn liên tục hàng nghìn gói tin `RequestSpectateTarget` hoặc `SaveSetting` mỗi giây. Server bị ép phải liên tục tính toán phân quyền spectate, gán lại thuộc tính mạng `ReplicationFocus` của engine, hoặc liên tục ghi dữ liệu vào bảng RAM của DataService, gây tắc nghẽn băng thông mạng (Network Ping Spike) và sụt giảm FPS của toàn bộ server.
- **Đề xuất giải pháp chuẩn**:
  Áp dụng bộ đếm cooldown trên Server cho mọi Remote tiếp nhận từ Client (tối thiểu 0.2s - 0.5s giữa 2 request đổi target spectate hoặc lưu setting).

---

#### 7. Khởi tạo tham chiếu GUI ở cấp độ Module Root gây lỗi `nil` chết hàng loạt Controller
- **Vị trí**: 
  - [`ShopController.lua:47-63`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua#L47-L63)
  - [`InventoryController.lua:45-60`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua#L45-L60)
  - [`ProfileController.lua:47-63`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua#L47-L63)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  Tại các file trên, các biến GUI như `Shop`, `ShopClose`, `TabContainer`, `Inventory`, `Profile` được tìm kiếm bằng `FindFirstChild` ngay ở ngoài cùng của file (khi file vừa được `require`).
  Nếu tại thời điểm client vừa kết nối, các UI trong `PlayerGui` chưa kịp sao chép (replicate) xong từ `StarterGui`, các biến này sẽ mang giá trị `nil`. Sau đó, khi `Init()` chạy:
  ```lua
  if not Shop then
      warn("[ShopController] Không tìm thấy Shop frame trong Menu GUI. Kiểm tra lại tên GUI.")
      return
  end
  ```
- **Hậu quả thực tế**: 
  Hàm `Init()` văng ra cảnh báo rồi hủy bỏ hoàn toàn việc khởi tạo. Toàn bộ tính năng Shop, Inventory hoặc Profile bị tê liệt vĩnh viễn trong suốt phiên chơi của client đó, người chơi click vào nút mở không có bất kỳ phản hồi nào.
- **Đề xuất giải pháp chuẩn**:
  Tuyệt đối không gán tham chiếu GUI ở scope toàn cục của Module. Bắt buộc chuyển toàn bộ logic tìm kiếm UI vào trong hàm `:Init()` kèm cơ chế `WaitForChild` an toàn hoặc thông qua một hàm `ResolveElements()` nội bộ (giống như cách `GameLoadingController` và `HotbarController` đã làm rất tốt).

---

#### 8. Đăng ký trùng lặp sự kiện giải phóng dữ liệu trong `QuestService`
- **Vị trí**: [`QuestService.lua:691-695`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L691-L695)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  Trong `QuestService:Init()`:
  ```lua
  if DataService.RegisterBeforeProfileRelease then
      DataService.RegisterBeforeProfileRelease(FlushSession)
  end

  Players.PlayerRemoving:Connect(FlushSession)
  ```
  Hàm `FlushSession` được đăng ký **cả 2 nơi**: vừa thông qua callback đồng bộ `BeforeProfileRelease` của `DataService`, vừa tự kết nối trực tiếp vào `Players.PlayerRemoving`.
- **Hậu quả thực tế**:
  Khi một người chơi thoát game, `FlushSession` sẽ bị gọi 2 lần liên tiếp. Lần thứ nhất chạy trơn tru, dọn sạch `_sessionStart[Player] = nil`. Đến lần thứ hai (khi sự kiện `PlayerRemoving` riêng lẻ kích hoạt), do thứ tự event của Roblox là bất định, có khả năng `ActiveProfiles[Player]` đã bị ProfileService giải phóng, nhưng `FlushSession` lần 2 vẫn cố gọi `QuestService.DispatchEvent` -> `DataService.GetQuestRawData` -> `WaitForProfile` tạo ra luồng rác không cần thiết hoặc gây ra cảnh báo đỏ trong log server.
- **Đề xuất giải pháp chuẩn**:
  Chỉ giữ lại duy nhất cơ chế `DataService.RegisterBeforeProfileRelease(FlushSession)` để đảm bảo tính đồng bộ trước khi giải phóng Profile; xóa bỏ kết nối `Players.PlayerRemoving:Connect(FlushSession)` tại `QuestService`.

---

### 🟡 NHÓM MEDIUM (HARDCODE & THIẾU NHẤT QUÁN KIẾN TRÚC)

#### 9. Vi phạm nguyên tắc No Hardcode: Bỏ qua config có sẵn và để rải rác Magic Numbers / Magic Strings
- **Vị trí**:
  - [`ShopService.lua:102-103`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L102-L103): Tự khai báo `local MinQty = 1`, `local MaxQty = 5` trong khi file [`ShopConfig.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/ShopConfig.lua) đã có sẵn `ShopConfig.MinAmount` và `ShopConfig.MaxAmount`.
  - [`QuestService.lua:151, 209`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L151): Hardcode số tiền hoàn lại mặc định `1000` (`RefundBasePrice = Chest.Price1 or 1000`, `BasePrice = 1000`) thay vì lấy từ `EconomyConfig`.
  - [`HighlightController.lua:21-22`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L21-L22): Hardcode chuỗi tên `"TeamHighlight"`, `"HighlightHelper"` thay vì đưa vào `TagConfig` hoặc `GuiConfig`.
  - [`GuiConfig.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GuiConfig.lua): Bị khuyết thiếu cấu hình của `Inventory`, `Profile`, `ScoreBoard`, `PlayerStatus`. Hậu quả là các Controller tương ứng tự hardcode chuỗi tên như `"AvatarThumbnail"`, `"ItemList"`, `"PlayerStats"`, `"GameWins"`, `"PlayerStatus"`, `"AllyTeam"`, `"EnemyTeam"`.
- **Mức độ**: `MEDIUM`
- **Hậu quả thực tế**:
  Khi Game Designer muốn đổi giới hạn số lượng mua rương hoặc điều chỉnh cơ chế hoàn tiền, họ sửa trong file Config nhưng Server vẫn chạy theo số hardcode cũ. Khi UI Designer đổi tên frame trong Studio, code lập tức bị gãy do chuỗi hardcode không khớp.
- **Đề xuất giải pháp chuẩn**:
  - Bổ sung toàn bộ bảng cấu hình phần tử UI cho các tính năng còn thiếu vào `GuiConfig.lua`.
  - Import và sử dụng `ShopConfig.MinAmount / MaxAmount` trong `ShopService`.
  - Đưa hằng số giá hoàn tiền `1000` vào `EconomyConfig.lua`.

---

#### 10. Đứt gãy tính nhất quán của vòng đời (Lifecycle Inconsistency) giữa các Controller
- **Vị trí**: Toàn bộ thư mục [`StarterPlayer/StarterPlayerScripts/Controllers/`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers)
- **Mức độ**: `MEDIUM`
- **Hiện trạng & Vấn đề**:
  Trong `Main.client.lua`, kiến trúc được thiết kế rõ ràng theo 2 pha:
  - **Pha 1**: Gọi `Init()` trên toàn bộ 24 Controller (chuyên trách chuẩn bị giao diện, thiết lập trạng thái nội bộ).
  - **Pha 2**: Gọi `Start()` trên toàn bộ 24 Controller (chuyên trách kết nối mạng, lắng nghe RemoteEvent và giao tiếp chéo giữa các Controller).
  Thế nhưng, khi quét toàn bộ mã nguồn: **Chỉ có 8/24 Controller có hàm `Start()`!** 16 Controller còn lại dồn hết toàn bộ logic kết nối RemoteEvent và logic nghiệp vụ vào `Init()`.
- **Hậu quả thực tế**:
  Các Controller ở pha `Init` cố gắng giao tiếp với các Controller khác chưa kịp khởi tạo xong, dẫn tới việc lập trình viên phải "vá tạm" bằng cách viết các hàm getter lười (`GetMenuController()`, `GetNavigationController()`, `GetItemRewardController()`, `GetHotbarController()`) sử dụng `script.Parent:FindFirstChild(...)` rải rác khắp 10 file khác nhau.
- **Đề xuất giải pháp chuẩn**:
  Quy chuẩn hóa 100% Controller:
  - Hàm `Init()`: Chỉ làm việc với GUI cục bộ, lấy reference, gán thuộc tính mặc định.
  - Hàm `Start()`: Kết nối các RemoteEvent, kết nối UserInputService và tham chiếu sang các Controller khác. Loại bỏ triệt để các hàm getter lười.

---

#### 11. Lạm dụng Busy-Waiting Polling bằng `task.wait(0.05)` thay vì Event/Signal
- **Vị trí**: [`PlayerDataController.lua:118, 137`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua#L118)
- **Mức độ**: `MEDIUM`
- **Hiện trạng & Vấn đề**:
  Trong `PlayerDataController.lua`, hàm `WaitForData()` và `RefreshData()` sử dụng vòng lặp kiểm tra cờ:
  ```lua
  while not _isDataLoaded and (os.clock() - StartTime < Timeout) do
      task.wait(0.05)
  end
  ```
  Trong khi đó, ngay tại dòng 22 của chính file này đã có sẵn một đối tượng `_dataLoadedBindable = Instance.new("BindableEvent")`!
- **Hậu quả thực tế**:
  Việc chạy vòng lặp `task.wait(0.05)` liên tục đánh thức thread của Lua scheduler (busy polling), vừa tốn CPU vừa gây ra độ trễ giả từ 0ms đến 50ms khi dữ liệu đã sẵn sàng.
- **Đề xuất giải pháp chuẩn**:
  Thay thế toàn bộ vòng lặp while polling bằng việc chờ Signal:
  ```lua
  if not _isDataLoaded then
      _dataLoadedBindable.Event:Wait()
  end
  return _localData
  ```

---

### 🟢 NHÓM LOW (CODE SMELL, QUY ƯỚC ĐẶT TÊN & TỐI ƯU NHỎ)

#### 12. Vi phạm quy ước 100% PascalCase trên diện rộng
- **Vị trí**: Hầu hết các file trong `src/`, ví dụ:
  - `FreezeService.lua`: `_firstBloodClaimed`, `_iceBlocks`
  - `SessionService.lua`: `_playerStates`, `_teamAssignment`, `_isMatchActive`, biến vòng lặp `for _, p in ...`, `for i = ...`, `for t = ...`
  - `MatchService.lua`: `_currentPhase`, `_earlyResult`, `_roundCounter`
  - `SpectateController.lua`: `_isSpectating`, `_isFrozenSpectator`, `_targetList`
- **Mức độ**: `LOW`
- **Hiện trạng**: Quy ước bắt buộc của dự án là 100% PascalCase và tiếng Anh cho tất cả biến, hàm. Việc pha trộn camelCase (`_currentPhase`) với PascalCase (`_RotConn`, `_ActiveSlots`) làm mất đi tính đồng bộ của toàn bộ hệ thống code.
- **Đề xuất**: Refactor đồng bộ toàn bộ biến cục bộ và biến module private sang PascalCase (ví dụ: `_CurrentPhase`, `_EarlyResult`, `_PlayerStates`, `Index`, `PlayerItem`).

---

#### 13. Dead Code & Anti-Pattern tự `require` chính mình
- **Vị trí**:
  - [`SpectateController.lua:102-122`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua#L102-L122): Khai báo 2 hàm `LockSpectatorMovement()` và `UnlockSpectatorMovement()` nhưng không hề có bất kỳ dòng code nào trong toàn bộ project gọi tới 2 hàm này.
  - [`SpectateController.lua:307`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua#L307): Viết `local SpectateController = require(script)` ngay bên trong chính module `SpectateController` để gọi `SetVisible(false)`, trong khi biến bảng `SpectateController` đã nằm sẵn ở scope ngoài!
  - [`SessionService.lua:420`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua#L420): Khai báo `local Team = _teamAssignment[Player]` nhưng không bao giờ sử dụng biến `Team`.
- **Mức độ**: `LOW`
- **Đề xuất**: Dọn dẹp các hàm mồ côi và biến thừa; thay `require(script).SetVisible(false)` bằng việc gọi trực tiếp `SpectateController.SetVisible(false)`.

---

## 3. DANH SÁCH CÁC ĐIỂM MÂU THUẪN CẦN PHẢN BIỆN (DEBATE LIST)

Dưới đây là các xung đột kiến trúc và logic giữa Client - Server cần thảo luận và thống nhất trước khi tiến hành viết code:

### Mâu thuẫn 1: Cơ chế Hit Detection — Client Spatial Query vs Server Raycast
- **Thực trạng**: 
  Client sử dụng `workspace:GetPartsInPart(Hitbox)` để bắt va chạm hình hộp 3D theo thời gian thực (rất mượt cho người đánh). Tuy nhiên, khi gửi lên Server, Server lại kiểm tra bằng một tia `Raycast` đường thẳng nối từ tâm HRP của Attacker sang tâm HRP của Target.
- **Vấn đề phản biện**: 
  Hai cơ chế toán học này hoàn toàn lệch nhau. Nếu Attacker đứng nép sau một góc cột và vung kiếm sượt qua mép ngoài của đối thủ, Hitbox 3D của Client sẽ báo trúng, nhưng tia Raycast thẳng của Server sẽ va vào mép cột và từ chối đòn đánh. Người chơi sẽ thấy kiếm chém trúng đối thủ nhưng đối thủ không hề bị đóng băng.
- **Câu hỏi kiến trúc**: Dự án muốn ưu tiên tính chuẩn xác tuyệt đối của Server (Server-side Shapecast / Spherecast) hay giữ Raycast đơn giản và nâng dung sai góc nhìn?

---

### Mâu thuẫn 2: Xử lý vật lý nhân vật khi Spectate ở xa (StreamingEnabled & Desync)
- **Thực trạng**: 
  Trong `SpectateController.lua`, Client gửi `RequestSpectateTarget` để Server set `Player.ReplicationFocus` sang người đang được quan sát. Hai hàm `LockSpectatorMovement` và `UnlockSpectatorMovement` bị bỏ quên không gọi.
- **Vấn đề phản biện**: 
  Dù có gọi `Humanoid.WalkSpeed = 0` trên Client thì thuộc tính này cũng **không replicate lên Server**. Khi `ReplicationFocus` bị dời ra xa khỏi vị trí thực tế của nhân vật Spectator tại Lobby, cơ chế vật lý của nhân vật ở sảnh sẽ bị mất kiểm soát cục bộ (network ownership desync) hoặc rơi xuyên sàn nếu vùng sảnh bị stream out.
- **Câu hỏi kiến trúc**: Khi người chơi bật Spectate, Server có nên Anchor trực tiếp `HumanoidRootPart` của Spectator tại Lobby và Unanchor khi họ tắt Spectate không?

---

### Mâu thuẫn 3: Định nghĩa trạng thái trận đấu (`InGame` vs `MatchActive`)
- **Thực trạng**: 
  `SessionService` có cờ `_isMatchActive`, trong khi `MatchService` lại quản lý State Machine qua `_currentPhase` (`Intermission`, `Setup`, `Ready`, `InGame`, `GameOver`). Hiện tại, `_isMatchActive` bị bật sớm ngay từ `Setup`.
- **Vấn đề phản biện**: 
  Việc duy trì song song 2 nguồn chân lý (Single Source of Truth) cho trạng thái trận đấu dẫn tới lỗ hổng bảo mật số 2 nêu trên. 
- **Câu hỏi kiến trúc**: Có nên khai tử hoàn toàn cờ `_isMatchActive` độc lập và đồng bộ hóa toàn bộ các Service theo một State Machine duy nhất do `MatchService` làm chủ quản không?

---

### Mâu thuẫn 4: Khởi tạo GUI — Tải trước tập trung (Pre-resolve) hay Khởi tạo lười (Lazy-load)
- **Thực trạng**: 
  Một nửa Controller (`ShopController`, `InventoryController`, `ProfileController`) cố gắng resolve GUI ngay lúc nạp file gây lỗi `nil`. Nửa còn lại (`ScoreBoardController`, `HotbarController`) lazy-load trong `Init()`.
- **Vấn đề phản biện**: 
  Cách làm chắp vá hiện tại là nguyên nhân sinh ra hàng loạt hàm getter rải rác. 
- **Câu hỏi kiến trúc**: Có nên thống nhất quy chuẩn: Tất cả GUI components chỉ được phép resolve bên trong `Init()` sau khi `GameLoadingController` đã xác nhận Client sẵn sàng?