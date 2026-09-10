# GuiControllers
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống điều phối giao diện sảnh, menu và chuyển cảnh (MenuController, NavigationController, GameStateController, GameLoadingScreen, RoundLoadingScreen, ModeAnnouncement, GameOverAnnouncement và các Menu con).
> Cập nhật lần cuối: 10-09-2026

---

## Kiến trúc

### 1. Phân tách Trách nhiệm Tập Trung: NavigationController & MenuController (Decoupled Lobby UI)
- **Chi tiết:** Tách hoàn toàn trách nhiệm quản lý `NavigationButtons` và `MenuGui` ra khỏi `GameStateController`:
  - `GameStateController`: Chuyên trách điều khiển HUD thi đấu (Timer, Phase banner, Frozen indicator) và thông báo chuyển phase trận đấu.
  - `NavigationController`: Chuyên trách quản lý ScreenGui `NavigationButtons`, gắn SFX và animation scale tập trung cho toàn bộ nút bấm sảnh, quản lý hiển thị số dư `Cash`.
  - `MenuController`: Đóng vai trò UI Coordinator độc quyền cho toàn bộ các cửa sổ trong `MenuGui` (`Shop`, `Inventory`, `Profile`, `Quest`), điều phối ẩn/hiện thanh nút điều hướng khi mở/đóng menu.
- **Triệt tiêu Circular Dependency:** Trước đây `GameStateController` phải lazy-require tới 7 controller con để ép đóng menu khi vào trận. Với mô hình mới, `GameStateController` chỉ cần gửi 1 lệnh duy nhất: `MenuController.SetVisible(false)` và `NavigationController.SetVisible(false)`. Các controller menu con chỉ đăng ký với `MenuController`, loại bỏ hoàn toàn việc require chéo lẫn nhau.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### 2. Quản lý Hiển thị Độc quyền (Mutual Exclusion) & Tích hợp ExcludedFrame
- **Chi tiết:** Tại một thời điểm chỉ có duy nhất 1 menu tab được phép mở trong `MenuGui`.
- **ExcludedFrame:** Khi một Frame (như `SpectateGui` trước đây) cần mở mà không bị các hàm dọn dẹp đóng nhầm, các hàm `HideAllFrames` và `CloseAll` của `MenuController` hỗ trợ tham số `ExcludedFrame` để bỏ qua việc ẩn frame đó. Khi mở bất kỳ tab menu chính nào, hệ thống chủ động gọi đóng spectate để giải phóng camera.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua)

### 3. Điều phối Hoạt họa Popup Tập Trung qua MenuController
- **Chi tiết:** Chuyển giao 100% quyền quản lý `Frame.Visible` và hiệu ứng `PopOpen`/`PopClose` cho `MenuController`.
- **Nguyên lý đơn nhiệm:** Hàm `Open()`/`Close()` của các controller con (`ShopController`, `InventoryController`, `ProfileController`, `QuestController`) không trực tiếp bật/tắt `Visible`, mà chỉ thuần túy làm nhiệm vụ dọn dẹp hoặc nạp dữ liệu (clear list, clean viewport, load data, bind item click).
- **Fast Switch:** Khi người chơi chuyển đổi nhanh giữa các tab menu, `MenuController` lập tức hủy tween đang chạy và ẩn ngay tab cũ để bung tab mới tức thì, tránh độ trễ tích lũy.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### 4. Quản lý Hiển thị GUI theo Phase và Trạng thái Tham gia Trận (Spectator-Aware)
- **Chi tiết:** Phân chia giao diện thành 2 nhóm rõ rệt:
  - **Lobby GUI** (`Menu`, `NavigationButtons`): Sử dụng kiểm tra 2 tầng: (1) Nếu `PlayerStateHelper.IsInMatch(LocalPlayer) == false` (Spectator ngoài trận) -> Luôn hiển thị Lobby GUI; (2) Nếu `IsInMatch == true` -> Tự động ẩn khi vào các phase gameplay (`Ready`, `InGame`, `GameOver`).
  - **Gameplay GUI** (`InGameGui`, `GameStatistic`): Chỉ kích hoạt trong thời gian thi đấu hoặc hiển thị kết quả cuối trận.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)

