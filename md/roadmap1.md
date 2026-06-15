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
---
# Phase 5: Shop
> Mục Tiêu: Hệ thống shop cho phép người chơi mua các rương gacha vật phẩm
---
# Phase 6: Spectate
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