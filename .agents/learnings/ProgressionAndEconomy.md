# ProgressionAndEconomy
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống tiến trình người chơi và kinh tế (Kinh tế & Thưởng trận đấu, Spree Streak, Nhiệm vụ Objective Engine 2.0, Hiệu ứng Mở rương, Phần thưởng Đa hình, Nhiệm vụ Lặp Vô hạn, Mutex In-Flight Lock và Đồng bộ Dữ liệu).
> Cập nhật lần cuối: 03-09-2026

---

## Kiến trúc

### 1. Tập trung hóa Kinh tế & Phần thưởng qua EconomyConfig & RewardHelper
- **Chi tiết:** Tách toàn bộ giá trị thưởng (Freeze, Thaw, Freezing/Thawing Spree, First Blood, Last Standing, Win, Lose) và mốc Spree Threshold khỏi `GameConfig` sang `EconomyConfig` độc lập.
- **RewardHelper Engine:** Đóng vai trò Pure Shared Helper (tuyệt đối không require ngược vào `ServerScriptService`), đóng gói công thức tính thưởng, hàm đồng bộ tiền `RewardAndSync(Player, Amount, DataService, UpdateMoneyEvent, Multiplier)` nhận `Multiplier` trực tiếp từ caller trên Server, và cung cấp Single Source of Truth cho thuật toán bốc thăm ngẫu nhiên theo tỷ lệ rơi `RewardHelper.WeightedRandom(Items)`. Giúp `FreezeService`, `MatchService`, `ShopService`, `QuestService` đọc và xử lý thống nhất.
- **File liên quan:** [EconomyConfig.lua](../../src/ReplicatedStorage/Shared/Config/EconomyConfig.lua), [RewardHelper.lua](../../src/ReplicatedStorage/Shared/Tools/RewardHelper.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

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
  - *Server-Side Yielding (`WaitForProfile` / `WaitForData`)*: Thay vì polling `task.wait(0.05)` làm lãng phí CPU, `DataService.WaitForProfile` sử dụng mô hình Coroutine Event-Driven: `coroutine.yield()` lắng nghe `_ProfileLoadedBindable.Event`. Nếu `PlayerRemoving` xảy ra trước khi profile nạp xong, luồng hủy yield tức thì qua `Players.PlayerRemoving`; nếu quá hạn `DataConfig.ProfileLoadTimeout`, `task.delay` sẽ tự động dọn dẹp và resume `nil` an toàn. 100% 0ms độ trễ mạng thừa và 0% CPU rác.
  - *Client-Side Reactive Signal (`OnDataLoaded` / `WaitForData`)*: `PlayerDataController` cung cấp Signal `OnDataLoaded(Callback)` (gọi callback tức thì nếu đã có dữ liệu trong cache, hoặc lắng nghe khi dữ liệu về) và cơ chế tự động thử lại `FetchDataFromServer` tối đa `DataConfig.MaxLoadRetries` lần.
  - *Triệt tiêu Polling*: Toàn bộ hệ thống hai đầu Server-Client loại bỏ hoàn toàn polling `task.wait()` và chuyển 100% sang đăng ký sự kiện hướng dữ liệu (Event-Driven).
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

### 13. Kiến trúc GamePass Đa Quyền Lợi & Mô Hình Định Giá Động Khu Vực (GamePass Tiering & Regional Pricing Engine)
- **Chi tiết:** Phân tách hoàn toàn Developer Products (tiêu dùng nhiều lần, `Enum.InfoType.Product`, `PromptProductPurchase`, `ProcessReceipt`) và GamePasses (sở hữu vĩnh viễn, `Enum.InfoType.GamePass`, `PromptGamePassPurchase`, `UserOwnsGamePassAsync`):
  - *Cấu hình tập trung:* Khai báo GamePasses độc lập trong `ProductConfig.lua` (`DoubleMatchMoney`, `UpgradeDailyQuests`).
  - *UI Đồng bộ Giá Khu Vực:* `GamePassSection` tái sử dụng mô hình *Fallback-First* (hiển thị ngay giá tĩnh $0\text{ms}$) và tầng cache bộ nhớ `_ProductInfoCache` từ `CurrencySection` qua `MarketplaceService:GetProductInfo(..., Enum.InfoType.GamePass)`.
  - *Phân định Static Name vs Dynamic Price:* Giữ nguyên text tiêu đề (`NameText` / `FrameLabel`) được thiết kế sẵn trong Studio, chỉ cập nhật động giá tiền `AmountText` theo giá khu vực thực tế.
- **File liên quan:** [ProductConfig.lua](../../src/ReplicatedStorage/Shared/Config/ProductConfig.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [RewardHelper.lua](../../src/ReplicatedStorage/Shared/Tools/RewardHelper.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

### 14. Mô hình Cân Bằng GamePass: Nhân Tiền Hướng Mục Tiêu & Kích Hoạt Retention (Targeted Multipliers & Quest Restock Engine)
- **Chi tiết:** Thiết kế Gamepass tối ưu hóa cân bằng kinh tế và tăng tỷ lệ giữ chân (Retention):
  - *Gamepass 1 (`DoubleMatchMoney`):* Nhân đôi $2\times$ tiền thưởng trong trận đấu, bị khóa an toàn bởi thời lượng ván đấu ($2-3$ phút/trận) giúp tránh lạm phát kinh tế.
  - *Gamepass 2 (`UpgradeDailyQuests`):* Kết hợp bộ 3 đặc quyền: mở rộng $+2$ slots (tổng $7$ quests), thưởng thêm $+50\%$ tiền quest khi claim (`math.round(BaseAmount * 1.5)`), và cấp $1$ lượt Instant Full Restock mỗi $24\text{h}$ (`ResetsUsed < 1`).
  - *Tạo Động Lực Chiến Thuật:* Buộc người chơi đưa ra quyết định cày trọn $14$ nhiệm vụ/ngày ($\approx 2,100$ tiền) để tối ưu lợi nhuận, chuyển hóa trực tiếp thành thời gian chơi thực tế (Playtime).
- **File liên quan:** [ProductConfig.lua](../../src/ReplicatedStorage/Shared/Config/ProductConfig.lua), [EconomyConfig.lua](../../src/ReplicatedStorage/Shared/Config/EconomyConfig.lua), [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

### 15. Kiến trúc Mutex In-Flight Lock & Giao dịch Nguyên tử (Atomic In-Flight Mutex Pattern)
- **Chi tiết:** Mọi giao dịch kinh tế tiêu tốn tiền tệ hoặc yield bất đồng bộ qua mạng (`BuyChest`, `ResetDailyQuests`, `ClaimQuest`) bắt buộc phải bảo vệ bằng bảng khóa tạm thời theo người chơi:
  1. *In-Flight Mutex:* Tra cứu `_Locks[Player.UserId]`. Nếu đang bị khóa, trả về ngay `{ Success = false, Reason = "BUSY" }`.
  2. *Exception Safety (`pcall`):* Bọc toàn bộ khối kiểm tra điều kiện, trừ tiền/progress và trao thưởng trong `pcall` để đảm bảo cờ khóa luôn được giải phóng về `nil` ở cuối luồng kể cả khi phát sinh lỗi runtime ngoài ý muốn.
  3. *Lifecycle Guard:* Giải phóng toàn bộ lock trong `Players.PlayerRemoving` để tránh kẹt trạng thái vĩnh viễn khi người chơi thoát game đột ngột.
- **File liên quan:** [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

### 16. Vòng Đời Thoát Game Tập Trung & Đồng Bộ Tránh Race Condition (`BeforeProfileRelease`)
- **Chi tiết:** Roblox không bảo đảm thứ tự chạy giữa các kết nối `Players.PlayerRemoving` độc lập của các service khác nhau. Khi player thoát game, nếu `DataService` giải phóng Profile trước, `QuestService` sẽ ghi dữ liệu vào một profile đã giải phóng dẫn đến mất mát thời gian chơi (PlayTime) và tiến độ nhiệm vụ.
- **Giải pháp Kiến trúc:** `DataService` cung cấp `DataService.BeforeProfileRelease` (sử dụng `BindableEvent`). Trong `OnPlayerRemoving`, `DataService` phát sự kiện này **trước** khi gọi `Profile:Release()`. Do `BindableEvent:Fire` thực thi đồng bộ ngay lập tức, `QuestService` flush toàn bộ tiến trình vào DataStore một cách an toàn và bảo đảm 100% không mất dữ liệu.
- **File liên quan:** [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

### 17. Quản Lý Kích Thước Bền Vững & Hàng Đợi FIFO Cho Lịch Sử Giao Dịch (PurchaseHistory FIFO Queue)
- **Chi tiết:** Mỗi giao dịch Developer Product thành công được lưu `PurchaseId` vào mảng `PurchaseHistory` để đảm bảo tính Idempotent. Nếu không giới hạn kích thước mảng, một tài khoản nạp nhiều lần sẽ làm phình to DataStore vượt ngưỡng trần 4MB của Roblox.
- **Giải pháp Kiến trúc:** Cấu hình trần `MaxPurchaseHistorySize = 100` trong `DataConfig.lua`. Khi `RecordPurchase` thêm một ID mới, nếu độ dài vượt quá giới hạn, hệ thống tự động loại bỏ phần tử cũ nhất ở đầu mảng (`table.remove(list, 1)`) theo nguyên lý FIFO.
- **File liên quan:** [DataConfig.lua](../../src/ReplicatedStorage/Shared/Config/DataConfig.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

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

### 12. Nguy Cơ Lạm Phát Kinh Tế Từ Nhân Đôi Tiền Toàn Nguồn & Reset Nhiệm Vụ Vô Hạn (Compound Economy Inflation Guard)
- **Vấn đề:** Nếu nhân đôi $2\times$ từ mọi nguồn hoặc cho phép reset Daily Quest không giới hạn, người chơi sẽ kiếm được lượng tiền khổng lồ mỗi ngày mà không cần cày trận, phá vỡ giá trị của rương (Chest) và vô hiệu hóa các gói Robux Developer Products.
- **Nguyên nhân:** Không phân tầng nguồn thu nhập (Match Loop vs Quest Loop vs Milestone) và thiếu kiểm soát trần (Cap) chu kỳ nhiệm vụ.
- **Giải pháp:**
  1. Giới hạn $2\times$ chỉ áp dụng cho thu nhập trực tiếp trong trận đấu.
  2. Áp dụng hệ số tỷ lệ $+50\%$ thay vì cộng phẳng $+100$ tiền cho Daily Quest.
  3. Đặt Hard Cap $1$ lần Instant Restock/ngày, lưu trạng thái `ResetsUsed` trong `QuestData.Daily` và reset tự động cùng `ResetTimestamp`.
- **File liên quan:** [EconomyConfig.lua](../../src/ReplicatedStorage/Shared/Config/EconomyConfig.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua)

### 13. Phân Biệt Cơ Chế Kiểm Tra Quyền Sở Hữu GamePass Client-Server & Tránh Rate-Limit API (GamePass Ownership Cache & Verification)
- **Vấn đề:** Gọi `MarketplaceService:UserOwnsGamePassAsync` liên tục trong mỗi action gameplay (mỗi lần freeze/thaw hoặc mỗi trận) sẽ gây nghẽn mạng và dính lỗi Rate Limit HTTP 429 trên Server.
- **Giải pháp:** Tích hợp tầng cache trạng thái sở hữu GamePass trên Server khi người chơi join (`_gamePassCache[Player][PassId]`). Khi người chơi mua thành công trong game qua `PromptGamePassPurchaseFinished`, Server cập nhật cache ngay lập tức. Mọi kiểm tra thưởng $2\times$ hay $+50\%$ quest chỉ đọc từ RAM cache $0\text{ms}$.
- **File liên quan:** [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [RewardHelper.lua](../../src/ReplicatedStorage/Shared/Tools/RewardHelper.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

### 14. Bẫy Dữ Liệu Bảng Nhiệm Vụ Rỗng Khi Timestamp Chu Kỳ Còn Hiệu Lực (Empty Quest Table State Guard)
- **Vấn đề:** Nếu profile người chơi có `ResetTimestamp > 0` (do dữ liệu cũ, wipe test hoặc lỗi migration), nhưng bảng `DailyData.Quests` đang rỗng `{}` hoặc `nil`, điều kiện kiểm tra chu kỳ `(Now - ResetTimestamp) >= ResetSeconds` trả về `false`. `PickRandomDailyQuests` không được gọi, dẫn đến server trả về mảng rỗng `Daily = {}` và giao diện nhiệm vụ của người chơi bị trống hoàn toàn cho đến hết 24h.
- **Giải pháp:** Bổ sung guard clause kiểm tra bảng rỗng: `IsQuestsEmpty = (not DailyData.Quests) or (next(DailyData.Quests) == nil)` trực tiếp vào điều kiện kích hoạt `CheckAndResetDaily`, đảm bảo luôn tự động sinh danh sách nhiệm vụ nếu dữ liệu bị thiếu.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

### 15. Race Condition Mua Rương Gây Double-Spend & Âm Tiền Khi Spam Mạng
- **Vấn đề:** Khoảng cách giữa dòng đọc số dư `Data.Money < TotalPrice` và dòng trừ tiền `DataService.AddMoney` không có cơ chế khóa. Nếu client gửi đồng thời nhiều request `BuyChest` trong cùng 1 frame, tất cả các luồng đều vượt qua bước kiểm tra số dư ban đầu dẫn đến mua nhiều rương vượt số tiền thực có, gây âm tiền hoặc nhân bản vật phẩm.
- **Giải pháp:** Sử dụng Mutex Lock `_BuyLocks[Player.UserId] = true` trước khi đọc số dư tài khoản kết hợp bọc khối giao dịch trong `pcall`, đảm bảo mỗi người chơi chỉ được thực thi tuần tự 1 giao dịch mở rương tại 1 thời điểm.
- **File liên quan:** [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### 16. Race Condition Yielding Bất Đồng Bộ Vượt Giới Hạn Reset Nhiệm Vụ Hàng Ngày
- **Vấn đề:** Khi client gọi `RequestResetDailyQuests`, `QuestService` gọi `ShopService.PlayerOwnsGamePass`. Hàm này thực hiện yield luồng khi gọi `MarketplaceService:UserOwnsGamePassAsync`. Trong thời gian yield chờ Roblox Cloud phản hồi, biến đếm `ResetsUsed` chưa kịp tăng. Kẻ tấn công gửi nhiều request đồng thời sẽ reset nhiệm vụ hàng ngày nhiều lần liên tiếp, phá vỡ giới hạn `MaxResets = 1`.
- **Giải pháp:** Áp dụng khóa luồng `_ResetLocks[Player.UserId] = true` ngay tại dòng đầu tiên của hàm trước khi yield hoặc kiểm tra GamePass, chặn đứng mọi request trùng lặp phát sinh khi giao dịch trước đó đang xử lý.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua)

### 17. Nguy Cơ Ghi Đè Mất Dữ Liệu Do Cướp Session Lock Bằng "ForceLoad" & Type Injection Gây Hỏng Profile
- **Vấn đề:** 
  1. `DataService` nạp profile bằng cờ `"ForceLoad"` thô bạo. Khi người chơi chuyển server nhanh lúc server cũ đang Final Save, session lock bị cướp dẫn đến ghi đè dữ liệu cũ chưa kịp lưu (Rollback).
  2. Handler `SaveSetting` chỉ clamp số nhưng cho phép ghi trực tiếp dữ liệu dạng string/table/NaN vào `Profile.Data.Settings`, làm quá tải giới hạn 4MB DataStore và crash client.
- **Giải pháp:**
  1. Chuyển `"ForceLoad"` thành hàm release handler: trả về `"Repeat"` để chờ server cũ lưu và nhả lock an toàn nếu player còn trong game, trả về `"Cancel"` nếu player đã thoát.
  2. Ép kiểu nghiêm ngặt `typeof(Value) == "number"` và loại trừ `NaN`/`math.huge` ở cả tầng Remote lẫn `DataService.SetSetting`.
- **File liên quan:** [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [ProfileService.lua](../../src/ServerScriptService/Lib/ProfileService.lua)

### 18. Lỗi Runtime Không Xác Định Trong `ProcessReceipt` Nuốt Mất Robux Của Người Chơi
- **Vấn đề:** Trong callback `MarketplaceService.ProcessReceipt`, nếu các hàm trao thưởng (`DataService.AddMoney`) hoặc ghi lịch sử phát sinh ngoại lệ không mong muốn, toàn bộ hàm bị sập unhandled error. Roblox có thể hiểu nhầm trạng thái giao dịch hoặc không xử lý lại đúng cách, dẫn đến việc người chơi bị trừ Robux nhưng không nhận được tiền trong game.
- **Giải pháp:** Bọc toàn bộ các thao tác cộng tiền, ghi biên lai và đồng bộ client bên trong khối `pcall`. Nếu `pcall` trả về `false`, ghi log cảnh báo và trả về `Enum.ProductPurchaseDecision.NotProcessedYet` để Roblox tự động thử lại (Retry Mechanism). Chỉ trả về `PurchaseGranted` khi toàn bộ nghiệp vụ thực thi thành công mỹ mãn.
- **File liên quan:** [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### 19. Khử Trùng Lặp Thuật Toán Weighted Random & Triệt Tiêu Phụ Thuộc Ngược Giữa ReplicatedStorage và ServerScriptService
- **Vấn đề:** 
  1. Thuật toán gacha `WeightedRandom` theo tỷ lệ rơi bị copy-paste trùng lặp giữa `ShopService` và `QuestService`.
  2. `RewardHelper` nằm ở `ReplicatedStorage` (module dùng chung) nhưng lại require ngược vào `ServerScriptService.Services.ShopService` để kiểm tra GamePass `DoubleMatchMoney`, phá vỡ ranh giới phân tầng Client-Server.
- **Giải pháp:**
  1. Đưa `RewardHelper.WeightedRandom(Items)` vào làm Single Source of Truth cho thuật toán bốc thăm theo DropRate. Cả `ShopService` và `QuestService` đều tái sử dụng helper này.
  2. Xóa bỏ hoàn toàn require sang `ServerScriptService` trong `RewardHelper.RewardAndSync`. Caller trên Server (`FreezeService`, `MatchService`) chịu trách nhiệm truyền hệ số nhân `Multiplier` (được đọc an toàn từ `ShopService.PlayerOwnsGamePass`).
- **File liên quan:** [RewardHelper.lua](../../src/ReplicatedStorage/Shared/Tools/RewardHelper.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 20. Triệt Tiêu Hoàn Toàn Polling 0.05s Trong WaitForProfile Bằng Coroutine Event-Driven Yielding
- **Vấn đề:** `DataService.WaitForProfile` trước đây sử dụng vòng lặp `while not ProfileResult and ... do task.wait(0.05) end`. Khi server có nhiều player join cùng lúc hoặc mạng lag, hàng loạt luồng polling liên tục đốt chu kỳ CPU Server một cách vô ích và tạo ra độ trễ nhân tạo ít nhất 50ms.
- **Giải pháp:** Viết lại toàn bộ hàm bằng mô hình Coroutine Event-Driven:
  1. Sử dụng `coroutine.yield()` để tạm dừng thread hiện tại.
  2. Lắng nghe `_ProfileLoadedBindable.Event`: khi profile của đúng player nạp xong, tự động resume thread kèm dữ liệu `Profile`.
  3. Lắng nghe `Players.PlayerRemoving`: nếu người chơi thoát game khi đang chờ, lập tức hủy yield và resume `nil` không chờ timeout.
  4. Lên lịch `task.delay(Timeout)` để resume `nil` an toàn nếu quá hạn nạp. Tự động ngắt kết nối mọi listener ngay khi resume.
- **File liên quan:** [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [DataConfig.lua](../../src/ReplicatedStorage/Shared/Config/DataConfig.lua)
