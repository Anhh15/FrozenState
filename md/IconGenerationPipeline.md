# Pipeline Tự Động Hóa Tạo Icon 2D Từ Model 3D (Roblox Studio Photo Booth & Local Capture)

## 1. Bối cảnh và Mục tiêu

- **Vấn đề hiệu năng:** Các thành phần giao diện hiển thị vật phẩm (ItemTemplate trong Inventory, Shop, Quest, Gacha) trước đây dùng `ViewportFrame`. Khi số lượng item trên màn hình vượt quá 20+ item, `ViewportFrame` gây sụt giảm FPS nghiêm trọng do mỗi Viewport là một pass vẽ riêng biệt.
- **Giải pháp chuyển đổi:** Chuyển toàn bộ hiển thị vật phẩm sang hình ảnh 2D (`ImageLabel`).
- **Nút thắt kỹ thuật:** Model vật phẩm (Icicle, Block, Chest) sau khi import từ Blender đã được tinh chỉnh trực tiếp bên trong Roblox Studio (vật liệu `Material.Ice`, `Material.Neon`, `Material.Glass`, gán màu `Color3`, lắp ghép thêm các Part phụ). 
  - Nếu xuất ngược lại Blender: Mất hoàn toàn các shader/vật liệu đặc thù của Roblox.
  - Nếu dùng `rbxthumb://`: Góc chụp camera cố định, không tùy chỉnh được góc nhìn cho từng loại item.
- **Mục tiêu của pipeline:** Tự động hóa 100% quá trình tạo ảnh 2D từ chính các Model trong Roblox Studio, bảo toàn trọn vẹn màu sắc, độ bóng và hiệu ứng ánh sáng của game mà không cần làm thủ công bất kỳ bước nào.

---

## 2. Kiến trúc Hệ thống

Hệ thống hoạt động theo mô hình Client-Server cục bộ (Localhost) giữa **Roblox Studio** và một **Python Background Worker**:

```
[Roblox Studio (Command Bar / Run Mode)]
   │
   ├─ 1. Dựng buồng chụp ảnh tại Y = 100,000 (cách ly hoàn toàn map)
   ├─ 2. Đặt Camera theo góc chuẩn từ ViewportConfig.lua
   ├─ 3. Lặp qua danh mục Item (ItemRegistry, Assets)
   ├─ 4. Đổi nền Đen (#000000) ──> Gửi HTTP POST: Step = "Black"
   ├─ 5. Đổi nền Trắng (#FFFFFF) ──> Gửi HTTP POST: Step = "White"
   │
   ▼ (Giao tiếp qua HTTP localhost:5000)
[Python Local Server (studio_capture.py)]
   │
   ├─ 1. Bắt tọa độ cửa sổ 3D Viewport của Roblox Studio
   ├─ 2. Chụp khung hình nền Đen (Ảnh 1)
   ├─ 3. Chụp khung hình nền Trắng (Ảnh 2)
   ├─ 4. Thuật toán Dual-Shot Difference Matte tách nền Alpha
   ├─ 5. Crop vuông 512x512, xuất file PNG nền trong suốt
   └─ 6. Phản hồi "OK" để Studio chuyển sang Item kế tiếp
```

---

## 3. Thuật toán Tách Nền: Dual-Shot Difference Matte

### Vấn đề của Phông Xanh Lá (Chroma Key truyền thống)
Trong danh mục vật phẩm hiện tại có `Green Icicle` và `Green Block`. Nếu dùng phông xanh lá (`#00FF00`):
1. Thuật toán lọc màu xanh sẽ xóa nhầm chính thân của các item màu xanh.
2. Các chất liệu khúc xạ/phản xạ như `Ice` và `Glass` bị ám viền xanh (Green Spill / Fringe) không thể xử lý sạch sẽ.

### Giải pháp: Kỹ thuật Dual-Shot (Đen & Trắng)
Bằng cách chụp vật thể trên 2 nền màu đơn sắc tương phản tuyệt đối (Đen `#000000` và Trắng `#FFFFFF`):

$$\text{Alpha} = 1.0 - (\text{Color}_{\text{White}} - \text{Color}_{\text{Black}})$$

$$\text{FinalColor} = \frac{\text{Color}_{\text{Black}}}{\text{Alpha}}$$

- **Ưu điểm vượt trội:**
  - Không phân biệt màu của vật thể: Item màu xanh lá, màu trắng, trong suốt hay phát sáng Neon đều được giữ nguyên 100%.
  - Tách nền sạch hoàn toàn đến từng pixel, viền mượt mà (Anti-Aliased), không bị răng cưa.

---

## 4. Đặc tả Kỹ thuật Triển khai

### 4.1. Phía Roblox Studio (`GenerateIcons.luau`)

