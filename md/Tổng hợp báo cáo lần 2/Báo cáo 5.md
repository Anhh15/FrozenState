Viewed RarityConfig.lua:1-38
Viewed PlayerStateConfig.lua:1-38
Viewed TagConfig.lua:1-20
Viewed GameModeConfig.lua:1-137
Viewed AudioConfig.lua:1-255
Viewed AnimationConfig.lua:1-128
Viewed GuiConfig.lua:1-249
Viewed ItemRewardController.lua:1-100
Viewed ItemRewardController.lua:411-450
Viewed GameOverAnnouncementController.lua:1-282
Viewed ScoreBoardController.lua:1-366
Viewed PlayerStatusController.lua:1-239
Viewed GameStateController.lua:1-150
Viewed GameStateController.lua:151-272
Viewed NavigationController.lua:1-238
Viewed RoundLoadingScreenController.lua:1-253
Viewed AccoladesController.lua:1-136
Viewed MusicController.lua:1-163
Viewed GameStatisticController.lua:1-150
Searched for "132948338000932"
Searched for "[0-9]{8,}"
Viewed GameLoadingController.lua:1-150
Viewed GameLoadingController.lua:380-460
Viewed GameLoadingController.lua:500-552

# BÁO CÁO KIỂM TOÁN HỆ THỐNG & BẢO MẬT TOÀN DIỆN
**Dự án**: `FrozenState`  
**Vai trò**: Senior Roblox System & Security Auditor  
**Chế độ**: Debate & Audit Mode (Chỉ phân tích, vạch lỗi, lập luận phản biện; **Zero code modification**)

---

## PHẦN 1: BẢNG ĐÁNH GIÁ MỨC ĐỘ RỦI RO

Hệ thống mã nguồn trong `src/` hiện đang tồn tại **nhiều lỗ hổng bảo mật nghiêm trọng** cùng những **sai lầm cốt lõi trong kiến trúc Client-Server**, có thể bị khai thác để phá hủy nền kinh tế game, gây treo ván đấu (softlock) hoặc làm sập hiệu năng máy chủ (DoS).

| Mức độ | Số lượng | Tóm tắt tác động |
| :--- | :---: | :--- |
| <kbd>**CRITICAL**</kbd> | **4** | Khai thác vô hạn tiền trong vài giây, chém 360 độ không cần vung kiếm, DoS Spatial Streaming làm sập server, và Softlock ván đấu vĩnh viễn khi rơi khỏi map. |
| <kbd>**HIGH**</kbd> | **4** | Tước quyền GamePass của người dùng khi mạng chập chờn, flood RemoteEvent ghi bẩn RAM Profile, Client trở thành bóng ma bất tử qua mặt Matchmaking, và Animation đóng băng không replicate do Server Anchor. |
| <kbd>**MEDIUM**</kbd> | **5** | Race Condition hỏng GUI ngay khi load module, lạm dụng busy-wait loop `task.wait(0.05)`, phá vỡ chuẩn vòng đời Init/Start ở 16/24 Controllers, vòng lặp phụ thuộc (Circular Dependency) phải né bằng lazy-require. |
| <kbd>**LOW**</kbd> | **3** | Rải rác Magic Numbers không quy tụ về Config, thư mục rác `src/StarterPlayerScripts` sai vị trí, và không nhất quán quy ước PascalCase cho biến private. |

---

## PHẦN 2: CHI TIẾT CÁC ĐIỂM YẾU & NGUY CƠ BẢO MẬT

---

### NHÓM CRITICAL (RỦI RO CHÍ MẠNG)