### 5. Hệ thống Chuyển cảnh RoundLoadingScreen & Thông báo ModeAnnouncement
- **Chi tiết:**
  - `RoundLoadingScreenController`: Quản lý Frame `Special/RoundLoadingScreen` để che giấu quá trình tải map và spawn nhân vật phía sau màn hình đen mượt mà (`FadeIn` -> `FadeOut`).
  - `ModeAnnouncementController`: Quản lý Frame `Special/ModeAnnouncement`. Khi là vòng đặc biệt (Special Round như Chaos, EternalFreeze), controller kích hoạt hiệu ứng Fade-in tiêu đề in hoa kèm âm thanh SFX đặc thù trước khi kích hoạt `RoundLoadingScreen`.
  - Phía Server (`MatchService.RunSetup`) tự động chờ thời lượng trình chiếu của thông báo để đảm bảo đồng bộ tuyệt đối giữa Client và Server.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### 6. Đồng bộ Hiển thị Nhãn Trang bị Vật phẩm (EquippedText Indicator)
- **Chi tiết:** Trong `InventoryController`, khi render danh sách vật phẩm theo tab ("Icicle" / "Block"), controller đối chiếu ID với `PlayerDataController.GetData()` để bật `.Visible = true` cho nhãn `EquippedText` trên ô vật phẩm khớp ID.
- **In-place Update:** Khi người chơi bấm nút Equip thành công, hàm `UpdateEquippedTags()` duyệt danh sách `ScrollingFrame` hiện có để cập nhật lại trạng thái hiển thị nhãn ngay lập tức mà không cần xóa và render lại toàn bộ danh sách.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua)

### 7. Kiến trúc Màn hình Khởi động Game & Cơ chế Cổng Thời gian Nạp Tiến độ Kép (GameLoadingController & Time-Gated Preload Engine)
- **Chi tiết:** Màn hình khởi động game ban đầu (`GameLoadingScreen`) phối hợp hoạt ảnh giao diện và nạp trước tài nguyên:
  - *Dots Wave Animation*: Sử dụng `UIScale` điều phối sóng hình sin gối đầu liên tục cho 3 Dot với `UIAspectRatioConstraint` ($1:1$) chống méo dẹt trên màn hình $16:9$.
  - *Title Water-Fill & Dynamic Scale*: Dùng `UIGradient.Transparency` theo chiều dọc kết hợp `UIScale` dâng từ $1.0 \to 1.4$.
  - *Cổng thời gian nạp tiến độ kép (Time-Gated Dual Progress)*:
    $$\text{ActualProgress} = \min(\text{AssetProgress}, \text{TimeProgress})$$
    với $\text{TimeProgress} = \min\left(1.0, \frac{\text{os.clock}() - \text{\_loadStartTime}}{\text{MinLoadingDuration}}\right)$. Giữ thời gian tối thiểu ($2.5\text{s}$) khi cache tức thì nhưng không làm nghẽn khi tải chậm.
  - *Pha kết thúc (Curtain Split)*: Chia đôi 2 container độc lập (`UpperContainer` trượt lên $-0.65$, `LowerContainer` trượt xuống $+0.65$) mở màn hình sảnh.
