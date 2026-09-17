# AnalyticsAndTelemetry
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống thống kê và phân tích dữ liệu (Roblox native AnalyticsService, Studio Mock logging, Custom Events, Economy Inflow/Outflow, Combat Telemetry, Drop Rate Tracking và Session Lifecycle).
> Cập nhật lần cuối: 17-09-2026

---

## Kiến trúc

### 1. Kiến trúc Telemetry Đa tầng Không Gây Tắc Nghẽn (Non-blocking Layered Telemetry Architecture)
- **Chi tiết:** Tách biệt hoàn toàn tầng logic nghiệp vụ (`MatchService`, `FreezeService`, `ShopService`, `QuestService`) khỏi hạ tầng logging qua Single Source of Truth `AnalyticsService.lua`.
- **Nguyên lý An toàn:** Toàn bộ lệnh gọi tới Roblox native `AnalyticsService` (`LogCustomEvent`, `LogEconomyEvent`, `LogProgressionEvent`) được bọc trong `pcall` và chuẩn hóa kiểu dữ liệu (`FormatCustomFields` ép chuỗi 100% dimensions). Lỗi kết nối telemetry từ Roblox không bao giờ làm gián đoạn gameplay.
- **File liên quan:** [AnalyticsService.lua](../../src/ServerScriptService/Services/AnalyticsService.lua), [AnalyticsConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnalyticsConfig.lua), [ServiceLoader.lua](../../src/ServerScriptService/Services/ServiceLoader.lua)

### 2. Tập trung Hằng số & Danh mục Sự kiện qua AnalyticsConfig
- **Chi tiết:** Tuyệt đối loại bỏ hardcode chuỗi event name, enum hay nguồn tiền trong codebase. Toàn bộ định danh được tập trung tại `AnalyticsConfig.lua`:
  - `Events`: `MatchStarted`, `MatchEnded`, `FrozenStateEntered`, `FirstBloodOccurred`, `SpreeAchieved`, `ItemAcquired`, `ChestOpened`, `PlayerSessionEnded`.
  - `EconomySources` & `EconomySinks`: Phân loại rõ ràng nguồn tiền vào và điểm xả tiền.
  - `Settings`: Cung cấp cờ bật/tắt linh hoạt (`EnableCustomEvents`, `EnableEconomyEvents`, `EnableProgressionEvents`).
- **File liên quan:** [AnalyticsConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnalyticsConfig.lua)

### 3. Thu Thập & Tổng Hợp Chỉ Số Trong RAM Trận Đấu (Match Aggregation Pattern)
- **Chi tiết:** Để tránh chạm giới hạn Rate Limit của Roblox Analytics, hệ thống áp dụng cơ chế gom cụm trong RAM thay vì ghi nhận từng frame:
  - `SessionService` duy trì các bộ đệm: `Throws`, `Hits`, `TimeSpentFrozen`, `FrozenStartTime`, `_didReachFrozenState`.
  - Trong suốt trận đấu, các service chỉ cập nhật số liệu cục bộ trong RAM.
  - Khi trận đấu kết thúc (`GameOver`), `MatchService` chụp snapshot và bắn duy nhất 1 sự kiện `LogMatchEnd` kèm theo `LogPlayerMatchSummary` cho từng người tham gia.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 4. Đo Lường Độ Chính Xác Vũ Khí & Thời Gian Vô Hiệu Hóa (Combat Accuracy & Incapacitation Telemetry)
