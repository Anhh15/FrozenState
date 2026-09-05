Searched for files: *
Searched for files: *.lua
Searched for files: *.lua
Searched for files: *.lua
Viewed RemoteDefinitions.lua:1-161
Viewed Main.server.lua:1-17
Viewed ServiceLoader.lua:1-80
Viewed FreezeService.lua:1-556
Viewed IcicleService.lua:1-189
Viewed IcicleScript.client.lua:1-247
Viewed DataService.lua:1-754
Viewed ProfileService.lua:1-100
Searched for "ProfileService"
Searched for "PlayerRemoving"
Viewed ShopService.lua:1-309
Viewed ChestConfig.lua:1-110
Viewed QuestService.lua:1-700
Viewed QuestConfig.lua:1-100
Viewed QuestConfig.lua:350-397
Viewed SessionService.lua:1-460
Viewed MatchService.lua:1-800
Viewed MatchService.lua:800-856
Viewed AdminService.lua:1-448
Viewed AdminConfig.lua:1-54
Searched for "AdminConfig"
Viewed TeamService.lua:1-83
Viewed MapService.lua:1-92
Viewed Main.client.lua:1-70
Viewed HighlightController.lua:1-332
Viewed SpectateController.lua:1-618
Viewed HotbarController.lua:1-750
Viewed PlayerDataController.lua:1-209
Viewed ShopController.lua:1-717
Searched for "Chests"
Viewed SettingController.lua:1-357
Viewed SoundController.lua:1-135
Viewed AudioHelper.lua:1-374
Viewed GameStateController.lua:1-241
Viewed MusicController.lua:1-163
Viewed ScoreBoardController.lua:1-359
Viewed PlayerStatusController.lua:1-231
Viewed QuestController.lua:1-651
Viewed AccoladesController.lua:1-128
Viewed InventoryController.lua:1-454
Viewed ProfileController.lua:1-286
Viewed GameStatisticController.lua:1-304
Viewed NavigationController.lua:1-226
Viewed MenuController.lua:1-266
Viewed GameLoadingController.lua:1-552
Viewed GameOverAnnouncementController.lua:1-282
Viewed ModeAnnouncementController.lua:1-243
Viewed FrozenStateAnnouncementController.lua:1-176
Viewed RoundLoadingScreenController.lua:1-253
Viewed ItemRewardController.lua:1-469
Searched for "EconomyConfig"
Searched for "InventoryConfig"
Viewed InventoryConfig.lua:1-10
Searched for "PlayerStateConfig"

# 📊 BÁO CÁO TỔNG QUAN RÀ SOÁT TOÀN BỘ SRC

Tôi đã hoàn thành rà soát toàn bộ thư mục `src/` (bao gồm `ServerScriptService`, `StarterPlayerScripts`, `ReplicatedStorage`). Dưới đây là kết quả kiểm toán an ninh và kiến trúc hệ thống độc lập.

---

## 1. BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO

| Mức độ | Số lượng | Mô tả tóm tắt |
| :--- | :--- | :--- |
| 🔴 **CRITICAL** (Lỗ hổng bảo mật/Exploit) | **5** | Thiếu Rate Limit/Line of Sight đòn đánh; Injection gây Dirty Write/Crash DataStore; Remote crash server; Race Condition GamePass/Claim; ForceLoad cướp session lock. |
| 🟠 **HIGH** (Lỗi kiến trúc/Race Condition/Leak) | **7** | Rò rỉ Instance IceBlock vĩnh viễn trong Workspace; Event connection leak trong tool; Lắng nghe `Workspace.ChildAdded` gây tụt FPS; 23 lời gọi `WaitForChild` treo boot Client; Lộ file nhạy cảm ở `ReplicatedStorage`. |
| 🟡 **MEDIUM** (Hardcode/Thiếu nhất quán) | **5** | Debug hack `ResetSeconds = 60` bỏ quên; Bất đồng nhất Lifecycle Client vs Server; Hàng loạt magic numbers và mã màu hardcode; Vi phạm quy ước đặt tên `_camelCase`. |
| 🟢 **LOW** (Code thừa/Format/Tối ưu nhỏ) | **4** | File rỗng `InventoryConfig.lua`; Lạm dụng `task.wait()`; Khởi tạo Sound ở top-level require; Dùng `Player.Chatted` lỗi thời. |