- **File liên quan:** [GameLoadingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 8. Điều Phối Thông Báo Kết Thúc Trận Đấu (GameOverAnnouncementController & Symmetric Animation Sequence)
- **Chi tiết:** Quản lý Frame `Special/GameOverAnnouncement` thông báo kết quả ván đấu ngay tại giây thứ 0 của phase `GameOver` (khi người chơi còn trong map thi đấu):
  - *Truyền dữ liệu sớm:* `MatchService` đóng gói `WinnerInfo` (`WinTeam` / `WinPlayer`) gửi kèm trong `UpdateGameStateEvent` tại giây 0 của `GameOver`.
  - *Chuỗi hoạt ảnh đối xứng (Symmetric Sequence):*
    - **Pha Mở:** `Background` mở rộng ngang từ tâm sang 2 bên (`Split`, $Size.X: 0 \to \text{BaseWidth}$) $\rightarrow$ `AnnouncementText` bay vút (`Fly In`, $Y: 2.0 \to \text{BasePos}$) vào giữa nền.
    - **Pha Đóng:** `AnnouncementText` bay vút lên đỉnh màn hình (`Fly Out`, $Y \to -1.0$) $\rightarrow$ Ngay sau đó `Background` co ngang về tâm ($Size.X \to 0$).
  - *Dynamic RichText & Safe UTF-8 Truncate:* Format màu tương đối (Xanh nếu thắng, Đỏ nếu thua, Trắng nếu Spectator, Vàng Kim `#FFD700` cho FFA). Sử dụng `GuiHelper.TruncateText` cắt chuỗi an toàn bằng `utf8` ($\le 15$ ký tự) *trước khi* đưa vào thẻ `<font>` để chống lỗi hỏng thẻ XML.
- **File liên quan:** [GameOverAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameOverAnnouncementController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 9. Chuyển Đổi Danh Sách Rương Sang 2D & Khai Tử Lazy Render Viewport Trong Shop
- **Chi tiết:** Trước đây, `ShopController` áp dụng cơ chế Lazy Render trì hoãn nạp mô hình 3D (`_LazyRenderQueue`, lắng nghe `CanvasPosition` của `ChestScroll`) để tránh giật lag khi danh sách chứa nhiều `ViewportFrame` 3D.
- **Khai tử toàn diện:** Khi rương được chuẩn hóa hiển thị bằng 2D `ImageLabel` (**`ChestIcon`**) qua `ChestConfig.GetChestIcon`, 100% tài nguyên card và item previews được nạp tức thì trong $0\text{ms}$ (1 Draw Call). Toàn bộ hệ thống hàng đợi Lazy Render, kết nối scroll `_ScrollConn`, hàm `CheckLazyQueue`, cấu hình `LazyRenderBuffer`, và các phụ thuộc 3D (`ViewportManager`, `ChestsFolder`) trong `ShopController` đã được gỡ bỏ hoàn toàn, đồng bộ với kiến trúc 2D của `InventoryController`.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ChestConfig.lua](../../src/ReplicatedStorage/Shared/Config/ChestConfig.lua), [ShopConfig.lua](../../src/ReplicatedStorage/Shared/Config/ShopConfig.lua)

### 10. Điều Phối Menu Setting Đa Section & Đồng Bộ Dữ Liệu Bền Vững (SettingController, Stepped Sliders & Drag-Ended Save)
- **Chi tiết:** Quản lý Frame `Menu/Setting` với các phân mục `GameplaySection` (AFK Toggle) và `SoundSection` (4 Sliders: `MasterRow`, `MusicRow`, `SFXRow`, `UIRow`):
  - *Stepped Slider Engine*: Tích hợp `SliderHelper` điều khiển 11 nấc vạch chia ($0\%, 10\%, \dots, 100\%$), phát âm thanh tick nhẹ khi nhảy nấc.
  - *Selective AutoBind & SFX Độc quyền*: Gọi `GuiHelper.SetIgnoreAutoBind` trên container `Config` và các thanh `SlideBar` để loại bỏ SFX/Scale mặc định của hệ thống GUI chung.
  - *Phân luồng Đồng bộ Kép (Dual Sync Flow)*:
    - **Local Real-time**: Khi đang kéo núm trượt, cập nhật `SoundGroup.Volume` tức thì ($0\text{ms}$).
    - **Server Debounced Save**: Chỉ kích hoạt RemoteEvent `SaveSetting` khi người chơi thả tay khỏi chuột/màn hình (`InputEnded`), triệt tiêu hoàn toàn nguy cơ spam network.
  - *Vòng đời nạp dữ liệu*: Đọc `Settings` từ `PlayerDataController.GetData()` lúc vào game và tự động làm mới vị trí núm trượt trong `OpenSetting()`.
- **File liên quan:** [SettingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua), [SliderHelper.lua](../../src/ReplicatedStorage/Shared/Tools/SliderHelper.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### 11. Điều Phối Nút Hành Động Theo Ngữ Cảnh Quyền Sở Hữu & Tab (Contextual Action Button Visibility Pattern)
- **Chi tiết:** Quản lý các nút hành động đặc quyền (như `ResetButton` làm mới Daily Quest) nằm bên trong container danh sách:
  - *Bộ lọc hiển thị đa chiều (Contextual Visibility)*: Nút chỉ `Visible = true` khi thỏa mãn đồng thời: (1) Đang ở tab phù hợp (`_currentTab == "Daily"`), và (2) Người chơi sở hữu GamePass (`OwnsQuestPass == true`).
  - *Tự động ẩn an toàn*: Khi chuyển tab (sang `Milestone`) hoặc khi dữ liệu xác nhận chưa sở hữu GamePass, nút lập tức ẩn hoàn toàn để tránh gây nhầm lẫn về UX.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [ProductConfig.lua](../../src/ReplicatedStorage/Shared/Config/ProductConfig.lua)

### 12. Kiến trúc Khởi Tạo GUI Trì Hoãn Trong Vòng Đời Controller (Deferred GUI Initialization Pattern)
- **Chi tiết:** Mọi thao tác truy xuất và gán biến DOM/GUI elements (`PlayerGui`, `ScreenGui`, `Frame`, `TextLabel`, `Button`) **tuyệt đối không được thực thi tại Module Scope** (bên ngoài các hàm của ModuleScript).
- **Vòng đời chuẩn hóa:** Module scope chỉ khai báo các biến cục bộ bằng `nil`. Toàn bộ việc truy xuất `WaitForChild` chỉ được thực hiện bên trong phương thức `:Init()`, sử dụng tham số thời gian chờ `GuiConfig.Timeouts.DefaultWaitForGui` (10s) kết hợp nil-guards an toàn. Mô hình này bảo đảm luồng `require()` của bootloader không bao giờ bị nghẽn (Zero Boot Deadlock) kể cả khi assets màn hình tải chậm.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 13. Kiến Trúc Khởi Động Client Độc Lập & Cách Ly Lỗi (Client Bootloader Fault Isolation Pattern)
- **Chi tiết:** Thay vì gọi trực tiếp phương thức `Init()` tuần tự trần trụi, `Main.client.lua` định nghĩa mảng `CONTROLLERS_ORDER` và duyệt qua từng Controller bằng khối bọc `pcall`. Nếu một Controller (đặc biệt là các module hiệu ứng phụ như Accolades) phát sinh ngoại lệ runtime, lỗi được cô lập và ghi log cảnh báo chi tiết mà không làm gián đoạn luồng khởi tạo của các Controller trọng yếu đứng sau (`SettingController`, `HotbarController`, `RoundLoadingScreenController`). Mô hình này đảm bảo tính nhất quán kiến trúc với `ServiceLoader` 2 pha phía Server.
- **File liên quan:** [Main.client.lua](../../src/StarterPlayer/StarterPlayerScripts/Main.client.lua), [ServiceLoader.lua](../../src/ServerScriptService/Services/ServiceLoader.lua)

### 14. Kiến Trúc Vòng Đời 2 Pha (2-Phase Lifecycle) Toàn Diện & Triệt Tiêu Antipatterns Trong Client Controllers
- **Chi tiết:** Đồng bộ 100% cho toàn bộ 24 Controller phía Client:
  - **Pha 1 (`:Init()`)**: Khởi tạo state nội bộ, resolve DOM/GUI an toàn (`WaitForChild` có timeout), gán nil-guards, bind sự kiện click nội bộ của UI. Tuyệt đối **cấm** kết nối `RemoteEvent` và **cấm** gọi/giao tiếp liên Controller.
  - **Pha 2 (`:Start()`)**: Nạp trực tiếp các Controller phụ thuộc vào biến module scope (`_MenuController = require(...)`), thực hiện đăng ký dịch vụ (`MenuController.RegisterTab`), kết nối toàn bộ `RemoteEvent.OnClientEvent`, `UserInputService`, và các observer `PlayerStateHelper`.
- **Triệt tiêu Antipatterns**: Xóa bỏ hoàn toàn cơ chế lazy getter rải rác (`GetMenuController`, `GetNavigationController`, v.v.) và cấm tự `require(script)`. `Main.client.lua` duyệt mảng `CONTROLLERS_ORDER` chạy trọn vẹn pha 1 (`Init`) cho toàn bộ 24 controllers trước khi bước sang pha 2 (`Start`).
- **File liên quan:** [Main.client.lua](../../src/StarterPlayer/StarterPlayerScripts/Main.client.lua), [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [SettingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua)

### 15. Cơ Chế Điều Phối & Đồng Bộ Trạng Thái Huy Hiệu Nhiệm Vụ Đa Điểm Kích Hoạt (Quest Notification Sync Engine)
- **Chi tiết:** Thiết lập kênh giao tiếp hướng sự kiện giữa `QuestController` và `NavigationController` để quản lý huy hiệu `NotificationImage` trên nút `Quest`:
  - *Đánh giá Trạng thái*: `QuestController.HasClaimableQuest` duyệt mảng `Daily` và `Milestone`, xác định xem có quest nào `(not Claimed) and (Completed or Progress >= Requirement)`.
  - *Đa điểm Kích hoạt (Multi-trigger)*: Tự động đánh giá ngầm và phát tín hiệu `NavigationController.SetQuestNotification(HasClaimable)` tại 4 thời điểm then chốt: (1) Ngay khi vào game qua `PlayerDataController.OnDataLoaded`; (2) Sau mỗi lần nhận thưởng thành công trong `ClaimQuest`; (3) Khi người chơi đóng cửa sổ Quest (`CloseQuest`); (4) Khi kết thúc ván đấu trở về sảnh (`UpdateGameState` phase `"Lobby"`).
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Xung đột Quyền Điều khiển Visible làm Ngắt Cụt Animation Đóng Menu
- **Vấn đề:** Khi `MenuController` gọi `PopClose` (cần ~0.2s để thu nhỏ `UIScale`), nếu controller con tự ý set `Frame.Visible = false` ngay lập tức, animation đóng sẽ bị ngắt cụt, làm mất hiệu ứng thị giác hoặc kẹt trạng thái khi mở lại.
- **Giải pháp:** Tách bạch hoàn toàn: Controller con không được can thiệp vào thuộc tính `Visible` của Frame gốc. Toàn bộ việc ẩn/hiện và chạy tween do `MenuController` đảm nhiệm.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua)

### 2. Mất Thanh Nút NavigationButtons khi Mở Menu Trước Khi Vào Trận
- **Vấn đề:** Người chơi mở Menu ở Sảnh rồi vào trận mà không chủ động đóng lại. Khi hết trận quay về Sảnh (`Intermission`), thanh nút `NavigationButtons` biến mất hoàn toàn.
- **Nguyên nhân:** Khi chuyển phase sang `Ready`, `MenuController.CloseAll()` đóng menu nhưng không kích hoạt lệnh khôi phục hiển thị cho container `Buttons`.
- **Giải pháp:**
  1. Trong `MenuController.CloseAll()`, tự động gọi `NavCtrl.SetButtonsContainerVisible(not IsSpectating)`.
  2. Trong `NavigationController.SetVisible()`, bổ sung phòng thủ tự động bật `ButtonsContainer.Visible = true` khi không có menu tab nào đang mở (`_activeTab == nil`).
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua)

### 3. Bỏ Sót Sự Kiện SFX khi Nút Bấm Lồng Sâu trong Container Con
- **Vấn đề:** Khi tái cấu trúc các nút điều hướng chuyển vào container con lồng sâu (như `Buttons/Extra/Profile`), nút bấm bị mất hiệu ứng âm thanh click và hover chuột.
- **Nguyên nhân:** Mã nguồn cũ duyệt qua `Container:GetChildren()`, chỉ kiểm tra con cấp 1 trực tiếp. Nút nằm ở cấp sâu hơn bị bỏ qua.
- **Giải pháp:** Sử dụng duyệt đệ quy `Container:GetDescendants()` kết hợp kiểm tra `Descendant:IsA("GuiButton")` để gắn sự kiện cho toàn bộ các nút bất kể độ sâu phân cấp cây UI.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua)

