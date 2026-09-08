# Icon Generation Pipeline & Open Cloud Uploader

Quy trình tự động hóa 100% việc tạo Icon 2D trong suốt từ Model 3D trực tiếp trong Roblox Studio và tải lên Open Cloud.

---

## 1. Kiến trúc Hai Pha Độc Lập

Hệ thống được thiết kế tách biệt thành 2 pha hoàn toàn chuyên biệt:

```
[Pha 1: Tạo Icon & Kiểm duyệt Local]
Roblox Studio (Command Bar) ──(HTTP)──> Python Worker (studio_capture.py)
                                               │
                                               ▼
                                       GUI_FrozenState/Icon/Item/{Type}/{Id}.png
                                               │
                                               ▼
                                   [Dev xem & duyệt ảnh]
                                               │
                                               ▼
[Pha 2: Upload Lên Roblox & Sync Code]
Dev chạy: python tools/icon_pipeline/upload_icons.py
   │
   ├─ 1. Upload qua Roblox Open Cloud Assets API
   ├─ 2. Lấy assetId hợp lệ
   └─ 3. Tự động ghi đè vào src/ReplicatedStorage/Shared/Config/ItemRegistry.lua
```

---

## 2. Chuẩn Bị & Cài Đặt

### Bước 2.1: Cài đặt thư viện Python
Mở Terminal tại thư mục gốc của project:
```bash
pip install -r tools/icon_pipeline/requirements.txt
```

### Bước 2.2: Bật HTTP Service trong Roblox Studio
1. Mở place game trong Roblox Studio.
2. Vào **Home** > **Game Settings** > **Security**.
3. Bật **Allow HTTP Requests** -> Bấm **Save**.

---

## 3. Pha 1: Chụp Ảnh & Kiểm Duyệt Local

### Bước 3.1: Khởi động Python Worker
Mở một cửa sổ Terminal riêng và chạy:
```bash
python tools/icon_pipeline/studio_capture.py
```
Worker sẽ hiển thị:
```
[Worker] KHỞI CHẠY PYTHON STUDIO CAPTURE WORKER...
[Worker] Lắng nghe tại http://127.0.0.1:5000
[Worker] Thư mục lưu ảnh: .../SuperFrozenState/GUI_FrozenState/Icon/Item
```

### Bước 3.2: Chạy lệnh chụp trong Roblox Studio
1. Đảm bảo cửa sổ Roblox Studio đang mở rõ ràng trên màn hình (không bị thu nhỏ xuống taskbar).
2. Mở cửa sổ **Command Bar** (View > Command Bar).
3. Gõ lệnh để chạy:

- **Chụp toàn bộ item (Icicles và Blocks):**
  ```lua
  require(game.ReplicatedStorage.Shared.Tools.IconGenerator).Run()
  ```

- **Hoặc chỉ chụp một phân loại cụ thể:**
  ```lua
  require(game.ReplicatedStorage.Shared.Tools.IconGenerator).Run("Icicle")
  ```

- **Hoặc chỉ chụp test đúng 1 item:**
  ```lua
  require(game.ReplicatedStorage.Shared.Tools.IconGenerator).Run("Icicle", "Green")
  ```

Studio sẽ tự động dựng buồng chụp tại $Y = 100,000$, căn góc camera chuẩn theo `ViewportConfig.lua`, đổi nền đen/trắng và gửi tín hiệu cho Python worker.

### Bước 3.3: Kiểm duyệt ảnh đã tạo
Mở thư mục `SuperFrozenState/GUI_FrozenState/Icon/Item/` bên ngoài dự án. Bạn sẽ thấy các file ảnh PNG nền trong suốt chuẩn 512x512 tại:
- `SuperFrozenState/GUI_FrozenState/Icon/Item/Icicle/<Id>.png`
- `SuperFrozenState/GUI_FrozenState/Icon/Item/Block/<Id>.png`

Kiểm tra độ trong suốt, màu sắc, viền và góc nhìn của từng ảnh. Nếu cần điều chỉnh góc nhìn, chỉnh sửa file `src/ReplicatedStorage/Shared/Config/ViewportConfig.lua`.

---

## 4. Pha 2: Upload Lên Roblox & Cập Nhật ItemRegistry

Khi đã kiểm duyệt và hài lòng với chất lượng các ảnh trong `GUI_FrozenState/Icon/Item/`:

### Bước 4.1: Cấu hình Open Cloud API Key
Tạo file `tools/icon_pipeline/.env` với nội dung:
```env
ROBLOX_API_KEY=your_open_cloud_api_key_here
ROBLOX_CREATOR_ID=123456789
CREATOR_TYPE=User
```
*(Nếu là Group game, đổi `CREATOR_TYPE=Group` và điền Group ID vào `ROBLOX_CREATOR_ID`).*

> **Cách lấy API Key:** Truy cập [Roblox Creator Dashboard](https://create.roblox.com/dashboard/credentials) > Tạo API Key mới với quyền **Assets: Write**.

### Bước 4.2: Kiểm tra thử danh sách upload (Dry-Run)
```bash
python tools/icon_pipeline/upload_icons.py --dry-run
```

### Bước 4.3: Thực hiện Upload chính thức
```bash
python tools/icon_pipeline/upload_icons.py
```
Script sẽ tự động:
1. Upload từng file ảnh trong `GUI_FrozenState/Icon/Item/` lên Roblox.
2. Chờ Roblox cấp mã `assetId`.
3. Tự động ghi mã `rbxassetid://<assetId>` vào đúng entry trong `src/ReplicatedStorage/Shared/Config/ItemRegistry.lua`.
