# CoreGameplay
> Tổng hợp kiến thức về cơ chế Gameplay cốt lõi (Freeze/Thaw, vòng lặp trận đấu) trong dự án.
> Cập nhật lần cuối: 21-07-2026

---

## Kiến trúc

### Tránh Circular Dependency bằng BindableEvent
- **Ngày:** 05-06-2026
- **Chi tiết:** Khi MatchService điều phối luồng game gọi FreezeService để cập nhật trạng thái, nếu FreezeService muốn kết thúc trận đấu và gọi ngược lại MatchService sẽ gây lỗi tham chiếu vòng (Circular Dependency). Giải pháp là dùng một BindableEvent (`MatchEndSignal`) trung gian đặt tại SessionService. FreezeService sẽ kích hoạt event này khi phát hiện một đội bị wipe sạch, và MatchService lắng nghe event để chuyển tiếp trạng thái GameOver.
- **File liên quan:** [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/SessionService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Xử lý Highlight phía Client
- **Ngày:** 05-06-2026
- **Chi tiết:** Việc tạo Highlight instance trực tiếp từ Server gây tốn băng thông mạng và khó tùy chỉnh riêng biệt cho từng client (ví dụ: bản thân player không được thấy highlight của chính mình). Giải pháp là Server chỉ đồng bộ team và trạng thái qua RemoteEvent, Client tự nhận diện và quản lý vòng đời của Highlight instance cục bộ.
- **File liên quan:** [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua), [TeamService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/TeamService.lua)

### Cấp phát Tool động (Dynamic Tool Lifecycle)
- **Ngày:** 21-07-2026
- **Chi tiết:** Thay vì đặt Tool trong StarterPack, Tool được lưu ở ServerStorage và được IcicleService clone, hàn ghép skin động và đưa vào Backpack người chơi khi trận đấu chuyển sang phase **InGame** (thay vì Ready) để tránh việc người chơi trang bị và sử dụng công cụ trong thời gian chuẩn bị, sau đó thu hồi khi GameOver. Đồng thời, khi người chơi bị đóng băng (Freeze), tool sẽ bị tịch thu ngay lập tức và chỉ được trao trả lại sau khi được cứu (Thaw) nếu trận đấu vẫn đang diễn ra.
- **File liên quan:** [IcicleService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/IcicleService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Luồng GameOver: đếm ngược trước, teleport & dọn dẹp, sau đó mới hiện stat
- **Ngày:** 06-06-2026
- **Chi tiết:** Luồng GameOver đúng: (1) Thu tool + kết thúc match + phát thưởng, (2) ThawAll, (3) Đếm ngược GameOverDuration (player vẫn ở trong đấu trường, chưa thấy bảng thống kê), (4) **Sau hết giờ**: teleport tất cả player về `workspace.SpawnLocation` bằng cách set `HRP.CFrame`, (5) Dọn IceBlock tàn dư, (6) UnloadMap, (7) **Cuối cùng**: fire `ShowGameOver` để hiện bảng thống kê khi player đã về Lobby. Pattern này đảm bảo player thấy stat trong môi trường sạch sẽ (Lobby), không còn map chiến đấu phía sau.
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Thiết kế va chạm Icicle Tool bằng Spatial Query với task.delay Window
- **Ngày:** 03-07-2026
- **Chi tiết:** Hit detection dùng `workspace:GetPartsInPart(Hitbox, OverlapParams)` (Spatial Query) thay vì Raycast. Hitbox chỉ active trong cửa sổ giai đoạn “vung” — xác định bằng `task.delay(HitStartTime)` và `task.delay(HitEndTime)`, timing được lưu trong `AudioConfig.Default` (per-skin) thay vì hardcode. Trong cửa sổ đó, `RunService.Heartbeat` poll liên tục; mỗi mục tiêu chỉ bị hit 1 lần (dedup bằng HitPlayers table), `FireServer` ngay khi phát hiện hit lần đầu. Audio được phát ngẫu nhiên từ danh sách `SwingAudios` (hỗ trợ cả 1 hoặc nhiều ID) tại `HitStartTime`. Guard `_CurrentSwingTrack ~= Track` bảo vệ trường hợp tool bị thu hồi trước khi delay fire. `PlaySwingAnimation()` trả về `Track` để caller gắn `Track.Stopped` fallback dừng poll khi Unequip.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [AudioConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/AudioConfig.lua)

### Hỗ trợ Va chạm Block Hitbox cho Thaw qua Spatial Query
- **Ngày:** 30-06-2026
- **Chi tiết:** Để hỗ trợ các skin khối băng (Ice Block) đa dạng nhưng vẫn đảm bảo công bằng, mỗi Model Block chứa một Part tên `Hitbox` có kích thước chuẩn. Khi đóng băng, server thiết lập `CanQuery = true` chỉ cho Hitbox của Block. Client khi kích hoạt Icicle Tool sẽ dùng `workspace:GetPartsInPart` để quét. Nếu chạm Block Hitbox, client đọc attribute `VictimUserId` trên Block Model để xác định người cần giải cứu (Thaw) thay vì tìm Character thông thường.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### Cơ chế Spree Streak độc lập để khuyến khích tinh thần đồng đội
- **Ngày:** 10-06-2026
- **Chi tiết:** Nhằm tối ưu hóa động lực của người chơi (incentive design), chuỗi Freeze Streak và Thaw Streak được quản lý hoàn toàn độc lập. Hành động đóng băng kẻ địch (Freeze) sẽ không làm reset chuỗi giải cứu (Thaw Streak) của người chơi đó, và ngược lại. Streak chỉ bị reset khi: (1) Bản thân đạt đủ điểm Spree để nhận thưởng, hoặc (2) Bản thân người chơi bị đóng băng (Victim). Thiết kế này khuyến khích người chơi thực hiện cả hai hành động đóng băng kẻ địch và giải cứu đồng đội mà không lo bị phạt mất chuỗi streak hiện có.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Hiển thị chi tiết phần thưởng Spree trong GameStatistic
- **Ngày:** 10-06-2026
- **Chi tiết:** Đồng bộ cách hiển thị của các chỉ số Freezing Spree và Thawing Spree tương tự như chỉ số Freezes và Thaws theo công thức: "Số lượng (× Giá trị) = Tổng nhận được". Thay đổi này giúp hiển thị trực quan tổng tiền thưởng tích lũy qua nhiều lần đạt Spree của người chơi trong trận đấu, thay vì chỉ hiển thị một giá trị tiền thưởng trực tiếp.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

---

## Bug & biện pháp

### StudioAccessToApisNotAllowed
- **Ngày:** 05-06-2026
- **Vấn đề:** Không thể ghi dữ liệu vào DataStore khi chạy thử game trong Roblox Studio.
- **Nguyên nhân:** Mặc định Roblox Studio khóa quyền truy cập vào API dịch vụ đám mây để đảm bảo an toàn cho game đã publish.
- **Fix:** Đăng tải game lên Roblox (Publish to Roblox), mở Game Settings -> Security -> Gạt bật "Enable Studio Access to API Services" -> Save.
- **File liên quan:** [DataService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ServerScriptService/Services/DataService.lua)

### IcicleScript Raycast bị chặn bởi IceBlock
- **Ngày:** 05-06-2026
- **Vấn đề:** Khi swing Icicle Tool, tia Raycast có thể bị chặn bởi các IceBlock trong workspace thay vì xuyên qua để hit target thực sự.
- **Nguyên nhân:** `FilterDescendantsInstances` chỉ loại trừ character của local player, không loại trừ các IceBlock instance đang tồn tại trong workspace.
- **Fix:** Trước mỗi lần raycast, thu thập tất cả Part tên "IceBlock" trong `workspace:GetChildren()` và thêm vào danh sách exclude của `RaycastParams`.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### Lỗi gọi sai API va chạm của Workspace
- **Ngày:** 06-06-2026
- **Vấn đề:** Gặp lỗi `GetPartBoundsOverlap is not a valid member of Workspace` ở Client khiến script bị crash khi kích hoạt tool.
- **Nguyên nhân:** Roblox API không cung cấp hàm `workspace:GetPartBoundsOverlap()`.
- **Fix:** Thay thế bằng API chuẩn `workspace:GetPartsInPart(Hitbox, Params)` để thực hiện spatial query va chạm.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### Hitbox không đi theo nhân vật khi di chuyển (Lỗi thiếu Weld)
- **Ngày:** 06-06-2026
- **Vấn đề:** Khi kích hoạt tool va chạm, mặc dù đứng sát đối thủ nhưng Client không phát hiện va chạm và đối thủ không bị đóng băng.
- **Nguyên nhân:** `Hitbox` của Tool trong Template (`ServerStorage.Icicles.Default`) không được hàn (weld) với `Handle`. Khi người chơi trang bị Tool, chỉ có `Handle` được gắn vào tay nhân vật, còn `Hitbox` bị rơi rớt hoặc đứng yên tại chỗ ở tọa độ ban đầu.
- **Fix:** Tạo `WeldConstraint` liên kết `Hitbox` sang `Handle` của Tool trong Template để `Hitbox` di chuyển theo nhân vật.
- **File liên quan:** `ServerStorage/Icicles/Default` (Roblox Studio)

### `GetMarkerReachedSignal` không fire — Workaround: `task.delay`
- **Ngày:** 02-07-2026
- **Vấn đề:** Marker signal `HitStart`/`HitEnd` không bao giờ fire dù animation có marker đúng tên, đúng ID, đã publish. Print bên trong callback không xuất hiện. Animation vẫn chạy bình thường.
- **Nguyên nhân:** Chưa xác định chính xác. Đã thử: (1) Animation Marker trong Studio, (2) `Animator:LoadAnimation()` thay `Humanoid:LoadAnimation()` (deprecated), (3) Tạo animation mới, (4) Reset Roblox. Tất cả đều không giải quyết được.
- **Workaround hiện tại (Hoướng B — đang dùng):** Dùng `task.delay(HitStartTime, ...)` và `task.delay(HitEndTime, ...)` với timing lưu trong `AudioConfig` (per-skin). Hoạt động ổn định nhưng cần sync timing thủ công với animation khi sửa.
- **Hướng A (chưa giải quyết — cần quay lại):** Tiếp tục điều tra tại sao `GetMarkerReachedSignal` không fire. Có thể liên quan đến Roblox platform bug hoặc cấu hình LocalScript. Nếu giải quyết được, chuyển lại sang Marker để tiết kiệm công sức maintain.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [AudioConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/FrozenState/src/ReplicatedStorage/Shared/Config/AudioConfig.lua)
