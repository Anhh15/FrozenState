# upload_icons.py
# Script độc lập chuyên biệt để tải các icon đã kiểm duyệt lên Roblox Open Cloud API
# và tự động cập nhật assetId vào src/ReplicatedStorage/Shared/Config/ItemRegistry.lua

import os
import re
import sys
import time
import argparse
from pathlib import Path

# Cấu hình UTF-8 cho Windows Console tránh lỗi charmap encoding
if sys.platform == "win32":
	try:
		sys.stdout.reconfigure(encoding="utf-8")
		sys.stderr.reconfigure(encoding="utf-8")
	except Exception:
		pass

import requests
from dotenv import load_dotenv

# Nạp biến môi trường từ .env nếu có
EnvPath = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=EnvPath)

ROBLOX_API_KEY   = os.getenv("ROBLOX_API_KEY", "")
ROBLOX_CREATOR_ID = os.getenv("ROBLOX_CREATOR_ID", "")
CREATOR_TYPE     = os.getenv("CREATOR_TYPE", "User") # "User" hoặc "Group"

ProjectRoot = Path(__file__).resolve().parent.parent.parent
RendersDir  = ProjectRoot / "renders"
RegistryPath = ProjectRoot / "src" / "ReplicatedStorage" / "Shared" / "Config" / "ItemRegistry.lua"

OPEN_CLOUD_UPLOAD_URL = "https://apis.roblox.com/assets/v1/assets"
OPEN_CLOUD_OPERATION_URL = "https://apis.roblox.com/assets/v1/operations/{operationId}"

def CheckPrerequisites():
	"""Kiểm tra sự tồn tại của thư mục renders và file cấu hình."""
	if not RendersDir.exists():
		print(f"[Upload] LỖI: Thư mục ảnh '{RendersDir}' không tồn tại. Hãy chạy pipeline chụp ảnh trước.")
		return False
	if not RegistryPath.exists():
		print(f"[Upload] LỖI: File '{RegistryPath}' không tồn tại.")
		return False
	return True

def ScanApprovedIcons(TargetType=None):
	"""Quét toàn bộ ảnh PNG đã sẵn sàng trong thư mục renders."""
	Icons = []
	for TypeFolder in RendersDir.iterdir():
		if TypeFolder.is_dir():
			TypeName = TypeFolder.name # "Icicle", "Block", "Chest"
			if TargetType and TypeName.lower() != TargetType.lower():
				continue
			for PngFile in TypeFolder.glob("*.png"):
				ItemId = PngFile.stem
				Icons.append({
					"Type": TypeName,
					"Id": ItemId,
					"Path": PngFile,
				})
	return Icons

def UploadAssetToRoblox(FilePath, DisplayName, Description="Auto generated 2D icon"):
	"""Upload 1 file ảnh PNG lên Roblox Open Cloud Assets API và đợi assetId."""
	if not ROBLOX_API_KEY:
		raise ValueError("Chưa thiết lập ROBLOX_API_KEY! Hãy cấu hình trong file tools/icon_pipeline/.env")

	CreatorField = "userId" if CREATOR_TYPE.lower() == "user" else "groupId"
	Metadata = {
		"assetType": "Decal",
		"displayName": DisplayName,
		"description": Description,
		"creationContext": {
			"creator": {
				CreatorField: ROBLOX_CREATOR_ID
			}
		}
	}

	Headers = {
		"x-api-key": ROBLOX_API_KEY,
	}

	with open(FilePath, "rb") as ImageFile:
		Files = {
			"request": (None, requests.compat.json.dumps(Metadata), "application/json"),
			"fileContent": (FilePath.name, ImageFile, "image/png"),
		}
		Response = requests.post(OPEN_CLOUD_UPLOAD_URL, headers=Headers, files=Files)

	if Response.status_code != 200:
		raise RuntimeError(f"Upload thất bại ({Response.status_code}): {Response.text}")

	ResultJson = Response.json()
	OperationId = ResultJson.get("path") # e.g. "operations/..."

	if not OperationId:
		# Một số trường hợp API trả về trực tiếp response.assetId
		if "response" in ResultJson and "assetId" in ResultJson["response"]:
			return ResultJson["response"]["assetId"]
		raise RuntimeError(f"Không nhận được operationId từ Roblox: {ResultJson}")

	# Polling operation status
	OpUrl = f"https://apis.roblox.com/assets/v1/{OperationId}"
	print(f"   [Polling] Đang đợi Roblox xử lý asset ({OperationId})...")

	for _ in range(15): # Đợi tối đa 30s
		time.sleep(2)
		OpRes = requests.get(OpUrl, headers=Headers)
		if OpRes.status_code == 200:
			OpData = OpRes.json()
			if OpData.get("done"):
				if "response" in OpData and "assetId" in OpData["response"]:
					return OpData["response"]["assetId"]
				elif "error" in OpData:
					raise RuntimeError(f"Lỗi xử lý asset: {OpData['error']}")

	raise TimeoutError("Hết thời gian chờ Roblox xử lý asset upload.")

