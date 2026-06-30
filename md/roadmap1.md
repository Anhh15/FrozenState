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
- ChestList (Frame) chứa 1 ScrollingFrame (đã có UIGridLayout) là khu vực display chest sử dụng ChestTemplate tại ReplicatedStorage/Assets/Gui/ChestTemplate
	- ChestTemplate sẽ chứa ChestViewport (đã có CurrentCamera) display model chest từ ReplicatedStorage/Assets/Chests, Một Background không cần quan tâm đến và NameText hiển thị tên của chest.
- ChestPopUp (Frame) xuất hiện khi nhấn vào ChestTemplate tại ChestList, tại đây sẽ hiển thị thông tin vật phẩm và số tiền cần trả để mua 1 chest hoặc 3 chest, cấu trúc bao gồm
	- Background và Curtain không cần quan tâm đến
	- CloseButton (ImageButton) để tắt ChestPopUp
	- Buy1Button và Buy3Button (ImageButton), người chơi nhấn vào để mua số lượng tương ứng. Bên trong mỗi nút chứa BuyText (TextlLabel) hiển thị thông tin và số tiền (Buy 1: xxx và Buy 3: xxxx), số tiền tùy loại chest
	- ChestTemplate tương tụ như là ReplicatedStorage/Assets/Gui/ChestTemplate nhưng không clone mà điều chỉnh tên, model,... Theo chest mà người chơi lựa chọn.
	- ItemInfo sẽ chứa 1 ScrollingFrame hiển thị thông tin vật phẩm mà chest có xác suất xuất hiện, các ItemTemplate sẽ được clone từ ReplicatedStorage/Assets/Gui/ItemTemplate và điều chỉnh tương ứng, đồng thời cho mục DropRateText bên trong ItemTemplate visible để hiển thị phần trăm rơi của vật phẩm

Một người chơi không thể sở hữu 2 skin giống nhau nên nếu mở giống thì sẽ được hoàn trả tiền theo độ hiểm (càng hiếm thì hoàn trả càng nhiều theo phần trăm, nên có config để điều chỉnh) ví dụ rương 1000 khi mở rare sẽ hoàn trả 20% tức 200 tức là theo % giá tiền của rương đó

Khi mở sẽ có hoạt ảnh nhưng tạm thời bỏ qua mà hãy cho thẳng vật phẩm vào skin thuộc sở hữu của người chơi đó, tức là không có gì màu mè; nhấn buy là sở hữu vật phẩm ngay; không pop up, không amm thanh, không gì cả, chỉ đơn giản là đưa vật phẩm vào vật phẩm sở hữu của người chơi. Toàn bộ hoạt ảnh, âm thanh, pop up sẽ được thêm sau. Lý do việc này là game vẫn còn đang trong giai đoạn phát triển, việc thiết kế hoạt ảnh hiện tại sẽ ảnh hưởng đến tiến độ, các hiệu ứng sẽ được thêm vào những giai đoạn cuối. Hiện tại chỉ cần hiển thị tại chat là "A đã mở được \[skin\]" hoặc "A mở trùng \[skin\] (hoàn trả xxx)" bằng tiếng Anh 

Cập nhật nhỏ tại NavigationButton/Stats/MoneyStats/MoneyText để hiển số tiền mà người chơi sở hữu, Text sẽ thay đổi khi số tiền người chơi có thay đổi. Từ giờ gọi tiền là Cash

Model Chest được lưu tại ReplicatedStorage/Assets/Chestsx

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
# Phase 7: Quest
> Mục tiêu: Xây dựng hệ thống nhiệm vụ có tiến trình và phần thưởng

Đường dẫn đến gui: StarterGui/Menu/Quest (Frame)

Quest được bật khi nhấn StarterGui/NavigationButton/Button/Quest