#### 1. Lỗ hổng Unlimited Money Exploit trong cấu hình Nhiệm vụ
* **Vị trí**: [`QuestConfig.lua:L310-L316`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/QuestConfig.lua#L310-L316)
* **Mức độ**: <kbd>**CRITICAL**</kbd>
* **Hiện trạng & Vấn đề**: 
  Nhiệm vụ Milestone `M_PlayTime2h` có tên hiển thị *"Play for 2 hours"*, nhưng tham số yêu cầu lại được đặt là `Requirement = 15` (15 giây thay vì 7200 giây). Đồng thời cờ `Repeatable` lại được bật thành `true` với phần thưởng `Reward = 600`.
* **Kịch bản khai thác / Hậu quả**: 
  Bất kỳ người chơi nào (thậm chí không cần dùng công cụ exploit, chỉ cần chơi bình thường) cũng có thể bấm nhận thưởng 600 tiền sau mỗi 15 giây. Kẻ gian chỉ cần viết 1 dòng script auto-claim remote `ClaimQuestReward` để thu về hàng triệu Coin trong thời gian ngắn, làm sụp đổ hoàn toàn hệ thống kinh tế và cửa hàng của trò chơi.
* **Đề xuất giải pháp**:
  Sửa ngay `Requirement = 7200` và đặt `Repeatable = false`. Bất kỳ nhiệm vụ thời gian chơi nào cũng phải kiểm tra chéo với thời gian session thực tế được lưu trên Server (`SessionService`).

```lua
-- Sửa lại trong QuestConfig.lua
M_PlayTime2h = {
    Id = "M_PlayTime2h",
    Name = "Play for 2 hours",
    Category = "Milestone",
    Requirement = 7200, -- 2 giờ = 7200 giây
    Reward = 600,
    Type = "PlayTime",
    Repeatable = false, -- Milestone không được lặp lại vô hạn
},
```

---

#### 2. Khai thác chém 360 độ & Bỏ qua chuỗi hành động Swing - Hit
* **Vị trí**: [`FreezeService.lua:L479-L566`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/FreezeService.lua#L479-L566), [`IcicleService.lua:L139-L174`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/IcicleService.lua#L139-L174)
* **Mức độ**: <kbd>**CRITICAL**</kbd>
* **Hiện trạng & Vấn đề**:
  1. Server chỉ kiểm tra khoảng cách Euclid (`12 studs`) và Raycast vật cản giữa Attacker và Victim, **hoàn toàn bỏ qua góc nhìn (Facing Angle / LookVector)**.
  2. Sự kiện `OnToolHit` **không bắt buộc phải có `OnToolSwing` diễn ra trước đó**. Khi Server nhận `OnToolHit`, nếu `_AttackSessions[AttackerPlayer]` chưa tồn tại, Server tự động tạo mới một session tạm thời với `HitsRemaining = 1` thay vì từ chối request.
  3. Kiểm tra Tool hời hợt: `AttackerChar:FindFirstChild("Icicle") or AttackerChar:FindFirstChildOfClass("Tool")` cho phép bất kỳ Tool nào cũng có thể đóng băng đối thủ.
* **Kịch bản khai thác / Hậu quả**:
  Exploiter không cần trang bị Icicle, không cần vung kiếm (`OnToolSwing`), chỉ cần đứng trong bán kính 12 studs rồi gửi spam remote `OnToolHit:FireServer(Victim)` liên tục theo chu kỳ cooldown. Kẻ tấn công có thể vừa chạy trốn vừa đóng băng toàn bộ người chơi xung quanh 360 độ mà không hề quay đầu lại.
* **Đề xuất giải pháp**:
  - Bắt buộc `OnToolHit` phải nằm trong một `AttackSession` hợp lệ đã được kích hoạt trước đó bởi `OnToolSwing` (nằm trong khung thời gian cửa sổ đánh `WindupTime <= t <= WindupTime + ActiveTime`).
  - Kiểm tra góc hướng mặt: Dot product giữa `AttackerHRP.CFrame.LookVector` và vector hướng tới nạn nhân phải lớn hơn `math.cos(math.rad(MaxAttackAngle / 2))` (ví dụ: góc quét tối đa 120 độ).
  - Xác thực chính xác tên và thuộc tính của Tool đang cầm trên tay phải là Tool hợp lệ do Server cấp.

---

#### 3. DoS StreamingEngine / Làm sập Server qua `RequestSpectateTarget`
* **Vị trí**: [`MatchService.lua:L820-L872`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/MatchService.lua#L820-L872)
* **Mức độ**: <kbd>**CRITICAL**</kbd>
* **Hiện trạng & Vấn đề**:
  Khi nhận RemoteFunction `RequestSpectateTarget(TargetPlayer)`, Server lập tức gán:
  `SpectatorPlayer.ReplicationFocus = TargetHRP` mà **không hề có Cooldown, Debounce hay Rate-limit**.
* **Kịch bản khai thác / Hậu quả**:
  Spatial Streaming của Roblox dựa vào `ReplicationFocus` để tính toán tải và gỡ bỏ chunk bản đồ cho client. Một exploiter gửi remote này 60 lần mỗi giây, liên tục đổi mục tiêu giữa các người chơi ở xa nhau trên map. Server Roblox sẽ bị ép phải liên tục tính toán lại phạm vi Streaming, phân bổ vùng nhớ và gửi gói tin network liên tục, gây tụt FPS server nghiêm trọng (Spike CPU), lag nghẽn toàn bộ server và có thể làm crash instance game.
* **Đề xuất giải pháp**:
  Đặt Rate-limit / Cooldown tối thiểu `0.5s` hoặc `1.0s` cho mỗi yêu cầu đổi `ReplicationFocus` trên Server. Nếu client gửi quá tần suất cho phép, từ chối ngay lập tức.

---

#### 4. Ván đấu bị treo vĩnh viễn (Softlock) khi người chơi rơi khỏi bản đồ
* **Vị trí**: [`MatchService.lua:L729-L740`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/MatchService.lua#L729-L740), [`SessionService.lua:L178-L215`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/SessionService.lua#L178-L215)
* **Mức độ**: <kbd>**CRITICAL**</kbd>
* **Hiện trạng & Vấn đề**:
  Hệ thống loại trừ người chơi trong `MatchService` chỉ lắng nghe duy nhất một sự kiện:
  `Humanoid.Died:Connect(function() FreezeService.EliminatePlayer(Player) end)`.
  Khi nhân vật bị đẩy ngã hoặc rơi xuống vực sâu vượt qua `Workspace.FallenPartsDestroyHeight`, Roblox Engine mặc định hủy bỏ (`Destroy`) Character instance mà **không kích hoạt sự kiện `Humanoid.Died`**.
* **Kịch bản khai thác / Hậu quả**:
  Người chơi rơi khỏi map sẽ biến mất, nhưng trạng thái trong `PlayerStateHelper` vẫn giữ nguyên là `Normal` hoặc `Frozen` thay vì chuyển sang `Eliminated`. Hàm kiểm tra điều kiện kết thúc trận đấu `SessionService.CheckWinCondition()` vẫn coi người này còn sống trong trận, dẫn đến việc ván đấu không thể kết thúc, đồng hồ đếm ngược hết giờ nhưng không thể phân định thắng thua, làm toàn bộ server bị kẹt vĩnh viễn.
* **Đề xuất giải pháp**:
  Lắng nghe thêm sự kiện `Character.AncestryChanged` hoặc `Player.CharacterRemoving`. Nếu Character bị gỡ khỏi Workspace trong khi ván đấu đang diễn ra và người chơi chưa bị loại, Server phải ngay lập tức gọi `FreezeService.EliminatePlayer(Player)`.

---

### NHÓM HIGH (RỦI RO CAO)

#### 5. Khóa nhầm GamePass vĩnh viễn của người chơi khi gặp sự cố mạng
* **Vị trí**: [`ShopService.lua:L285-L315`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/ShopService.lua#L285-L315)
* **Mức độ**: <kbd>**HIGH**</kbd>
* **Hiện trạng & Vấn đề**:
  Khi kiểm tra quyền sở hữu GamePass bằng `MarketplaceService:UserOwnsGamePassAsync(UserId, PassId)`, nếu API Roblox gặp sự cố gián đoạn (timeout, HTTP 500), `pcall` trả về `Success = false`. Code hiện tại xử lý:
  ```lua
  local Success, Result = pcall(function()
      return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, PassId)
  end)
  local Owns = Success and Result or false
  _GamePassCache[Player][PassKey] = Owns -- GHI ĐÈ FALSE VÀO CACHE SUỐT SESSION!
  ```
* **Kịch bản khai thác / Hậu quả**:
  Một người chơi đã bỏ Robux mua GamePass, nhưng lúc vào server đường truyền Roblox bị chập chờn trong 1 giây. Server gán ngay `_GamePassCache = false`. Kể từ đó, toàn bộ quyền lợi GamePass của họ bị khóa hoàn toàn trong suốt buổi chơi. Người chơi sẽ tưởng game bị lỗi nuốt tiền hoặc lừa đảo.
* **Đề xuất giải pháp**:
  Không bao giờ cache giá trị `false` khi `Success == false` (lỗi mạng). Phải thực hiện retry có giãn cách (exponential backoff) hoặc giữ nguyên trạng thái chưa xác định để truy vấn lại ở lần kế tiếp.

---

#### 6. Bỏ qua Handshake `FinishGameLoading` để trở thành Spectator bất tử
* **Vị trí**: [`MatchService.lua:L63-L76`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/MatchService.lua#L63-L76), [`MatchService.lua:L758-L763`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/MatchService.lua#L758-L763)
* **Mức độ**: <kbd>**HIGH**</kbd>
* **Hiện trạng & Vấn đề**:
  Server phụ thuộc 100% vào việc Client tự giác gửi RemoteEvent `FinishGameLoading` để gán `_PlayerGameStates[Player].GameLoaded = true`. Hàm lọc danh sách người chơi hợp lệ vào ván đấu `GetAlivePlayers()` lại loại trừ bất kỳ ai có `GameLoaded == false`.
* **Kịch bản khai thác / Hậu quả**:
  Kẻ gian can thiệp client chặn không cho gửi gói tin `FinishGameLoading`. Người này vẫn load vào map, có đầy đủ Character, nhưng Server không bao giờ tính họ vào danh sách tham gia thi đấu. Họ có thể tự do đi lại phá rối mà không bao giờ bị đóng băng, không bao giờ bị loại và không thể bị thua.
* **Đề xuất giải pháp**:
  Bổ sung cơ chế Server-side Timeout (ví dụ: tối đa `5.0s` sau khi chuyển sang trạng thái Loading). Nếu Client không gửi xác nhận, Server tự động cưỡng chế chuyển trạng thái hoặc đưa người chơi về sảnh chờ (Lobby).

---

#### 7. Flood RemoteEvent `SaveSetting` gây nghẽn Server và dirty-write Profile
* **Vị trí**: [`DataService.lua:L801-L809`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/DataService.lua#L801-L809)
* **Mức độ**: <kbd>**HIGH**</kbd>
* **Hiện trạng & Vấn đề**:
  Sự kiện `SaveSetting` cho phép Client cập nhật các cấu hình người dùng (`BgmVolume`, `SfxVolume`, v.v.) vào Profile trên Server nhưng hoàn toàn không có bộ đệm (Debounce) hay giới hạn tần suất (Rate Limit).
* **Kịch bản khai thác / Hậu quả**:
  Một Client gửi vòng lặp 1000 request/giây với các giá trị ngẫu nhiên. Server phải liên tục xử lý logic ghi dữ liệu vào Profile trong RAM và broadcast ngược lại, làm nghẽn hàng đợi RemoteEvent và tiêu hao CPU của Server vô ích.
* **Đề xuất giải pháp**:
  Thiết lập Rate Limit trên Server cho mỗi Player (ví dụ: tối đa 5 lần lưu/giây hoặc debounce 0.2s). Chỉ chấp nhận lưu nếu giá trị mới khác với giá trị hiện tại.

---

#### 8. Lỗi Animation tư thế đóng băng không replicate do Server Anchor
* **Vị trí**: [`FreezeService.lua:L222`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/FreezeService.lua#L222), [`SoundController.lua:L88-L91`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/SoundController.lua#L88-L91)
* **Mức độ**: <kbd>**HIGH**</kbd>
* **Hiện trạng & Vấn đề**:
  Khi đóng băng nạn nhân, Server set `HRP.Anchored = true`. Việc này thu hồi quyền NetworkOwnership của nhân vật về Server. Trong khi đó, việc phát animation tư thế đóng băng (`PlayPoseAnimation`) lại được giao cho Client của nạn nhân thực hiện (`if VictimPlayer == LocalPlayer then PlayPoseAnimation(...) end`).
* **Hậu quả**:
  Trong kiến trúc Roblox, khi một Assembly bị Server Anchor, các AnimationTrack do Client phát cục bộ sẽ **không replicate tin cậy đến các client khác**. Hậu quả thực tế trong game: Nạn nhân bị biến thành khối băng nhưng tư thế bên trong bị đứng hình ở trạng thái Idle mặc định thay vì tư thế bị đóng băng đặc trưng.
* **Đề xuất giải pháp**:
  Server phải chịu trách nhiệm load và phát AnimationTrack trên `Humanoid.Animator` của nạn nhân (hoặc replicate rõ ràng một Pose Snapshot CFrame tới toàn bộ Client).

---

### NHÓM MEDIUM (LỖI THIẾT KẾ KIẾN TRÚC & HIỆU NĂNG)

#### 9. Bug nghiêm trọng: Truy xuất GUI ở Top-Level Scope (Module Load Time)
* **Vị trí**: 
  - [`InventoryController.lua:L45-L62`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/InventoryController.lua#L45-L62)
  - [`ShopController.lua:L47-L70`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/ShopController.lua#L47-L70)
  - [`ProfileController.lua:L47-L63`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/ProfileController.lua#L47-L63)
* **Mức độ**: <kbd>**MEDIUM**</kbd>
* **Hiện trạng & Vấn đề**:
  Các Controller trên gọi `GuiHelper.GetScreenGui("Menu")` ngay ở phần khai báo biến đầu file (khi module được `require`). Tại thời điểm Client bắt đầu load script, `PlayerGui` thường chưa hoàn tất replicate toàn bộ các ScreenGui con.
* **Hậu quả**:
  `GetScreenGui("Menu")` trả về `nil`. Các biến `_ShopGui`, `_InventoryGui`, `_ProfileGui` bị gán `nil` vĩnh viễn. Khi hàm `Init()` hoặc `Start()` chạy, câu lệnh kiểm tra bảo vệ `if not _ShopGui then return end` âm thầm hủy bỏ toàn bộ hoạt động của Controller. Người chơi bấm nút mở Shop/Inventory sẽ hoàn toàn không có phản hồi.
* **Đề xuất giải pháp**:
  Tuyệt đối không truy xuất đối tượng trong `PlayerGui` ở top-level scope. Toàn bộ logic tìm kiếm UI phải được dời vào hàm `Init()` hoặc `Start()` sau khi đã đảm bảo GUI đã sẵn sàng qua `WaitForChild`.

---

#### 10. Vi phạm quy chuẩn vòng đời Init/Start tại 16/24 Controllers
* **Vị trí**: 
  - [`HighlightController.lua:L28`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/HighlightController.lua#L28)
  - [`SoundController.lua:L22`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/SoundController.lua#L22)
  - [`HotbarController.lua:L51`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/HotbarController.lua#L51)
  - [`MenuController.lua:L40`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/MenuController.lua#L40)
  - *(Và 12 controller khác: GameStatisticController, ModeAnnouncementController, AccoladesController, v.v.)*
* **Mức độ**: <kbd>**MEDIUM**</kbd>
* **Hiện trạng & Vấn đề**:
  Hệ thống `ServiceLoader` được xây dựng theo chuẩn 2 pha rõ ràng: Pha 1 gọi `:Init()` cho toàn bộ module để setup state cơ bản, Pha 2 gọi `:Start()` để kết nối sự kiện và tương tác chéo. Tuy nhiên, **16 trên tổng số 24 Controllers chỉ có `:Init()` mà không có `:Start()`**. Toàn bộ logic kết nối Remote, lắng nghe UserInputService, và gọi require chéo các controller khác bị nhồi nhét hết vào `:Init()`.
* **Hậu quả**:
  Gây ra hiện tượng Race Condition khi Controller A trong lúc chạy `Init()` lại đi gọi method của Controller B trong khi Controller B thậm chí còn chưa được `ServiceLoader` chạy tới `Init()`.
* **Đề xuất giải pháp**:
  Chuẩn hóa toàn bộ 24 Controller: `Init()` chỉ khởi tạo biến nội bộ; chuyển toàn bộ `Connect()`, `FireServer()`, và tương tác chéo sang `Start()`.

---

#### 11. Lạm dụng Busy-Wait Loop `task.wait(0.05)` thay vì Event-Driven
* **Vị trí**: [`PlayerDataController.lua:L117-L119, L136-L138`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/PlayerDataController.lua#L117-L119)
* **Mức độ**: <kbd>**MEDIUM**</kbd>
* **Hiện trạng & Vấn đề**:
  Hàm `WaitForData()` và `RefreshData()` sử dụng vòng lặp:
  ```lua
  while not _isDataLoaded do
      task.wait(0.05)
  end
  ```
  Trong khi ngay chính Controller này đã tạo sẵn một `_dataLoadedBindable = Instance.new("BindableEvent")`!
* **Hậu quả**:
  Lãng phí chu kỳ xử lý của Task Scheduler, biến kiến trúc hướng sự kiện thành cơ chế polling lạc hậu. Nếu dữ liệu gặp sự cố không load được, luồng này sẽ treo vĩnh viễn và liên tục đánh thức mỗi 50ms.
* **Đề xuất giải pháp**:
  Sử dụng `_dataLoadedBindable.Event:Wait()` kèm theo timeout an toàn:
  ```lua
  if not _IsDataLoaded then
      _DataLoadedBindable.Event:Wait()
  end
  ```

---

#### 12. Dữ liệu kế thừa (Legacy Junk) tồn đọng trong Profile Template
* **Vị trí**: [`DataService.lua:L30, L48-L52`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/DataService.lua#L30)
* **Mức độ**: <kbd>**MEDIUM**</kbd>
* **Hiện trạng & Vấn đề**:
  Trong `PROFILE_TEMPLATE` vẫn lưu trữ các trường:
  - `OwnedCosmetics = {}` (trong khi game đã tách ra thành `OwnedIcicles` và `OwnedBlocks`).
  - `DailyQuestData = {}`, `MilestoneQuestData = {}` (trong khi Quest System đã được nâng cấp lên `QuestData = { Active = {}, Completed = {} }`).
* **Hậu quả**:
  Làm phình to kích thước Document trong DataStore của người chơi, tăng dung lượng truyền tải mạng và gây nhầm lẫn nghiêm trọng cho bất kỳ lập trình viên nào bảo trì hệ thống sau này.
* **Đề xuất giải pháp**:
  Viết migration script để dọn sạch các trường legacy này khỏi ProfileStore khi người chơi đăng nhập.

---

#### 13. Phụ thuộc vòng (Circular Dependency) né tránh bằng Lazy-Require
* **Vị trí**: Rải rác trong `MenuController.lua`, `NavigationController.lua`, `ShopService.lua`.
* **Mức độ**: <kbd>**MEDIUM**</kbd>
* **Hiện trạng & Vấn đề**:
  Xuất hiện hàng loạt hàm dạng `GetMenuController()`, `GetNavigationController()` gọi `require` lặp đi lặp lại bên trong các function runtime để tránh lỗi Circular Dependency giữa các Controller UI.
* **Hậu quả**:
  Phản ánh sự phân tầng kiến trúc (Layering) bị lỗi. UI Controller cấp thấp và cấp cao đang phụ thuộc hai chiều vào nhau thay vì giao tiếp qua Event Bus hoặc Signal Pattern.
* **Đề xuất giải pháp**:
  Sử dụng mô hình Observer / BindableEvent trung gian để các Controller phát tín hiệu mở/đóng tab thay vì trực tiếp require và điều khiển lẫn nhau.

---

### NHÓM LOW (KHÔNG NHẤT QUÁN & HARDCODE)

#### 14. Magic Numbers rải rác ngoài Config
* **Vị trí**:
  - [`QuestController.lua:L66-L67`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/QuestController.lua#L66-L67): Hardcode `TweenInfo.new(0.25, ...)` và độ trễ `0.2`.
  - [`FreezeService.lua:L500-L528`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/FreezeService.lua#L500-L528): Hardcode fallback `0.8`, `0.4`, `1.5`.
  - [`QuestService.lua:L151, L208`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Server/QuestService.lua#L151): Hardcode giá trị cơ sở hoàn tiền `1000`.
  - [`GuiAnimConfig.lua:L137`](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GuiAnimConfig.lua#L137): Hardcode SoundId `132948338000932` trực tiếp, không khai báo trong `AudioConfig.lua` khiến asset không bao giờ được preload.
* **Mức độ**: <kbd>**LOW**</kbd>
* **Đề xuất giải pháp**: Di dời toàn bộ các hằng số này về đúng file Config tương ứng (`EconomyConfig`, `GuiAnimConfig`, `AudioConfig`).

---

#### 15. Tồn tại thư mục rác sai vị trí tại root `src/`
* **Vị trí**: Thư mục rỗng `src/StarterPlayerScripts/` nằm cạnh `src/StarterPlayer/StarterPlayerScripts/`.
* **Mức độ**: <kbd>**LOW**</kbd>
* **Đề xuất giải pháp**: Xóa bỏ thư mục `src/StarterPlayerScripts/` thừa này để tránh gây hiểu nhầm khi đồng bộ Rojo.

---

#### 16. Vi phạm quy ước đặt tên PascalCase
* **Vị trí**: Rải rác khắp codebase (`_isFrozenState`, `_iceBlocks`, `_sessionStart`, `_currentModeKey`, `_questGui`).
* **Mức độ**: <kbd>**LOW**</kbd>
* **Hiện trạng & Vấn đề**:
  Quy tắc dự án yêu cầu: *"100% PascalCase và tiếng Anh cho mọi biến và hàm"*. Tuy nhiên, codebase đang bị lai tạp giữa `_camelCase` và `_PascalCase` ở các biến private cấp module.
* **Đề xuất giải pháp**: Thống nhất chuyển đổi toàn bộ sang `_PascalCase` (ví dụ: `_IsFrozenState`, `_IceBlocks`, `_SessionStart`).

---

## PHẦN 3: DANH SÁCH CÁC ĐIỂM MÂU THUẪN CẦN PHẢN BIỆN (DEBATE LIST)

Dưới đây là 5 mâu thuẫn kiến trúc cốt lõi mà tôi phản bác và yêu cầu xem xét lại trước khi bắt tay vào triển khai code:

---

### 1. Kiến trúc Hitbox: Client-Authoritative ngây thơ hay Server-Side Hitbox?
* **Điểm phản bác**:
  Code hiện tại cho Client chạy Raycast cục bộ rồi gọi `OnToolHit:FireServer(Victim)`. Server sau đó kiểm tra lại khoảng cách 12 studs và raycast. Thiết kế này tạo ra một "ảo tưởng an toàn" (False sense of security).
  - Khoảng cách 12 studs là quá lớn đối với vũ khí cận chiến.
  - Server không kiểm tra góc nhìn, không kiểm tra độ trễ mạng (Ping/Latency Compensation).
  - Hacker có thể đứng yên và gửi Remote đóng băng bất kỳ ai đi ngang qua lưng mình.
* **Lập luận giải pháp**:
  Cần loại bỏ hoàn toàn việc Client quyết định trúng đích. Client chỉ gửi `OnToolSwing`. Server sẽ ghi nhận thời điểm bắt đầu vung kiếm, sau đó Server tự thực hiện **Shapecasting (Spatial Query / GetPartBoundsInBox)** tại thời điểm `ActiveTime` theo đúng hướng nhìn của nhân vật. Đây là cách duy nhất triệt tiêu hoàn toàn Reach Hack và 360-degree Hit.

---

### 2. Sự phụ thuộc ngớ ngẩn vào Handshake `FinishGameLoading` từ Client
* **Điểm phản bác**:
  Tại sao Server phải "ngồi chờ" một Client không đáng tin cậy gửi lời nhắn *"Tôi đã load xong"* thì mới đưa họ vào game? Nếu Client cố tình không gửi, họ trở thành bóng ma bất tử. Nếu mạng của một người chơi bị lag 10 giây, toàn bộ người chơi khác trong server phải chờ đợi hoặc ván đấu bắt đầu trong tình trạng thiếu người.
* **Lập luận giải pháp**:
  Server phải là cơ quan có thẩm quyền duy nhất (Server Authority). Khi Server quyết định bắt đầu ván đấu, Server gửi dữ liệu map cho toàn bộ Client và kích hoạt một bộ đếm ngược cứng (Hard Countdown) trên Server (ví dụ: tối đa 5 giây). Hết 5 giây, bất kỳ ai chưa sẵn sàng sẽ tự động bị chuyển thành Khán giả (Spectator) và ván đấu diễn ra bình thường. Không để Client nắm quyền quyết định nhịp độ trận đấu.

---

### 3. Vòng đời "Giả cầy": Tại sao xây dựng `ServiceLoader` nhưng lại bỏ qua `Start()`?
* **Điểm phản bác**:
  Hệ thống đã viết sẵn `ServiceLoader` hỗ trợ 2 giai đoạn: `Init()` rồi mới đến `Start()`. Đây là một kiến trúc chuẩn mực để chống Circular Dependency và Race Condition. Thế nhưng **16/24 Controllers hoàn toàn phớt lờ `Start()`**, nhét toàn bộ logic vào `Init()`. Sau đó, vì gặp lỗi truy xuất lẫn nhau, các lập trình viên lại chữa cháy bằng cách viết các hàm "lazy require" (`GetMenuController()`) bên trong logic bấm nút.
* **Lập luận giải pháp**:
  Đây là biểu hiện của việc viết code chắp vá. Bắt buộc phải thực hiện đúng quy chuẩn:
  - `Init()`: Khởi tạo bảng, state mặc định, preload asset, không được phép gọi method của Controller khác.
  - `Start()`: Bắt đầu kết nối RemoteEvent, UserInputService, kích hoạt GUI và gọi tương tác giữa các Controller.

---

### 4. Triết lý Cache GamePass: Đánh đổi doanh thu lấy sự tiện lợi lập trình?
* **Điểm phản bác**:
  Trong `ShopService`, việc gom `Success and Result or false` rồi lưu vào `_GamePassCache` là một sai lầm chết người trong game thương mại. Lỗi mạng Roblox API là chuyện xảy ra hàng ngày. Cache `false` đồng nghĩa với việc bạn vừa cướp đi món hàng mà người chơi đã trả tiền thật để mua, khiến họ phẫn nộ và đánh giá 1 sao cho game.
* **Lập luận giải pháp**:
  Cache chỉ được lưu khi và chỉ khi kết quả kiểm tra thành công (`Success == true`). Nếu API thất bại, tuyệt đối không lưu kết quả `false`. Lần kế tiếp người chơi sử dụng tính năng GamePass, hệ thống phải thực hiện truy vấn lại.

---

### 5. Xung đột triệt để giữa Server-Anchored và Client-Animation
* **Điểm phản bác**:
  Khi đóng băng, Server set `HRP.Anchored = true` (để nhân vật không bị trôi/văng do vật lý), nhưng lại để Client nạn nhân tự play animation đóng băng. Khi RootPart bị Anchor từ phía Server, cơ chế Replicate Animation của Roblox Engine từ Client lên Server bị vô hiệu hóa hoặc chập chờn đối với các Client khác.
* **Lập luận giải pháp**:
  Hoặc là Server trực tiếp load và play AnimationTrack trên Animator của nạn nhân, hoặc Server giữ `Anchored = false` và cố định nhân vật bằng `LinearVelocity` / `AlignPosition` với lực cực đại (`Force = math.huge`), cho phép chuyển động vật lý bị khóa nhưng Animation của Client vẫn replicate mượt mà 100% cho mọi người chơi trong phòng.