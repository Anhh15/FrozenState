# ItemSystem
> Tổng hợp kiến thức về Item System (ItemRegistry, Icicle/Block skins) trong dự án.
> Cập nhật lần cuối: 01-07-2026
---
## Kiến trúc
### Centralized ItemRegistry
- **Ngày:** 12-06-2026
- **Chi tiết:** Đưa registry cấu hình vật phẩm (Icicles, Blocks) về Shared (ReplicatedStorage) dưới dạng cấu trúc bảng lookup O(1). Việc này đảm bảo cả Server và Client dùng chung một nguồn dữ liệu duy nhất, ngăn ngừa sự không đồng bộ dữ liệu. Thiết lập chuỗi fallback an toàn (DataService -> ItemRegistry -> Cấu hình Default) cùng cảnh báo lỗi chi tiết khi thiếu cấu hình.
- **File liên quan:** [ItemRegistry.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/ItemRegistry.lua), [GameConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/GameConfig.lua)

### Model-based Ice Block & Dynamic Welding
- **Ngày:** 12-06-2026
- **Chi tiết:** Thay thế block đóng băng dạng Part đơn lẻ bằng Model chứa nhiều BasePart phức tạp cho phép thiết kế mỹ thuật tự do. Khi kích hoạt đóng băng, clone Model từ ServerStorage, định vị thông qua PivotTo vào HumanoidRootPart của nạn nhân, sau đó weld tất cả các BasePart con vào HumanoidRootPart đó để đảm bảo khối băng di chuyển đồng bộ hoàn toàn với người chơi.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FreezeService.lua)
---
## Bug & biện pháp
### Xử lý dọn dẹp Block dạng Model
- **Ngày:** 12-06-2026
- **Vấn đề:** Sau khi chuyển đổi từ Part sang Model, cơ chế giải băng cũ tìm kiếm Part bằng tên cố định "IceBlock" bị hỏng vì các Model skin được đặt tên động theo ID của skin đó.
- **Nguyên nhân:** Model được clone giữ nguyên tên SkinId thiết lập trong cấu hình để dễ quản lý, dẫn đến không có tên cố định.
- **Fix:** Thay đổi logic giải băng để duyệt tìm đối tượng con kế thừa lớp `Model` trong nhân vật và gọi `Destroy()`.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FreezeService.lua)

### Lặp vô hạn Animation Swing trên Icicle
- **Ngày:** 01-07-2026
- **Vấn đề:** Animation swing của Icicle khi được kích hoạt thì lặp lại liên tục không dừng và vẫn tiếp tục chạy ngay cả khi đã cất (unequip) tool.
- **Nguyên nhân:** Animation trong Roblox Studio được xuất bản với thuộc tính `Looped = true`. Khi phát bằng `LoadAnimation()`, track không dừng tự nhiên dẫn đến sự kiện `Track.Stopped` không bao giờ được kích hoạt để dọn dẹp. Đồng thời, thiếu xử lý sự kiện `Tool.Unequipped` và việc dọn dẹp không gọi `Track:Stop()` trước `Destroy()`.
- **Fix:** Override `Track.Looped = false` trên Client ngay sau khi load animation, lưu reference track hiện tại để gọi `Track:Stop()` và dọn dẹp khi `Tool.Unequipped`, đồng thời thêm `task.delay` phòng thủ dọn dẹp sau 5 giây nếu `Stopped` không kích hoạt.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

