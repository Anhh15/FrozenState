# ItemRegistry
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống đăng ký vật phẩm, độ hiếm, quản lý mô hình Viewport, Functional Component ItemCard, chuyển đổi 2D ItemImage, cơ chế hiển thị Avatar và Pipeline tự động hóa tạo Icon 2D (ItemRegistry, RarityConfig, ItemCard, ViewportManager, 2D CDN Avatar, Shop Lazy Rendering và Dual-Shot Matte Photo Booth).
> Cập nhật lần cuối: 08-09-2026

---

## Kiến trúc

### 1. Centralized ItemRegistry (Single Source of Truth cho Vật phẩm)
- **Chi tiết:** Đưa registry cấu hình vật phẩm (Icicles, Blocks) về Shared (`ReplicatedStorage/Shared/Config/ItemRegistry.lua`) dưới dạng cấu trúc bảng lookup $O(1)$. Đảm bảo cả Server và Client dùng chung một nguồn dữ liệu duy nhất, ngăn ngừa sự không đồng bộ dữ liệu.
- **Cấu trúc Entry & Asset Độc lập:** Mỗi entry gồm `Id`, `Name`, `Rarity`, `Type`, và `Icon` (Image ID riêng biệt). Cung cấp API `ItemRegistry.GetItemIcon(ItemId, ItemType)` tự động fallback về icon Default nếu item chưa có ID riêng.
- **Chuỗi Fallback An Toàn:** Khi truy vấn thông tin skin: `DataService` $\rightarrow$ `ItemRegistry` $\rightarrow$ `Cấu hình Default`, đi kèm cảnh báo lỗi chi tiết khi thiếu cấu hình.
- **File liên quan:** [ItemRegistry.lua](../../src/ReplicatedStorage/Shared/Config/ItemRegistry.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### 2. Đóng Gói UI Template qua Functional Component Helper (ItemCard.lua)
- **Chi tiết:** Thay vì để từng Controller (`Inventory`, `Shop`, `Profile`, `ItemReward`) tự clone `ItemTemplate` và thao tác trực tiếp với các node con (dễ gây lệch màu Rarity, quên ẩn thẻ `EquippedText`/`DropRateText`, hoặc lặp code), toàn bộ logic hiển thị thẻ vật phẩm được chuẩn hóa thành Functional Helper `ItemCard.lua` (`ReplicatedStorage/Shared/Tools/ItemCard.lua`).
- **API Đóng Gói & Tương Tác Tự Động:**
  - `ItemCard.Create(Parent, ItemId, ItemType, Options)`: Tự động gán thông số từ `ItemRegistry`, `RarityConfig`, nạp ảnh 2D `ItemImage` (`ImageLabel`) qua `ItemRegistry.GetItemIcon`, gắn click qua `Activated`, tự động nạp hiệu ứng Hover Scale (`GuiHelper.BindButtonScale`) và âm thanh SFX (`GuiHelper.BindButtonSound`) theo cấu hình tập trung `GuiConfig.Animations.ButtonScale.Overrides.ItemTemplate`.
  - `ItemCard.SetEquipped(Frame, IsEquipped)`: Cập nhật in-place thẻ trang bị trong $O(1)$ mà không cần re-render toàn bộ danh sách.
  - `ItemCard.SetDropRate(Frame, DropRate)`: Cập nhật in-place nhãn tỉ lệ rơi.
  - `ItemCard.Destroy(Frame)`: Hủy Frame an toàn và giải phóng tài nguyên.
- **File liên quan:** [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [AudioConfig.lua](../../src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### 3. Tự Động Hóa Camera ViewportFrame qua Bounding Box và ViewportConfig
- **Chi tiết:** Tự động hóa tính toán camera hiển thị mô hình 3D trong `ViewportFrame` bằng `ViewportManager.lua` dựa trên Bounding Box của mô hình. Hỗ trợ ghi đè góc nhìn (Pitch, Yaw, FOV, Padding) qua cấu hình phân tầng `ViewportConfig.lua` (`Default` $\rightarrow$ `Type` $\rightarrow$ `ItemId`).
- **Phân định Phạm vi 3D Viewport:** ViewportFrame 3D được giữ lại phục vụ độc quyền cho các khung hiển thị chi tiết (khung xem trước `ItemSelection` trong Inventory, `ChestViewport` trong Shop và ItemReward), loại bỏ hoàn toàn khỏi danh sách thẻ lặp lại (Card Grid).
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [ViewportConfig.lua](../../src/ReplicatedStorage/Shared/Config/ViewportConfig.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### 4. Quy Tắc Phân Vùng Lưu Trữ Template GUI & Khai Tử Dead Asset ChestTemplate
- **Chi tiết:**
  - **Template dùng chung giữa nhiều controller** (`ItemTemplate` dùng bởi Shop, Inventory, Profile, ItemReward): Đặt tại `ReplicatedStorage.Assets.Gui`.
  - **Template riêng của một GUI duy nhất** (`ChestPreview` chỉ dùng bởi ShopController): Đặt trong chính GUI đó (`Menu/Shop/Templates`).
  - **Khai tử `ChestTemplate`:** Xác nhận asset `ChestTemplate.rbxmx` trong `ReplicatedStorage/Assets/Gui` là tài nguyên thừa từ bản thiết kế cũ (roadmap 1), đã được thay thế hoàn toàn bởi component co-location `ChestPreview`.
- **Lợi ích:** Dễ chỉnh sửa trong Studio đúng ngữ cảnh, không bị Rojo sync xóa và tuân thủ nguyên tắc co-location.
- **File liên quan:** [default.project.json](../../default.project.json), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua)

### 5. Chuyển Đổi Toàn Diện Hiển Thị Avatar từ 3D Viewport sang 2D CDN (rbxthumb://)
- **Chi tiết:** Thay thế hoàn toàn mô hình 3D trên `ViewportFrame` ở các bảng giao diện bằng `ImageLabel` 2D trực tiếp từ Roblox CDN qua giao thức `rbxthumb://`:
  - **Top 1, 2, 3 (`TopPlayersStats`)**: Dùng `rbxthumb://type=Avatar&id={userId}&w=352&h=352` (Ảnh toàn thân).
  - **Thống kê cá nhân (`PlayerStats`)**: Dùng `rbxthumb://type=AvatarBust&id={userId}&w=352&h=352` (Ảnh từ eo trở lên).
  - **Hồ sơ cá nhân (`Profile`)**: Dùng `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` (Ảnh chân dung).
- **Lợi ích:** Tiết kiệm GPU/VRAM Client (không tốn các render pass 3D song song), loại bỏ `AvatarCacheService` trên Server giúp giảm tải RAM/CPU Server, hiển thị tức thì không bị méo camera hay độ trễ bất đồng bộ.
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### 6. Lazy Render ViewportFrame theo Vùng Nhìn Thấy (Shop Preview In-Place)
- **Chi tiết:** Để tối ưu hiệu suất khi một danh sách card GUI chứa các ViewportFrame 3D (như `ChestPreview.ChestViewport` trong Shop), áp dụng cơ chế lazy render: Chỉ clone model và gọi `ViewportManager.RenderItem` khi card nằm trong (hoặc gần) vùng nhìn thấy của `ScrollingFrame` cha.
- **Cơ chế:** Lưu hàng đợi `{ Frame, Data }`, lắng nghe `CanvasPosition` thay đổi để kiểm tra bounding box với buffer mở rộng trước khi render.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ShopConfig.lua](../../src/ReplicatedStorage/Shared/Config/ShopConfig.lua)

### 7. Chuyển Đổi Danh Sách Thẻ Vật Phẩm sang 2D Image & Khai Tử Lazy Render trong Inventory
- **Chi tiết:** Chuyển đổi toàn bộ hiển thị vật phẩm trong danh sách cuộn (`ItemTemplate`) và thanh Hotbar (`ItemSlot`) từ `ViewportFrame` sang `ImageLabel` (**`ItemImage`**).
- **Triệt tiêu Dead Code:** Do 2D Icon nạp tức thì trong $0\text{ms}$ và được engine gom vào 1 Draw Call duy nhất, toàn bộ hệ thống Lazy Loading (`_LazyRenderQueue`, `CheckLazyQueue`, `_ScrollConn`) trong `InventoryController` và `InventoryConfig.LazyRenderBuffer` được dỡ bỏ hoàn toàn, giảm tải độ phức tạp mã nguồn.
- **File liên quan:** [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [InventoryConfig.lua](../../src/ReplicatedStorage/Shared/Config/InventoryConfig.lua)

### 8. Pipeline Tự Động Hóa Tạo Icon 2D Từ Model 3D (Dual-Shot Difference Matte GUI Viewport)
- **Chi tiết:** Để thay thế `ViewportFrame` bằng `ImageLabel` mà vẫn bảo toàn 100% shader, vật liệu (`Ice`, `Glass`, `Neon`) và màu sắc trong Studio (tránh lỗi ám viền xanh và mất thân item màu lục khi dùng Chroma Key phông xanh), áp dụng kỹ thuật **Dual-Shot Difference Matte** với 2 lần chụp trên nền Đen (`#000000`) và Trắng (`#FFFFFF`):
  $$\text{Alpha} = 1.0 - (\text{Color}_{\text{White}} - \text{Color}_{\text{Black}})$$
  $$\text{FinalColor} = \frac{\text{Color}_{\text{Black}}}{\text{Alpha}}$$
- **Kiến trúc GUI ViewportFrame Photo Booth:** Thay vì dựng hộp 3D và đèn trong Workspace, Roblox Studio tạo `ScreenGui` tạm chứa `ViewportFrame` vuông tỉ lệ 1:1 (`800x800` pixels) căn giữa màn hình. Nạp model và camera bằng `ViewportManager.RenderItem`, thừa hưởng trực tiếp `ViewportConfig.Lighting` để đảm bảo ánh sáng tương đồng 100% với in-game Viewport. Đổi màu nền `BackgroundColor3` (Đen/Trắng) và gửi HTTP POST sang Python Local Worker.
- **Tách Biệt 2 Pha Chuyên Biệt (Decoupled Capture & Upload) & SSOT Output Path:**
  - *Pha 1 (Tạo & Kiểm duyệt):* Python Worker chụp, tách nền, crop vuông tâm và xuất file PNG 512x512 vào thư mục tập trung ngoài dự án `SuperFrozenState/GUI_FrozenState/Icon/Item/{Type}/{Id}.png` theo phân cấp để nhà phát triển kiểm tra trước.
  - *Pha 2 (Upload & Sync):* Script `upload_icons.py` tái sử dụng `config.OutputDir` làm nguồn chân lý duy nhất (SSOT), upload qua Roblox Open Cloud Assets API và tự động ghi đè mã `rbxassetid://...` vào `ItemRegistry.lua`.
- **File liên quan:** [IconPipelineConfig.lua](../../src/ReplicatedStorage/Shared/Config/IconPipelineConfig.lua), [IconGenerator.lua](../../src/ReplicatedStorage/Shared/Tools/IconGenerator.lua), [config.py](../../tools/icon_pipeline/config.py), [studio_capture.py](../../tools/icon_pipeline/studio_capture.py), [upload_icons.py](../../tools/icon_pipeline/upload_icons.py), [ItemRegistry.lua](../../src/ReplicatedStorage/Shared/Config/ItemRegistry.lua)

### 9. Single Source of Truth Cho Ánh Sáng ViewportFrame (ViewportConfig.Lighting)
- **Chi tiết:** Thay vì lưu tĩnh thông số ánh sáng trong file GUI XML (`Menu.rbxmx`), tập trung hóa toàn bộ tham số vào `ViewportConfig.Lighting` (`Ambient`, `LightColor`, `LightDirection`).
- **Tự Động Đồng Bộ:** Hàm `ViewportManager.RenderItem()` tự động áp dụng cấu hình này vào bất kỳ `ViewportFrame` nào trước khi gán Camera. Đảm bảo tính nhất quán 100% giữa khung preview trang bị (`ItemSelection`), rương quà (`Shop`, `ItemReward`) và buồng chụp Icon (`IconGenerator`).
- **File liên quan:** [ViewportConfig.lua](../../src/ReplicatedStorage/Shared/Config/ViewportConfig.lua), [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [IconGenerator.lua](../../src/ReplicatedStorage/Shared/Tools/IconGenerator.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Lỗi GetBoundingBox Crash Trên Asset Dạng Part/MeshPart Đơn Lẻ
- **Vấn đề:** Khi render mô hình tĩnh, gọi `Model:GetBoundingBox()` bị crash đối với các asset được lưu dưới dạng Part hoặc MeshPart đơn lẻ (như Icicle) thay vì Model.
- **Giải pháp:** Bọc (wrap) 100% tất cả các asset preview dạng Part/MeshPart thành Model trong Roblox Studio để bảo toàn tính đồng nhất của hệ thống nạp mô hình.
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua)

### 2. Rò Rỉ Bộ Nhớ (Memory Leak) và Phân Mảnh Logic Render do Naked Template
- **Vấn đề:** Khi clone thủ công `ItemTemplate` ở nhiều controller, các đối tượng con dễ bị bỏ quên khi dọn dẹp hoặc chuyển tab. Đồng thời mỗi controller tự viết lại ~50 dòng code để tìm node con, gán màu Rarity và ẩn hiện tag thừa.
- **Giải pháp:** Ủy quyền toàn bộ việc tạo, cập nhật và dọn dẹp cho `ItemCard.lua`. Quản lý tập trung 100% logic UI, gán `ItemImage` trực tiếp và hủy Frame an toàn qua `ItemCard.Destroy(Frame)`.
- **File liên quan:** [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### 3. Ngăn Ngừa Trang Bị Skin Giả Mạo Từ Client (Server Validation)
- **Vấn đề:** Người chơi có thể can thiệp client để gửi yêu cầu trang bị các skin hiếm mà họ chưa thực sự sở hữu trong dữ liệu.
- **Giải pháp:** Server khi nhận yêu cầu RemoteEvent phải đối chiếu danh sách `OwnedIcicles`/`OwnedBlocks` trong `DataStore` (hoặc Session Data) của người chơi. Chỉ cho phép trang bị và đồng bộ lại Client nếu hợp lệ.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

### 4. Bắt Nhầm Click Khi Vuốt Cuộn ScrollingFrame và Bất Cập Khi Bọc Button Trong Thẻ Item
- **Vấn đề:** `ItemTemplate` dùng root `Frame` khiến việc bắt click phải fallback qua `Frame.InputBegan` hoặc `MouseButton1Click`, dễ bị kích hoạt nhầm khi người chơi chạm màn hình vuốt cuộn `ScrollingFrame` trên thiết bị di động (Mobile/Tablet); đồng thời `GuiHelper.BindButtonScale` không thể nhận diện được nếu không phải `GuiButton`. Nếu bọc thêm `TextButton` con bên ngoài sẽ làm tăng số lượng instance và dễ xung đột lớp Z-Index.
- **Giải pháp:**
  1. Chuyển đổi trực tiếp Root của `ItemTemplate` thành `ImageButton` (`BackgroundTransparency = 1`, `AutoButtonColor = false`, `AnchorPoint = Vector2.new(0.5, 0.5)`).
  2. Chuẩn hóa `ItemCard.BindClick` ưu tiên sự kiện `Button.Activated` (Roblox engine tự động phân biệt giữa chạm bấm Tap/Click và vuốt cuộn Drag, đồng thời hỗ trợ mượt mà cả PC, Mobile và Gamepad).
  3. Cấu hình scale riêng cho `ItemTemplate` (`HoverScale = 1.05`, `PressScale = 0.95`) trong `GuiConfig.Animations.ButtonScale.Overrides` để thẻ bung nở từ tâm đối xứng mà không bị che đè lấn các ô lân cận trong `UIGridLayout`.
- **File liên quan:** [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### 5. Nghẽn Cổ Chai GPU do Lạm Dụng Hàng Loạt ViewportFrame trên Mobile (Viewport Grid Anti-Pattern)
- **Vấn đề:** Đặt hàng chục `ViewportFrame` 3D vào các ô thẻ trong danh sách cuộn (`ScrollingFrame`) hoặc các ô Hotbar gây ra bùng nổ draw calls và sub-render passes song song, làm sụt giảm nghiêm trọng FPS trên các thiết bị di động tầm thấp/trung bình.
- **Giải pháp:** Áp dụng mô hình **Hybrid (2D Grid + Single 3D Preview)**:
  - 100% các ô thẻ trong danh sách và Hotbar sử dụng `ImageLabel` 2D (**`ItemImage`**).
  - Duy trì duy nhất **1** `ViewportFrame` ở khung xem trước chi tiết (`ItemSelection`) để người chơi quan sát mô hình 3D khi click chọn.
- **File liên quan:** [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [HotbarController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HotbarController.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ItemRegistry.lua](../../src/ReplicatedStorage/Shared/Config/ItemRegistry.lua)

### 6. Sai Lệch Tọa Độ Cửa Sổ & Nhiễu Biên Khi Chụp Màn Hình Tách Nền trong Studio
- **Vấn đề:** Khi chụp màn hình từ Python, layout Roblox Studio của mỗi lập trình viên khác nhau (vị trí Explorer, Output), Windows High-DPI scaling (125%, 150%) làm lệch khung hình, và công thức Dual-Shot Matte bị crash chia cho 0 ($\text{Alpha} \to 0$) hoặc viền mờ hạt (noise) do ánh sáng bloom.
- **Giải pháp:**
  1. **Tự động nhận diện Viewport qua Sai phân (Auto Difference Rect Detection):** Lấy hiệu số $|Frame_{\text{White}} - Frame_{\text{Black}}| > 30$, vùng duy nhất biến đổi màu sắc mạnh chính là khung chữ nhật 3D Viewport.
  2. **Bảo vệ chia cho 0 & Lọc ngưỡng Alpha:** Vector hóa ma trận với NumPy: `np.where(Alpha > Threshold, ColorBlack / Alpha, 0.0)` và kẹp Alpha $[0.0, 1.0]$.
  3. **Windows DPI-Aware:** Kích hoạt `SetProcessDpiAwareness(2)` ngay khi khởi động Python worker để khớp tuyệt đối pixel vật lý.
- **File liên quan:** [studio_capture.py](../../tools/icon_pipeline/studio_capture.py), [IconPipelineConfig.lua](../../src/ReplicatedStorage/Shared/Config/IconPipelineConfig.lua)

### 7. Xung Đột Ghi Đè Tài Nguyên Khi Lưu Trữ Phẳng & Phân Mảnh Nguồn Dữ Liệu Pipeline
- **Vấn đề:** Khi kết xuất icon từ nhiều phân loại vật phẩm (`Icicle`, `Block`) ra thư mục chung, các item có cùng `ItemId` (như `Default`, `Green`, `Red`) sẽ ghi đè và làm mất file của nhau nếu lưu cấu trúc phẳng. Đồng thời, việc script upload tự khai báo hardcode đường dẫn cục bộ thay vì dùng chung biến cấu hình dẫn đến rủi ro lệch pha dữ liệu khi di dời thư mục lưu trữ.
- **Giải pháp:**
  1. **Bảo tồn phân cấp danh mục:** Áp dụng cấu trúc thư mục con `{OutputDir}/{ItemType}/{ItemId}.png` bảo vệ tính toàn vẹn của dữ liệu hình ảnh.
  2. **Single Source of Truth (SSOT):** Tập trung hóa biến `OutputDir` tại `config.py`; buộc toàn bộ các script vệ tinh (`studio_capture.py`, `upload_icons.py`) import trực tiếp từ config để loại bỏ hoàn toàn hardcode đường dẫn.
- **File liên quan:** [config.py](../../tools/icon_pipeline/config.py), [studio_capture.py](../../tools/icon_pipeline/studio_capture.py), [upload_icons.py](../../tools/icon_pipeline/upload_icons.py)

### 8. Lệch Ánh Sáng và Bóng Đổ Khi Tạo Icon Bằng Buồng Chụp 3D So Với ViewportFrame
- **Vấn đề:** Dựng buồng chụp 3D trong `Workspace` (vách hộp ở $Y = 100,000$ và 3 đèn SpotLight) tạo ra chênh lệch đồ họa lớn so với `ViewportFrame` in-game:
  1. `ViewportFrame` dùng shader diffuse Lambertian tối giản, không hỗ trợ shadow map, không có falloff theo khoảng cách và có `Ambient` môi trường rất cao (`Color3.fromRGB(200, 200, 200)`).
  2. Buồng chụp 3D Workspace có `Ambient = 0` (do vách chặn bóng), đèn SpotLight tạo bóng sắc và gắt, đèn BackLight tạo rim light thừa, và vách Neon gây tán xạ bloom.
- **Giải pháp:** Khai tử buồng chụp 3D, chuyển toàn bộ `IconGenerator` sang chụp trực tiếp trên `ViewportFrame` ở GUI. Do cùng chung engine shader và dùng chung `ViewportConfig.Lighting`, Icon 2D đạt độ tương đồng 100% với `ItemSelection`.
- **File liên quan:** [IconGenerator.lua](../../src/ReplicatedStorage/Shared/Tools/IconGenerator.lua), [IconPipelineConfig.lua](../../src/ReplicatedStorage/Shared/Config/IconPipelineConfig.lua), [ViewportConfig.lua](../../src/ReplicatedStorage/Shared/Config/ViewportConfig.lua), [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua)