### 4. FindFirstChild Thất Bại Silent khi Tìm Element GUI qua Frame Trung Gian
- **Vấn đề:** Tìm kiếm element qua Frame trung gian (ví dụ `ItemPreview:FindFirstChild("BuyButton", true)`) trả về `nil` khi cấu trúc phân cấp thực tế trong Studio bị thay đổi, dẫn đến sự kiện click không phản hồi mà không ném lỗi runtime.
- **Giải pháp:** Tìm trực tiếp từ root card với `Card:FindFirstChild("ElementName", true)` (tìm kiếm đệ quy từ gốc thẻ) thay vì phụ thuộc vào các Frame trung gian.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### 5. Lệch Nhịp Phase Setup giữa Server và Client khi Trình Chiếu Special Round
- **Vấn đề:** Khi bắt đầu Special Round có thông báo `ModeAnnouncement` (4.0s), Server chỉ chờ 1.5s rồi lập tức teleport người chơi và chuyển phase `Ready`, làm đứt đoạn thông báo của người chơi.
- **Giải pháp:** Trong `MatchService.RunSetup`, kiểm tra `GameModeHelper.IsSpecialRound(ModeKey)` và gọi `task.wait(GameConfig.GUI.ModeAnnouncement.DisplayDuration)` để Server và Client đồng bộ nhịp thời gian tuyệt đối.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua)