Script chạy một lần trong **Command Bar** hoặc khi khởi chạy Studio Test:
1. **Thiết lập Buồng Chụp (Photo Studio Box):**
   - Đặt tại tọa độ biệt lập: `Vector3.new(0, 100000, 0)`.
   - Khối hộp kích thước `40x40x40 studs`, tắt đổ bóng (`CastShadow = false`), vật liệu `SmoothPlastic`.
   - Bố trí ánh sáng trung tính: Gắn các `SurfaceLight` hoặc `PointLight` với ánh sáng trắng nhẹ để vật phẩm nổi khối rõ ràng.
2. **Thiết lập Camera Tự động:**
   - Tái sử dụng chính xác thuật toán từ `ViewportManager.lua` và thông số từ `ViewportConfig.lua`:
     - Lấy Bounding Box: `ModelCFrame, ModelSize = Model:GetBoundingBox()`.
     - Tính khoảng cách: `Distance = (ModelSize.Magnitude / 2) / math.sin(math.rad(FOV / 2)) * PaddingFactor`.
     - Tính góc xoay: Áp dụng `PitchAngle` và `YawAngle` tương ứng với loại item (`Icicle`, `Block`, `Chest`).
     - Gán trực tiếp vào `workspace.CurrentCamera`.
3. **Đồng bộ với Python qua `HttpService`:**
   - Bật `HttpService.HttpEnabled = true` trong Game Settings.
   - Gửi request đồng bộ:
     ```lua
     HttpService:PostAsync("http://127.0.0.1:5000/capture", HttpService:JSONEncode({
         ItemId   = Entry.Id,
         ItemType = Entry.Type,
         Step     = "Black", -- hoặc "White"
     }))
     ```

---

### 4.2. Phía Python Local Worker (`studio_capture.py`)

Chạy ngầm trên máy tính phát triển:
1. **Thư viện yêu cầu:**
   - `Flask`: Tạo endpoint HTTP nhận lệnh từ Studio.
   - `pygetwindow` hoặc `win32gui`: Xác định tọa độ cửa sổ "Roblox Studio" trên màn hình.
   - `mss` hoặc `Pillow (ImageGrab)`: Chụp ảnh màn hình tốc độ cao (< 20ms).
   - `numpy`: Thực hiện phép toán ma trận tách kênh Alpha trong tích tắc.
2. **Xử lý ảnh:**
   - Nhận tín hiệu `Step = "Black"`: Chụp vùng Viewport, lưu tạm ma trận màu Đen.
   - Nhận tín hiệu `Step = "White"`: Chụp vùng Viewport, lưu tạm ma trận màu Trắng.
   - Thực hiện tính toán ma trận để trích xuất `Alpha` và khôi phục kênh `RGB`.
   - Cắt vuông (Center Square Crop) và Resize chuẩn về kích thước **512x512** (hoặc 256x256).
   - Lưu file vào thư mục: `SuperFrozenState/GUI_FrozenState/Icon/Item/{ItemType}/{ItemId}.png`.

---

## 5. Mở Rộng: Tự Động Hóa Upload Lên Roblox (End-to-End Pipeline)

Sau khi toàn bộ ảnh PNG trong suốt được lưu trong thư mục `GUI_FrozenState/Icon/Item/`, khâu upload cũng có thể tự động hóa 100% thay vì kéo thả thủ công:

1. **Roblox Open Cloud Assets API:**
   - Sử dụng API Key tạo từ `create.roblox.com/dashboard/credentials` với quyền `Assets: Write`.
   - Script Python quét thư mục `GUI_FrozenState/Icon/Item/`, gửi request POST upload từng file ảnh lên kho Asset của game.
2. **Tự động Cập nhật Code:**
   - Khi Roblox phản hồi trả về mã `assetId` (ví dụ: `123456789`), script Python tự động đọc và cập nhật trực tiếp vào file cấu hình `src/ReplicatedStorage/Shared/Config/ItemRegistry.lua`:
     ```lua
     {
         Id     = "Green",
         Name   = "Green Icicle",
         Rarity = "Basic",
         Type   = "Icicle",
         Icon   = "rbxassetid://123456789",
     }
     ```

---

## 6. Quy Trình Vận Hành (Workflow Khi Thêm Item Mới)

Khi đội ngũ thiết kế thêm 10 item mới:
1. Tạo model, gắn màu sắc, vật liệu trực tiếp trong Roblox Studio (`ReplicatedStorage/Assets/ItemPreview/Icicles`, `ReplicatedStorage/Assets/ItemPreview/Blocks`,...).
2. Bật terminal và chạy:
   ```bash
   python tools/studio_capture.py
   ```
3. Trong Roblox Studio: Mở Command Bar và chạy lệnh thực thi script chụp.
4. Ngồi chờ 15–30 giây: Toàn bộ ảnh được chụp, tách nền, xuất file PNG chuẩn 512x512.
5. Chạy lệnh:
   ```bash
   python tools/upload_icons.py
   ```
   Toàn bộ mã `Icon` trong `ItemRegistry.lua` được cập nhật đồng bộ 100%. Không có bất kỳ thao tác thủ công nào.
