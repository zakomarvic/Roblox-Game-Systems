local Players = game:GetService("Players")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

for _, player in ipairs(Players:GetPlayers()) do
	InventoryService.Initialize(player)
end

Players.PlayerAdded:Connect(function(player)
	InventoryService.Initialize(player)
end)
