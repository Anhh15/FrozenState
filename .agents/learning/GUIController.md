# GUIController
> Tổng hợp kiến thức về quản lý GUI phía client theo trạng thái game trong dự án.
> Cập nhật lần cuối: 21-08-2026

---

## Kiến trúc

### Chuẩn hóa Hoạt họa Pop, Nối tiếp (Stagger) và Âm thanh per-item trong GameStatistic
- **Ngày:** 19-08-2026
- **Chi tiết:** Mở rộng kiến trúc hoạt họa `Pop` và `Stagger` sang `ScreenGui.GameStatistic` cho cả 2 màn hình `TopPlayersStats` và `PlayerStats`. Bổ sung hỗ trợ `ItemSoundId` vào `GuiHelper.StaggerPopOpen`, cho phép tự động phát âm thanh SFX (như tiếng đếm chỉ số `132948338000932`) đồng bộ với từng bước bung nở của phần tử mà không cần controller viết vòng lặp thủ công. Chuẩn hóa `NextButton` và các nút đóng `CloseButton` với hiệu ứng phóng to rê chuột (`HoverScale`), thu nhỏ khi bấm (`PressScale`) cùng âm thanh tương tác tương tự `NavigationButtons`. Quản lý luồng stagger an toàn (`task.cancel` trên thread và `CancelTween`) khi người chơi đóng GUI hoặc khi phase trận đấu thay đổi.
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua)

