# studio_capture.py
# Python Local Worker cho Icon Generation Pipeline
# Lắng nghe HTTP từ Roblox Studio, chụp màn hình và thực thi Dual-Shot Difference Matte

import os
import sys
import ctypes
from pathlib import Path

# Cấu hình UTF-8 cho Windows Console tránh lỗi charmap encoding
if sys.platform == "win32":
	try:
		sys.stdout.reconfigure(encoding="utf-8")
		sys.stderr.reconfigure(encoding="utf-8")
	except Exception:
		pass

from flask import Flask, request, jsonify
import numpy as np
from PIL import Image, ImageGrab

# Nạp cấu hình tập trung
import config

# =========================================================
# KHỞI TẠO WINDOWS HIGH-DPI AWARENESS
# =========================================================

def InitializeDpiAwareness():
	"""Đảm bảo tọa độ bắt cửa sổ chính xác từng pixel trên màn hình có scale DPI (125%, 150%)."""
	try:
		ctypes.windll.shcore.SetProcessDpiAwareness(2) # Per-monitor DPI aware
	except Exception:
		try:
			ctypes.windll.user32.SetProcessDPIAware()
		except Exception:
			pass

InitializeDpiAwareness()

# =========================================================
# QUẢN LÝ CỬA SỔ & VIEWPORT DETECTION
# =========================================================

def FindRobloxStudioWindow():
	"""Tìm tọa độ cửa sổ Roblox Studio trên màn hình."""
	try:
		import win32gui
		FoundHwnd = None
		FoundRect = None

		def EnumWindowsCallback(Hwnd, Extra):
			nonlocal FoundHwnd, FoundRect
			if win32gui.IsWindowVisible(Hwnd):
				Title = win32gui.GetWindowText(Hwnd)
				if config.StudioWindowTitleKeyword.lower() in Title.lower():
					FoundHwnd = Hwnd
					FoundRect = win32gui.GetWindowRect(Hwnd)
					return False
			return True

		try:
			win32gui.EnumWindows(EnumWindowsCallback, None)
		except Exception:
			pass # EnumWindows stops when callback returns False

		if FoundRect and (FoundRect[2] > FoundRect[0]) and (FoundRect[3] > FoundRect[1]):
			return FoundRect
	except ImportError:
		pass

	# Fallback qua pygetwindow nếu pywin32 chưa cài
	try:
		import pygetwindow as gw
		Windows = gw.getWindowsWithTitle(config.StudioWindowTitleKeyword)
		if Windows:
			TargetWin = Windows[0]
			return (TargetWin.left, TargetWin.top, TargetWin.right, TargetWin.bottom)
	except Exception:
		pass

	return None

def CaptureStudioWindow(WindowRect=None):
	"""Chụp lại vùng cửa sổ Roblox Studio hoặc toàn bộ màn hình nếu không tìm thấy."""
	if WindowRect:
		# ImageGrab.grab hỗ trợ tham số bbox=(left, top, right, bottom)
		return ImageGrab.grab(bbox=WindowRect, all_screens=True)
	return ImageGrab.grab(all_screens=True)

def DetectViewportRect(BlackImage, WhiteImage):
	"""Tự động phát hiện hình chữ nhật Viewport 3D dựa trên sai phân giữa Black và White frame."""
	BlackArr = np.array(BlackImage, dtype=np.float32)
	WhiteArr = np.array(WhiteImage, dtype=np.float32)

	# Sai phân màu giữa 2 frame
	Diff = np.abs(WhiteArr - BlackArr).mean(axis=2)
	Mask = Diff > config.DifferenceMinThreshold

	Rows = np.any(Mask, axis=1)
	Cols = np.any(Mask, axis=0)

	if np.any(Rows) and np.any(Cols):
		MinY, MaxY = np.where(Rows)[0][[0, -1]]
		MinX, MaxX = np.where(Cols)[0][[0, -1]]

		# Thêm biên độ an toàn nhẹ
		Width = MaxX - MinX
		Height = MaxY - MinY
		if Width > 100 and Height > 100:
			return (int(MinX), int(MinY), int(MaxX), int(MaxY))

	# Fallback nếu không xác định được: trả về toàn bộ ảnh
	return (0, 0, BlackImage.width, BlackImage.height)