def UpdateItemRegistryFile(ItemId, ItemType, AssetId):
	"""Cập nhật thuộc tính Icon của item tương ứng trong ItemRegistry.lua."""
	Content = RegistryPath.read_text(encoding="utf-8")

	# Pattern tìm block của ItemId trong ItemRegistry
	# Id = "Green", ... Icon = "..."
	Pattern = rf'(Id\s*=\s*"{ItemId}",[\s\S]*?Icon\s*=\s*")([^"]*)(")'

	NewIconUri = f"rbxassetid://{AssetId}"

	if re.search(Pattern, Content):
		UpdatedContent = re.sub(Pattern, rf'\g<1>{NewIconUri}\g<3>', Content, count=1)
		RegistryPath.write_text(UpdatedContent, encoding="utf-8")
		print(f"   [Sync] Đã cập nhật ItemRegistry.lua: {ItemId} -> {NewIconUri}")
		return True
	else:
		print(f"   [Cảnh báo] Không tìm thấy Id='{ItemId}' trong ItemRegistry.lua để tự động cập nhật.")
		return False

def Main():
	Parser = argparse.ArgumentParser(description="Upload icon lên Roblox Open Cloud và cập nhật ItemRegistry.lua")
	Parser.add_argument("--type", type=str, default=None, help="Chỉ upload một loại (Icicle, Block, Chest)")
	Parser.add_argument("--id", type=str, default=None, help="Chỉ upload một item cụ thể")
	Parser.add_argument("--dry-run", action="store_true", help="Chạy thử không upload, chỉ liệt kê các file sẽ upload")

	Args = Parser.parse_args()

	print("==================================================")
	print("[Upload] TIỆN ÍCH UPLOAD ICON LÊN ROBLOX OPEN CLOUD")
	print("==================================================")

	if not CheckPrerequisites():
		sys.exit(1)

	AllIcons = ScanApprovedIcons(Args.type)
	if Args.id:
		AllIcons = [Icon for Icon in AllIcons if Icon["Id"].lower() == Args.id.lower()]

	if not AllIcons:
		print("[Upload] Không tìm thấy icon nào để upload trong renders/.")
		sys.exit(0)

	print(f"[Upload] Tìm thấy {len(AllIcons)} icon đã được kiểm duyệt:")
	for Icon in AllIcons:
		print(f" - [{Icon['Type']}] {Icon['Id']}: {Icon['Path']}")

	if Args.dry_run:
		print("--------------------------------------------------")
		print("[Upload] Chế độ DRY-RUN hoàn tất. Không có dữ liệu nào được tải lên.")
		return

	if not ROBLOX_API_KEY:
		print("--------------------------------------------------")
		print("[Upload] LƯU Ý: Chưa có ROBLOX_API_KEY!")
		print("Hãy tạo file 'tools/icon_pipeline/.env' với nội dung:")
		print("ROBLOX_API_KEY=your_key_here")
		print("ROBLOX_CREATOR_ID=your_user_or_group_id")
		print("CREATOR_TYPE=User")
		print("Sau đó chạy lại lệnh này.")
		sys.exit(1)

	Confirm = input(f"Bạn có chắc chắn muốn upload {len(AllIcons)} icon lên Roblox? (y/N): ")
	if Confirm.strip().lower() not in ("y", "yes"):
		print("[Upload] Hủy bỏ tiến trình upload.")
		sys.exit(0)

	SuccessCount = 0
	for Index, Icon in enumerate(AllIcons, 1):
		print(f"\n[{Index}/{len(AllIcons)}] Đang upload {Icon['Type']}/{Icon['Id']}...")
		try:
			AssetId = UploadAssetToRoblox(Icon["Path"], f"Icon_{Icon['Type']}_{Icon['Id']}")
			print(f"   [Thành công] AssetId: {AssetId}")
			UpdateItemRegistryFile(Icon["Id"], Icon["Type"], AssetId)
			SuccessCount += 1
		except Exception as Err:
			print(f"   [Thất bại] Lỗi: {Err}")

	print("\n==================================================")
	print(f"[Upload] HOÀN TẤT! Thành công: {SuccessCount}/{len(AllIcons)}")
	print("==================================================")

if __name__ == "__main__":
	Main()