### 6. Người chơi bị Kéo Vào Trận Đấu Khi Đang Xem Loading Screen (GameLoaded Handshake)
- **Vấn đề:** Khi người chơi mới kết nối, nhân vật đã spawn ở Lobby trong lúc `GameLoadingScreen` đang tải. Nếu Server bắt đầu phase `Setup`, `MatchService.GetAlivePlayers()` duyệt qua tất cả người chơi có nhân vật và teleport họ vào đấu trường, phân đội và cấp vũ khí trong khi mắt người chơi vẫn đang nhìn màn hình tải.
- **Giải pháp:** Thiết lập cơ chế Handshake 2 chiều qua Attribute `GameLoaded`:
  1. Khi `PlayerAdded`, Server gán `Player:SetAttribute("GameLoaded", false)`.
  2. Trong `MatchService.GetAlivePlayers()`, bổ sung điều kiện bắt buộc: `PlayerStateHelper.IsGameLoaded(Player) == true`.
  3. Client chỉ phát RemoteEvent `FinishGameLoading` lên Server sau khi hoàn tất Pha 2 (mở rèm đôi). Server nhận sự kiện mới bật `GameLoaded = true`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua), [GameLoadingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua), [RemoteDefinitions.lua](../../src/ReplicatedStorage/Shared/Remotes/RemoteDefinitions.lua)

