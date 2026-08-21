# GuiArchitecture
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về nền tảng GUI (UIScale Animation Engine, Phân tầng Cấu hình Default/Overrides, Stagger Pop, Dynamic GUI Resolver và Quản lý Vòng đời ScreenGui).
> Cập nhật lần cuối: 21-08-2026

---

## Kiến trúc

### 1. Kiến trúc Animation GUI Tập Trung Dựa Trên UIScale (GuiHelper Engine)
- **Chi tiết:** Thay vì can thiệp trực tiếp vào thuộc tính `Size` (dễ làm vỡ layout, kẹt kích thước khi spam click hoặc méo giao diện so với thiết kế gốc trong Roblox Studio), toàn bộ hoạt ảnh giao diện được xây dựng trên `UIScale` và điều phối qua `GuiHelper.lua`.
- **Lợi ích:** `UIScale` bảo toàn nguyên vẹn `UDim2.Size` của các Frame thiết kế trong Studio và tự động scale đồng bộ toàn bộ các phần tử con bên trong.
- **Bộ API cốt lõi trong GuiHelper:**
  - `PopOpen(Frame, CustomConfig, OnComplete)`: Mở bung UI từ `Scale = 0` lên `1` với hiệu ứng nảy nhẹ (`EasingStyle.Back`).
  - `PopClose(Frame, CustomConfig, OnComplete)`: Thu nhỏ UI từ `Scale = 1` về `0` và tự động ẩn `Visible = false`.
  - `TweenScale(GuiObject, TargetScale, TweenInfo)`: Tween giá trị scale mượt mà, tự động hủy tween đang chạy trước đó.
  - `BindButtonScale(Button, CustomConfig)`: Gắn hiệu ứng hover (`MouseEnter` phóng to) và click (`MouseButton1Down` thu nhỏ) cho nút bấm.
  - `BindAllNavButtonsAnimation(Container)`: Tự động gom toàn bộ sự kiện từ các nút con cháu về scale item gốc trong container.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 2. Kiến trúc 2 Tầng Cấu Hình (Default & Overrides) Cho Toàn Bộ UI
- **Chi tiết:** Chuẩn hóa 100% cấu hình hoạt ảnh trong game sang mô hình 2 tầng trong `GuiConfig.Animations`:
  - `Default`: Chứa các tham số mặc định (Thời lượng `OpenDuration`, `CloseDuration`, Kiểu easing `EasingStyle`, Tỷ lệ scale `HoverScale`, `PressScale`).
  - `Overrides`: Chứa các cấu hình ghi đè đặc thù cho từng menu/nút cụ thể (`Shop`, `Inventory`, `Profile`, `Quest`, `GameStatistic`, `Accolades`).
