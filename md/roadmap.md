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
- **1.8** GUI PlayerData (sync từ Persistent DataStore)

---

## Phase 2: Item System
> **Mục tiêu:** Xây dựng hệ thống Icicle và Block đồng nhất.

- Cấu trúc chung Item: `ID`, `Name`, `Rarity`, `Path`
- Spawn skin Icicle theo `EquippedIcicle` của người chơi
- Spawn Block theo skin của attacker khi freeze

---

## Phase 3: Shop & Inventory
> **Mục tiêu:** Hệ thống sở hữu và mua sắm vật phẩm.

- Inventory GUI + Equip logic
- Shop Gacha system (minh bạch tỉ lệ)
- *(Optional)* Quest system

---

## Phase 4: Polish
> **Mục tiêu:** Hoàn thiện trải nghiệm âm thanh và hình ảnh.

- Animation: Swing (Icicle), Freeze pose
- SFX: hit, freeze, thaw, spree, UI, gacha
- BGM: Lobby, InGame, Frozen State

---

## Phase 5: Mở rộng
> **Mục tiêu:** Thêm các chế độ chơi đặc biệt.

- **Chaos Mode:** Tất cả là kẻ thù của nhau (free-for-all)
- **Multi-team Mode:** Chia thành 4 đội thay vì 2
- Xoay tua chế độ: cứ 2 round bình thường sẽ có 1 round đặc biệt
