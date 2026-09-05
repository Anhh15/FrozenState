Searched for files: *
Searched for files: *.lua
Searched for files: *.lua
Viewed RemoteDefinitions.lua:1-161
Viewed Main.server.lua:1-17
Viewed ServiceLoader.lua:1-80
Viewed Main.client.lua:1-93
Viewed FreezeService.lua:1-599
Searched for "OnToolSwing"
Viewed IcicleService.lua:1-189
Viewed IcicleScript.client.lua:1-248
Viewed ShopService.lua:1-330
Viewed DataService.lua:1-800
Viewed DataService.lua:800-815
Viewed QuestService.lua:1-735
Viewed SessionService.lua:1-465
Searched for "SetAfkState"
Searched for "RequestSpectateTarget"
Searched for "FinishGameLoading"
Viewed MatchService.lua:1-800
Viewed MatchService.lua:800-885
Viewed TeamService.lua:1-83
Viewed MapService.lua:1-92
Viewed AdminService.lua:1-450
Viewed AdminConfig.lua:1-54
Viewed SpectateController.lua:1-644
Viewed HighlightController.lua:1-315
Viewed TagHelper.lua:1-81
Viewed SettingController.lua:1-366
Searched for "IsAfk"
Viewed ShopController.lua:1-726
Viewed QuestController.lua:1-661
Viewed HotbarController.lua:1-750
Viewed GameStateController.lua:1-272
Viewed SoundController.lua:1-135
Viewed MusicController.lua:1-163
Viewed InventoryController.lua:1-461
Viewed PlayerDataController.lua:1-209
Viewed ScoreBoardController.lua:1-366
Viewed PlayerStatusController.lua:1-239
Viewed GameStatisticController.lua:1-394
Viewed GameOverAnnouncementController.lua:1-282
Viewed FrozenStateAnnouncementController.lua:1-176
Viewed ModeAnnouncementController.lua:1-243
Searched for "ModeAnnouncementController"
Viewed RoundLoadingScreenController.lua:1-253
Viewed GameLoadingController.lua:1-552
Viewed AccoladesController.lua:1-136
Viewed MenuController.lua:1-267
Viewed NavigationController.lua:1-238
Viewed ProfileController.lua:1-293
Viewed ItemRewardController.lua:1-483
Viewed GameConfig.lua:1-50
Viewed PlayerStateHelper.lua:1-228
Searched for "BindToClose"
Viewed DataConfig.lua:1-34
Searched for "SetMilestoneBase"
Searched for "AddCosmetic"
Searched for "task.wait("
Searched for ":Start()"
Viewed ShopConfig.lua:1-26
Viewed ViewportManager.lua:1-99

# 📊 BÁO CÁO TỔNG QUAN RÀ SOÁT TOÀN BỘ SRC

---

## 1. BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO

| Mức độ | Số lượng | Các mảng / Module ảnh hưởng chính |
| :--- | :---: | :--- |
| 🔴 **CRITICAL** | **3** | • **Combat & Server Authority**: Lỗ hổng 360-degree Kill Aura, Fake Hit chém xuyên tường (`FreezeService`, `IcicleService`).<br>• **Data Integrity**: Nguy cơ mất sạch dữ liệu PlayTime & Quest khi Server Shutdown đột ngột (`DataService`, `QuestService`).<br>• **Network Security**: Remote DoS / Flooding làm sập DataStore buffer (`DataService`). |
| 🟠 **HIGH** | **4** | • **Engine & Streaming**: Lạm dụng `ReplicationFocus` làm vỡ StreamingEnabled & Crash Client (`MatchService`, `SpectateController`).<br>• **Memory Leaks**: Rò rỉ RAM vĩnh viễn trên Client do không dọn dẹp khi người chơi thoát (`HighlightController`, `ScoreBoardController`, `PlayerStatusController`).<br>• **System Architecture**: Vỡ kiến trúc 2-Phase Lifecycle trên 16/24 Client Controllers (`StarterPlayerScripts`).<br>• **Data Concurrency**: Race Condition gây DataStore Session Lockout khi Player thoát nhanh (`DataService`). |
| 🟡 **MEDIUM** | **4** | • **Configuration**: Hardcode Magic Numbers vương vãi vi phạm nguyên tắc tập trung (`ShopService`, `QuestService`, `ShopController`, `InventoryController`).<br>• **Duct-tape Hacks**: Lạm dụng `task.wait()` mù để đồng bộ thời gian (`MatchService`, `HighlightController`, `QuestController`).<br>• **Code Conventions**: Vi phạm quy chuẩn PascalCase nghiêm trọng (lạm dụng `_camelCase` tràn lan).<br>• **API Deprecation**: Lắng nghe `Player.Chatted` cũ và sai lệch Prefix lệnh Admin (`AdminService`). |
| 🟢 **LOW** | **2** | • **Dead Code & Data Redundancy**: Module/Hàm bỏ hoang và trùng lặp cấu trúc Profile Template (`DataService`, `DataConfig`).<br>• **Network Idempotency**: Thiếu kiểm tra trạng thái lặp cho `FinishGameLoading` (`MatchService`). |
| **TỔNG CỘNG** | **13** | **Tình trạng tổng quan: Hệ thống có nền tảng cấu trúc tốt, nhưng tồn tại những lỗ hổng bảo mật chết người trong cơ chế xác thực Combat, quản lý vòng đời bộ nhớ Client lỏng lẻo và nguy cơ mất dữ liệu khi máy chủ tắt đột ngột.** |

