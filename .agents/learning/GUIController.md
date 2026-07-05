# GUIController
> Tổng hợp kiến thức về quản lý GUI phía client theo trạng thái game trong dự án.
> Cập nhật lần cuối: 06-07-2026

---

## Kiến trúc

### Quản lý visibility GUI theo phase game + trạng thái team (Spectator-aware)
- **Ngày:** 05-06-2026 (cập nhật 06-06-2026)
- **Chi tiết:** Các ScreenGui được chia thành 2 nhóm: "Lobby GUI" (Menu, NavigationButton) và "Gameplay GUI" (GameStatistic). Logic hiển thị Lobby GUI sử dụng 2 tầng kiểm tra: (1) **Tầng Team**: `LocalPlayer:GetAttribute("Team")` — nếu `nil` (Spectator/late-joiner) thì luôn hiện GUI bất kể phase; nếu có team mới vào tầng 2. (2) **Tầng Phase**: bảng `GAMEPLAY_PHASES = { Ready, InGame, GameOver }` tra cứu nhanh để ẩn GUI khi đang trong trận. Cache `_lastPhase / _lastTimeRemaining / _lastIsFrozenState` được lưu mỗi lần `UpdateDisplay` để `GetAttributeChangedSignal("Team")` có thể re-evaluate đúng lúc Attribute thay đổi. Server đồng bộ team qua `Player:SetAttribute("Team", ...)` thay vì Remote Event riêng.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/SessionService.lua)

### Render 3D Avatar lên GUI (ViewportFrame & WorldModel)
- **Ngày:** 10-06-2026 (cập nhật 11-06-2026)
- **Chi tiết:** Thay thế avatar 2D bằng `ViewportFrame` và `WorldModel`. Để tránh lỗi phân quyền `Players:CreateHumanoidModelFromUserId()` (chỉ chạy ở server) và lỗi `StreamingEnabled` làm mất nhân vật, Server sinh trước model tĩnh cho Top 1,2,3 tại thư mục `ReplicatedStorage.TempTopPlayers` khi kết thúc trận, Client chỉ cần clone về. Đối với hiển thị tĩnh cho LocalPlayer, Client clone nhân vật hiện tại và triệt tiêu mọi chuyển động bằng cách: Anchor toàn bộ `BasePart`, xóa sạch `Animator/Script/LocalScript/Sound`, và chỉnh `Humanoid.PlatformStand = true`.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Thiết kế UI Template Động qua Module Config (Inventory)
- **Ngày:** 15-06-2026
- **Chi tiết:** Thay thế nhiều template UI bằng duy nhất một `ItemFrame` chung kết hợp với `RarityConfig` chứa màu sắc, ảnh nền của từng độ hiếm. Client render tự động gán thuộc tính động từ Config, tránh hardcode thông số hiển thị trực tiếp trong code.
- **File liên quan:** [RarityConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/RarityConfig.lua)

### Quản lý Tài nguyên Đồ họa trong Dự án Sử dụng Rojo
- **Ngày:** 15-06-2026
- **Chi tiết:** Tránh Rojo xóa folder assets đồ họa (UI, Mesh Previews...) trong `ReplicatedStorage` khi sync bằng cách cấu hình `default.project.json` chỉ đồng bộ các thư mục con chứa Script (như `Controllers`, `Shared`...). Folder `ReplicatedStorage/Assets` được quản lý trực tiếp trong Roblox Studio để bảo toàn nguyên vẹn.
- **File liên quan:** [default.project.json](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/default.project.json)