---

## 2. CHI TIẾT CÁC ĐIỂM YẾU & NGUY CƠ BẢO MẬT

### 🔴 NHÓM 1: LỖ HỔNG BẢO MẬT & SERVER AUTHORITY (CRITICAL)

#### 1. Lỗ hổng `OnToolHit`: Thiếu Debounce, Rate Limit, Line of Sight và Tool Equipped Check
- **Vị trí**: [`FreezeService.lua:477-526`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L477-L526)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  1. Server chỉ kiểm tra duy nhất cự ly `Distance > GameConfig.Tool.HitboxRange * 1.5` dựa trên tọa độ của 2 `HumanoidRootPart`.
  2. **Không có Raycast kiểm tra Line of Sight**: Không xác minh có vật cản (tường, sàn nhà) giữa kẻ tấn công và nạn nhân hay không.
  3. **Không kiểm tra Tool Equipped**: Server không hề kiểm tra xem `Attacker.Character` có đang cầm Tool `Icicle` hay không.
  4. **Không có Cooldown / Rate Limit phía Server**: Không có bất kỳ biến debounce nào lưu timestamp đòn đánh gần nhất của người chơi.
  5. **Không xác thực với `OnToolSwing`**: Server không kiểm tra xem client có vừa thực hiện hành động vung kiếm hợp lệ trong cửa sổ đánh (`HitWindow`) hay không.
- **Kịch bản khai thác / Hậu quả thực tế**:
  Hacker dùng executor gửi một vòng lặp `for _, Target in ipairs(Players:GetPlayers()) do OnToolHit:FireServer(Target) end` liên tục mỗi frame. Kẻ tấn công có thể đứng sau một bức tường thành kiên cố, không cần trang bị vũ khí, và lập tức đóng băng (hoặc giải cứu) toàn bộ người chơi trong bán kính $1.5 \times HitboxRange$ trong 1 mili-giây mà không hề bị server chặn lại.
- **Đề xuất giải pháp chuẩn**:
  - Lưu bảng `_LastAttackTimestamps[UserId] = os.clock()` trên Server, ép khoảng cách tối thiểu giữa 2 lần nhận `OnToolHit` phải $\ge Cooldown - Tolerance$.
  - Kiểm tra `Attacker.Character:FindFirstChild("Icicle")` thực sự đang ở trên tay nhân vật.
  - Thực hiện `workspace:Raycast(AttackerHRP.Position, TargetHRP.Position - AttackerHRP.Position, RaycastParams)` với bộ lọc loại trừ 2 nhân vật để đảm bảo không bị cản bởi địa hình/tường.

---

#### 2. Lỗ hổng Payload Injection tại `SaveSetting`: Gây Dirty Write và Crash DataStore
- **Vị trí**: [`DataService.lua:652-673`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L652-L673) và [`DataService.lua:741-748`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L741-L748)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  Trong `SaveSettingEvent.OnServerEvent`, server chỉ kiểm tra `type(Key) == "string" and Value ~= nil`.
  Sau đó truyền vào `SetSetting(Player, Key, Value)`:
  ```lua
  if type(Value) == "number" then
      Value = math.clamp(math.round(Value / 10) * 10, 0, 100)
  end
  Profile.Data.Settings[Key] = Value
  ```
  Nếu `Value` **KHÔNG PHẢI là `number`** (ví dụ: `table` lồng nhau vô hạn, chuỗi string 2MB, `boolean`, `NaN`), lệnh `if` bị bỏ qua và `Value` được ghi thẳng vào `Profile.Data.Settings[Key]`.
- **Kịch bản khai thác / Hậu quả thực tế**:
  Hacker bắn: `SaveSetting:FireServer({ Key = "MasterVolume", Value = string.rep("A", 4e6) })` hoặc một bảng đệ quy cyclic table `{}`.
  Khi `ProfileService` tự động lưu xuống DataStore của Roblox:
  - Quá tải giới hạn 4MB / lỗi JSON Encode Cyclic Table.
  - DataStore báo lỗi nghiêm trọng, session bị corrupt, người chơi đó bị mất sạch toàn bộ dữ liệu khi join lại server mới.
- **Đề xuất giải pháp chuẩn**:
  Ép kiểu nghiêm ngặt và Whitelist giá trị:
  ```lua
  if typeof(Value) ~= "number" or Value ~= Value or Value == math.huge or Value == -math.huge then
      return false
  end
  ```

---

#### 3. Remote Crash Server thông qua `RequestSpectateTarget`
- **Vị trí**: [`MatchService.lua:794-820`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L794-L820)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  Server xử lý:
  ```lua
  RequestSpectateTargetEvent.OnServerEvent:Connect(function(SpectatorPlayer, TargetPlayer)
      if TargetPlayer == nil then ... return end
      if _currentPhase ~= "InGame" then return end
      ...
      if not TargetPlayer:IsDescendantOf(Players) then return end
  ```
  Server hoàn toàn **KHÔNG kiểm tra `TargetPlayer` có phải là Instance hay không**.
- **Kịch bản khai thác / Hậu quả thực tế**:
  Hacker gửi `RequestSpectateTarget:FireServer(12345)` hoặc `RequestSpectateTarget:FireServer("HackString")`.
  Khi server thực thi `TargetPlayer:IsDescendantOf(Players)`, engine sẽ văng lỗi runtime: `attempt to call method 'IsDescendantOf' (a nil value)`. Luồng sự kiện bị ngắt (unhandled exception). Nếu hacker spam liên tục sẽ gây spam exception làm nghẽn Event Loop của server.
- **Đề xuất giải pháp chuẩn**:
  Kiểm tra kiểu dữ liệu trước khi gọi bất kỳ method nào:
  ```lua
  if typeof(TargetPlayer) ~= "Instance" or not TargetPlayer:IsA("Player") then return end
  ```

---

#### 4. Race Condition & Reentrancy Vulnerability tại `ResetDailyQuests` và `ClaimQuest`
- **Vị trí**: [`QuestService.lua:473-526`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L473-L526) và [`ShopService.lua:264-294`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L264-L294)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  Trong `ResetDailyQuests(Player)`:
  1. Gọi `ShopSvc.PlayerOwnsGamePass(Player, "UpgradeDailyQuests")`.
  2. Nếu RAM cache chưa có, `ShopService` sẽ gọi `MarketplaceService:UserOwnsGamePassAsync`, đây là **hàm bất đồng bộ (Yielding Call)**!
  3. Trong khi luồng đang yield chờ HTTP response từ Roblox, điều kiện `ResetsUsed >= MaxResets` **CHƯA ĐƯỢC KIỂM TRA** và biến `ResetsUsed` **CHƯA ĐƯỢC TĂNG**.
  4. `ClaimQuest` cũng gặp tình trạng tương tự nếu mở rộng các hàm yield khi xử lý phần thưởng.
- **Kịch bản khai thác / Hậu quả thực tế**:
  Hacker kích hoạt 5 thread gọi `RequestResetDailyQuests` cùng 1 thời điểm. Cả 5 thread đều vượt qua bước kiểm tra sở hữu GamePass cùng lúc và reset nhiệm vụ 5 lần liên tục trong ngày, phá vỡ giới hạn `MaxResets = 1`.
- **Đề xuất giải pháp chuẩn**:
  Sử dụng cơ chế Mutex Lock theo từng người chơi:
  ```lua
  if _PlayerActionLocks[Player] then return { Success = false, Reason = "BUSY" } end
  _PlayerActionLocks[Player] = true
  -- Xử lý...
  _PlayerActionLocks[Player] = nil
  ```