### Kiến trúc 2 Tầng Toàn Diện (Default & Overrides) Cho Toàn Bộ Animation GUI & Quản Lý Tập Trung
- **Ngày:** 19-08-2026
- **Chi tiết:** Chuẩn hóa 100% các animation GUI trong game (`Pop`, `ButtonScale`, `Stagger`, `ItemReward`, `ModeAnnouncement`, `RoundLoadingScreen`, `Accolades`) sang mô hình 2 tầng (`Default` dùng chung + `Overrides` theo Key) trong `GuiConfig.lua`. Gom toàn bộ thời lượng, tốc độ xoay và âm lượng SFX (`AudioConfig`) khỏi các Controller client. `GuiHelper.lua` cung cấp các hàm resolver (`GetItemRewardAnimConfig`, `GetModeAnnouncementAnimConfig`, `GetRoundLoadingAnimConfig`, `GetAccoladesAnimConfig`) tự động hòa trộn `Overrides` với `Default`, triệt tiêu hoàn toàn magic numbers và hardcode.
- **File liên quan:** [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [AccoladesController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/AccoladesController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### Cơ chế Dò Ngược Tổ Tiên (Ancestor Resolution) & Overload Tham Số Linh Hoạt cho StaggerPopOpen
- **Ngày:** 19-08-2026
- **Chi tiết:** `GuiHelper.StaggerPopOpen` hỗ trợ tự động tìm tên menu nguồn khi người gọi không truyền `Identifier`. Thay vì chỉ lấy `ItemsList[1].Parent.Name` (dễ bị nhận nhầm thành `"ScrollingFrame"`), hàm duyệt ngược cây phân cấp (`Parent`, `Parent.Parent`...) để tìm Frame thuộc `GuiConfig.MenuFrames` hoặc có trong `Overrides`. Đồng thời hỗ trợ overload tham số linh hoạt: cho phép gọi `(ItemsList, "Inventory")`, `(ItemsList, CustomConfig)`, `(ItemsList, OnComplete)` mà không bắt buộc truyền đủ 4 tham số.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Hoạt họa xuất hiện lần lượt phân tầng (Staggered Pop Animation) & Overrides per-list cho Template Menu
- **Ngày:** 19-08-2026
- **Chi tiết:** Thay vì render tức thời toàn bộ danh sách card/template trong `ScrollingFrame` (gây cảm giác thô cứng), áp dụng `GuiHelper.StaggerPopOpen` dựa trên `UIScale` với độ trễ nối tiếp `DelayStep` (`0.03s`) và kiểu `EasingStyle.Back`. Phân tách cấu hình `Default` + `Overrides` theo tên menu/frame trong `GuiConfig.Animations.Stagger` và `Pop`. Hủy an toàn (`CancelTween` và `task.cancel` trên thread stagger) khi người chơi đóng menu hoặc chuyển tab nhanh, ngăn ngừa triệt để hiện tượng kẹt `UIScale = 0` hoặc xung đột hoạt họa.
- **File liên quan:** [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Tách biệt vòng đời hoạt họa Stagger khỏi chu kỳ Auto-Refresh ngầm trong Menu GUI
- **Ngày:** 19-08-2026
- **Chi tiết:** Trong các menu có cơ chế tự động làm mới dữ liệu thời gian thực (như `QuestController` đếm ngược/cập nhật tiến trình 1s/lần), sử dụng cờ `TriggerStagger` để kiểm soát hoạt họa. Hiệu ứng Stagger Pop chỉ kích hoạt khi người chơi mở menu hoặc chủ động bấm chuyển tab (`TriggerStagger = true`). Vòng lặp cập nhật ngầm định kỳ gọi với `TriggerStagger = false` để thực hiện in-place update các thuộc tính text, progress bar và nút bấm, đảm bảo giao diện luôn mượt mà và giữ nguyên vị trí cuộn `CanvasPosition` mà không bị gián đoạn hay chớp giật.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### Tách rời việc đóng gói dữ liệu thống kê (PreparePayloads) và thời điểm phát sóng (Broadcast) trong GameOver
- **Ngày:** 19-08-2026
- **Chi tiết:** Trong quy trình kết thúc trận (`InGame` -> `GameOver` -> `Intermission`), dữ liệu thống kê (Top 3, cá nhân, thắng/thua) phụ thuộc vào thông tin đội nhóm (`Team`). Nếu dọn dẹp state (`ClearTeam`, teleport lobby) trước khi gửi remote, dữ liệu team bị mất khiến bảng thống kê rỗng. Giải pháp chuẩn: chia làm 2 bước — (1) `PrepareGameOverPayloads` chụp snapshot dữ liệu ngay đầu `GameOver` khi team còn nguyên vẹn; (2) `SendGameOverPayloads` chỉ kích hoạt sau khi teleport về sảnh (`Intermission`), đảm bảo hiển thị đúng thời điểm mà dữ liệu không bị sai lệch.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Mẫu Truy Xuất Động GUI (Dynamic GUI Resolver Pattern) trong Single-Controller Client
- **Ngày:** 18-08-2026
- **Chi tiết:** Thay vì lưu biến tĩnh một lần duy nhất lúc `Init()` (dễ bị trỏ vào instance cũ bị hủy khi nhân vật spawn lần đầu `CharacterAdded` hoặc do cơ chế `ResetOnSpawn`), controller sử dụng hàm resolver động (`ResolveScreenElements` / `ResolveElements`) để luôn truy xuất trực tiếp các GuiObject active trong `PlayerGui`. Hàm tự động bật `ResetOnSpawn = false` và `Enabled = true` ngay khi truy xuất, kết hợp fallback thông minh (`Background = Frame:FindFirstChild("Background") or Frame`). Loại bỏ hoàn toàn nguy cơ rò rỉ hoặc tương tác trên GUI rác trong bộ nhớ.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### Chuẩn hóa phân cấp Animation trên phần tử con Background trong ScreenGui Special
- **Ngày:** 18-08-2026
- **Chi tiết:** Thay vì tween trực tiếp trên Frame cha (`RoundLoadingScreen`, `ItemReward`) làm mất trạng thái kích thước hoặc phá vỡ cấu trúc container toàn màn hình, chuyển 100% các animation nền (fade in/out, flash trắng chuyển pha) sang phần tử con `Background` (`Frame`/`ImageLabel`). Frame cha giữ `BackgroundTransparency = 1` và thuần túy quản lý `Visible` / vòng đời hiển thị. Cache giá trị mặc định (`BackgroundColor3`, `BackgroundTransparency`) từ instance `Background` khi `Init()`, giúp tùy biến giao diện trực tiếp trong Roblox Studio mà không cần can thiệp mã nguồn.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### Hệ thống Thông báo Chế độ Chơi Đặc biệt ModeAnnouncement & Phối hợp Setup Phase
- **Ngày:** 18-08-2026
- **Chi tiết:** Xây dựng `ModeAnnouncementController` độc lập quản lý Frame `Special/ModeAnnouncement` (`Background`, `ModeNameText`, `DescriptionText`). Khi là Special Round (Chaos, EternalFreeze), controller kích hoạt hiệu ứng nối tiếp (Fade In tiêu đề in hoa kèm SFX `75713209190949` -> Fade In mô tả), hiển thị trong 4.0s trước khi gọi `RoundLoadingScreen`. Phía Server (`MatchService.RunSetup`) tự động chờ thêm 4.0s để tránh race condition nhảy phase `Ready` sớm. Normal Round bỏ qua hoàn toàn. Tự động `ForceHide()` dọn dẹp khi chuyển phase `Ready`.
- **File liên quan:** [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameModeConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameModeConfig.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### Kiến trúc quản lý ResetOnSpawn và vòng đời GUI trong Single-Controller Pattern (ResetOnSpawn = false)
- **Ngày:** 18-08-2026
- **Chi tiết:** Trong kiến trúc Controller-Service (`StarterPlayerScripts`), các controller chỉ khởi tạo và gắn sự kiện `.Connect` một lần duy nhất khi client load. Mọi ScreenGui hệ thống (`Menu`, `NavigationButtons`, `GameState`, `Special`, `GameStatistic`) **bắt buộc phải đặt `ResetOnSpawn = false`**. Nếu đặt `true`, Roblox sẽ hủy và tạo mới ScreenGui khi nhân vật chết, làm mất toàn bộ các listener đã kết nối và biến GUI thành "GUI chết". Trạng thái dọn dẹp hoặc khôi phục khi nhân vật chết/hồi sinh được quản lý chủ động qua sự kiện `LocalPlayer.CharacterAdded` trong Controller.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Cơ chế Điều phối Hiển thị Độc quyền giữa Menu Tabs và SpectateGui (ExcludedFrame Coordinator)
- **Ngày:** 18-08-2026
- **Chi tiết:** Khi frame `Spectate` nằm bên trong ScreenGui `Menu` nhưng hoạt động độc lập với các tab menu nội bộ (Shop, Inventory, Profile, Quest), hàm `HideAllFrames` và `CloseAll` của `MenuController` hỗ trợ tham số `ExcludedFrame`. Khi `SpectateController.SetVisible(true)`, `MenuController.CloseAll(SpectateGui)` đóng các tab khác nhưng bỏ qua `SpectateGui`. Ngược lại, khi mở bất kỳ tab menu nào (`MenuController.OpenTab`), hệ thống chủ động gọi `SpectateController.SetVisible(false)` để giải phóng camera và chuyển trạng thái mượt mà.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

### Điều phối Hoạt họa Popup Tập Trung qua MenuController (UIScale Pop Animation)
- **Ngày:** 18-08-2026
- **Chi tiết:** Tích hợp hiệu ứng hoạt họa phóng to nảy nhẹ (`PopOpen`) và thu nhỏ (`PopClose`) dựa trên `UIScale` cho 4 menu chính (`Shop`, `Inventory`, `Profile`, `Quest`) trong `ScreenGui.Menu`. Sử dụng `UIScale` giúp hoạt họa hoàn toàn độc lập với kích thước `UDim2.Size` cụ thể của từng Frame thiết kế trong Studio. `MenuController` đóng vai trò điều phối duy nhất: tự động gọi `PopOpen` khi mở tab, `PopClose` khi đóng tab, và áp dụng cơ chế Fast Switch (hủy tween và ẩn ngay tab cũ khi chuyển đổi nhanh giữa các menu để phản hồi tức thì). Các controller con (`ShopController`, `InventoryController`, `ProfileController`, `QuestController`) không trực tiếp can thiệp vào `Visible`, mà chỉ tập trung xử lý dữ liệu.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### Phân tách trách nhiệm tập trung: NavigationController & MenuController (Decoupled Lobby UI)
- **Ngày:** 18-08-2026
- **Chi tiết:** Tách hoàn toàn trách nhiệm quản lý `NavigationButtons` và `MenuGui` ra khỏi `GameStateController`. `GameStateController` chỉ giữ đúng vai trò điều khiển GameState HUD (Timer, Phase, Frozen indicator) và thông báo thay đổi phase trận đấu. `NavigationController.lua` chuyên trách quản lý toàn bộ ScreenGui `NavigationButtons`, bind SFX, scale animation tập trung cho tất cả nút bấm và quản lý hiển thị số tiền `Cash`. `MenuController.lua` đóng vai trò UI Coordinator cho toàn bộ các cửa sổ trong `MenuGui` (`Shop`, `Inventory`, `Profile`, `Quest`), hiện thực cơ chế hiển thị độc quyền (Mutual Exclusion) và tự động yêu cầu `NavigationController` ẩn/hiện thanh nút khi mở/đóng menu, loại bỏ hoàn toàn các hàm lặp lại `HideAllMenuFrames` ở các controller con.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

### Kiến trúc hệ thống Animation GUI tập trung dựa trên UIScale và TweenService
- **Ngày:** 18-08-2026
- **Chi tiết:** Thay vì tween trực tiếp `Size` (dễ vỡ layout, kẹt kích thước khi spam click), sử dụng `UIScale` làm cốt lõi cho mọi animation GUI. `UIScale` giữ nguyên kích thước gốc trong Studio và scale đồng bộ toàn bộ UI con. Cấu hình phân tầng `Default` + `Overrides` per-button tại `GuiConfig.Animations` (`Pop`, `ButtonScale`) với `EasingStyle.Back` tạo độ nảy nhẹ. Để nút phóng to vươn lên trên (Dock style), đặt `AnchorPoint = (0.5, 1)` kết hợp `UIListLayout.VerticalAlignment = Bottom`. `GuiHelper.lua` cung cấp `PopOpen`, `PopClose`, `TweenScale`, `BindButtonScale`, `BindAllNavButtonsAnimation` (tự động gom sự kiện từ mọi `GuiButton` con cháu về scale item gốc) và quản lý `_activeTweens` hủy tween cũ khi tương tác nhanh.
- **File liên quan:** [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Tập trung hóa cấu trúc UI qua GuiConfig và GuiHelper (Decoupled GUI Paths)
- **Ngày:** 16-08-2026
- **Chi tiết:** Loại bỏ hoàn toàn Hardcoded Paths và Magic Strings rải rác trong các controller khi đổi tên hoặc tái cấu trúc phân cấp GUI (ví dụ: chuyển nút sang `Buttons/Extra/` và đổi tên `NavigationButtons`). Sử dụng `GuiConfig.lua` làm Single Source of Truth cho toàn bộ tên ScreenGui, Frame, Button, Stats keys. Cung cấp `GuiHelper.lua` với các tiện ích: `GetScreenGui`, `GetNavButton` (tìm kiếm đệ quy an toàn), `GetMoneyLabel`, `HideOtherMenuFrames`, và `BindAllNavButtonsSound` (dùng `GetDescendants()` để tự động gắn âm thanh hover/click cho mọi nút bấm con/cháu). Giúp các controller hoàn toàn độc lập với cấu trúc cây UI thực tế trong Studio.
- **File liên quan:** [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua)

### Tách biệt màn hình chuyển cảnh vòng đấu (RoundLoadingScreen) sang ScreenGui Special
- **Ngày:** 15-08-2026
- **Chi tiết:** Đổi tên từ `LoadingScreen` sang `RoundLoadingScreen` để phân biệt rạch ròi với màn hình tải game ban đầu (`GameLoadingScreen`). Di chuyển Frame `RoundLoadingScreen` từ `InGameGui` sang `Special` ScreenGui (nơi chứa các lớp phủ toàn màn hình như `ItemReward`). Điều này giúp phân tách hoàn toàn lớp Full-screen Overlay đặc biệt khỏi HUD thi đấu (`InGameGui`), cho phép `InGameGui.Enabled` chỉ cần kích hoạt trong các phase gameplay thực tế (`Ready`, `InGame`, `GameOver`) thay vì phải bật sớm ở phase `Setup`.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### Đồng bộ hiển thị nhãn trang bị vật phẩm (EquippedText Indicator) trong InventoryController
- **Ngày:** 28-07-2026
- **Chi tiết:** Trong `InventoryController`, khi render danh sách vật phẩm theo Tab ("Icicle" / "Block"), controller tra cứu ID đang trang bị trong `PlayerDataController.GetData()` (`EquippedIcicle` / `EquippedIceBlock`). Đặt thuộc tính `.Visible = true` cho nhãn `EquippedText` (hoặc fallback `Equipped`) trên ô vật phẩm khớp ID, và `.Visible = false` cho các vật phẩm khác. Khi bấm Equip thành công, hàm `UpdateEquippedTags()` quét danh sách `ScrollingFrame` để cập nhật `Visible` ngay lập tức mà không cần re-render toàn bộ danh sách. Đồng thời, tại các controller dùng chung `ItemTemplate` (`ItemRewardController`, `ShopController`, `ProfileController`), nhãn `EquippedText` được chủ động ẩn (`Visible = false`) khi clone.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### Lazy Render ViewportFrame theo vùng nhìn thấy ScrollingFrame (Shop Preview In-Place)
- **Ngày:** 28-07-2026
- **Chi tiết:** Để tối ưu hiệu suất khi một danh sách card GUI mỗi card có ViewportFrame 3D, áp dụng lazy render: chỉ clone model và gọi `ViewportManager.RenderItem` khi card nằm trong (hoặc gần) vùng nhìn thấy của ScrollingFrame cha. Cơ chế: lưu queue `{ Frame, Data }`, connect `ScrollingFrame:GetPropertyChangedSignal("CanvasPosition")`, tính `CardTop = Frame.AbsolutePosition.Y - Scroll.AbsolutePosition.Y + CanvasPosition.Y` so với `[CanvasY - Buffer, CanvasY + ScrollHeight + Buffer]`. Gọi `task.defer(CheckLazyQueue)` sau khi render tất cả card để render ngay các card đầu tiên mà không chờ scroll. Buffer pre-load nên lưu vào Config (không hardcode).
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ShopConfig.lua](../../src/ReplicatedStorage/Shared/Config/ShopConfig.lua)

### Vị trí Template GUI: shared với GUI owner
- **Ngày:** 28-07-2026
- **Chi tiết:** Quy tắc phân loại vị trí template GUI: template **dùng chung giữa nhiều controller** (ví dụ `ItemTemplate` dùng bởi Shop/Inventory/Profile/ItemReward) → đặt tại `ReplicatedStorage/Assets/Gui`. Template **riêng của một GUI duy nhất** (ví dụ `ChestPreview` chỉ dùng bởi ShopController) → đặt trong chính GUI đó (`Menu/Shop/Templates`). Ưu điểm: dễ chỉnh sửa trong Studio đúng ngữ cảnh, không bị Rojo sync xóa, tuân thủ nguyên tắc co-location. Template phải được đặt trong Folder (không phải Frame để tránh render), hoặc đặt `Visible = false`.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### Phân định độc lập và cố định Nhạc nền Lobby cho Spectator (Decoupling MusicController & SpectateController)
- **Ngày:** 28-07-2026
- **Chi tiết:** Đơn giản hóa logic nhạc nền bằng cách quy định Spectator (người chơi không có đội) luôn nghe nhạc Lobby (`AudioConfig.Music.Lobby`), không thay đổi phụ thuộc vào người mà họ spectate hay phase InGame/FrozenState. Nhờ đó, loại bỏ hoàn toàn cơ chế callback/lazy-require chéo giữa `SpectateController` và `MusicController` (`OnSpectateChanged`), giúp hai hệ thống độc lập hoàn toàn (decoupled), giảm độ phức tạp và tránh nguy cơ circular dependency.
- **File liên quan:** [MusicController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MusicController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

### Quản lý visibility GUI theo phase game + trạng thái team (Spectator-aware)
- **Ngày:** 05-06-2026 (cập nhật 06-06-2026)
- **Chi tiết:** Các ScreenGui được chia thành 2 nhóm: "Lobby GUI" (Menu, NavigationButton) và "Gameplay GUI" (GameStatistic). Logic hiển thị Lobby GUI sử dụng 2 tầng kiểm tra: (1) **Tầng Team**: `LocalPlayer:GetAttribute("Team")` — nếu `nil` (Spectator/late-joiner) thì luôn hiện GUI bất kể phase; nếu có team mới vào tầng 2. (2) **Tầng Phase**: bảng `GAMEPLAY_PHASES = { Ready, InGame, GameOver }` tra cứu nhanh để ẩn GUI khi đang trong trận. Cache `_lastPhase / _lastTimeRemaining / _lastIsFrozenState` được lưu mỗi lần `UpdateDisplay` để `GetAttributeChangedSignal("Team")` có thể re-evaluate đúng lúc Attribute thay đổi. Server đồng bộ team qua `Player:SetAttribute("Team", ...)` thay vì Remote Event riêng.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### Quản lý ẩn/hiện đồng thời các Frame Menu và NavigationButton (Điều phối bởi MenuController)
- **Ngày:** 18-08-2026 (cập nhật từ 21-07-2026)
- **Chi tiết:** Thay vì từng controller riêng lẻ tự ẩn các frame menu anh em, `MenuController.lua` đóng vai trò Coordinator tập trung. Khi mở bất kỳ tab nào (Shop, Inventory, Profile, Quest), `MenuController` tự động đóng tab đang active, ẩn toàn bộ frame khác trong `MenuGui` và gửi tín hiệu cho `NavigationController.SetButtonsContainerVisible(false)` để ẩn thanh nút `Buttons` (trong khi `Stats` hiển thị tiền vẫn giữ nguyên). Khi đóng tab, `MenuController` báo cho `NavigationController` hiện lại thanh nút.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua)

### Quản lý hiển thị InGameGui theo phase gameplay (Decoupled khỏi RoundLoadingScreen)
- **Ngày:** 15-08-2026 (cập nhật từ 21-07-2026)
- **Chi tiết:** `InGameGui` chỉ chứa thuần túy các gameplay HUD trong trận (`PlayerStatus`, `ScoreBoard`, `ScoreBoardButton`, `Accolades`). Màn hình chuyển cảnh `RoundLoadingScreen` đã được tách sang `Special` ScreenGui. Do đó, `InGameGui.Enabled` chỉ cần bật (`true`) trong các phase thi đấu (`Ready`, `InGame`, `GameOver`) và tự động tắt hoàn toàn (`false`) ở `Intermission` và `Setup`.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Render 3D Avatar lên GUI (ViewportFrame & WorldModel)
- **Ngày:** 10-06-2026 (cập nhật 11-06-2026)
- **Chi tiết:** Thay thế avatar 2D bằng `ViewportFrame` và `WorldModel`. Để tránh lỗi phân quyền `Players:CreateHumanoidModelFromUserId()` (chỉ chạy ở server) và lỗi `StreamingEnabled` làm mất nhân vật, Server sinh trước model tĩnh cho Top 1,2,3 tại thư mục `ReplicatedStorage.TempTopPlayers` khi kết thúc trận, Client chỉ cần clone về. Đối với hiển thị tĩnh cho LocalPlayer, Client clone nhân vật hiện tại và triệt tiêu mọi chuyển động bằng cách: Anchor toàn bộ `BasePart`, xóa sạch `Animator/Script/LocalScript/Sound`, và chỉnh `Humanoid.PlatformStand = true`.
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Thiết kế UI Template Động qua Module Config (Inventory)
- **Ngày:** 15-06-2026
- **Chi tiết:** Thay thế nhiều template UI bằng duy nhất một `ItemFrame` chung kết hợp với `RarityConfig` chứa màu sắc, ảnh nền của từng độ hiếm. Client render tự động gán thuộc tính động từ Config, tránh hardcode thông số hiển thị trực tiếp trong code.
- **File liên quan:** [RarityConfig.lua](../../src/ReplicatedStorage/Shared/Config/RarityConfig.lua)

### Quản lý Tài nguyên Đồ họa trong Dự án Sử dụng Rojo
- **Ngày:** 15-06-2026
- **Chi tiết:** Tránh Rojo xóa folder assets đồ họa (UI, Mesh Previews...) trong `ReplicatedStorage` khi sync bằng cách cấu hình `default.project.json` chỉ đồng bộ các thư mục con chứa Script (như `Controllers`, `Shared`...). Folder `ReplicatedStorage/Assets` được quản lý trực tiếp trong Roblox Studio để bảo toàn nguyên vẹn.
- **File liên quan:** [default.project.json](../../default.project.json)

### Tự động hóa Camera ViewportFrame qua Bounding Box và Config (`ViewportManager`)
- **Ngày:** 23-06-2026
- **Chi tiết:** Tự động hóa camera bằng `ViewportManager` dựa trên Bounding Box của mô hình 3D. Hỗ trợ ghi đè góc nhìn (Pitch, Yaw, FOV, Padding) qua cấu hình phân tầng `ViewportConfig` (Default -> Type -> ItemId) trên tất cả các tab Inventory, Shop và Profile.
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [ViewportConfig.lua](../../src/ReplicatedStorage/Shared/Config/ViewportConfig.lua)

### Triệt tiêu Circular Dependency bằng Tách Coordinator (MenuController & NavigationController)
- **Ngày:** 18-08-2026 (cập nhật từ 16-06-2026)
- **Chi tiết:** Trước đây `GameStateController` phải lazy-require tới 7 controller con để ép đóng menu khi vào trận, tạo liên kết chéo phức tạp. Bằng cách giới thiệu `MenuController` (UI Coordinator) và `NavigationController`, `GameStateController` chỉ cần gửi 1 lệnh `MenuController.SetVisible(false)` và `NavigationController.SetVisible(false)`. Các controller menu con (`Inventory`, `Shop`, `Profile`, `Quest`) chỉ đăng ký với `MenuController`, loại bỏ hoàn toàn việc require chéo lẫn nhau.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Inventory Controller - Data Flow Pattern (Local Cache + Client State Update)
- **Ngày:** 16-06-2026
- **Chi tiết:** Để tối ưu UX, Client đọc dữ liệu từ local cache `PlayerDataController.GetData()` thay vì liên tục gọi server. Khi trang bị skin mới, Client gửi RemoteEvent lên Server. Nhận xác nhận thành công, Client tự cập nhật cache local và làm mới UI ngay lập tức.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua)

### Logic hiển thị nút trang bị (EquipButton State Logic)
- **Ngày:** 16-06-2026
- **Chi tiết:** Trạng thái của EquipButton cập nhật động khi chọn item. Đối chiếu ID vật phẩm chọn với cache local. Trùng khớp thì đổi nhãn thành "Equipped" và khóa click (`Active = false`), khác biệt thì hiện "Equip" và cho click (`Active = true`).
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Tách biệt UI Template cho mục đích tái sử dụng (Shared Assets)
- **Ngày:** 17-06-2026
- **Chi tiết:** Đưa `ItemTemplate` ra thư mục dùng chung `ReplicatedStorage.Assets.Gui.ItemTemplate` để các controller khác (như Shop, Gifts) dễ dàng clone, đồng bộ mỹ thuật UI và giảm thiểu trùng lặp asset.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Highlight Tab an toàn không phụ thuộc thuộc tính Font/Text (ImageButton-safe)
- **Ngày:** 17-06-2026
- **Chi tiết:** Khi dùng `ImageButton` thay cho `TextButton` làm nút chuyển tab, việc truy cập các thuộc tính Text sẽ gây crash. Sửa bằng cách thay đổi `.BackgroundColor3` trực tiếp trên nút (màu trắng `#FFFFFF` khi active và xám `#2F2F2F` khi inactive) để hiển thị active tab.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Cơ chế click linh hoạt cho UI Template (Robust Click Event Binding)
- **Ngày:** 17-06-2026
- **Chi tiết:** Hỗ trợ click linh hoạt cho UI template: (1) Nếu là `GuiButton` thì kết nối `MouseButton1Click`; (2) Nếu là `Frame` thì tìm `GuiButton` con; (3) Nếu không có nút con nào, lắng nghe sự kiện `InputBegan` để bắt hành động Click/Touch.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Tải và Đồng bộ hóa Dữ liệu Client theo yêu cầu (Lazy-load Data Sync)
- **Ngày:** 17-06-2026
- **Chi tiết:** Nhằm tránh dữ liệu stats cũ bị hiển thị sai sau trận đấu, áp dụng Lazy-loading. Cung cấp hàm `PlayerDataController.RefreshData()`. Khi mở GUI Profile/Inventory, Client hiện dữ liệu cache có sẵn trước, sau đó chạy `task.spawn` kéo dữ liệu mới từ Server để cập nhật lại UI bất đồng bộ mà không block giao diện.
- **File liên quan:** [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### Hệ thống Spectate cho Spectator (Spectate System)
- **Ngày:** 26-06-2026
- **Chi tiết:** Xây dựng hệ thống quan sát trận đấu (Spectate) dành riêng cho người chơi không có đội (Spectator) trong phase `InGame`. Sử dụng Orbit Camera (CameraType.Custom, thiết lập `CameraSubject` trỏ đến `Humanoid` của người chơi đang thi đấu). Client duyệt chuyển đổi mục tiêu qua các nút điều hướng (Next/Back).
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Điều phối Streaming cho Spectate bằng ReplicationFocus và Lock Movement
- **Ngày:** 27-06-2026
- **Chi tiết:** Dưới chế độ `StreamingEnabled`, khi dời camera sang target ở xa, ta phải thay đổi tâm stream để tải dữ liệu đấu trường. Giải pháp là dịch chuyển `Player.ReplicationFocus` từ character của chính spectator sang `HumanoidRootPart` của target thông qua yêu cầu từ client gửi lên server. Đồng thời, trong khi spectate, cần khóa di chuyển (`WalkSpeed = 0`, `JumpPower = 0`, `JumpHeight = 0`) phía client để nhân vật spectator không bị trôi dạt do mất physics mô phỏng vùng lobby bị stream out. Khi tắt spectate, server trả lại `ReplicationFocus` về spectator HRP và client phục hồi tốc độ di chuyển gốc từ cấu hình `GameConfig`.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### Hệ thống GUI SFX tập trung qua GuiHelper & AudioHelper (Sound Pool Architecture)
- **Ngày:** 06-07-2026 (Cập nhật kiến trúc Sound Pool: 18-08-2026)
- **Chi tiết:** Thay vì tạo và hủy `Sound` instance phân tán bằng `Debris:AddItem` (gây rác bộ nhớ và tăng GC latency khi spam click), toàn bộ âm thanh GUI được điều phối tập trung qua `GuiHelper.PlayGuiSound(SoundId)` / `AudioHelper.PlayGuiSound(SoundId)`. Hệ thống sử dụng một static Sound Pool `_guiSoundPool` tái sử dụng các instance `Sound` trong `SoundService`, gán `TimePosition = 0` và phát ngay tức thì (0ms latency, không tạo rác). Quy tắc áp dụng: `CloseButton` → close sfx; tab/equip/nav buttons → button click sfx; `Buy1/Buy3` → ChestBuy (success) hoặc buy fail (fail) tùy `Result.Success`; `ClaimButton` (Quest) → QuestReward sfx; `ShowPlayerStats` → overall sfx. NavigationButton tự động bind cả `MouseEnter` (hover) lẫn `MouseButton1Click` qua `GuiHelper.BindAllNavigationEffects`.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [AudioHelper.lua](../../src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### Đồng bộ Loading Screen bằng trì hoãn Server (Server Delay Sync)
- **Ngày:** 20-07-2026
- **Chi tiết:** Để che giấu quá trình Setup (tải map, chia đội) khỏi người chơi, client khởi chạy animation fade-in của Loading Screen. Thay vì tạo RemoteEvent để client phản hồi khi fade-in hoàn tất, server thực hiện `task.wait(FadeInDuration)` ngay sau khi broadcast phase "Setup". Điều này giúp tinh giản network traffic và giảm độ phức tạp của logic đồng bộ mà vẫn đảm bảo Setup chỉ kết thúc sau khi màn hình đen đã che phủ hoàn toàn.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua)

### Điều phối luồng setup phase trên Server tránh race condition Loading Screen và hỗ trợ AFK
- **Ngày:** 21-07-2026
- **Chi tiết:** Để tránh màn hình đen vô ích cho những người chơi AFK hoặc Spectator thực sự, và đảm bảo thuộc tính `"Team"` đã được đồng bộ khi client bắt đầu fade-in, server tiến hành reset dữ liệu cũ, chia team mới (`SessionService.AssignTeams()`) và đồng bộ team (`TeamService.BroadcastTeamAssignment()`) **trước** khi phát tín hiệu `"Setup"` cho client. Sau đó, các thao tác tải tài nguyên nặng (như `MapService.LoadRandomMap()`) được thực hiện trong bóng tối (trong lúc client đang fade-in).
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

---

## Bug & biện pháp

### Lỗi Stagger Animation không nhận Overrides do lấy sai tên cha trực tiếp (ScrollingFrame thay vì Menu Name)
- **Ngày:** 19-08-2026
- **Vấn đề:** Khi cấu hình `GuiConfig.Animations.Stagger.Overrides["Inventory"]` (như thay đổi `DelayStep` hoặc `EasingStyle`), animation của các thẻ item trong Inventory không nhận hiệu ứng mới mà luôn chạy theo cấu hình `Default`.
- **Nguyên nhân:** `InventoryController` gọi `StaggerPopOpen(RenderedFrames)` không truyền `Identifier`. Hàm helper cũ lấy `ItemsList[1].Parent.Name`, trả về `"ScrollingFrame"` (tên của instance `ScrollingFrame` trong Studio) thay vì `"Inventory"`. Khi tra cứu `Overrides["ScrollingFrame"]`, hệ thống không tìm thấy và luôn fallback về `Default`.
- **Fix:** Viết hàm nội bộ `ResolveAncestorMenuName` duyệt ngược cây cha/ông để tìm Frame khớp với `GuiConfig.MenuFrames` hoặc `Overrides`, đồng thời hỗ trợ overload nhận `Identifier` trực tiếp ở tham số thứ 2.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### Bảng TopPlayersStats bị ẩn toàn bộ trên các chế độ Team-based do thứ tự dọn dẹp ClearTeam
- **Ngày:** 19-08-2026
- **Vấn đề:** Khi kết thúc Normal Mode hoặc các mode chia đội (như Eternal Freeze), `TopPlayersStats` không hiển thị các khung `PlayerTop1-3` và người chơi đội thắng bị tính là DEFEAT trên bảng cá nhân. Chế độ FFA (Chaos) không bị lỗi.
- **Nguyên nhân:** Trong `MatchService.RunGameOver`, `SessionService.ClearTeam` chạy trước khi gọi `BroadcastGameOver`. Khi `GetTopPlayers` lọc theo `GetTeamPlayers(WinTeam)`, mảng trả về `{}` rỗng khiến client ẩn cả 3 slot, đồng thời `GetTeam(Player)` bị `nil` làm sai cờ `Won`. Chế độ FFA lấy theo `GetStats(Player)` nên không bị ảnh hưởng.
- **Fix:** Chuẩn bị sẵn dữ liệu qua `PrepareGameOverPayloads` ngay đầu phase trước khi dọn dẹp team, sau đó gửi payload bằng `SendGameOverPayloads` khi đã về sảnh.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### AvatarThumbnail trên GameStatistic không hiển thị hình ảnh do rbxthumb với UserId âm trong Studio
- **Ngày:** 19-08-2026
- **Vấn đề:** `AvatarThumbnail` trên bảng cá nhân `PlayerStats` và Top 1-3 `TopPlayersStats` trong `GameStatistic` bị trống (không hiển thị ảnh avatar người chơi).
- **Nguyên nhân:** Script dùng chuỗi URL tĩnh `rbxthumb://` trực tiếp mà không kiểm tra `UserId <= 0`. Khi test trong Roblox Studio, `UserId` người chơi là số âm (`-1`, `-2`), khiến CDN Roblox báo lỗi texture không tải được.
- **Fix:** Chuyển sang dùng `Players:GetUserThumbnailAsync` bất đồng bộ trong `task.spawn` với `pcall`, bổ sung fallback `TargetUserId = 1` khi `UserId <= 0` cho môi trường Studio, và truyền đúng `Enum.ThumbnailType` (`AvatarThumbnail` cho Top 1-3, `AvatarBust` cho cá nhân).
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Lỗi Mất Màn Hình Chuyển Cảnh (RoundLoadingScreen) ở Trận Đầu Tiên của Người Chơi Mới
- **Ngày:** 18-08-2026
- **Vấn đề:** Người chơi mới join server luôn bị mất hiệu ứng `RoundLoadingScreen` ở đúng trận đầu tiên của họ, từ trận thứ 2 trở đi mới thấy bình thường.
- **Nguyên nhân:** (1) Khi người chơi mới kết nối, `Init()` cache cứng tham chiếu GUI trước khi nhân vật spawn lần đầu. Khi nhân vật spawn (`CharacterAdded`), Roblox engine tự động hủy và clone mới `PlayerGui.Special` do thuộc tính mặc định `ResetOnSpawn = true` trong Studio, khiến các biến tĩnh trỏ vào GUI chết. (2) Rào cản kiểm tra `IsInMatch` trong phase `Setup` tạo race condition mạng khi Attribute chưa kịp replicate từ Server.
- **Fix:** (1) Xây dựng hàm Dynamic Resolver (`ResolveScreenElements`) để luôn truy xuất instance GuiObject đang active trong `PlayerGui`, tự động ép `ResetOnSpawn = false` và `Enabled = true`. (2) Fallback thông minh `Background = Frame:FindFirstChild("Background") or Frame`. (3) Lắng nghe `CharacterAdded` để chuẩn hóa lại ScreenGui. (4) Bỏ chặn `IsInMatch` trong phase `Setup` (100% người chơi có mặt trong Setup đều tham gia trận mới).
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Lỗi Mất Thanh Nút NavigationButtons/Buttons khi Mở Menu Trước Khi Vào Trận
- **Ngày:** 18-08-2026
- **Vấn đề:** Khi người chơi mở Menu (Shop, Inventory, Profile, Quest) ở sảnh rồi vào trận mà không chủ động đóng lại, sau khi hết trận quay về `Intermission` thì thanh nút `NavigationButtons/Buttons` biến mất hoàn toàn, không thể tương tác lại kể cả khi reset character.
- **Nguyên nhân:** (1) Khi chuyển phase sang `Ready`, `MenuController.CloseAll()` đóng các menu nhưng không khôi phục hiển thị cho container `Buttons`. (2) Sau `GameOver`, Server chưa dọn dẹp sạch thuộc tính `Team` attribute của người chơi khi đưa về sảnh khiến client nhận diện sai trạng thái spectator/player.
- **Fix:** (1) Trong `MenuController.CloseAll()`, gọi `NavCtrl.SetButtonsContainerVisible(not IsSpectating)`. (2) Trong `NavigationController.SetVisible()`, bổ sung phòng thủ tự động bật `ButtonsContainer.Visible = true` khi không có menu tab nào đang mở (`_activeTab == nil`). (3) Trong `MatchService.RunGameOver`, gọi `SessionService.ClearTeam(Player)` và `PlayerStateHelper.SetTeam(Player, nil)` trước khi chuyển sang `Intermission`.
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Lệch nhịp phase Setup giữa Server và Client khi hiển thị thông báo Special Round (Server Setup Race Condition)
- **Ngày:** 18-08-2026
- **Vấn đề:** Khi bắt đầu vòng đấu đặc biệt có `ModeAnnouncement` (4.0s), server chỉ đợi 1.5s rồi lập tức chuyển sang `Ready` và teleport người chơi, khiến màn hình bị fade-out sớm hoặc teleport diễn ra trong lúc người chơi chưa đọc xong thông báo.
- **Nguyên nhân:** Server `MatchService.RunSetup` chỉ tính toán thời gian `FadeInDuration` của màn hình tải cố định mà không tính đến thời lượng trình chiếu của thông báo chế độ.
- **Fix:** Trong `MatchService.RunSetup`, kiểm tra `GameModeHelper.IsSpecialRound(ModeKey)` và gọi `task.wait(GameConfig.GUI.ModeAnnouncement.DisplayDuration)` để đồng bộ tuyệt đối nhịp thời gian giữa Server và Client.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua), [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua)

### Xung đột quyền điều khiển Visible và kẹt Animation khi controller con can thiệp trực tiếp
- **Ngày:** 18-08-2026
- **Vấn đề:** Khi `MenuController` gọi `PopClose` (cần ~0.2s để thu nhỏ `UIScale` về 0), các controller con nếu tự ý set `Frame.Visible = false` ngay lập tức sẽ ngắt cụt animation đóng, gây mất hiệu ứng thu nhỏ hoặc tạo xung đột hiển thị khi mở lại.
- **Nguyên nhân:** Thiếu sự phân định trách nhiệm rõ ràng: cả controller điều phối (`MenuController`) lẫn controller nội dung (`ShopController`, `InventoryController`...) cùng can thiệp vào thuộc tính `Visible` của Frame.
- **Fix:** Chuyển giao 100% quyền quản lý `Frame.Visible` và `PopOpen`/`PopClose` cho `MenuController`. Hàm `Open()`/`Close()` của các controller con chỉ thuần túy làm nhiệm vụ dọn dẹp/nạp dữ liệu (clear list, clean viewport, load data).
- **File liên quan:** [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Lỗi bị cắt đỉnh nút (ClipsDescendants) và xung đột vị trí khi scale trong UIListLayout
- **Ngày:** 18-08-2026
- **Vấn đề:** Khi hover phóng to nút vươn lên trên trong container có `UIListLayout`, nút không thể chỉnh thủ công `Position.Y`, hoặc phần đỉnh nút bị cắt cụt khi vượt quá khung chứa.
- **Nguyên nhân:** (1) `UIListLayout` khóa thuộc tính `Position` của các con và căn theo `VerticalAlignment` mặc định (Center/Top). (2) `ClipsDescendants = true` trên Frame cha tự động cắt bỏ mọi visual vượt ra ngoài bounding box.
- **Fix:** (1) Đặt `AnchorPoint = Vector2.new(0.5, 1)` cho các nút con và đổi `UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom` để layout tự động căn đáy. (2) Tắt `ClipsDescendants = false` trên container `Buttons` và ScreenGui.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Nguy cơ xung đột kích thước và Race Condition khi spam click UI Animation
- **Ngày:** 18-08-2026
- **Vấn đề:** Khi người chơi bấm mở/đóng menu hoặc di chuột liên tục qua các nút với tốc độ cao, các tween song song đè lên nhau khiến Frame bị méo kích thước, kẹt scale ở số trung gian (vd `0.3`) hoặc không thể mở lại.
- **Nguyên nhân:** Tween cũ chưa kịp kết thúc đã bị tween mới ghi đè mà không được hủy (`Cancel`), hoặc tween trực tiếp vào thuộc tính `Size` làm mất kích thước chuẩn ban đầu.
- **Fix:** (1) Dùng bảng `_activeTweens[Instance]` trong `GuiHelper` để tự động gọi `Cancel()` tween cũ trước khi tạo tween mới. (2) Sử dụng `UIScale` thay cho `Size` để bảo toàn kích thước Studio. (3) Khi `PopClose` hoàn tất (`Enum.PlaybackState.Completed`), luôn reset `UIScale.Scale = 1` sau khi gán `Visible = false` để tránh lỗi kẹt scale nếu sau đó UI được mở trực tiếp.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### Bỏ sót sự kiện SFX khi nút bấm nằm trong Frame con lồng sâu (Nesting Frame)
- **Ngày:** 16-08-2026
- **Vấn đề:** Khi tái cấu trúc các nút điều hướng chuyển vào container con (như `NavigationButtons/Buttons/Extra/Profile` và `Setting`), nút bấm bị mất hiệu ứng âm thanh click và hover chuột.
- **Nguyên nhân:** Mã nguồn cũ trong `GameStateController` duyệt trực tiếp qua `Container:GetChildren()`, chỉ kiểm tra các phần tử con cấp 1 trực thuộc `Buttons`. Khi nút nằm trong Frame `Extra` (con cấp 2), `GetChildren()` chỉ thấy Frame `Extra` (không phải `GuiButton`) nên bỏ qua việc gắn sự kiện SFX.
- **Fix:** Thay đổi logic duyệt sang đệ quy toàn bộ con cháu bằng `Container:GetDescendants()` (đóng gói trong `GuiHelper.BindAllNavButtonsSound`), kiểm tra `Descendant:IsA("GuiButton")` để gắn âm thanh cho tất cả các nút bất kể độ sâu phân cấp.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### GUI bị reset khi player chết (ResetOnSpawn)
- **Ngày:** 05-06-2026
- **Vấn đề:** GUI mất trạng thái mỗi khi player character chết và respawn.
- **Nguyên nhân:** Mặc định `ScreenGui.ResetOnSpawn = true` trong Roblox khiến GUI bị clone lại từ StarterGui khi character spawn lại.
- **Fix:** Trong hàm `Init()` của từng Controller, set `ScreenGui.ResetOnSpawn = false` trực tiếp trên instance trong `PlayerGui`.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Spectator / Người chơi mới join bị ẩn Lobby GUI
- **Ngày:** 06-06-2026
- **Vấn đề:** Người chơi mới join server khi trận đang diễn ra bị ẩn Menu và NavigationButton.
- **Nguyên nhân:** Logic Client chỉ dựa vào Game Phase toàn cục để ẩn/hiện GUI, không kiểm tra xem người chơi đó có thuộc một team nào không.
- **Fix:** Client kiểm tra `LocalPlayer:GetAttribute("Team")`; nếu `nil` (Spectator) thì luôn hiển thị GUI Menu/Nav bất kể Phase hiện tại.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### Lỗi không hiển thị 3D Avatar hoặc sai người do nhầm lẫn Username/DisplayName
- **Ngày:** 11-06-2026
- **Vấn đề:** Avatar của các top player không được hiển thị hoặc tra cứu ra `UserId = 0`.
- **Nguyên nhân:** Server gửi `DisplayName` xuống Client, sau đó Client gọi hàm `Players:FindFirstChild(name)` để lấy `UserId`. Tuy nhiên, Roblox đánh chỉ mục `Players` bằng `Username`. Nếu `DisplayName` khác `Username`, tra cứu luôn thất bại.
- **Fix:** Server truyền trực tiếp `UserId = P.UserId` vào danh sách `TopPlayers` khi serialize xuống Client. Client dùng thẳng `data.UserId` để render.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Camera ViewportFrame hiển thị sau lưng (nhìn gáy) nhân vật 3D
- **Ngày:** 11-06-2026
- **Vấn đề:** Khi render mô hình 3D trong `ViewportFrame`, người chơi chỉ thấy gáy (phía sau lưng) của Avatar thay vì khuôn mặt phía trước.
- **Nguyên nhân:** Các Character mặc định luôn quay mặt về hướng âm của trục Z (`-Z`), camera đặt ở trục dương `+distance` nên nhìn thấy gáy.
- **Fix:** Đổi offset trục Z của camera từ `+distance` thành `-distance` để đặt vị trí camera di chuyển lên phía trước mặt Avatar.
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Top 1, 2, 3 không hiển thị Avatar do lỗi phân quyền gọi API phía Client và StreamingEnabled
- **Ngày:** 11-06-2026
- **Vấn đề:** Khung Viewport của các Top player hoàn toàn trống rỗng khi kết thúc trận đấu.
- **Nguyên nhân:** (1) `Players:CreateHumanoidModelFromUserId()` là hàm chỉ chạy ở Server, khi gọi dưới Client sẽ ném lỗi. (2) `StreamingEnabled` làm nhân vật của người chơi khác bị stream out khỏi Client, khiến `character:Clone()` trả về `nil`.
- **Fix:** Server tạo trước các mô hình nhân vật tĩnh trong thư mục tạm `ReplicatedStorage.TempTopPlayers` từ Server trong thời gian đếm ngược GameOver. Client lấy bản sao từ đó để đưa vào ViewportFrame.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### ViewportFrame hiển thị nhân vật chuyển động/nhảy trực tiếp theo thời gian thực
- **Ngày:** 11-06-2026
- **Vấn đề:** Viewport thống kê cá nhân của local player hiển thị nhân vật chuyển động, nhảy nhót theo thao tác của người chơi thực tế.
- **Nguyên nhân:** Nhân vật khi clone vào WorldModel không được Anchor, đồng thời vẫn giữ lại Animator và liên kết khớp xương của client hiện hành.
- **Fix:** Anchor toàn bộ bộ phận vật lý (`BasePart.Anchored = true`), phá hủy (`Destroy`) tất cả Animator, Scripts, Sounds và cấu hình `Humanoid.PlatformStand = true` để khóa cứng tư thế tĩnh.
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Căn chỉnh Camera nhìn trực diện khuôn mặt (Portrait View)
- **Ngày:** 11-06-2026
- **Vấn đề:** Camera trong ViewportFrame hiển thị toàn thân nhân vật ở xa, không rõ mặt.
- **Nguyên nhân:** Code cũ tính toán vị trí camera dựa trên kích thước bounding box toàn bộ cơ thể nhân vật để lấy toàn cảnh.
- **Fix:** Định vị camera dựa trên bộ phận `Head` (đầu) của mô hình, di chuyển camera lên phía trước mặt của đầu theo hướng `LookVector` của `Head` ở khoảng cách 2.5 studs và hướng thẳng tiêu cự vào đầu để cận cảnh khuôn mặt.
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Rò rỉ Bộ nhớ (Memory Leak) khi chuyển đổi danh sách GUI
- **Ngày:** 15-06-2026
- **Vấn đề:** Khi chuyển đổi giữa các tab danh sách (như Icicles và Blocks) hoặc đóng GUI, các đối tượng Model và Camera bên trong `ViewportFrame` vẫn tồn tại trong bộ nhớ Client gây lãng phí tài nguyên.
- **Nguyên nhân:** Các liên kết sự kiện hoặc tham chiếu đối tượng không được hủy bỏ triệt để.
- **Fix:** Viết hàm dọn dẹp (Cleanup) thực hiện huỷ bỏ kết nối (`Disconnect`) các sự kiện xoay và gọi phương thức `:Destroy()` cho các Model, Camera trước khi khởi tạo danh sách mới.
- **File liên quan:** [Menu.rbxmx](../../assets/StarterGui/Menu.rbxmx)

### Trang bị Skin giả mạo từ Client (Server Validation)
- **Ngày:** 15-06-2026
- **Vấn đề:** Người chơi hack client để gửi yêu cầu trang bị các skin hiếm mà họ chưa thực sự sở hữu trong dữ liệu.
- **Nguyên nhân:** Thiếu bước kiểm tra và xác thực dữ liệu từ phía Server khi nhận được tín hiệu RemoteEvent trang bị từ Client.
- **Fix:** Server khi nhận yêu cầu phải đối chiếu danh sách `OwnedCosmetics` trong `DataStore` (hoặc Session Data) của người chơi. Chỉ cho phép trang bị và đồng bộ lại Client nếu hợp lệ.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### FindFirstChild thất bại silent khi tìm element GUI qua Frame trung gian
- **Ngày:** 28-07-2026
- **Vấn đề:** Các element GUI (button, label) tìm được qua Frame trung gian (ví dụ `ItemPreview:FindFirstChild("BuyButton", true)`) trả về `nil` khi nesting thực tế trong Studio khác giả định. Vì code có `if Button then` check, không có lỗi runtime nhưng connection không được tạo — click không phản hồi, text không cập nhật.
- **Nguyên nhân:** Tìm qua Frame trung gian tạo dependency vào cấu trúc nesting cụ thể. Nếu Frame trung gian không chứa element đúng vị trí, toàn bộ search chain thất bại silent.
- **Fix:** Tìm trực tiếp từ root card với `Card:FindFirstChild("ElementName", true)` (recursive) thay vì qua Frame trung gian. Đảm bảo tìm được bất kể element nằm ở đâu trong cây. Với TextLabel bên trong button, dùng `FindFirstChild("Tên thực tế")` thay vì `FindFirstChildOfClass("TextLabel")` để tránh nhầm label không đúng.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### Lỗi Circular Dependency giữa các Controllers khi require trực tiếp
- **Ngày:** 16-06-2026
- **Vấn đề:** Game bị crash hoặc báo lỗi script khi load hệ thống do dependency vòng lặp giữa các controllers.
- **Nguyên nhân:** Các controller require chéo lẫn nhau ở phần khai báo đầu file (top-level) khi được khởi tạo đồng thời bởi `Main.client.lua`.
- **Fix:** Chuyển require của controller phụ thuộc vào trong một hàm getter helper (lazy-require), chỉ require khi thực sự cần dùng ở runtime.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Lỗi crash script khi đổi text trạng thái trên ImageButton
- **Ngày:** 17-06-2026
- **Vấn đề:** Game báo lỗi khi người chơi chọn một vật phẩm mới và script cố gắng cập nhật chữ hiển thị trực tiếp lên nút trang bị (`EquipButton.Text = ...`).
- **Nguyên nhân:** Nút `EquipButton` trong thiết kế thực tế ở Studio là một `ImageButton` nên không có thuộc tính `Text`.
- **Fix:** Thực hiện kiểm tra động: Nếu nút có chứa một `TextLabel` con tên là `StatusText` thì cập nhật chữ lên đó; nếu không có thì mới ghi đè trực tiếp `.Text` (để hỗ trợ ngược cho `TextButton`), tránh lỗi runtime.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Chỉ số Profile không cập nhật sau khi kết thúc trận đấu (Lỗi Cache Tĩnh)
- **Ngày:** 17-06-2026
- **Vấn đề:** Khi người chơi chiến thắng hoặc thực hiện đóng băng/rã đông trong trận đấu, các chỉ số thống kê trong Profile không thay đổi khi họ mở lại Profile ở Lobby, chỉ cập nhật khi thoát ra vào lại server.
- **Nguyên nhân:** Client lưu trữ cache tĩnh `_localData` tại `PlayerDataController` và chỉ load một lần duy nhất khi join server. Khi kết thúc trận, Server lưu các chỉ số vào DataStore và chỉ đẩy sự kiện cập nhật tiền (`UpdateMoney`) chứ không đồng bộ lại toàn bộ thống kê về Client.
- **Fix:** Bổ dung hàm `RefreshData()` trong `PlayerDataController` để gọi server lấy data mới, đồng thời gọi bất đồng bộ hàm này mỗi khi mở Profile (`ProfileController.lua`) và Inventory (`InventoryController.lua`) để cập nhật lại UI bằng dữ liệu mới nhất.
- **File liên quan:** [PlayerDataController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Vật phẩm mới mua không hiển thị trong Inventory sau khi mua rương
- **Ngày:** 22-06-2026
- **Vấn đề:** Khi mua rương, tiền bị trừ đúng nhưng item mới không hiển thị trong Inventory.
- **Nguyên nhân:** (1) `InventoryController` đọc trường `Data.OwnedCosmetics` cũ thay vì `Data.OwnedIcicles` và `Data.OwnedBlocks` mới của Phase 5. (2) `ShopController` không cập nhật lại local cache của client sau khi RemoteFunction giao dịch mua rương hoàn thành.
- **Fix:** (1) Sửa `InventoryController` đọc đúng `Data.OwnedIcicles`/`OwnedBlocks` theo tab đang chọn (giữ tương thích ngược với `OwnedCosmetics`). (2) Trong `ShopController`, gọi `PlayerDataController.RefreshData()` bất đồng bộ qua `task.spawn` ngay khi giao dịch mua thành công.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### Lỗi GetBoundingBox trên Part/MeshPart đơn lẻ và giải pháp Asset Model
- **Ngày:** 23-06-2026
- **Vấn đề:** Khi render mô hình tĩnh, code gọi `Model:GetBoundingBox()` bị crash đối với các asset được lưu dưới dạng Part hoặc MeshPart đơn lẻ (như Icicle) thay vì Model. Lỗi này làm dừng luồng xử lý GUI, gây crash các logic phía sau (như không tắt được popup do chưa kịp kết nối CloseButton).
- **Nguyên nhân:** Khác biệt cấu trúc lưu trữ asset trong ReplicatedStorage giữa các vật phẩm (Block là Model, Icicle là Part).
- **Fix:** Thay vì sửa code ViewportManager phức tạp để tính toán AABB cho Part, người dùng thống nhất sửa thủ công bằng cách bọc (wrap) tất cả các asset preview dạng Part/MeshPart thành Model trong Roblox Studio để bảo toàn tính đồng nhất của hệ thống.
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### Lỗi không thể spectate khi người chơi quá xa do StreamingEnabled
- **Ngày:** 26-06-2026 (cập nhật 27-06-2026)
- **Vấn đề:** Khi người chơi bật spectate mục tiêu ở quá xa lobby, camera không chuyển sang mục tiêu mà chỉ focus tại chỗ.
- **Nguyên nhân:** Dưới chế độ `StreamingEnabled`, character của người chơi ở xa bị stream out (bị hủy) hoàn toàn ở client, dẫn đến `TargetPlayer.Character` trả về `nil`. Client không có Vector3 vị trí để gọi `RequestStreamAroundAsync`.
- **Fix:** client gửi RemoteEvent `RequestSpectateTarget` yêu cầu Server set `Player.ReplicationFocus` trỏ vào `HumanoidRootPart` của target player. Client poll kiểm tra nhân vật mỗi 0.1 giây (timeout 5s) và hướng camera khi nhân vật đã được tải đầy đủ.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Lỗi lơ lửng và mất di chuyển của Spectator khi tắt Spectate
- **Ngày:** 27-06-2026
- **Vấn đề:** Spectator bị lơ lửng khi đang spectate, và khi tắt (Close) spectate thì bị đóng băng tại chỗ, không thể di chuyển ở lobby.
- **Nguyên nhân:** `ReplicationFocus` dời sang target khiến vùng lobby bị stream out (mất physics mô phỏng). Khi tắt spectate, camera quay lại lobby nhưng `ReplicationFocus` không được reset, khiến lobby vẫn bị stream out.
- **Fix:** (1) Khóa di chuyển của spectator (`WalkSpeed = 0`, `JumpPower = 0`) khi đang xem để nhân vật không bị trôi do mất physics. (2) Gửi yêu cầu `RequestSpectateTarget` với tham số `nil` để server reset `ReplicationFocus` về chính spectator HRP khi tắt spectate, đồng thời khôi phục tốc độ di chuyển chuẩn.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Lỗi nhấp nháy/flickering của NavigationButton khi đang spectate
- **Ngày:** 27-06-2026
- **Vấn đề:** Khi đang spectate, nút NavigationButton bị ẩn đi rồi tự động hiện lại xen kẽ sau mỗi vài giây.
- **Nguyên nhân:** `GameStateController` định kỳ cập nhật thông tin phase/thời gian từ server và gọi `SetLobbyGuisVisible(true)` để hiển thị các lobby GUI, ghi đè hành động ẩn nút của `SpectateController`.
- **Fix:** Thay đổi `SetLobbyGuisVisible` trong `GameStateController` để kiểm tra trạng thái qua `SpectateController.IsSpectating()`. Chỉ kích hoạt lại `NavGui.Enabled = true` nếu người chơi không ở trong chế độ spectate.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

### Lỗi timing khiến người chơi join muộn không tương tác được với nút Spectate
- **Ngày:** 26-06-2026
- **Vấn đề:** Khi người chơi mới kết nối vào server khi trận đấu đang diễn ra, các nút điều khiển spectate (Next/Back/Close) và nút Spectate chính không phản hồi khi bấm.
- **Nguyên nhân:** Script client truy vấn các đối tượng GUI ở phần khai báo top-level bằng `WaitForChild(..., timeout)`. Do người chơi join muộn, một số UI element chưa kịp load xong trước khi timeout kết thúc, dẫn đến biến tham chiếu bị `nil` và làm crash luồng khởi tạo của controller.
- **Fix:** Di chuyển toàn bộ các câu lệnh tìm kiếm UI element bằng `WaitForChild` từ top-level vào bên trong hàm khởi tạo `Init()`, đồng thời loại bỏ tham số timeout để đảm bảo script luôn đợi đến khi GUI load thành công.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

### Lỗi người chơi mới join giữa trận không nhận được danh sách Spectate
- **Ngày:** 26-06-2026
- **Vấn đề:** Người chơi mới kết nối vào server khi trận đấu đang diễn ra có thể mở được giao diện Spectate nhưng danh sách người chơi để quan sát trống rỗng, không thể spectate ai.
- **Nguyên nhân:** Server chỉ broadcast danh sách người chơi thi đấu (`UpdateSpectateList`) tại thời điểm bắt đầu phase `InGame` hoặc khi có thay đổi trạng thái đóng băng/rã đông. Người chơi kết nối sau thời điểm đó sẽ không nhận được dữ liệu ban đầu.
- **Fix:** Trong `MatchService:Init()`, bổ sung lắng nghe sự kiện `Players.PlayerAdded`. Khi có người chơi mới tham gia và game đang trong phase `InGame`, Server đợi 2 giây (để client load xong remote) rồi gửi riêng danh sách người chơi Normal hiện tại cho client đó qua `FireClient`.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Không hiển thị AvatarThumbnail trên PlayerStatus và ScoreBoard khi clone
- **Ngày:** 19-07-2026
- **Vấn đề:** Ảnh đại diện người chơi (`AvatarThumbnail` 2D) không hiển thị (chỉ hiện nền background) sau khi clone các frame người chơi.
- **Nguyên nhân:** (1) Khối xử lý `task.spawn` tải ảnh bất đồng bộ qua `GetUserThumbnailAsync` được gọi trước khi gán `Clone.Parent`. Khi API hoàn thành quá nhanh hoặc đồng bộ, `Clone.Parent` lúc check vẫn là `nil`, khiến logic gán `.Image` bị bỏ quan. (2) `UserId` âm trong Studio test gây lỗi API tải ảnh.
- **Fix:** Di chuyển logic gán `Clone.Parent` lên trước khi gọi `task.spawn`. Đồng thời, nếu `UserId <= 0`, đổi thành `1` làm fallback để test được trong Studio.
- **File liên quan:** [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua)

### Lỗi ký tự BOM (U+FEFF) khi ghi file bằng PowerShell khiến Luau crash
- **Ngày:** 20-07-2026
- **Vấn đề:** Trình biên dịch Luau của Roblox báo lỗi `Expected identifier when parsing expression, got Unicode character U+feff` ở dòng 1 và module không thể load.
- **Nguyên nhân:** Lệnh PowerShell `Set-Content -Encoding UTF8` ghi tệp tin đính kèm mã Byte Order Mark (BOM - `U+FEFF`) ở đầu tệp tin, vốn không được Luau hỗ trợ.
- **Fix:** Ghi đè tệp tin sử dụng các thư viện chuẩn của hệ thống hoặc trình soạn thảo hỗ trợ UTF-8 Standard (No BOM).
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua)

### Lỗi crash QuestController do thiếu hàm require SpectateController
- **Ngày:** 21-07-2026
- **Vấn đề:** Khi người chơi đóng Quest GUI, NavigationButton/Button không hiển thị lại và xuất hiện lỗi crash ở client: `QuestController:312: attempt to call a nil value`.
- **Nguyên nhân:** Hàm `CloseQuest` thực hiện kiểm tra `IsSpectating` bằng cách gọi `GetSpectateController()`, tuy nhiên hàm lazy-require này chưa được định nghĩa trong script. Đồng thời việc gán `_navButton` sử dụng `FindFirstChild` có nguy cơ trả về `nil` do UI chưa tải kịp.
- **Fix:** Định nghĩa hàm `GetSpectateController()` lazy-require trong QuestController, đồng thời đổi việc lấy `_navButton` thành `WaitForChild("Button")`.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua)

### Lỗi ScoreBoard trống trơn và Player Status avatar hiển thị sai đội ở trận đầu tiên
- **Ngày:** 21-07-2026
- **Vấn đề:** ScoreBoard bị trống hoàn toàn và HUD hiển thị avatar xếp sai cột Ally/Enemy cho người chơi ở trận đầu tiên.
- **Nguyên nhân:** Do race condition giữa sự kiện RemoteEvent `SetTeamAssignment` và việc đồng bộ thuộc tính `"Team"` (Property Replication), dẫn đến client kiểm tra `LocalPlayer:GetAttribute("Team")` bị `nil` ngay tại thời điểm nhận event.
- **Fix:** Lấy thông tin team của LocalPlayer trực tiếp từ payload `Teams` gửi kèm sự kiện (`Teams[tostring(LocalPlayer.UserId)]`) thay vì đọc qua attribute.
- **File liên quan:** [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [PlayerStatusController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua)

### Lỗi Gui Spectate không hiển thị do bị HideAllFrames của MenuController ẩn đè
- **Ngày:** 18-08-2026
- **Vấn đề:** Bấm nút Spectate trên thanh NavigationButtons nhưng giao diện Spectate không xuất hiện.
- **Nguyên nhân:** Trong `SpectateController.SetVisible(true)`, code gọi `MenuController.CloseAll()` ngay sau khi set `SpectateGui.Visible = true`. Vì `Spectate` nằm trong ScreenGui `Menu`, `CloseAll` gọi `HideAllFrames()` duyệt qua tất cả con và ép `SpectateGui.Visible = false` ngay lập tức.
- **Fix:** Đảo thứ tự đóng menu trước rồi mới hiện `SpectateGui`, đồng thời cập nhật `CloseAll`/`HideAllFrames` hỗ trợ tham số `ExcludedFrame` để không ẩn đè `SpectateGui`.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MenuController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/MenuController.lua)

### Lỗi mất NavigationButtons vĩnh viễn và kẹt camera sau khi Reset / Chết trong Spectate Mode
- **Ngày:** 18-08-2026
- **Vấn đề:** Người chơi bật Spectate rồi reset nhân vật (hoặc chết) thì NavigationButtons không hiện lại, và khi hết trận camera bị kẹt cố định tại một điểm trong không gian.
- **Nguyên nhân:** (1) `SpectateController` không lắng nghe `LocalPlayer.CharacterAdded`, khiến cờ `_isSpectating` vẫn là `true` sau khi chết; `NavigationController.SetVisible` liên tục kiểm tra và ép ẩn NavigationButtons. (2) `RestoreCamera` cố gán `CameraSubject` vào instance `Humanoid` cũ đã bị hủy của nhân vật trước đó. (3) `MatchService` trên Server chặn lệnh reset `ReplicationFocus` khi phase không còn là `InGame`.
- **Fix:** (1) Lắng nghe `CharacterAdded` để tự động tắt spectate, mở lại NavigationButtons và khôi phục di chuyển. (2) `RestoreCamera` kiểm tra tính hợp lệ của Humanoid cũ, nếu đã bị hủy thì fallback bám theo nhân vật mới tại sảnh và đặt `CameraType = Custom`. (3) Cho phép server xử lý yêu cầu reset `ReplicationFocus` ở mọi phase.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)

### Lỗi ScoreBoardButton không phản hồi sau khi di chuyển vào Frame con
- **Ngày:** 21-08-2026
- **Vấn đề:** Bấm `ScoreBoardButton` không hiện ScoreBoard.
- **Nguyên nhân:** Khi `ScoreBoardButton` được di chuyển từ `InGameGui` vào frame con `InGameGui/Buttons`, mỗi controller tự resolve path GUI độc lập. Cả `GameStateController` lẫn `ScoreBoardController` đều dùng `InGameGui:FindFirstChild("ScoreBoardButton")` — trả về `nil` vì button đã đổi chỗ. Lỗi silent (không crash) nhưng event không được gắn.
- **Fix:** Khai báo path mới trong `GuiConfig.InGameButtons = { Buttons, ScoreBoardButton }`. Cập nhật đồng thời **cả 2** controller `GameStateController` và `ScoreBoardController` để resolve qua `InGameGui/Buttons/ScoreBoardButton`. Bài học: khi di chuyển GUI element, grep toàn bộ codebase tìm mọi nơi resolve element đó.
- **File liên quan:** [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [ScoreBoardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### Lỗi SpectateGui hiện rồi tắt ngay (flickering) khi player InMatch InGame
- **Ngày:** 21-08-2026
- **Vấn đề:** Bấm `SpectateButton` (khi bị Frozen trong trận), GUI Spectate hiện khoảng 1 giây rồi tự ẩn.
- **Nguyên nhân:** `SpectateGui` nằm trong `ScreenGui Menu`. `GameStateController` nhận `UpdateGameState` broadcast từ server **mỗi giây**, gọi `MenuCtrl.SetVisible(false)` → `MenuGui.Enabled = false` → mọi con trong Menu bị ẩn theo. Việc set `MenuGui.Enabled = true` tạm thời bị override ngay giây tiếp theo.
- **Fix:** Di chuyển `SpectateGui` ra khỏi `ScreenGui Menu` sang `ObserverGui` độc lập. `ObserverGui.Enabled` do `GameStateController` quản lý theo phase (giống `InGameGui`), không bị `MenuCtrl.SetVisible` ảnh hưởng.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Kiến trúc ObserverGui — ScreenGui độc lập cho hệ thống quan sát
- **Ngày:** 21-08-2026
- **Chi tiết:** Thay vì đặt `SpectateGui` trong `ScreenGui Menu` (bị disable khi InMatch InGame) hoặc `InGameGui` (chỉ dành cho người trong trận), tạo `ScreenGui ObserverGui` độc lập. Mục tiêu: giao thoa tương tác giữa người trong trận và Spectator — phục vụ cả Lobby Spectator (ngoài trận) lẫn Frozen Spectator (trong trận). `ObserverGui.Enabled` được `GameStateController` quản lý theo lifecycle giống `InGameGui` (bật trong Ready/InGame/GameOver, tắt trong Intermission). `SpectateController` là sole owner quản lý `SpectateGui.Visible` bên trong.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [GameStateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### Kiến trúc Frozen Spectator — phân biệt 2 loại spectator trong SpectateController
- **Ngày:** 21-08-2026
- **Chi tiết:** `SpectateController` phân biệt 2 loại spectator bằng cờ `_isFrozenSpectator`: (A) **Lobby Spectator** (`IsInMatch = false`) — lock movement, restore nav bar khi tắt. (B) **Frozen Spectator** (`IsInMatch = true`, state Frozen) — không lock/unlock movement (server quản lý), không ẩn/hiện nav bar. Server mở rộng `RequestSpectateTarget` handler: Frozen + HasTeams chỉ cho target đồng minh Normal; Frozen + FFA cho target bất kỳ Normal. Client tự filter danh sách theo `Player:GetAttribute("Team")` (client-side filter). `UpdatePlayerState` listener toggle `SpectateButton.Visible` và tắt spectate khi Thaw/Dead. `CharacterAdded` dùng làm safety net reset state.
- **File liên quan:** [SpectateController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua)