### Tự động hóa Camera ViewportFrame qua Bounding Box và Config (`ViewportManager`)
- **Ngày:** 23-06-2026
- **Chi tiết:** Tự động hóa camera bằng `ViewportManager` dựa trên Bounding Box của mô hình 3D. Hỗ trợ ghi đè góc nhìn (Pitch, Yaw, FOV, Padding) qua cấu hình phân tầng `ViewportConfig` (Default -> Type -> ItemId) trên tất cả các tab Inventory, Shop và Profile.
- **File liên quan:** [ViewportManager.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [ViewportConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/ViewportConfig.lua)

### Tránh Circular Dependency giữa các Controller bằng Lazy-require
- **Ngày:** 16-06-2026
- **Chi tiết:** Khi `GameStateController` cần ẩn/hiện các tab menu, việc require chéo trực tiếp ở top-level của các controller gây crash. Áp dụng lazy-require: require bên trong hàm helper getter và cache lại cho lần gọi đầu tiên để phá vỡ vòng lặp dependency lúc khởi tạo.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Inventory Controller - Data Flow Pattern (Local Cache + Client State Update)
- **Ngày:** 16-06-2026
- **Chi tiết:** Để tối ưu UX, Client đọc dữ liệu từ local cache `PlayerDataController.GetData()` thay vì liên tục gọi server. Khi trang bị skin mới, Client gửi RemoteEvent lên Server. Nhận xác nhận thành công, Client tự cập nhật cache local và làm mới UI ngay lập tức.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [PlayerDataController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua)

### Logic hiển thị nút trang bị (EquipButton State Logic)
- **Ngày:** 16-06-2026
- **Chi tiết:** Trạng thái của EquipButton cập nhật động khi chọn item. Đối chiếu ID vật phẩm chọn với cache local. Trùng khớp thì đổi nhãn thành "Equipped" và khóa click (`Active = false`), khác biệt thì hiện "Equip" và cho click (`Active = true`).
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Tách biệt UI Template cho mục đích tái sử dụng (Shared Assets)
- **Ngày:** 17-06-2026
- **Chi tiết:** Đưa `ItemTemplate` ra thư mục dùng chung `ReplicatedStorage.Assets.Gui.ItemTemplate` để các controller khác (như Shop, Gifts) dễ dàng clone, đồng bộ mỹ thuật UI và giảm thiểu trùng lặp asset.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Highlight Tab an toàn không phụ thuộc thuộc tính Font/Text (ImageButton-safe)
- **Ngày:** 17-06-2026
- **Chi tiết:** Khi dùng `ImageButton` thay cho `TextButton` làm nút chuyển tab, việc truy cập các thuộc tính Text sẽ gây crash. Sửa bằng cách thay đổi `.BackgroundColor3` trực tiếp trên nút (màu trắng `#FFFFFF` khi active và xám `#2F2F2F` khi inactive) để hiển thị active tab.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Cơ chế click linh hoạt cho UI Template (Robust Click Event Binding)
- **Ngày:** 17-06-2026
- **Chi tiết:** Hỗ trợ click linh hoạt cho UI template: (1) Nếu là `GuiButton` thì kết nối `MouseButton1Click`; (2) Nếu là `Frame` thì tìm `GuiButton` con; (3) Nếu không có nút con nào, lắng nghe sự kiện `InputBegan` để bắt hành động Click/Touch.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Tải và Đồng bộ hóa Dữ liệu Client theo yêu cầu (Lazy-load Data Sync)
- **Ngày:** 17-06-2026
- **Chi tiết:** Nhằm tránh dữ liệu stats cũ bị hiển thị sai sau trận đấu, áp dụng Lazy-loading. Cung cấp hàm `PlayerDataController.RefreshData()`. Khi mở GUI Profile/Inventory, Client hiện dữ liệu cache có sẵn trước, sau đó chạy `task.spawn` kéo dữ liệu mới từ Server để cập nhật lại UI bất đồng bộ mà không block giao diện.
- **File liên quan:** [PlayerDataController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [ProfileController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### Hệ thống Spectate cho Spectator (Spectate System)
- **Ngày:** 26-06-2026
- **Chi tiết:** Xây dựng hệ thống quan sát trận đấu (Spectate) dành riêng cho người chơi không có đội (Spectator) trong phase `InGame`. Sử dụng Orbit Camera (CameraType.Custom, thiết lập `CameraSubject` trỏ đến `Humanoid` của người chơi đang thi đấu). Client duyệt chuyển đổi mục tiêu qua các nút điều hướng (Next/Back).
- **File liên quan:** [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Điều phối Streaming cho Spectate bằng ReplicationFocus và Lock Movement
- **Ngày:** 27-06-2026
- **Chi tiết:** Dưới chế độ `StreamingEnabled`, khi dời camera sang target ở xa, ta phải thay đổi tâm stream để tải dữ liệu đấu trường. Giải pháp là dịch chuyển `Player.ReplicationFocus` từ character của chính spectator sang `HumanoidRootPart` của target thông qua yêu cầu từ client gửi lên server. Đồng thời, trong khi spectate, cần khóa di chuyển (`WalkSpeed = 0`, `JumpPower = 0`, `JumpHeight = 0`) phía client để nhân vật spectator không bị trôi dạt do mất physics mô phỏng vùng lobby bị stream out. Khi tắt spectate, server trả lại `ReplicationFocus` về spectator HRP và client phục hồi tốc độ di chuyển gốc từ cấu hình `GameConfig`.
- **File liên quan:** [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua), [GameConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### Hệ thống GUI SFX phân tán theo Controller (Phase 8.3)
- **Ngày:** 06-07-2026
- **Chi tiết:** Mỗi controller tự quản lý âm thanh GUI riêng thay vì gộp vào một module trung tâm. Dùng hàm helper cục bộ `PlayGuiSound(SoundId)` trong mỗi controller: tạo `Sound` object, gán `rbxassetid://`, parent vào `PlayerGui`, gọi `:Play()` rồi tự hủy qua `Debris:AddItem(S, 3)`. Quy tắc áp dụng: `CloseButton` → close sfx; tab/equip/nav buttons → button click sfx; `Buy1/Buy3` → ChestBuy (success) hoặc buy fail (fail) tùy `Result.Success`; `ClaimButton` (Quest) → QuestReward sfx; `ShowPlayerStats` → overall sfx. NavigationButton bind cả `MouseEnter` (hover) lẫn `MouseButton1Click`. Ưu điểm: độc lập, không tạo dependency mới, dễ mở rộng per-controller trong tương lai.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [QuestController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [ProfileController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

---

## Bug & biện pháp

### GUI bị reset khi player chết (ResetOnSpawn)
- **Ngày:** 05-06-2026
- **Vấn đề:** GUI mất trạng thái mỗi khi player character chết và respawn.
- **Nguyên nhân:** Mặc định `ScreenGui.ResetOnSpawn = true` trong Roblox khiến GUI bị clone lại từ StarterGui khi character spawn lại.
- **Fix:** Trong hàm `Init()` của từng Controller, set `ScreenGui.ResetOnSpawn = false` trực tiếp trên instance trong `PlayerGui`.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Spectator / Người chơi mới join bị ẩn Lobby GUI
- **Ngày:** 06-06-2026
- **Vấn đề:** Người chơi mới join server khi trận đang diễn ra bị ẩn Menu và NavigationButton.
- **Nguyên nhân:** Logic Client chỉ dựa vào Game Phase toàn cục để ẩn/hiện GUI, không kiểm tra xem người chơi đó có thuộc một team nào không.
- **Fix:** Client kiểm tra `LocalPlayer:GetAttribute("Team")`; nếu `nil` (Spectator) thì luôn hiển thị GUI Menu/Nav bất kể Phase hiện tại.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/SessionService.lua)

### Lỗi không hiển thị 3D Avatar hoặc sai người do nhầm lẫn Username/DisplayName
- **Ngày:** 11-06-2026
- **Vấn đề:** Avatar của các top player không được hiển thị hoặc tra cứu ra `UserId = 0`.
- **Nguyên nhân:** Server gửi `DisplayName` xuống Client, sau đó Client gọi hàm `Players:FindFirstChild(name)` để lấy `UserId`. Tuy nhiên, Roblox đánh chỉ mục `Players` bằng `Username`. Nếu `DisplayName` khác `Username`, tra cứu luôn thất bại.
- **Fix:** Server truyền trực tiếp `UserId = P.UserId` vào danh sách `TopPlayers` khi serialize xuống Client. Client dùng thẳng `data.UserId` để render.
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua), [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Camera ViewportFrame hiển thị sau lưng (nhìn gáy) nhân vật 3D
- **Ngày:** 11-06-2026
- **Vấn đề:** Khi render mô hình 3D trong `ViewportFrame`, người chơi chỉ thấy gáy (phía sau lưng) của Avatar thay vì khuôn mặt phía trước.
- **Nguyên nhân:** Các Character mặc định luôn quay mặt về hướng âm của trục Z (`-Z`), camera đặt ở trục dương `+distance` nên nhìn thấy gáy.
- **Fix:** Đổi offset trục Z của camera từ `+distance` thành `-distance` để đặt vị trí camera di chuyển lên phía trước mặt Avatar.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Top 1, 2, 3 không hiển thị Avatar do lỗi phân quyền gọi API phía Client và StreamingEnabled
- **Ngày:** 11-06-2026
- **Vấn đề:** Khung Viewport của các Top player hoàn toàn trống rỗng khi kết thúc trận đấu.
- **Nguyên nhân:** (1) `Players:CreateHumanoidModelFromUserId()` là hàm chỉ chạy ở Server, khi gọi dưới Client sẽ ném lỗi. (2) `StreamingEnabled` làm nhân vật của người chơi khác bị stream out khỏi Client, khiến `character:Clone()` trả về `nil`.
- **Fix:** Server tạo trước các mô hình nhân vật tĩnh trong thư mục tạm `ReplicatedStorage.TempTopPlayers` từ Server trong thời gian đếm ngược GameOver. Client lấy bản sao từ đó để đưa vào ViewportFrame.
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua), [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### ViewportFrame hiển thị nhân vật chuyển động/nhảy trực tiếp theo thời gian thực
- **Ngày:** 11-06-2026
- **Vấn đề:** Viewport thống kê cá nhân của local player hiển thị nhân vật chuyển động, nhảy nhót theo thao tác của người chơi thực tế.
- **Nguyên nhân:** Nhân vật khi clone vào WorldModel không được Anchor, đồng thời vẫn giữ lại Animator và liên kết khớp xương của client hiện hành.
- **Fix:** Anchor toàn bộ bộ phận vật lý (`BasePart.Anchored = true`), phá hủy (`Destroy`) tất cả Animator, Scripts, Sounds và cấu hình `Humanoid.PlatformStand = true` để khóa cứng tư thế tĩnh.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Căn chỉnh Camera nhìn trực diện khuôn mặt (Portrait View)
- **Ngày:** 11-06-2026
- **Vấn đề:** Camera trong ViewportFrame hiển thị toàn thân nhân vật ở xa, không rõ mặt.
- **Nguyên nhân:** Code cũ tính toán vị trí camera dựa trên kích thước bounding box toàn bộ cơ thể nhân vật để lấy toàn cảnh.
- **Fix:** Định vị camera dựa trên bộ phận `Head` (đầu) của mô hình, di chuyển camera lên phía trước mặt của đầu theo hướng `LookVector` của `Head` ở khoảng cách 2.5 studs và hướng thẳng tiêu cự vào đầu để cận cảnh khuôn mặt.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Rò rỉ Bộ nhớ (Memory Leak) khi chuyển đổi danh sách GUI
- **Ngày:** 15-06-2026
- **Vấn đề:** Khi chuyển đổi giữa các tab danh sách (như Icicles và Blocks) hoặc đóng GUI, các đối tượng Model và Camera bên trong `ViewportFrame` vẫn tồn tại trong bộ nhớ Client gây lãng phí tài nguyên.
- **Nguyên nhân:** Các liên kết sự kiện hoặc tham chiếu đối tượng không được hủy bỏ triệt để.
- **Fix:** Viết hàm dọn dẹp (Cleanup) thực hiện huỷ bỏ kết nối (`Disconnect`) các sự kiện xoay và gọi phương thức `:Destroy()` cho các Model, Camera trước khi khởi tạo danh sách mới.
- **File liên quan:** [Menu.rbxmx](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/assets/GUI/Menu.rbxmx)

### Trang bị Skin giả mạo từ Client (Server Validation)
- **Ngày:** 15-06-2026
- **Vấn đề:** Người chơi hack client để gửi yêu cầu trang bị các skin hiếm mà họ chưa thực sự sở hữu trong dữ liệu.
- **Nguyên nhân:** Thiếu bước kiểm tra và xác thực dữ liệu từ phía Server khi nhận được tín hiệu RemoteEvent trang bị từ Client.
- **Fix:** Server khi nhận yêu cầu phải đối chiếu danh sách `OwnedCosmetics` trong `DataStore` (hoặc Session Data) của người chơi. Chỉ cho phép trang bị và đồng bộ lại Client nếu hợp lệ.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Lỗi Circular Dependency giữa các Controllers khi require trực tiếp
- **Ngày:** 16-06-2026
- **Vấn đề:** Game bị crash hoặc báo lỗi script khi load hệ thống do dependency vòng lặp giữa các controllers.
- **Nguyên nhân:** Các controller require chéo lẫn nhau ở phần khai báo đầu file (top-level) khi được khởi tạo đồng thời bởi `Main.client.lua`.
- **Fix:** Chuyển require của controller phụ thuộc vào trong một hàm getter helper (lazy-require), chỉ require khi thực sự cần dùng ở runtime.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Lỗi crash script khi đổi text trạng thái trên ImageButton
- **Ngày:** 17-06-2026
- **Vấn đề:** Game báo lỗi khi người chơi chọn một vật phẩm mới và script cố gắng cập nhật chữ hiển thị trực tiếp lên nút trang bị (`EquipButton.Text = ...`).
- **Nguyên nhân:** Nút `EquipButton` trong thiết kế thực tế ở Studio là một `ImageButton` nên không có thuộc tính `Text`.
- **Fix:** Thực hiện kiểm tra động: Nếu nút có chứa một `TextLabel` con tên là `StatusText` thì cập nhật chữ lên đó; nếu không có thì mới ghi đè trực tiếp `.Text` (để hỗ trợ ngược cho `TextButton`), tránh lỗi runtime.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Chỉ số Profile không cập nhật sau khi kết thúc trận đấu (Lỗi Cache Tĩnh)
- **Ngày:** 17-06-2026
- **Vấn đề:** Khi người chơi chiến thắng hoặc thực hiện đóng băng/rã đông trong trận đấu, các chỉ số thống kê trong Profile không thay đổi khi họ mở lại Profile ở Lobby, chỉ cập nhật khi thoát ra vào lại server.
- **Nguyên nhân:** Client lưu trữ cache tĩnh `_localData` tại `PlayerDataController` và chỉ load một lần duy nhất khi join server. Khi kết thúc trận, Server lưu các chỉ số vào DataStore và chỉ đẩy sự kiện cập nhật tiền (`UpdateMoney`) chứ không đồng bộ lại toàn bộ thống kê về Client.
- **Fix:** Bổ dung hàm `RefreshData()` trong `PlayerDataController` để gọi server lấy data mới, đồng thời gọi bất đồng bộ hàm này mỗi khi mở Profile (`ProfileController.lua`) và Inventory (`InventoryController.lua`) để cập nhật lại UI bằng dữ liệu mới nhất.
- **File liên quan:** [PlayerDataController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [ProfileController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Vật phẩm mới mua không hiển thị trong Inventory sau khi mua rương
- **Ngày:** 22-06-2026
- **Vấn đề:** Khi mua rương, tiền bị trừ đúng nhưng item mới không hiển thị trong Inventory.
- **Nguyên nhân:** (1) `InventoryController` đọc trường `Data.OwnedCosmetics` cũ thay vì `Data.OwnedIcicles` và `Data.OwnedBlocks` mới của Phase 5. (2) `ShopController` không cập nhật lại local cache của client sau khi RemoteFunction giao dịch mua rương hoàn thành.
- **Fix:** (1) Sửa `InventoryController` đọc đúng `Data.OwnedIcicles`/`OwnedBlocks` theo tab đang chọn (giữ tương thích ngược với `OwnedCosmetics`). (2) Trong `ShopController`, gọi `PlayerDataController.RefreshData()` bất đồng bộ qua `task.spawn` ngay khi giao dịch mua thành công.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### Lỗi GetBoundingBox trên Part/MeshPart đơn lẻ và giải pháp Asset Model
- **Ngày:** 23-06-2026
- **Vấn đề:** Khi render mô hình tĩnh, code gọi `Model:GetBoundingBox()` bị crash đối với các asset được lưu dưới dạng Part hoặc MeshPart đơn lẻ (như Icicle) thay vì Model. Lỗi này làm dừng luồng xử lý GUI, gây crash các logic phía sau (như không tắt được popup do chưa kịp kết nối CloseButton).
- **Nguyên nhân:** Khác biệt cấu trúc lưu trữ asset trong ReplicatedStorage giữa các vật phẩm (Block là Model, Icicle là Part).
- **Fix:** Thay vì sửa code ViewportManager phức tạp để tính toán AABB cho Part, người dùng thống nhất sửa thủ công bằng cách bọc (wrap) tất cả các asset preview dạng Part/MeshPart thành Model trong Roblox Studio để bảo toàn tính đồng nhất của hệ thống.
- **File liên quan:** [ViewportManager.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [ShopController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### Lỗi không thể spectate khi người chơi quá xa do StreamingEnabled
- **Ngày:** 26-06-2026 (cập nhật 27-06-2026)
- **Vấn đề:** Khi người chơi bật spectate mục tiêu ở quá xa lobby, camera không chuyển sang mục tiêu mà chỉ focus tại chỗ.
- **Nguyên nhân:** Dưới chế độ `StreamingEnabled`, character của người chơi ở xa bị stream out (bị hủy) hoàn toàn ở client, dẫn đến `TargetPlayer.Character` trả về `nil`. Client không có Vector3 vị trí để gọi `RequestStreamAroundAsync`.
- **Fix:** client gửi RemoteEvent `RequestSpectateTarget` yêu cầu Server set `Player.ReplicationFocus` trỏ vào `HumanoidRootPart` của target player. Client poll kiểm tra nhân vật mỗi 0.1 giây (timeout 5s) và hướng camera khi nhân vật đã được tải đầy đủ.
- **File liên quan:** [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Lỗi lơ lửng và mất di chuyển của Spectator khi tắt Spectate
- **Ngày:** 27-06-2026
- **Vấn đề:** Spectator bị lơ lửng khi đang spectate, và khi tắt (Close) spectate thì bị đóng băng tại chỗ, không thể di chuyển ở lobby.
- **Nguyên nhân:** `ReplicationFocus` dời sang target khiến vùng lobby bị stream out (mất physics mô phỏng). Khi tắt spectate, camera quay lại lobby nhưng `ReplicationFocus` không được reset, khiến lobby vẫn bị stream out.
- **Fix:** (1) Khóa di chuyển của spectator (`WalkSpeed = 0`, `JumpPower = 0`) khi đang xem để nhân vật không bị trôi do mất physics. (2) Gửi yêu cầu `RequestSpectateTarget` với tham số `nil` để server reset `ReplicationFocus` về chính spectator HRP khi tắt spectate, đồng thời khôi phục tốc độ di chuyển chuẩn.
- **File liên quan:** [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Lỗi nhấp nháy/flickering của NavigationButton khi đang spectate
- **Ngày:** 27-06-2026
- **Vấn đề:** Khi đang spectate, nút NavigationButton bị ẩn đi rồi tự động hiện lại xen kẽ sau mỗi vài giây.
- **Nguyên nhân:** `GameStateController` định kỳ cập nhật thông tin phase/thời gian từ server và gọi `SetLobbyGuisVisible(true)` để hiển thị các lobby GUI, ghi đè hành động ẩn nút của `SpectateController`.
- **Fix:** Thay đổi `SetLobbyGuisVisible` trong `GameStateController` để kiểm tra trạng thái qua `SpectateController.IsSpectating()`. Chỉ kích hoạt lại `NavGui.Enabled = true` nếu người chơi không ở trong chế độ spectate.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua), [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

### Lỗi timing khiến người chơi join muộn không tương tác được với nút Spectate
- **Ngày:** 26-06-2026
- **Vấn đề:** Khi người chơi mới kết nối vào server khi trận đấu đang diễn ra, các nút điều khiển spectate (Next/Back/Close) và nút Spectate chính không phản hồi khi bấm.
- **Nguyên nhân:** Script client truy vấn các đối tượng GUI ở phần khai báo top-level bằng `WaitForChild(..., timeout)`. Do người chơi join muộn, một số UI element chưa kịp load xong trước khi timeout kết thúc, dẫn đến biến tham chiếu bị `nil` và làm crash luồng khởi tạo của controller.
- **Fix:** Di chuyển toàn bộ các câu lệnh tìm kiếm UI element bằng `WaitForChild` từ top-level vào bên trong hàm khởi tạo `Init()`, đồng thời loại bỏ tham số timeout để đảm bảo script luôn đợi đến khi GUI load thành công.
- **File liên quan:** [SpectateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SpectateController.lua)

### Lỗi người chơi mới join giữa trận không nhận được danh sách Spectate
- **Ngày:** 26-06-2026
- **Vấn đề:** Người chơi mới kết nối vào server khi trận đấu đang diễn ra có thể mở được giao diện Spectate nhưng danh sách người chơi để quan sát trống rỗng, không thể spectate ai.
- **Nguyên nhân:** Server chỉ broadcast danh sách người chơi thi đấu (`UpdateSpectateList`) tại thời điểm bắt đầu phase `InGame` hoặc khi có thay đổi trạng thái đóng băng/rã đông. Người chơi kết nối sau thời điểm đó sẽ không nhận được dữ liệu ban đầu.
- **Fix:** Trong `MatchService:Init()`, bổ sung lắng nghe sự kiện `Players.PlayerAdded`. Khi có người chơi mới tham gia và game đang trong phase `InGame`, Server đợi 2 giây (để client load xong remote) rồi gửi riêng danh sách người chơi Normal hiện tại cho client đó qua `FireClient`.
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

