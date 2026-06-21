# FrozenState — Roadmap
---
## Phase 0: Foundation
> **Mục tiêu:** Xây dựng hạ tầng kiến trúc làm nền móng cho toàn bộ các phase sau. Không chứa gameplay logic.
- Module / Service architecture
- Config (tham số chung toàn game)
- Remote Events / Functions (khai báo sẵn cho các phase sau)
- Persistent DataStore
  - Schema + Load/Save: `Money`, `TotalFreezes`, `TotalThaws`, `TotalFreezingSpree`, `TotalThawingSpree`, `TotalFirstBlood`, `TotalLastStanding`, `OwnedCosmetics`, `EquippedIcicle`, `EquippedIceBlock`
---
## Phase 1: Core Gameplay
> **Mục tiêu:** Nền móng gameplay cơ bản nhất; không có âm thanh, animation và menu GUI.
- Session Data (dữ liệu tạm trong trận)
- **1.1** Tool Icicle (thô sơ)
- **1.2** Freeze / Thaw mechanic + Spree (Freezing Spree, Thawing Spree)
- **1.3** Player State: `Normal`, `Frozen`, `Dead`
- **1.4** Team Assignment + Highlight (đỏ/xanh)
- **1.5** Match Flow
  - `Intermission` → `Setup` → `Ready` → `InGame` → `GameOver` → (quay lại `Intermission`)
  - **Frozen State:** Sub-phase trong InGame, kích hoạt khi còn 45 giây
- **1.6** GUI GameState
- **1.7** GUI Game Statistic
---
## Phase 2: Item System
> **Mục tiêu:** Xây dựng hệ thống Icicle và Block đồng nhất.
- Cấu trúc chung Item: `ID`, `Name`, `Rarity`, `Path`
- Spawn skin Icicle theo `EquippedIcicle` của người chơi
- Spawn Block theo skin của attacker khi freeze
- Hệ số đồng nhất như rarity Common màu trắng, Rare màu lam,... (theo Hex)
- Các model Block và Icicle sẽ được chứa trong các folder rieegns ServerStorage/Icicles, ServerStorage/Blocks
---
## Phase 3:  Inventory
> **Mục tiêu:** Hệ thống inventory
- Cấu trúc Frame Item:
	- Mỗi Frame sẽ luôn chứa Background (ImageLabel) phụ thuộc vào Rarity của item (Icicles/Block) đó, điều này chỉ nhầm mục đích thẩm mĩ khi các item hiêm sẽ có background chi tiết và đầu tư hơn
	- Layer trên background sẽ là ViewportFrame để display Item đó, tránh việc phải tạo icon cho từng item một
	- Layer cuối đơn giản là toàn bộ tên item, rarity, nói chung là các text/thông tin item. RarityText sẽ có màu phụ thuộc vào rarity
	- Như toàn bộ các Gui khác, toàn bộ thiết kế gui này sẽ do tôi đảm nhận
- Cấu trúc GUI:
	- MenuLabel và Background không cần quan tâm
	- CloseButton để tắt Inventory
	- TabContainer: Sẽ chứa 2 nút bấm để hiển thị 2 mục khác nhau là Icicles và Blocks
	- ItemList sẽ chứa một ScrollingFrame, bên trong ScrollingFrame sẽ chứa ItemFrame (đã được trình baỳ bên trên)
	- ItemSelection sẽ luôn được hiển thị, khi người chơi nhấn vào ItemFrame thì sẽ biểu thị tại đây để người chơi có thể xem rõ hơn, bên trong ItemSelection sẽ có ItemViewport để hiển thị vật phẩm tưởng tụ ItemFrame, đồng thời có EquipButton (bấm vào thì người chơi sẽ trang bị skin này)
- Inventory GUI
- StarterGui/Menu/Inventory sẽ được mở khi bấm vào StarterGui/Navigationbutton/Button/Inventory
**Lưu ý:** Frame Item sẽ xuất hiện không chỉ trong Inventory Gui mà còn có gui Shop, Gui profile,...
Vấn đề cần bàn luận: Do Background của ItemFrame sẽ phụ thuộc vào rarity của item (rare màu xanh, epic màu cam,...) thì nên lưu trữ vào một nơi chứa và clone vào; hay thay đổi tùy biến Background và chỉ sử dụng duy nhất một Frame?

