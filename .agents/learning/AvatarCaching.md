# AvatarCaching
> Tổng hợp kiến thức về tối ưu hiển thị avatar người chơi trong dự án.
> Cập nhật lần cuối: 28-07-2026

---

## Kiến trúc

### 1. Chuyển đổi từ 3D Viewport sang 2D Thumbnail CDN (`rbxthumb://`)
- **Ngày:** 28-07-2026
- **Chi tiết:** Đã thay thế toàn bộ mô hình 3D trên `ViewportFrame` ở các bảng giao diện bằng `ImageLabel` 2D trực tiếp từ Roblox CDN qua giao thức `rbxthumb://`.
  - **Top 1, 2, 3 (`TeamWonStats`)**: Dùng `rbxthumb://type=Avatar&id={userId}&w=352&h=352` (Ảnh toàn thân).
  - **Thống kê cá nhân (`PlayerStats`)**: Dùng `rbxthumb://type=AvatarBust&id={userId}&w=352&h=352` (Ảnh từ eo trở lên).
  - **Hồ sơ cá nhân (`Profile`)**: Dùng `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150` (Ảnh chân dung).
- **Lợi ích:** Tiết kiệm GPU/VRAM Client (không tốn 4 render pass 3D song song), loại bỏ `AvatarCacheService` trên Server giúp giảm tải RAM/CPU Server, hiển thị tức thì không bị méo camera hay độ trễ bất đồng bộ.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [ProfileController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua), [ServiceLoader.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/ServiceLoader.lua)

---

## Bug & biện pháp

### 1. Phụ kiện 3D to làm lệch camera ViewportFrame và nặng Client/Server
- **Ngày:** 28-07-2026
- **Vấn đề:** Khi render 3D Model trong ViewportFrame, các phụ kiện kích thước lớn (nón, cánh...) dễ làm lệch góc camera hoặc che khuất khuôn mặt, đồng thời việc clone nhiều 3D Model ở GameOver phase gây tốn tài nguyên Client và RAM Server.
- **Nguyên nhân:** ViewportFrame 3D phụ thuộc vào việc tính BoundingBox/CFrame thủ công và tạo thêm render pass 3D song song trên Client, kết hợp với dịch vụ clone model ở Server (`AvatarCacheService`).
- **Fix:** Thay thế ViewportFrame 3D bằng ImageLabel 2D sử dụng đường dẫn `rbxthumb://` từ Roblox CDN. CDN của Roblox tự động chụp ảnh với ánh sáng Studio chuẩn xác và render sẵn.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [ProfileController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)