- **Resolver tự động:** `GuiHelper` cung cấp các hàm giải quyết cấu hình (`GetPopAnimConfig`, `GetButtonAnimConfig`, `GetStaggerAnimConfig`, `GetItemRewardAnimConfig`...) tự động hòa trộn `Overrides` với `Default`, triệt tiêu hoàn toàn magic numbers và hardcode trong các Controller.
- **File liên quan:** [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 3. Hoạt họa Xuất hiện Nối tiếp Phân tầng (Staggered Pop Animation)
- **Chi tiết:** Khi hiển thị danh sách các thẻ item/nhiệm vụ trong `ScrollingFrame`, áp dụng `GuiHelper.StaggerPopOpen` để kích hoạt hiệu ứng bung nở nối tiếp với độ trễ `DelayStep` (`0.03s`) thay vì hiện thô cứng toàn bộ cùng lúc.
- **Cơ chế Dò Ngược Tổ Tiên (Ancestor Resolution):** Nếu người gọi không truyền `Identifier`, hàm tự động duyệt ngược cây phân cấp (`Parent`, `Parent.Parent`...) để tìm Frame gốc thuộc `GuiConfig.MenuFrames` hoặc có trong `Overrides`, tránh nhận nhầm tên generic `"ScrollingFrame"`.
- **Hỗ trợ Overload linh hoạt:** Cho phép gọi `StaggerPopOpen(ItemsList, "Inventory")`, `StaggerPopOpen(ItemsList, CustomConfig)`, hoặc `StaggerPopOpen(ItemsList, OnComplete)`.
- **Tích hợp âm thanh per-item:** Tự động phát SFX âm thanh (như tiếng đếm chỉ số trong `GameStatistic`) đồng bộ với từng bước bung nở của phần tử mà không cần controller tự viết vòng lặp.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 4. Tách biệt Hoạt họa Stagger khỏi Chu kỳ Auto-Refresh Ngầm
- **Chi tiết:** Với các menu có cơ chế tự động cập nhật dữ liệu thời gian thực (như đếm ngược nhiệm vụ 1s/lần trong `QuestController`), sử dụng cờ `TriggerStagger` để kiểm soát:
  - Chỉ kích hoạt hiệu ứng Stagger Pop khi người chơi mở menu hoặc chủ động chuyển tab (`TriggerStagger = true`).
  - Chu kỳ làm mới ngầm định kỳ gọi với `TriggerStagger = false` để thực hiện cập nhật in-place các thuộc tính text, progress bar và nút bấm, giữ nguyên vị trí cuộn `CanvasPosition` mà không bị gián đoạn hay chớp nháy UI.
- **File liên quan:** [QuestController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/QuestController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 5. Single Source of Truth cho Đường dẫn Cấu trúc UI (Decoupled GUI Paths)
- **Chi tiết:** Toàn bộ tên ScreenGui, Frame, Container, Button và Stats keys được tập trung trong `GuiConfig.lua`.
- **Truy xuất an toàn qua GuiHelper:** `GuiHelper` cung cấp các tiện ích `GetScreenGui`, `GetNavButton` (tìm kiếm đệ quy an toàn), `GetMoneyLabel`, `HideOtherMenuFrames`, và `BindAllNavButtonsSound` (dùng `GetDescendants()` để tự động gắn âm thanh hover/click cho mọi nút bấm con/cháu). Các controller hoàn toàn độc lập với cấu trúc cây phân cấp thực tế trong Roblox Studio.
- **File liên quan:** [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 6. Mẫu Truy Xuất Động GUI (Dynamic GUI Resolver Pattern)
- **Chi tiết:** Trong kiến trúc Single-Controller Client, các controller sử dụng hàm resolver động (`ResolveScreenElements` / `ResolveElements`) để luôn truy xuất trực tiếp instance GuiObject đang active trong `PlayerGui` thay vì cache biến tĩnh lúc `Init()`.
- **Tự động hóa:** Hàm resolver tự động ép `ResetOnSpawn = false` và `Enabled = true` ngay khi truy xuất, kết hợp fallback thông minh (`Background = Frame:FindFirstChild("Background") or Frame`), loại bỏ hoàn toàn nguy cơ rò rỉ bộ nhớ hoặc tương tác trên GUI chết.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 7. Chuẩn hóa Phân cấp Animation trên Phần tử con Background trong ScreenGui Đặc biệt
- **Chi tiết:** Thay vì tween trực tiếp trên Frame cha (`RoundLoadingScreen`, `ItemReward`) làm phá vỡ cấu trúc container toàn màn hình, chuyển 100% các animation nền (fade in/out, flash trắng chuyển pha) sang phần tử con `Background` (`Frame`/`ImageLabel`). Frame cha giữ `BackgroundTransparency = 1` và thuần túy quản lý `Visible` và vòng đời hiển thị.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. GUI bị biến thành "GUI Chết" khi Character Respawn do ResetOnSpawn = true
- **Vấn đề:** Khi nhân vật chết và hồi sinh, giao diện bị reset mất trạng thái và các nút bấm không còn phản hồi click.
- **Nguyên nhân:** Thuộc tính mặc định `ScreenGui.ResetOnSpawn = true` khiến Roblox tự động hủy và tạo mới ScreenGui khi respawn. Toàn bộ các kết nối sự kiện `.Connect` mà controller đã bind ở `Init()` bị đứt gãy.
- **Giải pháp:** Mọi ScreenGui hệ thống (`Menu`, `NavigationButtons`, `GameState`, `Special`, `GameStatistic`, `ObserverGui`) **bắt buộc phải đặt `ResetOnSpawn = false`**. Quản lý dọn dẹp hoặc khôi phục UI chủ động qua sự kiện `LocalPlayer.CharacterAdded`.
- **File liên quan:** Toàn bộ GUI Controllers

### 2. Xung đột kích thước và Race Condition khi Spam Click UI Animation
- **Vấn đề:** Khi người chơi đóng/mở menu hoặc di chuột qua các nút với tốc độ cao, các tween song song đè lên nhau làm Frame bị méo kích thước, kẹt scale ở số trung gian (vd `0.3`) hoặc không thể mở lại.
- **Giải pháp:**
  1. Duy trì bảng `_activeTweens[Instance]` trong `GuiHelper` để tự động gọi `Cancel()` tween cũ trước khi tạo tween mới.
  2. Sử dụng `UIScale` thay cho `Size` để bảo toàn kích thước Studio.
  3. Khi `PopClose` hoàn tất (`PlaybackState.Completed`), luôn reset `UIScale.Scale = 1` sau khi gán `Visible = false` để tránh lỗi kẹt scale nếu UI được mở trực tiếp sau đó.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 3. Nút bấm bị cắt đỉnh (ClipsDescendants) và xung đột vị trí trong UIListLayout
- **Vấn đề:** Khi hover phóng to nút vươn lên trên (Dock style) trong container có `UIListLayout`, nút không thể chỉnh thủ công `Position.Y` hoặc đỉnh nút bị cắt cụt.
- **Nguyên nhân:** `UIListLayout` khóa thuộc tính `Position` của các con và `ClipsDescendants = true` trên Frame cha tự động cắt bỏ phần hình ảnh vượt ra ngoài khung chứa.
- **Giải pháp:**
  1. Đặt `AnchorPoint = Vector2.new(0.5, 1)` cho các nút con và đổi `UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom` để layout tự động căn đáy và bung lên trên khi scale.
  2. Tắt `ClipsDescendants = false` trên container `Buttons` và ScreenGui cha.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [NavigationController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/NavigationController.lua)