---
# Phase 4: Profile
> Mục tiêu: Hiện thị Gui profile của người chơi, cho phép theo dõi các thông số cá nhân

Cấu trúc Gui:
- MenuLabel là Frame cho người chơi biết đang ở menu gì nên không cần quân tâm đến frame này
- PlayerInfo hiển thị thông tin cá chân của người chơi, hiện tại có 2 phần chính là PlayerViewport để hiển thị avatar cho người chơi hoạt động tương tự Gui GameStatistic tại phase 1 và PlayerNameText đơn giản tên của người chơi và id (ví dụ: Max (@Max123))
- ItemList hiển thị skin mà người chơi đang mang (Icicles và Blocks), bên trong đã có sẵn UIGridLayout, chỉ cần clone ItemTemplate vào và hiển thị skin người chơi đang sử dụng.
- PlayerStats hiển thị thông số người chơi xuyên suốt từ lúc bắt đầu chơi; bên trong sẽ có 2 Frame: 
	- GameWins: Thành phần duy nhất cần chỉnh sửa là ValueText cho biết người chơi đã thắng được tổng cộng bao nhiêu trận đấu
	- Stats: Bên trong Stats sẽ chứa các Frame nữa như Freezes, Thaws, FirstBlood, ThawingSpree,... Bên trong mỗi Frame nhỏ này sẽ chứa 2 giá trị là NameText  và ValueText; tương tự frame GameWins chỉ cần thay đổi ValueText tương ứng với thông số của người chơi
- CloseButton: Tắt Gui
- Background: Không cần quan tâm
Gui Sẽ Visible khi ấn vào StarterGui/NavigationButton/Button/Profile

---
# Phase 5: Shop
> Mục Tiêu: Hệ thống shop cho phép người chơi mua các rương gacha vật phẩm

Đường dẫn với Shop StarterGui/Menu/Shop

Shop sẽ được bật khi nhấn StarterGui/NavigationButton/Button/Shop

Cấu trúc Gui:
- CloseButton: Bấm để tắt Shop gui
- TabContainer: Chứa 2 ImageButton Blocks và Icicles, để chuyển sang mua skin cho vật phẩm tương ứng
- MenuLabel và Background đơn giản là hiện thông tin, không cần quan tâm đến
- ChestList (Frame) chứa 1 ScrollingFrame (đã có UIGridLayout) là khu vực display chest sử dụng ChestTemplate tại ReplicatedStorage/Asset/Gui/ChestTemplate
	- ChestTemplate sẽ chứa ChestViewport (đã có CurrentCamera) display model chest từ ReplicatedStorage/Assets/Chests, Một Background không cần quan tâm đến và NameText hiển thị tên của chest.
- ChestPopUp (Frame) xuất hiện khi nhấn vào ChestTemplate tại ChestList, tại đây sẽ hiển thị thông tin vật phẩm và số tiền cần trả để mua 1 chest hoặc 3 chest, cấu trúc bao gồm
	- Background và Curtain không cần quan tâm đến
	- CloseButton (ImageButton) để tắt ChestPopUp
	- Buy1Button và Buy3Button (ImageButton), người chơi nhấn vào để mua số lượng tương ứng. Bên trong mỗi nút chứa BuyText (TextlLabel) hiển thị thông tin và số tiền (Buy 1: xxx và Buy 3: xxxx), số tiền tùy loại chest
	- ChestTemplate tương tụ như là ReplicatedStorage/Asset/Gui/ChestTemplate nhưng không clone mà điều chỉnh tên, model,... Theo chest mà người chơi lựa chọn.
	- ItemInfo sẽ chứa 1 ScrollingFrame hiển thị thông tin vật phẩm mà chest có xác suất xuất hiện, các ItemTemplate sẽ được clone từ ReplicatedStorage/Asset/Gui/ItemTemplate và điều chỉnh tương ứng, đồng thời cho mục DropRateText bên trong ItemTemplate visible để hiển thị phần trăm rơi của vật phẩm

Một người chơi không thể sở hữu 2 skin giống nhau nên nếu mở giống thì sẽ được hoàn trả tiền theo độ hiểm (càng hiếm thì hoàn trả càng nhiều theo phần trăm, nên có config để điều chỉnh) ví dụ rương 1000 khi mở rare sẽ hoàn trả 20% tức 200 tức là theo % giá tiền của rương đó