Cấu trúc Gui:
- Như đường dẫn đã trình bày, Quest là một Frame trong ScreenGui Menu
- Background và MenuLabel không cần quan tâm
- CloseButton (ImageButton): khi nhấn sẽ tắt ẩn gui Quest
- QuestTemplates (Folder): Chứa template của nhiệm vụ, hiện tại chỉ có 1, có thể tương lại sẽ có thể có sự điều chỉnh hoặc thêm bớt
	- QuestTemplate (Frame): Frame được clone khi có nhiệm vụ. Bên trong QuestTemplate sẽ có cấu trúc sau:
		- Background không cần quan tâm đến
		- QuestText (TextLabel) hiển thị thông tin nhiệm vụ (thắng 10 trận, freeze 10 người,...)
		- ClaimButton (ImageButton): khi người chơi đã thực hiện đủ yêu cầu thì sẽ đổi hình (để placeholder) và cho phép người chơi nhấn để đổi thưởng đồng thời hiển thị RewardAnnouncement được nói ở phần sau
		- Reward (Frame): Frame chứa thông tin phần thưởng với Icon (ImageLabel) hiển thị icon của phần thưởng (tiền,...) và Amount (TextLabel) cho biết số lượng phần thưởng
		- ProgressBar (Frame) là một thanh dài hiển thị tiến trình cần đạt với bên trong có ProgressText (TextLabel) cho biết tiến trình cụ thể (ví dụ: 12/20), khi đạt đủ thì thay vì hiển thị 20/20 thì sẽ hiển thị DONE và Progress (Frame) có chiều cao (trục Y) tương tự Parent ProgressBar nhưng có màu khác và chiều dài thay đổi tùy thuộc vào tiến trình hiện tại của người chơi (ví dụ: 10/20 thì chiều dại sẽ bằng 1/2 ProgressBar)
- QuestList (SrollingFrame): Chứa thông tin của những nhiệm vụ hiện có của người chơi. Trong QuestList hiện tại rỗng, khi có nhiệm vụ sẽ clone QuestTemplate từ QuestTemplates đã nói phía trên
- TabConatainer (Frame) hiện tại chứa 2 tab (ImageButton) là DailyTab và MileStoneTab để hiển thị đúng với từng mục. Việc thay đổi sẽ dùng chung ScrollingFrame QuestList thay vì cần nhiều ScrollingFrame tương tự như Inventory hay Shop
- RewardAnnouncement (Frame) hiển thị thông tin phần thưởng nhận được khi người hơi claim nhiệm vụ. Cấu trúc bên trong gồm Background không cần quan tâm, Icon (ImageLabel) hiển thị Icon của phần thưởng và Amount (TextLabel) hiển thị số lượng của phần thưởng.
Quest sẽ bao gồm nhiệm vụ và tiến trình như đã trình bày tại cấu trúc gui, với mỗi quest sẽ có yêu cầu được tính dựa trên data của người chơi (thắng 10 trận, freeze 10 người). Để làm đa dạng nhiệm vụ thì sẽ thêm nhiều dữ liệu cho người chơi thay vì chỉ data hiện tại (freezes, thaws, spree, last stading,...) như thời gian chơi, số lần chiến thắng của mỗi map, số lần chiến thắng mỗi chế độ; những thông số này sẽ không đưa vào gui Profile (tức gui Profile không đụng đến) để người chơi không thể thấy mà chỉ đơn giản là lưu lấy dữ liệu thống kê. 
Phần thưởng hiện tại là tiền, sau này có thể thêm như kinh nghiệm level (hiện tại chưa có ý định thêm vào), vật phẩm đặc trưng chỉ có thể có qua nhiệm vụ.
Data mới cần lưu trữ cho hệ thông nhiệm vụ: thời gian chơi
Nên có config nhiệm vụ để điều chỉnh phần thường, số lượng phần thưởng, loại nhiệm vụ (cần chơi trong bao lâu, freezes bao nhiêu,...) và yêu cầu số lượng cần đạt cho nhiệm vụ. Daily và MineStone hoặc bất cứ loại nào mới được thêm sau này cần tách riêng

