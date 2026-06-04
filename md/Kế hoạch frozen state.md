# Mục tiêu
Tạo dựng cho chơi tối đa 16 người được chia đều cho 2 đội với mục tiêu là đóng băng toàn bộ đội còn lại để giành thắng cuộc, sau mỗi trận người chơi sẽ nhận được tiền thưởng để có thể mua trang phục cho các vật phẩm
# Khái niệm
**Freeze:** khi một người chơi đóng băng kẻ địch, đưa kẻ địch vào trạng thái bất động hoàn toàn, tạo ra block bao quanh kẻ địch
**Thaw:** Khi một người chơi cứu đồng đội khỏi trạng thái đóng băng cho phép vào lại cuộc chơi đồng thời phá bỏ lớp băng

**icicle:** vũ khi của người chơi, có thể mang trang phục.
**Block:** Các khối băng sử dụng để làm điểm nhấn, khi A đóng băng B thì Block mang trang phục của A sẽ bao quanh B
# Game State
Game State sẽ xuất hiện xuyên suốt quá trình chời game phía trên màn hình để hiển thị giai đoạn trận đấu (in game, intermission, ready,...)
Các giai đoạn: 
- **Intermission:** Kéo dài 20 giây, đây là giai đoạn để người chơi xem thống kê từ trận đấu trước, thay đổi trang phục hoặc làm việc gì đó khác để chờ trận đấu tiếp theo
- **Setup:** Không có thời gian cố định, giai đoạn loadmap vào workspace, chia đội; là giai đoạn chuẩn bị trước khi trận đấu bắt đầu. (Giai đoạn này được ẩn, tức là gui thời gian sẽ đứng yên ở 00:00 và gamestate sẽ nằm ở intermission cho đến khi setup toàn bộ và sẵn sàng vào giai đoạn ready)
- **Ready:** 3 Giây, ngươi chơi sẽ được dịch chuyển đến vị trí tương ứng trên bản đồ và đứng cố định cho đến khi giai đoạn này kết thúc
- **In game:** keos dài tối đa 180 giây, đây là giai đoạn chủ chôt nơi 2 bên sẽ lao vào chiến đấu, nếu một bên bị đóng băng hoàn toàn thì đội còn lại sẽ chiến thắng và kết thúc giai đoạn sớm, nếu không có bên nào bị đóng băng hoàn toàn và hết 180 giây thì sẽ xem xét các điều kiện sau:
	- bên nào còn nhiều người sống sót hơn
	- nếu vần hòa thì bên nào nhiều tổng freeze và thaw hơn
	- Nếu vần hòa thì xét random, không thể xảy ra hòa
- **Game Over:** Kéo dài 6 giây, sau khi hết 2 giây đầu tiên, toàn bộ người chơi sẽ hiển thị thông tin thắng hoặc thua cùng với đó toàn bộ người bị đóng băng sẽ được thaw
- Quay trở lại Intermission và hiển thị thống kể từ trận đấu vừa xảy ra

- **Frozen State:** Giai đoạn đặc biệt, nằm bên trong giai đoạn in game, đây là giai đoạn người chơi chỉ có thể freeze mà không thể thaw đồng minh

# GUI
**Lưu ý:** Cấu trúc Gui sẽ được tôi cập nhật khi đến các phase cụ thể, toàn bộ thiết kế và cấu trúc gui sẽ do tôi quản lý

**Game State:** Một khung nhỏ phía trên màn hỉnh hiển thị các giai đoạn trận đấu và thời gian cho mỗi gia đoạn đó

**Game Statistic:** Thống kê trận đấu người chơi vừa tham gia bao hồm 2 bảng:
- **Team Won:** Thông báo đội thắng cuộc cùng top 3 người chơi có công lớn nhất toàn đội
- Game Stats: Thông báo thắng/thua của bán thân cùng chỉ số freeze/thaw có được cũng như tổng tiền thưởng và số tiền cho mỗi chỉ số

**NavigationButton:** Các button để người chơi có thể bấm và mở các menu, các icon sẽ kết nối với gui menu tương ứng
- **Spectate**
- **Inventory**
- **Shop**
- **Quests**
- **Setting**
- **Profile**
- **Money**

**Menu:** Các giao diện cho để người chơi tương tác
- **Profile:** Thống kê thông tin người chơi xuyên suốt từ lúc tham gia như lượt freeze/thaw, tên và giao diện người chơi, trang phục icicle và block đang sử dụng
- **Inventory:** Hiển thị những trang phục icicle và block mà người chơi sở hữu và có thể trang bị
- **Shop:** hiển thị vật phầm mà người chơi có thể mua cùng với đó là các gamepass và vật phẩm sử dụng robux để mua
- **Quests:** Hiển thị các nhiệm vụ hằng ngày, nhiệm vụ milestone cùng với đó là phần thưởng đăng nhập và phân thưởng thời gian chơi daily
- **Spectator:** Cho phép người chơi đang không tham gia vào trận đấu có thể thoi dõi người trong trận.
- **Setting:** Cài đặt cơ bản như afk, tắt nhạc,...
- **Money:** Mở một mục của Gui shop đưa trực tiếp đến nơi cho phép mua tiền tệ in game