Khi mở sẽ có hoạt ảnh nhưng tạm thời bỏ qua mà hãy cho thẳng vật phẩm vào skin thuộc sở hữu của người chơi đó, tức là không có gì màu mè; nhấn buy là sở hữu vật phẩm ngay; không pop up, không amm thanh, không gì cả, chỉ đơn giản là đưa vật phẩm vào vật phẩm sở hữu của người chơi. Toàn bộ hoạt ảnh, âm thanh, pop up sẽ được thêm sau. Lý do việc này là game vẫn còn đang trong giai đoạn phát triển, việc thiết kế hoạt ảnh hiện tại sẽ ảnh hưởng đến tiến độ, các hiệu ứng sẽ được thêm vào những giai đoạn cuối

Cập nhật nhỏ tại NavigationButton/Stats/MoneyStats/MoneyText để hiển số tiền mà người chơi sở hữu, Text sẽ thay đổi khi số tiền người chơi có thay đổi. Từ giờ gọi tiền là Cash

Model Chest được lưu tại ReplicatedStorage/Asset/Chestsx

Khi di chuyển bằng các nút trong Tabcontainer thì ScrollingFrame cũng phải chuyển theo. Ví dụ: đang ở Icicles thì Shop/ChestList/ScrollingFrame nên hiển thị rương chứa các Icicles, với Blocks cũng tương tự nhưng là rương và vật phẩm cho Blocks. Ở đây sẽ không có 2 ScrollingFrame mà thay vào đó là một ScrollingFrame để clear và clone lại các chest

Nếu ChestPopUp đang mở nhưng ngươi chơi tương tác với TabContainer hoặc đóng cả Shop thì thực hiện việc clean ChestPopUp như cách nhấn CloseButton tại ChestPopUp
# Phase 6: Spectate
> Mục tiêu: Tạo cơ chế cho phép những người đang không tham gia vào trận đấu có thể quan sát người chơi
> Ý tưởng: Tạo một vòng lặp, khi người chơi không tham gia trận đấu bắt đầu quan sát thì sẽ hướng camera vào người chơi đó (giống như đang điều camera người chơi nhưng focus vào người đang quan sát), có 2 nút bấm để có thể quan sát người tiếp theo hoặc quay lại người trước trong vòng lặp

Cấu trúc Gui:
- Path: StarterGui/Menu/Spectate
- Để tắt Gui thì CloseButton (ImageButton)
- NextButton (ImageButton) được sử đụng đến quan sát người tiếp theo trong vòng lặp, BackButton tương tự nhưng đi ngược về phía sau
- PlayerName (Frame) chỉ cần quan tâm đến PlayerNameText (TextLabel) bên trong, đây sẽ display tên và id của người đang quan sát (ví dụ: Max (@Max123))

Chế độ Spectate sẽ được bật khi nhấn vào Starter/NavigationButton/Spectate

Khi Spectate này được bật thì tương tự với toàn bộ Gui trong Starter/Menu là sẽ tắt các Frame còn lại, đồng thời ần toàn bộ gui thuộc Starter/NavigationButton

Thông tin thêm:
- nếu đang quan sát 1 người chơi nhưng bị đóng băng/out game thì lập tức chuyển sang người chơi khác
- Chỉ khi trong phase InGame, chỉ người không tham gia vào trận đấu hiện tại (ở lobby, mới vào server, không được phân vào team nào)

---
## Phase 7: Polish
> **Mục tiêu:** Hoàn thiện trải nghiệm âm thanh và hình ảnh.
- Animation: Swing (Icicle), Freeze pose
- SFX: hit, freeze, thaw, spree, UI, gacha
- BGM: Lobby, InGame, Frozen State
---
## Phase 8: Mở rộng
> **Mục tiêu:** Thêm các chế độ chơi đặc biệt.
- **Chaos Mode:** Tất cả là kẻ thù của nhau (free-for-all)
- **Multi-team Mode:** Chia thành 4 đội thay vì 2
- Xoay tua chế độ: cứ 2 round bình thường sẽ có 1 round đặc biệt
# Phase 9: Setting
> Mục tiêu: Hệ thống cài đặt cho phép người chơi điều chỉnh như tắt nhạc, tắt tiếng,...
# Phase 10: Quest
> Mục tiêu: Xây dựng hệ thống quest