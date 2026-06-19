# GUIController
> Tổng hợp kiến thức về quản lý GUI phía client theo trạng thái game trong dự án.
> Cập nhật lần cuối: 17-06-2026

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
- **Chi tiết:** Thay vì tạo nhiều file UI template cho từng Rarity, sử dụng duy nhất một template `ItemFrame` chung kết hợp với một `RarityConfig` chứa thông tin màu sắc, ID ảnh nền. Client khi render sẽ tự động gán thuộc tính động từ Config này. Thiết kế này giúp dễ dàng bảo trì cấu trúc UI ở một nơi duy nhất và tránh hardcode các thông số hiển thị trực tiếp trong logic code.
- **File liên quan:** [RarityConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/RarityConfig.lua)

### Quản lý Tài nguyên Đồ họa trong Dự án Sử dụng Rojo
- **Ngày:** 15-06-2026
- **Chi tiết:** Để tránh việc Rojo xóa mất folder chứa tài nguyên đồ họa (UI Templates, Mesh Previews...) trong `ReplicatedStorage` khi đồng bộ, thay vì ánh xạ toàn bộ `ReplicatedStorage`, hãy cấu hình `default.project.json` chỉ đồng bộ các thư mục con chứa Script (như `Controllers`, `Shared`...). Folder `ReplicatedStorage/Assets` sẽ được quản lý trực tiếp trong Roblox Studio và được bảo toàn nguyên vẹn cấu trúc Mesh/UI.
- **File liên quan:** [default.project.json](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/default.project.json)

### Tối ưu hóa ViewportFrame hiển thị Vật phẩm Tĩnh
- **Ngày:** 15-06-2026
- **Chi tiết:** Render vật phẩm tĩnh trong `ViewportFrame` bằng cách tạo sẵn các đối tượng `Camera` tĩnh trong Studio, không cần dùng code tạo camera động nhằm tiết kiệm tài nguyên. Để các vật phẩm hiển thị cân đối với camera tĩnh, toàn bộ mô hình Mesh Preview trong `ReplicatedStorage` phải được scale về cùng một kích thước chuẩn từ trước. Chỉ dùng code xoay động cho vật phẩm đang được chọn ở khung chi tiết để tối ưu hiệu năng CPU trên di động.
- **File liên quan:** [Menu.rbxmx](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/assets/GUI/Menu.rbxmx)

### Tránh Circular Dependency giữa các Controller bằng Lazy-require
- **Ngày:** 16-06-2026
- **Chi tiết:** Khi `GameStateController` cần ẩn/hiện `InventoryController` theo trạng thái trận đấu, việc require trực tiếp ở top-level của hai controller sẽ gây lỗi circular dependency do cả hai đều được load lúc khởi động. Giải pháp là áp dụng lazy-require: định nghĩa hàm helper require `InventoryController` và cache lại trong lần đầu tiên được gọi, giúp phá vỡ vòng lặp dependency lúc khởi tạo.
- **File liên quan:** [GameStateController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStateController.lua)

### Inventory Controller - Data Flow Pattern (Local Cache + Client State Update)
- **Ngày:** 16-06-2026
- **Chi tiết:** Để tối ưu hóa trải nghiệm người dùng, client lấy dữ liệu trang bị từ cache local (`PlayerDataController.GetData()`) thay vì liên tục gọi server. Khi người chơi nhấn trang bị (equip), Client gửi yêu cầu lên Server qua RemoteEvent. Sau khi nhận xác nhận thành công từ Server, Client cập nhật trực tiếp cache local (`Data[SlotName] = ItemId`) và làm mới giao diện ngay lập tức mà không cần round-trip tải lại toàn bộ dữ liệu.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [PlayerDataController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua)

