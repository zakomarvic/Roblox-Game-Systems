local Players = game:GetService("Players")

local InventorySystem = script.Parent
local InventoryService = require(InventorySystem:WaitForChild("InventoryService"))
require(InventorySystem:WaitForChild("InventoryBackpackService"))

for _, player in ipairs(Players:GetPlayers()) do
	InventoryService.Initialize(player)
end

Players.PlayerAdded:Connect(function(player)
	InventoryService.Initialize(player)
end)
