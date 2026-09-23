local Players = game:GetService("Players")

local InventorySystem = script.Parent
local InventoryService = require(InventorySystem:WaitForChild("InventoryService"))
local InventoryPersistenceService = require(InventorySystem:WaitForChild("InventoryPersistenceService"))
local InventoryBackpackService = require(InventorySystem:WaitForChild("InventoryBackpackService"))

local Loading = {}

local function setupPlayer(player)
	if Loading[player] then
		return
	end

	Loading[player] = true

	local success = InventoryPersistenceService.Load(player)
	if success then
		InventoryBackpackService.StartPlayer(player)
	else
		warn(("InventoryServiceBootstrap: inventory sync skipped for %s because loading failed."):format(player.Name))
	end

	Loading[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	Loading[player] = nil
	InventoryService.Destroy(player)
end)
