> Mục tiêu: Phát triển trạng thái, thông số người chơi trong trận đấu

Toàn bộ các gui chỉ xuất hiện trong gamestate Ready, InGame và GameOver sẽ nằm tại StarterGui/InGameGui
# Phase 1: Core
## PlayerStatus
> Thể hiện avatar của những người chơi tham gia trận đấu kể cả đồng minh và kẻ địch
### Cấu trúc:
Được đặt tại InGameGui/PlayerStatus (Frame), bên trong có cấu trúc như sau:
- Template (Folder): Chứa AvatarThumbnail (ImageLable) là template để hiển thị avatar của người chơi.
- AllyTeam/EnemyTeam (Frame) (đã có UIGridLayout cho thẩm mĩ): là nơi AvatarStatus được clone vào, nếu là đồng minh thì clone vào AllyTeam, ngược lại kẻ địch sẽ được clone vào EnemyTeam
### Chức năng:
Nếu AvatarStatus là đồng mình thì background được hiển thị sẽ có màu 009DFF, kẻ địch thì màu FF5151
Hình ành sẽ là Avatar Thumbnail HeadShot của người chơi

## Thêm:
PlayerStatus sẽ luôn hiển thị từ lúc bắt đầu, kể cả spectator (người không tham gia trận đấu) cũng sẽ hiển thị. Spectator luôn nhìn thấy Team 1 là xanh dương, Team 2 là đỏ
## ScoreBoard
> Cho phép người chơi theo dõi thông số của ta và địch
### Cấu trúc
Được đặt tại InGameGui/ScoreBoard (Frame), bên trong có cấu trúc như sau:
- Background, EnemyTeamLabel và AllyTeamLabel không cần quan tâm
- Template (Folder) chứa template của người chơi là PlayerStats (Frame) cần được clone với cấu trúc:
	- AvatarThumbnail (ImageLabel): Hình ành sẽ là Avatar Thumbnail HeadShot của người chơi
	- FrozenStatus (ImageLabel) cho biết người chơi có đang frozen hay không, nếu không thì ẩn (mặc định)
	- FreezesText/ThawsText (TextLabel) hiển thị thông số freezes và thaws của người chơi đó (mặc định là 0)
	- NameText hiển thị display name thay vì id name của người chơi
- AllyInfo (Frame) chứa thông số của đồng mình và có cấu trúc:
	- StatsLabel không cần quan tâm
	- StatsFrame (Frame) là Frame chính để clone PlayerStats vào nếu là đồng mình
- EnemyInfo (Frame) chứa thông số của kẻ địch và có cấu trúc:
	- StatsLabel không cần quan tâm
	- StatsFrame (Frame) là Frame chính để clone PlayerStats vào nếu là kẻ địch
- CloseButton (ImageButton) bấm để tắt ScoreBoard trong trường hợp trục trặc

Ngoài ra còn có InGameGui/ScoreBoardButton (ImageButton) để khi bấm sẽ hiển thị ScoreBoard
### Chức năng
Cho phép người chơi bật tắt ScoreBoard để theo dõi thông số, bất/tắt như sau:
- ScoreBoardButton khi người dùng là mobile hoặc muốn đè để bật, thả để tắt thủ công
- Với PC có thể bật bằng cách đè nút `ctrl` và thả để tắt
- Với console thì đè `R1` và thả để tắt (hãy bàn luận điểm này vì tôi không rành về console)
Khi được sắp đội thì clone PlayerStats vào AllyInfo/StatsFrame và EnemyInfo/StatsFrame và cập nhật hình ảnh, visible,...
Khi người chơi ở trạng thái frozen thì bật FrozenStatus
ScoreBoard chỉ cập nhật thông số người chơi của trận đấu đang diễn ra tức khi bắt đầu trận mới đều có freezes và thaws là 0

## AccoladesAnnouncement
Đặt tại InGameGui/AccoladesAnnouncement (TextLabel)
Đây đơn giản là một TextLabel hiển thị khi người chơi đạt được 3 danh hiệu đặc biệt là First Blood và Freezing/Thawing Spree, Last Stading là thành phần không hiển thị vì tính chất của nó
Chỉ thông báo đơn phương khi người chơi đạt được danh hiệu còn lại sẽ không thầy gì cả. Điều này không đồng nghĩa mọi danh hiệu đều được áp dụng, như first blood chỉ thông báo cho người đầu tiên freeze chứ không phải tất cả đều có first blood
Khi xuất hiện sẽ hiển thị kèm audio `96102213526905` với hiệu ứng như sau:
- được chia làm 2 phần là thực và ảo:
	- Thực sẽ zoom từ chữ nhỏ xíu thành kích thước mặc định (kéo dài .5 giây)
	- Ảo sẽ zoom từ chữ nhỏ xíu đến lớn hơn kích thước mặc định, tăng dần độ trong suốt đến khi kích thước đạt đỉnh thì được xem như biến mất. (kéo dài .7 giây)

Announcement sẽ biến mất sau 3 giây tính cả animation


## Lưu ý:
Các spectator sẽ không hiển thị các những gì bên trong InGameGui trừ những ngoại lệ tôi đề cập