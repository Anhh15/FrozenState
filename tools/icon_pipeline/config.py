# config.py
# Cấu hình tập trung cho Python Local Worker của Icon Generation Pipeline
# Loại bỏ hoàn toàn hardcode các thông số kỹ thuật

import os
from pathlib import Path

# Thư mục gốc của repository
ProjectRoot = Path(__file__).resolve().parent.parent.parent

# Cấu hình Flask Server
ServerHost = "127.0.0.1"
ServerPort = 5000

# Thư mục lưu trữ ảnh PNG trong suốt xuất ra
OutputDir = ProjectRoot / "renders"

# Độ phân giải đích của Icon (Vuông 512x512)
TargetResolution = (512, 512)

# Từ khóa tìm kiếm tiêu đề cửa sổ Roblox Studio trên Windows
StudioWindowTitleKeyword = "Roblox Studio"

# Cấu hình thuật toán Dual-Shot Matte & Khử nhiễu
AlphaThreshold = 0.02          # Ngưỡng Alpha coi là nền trong suốt hoàn toàn
DifferenceMinThreshold = 30    # Ngưỡng sai phân RGB nhận diện vùng Viewport giữa Black và White frame
CropPaddingFactor = 1.1        # Hệ số đệm khi crop khung hình bao quanh vật phẩm
