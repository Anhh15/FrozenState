-- Main.client.lua
-- Entry point phía Client
-- Khởi tạo RemoteDefinitions (client-side) để đăng ký reference tới các Remote

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[Client] Đang kết nối FrozenState...")

-- Lấy reference đến tất cả Remotes (chờ server tạo xong)
require(ReplicatedStorage.Shared.Remotes.RemoteDefinitions)

-- Thêm Controller ở đây khi đến các phase sau:
-- local GameStateController = require(script.Parent.Controllers.GameStateController)
-- GameStateController:Init()

print("[Client] Đã kết nối.")
