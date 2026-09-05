# CombatSystem
> Tổng hợp kiến thức kiến trúc và giải pháp kỹ thuật về hệ thống chiến đấu (Icicle Tool, Hitbox Spatial Query, Freeze/Thaw mechanics, IceBlock Model và Tags CollectionService).
> Cập nhật lần cuối: 05-09-2026

---

## Kiến trúc

### 1. Vòng đời Icicle Tool & Nhận diện Va chạm bằng Spatial Query (Hitbox Window)
- **Chi tiết:** Cấp phát Tool động: Tool được lưu trữ tại `ServerStorage.Icicles` và được `IcicleService` clone, hàn ghép skin và đưa vào Backpack người chơi khi chuyển sang phase `InGame`. Tịch thu tool ngay lập tức khi người chơi bị `Freeze` hoặc `Dead`, và trao trả lại khi được `Thaw`.
- **Cơ chế Hit Detection:** Thay vì sử dụng Raycast (dễ bị cản trở bởi các object khác) hay `.Touched` (kém chính xác và phụ thuộc physics engine), hệ thống sử dụng Spatial Query `workspace:GetPartsInPart(Hitbox, OverlapParams)` trên Client.
- **Hitbox Active Window:** Hitbox chỉ được kích hoạt trong khoảng thời gian vung vũ khí thực tế dựa trên cấu hình `AnimationConfig.Default` (`HitStartTime`, `HitEndTime`). Trong khoảng thời gian này, `RunService.Heartbeat` quét liên tục, sử dụng bảng dedup `HitPlayers` để đảm bảo mỗi mục tiêu chỉ bị đánh trúng 1 lần duy nhất mỗi cú vung, sau đó `FireServer` ngay lập tức.
- **File liên quan:** [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [IcicleService.lua](../../src/ServerScriptService/Services/IcicleService.lua), [AnimationConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnimationConfig.lua)

### 2. Khối băng Đa hình (Model-based Ice Block) & Dynamic Welding
- **Chi tiết:** Khối băng đóng băng người chơi được thiết kế dưới dạng `Model` chứa nhiều BasePart phức tạp thay vì Part đơn lẻ, cho phép tự do thiết kế mỹ thuật các skin băng đa dạng.
- **Cơ chế gắn kết:** Khi kích hoạt đóng băng, Server clone Model từ `ServerStorage.IceBlocks`, đặt vị trí qua `PivotTo` vào `HumanoidRootPart` của nạn nhân, sau đó tự động tạo `WeldConstraint` hàn tất cả các BasePart con vào `HumanoidRootPart` để khối băng di chuyển hoàn toàn đồng bộ với nhân vật.
- **Khóa cứng vị trí nạn nhân:** Đặt `HumanoidRootPart.Anchored = true` khi `FreezePlayer` để người chơi cố định tại vị trí bị trúng đòn (kể cả trên không), ngăn nhân vật bị va chạm vật lý Roblox đẩy văng đi. Khôi phục `Anchored = false` khi `ThawPlayer`.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### 3. Cơ chế Quét Va chạm Giải cứu Khối băng (Block Hitbox for Thaw)
- **Chi tiết:** Để hỗ trợ các skin khối băng đa dạng về hình dáng mà vẫn đảm bảo tính công bằng trong gameplay, mỗi Model Block bắt buộc chứa một Part chuẩn tên `Hitbox`.
- **Logic giải cứu:** Khi đóng băng, Server bật `CanQuery = true` cho Hitbox của Block và gắn tag `TagConfig.Tags.Hitbox`. Client khi vung Icicle Tool quét trúng Part Hitbox này sẽ đọc Attribute `VictimUserId` trên Block Model để xác định đồng minh cần giải cứu (`Thaw`), thay vì phải quét trúng Character của nạn nhân.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### 4. Quản lý Thực thể qua TagConfig & TagHelper (CollectionService)
- **Chi tiết:** Định nghĩa danh mục Tags chuẩn toàn game trong `TagConfig` (`IceBlock`, `Hitbox`, `HighlightHelper`, `SpawnPoint`). `TagHelper` bọc các API `AddTag`, `RemoveTag`, `HasTag`, `GetTagged`, `ObserveTagAdded`, `ObserveTagRemoved`.
- **Tối ưu hóa truy vấn:** `FreezeService` tự động gắn/gỡ tag khi tạo/xóa khối băng. Các hệ thống khác sử dụng `TagHelper.GetTagged(TagConfig.Tags.IceBlock)` để truy xuất trực tiếp các khối băng với hiệu năng cao, triệt tiêu hoàn toàn việc quét toàn bộ `Workspace:GetChildren()` $O(n)$.
- **File liên quan:** [TagConfig.lua](../../src/ReplicatedStorage/Shared/Config/TagConfig.lua), [TagHelper.lua](../../src/ReplicatedStorage/Shared/Tools/TagHelper.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### 5. Quản lý Bộ nhớ Khối băng O(1) Cache
- **Chi tiết:** Module Server `FreezeService` duy trì bảng cache cục bộ `_iceBlocks` (map `UserId -> BlockModel`). Khi `SpawnIceBlock`, lưu reference ngay sau khi set parent. Khi `RemoveIceBlock`, tra cứu trực tiếp $O(1)$ và dọn dẹp. Thực hiện cleanup an toàn trong sự kiện `Players.PlayerRemoving` để chống rò rỉ bộ nhớ.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua)

### 6. Quản lý Vòng đời Highlight Nhân vật & Khối Băng (HighlightController)
- **Chi tiết:** Quản lý viền Highlight cục bộ hoàn toàn tại Client (`HighlightController`).
- **Logic Highlight:** Phân biệt phe theo `LocalPlayer` (Đồng minh = Xanh, Kẻ địch = Đỏ; trong FFA = 100% Đỏ). Chỉ gán Highlight khi cả `LocalPlayer` và mục tiêu thỏa mãn `IsInMatch == true` và `State ~= "Dead"`.
- **Highlight khối băng xuyên vật thể:** Khi mục tiêu bị đóng băng (`State == "Frozen"`), Client gán `Highlight.Adornee = HighlightHelper` (Part nằm trong Model khối băng) với `DepthMode = Enum.HighlightDepthMode.AlwaysOnTop` để người chơi định vị rõ vị trí đồng minh/kẻ địch bị đóng băng xuyên qua các bức tường. Khi giải cứu (`Thaw`), `Adornee` được trả lại cho `Character`.
- **File liên quan:** [HighlightController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)

### 7. Mô hình Stateful Attack Verification & Xác thực Đòn đánh Đa tầng (Server Authority)
- **Chi tiết:** Triệt tiêu hoàn toàn fake-hit và bypass swing bằng quy trình xác thực trạng thái 2 pha có phân quyền rõ ràng giữa vũ khí và luật chơi:
  1. *Khởi tạo Phiên đánh (IcicleService):* Client gửi `OnToolSwing` ngay khi click vung kiếm. Server kiểm tra Phase `InGame`, State `Normal`, `Health > 0`, Tool Icicle trên tay và Cooldown (`GameConfig.Tool.IcicleCooldown`). Nếu hợp lệ, tạo `_AttackSessions[UserId] = { SwingStartTime = Now, SkinId = SkinId, HitTargets = {} }` và broadcast SFX.
  2. *Xác thực Đòn đánh (FreezeService):* Khi nhận `OnToolHit`, Server bắt buộc tra cứu `AttackSession` từ `IcicleService` (từ chối ngay nếu thiếu session).
  3. *Timing Window:* Thời gian trôi qua $\Delta t = \text{Now} - \text{SwingStartTime}$ phải nằm trong khoảng $[\text{HitStartTime} - \text{Tol}, \text{HitEndTime} + \text{Tol}]$ (đọc từ `AnimationConfig` theo SkinId và `HitWindowLatencyTolerance`).
  4. *Góc nhìn LookVector (XZ Projection):* Chiếu vector hướng nhìn và vector tới mục tiêu lên mặt phẳng XZ để loại bỏ sai số độ cao khi nhảy/dốc:
     $$\text{Dot} = \vec{U}_{\text{Facing}} \cdot \vec{U}_{\text{Target}} \ge \text{GameConfig.Tool.MinDotProduct} \ (0.5)$$
     Triệt tiêu hoàn toàn hành vi quay lưng chém hoặc 360° Kill-Aura.
  5. *Khoảng cách & LoS:* Kiểm tra $D \le \text{HitboxRange} \times \text{HitLagTolerance}$ và Raycast LoS loại trừ toàn bộ nhân vật người chơi trong trận để tránh bị chặn nhầm bởi người thứ ba.
  6. *Alive & Phase Check:* Bắt buộc cả hai bên có `Humanoid.Health > 0`, trận đấu đang `InGame` (thông qua `SessionService.GetCurrentPhase()`).
- **File liên quan:** [IcicleService.lua](../../src/ServerScriptService/Services/IcicleService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [AnimationConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnimationConfig.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

### 8. Bảo Mật Server Authority & Cô Lập Mã Nguồn Quản Trị / Backend
- **Chi tiết:** Mọi tệp chứa cấu hình quản trị viên, ID người dùng Admin (`AdminConfig.lua`) và thư viện DataStore can thiệp dữ liệu sâu (`ProfileService.lua`) tuyệt đối không được đặt trong `ReplicatedStorage`.
- **Nguyên lý Cô lập:** Di dời toàn bộ vào `ServerScriptService/Config/AdminConfig.lua` và `ServerScriptService/Lib/ProfileService.lua`. Cấu hình Rojo map trực tiếp vào Server, Client hoàn toàn bị cô lập khỏi mã nguồn nhạy cảm, loại bỏ nguy cơ hacker dịch ngược Client để khai thác danh sách Admin.
- **File liên quan:** [AdminConfig.lua](../../src/ServerScriptService/Config/AdminConfig.lua), [ProfileService.lua](../../src/ServerScriptService/Lib/ProfileService.lua), [AdminService.lua](../../src/ServerScriptService/Services/AdminService.lua), [DataService.lua](../../src/ServerScriptService/Services/DataService.lua)

---

## Vấn đề kiến trúc & Giải pháp

### 1. Dọn dẹp IceBlock Model tàn dư thất bại do so khớp tên tĩnh ("IceBlock")
- **Vấn đề:** Khi chuyển sang hệ thống skin động (Model), các khối băng được đặt tên theo SkinId (vd: "Default", "RedIce") thay vì tên cố định "IceBlock". Logic dọn dẹp cũ quét `workspace:GetChildren()` kiểm tra `Child.Name == "IceBlock"` nên không bao giờ tìm thấy.
- **Giải pháp:** Sử dụng `TagHelper.GetTagged(TagConfig.Tags.IceBlock)` để dọn dẹp toàn bộ các khối băng sót lại khi kết thúc trận, đảm bảo độ chính xác tuyệt đối và tối ưu tốc độ xử lý.
- **File liên quan:** [MatchService.lua](../../src/ServerScriptService/Services/MatchService.lua), [TagHelper.lua](../../src/ReplicatedStorage/Shared/Tools/TagHelper.lua)

### 2. Hitbox Tool bị rơi rớt hoặc đứng yên do thiếu WeldConstraint
- **Vấn đề:** Khi người chơi kích hoạt tool, dù đứng sát đối thủ nhưng Client không phát hiện va chạm do Hitbox không di chuyển theo nhân vật.
- **Nguyên nhân:** Trong template Tool (`ServerStorage.Icicles.Default`), Part `Hitbox` không được hàn (`Weld`) vào `Handle`. Khi nhân vật trang bị Tool, chỉ có `Handle` được gắn vào tay, còn `Hitbox` bị rơi tự do hoặc đứng yên tại tọa độ gốc.
- **Giải pháp:** Bắt buộc tạo `WeldConstraint` liên kết `Hitbox` với `Handle` trong toàn bộ asset template Tool.
- **File liên quan:** Template Tool trong `ServerStorage/Icicles/`

### 3. Sự kiện Animation Marker `GetMarkerReachedSignal` không kích hoạt
- **Vấn đề:** Animation marker `HitStart`/`HitEnd` không fire trên một số thiết bị hoặc asset animation đã publish, dẫn đến cửa sổ va chạm không bao giờ mở.
- **Giải pháp:** Thiết kế cơ chế timing dự phòng có cấu hình: Lưu `HitStartTime` và `HitEndTime` trong `AnimationConfig` cho từng skin vũ khí và sử dụng `task.delay` để kích hoạt/tắt cửa sổ quét va chạm.
- **File liên quan:** [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [AnimationConfig.lua](../../src/ReplicatedStorage/Shared/Config/AnimationConfig.lua)

### 4. Highlight tồn dư trên nhân vật hồi sinh ở Sảnh khi Reset trong Setup/Ready
- **Vấn đề:** Khi người chơi Reset nhân vật trong phase Setup hoặc Ready, nhân vật mới hồi sinh ở Sảnh vẫn bị gán viền Highlight của trận đấu.
- **Nguyên nhân:** Client không dọn dẹp `KnownTeams` khi nhận trạng thái `Dead`, đồng thời `CharacterAdded` ở sảnh không kiểm tra cờ `IsInMatch`.
- **Giải pháp:** Trong `HighlightController`, xóa ngay player khỏi `KnownTeams` khi `State == "Dead"`, kiểm tra nghiêm ngặt `PlayerStateHelper.IsInMatch(Player) == true` và `State ~= "Dead"` trước khi gán Highlight. Lắng nghe `PlayerStateHelper.ObserveMatchState` để cập nhật lại toàn bộ khi trạng thái tham gia trận của `LocalPlayer` thay đổi.
- **File liên quan:** [HighlightController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua), [PlayerStateHelper.lua](../../src/ReplicatedStorage/Shared/Tools/PlayerStateHelper.lua)

### 5. Rò rỉ Model Khối Băng (Orphaned IceBlock) trong Workspace khi Nạn nhân Thoát Game
- **Vấn đề:** Khi người chơi bị đóng băng (`Frozen`) thoát khỏi server, sự kiện `PlayerRemoving` chỉ gán `nil` trong bảng cache `_iceBlocks[UserId]`, bỏ quên việc gọi `:Destroy()` trên Model trong Workspace. Part và WeldConstraint tàn dư tồn tại vĩnh viễn gây rò rỉ RAM máy chủ và quá tải engine vật lý.
- **Giải pháp:** Trong `Players.PlayerRemoving` của `FreezeService`, gọi hàm `RemoveIceBlock(Player)` để tháo gỡ tag `TagConfig.Tags.IceBlock` và gọi `:Destroy()` trên Model trước khi giải phóng tham chiếu khỏi bảng cache.
- **File liên quan:** [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [TagHelper.lua](../../src/ReplicatedStorage/Shared/Tools/TagHelper.lua)

### 6. Rò Rỉ Kết Nối Sự Kiện & Luồng Quét Hitbox Chạy Ngầm Trong `IcicleScript`
- **Vấn đề:** 
  1. Mỗi lần click kích hoạt Tool (`Activated`), code kết nối `Track.Stopped:Connect` mà không disconnect, gây tích lũy hàng chục listener trong bộ nhớ sau nhiều lần vung kiếm.
  2. Khi người chơi gỡ trang bị vũ khí (`Unequipped`), vòng lặp `Heartbeat` quét hitbox không bị ngắt nếu đang trong cửa sổ `HitStartTime` $\rightarrow$ `HitEndTime`, dẫn đến việc quét hitbox ngầm khi không cầm vũ khí.
- **Giải pháp:**
  1. Đổi `Track.Stopped:Connect` sang `Track.Stopped:Once` để tự động dọn dẹp listener ngay khi animation dừng.
  2. Gọi `StopHitboxPoll()` ngay bên trong listener `Tool.Unequipped` để lập tức ngắt kết nối `_HitboxConnection` khi cất vũ khí.
- **File liên quan:** [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### 7. Tụt FPS Do Quét Toàn Bộ Workspace $O(N \times M)$ Khi Cập Nhật Highlight Khối Băng
- **Vấn đề:** Trong `HighlightController`, sự kiện `Workspace.ChildAdded` và `ChildRemoved` lắng nghe trên toàn bộ Workspace. Mỗi khi bất kỳ instance nào sinh ra hoặc mất đi (kể cả hiệu ứng hạt particle, mảnh vụn), hàm `RefreshAll()` được gọi duyệt qua toàn bộ danh sách người chơi, gây drop FPS nghiêm trọng trong giao tranh đông người.
- **Giải pháp:** Gỡ bỏ hoàn toàn `Workspace.ChildAdded/Removed`. Sử dụng `TagHelper.ObserveTagAdded` và `ObserveTagRemoved` trên tag `TagConfig.Tags.IceBlock`. Khi có khối băng thay đổi, chỉ tra cứu `VictimUserId` và cập nhật Adornee $O(1)$ cho duy nhất người chơi tương ứng qua hàm `UpdateSinglePlayerHighlight`.
- **File liên quan:** [HighlightController.lua](../../src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua), [TagHelper.lua](../../src/ReplicatedStorage/Shared/Tools/TagHelper.lua)

### 8. Lỗi Runtime và Hỏng Dọn Dẹp Hitbox Do Khai Báo Hàm Cục Bộ Sau Sự Kiện (Function Hoisting & Scope Pitfall)
- **Vấn đề:** Trong Luau/Lua 5.1, khai báo `local function StopHitboxPoll()` nằm bên dưới sự kiện `Tool.Unequipped:Connect` khiến handler tra cứu biến toàn cục `StopHitboxPoll` (`nil`). Khi người chơi cất vũ khí hoặc bị đóng băng/hạ gục giữa lúc vung đòn, game văng exception `attempt to call a nil value`, làm chết đứng luồng dọn dẹp animation.
- **Giải pháp:** Bắt buộc đặt toàn bộ định nghĩa hàm tiện ích hoặc forward declaration (`local StopHitboxPoll`) lên trước các kết nối sự kiện lắng nghe vòng đời Tool.
- **File liên quan:** [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### 9. Lỗ hổng 360° Kill-Aura & Bypass Vung Kiếm trong Combat (`CRIT-04`)
- **Vấn đề:** `FreezeService` tiếp nhận `OnToolHit` độc lập và tự khởi tạo `_AttackSessions` bằng `os.clock()` khi nhận hit mà không cần biết Client có gọi `OnToolSwing` hay không. Đồng thời Server chỉ kiểm tra khoảng cách Euclidean 3D đơn thuần ($D \le 12\text{ studs}$), bỏ qua hoàn toàn góc nhìn và lượng máu `Health > 0`, cho phép kẻ gian quay lưng chém 360 độ hoặc chém từ cõi chết trước giờ đấu.
- **Giải pháp:** Thiết lập chuỗi xác thực Stateful Attack: `IcicleService` bắt buộc tiếp nhận `OnToolSwing` trước để mở `AttackSession` trong RAM Server. `FreezeService` tra cứu session, kiểm tra cửa sổ thời gian trôi qua $\Delta t \in [\text{HitStartTime} - \text{Tol}, \text{HitEndTime} + \text{Tol}]$, chiếu vector hướng nhìn lên mặt phẳng ngang XZ kiểm tra $\text{Dot} \ge 0.5$ ($\pm 60^\circ$ phía trước), kiểm tra `Humanoid.Health > 0` cả hai bên và lọc sạch toàn bộ Character người chơi khỏi Raycast LoS.
- **File liên quan:** [IcicleService.lua](../../src/ServerScriptService/Services/IcicleService.lua), [FreezeService.lua](../../src/ServerScriptService/Services/FreezeService.lua), [IcicleScript.client.lua](../../src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [GameConfig.lua](../../src/ReplicatedStorage/Shared/Config/GameConfig.lua), [SessionService.lua](../../src/ServerScriptService/Services/SessionService.lua)