- **Chi tiết:**
  - *Icicle Accuracy:* Tính theo công thức:
    $$\text{AccuracyPercent} = \left\lfloor \frac{\text{Hits}}{\text{Throws}} \times 100 \right\rfloor$$
    `Throws` được đếm khi người chơi vung kiếm hợp lệ (`OnToolSwing` trong `IcicleService`), còn `Hits` chỉ được cộng khi cú đánh vượt qua toàn bộ 10 bước kiểm tra máy chủ trong `FreezeService`.
  - *TimeSpentFrozen:* Tích lũy thời gian bất động của người chơi:
    $$\text{TimeSpentFrozen} = \sum (\text{ThawTimestamp} - \text{FrozenTimestamp})$$
    Phục vụ trực tiếp cho việc cân bằng trải nghiệm, tránh để thời gian "chết" của người chơi vượt quá ngưỡng gây nản lòng ($> 45\text{s}$).
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [IcicleService.lua](../../src/ServerScriptService/Services/IcicleService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 5. Theo Dõi Vòng Đời Phiên Chơi & Chụp Số Dư An Toàn (Player Session Lifecycle Tracking)
- **Chi tiết:** `SessionService` quản lý `_playerSessionInfo` lưu `JoinTimestamp`, `MatchesPlayed`, và `StartingMoney`. Để tránh race condition khi profile bị đóng trước khi tính delta, `SessionService` hook vào `DataService.RegisterBeforeProfileRelease` để chụp số dư `CurrentMoney` ngay trước khi giải phóng Profile:
  $$\Delta \text{Money} = \text{CurrentMoney} - \text{StartingMoney}$$
  Ghi nhận sự kiện `PlayerSessionEnded` kèm `SessionDuration`, phục vụ phân tích độ giữ chân (Retention) và biến động số dư ròng của từng người chơi.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### 6. Phân Tách Doanh Thu Thực (Robux IAP) & Dòng Tiền Ảo Trong Economy Telemetry
- **Chi tiết:** Tách bạch nguồn tiền thưởng/hoàn trong game với giao dịch Robux tiền thật để không làm sai lệch báo cáo tài chính trên Creator Hub:
  - *Developer Product (Robux):* Ghi nhận `Type: ProductPurchase`, `Sku` là tên gói hiển thị (ví dụ: `A LOT`), kèm `ProductId` và `PurchaseId` trong metadata.
  - *Cashback Gacha:* Ghi nhận `Type: DuplicateRefund`, `Sku` là `ChestId` (ví dụ: `BasicIcicleChest`), kèm `RefundFrom`.
  Cả hai đều qua `AnalyticsService.LogIncome` với tham số `ItemSku` tùy biến.
- **File liên quan:** [AnalyticsConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnalyticsConfig.lua), [AnalyticsService.lua](../../src/ServerScriptService/Services/AnalyticsService.lua), [ShopService.lua](../../src/ServerScriptService/Services/ShopService.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Cảnh báo và Thất bại Khi Gọi Analytics Trong Môi Trường Roblox Studio (Studio Mock Fallback Engine)
- **Vấn đề:** Khi kiểm thử trong Roblox Studio, việc gọi `AnalyticsService` trực tiếp sẽ báo lỗi warning hoặc thất bại do chưa publish lên môi trường Production, gây nhiễu log và tiềm ẩn nguy cơ làm bẩn tập dữ liệu phân tích thật.
- **Giải pháp:** Tích hợp bộ kiểm tra `RunService:IsStudio()` kết hợp tùy chọn `AnalyticsConfig.Settings.IsStudioMockEnabled`. Khi chạy trong Studio, toàn bộ sự kiện được định tuyến sang Mock Logger in trực quan ra Output console theo cấu trúc chuẩn `[Mock CustomEvent]`, `[Mock EconomyEvent]`, `[Mock ProgressionEvent]`.
- **File liên quan:** [AnalyticsService.lua](../../src/ServerScriptService/Services/AnalyticsService.lua), [AnalyticsConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnalyticsConfig.lua)

### 2. Nguy Cơ Nghẽn Mạng & Throttling Do Ghi Nhận Sự Kiện Tần Suất Quá Cao (Ingestion Rate-Limit Protection)
- **Vấn đề:** Bắn sự kiện mỗi khi người chơi vung vũ khí hoặc nhận từng đồng tiền lẻ sẽ làm cạn kiệt hạn ngạch mạng của server và dính Rate-limit HTTP 429 từ Roblox Analytics.
- **Giải pháp:** Phân tầng dữ liệu nghiêm ngặt: các chỉ số nhịp độ cao (`Throws`, `Hits`, `Freezes`, `Thaws`) chỉ tích lũy vào RAM session qua `SessionService.IncrementStat`. Chỉ kích hoạt ghi nhận sự kiện lên Roblox tại các điểm mốc vòng đời: Bắt đầu trận (`MatchStarted`), Kích hoạt trạng thái nguy cấp (`FrozenStateEntered`), Hoàn thành nhiệm vụ/mua rương, và Kết thúc ván (`MatchEnded`).
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 3. Thất Thoát Dữ Liệu Thời Gian Đóng Băng Khi Thoát Game Hoặc Chết Đột Ngột
- **Vấn đề:** Người chơi đang ở trạng thái `Frozen` nhưng đột ngột thoát game (`PlayerRemoving`) hoặc rơi xuống void / reset character (`EliminatePlayer`), nếu chỉ tính giờ ở hàm `ThawPlayer` thì mốc `FrozenStartTime` sẽ bị thất lạc vĩnh viễn, làm sai lệch chỉ số `TimeSpentFrozen`.
- **Giải pháp:** Thiết lập điểm chốt chặn finalize `SessionService.RecordFrozenEnd(Player)` bắt buộc tại 3 vị trí: (1) `ThawPlayer` khi được giải cứu, (2) `ThawAll` khi kết thúc ván đấu, và (3) `EliminatePlayer` / `PlayerRemoving` ngay trước khi người chơi bị xóa khỏi session.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 4. Bẫy Mất Dữ Liệu Số Dư Cuối Do Thứ Tự Lifecycle Của PlayerRemoving (Data Release Race Condition)
- **Vấn đề:** Do `DataService` khởi tạo trước trong `ServiceLoader`, sự kiện `PlayerRemoving` của nó chạy trước và giải phóng Profile (`Profile:Release()`). Khi `SessionService` nhận sự kiện `PlayerRemoving` sau đó, `DataService.GetData(Player)` đã trả về `nil`, khiến `CurrentMoney` bị fallback về 0 hoặc bằng `StartingMoney`, làm `NetMoneyChange = 0` (hoặc âm toàn bộ tài khoản).
- **Giải pháp:** Sử dụng hook đồng bộ `DataService.RegisterBeforeProfileRelease` để `SessionService` flush telemetry và lấy số dư `CurrentMoney` chính xác ngay trước khi profile đóng. Đồng thời bổ sung fallback 2 chiều giữa `SetStartingMoney` và `InitPlayerSession` để không bỏ sót `StartingMoney`.
- **File liên quan:** [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### 5. Mất Tên Template Bản Đồ Gốc Khi Clone Ra Workspace Container
- **Vấn đề:** Khi `MapService.LoadRandomMap` clone template map vào Workspace, model được đổi tên thành container chung (`CurrentMap` theo `MapConfig.Folders.MapContainer`). Code đo lường lấy `CurrentMap.Name` sẽ luôn ghi nhận `"CurrentMap"` vào sự kiện `MatchStarted` và `MatchEnded`, làm mất dữ liệu phân tích tỷ lệ thắng/thời gian theo từng map cụ thể.
- **Giải pháp:** Lưu trữ tên template gốc vào state nội bộ `_currentMapName` tại thời điểm chọn ngẫu nhiên trong `MapService.LoadRandomMap`, đồng thời mở API công khai `MapService.GetCurrentMapName()` để các service khác truy xuất.
- **File liên quan:** [MapService.lua](../../src/ServerScriptService/Services/MapService.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)
