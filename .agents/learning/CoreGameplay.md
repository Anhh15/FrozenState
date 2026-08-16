# CoreGameplay
> Tổng hợp kiến thức về cơ chế Gameplay cốt lõi (Freeze/Thaw, vòng lặp trận đấu, Audio/Animation, Map/Spawn, Tags và Kinh tế/Thưởng) trong dự án.
> Cập nhật lần cuối: 17-08-2026

---

## Kiến trúc

### Kiến trúc Tách biệt Audio (AudioConfig & AudioHelper) và Animation (AnimationConfig & AnimationHelper)
- **Ngày:** 17-08-2026
- **Chi tiết:** Tách bạch hoàn toàn giữa hệ thống âm thanh và chuyển động để tránh lai tạp cấu hình. `AudioConfig` chỉ lưu Sound IDs, BGM, SFX và âm lượng; `AudioHelper` cung cấp API phát 2D (GUI/Notification), 3D Spatial (gắn Part/HRP, tự dọn dẹp bằng `Sound.Ended:Once()`), tạo Sound Pool cho vũ khí và Preload assets. `AnimationConfig` lưu Animation IDs (Swing, Pose), timing cửa sổ Hitbox (`HitStartTime`, `HitEndTime`), Track priority; `AnimationHelper` chuẩn hóa nạp Track qua `Animator:LoadAnimation()` (loại bỏ `Humanoid:LoadAnimation` cũ), cache track và chống rò rỉ bộ nhớ khi nhân vật chết/respawn.
- **File liên quan:** [AudioConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [AudioHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [AnimationConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/AnimationConfig.lua), [AnimationHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AnimationHelper.lua), [SoundController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/SoundController.lua), [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### Kiến trúc Tập trung hóa Kinh tế & Phần thưởng qua EconomyConfig & RewardHelper
- **Ngày:** 17-08-2026
- **Chi tiết:** Tách toàn bộ giá trị thưởng (Freeze, Thaw, Freezing/Thawing Spree, First Blood, Last Standing, Win, Lose) và mốc Spree Threshold khỏi `GameConfig` sang `EconomyConfig` độc lập. `RewardHelper` đóng gói các công thức tính thưởng (tính BaseReward + SpreeBonus theo chuỗi streak), kiểm tra First Blood, thưởng kết thúc trận và hàm đồng bộ tiền `RewardAndSync(Player, Amount, DataService, UpdateMoneyEvent)`. Giúp `FreezeService`, `MatchService`, `GameStatisticController` đọc và trao thưởng thống nhất mà không duplicate logic.
- **File liên quan:** [EconomyConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/EconomyConfig.lua), [RewardHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/RewardHelper.lua), [GameConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GameConfig.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua)

### Kiến trúc Quản lý Bản đồ & Spawn qua MapConfig & MapHelper
- **Ngày:** 17-08-2026
- **Chi tiết:** Loại bỏ hoàn toàn hardcoded string đường dẫn thư mục trong `MapService`. `MapConfig` quản lý tên folder (`Maps`, `CurrentMap`, `SpawnPoint`, `TeamBase`, `FFA`) và prefix spawn (`T1SpawnPoint`, `T2SpawnPoint`, `SpawnPoint`). `MapHelper` cung cấp các hàm tiện ích lọc danh sách Part spawn theo team/FFA, chọn ngẫu nhiên điểm spawn và tính CFrame spawn an toàn phía trên mặt sàn cho nhân vật.
- **File liên quan:** [MapConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/MapConfig.lua), [MapHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/MapHelper.lua), [MapService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MapService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Kiến trúc Quản lý Thực thể qua TagConfig & TagHelper (CollectionService)
- **Ngày:** 17-08-2026
- **Chi tiết:** Định nghĩa danh mục CollectionService Tags chuẩn toàn game trong `TagConfig` (`IceBlock`, `Hitbox`, `HighlightHelper`, `SpawnPoint`). `TagHelper` bọc các API `AddTag`, `RemoveTag`, `HasTag`, `GetTagged`, `ObserveTagAdded`, `ObserveTagRemoved`. `FreezeService` tự động gắn/gỡ tag khi tạo/xóa khối băng. `HighlightController` dùng `TagHelper.GetTagged(IceBlock)` để tìm nhanh Model khối băng của victim thay vì quét toàn bộ Workspace qua `GetChildren()` $O(n)$.
- **File liên quan:** [TagConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/TagConfig.lua), [TagHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/TagHelper.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua)

### Highlight khối băng bị đóng băng qua Adornee HighlightHelper
- **Ngày:** 23-07-2026
- **Chi tiết:** Khi một người chơi bị đóng băng, Server spawn Model khối băng vào Workspace (có chứa Part/Mesh `HighlightHelper`). Client (`HighlightController.lua`) quản lý Highlight cục bộ dựa trên phe đối với `LocalPlayer` (Đồng minh = Xanh, Kẻ địch = Đỏ). Khi mục tiêu bị đóng băng, Client gán `Highlight.Adornee = HighlightHelper` với `DepthMode = AlwaysOnTop` thay vì bọc toàn bộ Character. Khi giải cứu (Thaw), `Adornee` được trả lại `Character`. Lắng nghe `Workspace.ChildAdded`/`ChildRemoved` để cập nhật `Adornee` tức thì khi khối băng xuất hiện hoặc biến mất.
- **File liên quan:** [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Tránh Circular Dependency bằng BindableEvent
- **Ngày:** 05-06-2026
- **Chi tiết:** Khi MatchService điều phối luồng game gọi FreezeService để cập nhật trạng thái, nếu FreezeService muốn kết thúc trận đấu và gọi ngược lại MatchService sẽ gây lỗi tham chiếu vòng (Circular Dependency). Giải pháp là dùng một BindableEvent (`MatchEndSignal`) trung gian đặt tại SessionService. FreezeService sẽ kích hoạt event này khi phát hiện một đội bị wipe sạch, và MatchService lắng nghe event để chuyển tiếp trạng thái GameOver.
- **File liên quan:** [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Xử lý Highlight phía Client
- **Ngày:** 05-06-2026
- **Chi tiết:** Việc tạo Highlight instance trực tiếp từ Server gây tốn băng thông mạng và khó tùy chỉnh riêng biệt cho từng client (ví dụ: bản thân player không được thấy highlight của chính mình). Giải pháp là Server chỉ đồng bộ team và trạng thái qua RemoteEvent, Client tự nhận diện và quản lý vòng đời của Highlight instance cục bộ.
- **File liên quan:** [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua), [TeamService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/TeamService.lua)

### Highlight xuyên tường cho Player bị đóng băng (AlwaysOnTop)
- **Ngày:** 21-07-2026
- **Chi tiết:** Nhằm giúp định vị đồng minh để cứu và kẻ địch để canh gác, highlight nhân vật bị đóng băng được hiển thị xuyên vật thể. Client tự duy trì bảng cache trạng thái đóng băng (`_frozenPlayers`) thông qua RemoteEvent `UpdatePlayerState` có sẵn từ Server. Việc này giúp cô lập mã nguồn tại client và tối ưu cho trận đấu vòng khép kín. Trạng thái đóng băng cá nhân kết hợp logic với Game Phase (`_isFrozenState`) để cập nhật thuộc tính `DepthMode` (`AlwaysOnTop` khi bị đóng băng hoặc trong phase FrozenState, ngược lại quay về `Occluded`).
- **File liên quan:** [HighlightController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/HighlightController.lua)

### Cấp phát Tool động (Dynamic Tool Lifecycle)
- **Ngày:** 21-07-2026
- **Chi tiết:** Thay vì đặt Tool trong StarterPack, Tool được lưu ở ServerStorage và được IcicleService clone, hàn ghép skin động và đưa vào Backpack người chơi khi trận đấu chuyển sang phase **InGame** (thay vì Ready) để tránh việc người chơi trang bị và sử dụng công cụ trong thời gian chuẩn bị, sau đó thu hồi khi GameOver. Đồng thời, khi người chơi bị đóng băng (Freeze), tool sẽ bị tịch thu ngay lập tức và chỉ được trao trả lại sau khi được cứu (Thaw) nếu trận đấu vẫn đang diễn ra.
- **File liên quan:** [IcicleService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/IcicleService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Luồng GameOver: đếm ngược trước, teleport & dọn dẹp, sau đó mới hiện stat
- **Ngày:** 06-06-2026
- **Chi tiết:** Luồng GameOver đúng: (1) Thu tool + kết thúc match + phát thưởng, (2) ThawAll, (3) Đếm ngược GameOverDuration (player vẫn ở trong đấu trường, chưa thấy bảng thống kê), (4) **Sau hết giờ**: teleport tất cả player về `workspace.SpawnLocation` bằng cách set `HRP.CFrame`, (5) Dọn IceBlock tàn dư, (6) UnloadMap, (7) **Cuối cùng**: fire `ShowGameOver` để hiện bảng thống kê khi player đã về Lobby. Pattern này đảm bảo player thấy stat trong môi trường sạch sẽ (Lobby), không còn map chiến đấu phía sau.
- **File liên quan:** [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua)

### Thiết kế va chạm Icicle Tool bằng Spatial Query với task.delay Window
- **Ngày:** 03-07-2026 (cập nhật 17-08-2026)
- **Chi tiết:** Hit detection dùng `workspace:GetPartsInPart(Hitbox, OverlapParams)` (Spatial Query) thay vì Raycast. Hitbox chỉ active trong cửa sổ giai đoạn "vung" — xác định bằng `task.delay(HitStartTime)` và `task.delay(HitEndTime)`, timing được lưu trong `AnimationConfig.Default` (per-skin) thay vì hardcode. Trong cửa sổ đó, `RunService.Heartbeat` poll liên tục; mỗi mục tiêu chỉ bị hit 1 lần (dedup bằng HitPlayers table), `FireServer` ngay khi phát hiện hit lần đầu. Audio được phát ngẫu nhiên từ danh sách `SwingAudios` (qua `AudioConfig` và `AudioHelper.PlayPooledSound`) tại `HitStartTime`. Guard `_CurrentSwingTrack ~= Track` bảo vệ trường hợp tool bị thu hồi trước khi delay fire.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [AnimationConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/AnimationConfig.lua), [AudioConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/AudioConfig.lua), [AudioHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AudioHelper.lua)

### Hỗ trợ Va chạm Block Hitbox cho Thaw qua Spatial Query
- **Ngày:** 30-06-2026
- **Chi tiết:** Để hỗ trợ các skin khối băng (Ice Block) đa dạng nhưng vẫn đảm bảo công bằng, mỗi Model Block chứa một Part tên `Hitbox` có kích thước chuẩn. Khi đóng băng, server thiết lập `CanQuery = true` chỉ cho Hitbox của Block và gắn tag `TagConfig.Tags.Hitbox`. Client khi kích hoạt Icicle Tool sẽ dùng `workspace:GetPartsInPart` để quét. Nếu chạm Block Hitbox, client đọc attribute `VictimUserId` trên Block Model để xác định người cần giải cứu (Thaw) thay vì tìm Character thông thường.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### Cơ chế Spree Streak độc lập để khuyến khích tinh thần đồng đội
- **Ngày:** 10-06-2026 (cập nhật 17-08-2026)
- **Chi tiết:** Nhằm tối ưu hóa động lực của người chơi, chuỗi Freeze Streak và Thaw Streak được quản lý hoàn toàn độc lập. Hành động đóng băng kẻ địch (Freeze) không làm reset chuỗi giải cứu (Thaw Streak) của người chơi đó, và ngược lại. Streak chỉ bị reset khi: (1) Bản thân đạt đủ mốc `EconomyConfig.Spree.Threshold` để nhận thưởng Spree Bonus (tính qua `RewardHelper`), hoặc (2) Bản thân người chơi bị đóng băng (Victim).
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [RewardHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/RewardHelper.lua), [EconomyConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/EconomyConfig.lua)

### Hiển thị chi tiết phần thưởng Spree trong GameStatistic
- **Ngày:** 10-06-2026 (cập nhật 17-08-2026)
- **Chi tiết:** Đồng bộ cách hiển thị của các chỉ số Freezing Spree và Thawing Spree tương tự như chỉ số Freezes và Thaws theo công thức: "Số lượng (× Giá trị) = Tổng nhận được". Giá trị tiền thưởng từng loại hành động được tra cứu từ `RewardHelper.GetRewardAmount()` thay vì hardcode hay đọc trực tiếp table cũ.
- **File liên quan:** [GameStatisticController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/GameStatisticController.lua), [RewardHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/RewardHelper.lua)

### Cache IceBlock để RemoveIceBlock chạy O(1) (thay vì scan workspace O(n))
- **Ngày:** 12-08-2026
- **Chi tiết:** Ban đầu `RemoveIceBlock()` duyệt toàn bộ `workspace:GetChildren()` mỗi lần Thaw để tìm đúng Block Model — O(n) theo số object trong workspace. Tối ưu bằng cách thêm `local _iceBlocks = {}` (map `UserId → BlockModel`) tại module level. `SpawnIceBlock()` lưu reference ngay sau khi set parent: `_iceBlocks[Victim.UserId] = BlockModel`. `RemoveIceBlock()` lookup trực tiếp O(1) và set nil. Cleanup trong `PlayerRemoving` để tránh memory leak. `ThawAll()` không cần dùng cache riêng vì vẫn loop qua Players.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Tập trung hằng số di chuyển vào GameConfig.Player (không hardcode ở nhiều nơi)
- **Ngày:** 12-08-2026
- **Chi tiết:** `DEFAULT_WALK_SPEED`, `DEFAULT_JUMP_POWER`, `DEFAULT_JUMP_HEIGHT` từng được định nghĩa lặp lại ở cả `MatchService.lua` và `FreezeService.lua`. Quy tắc: tất cả thông số di chuyển mặc định của player phải khai báo **một lần duy nhất** trong `GameConfig.Player` (`DefaultWalkSpeed`, `DefaultJumpPower`, `DefaultJumpHeight`). Các service chỉ được đọc từ đó. Điều này đảm bảo chỉnh một nơi là áp dụng đồng bộ mọi nơi (SetMovementLocked, ThawPlayer, ThawAll, SpectateController.UnlockMovement).
- **File liên quan:** [GameConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/GameConfig.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

### Dọn Sound instance bằng Sound.Ended:Once() qua AudioHelper
- **Ngày:** 12-08-2026 (cập nhật 17-08-2026)
- **Chi tiết:** `AudioHelper.PlaySpatialSound()` và `AudioHelper.Play2DSound()` tạo Sound instance động và kết nối `Sound.Ended:Once(function() Sound:Destroy() end)` kết hợp timeout fallback phòng thủ. Pattern này đảm bảo Sound tự dọn dẹp ngay khi phát xong, không sớm không muộn, loại bỏ hoàn toàn rò rỉ bộ nhớ âm thanh trên cả Server lẫn Client.
- **File liên quan:** [AudioHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [GuiHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/GuiHelper.lua), [ItemRewardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ItemRewardController.lua)

### Xử lý chuyển Spectator khi nhân vật chết hoặc thoát game giữa trận
- **Ngày:** 14-08-2026
- **Chi tiết:** Khi người chơi chết (Reset Character / Rơi khỏi map) hoặc thoát game (`PlayerRemoving`) trong phase InGame/Ready: Server gọi `FreezeService.EliminatePlayer` đặt trạng thái `"Dead"`, thu hồi Tool, xóa IceBlock, xóa `Team` attribute và kích hoạt `MatchEndSignal` nếu đội bị wipe. Người chơi chết được chuyển sang màn hình Spectator.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua), [MatchService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/MatchService.lua), [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua)

### Khóa cứng vị trí nhân vật bị đóng băng (Anchored HRP)
- **Ngày:** 14-08-2026
- **Chi tiết:** Đặt `HumanoidRootPart.Anchored = true` khi `FreezePlayer` để người chơi hoàn toàn đứng yên tại vị trí bị hit (kể cả trên không), ngăn nhân vật bị các player khác tông/đẩy đi do vật lý Roblox. Khôi phục `Anchored = false` khi `ThawPlayer` hoặc `ThawAll`.
- **File liên quan:** [FreezeService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/FreezeService.lua)

---

## Bug & biện pháp

### StudioAccessToApisNotAllowed
- **Ngày:** 05-06-2026
- **Vấn đề:** Không thể ghi dữ liệu vào DataStore khi chạy thử game trong Roblox Studio.
- **Nguyên nhân:** Mặc định Roblox Studio khóa quyền truy cập vào API dịch vụ đám mây để đảm bảo an toàn cho game đã publish.
- **Fix:** Đăng tải game lên Roblox (Publish to Roblox), mở Game Settings -> Security -> Gạt bật "Enable Studio Access to API Services" -> Save.
- **File liên quan:** [DataService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/DataService.lua)

### IcicleScript Raycast bị chặn bởi IceBlock
- **Ngày:** 05-06-2026
- **Vấn đề:** Khi swing Icicle Tool, tia Raycast có thể bị chặn bởi các IceBlock trong workspace thay vì xuyên qua để hit target thực sự.
- **Nguyên nhân:** `FilterDescendantsInstances` chỉ loại trừ character của local player, không loại trừ các IceBlock instance đang tồn tại trong workspace.
- **Fix:** Trước mỗi lần raycast, thu thập tất cả Part tên "IceBlock" trong `workspace:GetChildren()` và thêm vào danh sách exclude của `RaycastParams`.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### Lỗi gọi sai API va chạm của Workspace
- **Ngày:** 06-06-2026
- **Vấn đề:** Gặp lỗi `GetPartBoundsOverlap is not a valid member of Workspace` ở Client khiến script bị crash khi kích hoạt tool.
- **Nguyên nhân:** Roblox API không cung cấp hàm `workspace:GetPartBoundsOverlap()`.
- **Fix:** Thay thế bằng API chuẩn `workspace:GetPartsInPart(Hitbox, Params)` để thực hiện spatial query va chạm.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua)

### Hitbox không đi theo nhân vật khi di chuyển (Lỗi thiếu Weld)
- **Ngày:** 06-06-2026
- **Vấn đề:** Khi kích hoạt tool va chạm, mặc dù đứng sát đối thủ nhưng Client không phát hiện va chạm và đối thủ không bị đóng băng.
- **Nguyên nhân:** `Hitbox` của Tool trong Template (`ServerStorage.Icicles.Default`) không được hàn (weld) với `Handle`. Khi người chơi trang bị Tool, chỉ có `Handle` được gắn vào tay nhân vật, còn `Hitbox` bị rơi rớt hoặc đứng yên tại chỗ ở tọa độ ban đầu.
- **Fix:** Tạo `WeldConstraint` liên kết `Hitbox` sang `Handle` của Tool trong Template để `Hitbox` di chuyển theo nhân vật.
- **File liên quan:** `ServerStorage/Icicles/Default` (Roblox Studio)

### `GetMarkerReachedSignal` không fire — Workaround: `task.delay`
- **Ngày:** 02-07-2026 (cập nhật 17-08-2026)
- **Vấn đề:** Marker signal `HitStart`/`HitEnd` không bao giờ fire dù animation có marker đúng tên, đúng ID, đã publish. Print bên trong callback không xuất hiện. Animation vẫn chạy bình thường.
- **Nguyên nhân:** Chưa xác định chính xác. Đã thử: (1) Animation Marker trong Studio, (2) `Animator:LoadAnimation()` thay `Humanoid:LoadAnimation()` (deprecated), (3) Tạo animation mới, (4) Reset Roblox. Tất cả đều không giải quyết được.
- **Workaround hiện tại (Hướng B — đang dùng):** Dùng `task.delay(HitStartTime, ...)` và `task.delay(HitEndTime, ...)` với timing lưu trong `AnimationConfig` (per-skin). Hoạt động ổn định nhưng cần sync timing thủ công với animation khi sửa.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [AnimationConfig.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Config/AnimationConfig.lua)

### Độ trễ kích hoạt Tool ở lần bấm chuột đầu tiên
- **Ngày:** 14-08-2026 (cập nhật 17-08-2026)
- **Vấn đề:** Cú click chuột đầu tiên sau khi trang bị Tool không vung animation hoặc bị hoãn làm lỡ cửa sổ va chạm hit detection.
- **Nguyên nhân:** Asset Animation và Audio chưa được nạp vào bộ nhớ client (chưa preload), `Animator:LoadAnimation` tốn thời gian nạp ở lần đầu.
- **Fix:** Khởi tạo Sound Pool bằng `AudioHelper.CreateSoundPool()`, Preload audio và animation bằng `AudioHelper.PreloadAudios` & `AnimationHelper.PreloadAnimations`, kết hợp nạp sẵn `AnimationTrack` lên `Animator` qua `AnimationHelper.LoadTrack`.
- **File liên quan:** [IcicleScript.client.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/IcicleScript.client.lua), [AudioHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AudioHelper.lua), [AnimationHelper.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ReplicatedStorage/Shared/Tools/AnimationHelper.lua)

### Biểu tượng FrozenStatus không hiện trên ScoreBoard/HUD khi player chết hoặc out game
- **Ngày:** 14-08-2026
- **Vấn đề:** Khi player chết hoặc out game, ScoreBoard của các player khác không hiển thị biểu tượng đóng băng/loại của người đó.
- **Nguyên nhân:** Client check `(Data.State == "Frozen")` nên bỏ qua trạng thái `"Dead"`. Ngoài ra `PlayerRemoving` thiếu broadcast `UpdatePlayerState`.
- **Fix:** Đổi check thành `(Data.State == "Frozen" or Data.State == "Dead")` trên client và broadcast `UpdatePlayerState` với `State = "Dead"` khi `PlayerRemoving` trên server.
- **File liên quan:** [ScoreBoardController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/ScoreBoardController.lua), [PlayerStatusController.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/StarterPlayer/StarterPlayerScripts/Controllers/PlayerStatusController.lua), [SessionService.lua](file:///c:/Users/thuyl/OneDrive/Dokumente/THIEN_ANH_FOLDER/SuperFrozenState/FrozenState/src/ServerScriptService/Services/SessionService.lua)