### 7. Phần tử GUI bị Méo Dẹt Ngang khi Phóng to bằng UIScale trên Màn hình 16:9
- **Vấn đề:** Khi dùng `UIScale` phóng to các đối tượng hình vuông/tròn (như các Dot loading), kích thước bị dẹt ngang thành hình chữ nhật.
- **Nguyên nhân:** Khung chứa hoặc đối tượng con đặt `Size` bằng `UDim2.Scale`. Tỉ lệ màn hình $16:9$ khiến $1\%$ chiều rộng lớn hơn $1\%$ chiều cao tính theo pixel thực tế, khi `UIScale` nhân hệ số lên sẽ khuyếch đại độ lệch này.
- **Giải pháp:** Gắn đối tượng `UIAspectRatioConstraint` với `AspectRatio = 1.0` và `AspectType = Enum.AspectType.Fit` trực tiếp vào phần tử UI, ép Roblox luôn duy trì tỉ lệ pixel $1:1$ vuông hoàn hảo trên mọi kích thước màn hình.
- **File liên quan:** [GameLoadingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameLoadingController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 8. Lỗi Rò rỉ Hàng đợi và Nạp Đồ họa lên Instance GUI đã Hủy khi Spam Chuyển Tab Menu
- **Vấn đề:** Khi người chơi spam chuyển đổi nhanh giữa các tab (Icicle / Block) hoặc đóng menu trong lúc hàng đợi Lazy Render đang chờ xử lý, các thẻ cũ bị hủy khỏi DOM nhưng vẫn còn trong `_LazyRenderQueue`. Khi cuộn hoặc timer kích hoạt, script cố nạp 3D model lên instance chết gây warning/error console hoặc rò rỉ bộ nhớ.
- **Nguyên nhân:** Hàm dọn dẹp `ClearItemList` chỉ hủy các Frame con trong `ScrollingFrame` mà quên ngắt kết nối sự kiện `CanvasPosition` và không làm sạch `_LazyRenderQueue`.
- **Giải pháp:**
  1. Trong hàm dọn dẹp `ClearItemList`/`ClearChestList`, chủ động gọi `_ScrollConn:Disconnect()` và `table.clear(_LazyRenderQueue)`.
  2. Trong vòng lặp `CheckLazyQueue`, bổ sung guard clause: nếu `not Frame.Parent` thì xóa ngay phần tử khỏi queue (`table.remove(_LazyRenderQueue, Index)`) và bỏ qua `continue`.
  3. **Triệt tiêu tận gốc (Khai tử Lazy Render):** Khi `InventoryController` và `ShopController` chuyển đổi hoàn toàn sang 2D Image/Icon, toàn bộ hệ thống Lazy Render Queue được dỡ bỏ hoàn toàn, loại bỏ 100% nguy cơ phát sinh lỗi rò rỉ này trong runtime.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### 9. Xung Đột Âm Thanh AutoBindButtons Gây Phát SFX Click/Hover Sai Thiết Kế Trên Cụm Nút Setting
- **Vấn đề:** Khi mở menu Setting, việc di chuột hoặc click vào các nút toggle bị phát đè âm thanh hover và click mặc định của hệ thống GUI chung, vi phạm yêu cầu chỉ phát SFX riêng khi đổi trạng thái.
- **Nguyên nhân:** `AutoBindButtons` duyệt toàn bộ cây con của `SettingFrame` và tự động gán SFX cho tất cả `GuiButton`.
- **Giải pháp:** Sử dụng `GuiHelper.SetIgnoreAutoBind` gắn cờ `IgnoreAutoBind = true` trên container `Config` và các nút con trước khi gọi `AutoBindButtons` cho `SettingFrame`.
- **File liên quan:** [SettingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 10. Lỗi Xóa Nhầm Nút Điều Khiển Tĩnh Trong Danh Sách Khi Tái Sử Dụng Container (Dynamic List Child Pruning Hazard)
- **Vấn đề:** Khi hàm re-render hoặc dọn dẹp (`ClearQuestList` / `RenderQuestList`) quét toàn bộ `ScrollingFrame:GetChildren()` để hủy các card cũ, các nút điều khiển tĩnh nằm chung container (như `ResetButton`) bị `Child:Destroy()` nhầm, dẫn đến mất nút hoặc gây crash `nil indexing` ở lần tương tác sau.
- **Nguyên nhân:** Logic dọn dẹp chỉ loại trừ `UIListLayout`/`UIPadding` mà coi mọi Frame/Button khác đều là card động được sinh ra từ template.
- **Giải pháp:** Thiết lập bộ lọc ngoại lệ đa tầng trong hàm dọn dẹp: kiểm tra `Child ~= _controlButton and Child.Name ~= StaticElementName and not Child:IsA("UIGridLayout")` trước khi hủy đối tượng.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 11. Lỗi Treo Luồng Khởi Tạo Client Controller Do WaitForChild Không Timeout Trước Khi Đăng Ký Tab (Bounded Yield & Start-Phase Tab Registration)
- **Vấn đề:** Khi controller menu gọi `WaitForChild` không có timeout cho các phần tử con lồng sâu (`TabContainer`, `CloseButton`, `RewardAnnouncement`), nếu một phần tử chưa nhân bản hoặc bị đổi tên, luồng khởi tạo sẽ bị treo vĩnh viễn (Infinite Yield). Dẫn đến lệnh `MenuController.RegisterTab` ở cuối hàm không bao giờ được gọi, làm tê liệt toàn bộ tab menu đó.
- **Giải pháp:**
  1. *Bounded Yield*: Sử dụng tìm kiếm đệ quy `FindFirstChild("Name", true)` kết hợp `WaitForChild("Name", GuiConfig.Timeouts.ShortWait)` có giới hạn thời gian an toàn trong `:Init()`.
  2. *Start-Phase Tab Registration*: Chuyển toàn bộ thao tác `MenuController.RegisterTab` sang phương thức `:Start()`, đảm bảo toàn bộ cây GUI đã resolve xong và `MenuController` đã qua pha khởi tạo trước khi nhận đăng ký.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 12. Treo Cứng Client Lúc Khởi Động (Boot Deadlock) Do Gọi `WaitForChild` Không Timeout Tại Module Scope (HIGH-02)
- **Vấn đề:** Khi `Main.client.lua` thực thi lệnh `require()` lần lượt các Controller trong `StarterPlayerScripts`, các controller như `GameStateController`, `ShopController`, `InventoryController`, `ProfileController` gọi trực tiếp `LocalPlayer:WaitForChild("PlayerGui"):WaitForChild(...)` không có timeout ngay tại module level. Khi mạng chậm hoặc client tải giao diện chậm, luồng thực thi của `require()` bị dừng vĩnh viễn (infinite yield), khiến các Controller phía sau không bao giờ được nạp và toàn bộ game bị treo cứng lúc vào game.
- **Giải pháp:** 
  1. Khởi tạo toàn bộ biến GUI thành `nil` ở module scope.
  2. Dời toàn bộ logic tìm kiếm cây UI vào hàm `:Init()` với timeout an toàn từ `GuiConfig.Timeouts.DefaultWaitForGui` (10s).
  3. Bổ sung nil-guards trước mọi thao tác cập nhật Text hay gắn sự kiện nút bấm.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 13. Lỗi Kẹt Giao Diện & Mất Thanh Điều Hướng Do Ẩn Container Trước Khi Xác Thực Tab (Premature UI Mutation & Defensive Tab Guard)
- **Vấn đề:** Khi mở một tab menu (`MenuController.OpenTab`), hệ thống vội vàng ẩn thanh điều hướng (`NavCtrl.SetButtonsContainerVisible(false)`) trước khi tra cứu tab trong `_RegisteredTabs`. Nếu tab chưa được đăng ký (do controller nạp lỗi hoặc chưa hoàn tất khởi tạo), hàm in cảnh báo rồi kết thúc mà không mở menu, đồng thời thanh NavigationButtons bị ẩn vĩnh viễn khiến người chơi kẹt giao diện hoàn toàn.
- **Giải pháp:** Áp dụng Defensive Guard Clause: Tra cứu `local TargetData = _RegisteredTabs[TabName]` ngay tại dòng đầu tiên của `OpenTab`. Nếu `not TargetData`, lập tức hủy luồng thực thi và tuyệt đối không thực hiện bất kỳ thay đổi trạng thái nào trên các container giao diện cha (`ButtonsContainer`, `SpectateGui`).
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua)

### 14. Chuẩn Hóa Kiến Trúc Vòng Đời 2 Pha (Init -> Start) Cho Toàn Bộ 24 Client Controllers & Triệt Tiêu Lazy Getters (HIGH-07)
- **Vấn đề:** Để tránh vòng lặp phụ thuộc khi mở các tab menu hoặc điều khiển HUD, các Controller con dùng boilerplate `local function GetMenuController()` để `require` động giữa chừng, thậm chí `require(script)` trong callback. Một số controller kết nối RemoteEvent hoặc gọi controller khác ngay trong `:Init()`, gây race condition và phá vỡ tính phân tách của vòng đời.
- **Giải pháp:** Đồng bộ chuẩn 2 pha nghiêm ngặt trên toàn bộ 24 Controller phía Client:
  1. *Pha 1 (`:Init()`)*: Tìm kiếm các phần tử GUI trong DOM với timeout an toàn, gán nil-guards, bind tương tác nội bộ. Tuyệt đối không kết nối `RemoteEvent` và không gọi controller khác.
  2. *Pha 2 (`:Start()`)*: Nạp sẵn các Controller phụ thuộc vào biến module scope (`_MenuController = require(...)`), thực hiện đăng ký dịch vụ (`MenuController.RegisterTab`), kết nối toàn bộ `RemoteEvent.OnClientEvent`, `UserInputService`, và lắng nghe vòng đời nhân vật.
- **File liên quan:** [Main.client.lua](../../src/StarterPlayer/StarterPlayerScripts/Main.client.lua), [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [SettingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [SoundController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua)

### 15. Lỗi Zombie Coroutine & Lệch Trạng Thái (State Desync) Của Hoạt Ảnh Huy Hiệu Khi Container Bị Ẩn
- **Vấn đề:** Khi mở các menu toàn màn hình hoặc vào trận đấu, thanh dock `ButtonsContainer` bị ẩn. Nếu vòng lặp coroutine pulse của huy hiệu tiếp tục chạy ngầm: (1) Lãng phí tài nguyên CPU/GPU; (2) Khi người chơi bấm nhận hết nhiệm vụ trong menu rồi đóng lại, huy hiệu vẫn tiếp tục đập sai thực tế; (3) Scale có thể bị kẹt ở đỉnh $1.2$ khi container đột ngột hiển thị lại.
- **Giải pháp:** Tích hợp quản lý vòng đời chặt chẽ trong `NavigationController`:
  1. Khi `SetVisible(false)` hoặc `SetButtonsContainerVisible(false)`, lập tức hủy coroutine pulse (`task.cancel(_PulseTask)`) và reset `UIScale.Scale = 1.0`.
  2. Khi container hiển thị lại, chỉ khởi động lại pulse nếu cờ `_IsNotificationActive == true`.
  3. Khi claim hết quà trong menu Quest, `QuestController` lập tức gọi `SetQuestNotification(false)` ngắt hoàn toàn hiệu ứng từ bên trong.
- **File liên quan:** [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua)