# ProgressionAndEconomy
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống tiến trình người chơi và kinh tế (Kinh tế & Thưởng trận đấu, Spree Streak, Nhiệm vụ Objective Engine 2.0, Hiệu ứng Mở rương, Phần thưởng Đa hình, Nhiệm vụ Lặp Vô hạn và Đồng bộ Dữ liệu).
> Cập nhật lần cuối: 01-09-2026

---

## Kiến trúc

### 1. Tập trung hóa Kinh tế & Phần thưởng qua EconomyConfig & RewardHelper
- **Chi tiết:** Tách toàn bộ giá trị thưởng (Freeze, Thaw, Freezing/Thawing Spree, First Blood, Last Standing, Win, Lose) và mốc Spree Threshold khỏi `GameConfig` sang `EconomyConfig` độc lập.
- **RewardHelper Engine:** Đóng gói các công thức tính thưởng (tính BaseReward + SpreeBonus theo chuỗi streak), kiểm tra First Blood, thưởng kết thúc trận và hàm đồng bộ tiền `RewardAndSync(Player, Amount, DataService, UpdateMoneyEvent)`. Giúp `FreezeService`, `MatchService`, `GameStatisticController` đọc và trao thưởng thống nhất mà không duplicate logic.
- **File liên quan:** [EconomyConfig.lua](../../src/ReplicatedStorage/Shared/Config/EconomyConfig.lua), [RewardHelper.lua](../../src/ReplicatedStorage/Shared/Tools/RewardHelper.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 2. Cơ chế Spree Streak Độc Lập Khuyến Khích Tinh Thần Đồng Đội
- **Chi tiết:** Chuỗi Freezing Spree và Thawing Spree được quản lý hoàn toàn độc lập. Hành động đóng băng kẻ địch không làm reset chuỗi giải cứu của người chơi đó, và ngược lại.
- **Điều kiện Reset Streak:** Streak chỉ bị reset khi: (1) Bản thân đạt đủ mốc `EconomyConfig.Spree.Threshold` để nhận thưởng Spree Bonus (tính qua `RewardHelper`), hoặc (2) Bản thân người chơi bị đối thủ đóng băng (`Victim`).
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [RewardHelper.lua](../../src/ReplicatedStorage/Shared/Tools/RewardHelper.lua)

### 3. Kiến trúc Objective Engine 2.0 & Event-Driven Quest Dispatcher
- **Chi tiết:** Thay thế hoàn toàn cơ chế lấy hiệu số snapshot trọn đời (`CurrentStat - BaseProgress`) bằng mô hình hướng sự kiện (Event-Driven). Gameplay Services (`FreezeService`, `MatchService`, `ShopService`) chỉ phát sự kiện qua `QuestService.DispatchEvent(Player, EventName, EventData)`.
- **4 Loại Objective Chuẩn Hóa:**
  - `InMatchCounter`: Yêu cầu đạt số lượng trong **duy nhất 1 trận** (vd: Freeze 10 người trong 1 trận).
  - `Accumulative`: Tích lũy cộng dồn qua nhiều trận kèm điều kiện lọc `Conditions` (vd: Thaw 3 đồng đội trong FrozenState, Open 2 Chests).
  - `MatchCondition`: Điều kiện kết thúc trận (vd: Thắng mode Chaos, thắng khi là Last Standing).
  - `LifetimeStat`: Dựa trên DataStore/Thời gian chơi (vd: PlayTime 30 phút).
- **File liên quan:** [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 4. Quản lý Tiến Trình RAM Theo Trận Đấu & Lưu Trữ Bền Vững QuestData
- **Chi tiết:** Tách biệt 2 tầng lưu trữ dữ liệu nhiệm vụ:
  - *Tầng RAM In-Match (`_matchProgress[Player][QuestId]`)*: Đếm tiến trình tạm thời của `InMatchCounter`. Nếu kết thúc trận mà chưa đạt $\ge \text{Requirement}$, bộ đếm tự hủy về 0 mà không ghi vào DataStore.
  - *Tầng Bền Vững (`QuestData`)*: Lưu trực tiếp `{ Progress, Completed, Claimed }` trong `PROFILE_TEMPLATE` của ProfileService cho các quest `Accumulative` và `Milestone`.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### 5. Theo dõi PlayTime Tối Giản Hiệu Năng Thời Gian Thực
- **Chi tiết:** Server lưu thời điểm join (`_sessionStart`). Khi tính toán tiến trình cho `PlayTime`, Server tự động cộng thêm thời gian session hiện tại:
  $$\text{PlayTime} = \text{Data.PlayTime} + (\text{os.time}() - \text{\_sessionStart}[Player])$$
- Khi người chơi rời game (`PlayerRemoving`), Server mới ghi giá trị này vào DataStore để lưu trữ bền vững, tránh spam ghi DataStore liên tục.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### 6. Module Độc Lập ItemRewardController & Reward-First Pattern
- **Chi tiết:** Toàn bộ logic hiệu ứng mở rương được đặt trong `ItemRewardController.lua` riêng biệt thay vì gộp vào ShopController:
  - `ShowChestReward(ReceivedItems, ChestId)`: Chạy Pha 1 (hiệu ứng rương + click x3) + Pha 2 (bung nở hiển thị item).
  - `ShowItemReward(Items)`: Bỏ qua Pha 1, vào thẳng Pha 2 — dùng khi nhận item trực tiếp từ quest hoặc sự kiện.
- **Reward-First Pattern:** Server trao vật phẩm/tiền ngay khi nhận yêu cầu mua rương, **TRƯỚC** khi Client kích hoạt hiệu ứng. Nếu người chơi thoát giữa chừng hoặc vào trận đấu, vật phẩm vẫn an toàn tuyệt đối do đã được ghi nhận ở Server.
- **File liên quan:** [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua)

### 7. Cơ chế Yielding Sẵn Sàng Dữ Liệu & Reactive Signal Đồng Bộ Hai Đầu (Data Readiness Engine & OnDataLoaded Signal)
- **Chi tiết:**
  - *Server-Side Yielding (`WaitForProfile` / `WaitForData`)*: Thay vì trả về `nil` khi `ProfileStore:LoadProfileAsync` đang nạp, `DataService` sử dụng `_ProfileLoadedBindable` yield an toàn theo `DataConfig.ProfileLoadTimeout` và tự hủy chờ nếu player rời server (`PlayerRemoving`). `GetPlayerDataFn.OnServerInvoke` luôn đảm bảo 100% dữ liệu sẵn sàng trước khi phản hồi.
  - *Client-Side Reactive Signal (`OnDataLoaded` / `WaitForData`)*: `PlayerDataController` cung cấp Signal `OnDataLoaded(Callback)` (gọi callback tức thì nếu đã có dữ liệu trong cache, hoặc lắng nghe khi dữ liệu về) và cơ chế tự động thử lại `FetchDataFromServer` tối đa `DataConfig.MaxLoadRetries` lần.
  - *Triệt tiêu Polling*: Các controller phụ thuộc (`SettingController`) loại bỏ hoàn toàn polling `task.wait()` và chuyển sang đăng ký sự kiện hướng dữ liệu (Event-Driven).
- **File liên quan:** [DataConfig.lua](../../src/ReplicatedStorage/Shared/Config/DataConfig.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [SettingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua)

### 8. Kiến trúc Xử lý Giao dịch Robux, Chống Lặp Idempotency & Đồng Bộ Giá Khu Vực (Managed Pricing Engine)
- **Chi tiết:** Triển khai hệ thống bán vật phẩm/tiền tệ bằng Robux (Developer Products) tuân thủ tiêu chuẩn an toàn và tối ưu hóa doanh thu toàn cầu của Roblox:
  - *Cấu hình tập trung:* Khai báo toàn bộ gói trong `ProductConfig.lua` (`ProductId`, `DisplayName`, `RobuxPrice`, `CurrencyAmount`), cung cấp helper `GetPackageByProductId` tra cứu tức thì.
  - *Idempotency chống cộng trùng tiền:* Lưu mảng `PurchaseHistory` trong Profile DataStore. Khi `MarketplaceService.ProcessReceipt` được gọi, kiểm tra `DataService.HasProcessedPurchase` trước khi cộng tiền để chống lỗi mạng gửi lặp biên lai.
  - *Kiểm soát nạp dữ liệu:* Chờ Profile sẵn sàng qua `DataService.WaitForProfile(Player)`. Nếu người chơi rời server hoặc Profile chưa tải xong, trả về `NotProcessedYet` để Roblox tự động retry khi người chơi quay lại.
  - *Dynamic Regional Pricing & Cache Engine:* Hỗ trợ tính năng Managed Pricing (giá theo khu vực). Client áp dụng cơ chế *Fallback-First* (hiển thị ngay giá config $0\text{ms}$) kết hợp *In-Memory Cache* (`_ProductInfoCache`) và chạy ngầm `MarketplaceService:GetProductInfo` để lấy `PriceInRobux` thực tế, cập nhật in-place mà không gây nghẽn mạng hay dính Rate-limit HTTP 429.
- **File liên quan:** [ProductConfig.lua](../../src/ReplicatedStorage/Shared/Config/ProductConfig.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### 9. Kiến trúc Quản trị CLI Server-Authority & Đồng Bộ Dữ Liệu Hai Đầu (Admin CLI & Realtime Data Sync Engine)
- **Chi tiết:** Triển khai hệ thống điều hành và can thiệp dữ liệu người chơi qua dòng lệnh Chat CLI với quyền lực 100% thuộc Server (`Server Authority`):
  - *Bảo mật Zero-Remote:* Tuyệt đối không tạo RemoteEvent/RemoteFunction thực thi lệnh từ Client. Lắng nghe trực tiếp sự kiện `Player.Chatted` trên Server và xác thực `AdminConfig.IsAdmin(Player)` bằng `Player.UserId` hoặc môi trường Studio.
  - *Mở rộng API Can Thiệp 2 Chiều (`DataService`):* Cung cấp đầy đủ các phương thức `SetMoney`, `SetStat`, `RemoveIcicle`/`RemoveBlock`, `ClearSkins`, `GiveAllSkins`, `ResetProfileData`, `ClearPurchaseHistory`.
  - *Realtime Push-Sync (`SyncPlayerData`):* Khi Admin chỉnh sửa dữ liệu của mục tiêu (hoặc bản thân), Server đẩy toàn bộ dữ liệu mới nhất qua RemoteEvent `SyncPlayerData` kèm `UpdateMoney`. `PlayerDataController` cập nhật lại cache nội bộ và phát signal cho toàn bộ hệ thống UI cập nhật tức thì mà không cần rejoin.
  - *Audit Logging:* Ghi vết minh bạch mọi lệnh thực thi (Admin Name, UserId, Command, Arguments, Result) trên Server console.
- **File liên quan:** [AdminConfig.lua](../../src/ReplicatedStorage/Shared/Config/AdminConfig.lua), [AdminService.lua](../../src/ServerScriptService/Services/AdminService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [RemoteDefinitions.lua](../../src/ReplicatedStorage/Shared/Remotes/RemoteDefinitions.lua), [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua)

### 10. Nguyên Tắc Toàn Vẹn Số Nguyên Tiền Tệ & Cơ Chế Làm Tròn Chuẩn (Integer Integrity & Standard Rounding Pattern)
- **Chi tiết:** Dữ liệu tiền tệ (`Money`, `Cash`) lưu trong DataStore và xử lý trên Server **luôn luôn phải là số nguyên (Integer)** nhằm triệt tiêu hoàn toàn lỗi trôi dạt dấu chấm động (Floating-point Precision Issue) và đảm bảo tính chính xác khi so sánh điều kiện giao dịch (`Money >= Price`).
- **Standard Rounding Engine (`math.round`):** Khi tính toán các tỷ lệ phần trăm kinh tế (ví dụ: hoàn tiền khi mua trùng skin theo công thức $\text{RefundBasePrice} \times \text{RarityEntry.RefundPercent}$), Server sử dụng `math.round()` thay vì `math.floor()`. Điều này thực thi quy tắc làm tròn chuẩn ($\ge 0.5$ làm tròn lên, $< 0.5$ làm tròn xuống), vừa đảm bảo quyền lợi công bằng cho người chơi vừa bảo toàn dữ liệu số nguyên tuyệt đối.
- **File liên quan:** [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [RarityConfig.lua](../../src/ReplicatedStorage/Shared/Config/RarityConfig.lua), [EconomyConfig.lua](../../src/ReplicatedStorage/Shared/Config/EconomyConfig.lua)

### 11. Hệ Sinh Thái Phần Thưởng Đa Hình & Quy Tắc Mở Nhiều Rương Nhận X Vật Phẩm (Polymorphic Rewards & Single-Open Multi-Draw Pattern)
- **Chi tiết:** Chuẩn hóa phần thưởng nhiệm vụ hỗ trợ 3 loại vật phẩm đơn nhất (`Money`, `Chest`, `Item`):
  - *Quy tắc Mở Nhiều Rương ($X$ Chests)*: Server rút thăm $X$ lần dựa trên drop rate của `ChestConfig` (tự động hoàn tiền qua `RarityConfig` nếu trùng), Client kích hoạt `ItemRewardController.ShowChestReward` chạy animation mở rương **1 lần duy nhất** và bung nở hiển thị đồng thời $X$ thẻ bài.
  - *Phần thưởng Item*: Trao trực tiếp qua `DataService.AddIcicle` / `AddBlock` (hoàn tiền nếu đã sở hữu), Client kích hoạt `ItemRewardController.ShowItemReward`.
- **File liên quan:** [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### 12. Cơ Chế Nhiệm Vụ Lặp Lại Vô Hạn & Bảo Lưu Tiến Trình Dôi Dư (Infinite Repeatable Quests & Excess Progress Retention Pattern)
- **Chi tiết:** Thiết lập cờ `Repeatable = true` trong `QuestConfig` cho phép nhiệm vụ lặp lại vô hạn chu kỳ ngay sau khi nhận thưởng:
  - *Duy trì trạng thái cày:* Server không gán `Claimed = true` vĩnh viễn, mà giữ `Claimed = false` sau mỗi lần claim thành công.
  - *Bảo lưu tiến trình dôi dư (Excess Progress Retention):* Khi nhận thưởng, hệ thống chỉ trừ đi đúng mức yêu cầu:
    $$\text{Progress mới} = \max(0, \text{Progress cũ} - \text{Requirement})$$
    *(Ví dụ: Người chơi đạt $65/50$, sau khi claim sẽ còn $15/50$ cho chu kỳ tiếp theo thay vì bị reset về $0$).*
  - *Liên tục cộng dồn:* `DispatchEvent` vẫn cho phép tiếp tục tích lũy tiến trình vượt quá `Requirement` kể cả khi người chơi chưa kịp bấm nhận thưởng.
- **File liên quan:** [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Triệt Tiêu Hoàn Toàn Polling 1s và Đồng Bộ Dữ Liệu Quest Theo Nhu Cầu (Zero-Polling Event-Driven Quest Sync)
- **Vấn đề:** Thiết kế cũ dùng vòng lặp polling 1s/lần (`_autoRefreshTask`) khi mở GUI Quest gây spam RemoteFunction `GetQuestData`, làm nghẽn băng thông và lãng phí CPU server.
- **Giải pháp:**
  1. *Fetch on Demand*: Client chỉ gọi `GetQuestData` **1 lần duy nhất** khi mở menu (`OpenQuest`) hoặc khi bấm chuyển tab.
  2. *Local Countdown*: Bộ đếm thời gian reset chu kỳ tự chạy bằng `os.time()` ở local client, không gửi request mạng.
  3. *In-Match Notification*: Khi hoàn thành nhiệm vụ giữa trận, Server chủ động bắn RemoteEvent `NotifyAccoladeEvent` chúc mừng tức thì mà không cần client refresh lại toàn bộ danh sách quest.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

### 2. Chỉ số Profile & Inventory Không Cập Nhật Sau Khi Kết Thúc Trận Đấu (Lỗi Cache Tĩnh)
- **Vấn đề:** Khi người chơi có thêm chiến thắng hoặc đóng băng/giải cứu trong trận, các chỉ số trong Profile không thay đổi khi mở lại ở Sảnh.
- **Nguyên nhân:** Client lưu trữ cache tĩnh `_localData` tại `PlayerDataController` và chỉ load một lần lúc vào game. Khi trận kết thúc, Server chỉ đồng bộ sự kiện cập nhật tiền chứ không tự động replicate toàn bộ stat profile.
- **Giải pháp:** Bổ sung hàm `PlayerDataController.RefreshData()` kéo dữ liệu mới từ Server, đồng thời gọi bất đồng bộ hàm này mỗi khi mở tab Profile hoặc Inventory.
- **File liên quan:** [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### 3. Kích thước RewardAnnouncement Không Thay Đổi Theo Thiết Kế trong Studio
- **Vấn đề:** Thay đổi kích thước `RewardAnnouncement` trong Studio không có tác dụng — animation luôn zoom đến một kích thước cố định.
- **Nguyên nhân:** Thuộc tính `TargetSize` trong code bị hardcode là `UDim2.fromScale(0.4, 0.15)` thay vì đọc từ thuộc tính `Size` của GUI instance.
- **Giải pháp:** Lưu `_rewardOriginalSize = _rewardAnnouncement.Size` trong `Init()` trước khi ẩn element. Hàm animation sử dụng `_rewardOriginalSize` làm `TargetSize`.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### 4. Lỗi Race Condition Khi Khởi Động Client Khiến Dữ Liệu Trả Về `nil` và Mất Đồng Bộ Sound Setting
- **Vấn đề:** Khi vào game (đặc biệt trong Studio solo Play), client nhận cảnh báo `[PlayerDataController] InvokeServer thất bại: nil` (>90%), số tiền không hiện, và slider Setting bị kẹt ở mức mặc định (100% / nấc 11) do vòng lặp polling 5s bị timeout trước khi dữ liệu kịp về.
- **Nguyên nhân:**
  1. Server nhận `GetPlayerData:InvokeServer()` trong lúc `LoadProfileAsync` đang chạy, `ActiveProfiles[Player]` còn `nil` và Server lập tức trả về `nil` mà không yield chờ.
  2. `PlayerDataController` chỉ gọi một lần trong `Init()`, không retry khi nhận `nil` và không có cơ chế phát tín hiệu cho các controller khác.
  3. `SettingController` chỉ đợi tối đa 5s rồi dừng hoàn toàn, không có listener khi data về sau đó.
- **Giải pháp:**
  1. Phía Server: `DataService.WaitForData(Player)` yield chờ `_ProfileLoadedBindable` nạp xong mới trả kết quả.
  2. Phía Client: `PlayerDataController` quản lý retry theo `DataConfig` và kích hoạt `OnDataLoaded`. `SettingController` lắng nghe `OnDataLoaded` kèm cờ `_HasUserModifiedSettings` để đồng bộ âm lượng tức thì mà không bị ghi đè.
- **File liên quan:** [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [SettingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua), [DataConfig.lua](../../src/ReplicatedStorage/Shared/Config/DataConfig.lua)

### 5. Nguy Cơ Nhân Đôi Tiền Tệ Do Roblox Retry Giao Dịch Khi Mạng Lag (Receipt Replay Vulnerability)
- **Vấn đề:** Khi mạng chập chờn hoặc server phản hồi chậm, Roblox có thể gửi lại cùng một `ReceiptInfo` nhiều lần. Nếu server chỉ đơn thuần cộng tiền rồi trả về `PurchaseGranted`, người chơi sẽ nhận được gấp nhiều lần số tiền đã mua mà chỉ tốn một lần Robux.
- **Nguyên nhân:** Thiếu cơ chế lưu vết `PurchaseId` (Idempotency) trên DataStore của người chơi.
- **Giải pháp:**
  1. Thêm trường `PurchaseHistory = {}` vào `PROFILE_TEMPLATE` của ProfileService.
  2. Bổ sung 2 helper `DataService.HasProcessedPurchase(Player, PurchaseId)` và `DataService.RecordPurchase(Player, PurchaseId)`.
  3. Trong `ProcessReceipt`, kiểm tra `HasProcessedPurchase` đầu tiên: nếu `true`, bỏ qua bước cộng tiền và trả ngay `PurchaseGranted`.
- **File liên quan:** [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua)

### 6. Lệch Giá Giữa UI Game và Popup Mua Roblox Do Tính Năng Managed Pricing (Regional Pricing Divergence)
- **Vấn đề:** Khi bật tính năng Managed Pricing trên Roblox Creator Dashboard, giá sản phẩm tự động điều chỉnh theo sức mua khu vực (ví dụ: từ 100 Robux giảm còn 40 Robux tại Việt Nam). Nếu Client chỉ hiển thị giá tĩnh từ file config, người chơi sẽ thấy giá trên nút bấm và giá trên bảng xác nhận Native của Roblox bị lệch nhau.
- **Nguyên nhân:** Roblox định giá động tại runtime dựa trên vị trí địa lý của người chơi gọi request.
- **Giải pháp:**
  1. Áp dụng mô hình *Fallback-First*: Hiển thị tức thời giá config mặc định ($0\text{ms}$).
  2. Chạy luồng ngầm bất đồng bộ (`task.spawn` + `pcall`) gọi `MarketplaceService:GetProductInfo(ProductId, Enum.InfoType.Product)` để lấy `PriceInRobux` thực tế.
  3. Duy trì tầng cache `_ProductInfoCache` trong Client RAM để mỗi sản phẩm chỉ fetch một lần duy nhất, loại bỏ hoàn toàn nguy cơ nghẽn mạng và lỗi HTTP 429 Rate Limit khi chuyển tab.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ProductConfig.lua](../../src/ReplicatedStorage/Shared/Config/ProductConfig.lua)

### 7. Lỗi Logic Khi Thu Hồi Skin Đang Trang Bị và Fallback Tự Động (Equipped Item Invalidation)
- **Vấn đề:** Khi Admin dùng lệnh xóa skin (`/removeskin` hoặc `/clearskins`) của người chơi, nếu người chơi đó đang trang bị chính skin bị xóa (`EquippedIcicle` hoặc `EquippedIceBlock`), hệ thống vẫn giữ nguyên `Equipped` ID dẫn đến lỗi logic và crash khi spawn/render mô hình nhân vật trong trận.
- **Nguyên nhân:** Thiếu cơ chế kiểm tra và vô hiệu hóa trang bị khi mảng sở hữu (`OwnedIcicles`/`OwnedBlocks`) bị biến đổi.
- **Giải pháp:** Trong `DataService.RemoveIcicle`, `DataService.RemoveBlock` và `DataService.ClearSkins`, tích hợp cơ chế kiểm tra: Nếu skin bị xóa trùng khớp với `EquippedIcicle` hoặc `EquippedIceBlock`, tự động reset thuộc tính trang bị về `"Default"`, đồng thời đồng bộ lại toàn bộ dữ liệu về Client.
- **File liên quan:** [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [AdminService.lua](../../src/ServerScriptService/Services/AdminService.lua)

### 8. Rủi Ro Bảo Mật & Lỗ Hổng Từ Các Cơ Chế Thụ Động Tự Động Can Thiệp Dữ Liệu (Zero Implicit Side-Effects)
- **Vấn đề:** Các ý tưởng thiết kế tự động quét sự hiện diện của Admin ở cuối trận hoặc trong phòng chơi để tự động can thiệp dữ liệu tiềm ẩn nguy cơ bị hacker khai thác giả lập presence hoặc gây rối loạn luồng gameplay chính.
- **Nguyên nhân:** Các cơ chế tự động tương tác ngầm (implicit side-effects) phụ thuộc vào sự kiện gameplay chung làm phân mảnh quyền kiểm soát và dễ phát sinh lỗ hổng.
- **Giải pháp:** Áp dụng nguyên tắc *Explicit Command-Driven*: Loại bỏ 100% các hook thụ động trong vòng đời trận đấu. Mọi thao tác can thiệp dữ liệu (tiền, stats, skin, reset, ban/kick) phải do Admin chủ động gõ lệnh trực tiếp qua CLI với đầy đủ Server-side Validation và Audit Log.
- **File liên quan:** [AdminService.lua](../../src/ServerScriptService/Services/AdminService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [AdminConfig.lua](../../src/ReplicatedStorage/Shared/Config/AdminConfig.lua)

### 9. Rò Rỉ Bộ Nhớ RAM Từ Bộ Đếm In-Match và Giải Pháp Dọn Dẹp Vòng Đời Trận Đấu (In-Match RAM Lifecycle & Memory Leak Guard)
- **Vấn đề:** Bộ đếm `_matchProgress[Player]` lưu trong RAM server của `QuestService` có nguy cơ tích tụ rác bộ nhớ nếu người chơi thoát game giữa trận hoặc sau hàng trăm ván đấu liên tiếp.
- **Giải pháp:**
  1. Kết nối sự kiện `Players.PlayerRemoving` để giải phóng ngay lập tức bảng `_matchProgress[Player] = nil` khi người chơi rời game.
  2. `MatchService.RunSetup` chủ động gọi `QuestService.ResetMatchProgress()` khi bắt đầu ván mới để làm sạch toàn bộ dữ liệu trận trước.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 10. Xung Đột Schema Dữ Liệu Quest Cũ-Mới và Cơ Chế Tự Động Chuyển Đổi (Safe DataStore Migration Pattern)
- **Vấn đề:** Người chơi cũ có Profile lưu dữ liệu `DailyQuestData` / `MilestoneQuestData` dạng cũ. Khi server nạp code mới, nếu truy cập thẳng vào `QuestData` sẽ bị crash do `nil indexing`.
- **Giải pháp:** Trong `DataService.OnProfileLoaded`, bổ sung bộ lọc kiểm tra: nếu `Profile.Data.QuestData == nil`, tự động khởi tạo cấu trúc `{ Daily = { ResetTimestamp, Quests = {} }, Milestone = { Quests = {} } }` kế thừa timestamp cũ trước khi gameplay truy cập.
- **File liên quan:** [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### 11. Kẹt Trạng Thái Claimed Khiến Nhiệm Vụ Milestone Biến Thành Nhiệm Vụ Một Lần (Repeatable Quest Lock Pitfall)
- **Vấn đề:** Khi claim nhiệm vụ, nếu server tự động gán `Claimed = true` và `DispatchEvent` chặn không cho cộng tiến trình cho các quest đã claim, toàn bộ nhiệm vụ Milestone sẽ bị biến thành nhiệm vụ 1 lần và khóa nút thành `"Claimed"`.
- **Giải pháp:** Phân nhánh xử lý theo cờ `ConfigEntry.Repeatable`:
  - Nếu `Repeatable == true` (Milestone): Trừ đúng mức `Requirement` khỏi `Progress`, giữ `Claimed = false` để tiếp tục chu kỳ cày mới, và cho phép `DispatchEvent` tiếp tục cộng dồn tiến trình kể cả khi vượt mốc.
  - Nếu `Repeatable == false` (Daily): Đánh dấu `Claimed = true` vĩnh viễn trong chu kỳ 24h.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)
