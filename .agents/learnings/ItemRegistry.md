# ItemRegistry
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống đăng ký vật phẩm, độ hiếm, quản lý mô hình Viewport, Functional Component ItemCard và cơ chế hiển thị Avatar (ItemRegistry, RarityConfig, ItemCard, ViewportManager, 2D CDN Avatar và Lazy Rendering).
> Cập nhật lần cuối: 28-08-2026

---

## Kiến trúc

### 1. Centralized ItemRegistry (Single Source of Truth cho Vật phẩm)
- **Chi tiết:** Đưa registry cấu hình vật phẩm (Icicles, Blocks) về Shared (`ReplicatedStorage/Shared/Config/ItemRegistry.lua`) dưới dạng cấu trúc bảng lookup $O(1)$. Đảm bảo cả Server và Client dùng chung một nguồn dữ liệu duy nhất, ngăn ngừa sự không đồng bộ dữ liệu.
- **Chuỗi Fallback An Toàn:** Khi truy vấn thông tin skin: `DataService` $\rightarrow$ `ItemRegistry` $\rightarrow$ `Cấu hình Default`, đi kèm cảnh báo lỗi chi tiết khi thiếu cấu hình.
- **File liên quan:** [ItemRegistry.lua](../../src/ReplicatedStorage/Shared/Config/ItemRegistry.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### 2. Đóng Gói UI Template qua Functional Component Helper (ItemCard.lua)
- **Chi tiết:** Thay vì để từng Controller (`Inventory`, `Shop`, `Profile`, `ItemReward`) tự clone `ItemTemplate` và thao tác trực tiếp với các node con (dễ gây lệch màu Rarity, quên ẩn thẻ `EquippedText`/`DropRateText`, hoặc lặp code), toàn bộ logic hiển thị thẻ vật phẩm được chuẩn hóa thành Functional Helper `ItemCard.lua` (`ReplicatedStorage/Shared/Tools/ItemCard.lua`).
- **API Đóng Gói & Cập Nhật In-Place:**
  - `ItemCard.Create(Parent, ItemId, ItemType, Options)`: Tự động gán thông số từ `ItemRegistry`, `RarityConfig`, tải 3D qua `ViewportManager`, gắn click và scale hover.
  - `ItemCard.SetEquipped(Frame, IsEquipped)`: Cập nhật in-place thẻ trang bị trong $O(1)$ mà không cần re-render toàn bộ danh sách.
  - `ItemCard.SetDropRate(Frame, DropRate)`: Cập nhật in-place nhãn tỉ lệ rơi.
  - `ItemCard.Destroy(Frame)`: Tự động dọn dẹp camera và model 3D trong `ViewportFrame` trước khi hủy instance, triệt tiêu rò rỉ bộ nhớ.
- **File liên quan:** [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### 3. Tự Động Hóa Camera ViewportFrame qua Bounding Box và ViewportConfig
- **Chi tiết:** Tự động hóa tính toán camera hiển thị mô hình 3D trong `ViewportFrame` bằng `ViewportManager.lua` dựa trên Bounding Box của mô hình. Hỗ trợ ghi đè góc nhìn (Pitch, Yaw, FOV, Padding) qua cấu hình phân tầng `ViewportConfig.lua` (`Default` $\rightarrow$ `Type` $\rightarrow$ `ItemId`) trên tất cả các tab Inventory, Shop và Profile.
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [ViewportConfig.lua](../../src/ReplicatedStorage/Shared/Config/ViewportConfig.lua)

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
- **Chi tiết:** Để tối ưu hiệu suất khi một danh sách card GUI có nhiều ViewportFrame 3D, áp dụng cơ chế lazy render: Chỉ clone model và gọi `ViewportManager.RenderItem` khi card nằm trong (hoặc gần) vùng nhìn thấy của `ScrollingFrame` cha.
- **Cơ chế:** Lưu hàng đợi `{ Frame, Data }`, lắng nghe `CanvasPosition` thay đổi để kiểm tra bounding box với buffer mở rộng trước khi render.
- **File liên quan:** [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ShopConfig.lua](../../src/ReplicatedStorage/Shared/Config/ShopConfig.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Lỗi GetBoundingBox Crash Trên Asset Dạng Part/MeshPart Đơn Lẻ
- **Vấn đề:** Khi render mô hình tĩnh, gọi `Model:GetBoundingBox()` bị crash đối với các asset được lưu dưới dạng Part hoặc MeshPart đơn lẻ (như Icicle) thay vì Model.
- **Giải pháp:** Bọc (wrap) 100% tất cả các asset preview dạng Part/MeshPart thành Model trong Roblox Studio để bảo toàn tính đồng nhất của hệ thống nạp mô hình.
- **File liên quan:** [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua)

### 2. Rò Rỉ Bộ Nhớ (Memory Leak) và Phân Mảnh Logic Render do Naked Template
- **Vấn đề:** Khi clone thủ công `ItemTemplate` ở nhiều controller, các đối tượng Model và Camera bên trong `ViewportFrame` dễ bị bỏ quên khi dọn dẹp hoặc chuyển tab. Đồng thời mỗi controller tự viết lại ~50 dòng code để tìm node con, gán màu Rarity và ẩn hiện tag thừa.
- **Giải pháp:** Ủy quyền toàn bộ việc tạo, cập nhật và dọn dẹp cho `ItemCard.lua`. Hàm `ItemCard.Destroy(Frame)` tự động gọi `ViewportManager.CleanViewport(ItemViewport)` trước khi `Frame:Destroy()`, đảm bảo an toàn bộ nhớ tuyệt đối và tập trung hóa 100% logic UI.
- **File liên quan:** [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [ViewportManager.lua](../../src/ReplicatedStorage/Shared/Tools/ViewportManager.lua), [InventoryController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/InventoryController.lua)

### 3. Ngăn Ngừa Trang Bị Skin Giả Mạo Từ Client (Server Validation)
- **Vấn đề:** Người chơi có thể can thiệp client để gửi yêu cầu trang bị các skin hiếm mà họ chưa thực sự sở hữu trong dữ liệu.
- **Giải pháp:** Server khi nhận yêu cầu RemoteEvent phải đối chiếu danh sách `OwnedIcicles`/`OwnedBlocks` trong `DataStore` (hoặc Session Data) của người chơi. Chỉ cho phép trang bị và đồng bộ lại Client nếu hợp lệ.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)
