-- Main.server.lua
-- Entry point phía Server
-- Khởi tạo RemoteDefinitions trước (tạo folder Remotes) rồi load tất cả service

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Server] Đang khởi động FrozenState...")

-- Bước 1: Tạo Remotes trước để Client có thể WaitForChild ngay khi join
require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- Bước 2: Khởi động tất cả service theo thứ tự
local ServiceLoader = require(script.Parent.Services.ServiceLoader)
ServiceLoader.LoadAll()

print("[Server] FrozenState đã sẵn sàng.")