---

#### 5. Cướp Session Lock rủi ro bằng `"ForceLoad"` tại `DataService`
- **Vị trí**: [`DataService.lua:121-126`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L121-L126)
- **Mức độ**: `CRITICAL`
- **Hiện trạng & Vấn đề**:
  `PlayerStore:LoadProfileAsync(("Player_%d"):format(Player.UserId), "ForceLoad")`.
  Theo tài liệu chính thức của ProfileService, `"ForceLoad"` sẽ bỏ qua session lock và giải phóng quyền sở hữu của session cũ. Nếu người chơi vừa thoát khỏi một server khác và server đó đang thực hiện tác vụ lưu cuối cùng (Final Save / Auto-save), việc cướp session lock ngay lập tức có thể dẫn đến **Data Overwrite / Rollback** (dữ liệu phiên cũ chưa kịp lưu đã bị phiên mới đè lên).
- **Đề xuất giải pháp chuẩn**:
  Sử dụng callback chuẩn của ProfileService với cơ chế retry có kiểm soát hoặc timeout thay vì ép buộc `"ForceLoad"` ngay lần gọi đầu tiên.

---

### 🟠 NHÓM 2: LỖI KIẾN TRÚC, MEMORY LEAK & EVENT LEAK (HIGH)

#### 6. Rò rỉ Model `IceBlock` trong Workspace khi Player thoát game
- **Vị trí**: [`FreezeService.lua:544-546`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua#L544-L546)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  ```lua
  Players.PlayerRemoving:Connect(function(Player)
      _iceBlocks[Player.UserId] = nil
  end)
  ```
  Khi một người chơi đang bị đóng băng (`Frozen`) thoát khỏi server, Server chỉ giải phóng tham chiếu trong bảng `_iceBlocks`, **HOÀN TOÀN KHÔNG GỌI `:Destroy()`** trên Model khối băng trong `workspace`!
- **Hậu quả thực tế**:
  Model khối băng (gồm nhiều BasePart, Mesh, Weld, Hitbox) sẽ bị bỏ rơi vĩnh viễn trong Workspace của server cho đến hết trận đấu. Nếu qua nhiều vòng đấu hoặc server chạy lâu dài, số lượng part rác này tích tụ gây rò rỉ RAM máy chủ và làm lag vật lý.
- **Đề xuất giải pháp chuẩn**:
  ```lua
  Players.PlayerRemoving:Connect(function(Player)
      local Block = _iceBlocks[Player.UserId]
      if Block then
          Block:Destroy()
      end
      _iceBlocks[Player.UserId] = nil
  end)
  ```

---

#### 7. Event Connection Leak trong `IcicleScript.client.lua`
- **Vị trí**: [`IcicleScript.client.lua:237-239`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua#L237-L239)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  Mỗi lần người chơi bấm chuột vung vũ khí (`Tool.Activated`):
  ```lua
  Track.Stopped:Connect(function()
      StopHitboxPoll()
  end)
  ```
  AnimationTrack `Track` được cache và tái sử dụng liên tục qua `_cachedSwingTracks`. Điều này đồng nghĩa với việc: **mỗi cú chém sẽ kết nối thêm một hàm ẩn danh mới vào sự kiện `Stopped` của cùng một Track mà không bao giờ ngắt kết nối!**
- **Hậu quả thực tế**:
  Sau 50 cú chém, một lần animation dừng sẽ kích hoạt 50 hàm callback cùng lúc. Sau 1000 cú chém, bộ nhớ client sẽ bị rò rỉ (closure leak) và gây giật khung hình mỗi khi hoàn tất animation.
- **Đề xuất giải pháp chuẩn**:
  Sử dụng `Track.Stopped:Once(...)` hoặc chỉ gán listener một lần duy nhất lúc tạo / cache AnimationTrack.

---

#### 8. Tụt FPS do lắng nghe `Workspace.ChildAdded` & `ChildRemoved` trên Client
- **Vị trí**: [`HighlightController.lua:316-326`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L316-L326)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  ```lua
  Workspace.ChildAdded:Connect(function(Child)
      if Child:IsA("Model") and PlayerStateHelper.GetVictimUserId(Child) ~= nil then
          RefreshAll()
      end
  end)
  ```
  Lắng nghe trên toàn bộ `Workspace`. Bất kỳ Instance nào sinh ra trong game (part hiệu ứng, âm thanh, mảnh vỡ) đều kích hoạt callback này. Hơn nữa, `RefreshAll()` duyệt qua toàn bộ người chơi trong server và cập nhật lại thuộc tính `Highlight`.
- **Hậu quả thực tế**:
  Khối băng đã được Server gán tag `TagConfig.Tags.IceBlock`, nhưng Client lại đi scan toàn bộ Workspace thay vì dùng `CollectionService`. Việc này làm tụt giảm FPS nghiêm trọng trong các pha giao tranh nhiều hạt/part.
- **Đề xuất giải pháp chuẩn**:
  Thay thế bằng `CollectionService:GetInstanceAddedSignal(TagConfig.Tags.IceBlock)` và `GetInstanceRemovedSignal`.

---

#### 9. Top-level Blocking: 23 lời gọi `WaitForChild` không timeout treo đứng Client
- **Vị trí**: [`GameStatisticController.lua:22-66`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua#L22-L66) và [`GameStateController.lua:22-27`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua#L22-L27)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  Có đến hơn 20 lời gọi `WaitForChild` **không có timeout** được đặt ngay ở phạm vi module top-level (ngoài hàm `Init`).
  Trong [`Main.client.lua:17-18`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Main.client.lua#L17-L18), khi `require(GameStateController)` hoặc `require(GameStatisticController)` được chạy, nếu giao diện chưa kịp replicate đầy đủ hoặc một part con bị designer đổi tên, **toàn bộ luồng khởi động Client sẽ bị treo vĩnh viễn tại dòng `require`**. 16 Controllers phía sau sẽ không bao giờ được nạp!
- **Đề xuất giải pháp chuẩn**:
  Chuyển toàn bộ việc resolve GUI vào bên trong hàm `Init()`, sử dụng `GuiHelper` với timeout an toàn.

---

#### 10. Lộ mã nguồn nhạy cảm và Admin ID tại `ReplicatedStorage`
- **Vị trí**: [`ReplicatedStorage/Shared/Config/AdminConfig.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/AdminConfig.lua) và [`ReplicatedStorage/Shared/Lib/ProfileService.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Lib/ProfileService.lua)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  1. `AdminConfig.lua` chứa danh sách User ID của Owner/Admin và tiền tố lệnh CLI, được đặt trong `ReplicatedStorage` nhưng **chỉ có duy nhất `AdminService.lua` (Server) sử dụng**. Bất kỳ client nào cũng đọc được danh sách Admin User ID này.
  2. `ProfileService.lua` là thư viện backend chỉ chạy trên Server, nhưng lại bị đặt trong `ReplicatedStorage/Shared/Lib/`.
- **Đề xuất giải pháp chuẩn**:
  Chuyển `AdminConfig.lua` và `ProfileService.lua` vào `ServerScriptService` hoặc `ServerStorage`.

---

#### 11. Race Condition khi người chơi rời server (`PlayerRemoving`)
- **Vị trí**: [`DataService.lua:135-143`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua#L135-L143) và [`QuestService.lua:647-662`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L647-L662)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  Cả `DataService` và `QuestService` đều kết nối sự kiện `Players.PlayerRemoving` một cách độc lập.
  Nếu `DataService.PlayerRemoving` chạy trước, nó gọi `Profile:Release()` và set `ActiveProfiles[Player] = nil`. Khi `QuestService.PlayerRemoving` chạy ngay sau đó để tính toán `DataService.AddPlayTime(Player, SessionSeconds)`, hàm `AddPlayTime` sẽ thất bại vì `Profile` đã bị giải phóng!
- **Đề xuất giải pháp chuẩn**:
  Tập trung hóa vòng đời `PlayerRemoving` qua một Manager hoặc ServiceLoader duy nhất theo thứ tự ưu tiên (QuestService flush dữ liệu -> DataService mới release Profile).

---

#### 12. Xử lý lỗi thiếu `pcall` trong `MarketplaceService.ProcessReceipt`
- **Vị trí**: [`ShopService.lua:184-227`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/ShopService.lua#L184-L227)
- **Mức độ**: `HIGH`
- **Hiện trạng & Vấn đề**:
  Trong callback `ProcessReceipt`, các thao tác `DataService.AddMoney` và `DataService.RecordPurchase` không được bọc trong khối bảo vệ `pcall`. Nếu có bất kỳ lỗi runtime nào xảy ra giữa chừng, Roblox sẽ hiểu nhầm giao dịch bị lỗi và gọi retry liên tục, hoặc người chơi bị trừ Robux nhưng không được xác nhận mua hàng thành công.
- **Đề xuất giải pháp chuẩn**:
  Bọc toàn bộ logic cấp tiền và ghi biên lai vào `pcall`. Chỉ trả về `Enum.ProductPurchaseDecision.PurchaseGranted` khi `pcall` trả về `true`.

---

### 🟡 NHÓM 3: HARDCODE, CODE SMELL & BẤT ĐỒNG NHẤT CẤU TRÚC (MEDIUM)

#### 13. Debug Hack bỏ quên: Daily Quest reset mỗi 60 giây
- **Vị trí**: [`QuestConfig.lua:14`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/QuestConfig.lua#L14)
- **Mức độ**: `MEDIUM`
- **Hiện trạng**:
  `ResetSeconds = 60,--86400, -- Thời gian reset: 24 giờ (giây)`
  Một đoạn code vá tạm phục vụ việc test đã bị bỏ quên trong file cấu hình chính thức, làm toàn bộ nhiệm vụ hàng ngày của game reset liên tục sau mỗi 1 phút!
- **Đề xuất giải pháp chuẩn**:
  Khôi phục về giá trị chuẩn: `ResetSeconds = 86400`.

---

#### 14. Bất đồng nhất Kiến trúc Lifecycle giữa Client và Server
- **Vị trí**: Toàn bộ [`Main.server.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Main.server.lua) vs [`Main.client.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Main.client.lua)
- **Mức độ**: `MEDIUM`
- **Hiện trạng**:
  - Phía **Server**: Có `ServiceLoader.lua` quản lý 2 pha chuẩn chỉnh: `Init()` rồi mới đến `Start()`.
  - Phía **Client**: Không có `ControllerLoader`! `Main.client.lua` phải require thủ công 24 Controllers và **chỉ gọi duy nhất `Init()` mà không có pha `Start()`**.
  - Kết quả: Các Controller khi cần gọi nhau trong lúc khởi động buộc phải dùng cơ chế `GetMenuController()` hoặc `GetNavigationController()` (lazy-require chắp vá) ở khắp các file để tránh lỗi module chưa sẵn sàng.
- **Đề xuất giải pháp chuẩn**:
  Tạo `ControllerLoader.lua` tương tự `ServiceLoader.lua`, duyệt tự động toàn bộ Controller trong folder, gọi `Init()` cho tất cả, sau đó mới gọi `Start()`.

---

#### 15. Vi phạm nghiêm trọng triết lý "Zero Hardcode"
- **Vị trí**: Rải rác trong nhiều module:
  - [`HighlightController.lua:22-25`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua#L22-L25): Hardcode trực tiếp màu sắc `Color3.fromRGB(220, 50, 50)`, `Color3.fromRGB(50, 120, 220)`.
  - [`ShopController.lua:211-212`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua#L211-L212): Hardcode màu tab `Color3.fromHex("FFFFFF")`, `Color3.fromHex("2F2F2F")`.
  - [`InventoryController.lua:351-356`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua#L351-L356): Hardcode lặp lại mã màu hex.
  - [`QuestService.lua:174, 231`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/QuestService.lua#L174): Hardcode giá hoàn tiền mặc định `1000`.
  - [`MatchService.lua:647`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L647): Hardcode offset teleport `Vector3.new(0, 4, 0)`.
  - [`HotbarController.lua:24-34`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua#L24-L34): Hardcode bảng phím số `SLOT_KEY_CODES` trong controller.
- **Đề xuất giải pháp chuẩn**:
  Đưa toàn bộ các giá trị này về các file cấu hình tương ứng trong `ReplicatedStorage/Shared/Config/`.

---

#### 16. Vi phạm quy ước dự án: Sử dụng tràn lan `_camelCase`
- **Vị trí**: Toàn bộ codebase (đã liệt kê ở phần phân tích).
- **Mức độ**: `MEDIUM`
- **Hiện trạng**:
  Quy ước dự án bắt buộc: *"100% PascalCase và sử dụng tiếng Anh cho mọi biến và hàm"*.
  Tuy nhiên, codebase đang sử dụng hỗn loạn các biến private bắt đầu bằng dấu gạch dưới và chữ thường: `_iceBlocks`, `_playerStates`, `_isMatchActive`, `_currentPhase`, `_targetList`, `_localData`... đồng thời xen lẫn với các biến `_PascalCase` (`_InGameGui`, `_HotbarFrame`).
- **Đề xuất giải pháp chuẩn**:
  Chuẩn hóa toàn bộ biến private nội bộ thành `PascalCase` thuần túy (hoặc `_PascalCase` nếu muốn đánh dấu private, nhưng phải viết hoa chữ cái đầu tiên: `_IceBlocks`, `_PlayerStates`, `_IsMatchActive`).

---

#### 17. Client tự suy đoán logic Team của Server (`Duct-tape Logic`)
- **Vị trí**: [`SpectateController.lua:564`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua#L564)
- **Mức độ**: `MEDIUM`
- **Hiện trạng**:
  ```lua
  _hasTeams = (Data.PlayerStatusType ~= "Disabled") and (Data.HighlightMode ~= "FFA")
  ```
  Client phải chắp vá bằng cách so sánh 2 chuỗi hiển thị để tự đoán xem vòng đấu có chia đội hay không.
- **Đề xuất giải pháp chuẩn**:
  Server trong `MatchService` và `SetGameMode` RemoteEvent phải gửi trực tiếp cờ boolean `HasTeams = Mode.HasTeams`.

---

### 🟢 NHÓM 4: CODE THỪA & TỐI ƯU NHỎ (LOW)

#### 18. File rỗng không sử dụng: `InventoryConfig.lua`
- **Vị trí**: [`ReplicatedStorage/Shared/Config/InventoryConfig.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/InventoryConfig.lua)
- **Mức độ**: `LOW`
- **Hiện trạng**: File chỉ chứa một bảng rỗng `local InventoryConfig = {}` và không có bất kỳ script nào trong dự án require tới (Dead Code).

