# GuiArchitecture
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về nền tảng GUI (UIScale Animation Engine, Phân tầng Cấu hình Default/Overrides, Stagger Pop, Dynamic GUI Resolver, Phân tách GuiConfig/GuiAnimConfig và Quản lý Vòng đời ScreenGui).
> Cập nhật lần cuối: 30-08-2026

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

### 2. Kiến trúc 2 Tầng Cấu Hình (Default & Overrides) Cho Toàn Bộ UI Animation
- **Chi tiết:** Chuẩn hóa 100% cấu hình hoạt ảnh trong game sang mô hình 2 tầng trong `GuiAnimConfig.Animations`:
  - `Default`: Chứa các tham số mặc định (`OpenDuration`, `CloseDuration`, `EasingStyle`, `HoverScale`, `PressScale`...).
  - `Overrides`: Chứa các cấu hình ghi đè đặc thù cho từng menu/nút cụ thể theo key (`"Shop"`, `"Inventory"`, `"TopPlayersStats"`...).
- **Resolver:** `GuiAnimConfig` cung cấp public getters (`GetPopConfig`, `GetButtonScaleConfig`, `GetStaggerConfig`, `GetItemRewardAnimConfig`...) tự động hòa trộn `Overrides` với `Default` qua helper private `Resolve(AnimKey, OverrideKey)`. `GuiHelper` giữ các proxy 1 dòng sang `GuiAnimConfig` để Controllers không phải thay đổi call site.
- **File liên quan:** [GuiAnimConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiAnimConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

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

### 5. Single Source of Truth — Phân Tách GuiConfig (Tên) và GuiAnimConfig (Thông Số)
- **Chi tiết:** GUI config được tách thành 2 file với trách nhiệm rõ ràng:
  - **[GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua):** Chỉ chứa tên phần tử (strings) — `ScreenGuis`, `NavContainers`, `NavButtons`, `MenuFrames`, `HotbarElements`... và `Timeouts`. Không có Enum, Color3 hay giá trị animation.
  - **[GuiAnimConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiAnimConfig.lua):** Chứa `PlayerStatus` (màu sắc HUD), `GameOver` (màu, MaxNameLength) và toàn bộ `Animations` block (10 animation types) + public getters.
- **Lý do:** Hai loại dữ liệu có tính chất khác nhau hoàn toàn — tên instance trong Roblox Studio (static, không đổi) vs thông số hành vi runtime (hay điều chỉnh). Tách ra giúp locate nhanh khi cần sửa.
- **Cả 2 file đều nằm trong `ReplicatedStorage/Shared/Config/`** để Server (`MatchService`) và Client đều có thể require trực tiếp.
- **File liên quan:** [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [GuiAnimConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiAnimConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 6. Mẫu Truy Xuất Động GUI (Dynamic GUI Resolver Pattern)
- **Chi tiết:** Trong kiến trúc Single-Controller Client, các controller sử dụng hàm resolver động (`ResolveScreenElements` / `ResolveElements`) để luôn truy xuất trực tiếp instance GuiObject đang active trong `PlayerGui` thay vì cache biến tĩnh lúc `Init()`.
- **Tự động hóa:** Hàm resolver tự động ép `ResetOnSpawn = false` và `Enabled = true` ngay khi truy xuất, kết hợp fallback thông minh (`Background = Frame:FindFirstChild("Background") or Frame`), loại bỏ hoàn toàn nguy cơ rò rỉ bộ nhớ hoặc tương tác trên GUI chết.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ModeAnnouncementController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ModeAnnouncementController.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 7. Chuẩn hóa Phân cấp Animation trên Phần tử con Background trong ScreenGui Đặc biệt
- **Chi tiết:** Thay vì tween trực tiếp trên Frame cha (`RoundLoadingScreen`, `ItemReward`) làm phá vỡ cấu trúc container toàn màn hình, chuyển 100% các animation nền (fade in/out, flash trắng chuyển pha) sang phần tử con `Background` (`Frame`/`ImageLabel`). Frame cha giữ `BackgroundTransparency = 1` và thuần túy quản lý `Visible` và vòng đời hiển thị.
- **File liên quan:** [RoundLoadingScreenController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/RoundLoadingScreenController.lua), [ItemRewardController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua)

### 8. Kiến trúc Phân quyền Tương tác Nút Bấm & Bộ lọc Tự động (Selective AutoBind & Component Authority Pattern)
- **Chi tiết:** Phân tách ranh giới rõ ràng giữa **Auto-Binding toàn cục** (`GuiHelper.AutoBindButtons`) và **Component-Level Binding** (`ItemCard`, custom UI elements):
  - `GuiHelper.AutoBindButtons`: Quét và tự động gán Scale Animation + SFX cho toàn bộ `GuiButton` trong container qua `DescendantAdded`.
  - **Cơ chế Loại trừ 3 Tầng (Selective Filter):**
    1. *Đã xử lý:* Kiểm tra `_BoundButtons[Button]` (được đánh dấu bởi `GuiHelper.MarkBound` hoặc các hàm bind trực tiếp).
    2. *Attribute bỏ qua:* Kiểm tra thuộc tính `IgnoreAutoBind == true` hoặc `AutoBind == false` trên nút hoặc trên bất kỳ Frame tổ tiên nào (cho phép tắt theo từng nhánh component).
    3. *Khu vực Template:* Tự động bỏ qua mọi phần tử con nằm trong container/folder có tên `"Templates"`.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [GuiConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiConfig.lua), [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua)

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

### 4. Silent Value Divergence — Fallback Hardcode trong Helper Lệch Giá Trị Config
- **Vấn đề:** Khi getter của `GuiHelper` (trước khi tách) tự resolve Default+Override và đặt fallback hardcode cuối mỗi trường (`or 0.12`), nếu giá trị Default trong config bị sửa nhưng fallback không được cập nhật đồng bộ, code chạy đúng về mặt logic (không có lỗi runtime) nhưng sử dụng giá trị sai một cách âm thầm. Ví dụ thực tế: `Phase1DotBlinkTime` trong `GuiHelper.GetGameLoadingAnimConfig` fallback `= 0.12` trong khi `GuiConfig` khai báo `= 0.4`.
- **Nguyên nhân gốc:** Logic resolve Default+Override bị đặt trong Helper thay vì trong Config module — tạo ra 2 nơi cần đồng bộ giá trị.
- **Giải pháp:** Di chuyển toàn bộ logic resolve và getters vào `GuiAnimConfig.lua`. `GuiHelper` chỉ giữ proxy 1 dòng (`return GuiAnimConfig.GetXxx(...)`). Khi Default trong `GuiAnimConfig` thay đổi, Helper tự động phản ánh — không còn chỗ để diverge.
- **File liên quan:** [GuiAnimConfig.lua](../../src/ReplicatedStorage/Shared/Config/GuiAnimConfig.lua), [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua)

### 5. Ghi đè Tương tác & Lãng phí Hiệu năng do DescendantAdded trong AutoBindButtons
- **Vấn đề:** Khi clone các thẻ hiển thị tĩnh (như `ItemTemplate` trong `Shop` Chest Preview hay `Profile` Equipped Items với `EnableHover = false`), các thẻ này vẫn bị phóng to và phát SFX khi di chuột qua.
- **Nguyên nhân:** `AutoBindButtons` gắn trên Frame cha (`Shop`, `Profile`) lắng nghe `DescendantAdded`. Khi `ItemCard.Create` clone template và gán `.Parent`, `DescendantAdded` bắt được `GuiButton` con và tự động gắn đè `BindButtonScale` và `BindButtonSound`, vô hiệu hóa cấu hình `EnableHover = false`.
- **Giải pháp:**
  1. `ItemCard` gọi `GuiHelper.MarkBound(Frame)` cho toàn bộ các nút con và gán `SetIgnoreAutoBind(Frame, true)` trước khi set `.Parent`.
  2. `AutoBindButtons` tích hợp hàm kiểm tra `ShouldIgnoreAutoBind` để tôn trọng quyền cấu hình riêng của từng component và bỏ qua toàn bộ folder `Templates`.
- **File liên quan:** [GuiHelper.lua](../../src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [ItemCard.lua](../../src/ReplicatedStorage/Shared/Tools/ItemCard.lua), [ShopController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ShopController.lua), [ProfileController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/ProfileController.lua)

### 6. Bẫy Toạ Độ Tĩnh Position của Phần Tử Con Khi Bị Quản Lý Bởi UIListLayout
- **Vấn đề:** Khi tạo component thanh trượt (Stepped Slider) với các vạch chia `Tick1` $\rightarrow$ `Tick11`, nếu script đọc `TargetTick.Position` để gán toạ độ cho núm `Knob`, núm bị khóa cứng tại góc trái ($0\%$) và không thể di chuyển khi tương tác.
- **Nguyên nhân:** Khi các phần tử con được sắp xếp bằng `UIListLayout`, Roblox quản lý vị trí runtime độc quyền; thuộc tính tĩnh `Position` của toàn bộ các phần tử con trong Studio vẫn giữ nguyên giá trị `UDim2.new(0, 0, 0, 0)`.
- **Giải pháp:** Tuyệt đối không đọc thuộc tính `Position` tĩnh của các đối tượng nằm trong layout container. Thay vào đó:
  1. Sử dụng công thức toán học tuyến tính:
     $$\text{Knob.Position} = \text{UDim2.new}\left(\frac{\text{StepIndex}}{\text{StepCount}}, 0, 0.5, 0\right)$$
  2. Gán `Knob.AnchorPoint = Vector2.new(0.5, 0.5)` để tâm của núm luôn căn chính xác $100\%$ vào tâm từng vạch chia $0\%, 10\%, \dots, 100\%$.
- **File liên quan:** [SliderHelper.lua](../../src/ReplicatedStorage/Shared/Tools/SliderHelper.lua), [SettingController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/SettingController.lua)
