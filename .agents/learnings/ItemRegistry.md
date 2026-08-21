# ItemRegistry
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống đăng ký vật phẩm, độ hiếm, quản lý mô hình Viewport và cơ chế hiển thị Avatar (ItemRegistry, RarityConfig, ViewportManager, 2D CDN Avatar và Lazy Rendering).
> Cập nhật lần cuối: 21-08-2026

---

## Kiến trúc

### 1. Centralized ItemRegistry (Single Source of Truth cho Vật phẩm)
- **Chi tiết:** Đưa registry cấu hình vật phẩm (Icicles, Blocks) về Shared (`ReplicatedStorage/Shared/Config/ItemRegistry.lua`) dưới dạng cấu trúc bảng lookup $O(1)$. Đảm bảo cả Server và Client dùng chung một nguồn dữ liệu duy nhất, ngăn ngừa sự không đồng bộ dữ liệu.
- **Chuỗi Fallback An Toàn:** Khi truy vấn thông tin skin: `DataService` $\rightarrow$ `ItemRegistry` $\rightarrow$ `Cấu hình Default`, đi kèm cảnh báo lỗi chi tiết khi thiếu cấu hình.
- **File liên quan:** [ItemRegistry.lua](../../src/ReplicatedStorage/Shared/Config/ItemRegistry.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### 2. Thiết Kế UI Template Động qua RarityConfig
- **Chi tiết:** Thay vì tạo nhiều template UI cho từng loại vật phẩm, hệ thống sử dụng duy nhất một `ItemTemplate` chung kết hợp với `RarityConfig.lua` chứa thông số màu sắc, stroke và hình ảnh nền đặc thù cho từng độ hiếm (Common, Rare, Epic, Legendary). Client tự động gán thuộc tính động từ Config khi render.
- **File liên quan:** [RarityConfig.lua](../../src/ReplicatedStorage/Shared/Config/RarityConfig.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### 3. Tự Động Hóa Camera ViewportFrame qua Bounding Box và ViewportConfig
- **Chi tiết:** Tự động hóa tính toán camera hiển thị mô hình 3D trong `ViewportFrame` bằng `ViewportManager.lua` dựa trên Bounding Box của mô hình. Hỗ trợ ghi đè góc nhìn (Pitch, Yaw, FOV, Padding) qua cấu hình phân tầng `ViewportConfig.lua` (`Default` $\rightarrow$ `Type` $\rightarrow$ `ItemId`) trên tất cả các tab Inventory, Shop và Profile.
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [ViewportConfig.lua](../../src/ReplicatedStorage/Shared/Config/ViewportConfig.lua)

### 4. Quy Tắc Phân Vùng Lưu Trữ Template GUI
- **Chi tiết:**
  - **Template dùng chung giữa nhiều controller** (như `ItemTemplate` dùng bởi Shop, Inventory, Profile, ItemReward): Đặt tại `ReplicatedStorage.Assets.Gui`.
  - **Template riêng của một GUI duy nhất** (như `ChestPreview` chỉ dùng bởi ShopController): Đặt trong chính GUI đó (`Menu/Shop/Templates`).
- **Lợi ích:** Dễ chỉnh sửa trong Studio đúng ngữ cảnh, không bị Rojo sync xóa và tuân thủ nguyên tắc co-location.
- **File liên quan:** [default.project.json](../../default.project.json), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### 5. Chuyển Đổi Toàn Diện Hiển Thị Avatar từ 3D Viewport sang 2D CDN (rbxthumb://)
- **Chi tiết:** Thay thế hoàn toàn mô hình 3D trên `ViewportFrame` ở các bảng giao diện bằng `ImageLabel` 2D trực tiếp từ Roblox CDN qua giao thức `rbxthumb://`:
  - **Top 1, 2, 3 (`TopPlayersStats`)**: Dùng `rbxthumb://type=Avatar&id={userId}&w=352&h=352` (Ảnh toàn thân).
  - **Thống kê cá nhân (`PlayerStats`)**: Dùng `rbxthumb://type=AvatarBust&id={userId}&w=352&h=352` (Ảnh từ eo trở lên).
  - **Hồ sơ cá nhân (`Profile`)**: Dùng `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` (Ảnh chân dung).
- **Lợi ích:** Tiết kiệm GPU/VRAM Client (không tốn các render pass 3D song song), loại bỏ `AvatarCacheService` trên Server giúp giảm tải RAM/CPU Server, hiển thị tức thì không bị méo camera hay độ trễ bất đồng bộ.
- **File liên quan:** [GameStatisticController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### 6. Lazy Render ViewportFrame theo Vùng Nhìn Thấy (Shop Preview In-Place)
- **Chi tiết:** Để tối ưu hiệu suất khi một danh sách card GUI có nhiều ViewportFrame 3D, áp dụng cơ chế lazy render: Chỉ clone model và gọi `ViewportManager.RenderItem` khi card nằm trong (hoặc gần) vùng nhìn thấy của `ScrollingFrame` cha.
- **Cơ chế:** Lưu hàng đợi `{ Frame, Data }`, lắng nghe `CanvasPosition` thay đổi để kiểm tra bounding box với buffer mở rộng trước khi render.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ShopConfig.lua](../../src/ReplicatedStorage/Shared/Config/ShopConfig.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Lỗi GetBoundingBox Crash Trên Asset Dạng Part/MeshPart Đơn Lẻ
- **Vấn đề:** Khi render mô hình tĩnh, gọi `Model:GetBoundingBox()` bị crash đối với các asset được lưu dưới dạng Part hoặc MeshPart đơn lẻ (như Icicle) thay vì Model.
- **Giải pháp:** Bọc (wrap) 100% tất cả các asset preview dạng Part/MeshPart thành Model trong Roblox Studio để bảo toàn tính đồng nhất của hệ thống nạp mô hình.
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua)

### 2. Rò Rỉ Bộ Nhớ (Memory Leak) Khi Chuyển Đổi Danh Sách GUI
- **Vấn đề:** Khi chuyển đổi giữa các tab danh sách (như Icicles và Blocks) hoặc đóng GUI, các đối tượng Model và Camera bên trong `ViewportFrame` vẫn tồn tại trong bộ nhớ Client gây lãng phí tài nguyên.
- **Giải pháp:** Xây dựng hàm dọn dẹp (Cleanup) chủ động ngắt kết nối (`Disconnect`) các sự kiện xoay và gọi phương thức `:Destroy()` cho các Model, Camera trước khi khởi tạo danh sách mới.
- **File liên quan:** [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua)

### 3. Ngăn Ngừa Trang Bị Skin Giả Mạo Từ Client (Server Validation)
- **Vấn đề:** Người chơi có thể can thiệp client để gửi yêu cầu trang bị các skin hiếm mà họ chưa thực sự sở hữu trong dữ liệu.
- **Giải pháp:** Server khi nhận yêu cầu RemoteEvent phải đối chiếu danh sách `OwnedIcicles`/`OwnedBlocks` trong `DataStore` (hoặc Session Data) của người chơi. Chỉ cho phép trang bị và đồng bộ lại Client nếu hợp lệ.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)