#### 19. Lạm dụng `task.wait()` mù quáng
- **Vị trí**: [`MatchService.lua:457, 655, 776`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua#L457)
- **Mức độ**: `LOW`
- **Hiện trạng**: Dùng `task.wait(0.5)`, `task.wait(0.2)`, `task.wait(2)` để "chờ map load" hoặc "chờ physics ổn định" thay vì dùng Signal/Event xác thực khi hoàn tất.

#### 20. Khởi tạo Instance tại Module Scope trong `MusicController`
- **Vị trí**: [`MusicController.lua:44-49`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua#L44-L49)
- **Mức độ**: `LOW`
- **Hiện trạng**: Tạo ngay `Sound` instance và gán vào `SoundService` ngay khi module được `require`, vi phạm tính độc lập của hàm `Init()`.

#### 21. Sử dụng API lỗi thời `Player.Chatted`
- **Vị trí**: [`AdminService.lua:428, 436`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/AdminService.lua#L428)
- **Mức độ**: `LOW`
- **Hiện trạng**: `Player.Chatted` không hoạt động trên hệ thống chat mới (`TextChatService`). Cần hỗ trợ cả `TextChatService` để đảm bảo lệnh CLI hoạt động trên mọi place hiện đại.

---

## 3. DANH SÁCH CÁC ĐIỂM MÂU THUẪN CẦN PHẢN BIỆN (DEBATE LIST)

Dưới đây là các mâu thuẫn kiến trúc cốt lõi mà lập trình viên cần làm rõ và đưa ra quyết định:

### 🥊 Mâu thuẫn 1: Client-Side Hit Detection vs 100% Server Authority
- **Thực trạng**: Hiện tại, client chạy `GetPartsInPart(Hitbox)` rồi gửi tên nạn nhân lên server qua `OnToolHit`. Server tin tưởng client đến 90% (chỉ check cự ly `Distance < HitboxRange * 1.5`).
- **Xung đột**:
  - Nếu chuyển hoàn toàn việc tính toán Hitbox sang Server: Sẽ chống hack triệt để 100%, nhưng người chơi bị ping cao (>100ms) sẽ cảm thấy đánh trúng nhưng không có hiệu ứng (Hit-reg delay/Ghost swing).
  - Nếu giữ nguyên Client-Side Detection: Bắt buộc Server phải có bộ lọc xác thực tối thiểu: (1) Check Line of Sight bằng Raycast, (2) Check Tool Equipped trên nhân vật, (3) Check Server Attack Cooldown.
- **Câu hỏi cho bạn**: Bạn muốn dự án đi theo hướng **Server-Assisted Client Hitreg** (Client tính, Server kiểm tra nghiêm ngặt bằng Raycast + Cooldown) hay **100% Server Hitreg**?

### 🥊 Mâu thuẫn 2: Kiến trúc Quản lý Vòng đời Client (Client Lifecycle)
- **Thực trạng**: Server dùng `ServiceLoader` 2-phase (`Init()` rồi `Start()`), nhưng Client lại không có loader, khởi tạo 1 phase thủ công trong `Main.client.lua`. Đồng thời, các Controller lại resolve GUI bằng `WaitForChild` ngay ở module top-level scope.
- **Xung đột**: Các Controller phụ thuộc lẫn nhau (`MenuController`, `NavigationController`, `ShopController`, `QuestController`) đang phải dùng kỹ thuật lazy-require `GetMenuController()` bên trong từng hàm để né lỗi circular dependency.
- **Câu hỏi cho bạn**: Có đồng ý xây dựng một `ControllerLoader.lua` đồng nhất cho Client theo chuẩn 2-phase (`Init()` -> `Start()`), đồng thời cấm 100% việc gọi `WaitForChild` hoặc tạo Instance ngoài phạm vi hàm lifecycle không?

### 🥊 Mâu thuẫn 3: Vị trí của `ProfileService.lua` và `AdminConfig.lua`
- **Thực trạng**: Cả 2 file đều nằm trong `ReplicatedStorage/Shared/`, khiến Roblox tự động replicate toàn bộ mã nguồn lưu trữ và bảng phân quyền User ID của Admin xuống máy của mọi người chơi (kể cả kẻ khai thác).
- **Phản biện**: Nguyên tắc bảo mật Roblox là không bao giờ để lộ logic Server-Only hoặc danh tính Owner/Admin ở `ReplicatedStorage`.
- **Câu hỏi cho bạn**: Có đồng ý di chuyển `ProfileService.lua` và `AdminConfig.lua` ra khỏi `ReplicatedStorage` để đưa vào `ServerScriptService` (hoặc `ServerStorage`) nhằm bảo toàn nguyên tắc an ninh không?