### Logic hiển thị nút trang bị (EquipButton State Logic)
- **Ngày:** 16-06-2026
- **Chi tiết:** Trạng thái hiển thị của nút trang bị (EquipButton) được cập nhật động mỗi khi người chơi chọn một vật phẩm mới. Logic đối chiếu ID vật phẩm đang chọn (`_selectedEntry.Id`) với ID vật phẩm hiện đang trang bị trong cache local của slot tương ứng. Nếu trùng khớp, nút đổi nhãn thành "Equipped" và khóa tương tác (`Active = false`). Nếu khác biệt, nút hiển thị "Equip" và cho phép click (`Active = true`).
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Tách biệt UI Template cho mục đích tái sử dụng (Shared Assets)
- **Ngày:** 17-06-2026
- **Chi tiết:** Thay vì lưu trữ `ItemTemplate` trực tiếp bên trong đối tượng ScrollingFrame của Inventory GUI, template này được đưa ra thư mục dùng chung `ReplicatedStorage.Assets.Gui.ItemTemplate` (hỗ trợ cả `Gui` và `GUI`). Thiết kế này cho phép các hệ thống giao diện tương lai (như Shop, Gifts) dễ dàng nhân bản một template chuẩn duy nhất, giúp đồng bộ mỹ thuật UI và giảm thiểu trùng lặp asset.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Highlight Tab an toàn không phụ thuộc thuộc tính Font/Text (ImageButton-safe)
- **Ngày:** 17-06-2026
- **Chi tiết:** Khi sử dụng `ImageButton` thay vì `TextButton` để làm nút chuyển đổi tab, việc ghi đè trực tiếp các thuộc tính của Text (như `.FontFace` hay `.TextTransparency`) sẽ gây lỗi script do các thuộc tính này không tồn tại trên `ImageButton`. Giải pháp thay thế là thay đổi màu nền `.BackgroundColor3` trực tiếp trên nút (đặt màu trắng `#FFFFFF` khi active và xám `#2F2F2F` khi inactive), vừa đạt hiệu ứng chuyển đổi thị giác vừa đảm bảo an toàn tuyệt đối trước các lỗi crash thuộc tính.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Cơ chế click linh hoạt cho UI Template (Robust Click Event Binding)
- **Ngày:** 17-06-2026
- **Chi tiết:** Để tránh lỗi script dừng đột ngột khi liên kết sự kiện click chuột lên UI template không xác định (do thiết kế template có thể thay đổi từ `ImageButton`, `TextButton` sang `Frame` thông thường), script thực hiện kiểm tra động: (1) Nếu là `GuiButton` thì kết nối `MouseButton1Click` trực tiếp; (2) Nếu là `Frame` thì quét tìm `GuiButton` con; (3) Nếu không có nút con nào, lắng nghe sự kiện `InputBegan` để bắt hành động Click chuột/Chạm cảm ứng.
- **File liên quan:** [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### Tải và Đồng bộ hóa Dữ liệu Client theo yêu cầu (Lazy-load Data Sync)
- **Ngày:** 17-06-2026
- **Chi tiết:** Thay vì đẩy dữ liệu stats của người chơi liên tục từ Server về Client khi có thay đổi, hoặc chỉ tải một lần duy nhất lúc người chơi mới kết nối (gây lỗi hiển thị stats cũ sau trận), áp dụng cơ chế Lazy-loading. Cung cấp hàm `PlayerDataController.RefreshData()` dùng để gọi RemoteFunction kéo dữ liệu mới nhất từ Server. Khi mở các GUI Menu liên quan (như Profile, Inventory), Client trước hết hiển thị dữ liệu cũ có sẵn trong cache, sau đó chạy một tiến trình bất đồng bộ (`task.spawn`) làm mới dữ liệu và cập nhật lại giao diện, đảm bảo thông tin luôn chính xác mà không block luồng giao diện chính.
- **File liên quan:** [PlayerDataController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [ProfileController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

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
- **Fix:** Server truyền trực tiếp `UserId = P.UserId` vào danh sách `TopPlayers` when serialize xuống Client. Client dùng thẳng `data.UserId` để render.
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
- **Fix:** Bổ sung hàm `RefreshData()` trong `PlayerDataController` để gọi server lấy data mới, đồng thời gọi bất đồng bộ hàm này mỗi khi mở Profile (`ProfileController.lua`) và Inventory (`InventoryController.lua`) để cập nhật lại UI bằng dữ liệu mới nhất.
- **File liên quan:** [PlayerDataController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerDataController.lua), [ProfileController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [InventoryController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)