---

## 2. CHI TIẾT CÁC ĐIỂM YẾU & NGUY CƠ BẢO MẬT (XẾP THEO ĐỘ ƯU TIÊN)

### 🔴 NHÓM CRITICAL (Rủi ro cực hạn – Cần khắc phục ngay lập tức)

---

#### 1. [CRIT-01] Lỗ hổng Fake Hit & 360° Kill Aura không cần vung kiếm
- **Vị trí**: [`FreezeService.lua:498-538`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Freeze/FreezeService.lua#L498-L538) và [`IcicleService.lua:166-172`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Tools/IcicleService.lua#L166-L172)
- **Phân loại**: Trụ cột 1 – Lỗ hổng bảo mật & Server Authority
- **Mức độ**: 🔴 **CRITICAL**
- **Hiện trạng code**:
  `FreezeService` tự ý khởi tạo phiên tấn công mới (`_AttackSessions[Attacker]`) ngay khi nhận được tín hiệu `OnToolHit`. Server **hoàn toàn không xác thực xem Client có thực sự gọi `OnToolSwing` hay không**. Hơn nữa, việc xác thực đòn đánh tại server chỉ kiểm tra khoảng cách Euclid 3D đơn thuần (`Distance <= HitboxRange * HitboxTolerance`), hoàn toàn không kiểm tra vector hướng nhìn (`LookVector`) hay kiểm tra vật cản (Raycast Line-of-Sight).
- **Kịch bản khai thác**:
  1. Kẻ gian (exploiter) không cần trang bị hoặc không cần click chuột vung kiếm (không bao giờ kích hoạt animation chém hay `OnToolSwing`).
  2. Kẻ gian chỉ cần đứng gần nạn nhân (thậm chí đứng quay lưng lại hoặc đứng sau bức tường dày) và viết script spam remote `OnToolHit:FireServer(VictimCharacter)` mỗi 0.8 giây.
  3. Server kiểm tra khoảng cách thấy hợp lệ sẽ lập tức đóng băng nạn nhân. Kẻ gian tạo ra một vòng tròn "Kill Aura" 360 độ chém xuyên tường mà không có bất kỳ hoạt ảnh nào hiển thị.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Hợp nhất vòng đời tấn công giữa `IcicleService` và `FreezeService`. Khi client gọi `OnToolSwing`, server ghi lại `LastSwingTimestamp[Attacker]`.
  - `OnToolHit` chỉ được chấp nhận nếu nằm trong "cửa sổ chém hợp lệ": `(Now - LastSwingTimestamp) <= MaxSwingDuration` và `(Now - LastSwingTimestamp) >= MinSwingDelay`.
  - Bắt buộc kiểm tra góc chém trên Server: Vector từ kẻ tấn công đến nạn nhân phải nằm trong góc nhìn phía trước:
    $$\vec{A} \cdot \vec{D} \ge \cos(\text{MaxAngle})$$
    (với $\vec{A}$ là `HumanoidRootPart.CFrame.LookVector` và $\vec{D}$ là hướng chuẩn hóa tới nạn nhân).
  - Bổ sung Raycast kiểm tra Line-of-Sight từ kẻ tấn công đến nạn nhân để triệt tiêu việc chém xuyên vật cản/tường.

---

#### 2. [CRIT-02] Mất sạch dữ liệu PlayTime & Quest khi Server Shutdown đột ngột (`game:BindToClose`)
- **Vị trí**: [`DataService.lua:73-85, 230-245`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Data/DataService.lua#L73-L85) và [`QuestService.lua:89-98`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Quests/QuestService.lua#L89-L98)
- **Phân loại**: Trụ cột 1 – Lỗ hổng bảo mật & Toàn vẹn dữ liệu
- **Mức độ**: 🔴 **CRITICAL**
- **Hiện trạng code**:
  `DataService` có hàm `RegisterBeforeProfileRelease` để các service khác như `QuestService` đăng ký lưu dữ liệu tạm (PlayTime trong RAM, tiến độ nhiệm vụ) trước khi Profile bị đóng. Tuy nhiên, `DataService` **chỉ gọi callback này khi `PlayerRemoving` kích hoạt**. Khi Roblox tắt máy chủ để cập nhật game hoặc server crash, sự kiện `game:BindToClose` của Roblox kích hoạt, thư viện `ProfileService` sẽ tự động đóng toàn bộ Profile ngay lập tức mà `DataService` không hề có hook `BindToClose` để gọi các callback này.
- **Rủi ro thực tế**:
  Khi nhà phát triển bấm "Restart Servers for Update" hoặc server bị buộc dừng, toàn bộ thời gian chơi của người chơi trong phiên đó và tiến độ nhiệm vụ đang nằm trong RAM của `QuestService` bị vứt bỏ hoàn toàn mà không kịp đồng bộ vào Profile. Người chơi mất trắng tiến độ cày cuốc.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Đăng ký `game:BindToClose` trực tiếp trong `DataService`.
  - Trong `BindToClose`, lặp qua toàn bộ người chơi đang hoạt động trong `ActiveProfiles`, kích hoạt tuần tự các hàm đăng ký qua `RegisterBeforeProfileRelease`, sau đó mới cho phép `ProfileService` release dữ liệu.

---

#### 3. [CRIT-03] Lỗ hổng Remote Flooding / DataStore Denial of Service qua `SaveSetting`
- **Vị trí**: [`DataService.lua:801-809`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Data/DataService.lua#L801-L809)
- **Phân loại**: Trụ cột 1 – Server Authority & An toàn mạng
- **Mức độ**: 🔴 **CRITICAL**
- **Hiện trạng code**:
  Server lắng nghe remote `SaveSetting:FireServer(Key, Value)`. Khi nhận tín hiệu, server trực tiếp gán giá trị mà Client gửi lên vào bảng dữ liệu: `Profile.Data.Settings[Key] = Value`. Đoạn mã này **hoàn toàn không có Rate Limit / Debounce**, không kiểm tra độ dài dữ liệu, và không kiểm tra danh sách trắng (whitelist) các `Key` hợp lệ.
- **Kịch bản khai thác**:
  Kẻ gian chạy vòng lặp gửi hàng chục ngàn gói tin `SaveSetting` mỗi giây với dung lượng chuỗi ngẫu nhiên khổng lồ. Điều này làm tràn bộ nhớ RAM của Server, phình to dung lượng Session DataStore vượt quá giới hạn 4MB của Roblox, dẫn tới việc DataStore bị từ chối lưu (Throttle/Data Drop) cho toàn bộ người chơi trong server.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Thiết lập cơ chế Token Bucket Rate Limiter cho từng người chơi (tối đa 1 lần lưu cấu hình mỗi 2 giây).
  - Kiểm tra Whitelist nghiêm ngặt: `Key` bắt buộc phải tồn tại trong bảng cấu hình [`DataConfig.DefaultSettings`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Config/DataConfig.lua).
  - Kiểm tra kiểu dữ liệu (`typeof(Value)`) tương ứng với kiểu mặc định của `DataConfig`, từ chối mọi giá trị lạ hoặc chuỗi vượt quá 64 ký tự.

---

### 🟠 NHÓM HIGH (Rủi ro cao – Ảnh hưởng hiệu năng, vỡ vòng đời và rò rỉ RAM)

---

#### 4. [HIGH-01] Lạm dụng `ReplicationFocus` làm vỡ StreamingEnabled & Gây Crash Client
- **Vị trí**: [`MatchService.lua:820-873`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Match/MatchService.lua#L820-L873) và [`SpectateController.lua:136`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Spectate/SpectateController.lua#L136)
- **Phân loại**: Trụ cột 1 & 5 – Lỗ hổng tài nguyên Server & Tối ưu hóa
- **Mức độ**: 🟠 **HIGH**
- **Hiện trạng code**:
  Khi khán giả chuyển đổi mục tiêu theo dõi, client gửi remote `RequestSpectateTarget`. Server gán ngay lập tức `SpectatorPlayer.ReplicationFocus = TargetCharacter.HumanoidRootPart` mà không có bất kỳ bộ đệm thời gian (debounce) nào. Phía Client thì kích hoạt remote này ở mỗi lần người dùng bấm nút Next/Previous.
- **Rủi ro thực tế**:
  Với tính năng `StreamingEnabled` của Roblox, khi `ReplicationFocus` thay đổi liên tục với tốc độ cao (do kẻ gian spam hoặc người chơi bấm nút liên tục), Engine của Roblox bị ép phải liên tục dọn sạch (stream out) và tải lại (stream in) các vùng địa hình/mô hình xung quanh các vị trí xa nhau. Điều này gây sụt giảm FPS nghiêm trọng cho server và làm văng game (crash bộ nhớ) đối với các thiết bị di động hoặc máy cấu hình yếu.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Phía Client: Đặt debounce tối thiểu 0.3s cho thao tác bấm nút chuyển mục tiêu.
  - Phía Server: Áp dụng Rate Limit tối thiểu 0.5s giữa các lần thay đổi `ReplicationFocus` của một người chơi. Nếu gửi quá nhanh, chỉ trả về lỗi hoặc bỏ qua.

---

#### 5. [HIGH-02] Rò rỉ bộ nhớ (Memory Leak) vĩnh viễn trên Client do bỏ quên `PlayerRemoving`
- **Vị trí**: [`HighlightController.lua:40-42, 170-220`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Highlight/HighlightController.lua#L40-L42)
- **Phân loại**: Trụ cột 5 – Memory Leaks & Event Cleanup
- **Mức độ**: 🟠 **HIGH**
- **Hiện trạng code**:
  `HighlightController` lưu trữ thông tin trạng thái người chơi trong các bảng cục bộ: `KnownTeams[UserIdStr]`, `_frozenPlayers[UserIdStr]`, `_playerStates[UserIdStr]`. Tuy nhiên, Controller này **hoàn toàn không kết nối tới sự kiện `Players.PlayerRemoving`**. Các controller giao diện khác như [`ScoreBoardController.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/ScoreBoard/ScoreBoardController.lua) và [`PlayerStatusController.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/PlayerStatus/PlayerStatusController.lua) cũng không dọn dẹp các thẻ hiển thị khi người chơi thoát giữa trận đấu.
- **Rủi ro thực tế**:
  Trong một server hoạt động nhiều giờ, hàng trăm lượt người chơi tham gia và rời đi. Bảng bộ nhớ của `HighlightController` liên tục phình to, giữ lại các tham chiếu đối tượng không thể thu gom rác (garbage collect). Trên giao diện người dùng, danh sách điểm số và trạng thái người chơi hiển thị thẻ của những người chơi đã thoát game (ghost players) cho tới khi trận đấu kết thúc hoàn toàn.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Kết nối `Players.PlayerRemoving` trong `HighlightController:Start()`: Hủy `Highlight` instance của người chơi đó và xóa hoàn toàn các key liên quan trong `KnownTeams`, `_frozenPlayers`, `_playerStates`.
  - Cập nhật `ScoreBoardController` và `PlayerStatusController` để tự động gỡ bỏ thẻ UI của người chơi ngay khi họ rời khỏi server.

---

#### 6. [HIGH-03] Vỡ kiến trúc 2 giai đoạn khởi tạo (Broken Two-Phase Lifecycle) trên Client
- **Vị trí**: [`Main.client.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Main.client.lua) và 16/24 Controllers
- **Phân loại**: Trụ cột 3 – Kiến trúc hệ thống
- **Mức độ**: 🟠 **HIGH**
- **Hiện trạng code**:
  Kiến trúc dự án định nghĩa quy trình 2 giai đoạn: Giai đoạn 1 chạy `:Init()` cho tất cả Controller, sau đó Giai đoạn 2 mới chạy `:Start()`. Tuy nhiên, trong 24 Controller hiện có, **chỉ có vỏn vẹn 8 Controller hiện thực hàm `:Start()`**. 16 Controller còn lại dồn toàn bộ logic lắng nghe Remote, kết nối giao diện, và truy xuất các Controller khác ngay trong `:Init()`.
- **Rủi ro thực tế**:
  Gây ra hiện tượng phụ thuộc vòng (circular dependency) và lỗi truy xuất trước khi khởi tạo (race condition). Do Controller A gọi Controller B ngay trong `:Init()` khi Controller B chưa kịp chạy xong `:Init()`, các lập trình viên đã phải dùng các biện pháp chắp vá như gọi hàm trợ giúp lười biếng `GetMenuController()` hoặc `require` trễ để né lỗi.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Tách bạch dứt khoát 100% Controller theo đúng chuẩn:
    - `:Init()`: Chỉ khởi tạo biến nội bộ, lấy tham chiếu UI elements, không kết nối Remote và không gọi method logic của Controller khác.
    - `:Start()`: Bắt đầu kết nối tín hiệu Remote, lắng nghe sự kiện từ Service/Controller khác và kích hoạt luồng hoạt động chính.

---

#### 7. [HIGH-04] Race Condition gây DataStore Session Lockout khi Người chơi thoát nhanh
- **Vị trí**: [`DataService.lua:230-245`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Data/DataService.lua#L230-L245)
- **Phân loại**: Trụ cột 1 – Toàn vẹn dữ liệu
- **Mức độ**: 🟠 **HIGH**
- **Hiện trạng code**:
  Trong luồng xử lý `OnPlayerAdded`, thao tác `ProfileStore:LoadProfileAsync` là một tác vụ bất đồng bộ (yield). Nếu một người chơi vào game và thoát ra ngay lập tức (trong vòng chưa đầy 1 giây) khi tác vụ này đang thực thi, sự kiện `PlayerRemoving` sẽ chạy trước khi `LoadProfileAsync` hoàn thành. Khi `LoadProfileAsync` trả về, code vẫn lưu profile vào bảng `ActiveProfiles[Player]` mà người chơi thì không còn trong server.
- **Rủi ro thực tế**:
  Profile của người chơi bị kẹt trạng thái mở (Session Locked) trên server cũ. Khi người chơi chuyển sang server mới, ProfileService tại server mới sẽ không thể tải dữ liệu và buộc người chơi phải chờ từ 10 đến 30 phút cho đến khi Session cũ tự hết hạn, gây ức chế tột cùng cho người dùng.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  Ngay sau khi `LoadProfileAsync` hoàn thành, lập tức kiểm tra:
  ```lua
  if not Player:IsDescendantOf(Players) then
      Profile:Release()
      return
  end
  ```

---

### 🟡 NHÓM MEDIUM (Rủi ro trung bình – Code chắp vá, Hardcode và Vi phạm Quy ước)

---

#### 8. [MED-01] Vi phạm nguyên tắc Không Hardcode (Magic Numbers rải rác trong mã nguồn)
- **Vị trí**: 
  - [`ShopService.lua:102-103`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Shop/ShopService.lua#L102-L103): Hardcode `MinQty = 1`, `MaxQty = 5` thay vì dùng cấu hình.
  - [`QuestService.lua:151, 208`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Quests/QuestService.lua#L151): Hardcode giá trị hoàn tiền mặc định `1000` Coins.
  - [`MatchService.lua:193`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Match/MatchService.lua#L193): Hardcode giá trị `3` cho bảng xếp hạng Top người chơi xuất sắc.
  - [`ShopController.lua:211-220, 350-355`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Shop/ShopController.lua#L211-L220) & [`InventoryController.lua:351-355`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Inventory/InventoryController.lua#L351-L355): Hardcode mã màu Hex `"FFFFFF"` và `"2F2F2F"`.
  - [`FreezeService.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Freeze/FreezeService.lua) & [`HotbarController.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Hotbar/HotbarController.lua): Tràn ngập các giá trị fallback dự phòng viết tắt như `or 0.8`, `or 0.4`, `or 1.5`, `or 4`.
- **Phân loại**: Trụ cột 4 – Không hardcode & Cấu hình tập trung
- **Mức độ**: 🟡 **MEDIUM**
- **Hiện trạng & Rủi ro**:
  Vi phạm trực tiếp triết lý thiết kế của dự án: *"Không hardcode, ưu tiên lưu tham số vào file tham số chung để dễ dàng điều chỉnh"*. Khi Game Designer muốn cân bằng kinh tế, chỉnh sửa giao diện hoặc tinh chỉnh thời gian hồi chiêu, họ buộc phải lùng sục từng dòng code trong logic thay vì chỉnh sửa tại các file Config tập trung.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Đưa `MinQty`, `MaxQty` vào [`ShopConfig.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Config/ShopConfig.lua).
  - Đưa giá trị hoàn tiền vào [`EconomyConfig.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Config/EconomyConfig.lua).
  - Đưa màu sắc Tab kích hoạt/vô hiệu hóa vào [`GuiAnimConfig.lua`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Config/GuiAnimConfig.lua).
  - Xóa bỏ toàn bộ các magic number `or X` và đảm bảo biến cấu hình luôn có giá trị đầy đủ trong Config tương ứng.

---

#### 9. [MED-02] Lạm dụng `task.wait()` mù (Blind Timing Hacks)
- **Vị trí**:
  - [`MatchService.lua:799`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Match/MatchService.lua#L799): `task.wait(2)` khi người chơi mới tham gia giữa trận.
  - [`MatchService.lua:469`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Match/MatchService.lua#L469): `task.wait(0.5)` làm bước đệm tải bản đồ.
  - [`HighlightController.lua:187`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Highlight/HighlightController.lua#L187): `task.wait(0.1)` sau khi chờ `HumanoidRootPart`.
  - [`QuestController.lua:396`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Quests/QuestController.lua#L396): `task.wait(0.3)` chờ animation trước khi làm mới UI.
- **Phân loại**: Trụ cột 2 – Code chắp vá & Giải pháp tạm bợ
- **Mức độ**: 🟡 **MEDIUM**
- **Hiện trạng & Rủi ro**:
  Dùng độ trễ thời gian cố định để "đoán" xem tài nguyên đã sẵn sàng hay chưa là một kỹ thuật lập trình chắp vá điển hình trong Roblox. Khi mạng của người chơi bị lag (ping cao), việc chờ `2` giây không đảm bảo client đã tải xong game, dẫn tới việc nhân vật bị spawn lơ lửng giữa hư không. Ngược lại, với các máy mạng nhanh, độ trễ này làm chậm trải nghiệm vô ích.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Thay thế hoàn toàn cơ chế chờ thời gian mù bằng kiến trúc Event-driven (hướng sự kiện): Lắng nghe tín hiệu Remote `FinishGameLoading` từ Client cụ thể đó trước khi cho phép gán trạng thái hoặc dịch chuyển nhân vật vào trận.

---

#### 10. [MED-03] Vi phạm nghiêm trọng quy chuẩn đặt tên PascalCase (Quy ước #1)
- **Vị trí**: Hầu như tất cả các Service và Controller trong `src/`
- **Phân loại**: Trụ cột 3 – Quy ước dự án (Coding Conventions)
- **Mức độ**: 🟡 **MEDIUM**
- **Hiện trạng code**:
  Quy tắc cốt lõi của dự án đã nêu rõ: *"Sử dụng PascalCase và tiếng Anh cho mọi biến và hàm để chung một quy tắc với roblox"*. Tuy nhiên, mã nguồn hiện tại đang bị ô nhiễm bởi thói quen dùng `_camelCase` cho các biến thành viên và biến cục bộ:
  - `_isSpectating`, `_playerStates`, `_teamAssignment`, `_iceBlocks`, `_sessionStart`, `_lastPhase`, `_frozenPlayers`, `_roundActive`, `_activeProfiles`, v.v.
- **Rủi ro thực tế**:
  Sự pha trộn vô tổ chức giữa `_camelCase`, `camelCase` và `PascalCase` làm giảm tính nhất quán của hệ sinh thái `src/`, gây nhầm lẫn khi các module tương tác với nhau và làm tăng nguy cơ bug do gõ sai định dạng biến.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  Chuẩn hóa toàn diện 100% các biến và trường dữ liệu sang chuẩn `PascalCase` thuần túy (ví dụ: `IsSpectating`, `PlayerStates`, `TeamAssignment`, `IceBlocks`, `SessionStart`).

---

#### 11. [MED-04] Sử dụng API lỗi thời (`Player.Chatted`) & Lỗi cấu hình Prefix trong Admin
- **Vị trí**: [`AdminService.lua:430, 395-408`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Admin/AdminService.lua#L430)
- **Phân loại**: Trụ cột 2 & 3 – Code Smells & Tính nhất quán
- **Mức độ**: 🟡 **MEDIUM**
- **Hiện trạng code**:
  Hệ thống lệnh quản trị đang lắng nghe sự kiện qua `Player.Chatted`. Đồng thời, bảng trợ giúp lệnh (`PrintHelp`) đang hướng dẫn người dùng gõ lệnh bằng tiền tố `/` (ví dụ: `/freeze <player>`), trong khi cấu hình thực tế tại [`AdminConfig.Prefix`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Config/AdminConfig.lua) lại là chuỗi `//`.
- **Rủi ro thực tế**:
  Roblox đã nâng cấp toàn diện sang `TextChatService`. Trên các máy chủ sử dụng giao diện chat hiện đại, sự kiện `Player.Chatted` thường xuyên bị chặn hoặc không nhận được thông điệp, khiến Admin không thể thực thi lệnh khẩn cấp. Hơn nữa, việc hiển thị sai tiền tố khiến Admin gõ nhầm lệnh và vô tình gửi lộ lệnh quản trị ra kênh chat công khai của người chơi.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  - Chuyển đổi cơ chế bắt lệnh sang `TextChatService` hoặc hỗ trợ song song.
  - Sử dụng trực tiếp biến `AdminConfig.Prefix` trong chuỗi hướng dẫn của `PrintHelp` thay vì hardcode ký tự `/`.

---

### 🟢 NHÓM LOW (Rủi ro thấp – Mã thừa và Tối ưu hóa vi mô)

---

#### 12. [LOW-01] Mã nguồn thừa (Dead Code) & Trùng lặp cấu trúc dữ liệu DataStore
- **Vị trí**: [`DataService.lua:665, 674`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Data/DataService.lua#L665) và [`DataConfig.lua:16-28`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Config/DataConfig.lua#L16-L28)
- **Phân loại**: Trụ cột 2 – Dead Code
- **Mức độ**: 🟢 **LOW**
- **Hiện trạng code**:
  - Hàm `DataService:SetMilestoneBase` hoàn toàn không được gọi ở bất kỳ đâu trong toàn bộ dự án.
  - Hàm `DataService:AddCosmetic` bị đánh dấu ghi chú là deprecated nhưng vẫn tồn tại chiếm dụng dung lượng.
  - Trong `PROFILE_TEMPLATE` của `DataConfig.lua`, dữ liệu nhiệm vụ vừa được lưu trong bảng tổng hợp `QuestData`, vừa có thêm các trường dư thừa là `DailyQuestData` và `MilestoneQuestData`.
- **Rủi ro thực tế**:
  Tạo ra rác trong bộ nhớ và gây lãng phí dung lượng lưu trữ JSON trong DataStore của mỗi người chơi.
- **Giải pháp chuẩn kiến trúc đề xuất**:
  Xóa bỏ các hàm bỏ hoang, dọn dẹp các trường trùng lặp trong mẫu cấu hình dữ liệu và viết migration script đơn giản để lược bỏ dữ liệu rác cũ.

---

#### 13. [LOW-02] Thiếu kiểm tra trạng thái lặp (Idempotency) cho `FinishGameLoading`
- **Vị trí**: [`MatchService.lua:759-763`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Match/MatchService.lua#L759-L763)
- **Phân loại**: Trụ cột 2 – An toàn mạng vi mô
- **Mức độ**: 🟢 **LOW**
- **Hiện trạng code**:
  Khi client gửi remote `FinishGameLoading`, server trực tiếp gọi `SessionService:SetGameLoaded(Player, true)` và in dòng thông báo ra console mà không kiểm tra xem người chơi này đã hoàn tất tải game trước đó hay chưa.
- **Rủi ro thực tế**:
  Client có thể vô tình hoặc cố ý spam liên tục remote này để spam nhật ký máy chủ (console log spam).
- **Giải pháp chuẩn kiến trúc đề xuất**:
  Kiểm tra `if SessionService:IsGameLoaded(Player) then return end` trước khi xử lý logic tiếp theo.

---

## 3. DANH SÁCH CÁC ĐIỂM MÂU THUẪN CẦN PHẢN BIỆN (DEBATE LIST)

Dưới đây là 4 điểm mâu thuẫn kiến trúc cốt lõi giữa phía Client và Server cần đưa ra tranh luận dứt khoát trước khi bắt tay vào triển khai tái cấu trúc:

---

### 💥 TRANH BIỆN 1: Kiến trúc Combat – Tin tưởng Client Hitbox hay Server-Authoritative Tuyệt đối?

- **Mâu thuẫn hiện tại**:
  Client hiện đang đóng vai trò "thẩm phán": Tự phát hiện va chạm qua Raycast/Touched của Tool -> Bắn tín hiệu `OnToolHit(Victim)` lên Server -> Server chỉ đo khoảng cách rồi áp dụng trạng thái đóng băng (`FreezeService`). Trong khi đó, hành động vung kiếm (`OnToolSwing`) lại bị đẩy sang một Service hoàn toàn độc lập (`IcicleService`) chỉ để phát âm thanh 3D!
- **Phản biện góc nhìn Bảo mật & Kiến trúc**:
  Thiết kế này là **sai lầm nghiêm trọng nhất** về bảo mật trong lập trình game Roblox. Việc tách rời `OnToolSwing` và `OnToolHit` biến server thành một "con rối" thụ động. Một exploiter không cần quan tâm đến vũ khí hay animation, chỉ cần bắn `OnToolHit` kèm theo UserID của toàn bộ người chơi khác trong phòng là có thể đóng băng toàn bộ server sau vài giây.
- **Đề xuất giải pháp chuẩn mực**:
  - Hợp nhất: Toàn bộ vòng đời chiến đấu phải được kiểm soát bởi một Service duy nhất (`CombatService` hoặc `FreezeService` quản lý toàn diện).
  - Vòng đời chuẩn xác:
    1. Client bấm chuột: Bắn `RequestSwing:FireServer()`.
    2. Server kiểm tra Cooldown. Nếu hợp lệ: Cấp phát một `SwingToken` có thời hạn (ví dụ: hiệu lực từ 0.15s đến 0.45s tính từ lúc vung kiếm), đồng thời phát sóng âm thanh/animation cho các client khác.
    3. Client va chạm mục tiêu: Gửi `ReportHit:FireServer(Victim, SwingToken)`.
    4. Server kiểm tra: `SwingToken` có hợp lệ không? Đã dùng chưa (chống 1 nhát chém trúng nhiều lần nếu là vũ khí đơn mục tiêu)? Vị trí mục tiêu có nằm trong góc nhìn phía trước không? Có bị cản bởi tường không? Nếu tất cả đều đạt -> Mới kích hoạt đóng băng.

---

### 💥 TRANH BIỆN 2: Lỗ hổng Trạng thái AFK (`SetAfkState`) giữa trận đấu

- **Mâu thuẫn hiện tại**:
  Remote `SetAfkState` cho phép Client tự ý gửi yêu cầu bật/tắt trạng thái AFK bất cứ khi nào người dùng tương tác với nút AFK trên giao diện. Server nhận tín hiệu và lưu trạng thái vào `SessionService`.
- **Phản biện góc nhìn Gameplay & Exploit**:
  Điều gì sẽ xảy ra nếu một người chơi đang bị rượt đuổi và sắp bị đối phương đóng băng, họ lập tức bấm nút "Bật AFK"? Hoặc một người chơi cố tình chuyển sang trạng thái AFK để được chuyển sang chế độ Khán giả (Spectate) nhằm theo dõi vị trí của đối phương rồi báo cho đồng đội qua Discord? Hiện tại, code của `MatchService` không có cơ chế loại bỏ hoặc xử thua ngay lập tức đối với người chơi tự ý đổi trạng thái AFK khi trận đấu đang ở pha `Playing`.
- **Đề xuất giải pháp chuẩn mực**:
  - Nghiêm cấm thay đổi trạng thái AFK khi trận đấu đang diễn ra: Nếu đang ở pha `Playing` hoặc `Ending`, remote `SetAfkState` phải bị từ chối hoặc chỉ ghi nhận trạng thái cho **ván đấu kế tiếp**.
  - Nếu người chơi cố tình ngắt kết nối hoặc ép kích hoạt AFK bằng script khi đang trong sân: Server phải ngay lập tức tính là bị đóng băng / xử thua và dọn dẹp nhân vật khỏi bản đồ thi đấu.

---

### 💥 TRANH BIỆN 3: Đập tan tư duy "Nhồi nhét `:Init()`" trên 16 Client Controllers

- **Mâu thuẫn hiện tại**:
  Tại sao `Main.client.lua` đã định nghĩa sẵn quy trình 2 pha rất bài bản (`Init` -> `Start`), nhưng có đến 16 Controller lại bỏ trống hoàn toàn hàm `:Start()` và dồn hết tất cả mã nguồn vào `:Init()`?
- **Phản biện góc nhìn Lập trình**:
  Đây là biểu hiện rõ nét của lối tư duy lập trình "tiện đâu viết đấy" (duct-tape engineering). Khi viết Controller mới, người lập trình chỉ viết code vào `Init()` cho nhanh, dẫn đến việc khi Controller đó cần gọi một Controller khác, Controller kia có thể chưa chạy `Init()`, gây crash game. Để sửa lỗi đó, thay vì chuyển code sang `Start()`, họ lại tiếp tục viết thêm các hàm chắp vá như `GetMenuController()` hoặc `require` lười biếng.
- **Đề xuất giải pháp chuẩn mực**:
  - Ban hành quy tắc thép:
    - **`Controller:Init()`**: Cấm tuyệt đối việc gọi Controller khác. Cấm kết nối tín hiệu từ Server (`RemoteEvent.OnClientEvent`). Chỉ được phép khởi tạo bảng dữ liệu nội bộ và bắt các sự kiện UI thuần túy (như hover nút bấm).
    - **`Controller:Start()`**: Nơi duy nhất được phép kết nối RemoteEvent và tương tác chéo với các Controller khác trong hệ thống.

---

### 💥 TRANH BIỆN 4: Quản lý vòng đời dữ liệu khi Server Shutdown – Sự thiếu vắng của `BindToClose`

- **Mâu thuẫn hiện tại**:
  Hệ thống đang phụ thuộc hoàn toàn vào giả định: "Mọi dữ liệu sẽ được lưu khi người chơi rời server (`PlayerRemoving`)".
- **Phản biện góc nhìn Toàn vẹn hệ thống**:
  Trong môi trường vận hành thực tế của Roblox, server có thể bị tắt bất ngờ bất kỳ lúc nào do: Roblox cập nhật nền tảng, nhà phát triển publish phiên bản mới và bấm nút Migrate, hoặc server bị lỗi crash. Khi đó, `PlayerRemoving` kích hoạt không đầy đủ hoặc bị bỏ qua, và Roblox chỉ cho phép tối đa 30 giây trong `game:BindToClose` để dọn dẹp. Việc `DataService` không có cơ chế `BindToClose` để gom toàn bộ dữ liệu tạm từ `QuestService` và `SessionService` đồng nghĩa với việc chấp nhận rủi ro mất dữ liệu hàng loạt của người chơi.
- **Đề xuất giải pháp chuẩn mực**:
  - `DataService` phải là nơi làm chủ vòng đời tắt của toàn server thông qua `game:BindToClose`.
  - Thiết lập cơ chế Flush dữ liệu tập trung: Khi Server chuẩn bị tắt, `DataService` phát tín hiệu khẩn cấp cho tất cả các Service con đồng bộ toàn bộ cache trên RAM về Profile, sau đó mới cho phép `ProfileService` ngắt kết nối an toàn.

---

Báo cáo này đã phản ánh toàn bộ các điểm yếu cốt lõi, không né tránh và đi thẳng vào các rủi ro kỹ thuật. Hãy phản hồi để chúng ta cùng thống nhất phương án xử lý các điểm tranh biện trên trước khi bước vào giai đoạn tái cấu trúc code!