DailyTab sẽ hiển thị các nhiệm thường ngày được cập nhật mỗi 24 giờ bao gồm 5 nhiệm vụ khác được random từ bể nhiệm vụ (giả sử có 20 nhiệm vụ thì mỗi ngày lấy ngẫu nhiên 5 nhiệm vụ). Thời gian 24 giờ sẽ không theo khung giờ nào mà phụ thuộc vào người chơi; giả sử người chơi vào game lúc 13h26 theo giờ VN thì 24 giờ sẽ bắt đầu lúc đó và sẽ reset vào lần tiếp theo người chơi vào game sau 24 giờ (ví dụ vào game lúc 13h 23/6 tức hết thời gian vào 13h 24/6 nhưng 15h 26/6 người chơi vào thì vòng lặp tiếp theo sẽ bắt đầu lúc 15h 26/6). Khi người chơi hoàn thành và nhấn claim thì quest sẽ được loại bỏ 

MineStoneTab sẽ hiển thị các nhiệm vụ lặp đi lặp lại tức là khi hoàn thành nhiệm vụ; giả sử đạt 10 trận thắng thì khi người chơi claim nhiệm vụ sẽ tự đồng reset mà không biến mất.

RewardAnnouncement chỉ hiển thị khi người chơi claim quest và tồn tại trong 3 giây. hoạt ảnh là sẽ zoom lên kích thước hiện tại rồi sau 3 giây sẽ zoom nhỏ lại và ẩn đi

Toàn bộ âm thanh sẽ được thêm tại phase sau 

---

## Phase 8: Polish
> **Mục tiêu:** Hoàn thiện trải nghiệm âm thanh và hình ảnh.

id audio
swing audio 1 136455914086398
swing audio 2 134318072265347
swing audio 3 136610895235499

thaw audio 138690892117059
freeze audio 92048469072346

gui button click 7249903719
gui mouse enter 137872392480008
gui close button click 103307955424380

Nhạc lobby 1846271108
Nhạc InGame 1846271109
Nhạc InGame FrozenState 1846271110

id animation
swing animation 139026922747808
pose animation 139714014570733
### 8.1 Nhạc nền
cả 3 id audio nhạc nhạc đã được đề cập phía trên
Hệ thống cần đảm bảo khi người chơi không tham gia trận đấu sẽ có nhạc lobby, khi tham gia trận thì không có nhạc lobby mà thay vào đó là InGame hoạc FrozenState nếu đang trong giai đoạn đó.
ví dụ: có 3 người trong server, 2 người đang trong trận (chưa vào FrozenState) và 1 người ở lobby (không có trong trận) thì người ở lobby sẽ có nhạc lobby, 2 người trong trận sẽ có nhạc InGame. Tuy nhiên nếu người chơi đang ở lobby (spectator) spectate người trong trận thì cũng nghe được những gì mà người được theo dõi nghe thấy
### 8.2 animation và gameplay sfx
Khi vung Icicle sẽ sử dụng 'swing animation' cùng với đó là random 1 trong 3 'swing audio'
Khi người chơi bị đánh trúng (đóng băng) thì sẽ kích hoạt 'freeze audio' và người đó sẽ kích hoạt 'pose animation'
Khi người chơi được thaw thì sẽ kích hoạt 'thaw audio'

Hệ thống gameplay sfx cần có 2 tầng default và phần ghi đè. Mục đích là nếu người chơi sử dụng Icicle hay Block không có hiệu ứng riêng thì swing/freeze/thaw audio sẽ sử dụng mặc định (đã ghi phía trên), với các Icicle/Block đặc biệt thì sẽ có hiệu ứng âm thanh riêng biệt để tăng trải nghiệm
Tương tự áp dụng 2 tầng với animation với người bị đóng băng, không thể thay đổi animation của icicle vì sẽ làm mất cân bằng, do đó chỉ có thể thay thế animation khi người chơi đang bị đóng băng vì animation không ảnh hưởng gì đến hitbox của blox.
### 8.3 gui sfx

---
## Phase 9: Mở rộng
> **Mục tiêu:** Thêm các chế độ chơi đặc biệt.
- **Chaos Mode:** Tất cả là kẻ thù của nhau (free-for-all)
- **Multi-team Mode:** Chia thành 4 đội thay vì 2
- Xoay tua chế độ: cứ 2 round bình thường sẽ có 1 round đặc biệt
# Phase 10: Setting
> Mục tiêu: Hệ thống cài đặt cho phép người chơi điều chỉnh như tắt nhạc, tắt tiếng,...
