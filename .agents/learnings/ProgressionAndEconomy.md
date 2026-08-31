# ProgressionAndEconomy
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống tiến trình người chơi và kinh tế (Kinh tế & Thưởng trận đấu, Spree Streak, Nhiệm vụ Daily/Milestone, Hiệu ứng Mở rương và Đồng bộ Dữ liệu).
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

### 3. Thiết kế Delta-Progress cho Hệ thống Nhiệm vụ (Quest System)
- **Chi tiết:** Để theo dõi tiến trình nhiệm vụ dựa trên các chỉ số sẵn có (`TotalFreezes`, `TotalWins`, `PlayTime`) mà không cần tạo nhiều biến đếm độc lập hay reset stat gốc khi hoàn thành, hệ thống sử dụng cơ chế mốc bắt đầu (`BaseProgress`).
- **Công thức:**
  $$\text{Tiến trình thực tế} = \text{CurrentStat} - \text{BaseProgress}$$
- **Daily Quest:** `BaseProgress` được chụp lại (snapshot) tại thời điểm reset daily (chu kỳ 24h độc lập tính theo thời điểm join của từng player).
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua)

### 4. Cấu hình Tùy chọn Reset Tiến trình Milestone Quest (StackExcessProgress)
- **Chi tiết:** Cấu hình tùy chọn `StackExcessProgress` trong `QuestConfig.lua`:
  - `StackExcessProgress = false`: Tại thời điểm nhận thưởng (claim), Server gán `BaseProgress = CurrentStat` để reset tiến trình dôi dư về 0.
  - `StackExcessProgress = true`: Server tịnh tiến `BaseProgress = BaseProgress + Requirement` để cộng dồn tiến trình dôi dư vào chu kỳ tiếp theo.
- **File liên quan:** [QuestConfig.lua](../../src/ReplicatedStorage/Shared/Config/QuestConfig.lua), [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua)

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

---

## Vấn đề kiến trúc & Giải pháp

### 1. Tiến trình PlayTime Không Cập Nhật Thời Gian Thực Trên GUI và Cuộn UI Bị Reset
- **Vấn đề:** Nhiệm vụ `PlayTime` không nhảy số trên GUI khi mở lên, chỉ khi thoát rồi vào lại mới thấy tiến trình. Ngoài ra, việc xóa và render lại toàn bộ list làm vị trí cuộn của ScrollingFrame bị nhảy về đầu trang.
- **Giải pháp:** Server tính dồn session trong `GetStatValue`. Client bật vòng lặp cập nhật ngầm 1s/lần khi GUI mở và áp dụng cơ chế cập nhật in-place (chỉ gán lại thuộc tính text/size của Frame cũ) để giữ nguyên `CanvasPosition`.
- **File liên quan:** [QuestService.lua](../../src/ServerScriptService/Services/QuestService.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

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