# =========================================================
# THUẬT TOÁN DUAL-SHOT DIFFERENCE MATTE
# =========================================================

def ComputeDualShotMatte(BlackImage, WhiteImage):
	"""
	Thực hiện thuật toán Dual-Shot Matte:
	Alpha = 1.0 - (White - Black)
	FinalColor = Black / Alpha
	"""
	# Chuyển đổi sang mảng float32 chuẩn hóa [0.0, 1.0]
	BlackArr = np.array(BlackImage.convert("RGB"), dtype=np.float32) / 255.0
	WhiteArr = np.array(WhiteImage.convert("RGB"), dtype=np.float32) / 255.0

	# Tính toán sai phân màu nền
	Diff = np.clip(WhiteArr - BlackArr, 0.0, 1.0)
	Alpha = 1.0 - Diff.mean(axis=2)
	Alpha = np.clip(Alpha, 0.0, 1.0)

	# Lọc ngưỡng trong suốt tuyệt đối để loại bỏ pixel rác
	OpaqueMask = Alpha > config.AlphaThreshold

	# Khôi phục màu gốc không bị pha trộn nền đen
	RestoredRgb = np.zeros_like(BlackArr)
	RestoredRgb[OpaqueMask] = np.clip(BlackArr[OpaqueMask] / Alpha[OpaqueMask, np.newaxis], 0.0, 1.0)

	# Tạo mảng RGBA hoàn chỉnh
	Height, Width = Alpha.shape
	RgbaArr = np.zeros((Height, Width, 4), dtype=np.uint8)
	RgbaArr[:, :, :3] = (RestoredRgb * 255.0).astype(np.uint8)
	RgbaArr[:, :, 3] = (Alpha * 255.0).astype(np.uint8)
	RgbaArr[~OpaqueMask, 3] = 0

	ResultImage = Image.fromarray(RgbaArr, mode="RGBA")
	return ResultImage

def ProcessAndSaveIcon(BlackImage, WhiteImage, ItemType, ItemId):
	"""Cắt xén hình chữ nhật Viewport, thực hiện tách nền, crop vuông và resize chuẩn."""
	# 1. Phát hiện Viewport
	ViewportRect = DetectViewportRect(BlackImage, WhiteImage)
	BlackCrop = BlackImage.crop(ViewportRect)
	WhiteCrop = WhiteImage.crop(ViewportRect)

	# 2. Tách nền Alpha bằng Dual-Shot Matte
	TransparentIcon = ComputeDualShotMatte(BlackCrop, WhiteCrop)

	# 3. Crop vuông trung tâm (Center Square Crop)
	Width, Height = TransparentIcon.size
	SquareSize = min(Width, Height)
	CropLeft = (Width - SquareSize) // 2
	CropTop = (Height - SquareSize) // 2
	SquareIcon = TransparentIcon.crop((CropLeft, CropTop, CropLeft + SquareSize, CropTop + SquareSize))

	# 4. Resize chuẩn về độ phân giải đích (512x512) với bộ lọc Lanczos
	FinalIcon = SquareIcon.resize(config.TargetResolution, Image.Resampling.LANCZOS)

	# 5. Lưu kết quả ra thư mục renders/{ItemType}/{ItemId}.png
	TargetFolder = config.OutputDir / ItemType
	TargetFolder.mkdir(parents=True, exist_ok=True)
	OutputPath = TargetFolder / f"{ItemId}.png"

	FinalIcon.save(OutputPath, format="PNG")
	print(f"[Worker] Đã xuất icon thành công: {OutputPath}")
	return OutputPath

# =========================================================
# FLASK HTTP SERVER & ENDPOINTS
# =========================================================

App = Flask(__name__)
TempFrameCache = {} # Lưu tạm Black frame chờ White frame theo ItemKey