# Lưu ý:
Toàn bộ gui, model sẽ do tôi đảm nhiệm, bạn chỉ có nhiệm vụ script để cho tựa game có thể hoạt động trơn tru
# Phase 0: Xây dựng Foudation
> **Mục tiêu:** Xây dựng một nền móng kiến trúc dễ dàng thêm thắt và dễ bảo trì cho trò chơi, GUI liên quan đến game flow
# Phase 1: Core Gameplay
> **Mục tiêu:** Nền móng gameplay cơ bản nhất; không có âm thanh, animation và menu gui

### 1.1 Tool: Vũ khí của người chơi gọi là Icicle
Chỉ được cấp cho người chơi khi vào trận tức gamestate ingame
Tương lại tool sẽ có khin khác nhau, tạm thời chỉ là một tool thô sơ, sau này sẽ được điều chỉnh tại các phase tương lai
Tool sẽ được kích hoạt khi nhấn vào màn hình
Nếu hitbox chạm kẻ địch thì freeze, đồng mình thì thaw
### 1.2 Mechanic: Freeze và thaw
Mechanic tổng bộ của việc freeze kẻ địch và thaw đồng minh
Freezing Spree: khi người chơi freeze kẻ địch liên tiếp 3 lần mà không bị đóng băng sẽ được tính là một spree, khi đạt spree hoặc đóng băng thì sẽ bị kéo về 0
thawing Spree: tương tự freezing spree nhưng là giải cứu đồng đội
### 1.3 Player State: Trạng thái của người chơi
Người chơi sẽ có 3 trạng thái khác nhau: Frozen tức bị đóng băng, Normal tức có thể đi lại bình thường, Dead tức người chơi không ở bên trong trận đấu
Xử lý cho từng state khác nhau
### 1.4 Chia đội ở giai đoạn setup
Người chơi sẽ được chia ngẫu nhiên vào 2 đội với số lượng hơn kém tối đa 1 người
Kẻ địch sẽ hiện highlight đỏ, động minh màu xanh dương nhưng bản thân sẽ không hiển thị màu

### 1.5 Match Flow
**những vấn đề lưu ý:**
- Gui gamestate luôn cập nhật tình hình và thời gian trò chơi
- Yêu cầu tối thiểu 2 người chơi, nếu không đủ số lượng thì sẽ luôn ở intermission và thời gian là thời gian tối đa của intermission
- Khi người chơi vào trong lúc trận đấu đang diễn ra sẽ không thể tham gia mà chỉ có thể quan sát
- Khi người chơi thoát khi đã phân đội thì người này sẽ được tính là frozen

**Intermission:** Kéo dài 20 giây, đây là giai đoạn để người chơi xem thống kê từ trận đấu trước, thay đổi trang phục hoặc làm việc gì đó khác để chờ trận đấu tiếp theo
**Setup:** Không có thời gian cố định, giai đoạn clone map ngẫu nhiên từ ServerStorage vào workspace, chia đội; là giai đoạn chuẩn bị trước khi trận đấu bắt đầu. (Giai đoạn này được ẩn, tức là gui thời gian sẽ đứng yên ở 00:00 và gamestate sẽ nằm ở intermission cho đến khi setup toàn bộ và sẵn sàng vào giai đoạn ready)
**Ready:** 3 Giây, ngươi chơi sẽ được dịch chuyển đến vị trí tương ứng trên bản đồ, được đưa trang bị và đứng cố định cho đến khi giai đoạn này kết thúc
**In game:** kéo dài tối đa 180 giây, đây là giai đoạn chủ chôt nơi 2 bên sẽ lao vào chiến đấu, nếu một bên bị đóng băng hoàn toàn thì đội còn lại sẽ chiến thắng và kết thúc giai đoạn sớm, nếu không có bên nào bị đóng băng hoàn toàn và hết 180 giây thì sẽ xem xét các [điều kiện chiến thắng] sau:
	Bên nào còn nhiều người sống sót hơn, nếu một bên có tổng thành viên ít hơn tổng bên còn lại thì bên đó sẽ được cộng một người sống sót cho công bằng
	Nếu vẫn hòa thì bên nào nhiều tổng freeze và thaw hơn sẽ thắng
	Nếu vẫn hòa thì xét random, không thể xảy ra hòa
**Game Over:** Kéo dài 6 giây, sau khi hết 2 giây đầu tiên, toàn bộ người chơi sẽ hiển thị thông tin thắng hoặc thua cùng với đó toàn bộ người bị đóng băng sẽ được thaw
Quay trở lại Intermission

**Frozen State:** Giai đoạn đặc biệt, nằm bên trong giai đoạn in game, đây là giai đoạn người chơi chỉ có thể freeze mà không thể thaw đồng minh đồng thời toàn bộ highlight sẽ xuất hiện xuyên vật thể
### 1.6 GUI GameState:

### 1.7 GUI ingame, có thể cân nhắc để vào phase sau

### 1.8 GUI Game Statistic, có thể cân nhắc để vào phase sau