@App.route("/capture", methods=["POST"])
def HandleCaptureRequest():
	Data = request.get_json(force=True)
	if not Data:
		return jsonify({"status": "error", "message": "Invalid JSON body"}), 400

	ItemId   = Data.get("ItemId")
	ItemType = Data.get("ItemType", "Item")
	Step     = Data.get("Step") # "Black" hoặc "White"

	if not ItemId or not Step:
		return jsonify({"status": "error", "message": "Missing ItemId or Step"}), 400

	ItemKey = f"{ItemType}_{ItemId}"
	WindowRect = FindRobloxStudioWindow()
	CapturedImage = CaptureStudioWindow(WindowRect)

	if Step.lower() == "black":
		TempFrameCache[ItemKey] = {
			"black": CapturedImage,
		}
		print(f"[Worker] Đã lưu Black frame cho {ItemKey}")
		return jsonify({"status": "ok", "message": "Black frame captured"})

	elif Step.lower() == "white":
		Cached = TempFrameCache.get(ItemKey)
		if not Cached or "black" not in Cached:
			return jsonify({"status": "error", "message": f"Không tìm thấy Black frame cho {ItemKey}"}), 400

		BlackImage = Cached["black"]
		WhiteImage = CapturedImage

		try:
			OutputPath = ProcessAndSaveIcon(BlackImage, WhiteImage, ItemType, ItemId)
			del TempFrameCache[ItemKey]
			return jsonify({
				"status": "ok",
				"message": f"Saved {ItemType}/{ItemId}.png",
				"path": str(OutputPath)
			})
		except Exception as Err:
			print(f"[Worker] Lỗi xử lý Dual-Shot Matte cho {ItemKey}: {Err}")
			return jsonify({"status": "error", "message": str(Err)}), 500

	return jsonify({"status": "error", "message": f"Unknown step '{Step}'"}), 400

# =========================================================
# CHẠY TRỰC TIẾP HOẶC TEST MOCK
# =========================================================

if __name__ == "__main__":
	if len(sys.argv) > 1 and sys.argv[1] == "--test-matte":
		print("[Worker] Chạy test thuật toán Dual-Shot Matte với dữ liệu tổng hợp...")
		# Tạo mock black và white image (Hộp tròn màu xanh bán trong suốt)
		Size = (400, 400)
		MockBlack = Image.new("RGB", Size, (0, 0, 0))
		MockWhite = Image.new("RGB", Size, (255, 255, 255))

		# Vẽ vật thể màu xanh lục bán trong suốt ở giữa
		BlackPixels = MockBlack.load()
		WhitePixels = MockWhite.load()
		Center = (200, 200)
		Radius = 80

		for Y in range(Size[1]):
			for X in range(Size[0]):
				Dist = ((X - Center[0])**2 + (Y - Center[1])**2)**0.5
				if Dist <= Radius:
					AlphaVal = 0.8
					ItemColor = (0, 220, 100) # Xanh lục
					# Render trên nền đen
					BlackPixels[X, Y] = (
						int(ItemColor[0] * AlphaVal + 0 * (1 - AlphaVal)),
						int(ItemColor[1] * AlphaVal + 0 * (1 - AlphaVal)),
						int(ItemColor[2] * AlphaVal + 0 * (1 - AlphaVal)),
					)
					# Render trên nền trắng
					WhitePixels[X, Y] = (
						int(ItemColor[0] * AlphaVal + 255 * (1 - AlphaVal)),
						int(ItemColor[1] * AlphaVal + 255 * (1 - AlphaVal)),
						int(ItemColor[2] * AlphaVal + 255 * (1 - AlphaVal)),
					)

		TestOut = ProcessAndSaveIcon(MockBlack, MockWhite, "Test", "GreenSphere")
		print(f"[Worker] Test hoàn tất! Kiểm tra kết quả tại: {TestOut}")
		sys.exit(0)

	print("==================================================")
	print("[Worker] KHỞI CHẠY PYTHON STUDIO CAPTURE WORKER...")
	print(f"[Worker] Lắng nghe tại http://{config.ServerHost}:{config.ServerPort}")
	print(f"[Worker] Thư mục lưu ảnh: {config.OutputDir}")
	print("==================================================")
	App.run(host=config.ServerHost, port=config.ServerPort, debug=False)