# Phase 2: Dữ liệu
### 2.1: Lưu trữ
Lưu trữ các thông số xuyên suốt
- `Money` (Tiền tệ)
- `TotalFreezes` (Tổng số lần đóng băng)
- `TotalThaws` (Tổng số lần giải cứu)
- `TotalFreezingSpree` (Tổng số lần giải cứu)
- `TotalThawingSpree` (Tổng số lần giải cứu)
- `TotalFirstBlood` (Tổng số lần giải cứu)
- `TotalLastStanding` (Tổng số trận thắng)
- `OwnedCosmetics` (Danh sách vật phẩm đã sở hữu)
- `EquippedIcicle` và `EquippedIceBlock` (Vật phẩm đang trang bị)
### 2.2: Gui

# Phase 3: Item
> Mục tiêu: Xây dựng hệ thông icicle và block đồng nhất

Cấu trúc icicle và block đã được xây dựng từ ban đầu
### 3.1 Xây dựng một cấu trúc chung cho toàn bộ item
Những thuộc tính được sử dụng chung cho mọi item để đồng nhất để có thể hiển thị gui, load tool mượt mà:
- ID
- Name (tên): Tên của item
- Rarity (độ hiếm): Độ hiếm của vật phấm (common, rare, epic,...), mỗi độ hiếm sẽ có một màu khác nhau nhằm hiển thị trên gui
- Hiển thị gui, tạo một viewport 3d vật phẩm làm icon cho các gui như profile, shop, inventory thay vì import hình ảnh
- Path dẫn đến vật phẩm

# Phase 4: Shop và inventory
### 4.1 Đồng bộ hóa
Đồng bộ hóa dữ liệu trang bị từ PlayerData: Lưu danh sách đã sở hữu
Trạng thái trang bị hiện item hiện tại
### 4.2 Hệ thông inventory và item trang bị
Đồng bộ dữ liệu danh sách vật phẩm đã sở hữu lên GUI.
-  Viết logic trang bị (Equip) trên Server: Khi nhận tín hiệu từ Client, kiểm tra quyền sở hữu, cập nhật dữ liệu người chơi, và thông báo thành công.
-  Viết logic áp dụng skin (Spawn/Weld):
	- Khi người chơi spawn: Tự động clone model `EquippedIcicle` đã lưu và weld vào Handle vô hình của Tool.
	- Khi người chơi A đóng băng người chơi B: Đọc skin khối băng đang trang bị của **Người chơi A (attacker)** và tạo khối băng mang skin đó bao quanh **Người chơi B (victim)**.
### 4.3 Hệ thống shop
Shop sẽ theo hệ thống mở rương gacha, cố gắng minh bạch nhất có thể để không bị xếp vào cờ bạc trá hình theo pháp luật Việt Nam
Toàn bộ item trong rương phải có tỉ lệ mở trúng
Cơ chế mở rương, khi mua người chơi sẽ nhận được được vật phẩm ngẫu nhiên đã được chia tỉ lệ từ trước
Tích hợp animation viewport từ riêng, sau đó là một hàng vật phẩm được xoay tạo tính hồi hộp cho người
### 4.4 Hệ thống nhiệm vụ (tạm không cần quan tâm)
Hệ thống sẽ bao gồm nhiều loại nhiệm vụ khác nhau
- Nhiệm vụ hàng ngày: Mỗi ngày sẽ có nhiệm vụ ngẫu nhiên (reset mỗi 24h)
- Đăng nhập hằng ngày: trong một tháng đăng nhập mỗi ngày thường xuyên sẽ có thưởng càng lớn (reset mỗi tháng)
- Nhiệm vụ thời gian mỗi ngày: mỗi ngày sẽ có các cột mốc thời gian, người chơi chơi càng lâu thì thưởng càng lớn, reset mỗi 24h
- Nhiệm vụ đường dài: một nhiệm vụ khá dài để có được phàn thưởng (1000 freeze, 1000 thaw,...)

## Phase 5: Hoàn thiện
### 5.1 · Animations
Animation vung Icicle chiến đấu (Swing).
Animation/Hiệu ứng khi nhân vật bị đóng băng (bị khóa tư thế đứng).
### 5.2 · Sound Effects (SFX)
Âm thanh vung Icicle
Âm thanh đánh trúng mục tiêu (freeze/thaw).
Âm thanh hình thành khối băng (shattering ice) và phá vỡ khối băng (cracking/breaking).
Âm thanh click nút GUI, âm thanh mở rương gacha.
Âm thanh đặc biệt khi đạt Freeze Spree hoặc kích hoạt Last Standing.
### 5.3 · Background Music (BGM)
Nhạc nền tại Lobby.
Nhạc nền khi ở trong trận (In-Game).
Nhạc nền giai đoạn frozen state

# Phase 6: thêm
Thêm các chế độ đặc biệt, Mỗi chế độ sử dụng các map riêng biệt không trùng với chế độ thường
- Choas: tất cả là kẻ thủ của nhau
- Multi team: thay vì 2 thì được chia thành 4 đội

Tích hợp xoay tua chế độ: cứ mỗi 2 round bình thường sẽ đến 1 round đặc biệt