local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ItemDefinitions = require(script.Parent:WaitForChild("ItemDefinitions"))

local InventoryBackpackService = {}

local PlayerConnections = {}
local Syncing = {}

local function getBackpack(player)
	return player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
end

local function getCharacter(player)
	return player.Character
end

local function countToolInstances(player, toolName)
	local count = 0
	local backpack = getBackpack(player)
	local character = getCharacter(player)

	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child.Name == toolName then
				count += 1
			end
		end
	end

	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child.Name == toolName then
				count += 1
			end
		end
	end

	return count
end

local function findStarterTool(toolName)
	for _, child in ipairs(StarterPack:GetChildren()) do
		if child:IsA("Tool") and child.Name == toolName then
			return child
		end
	end

	return nil
end

local function removeExcessBackpackTools(player, toolName, amount)
	if amount <= 0 then
		return
	end

	local backpack = getBackpack(player)
	if not backpack then
		return
	end

	for _, child in ipairs(backpack:GetChildren()) do
		if amount <= 0 then
			break
		end

		if child:IsA("Tool") and child.Name == toolName then
			child:Destroy()
			amount -= 1
		end
	end
end

local function ensureToolCount(player, itemId, definition)
	local toolName = definition.ToolName
	if type(toolName) ~= "string" or toolName == "" then
		return
	end

	local desired = InventoryService.GetItemCount(player, itemId)
	local current = countToolInstances(player, toolName)

	if current < desired then
		local template = findStarterTool(toolName)
		if not template then
			warn(("InventoryBackpackService: no StarterPack template found for %s (%s)."):format(itemId, toolName))
			return
		end

		local backpack = getBackpack(player)
		if not backpack then
			return
		end

		for _ = current + 1, desired do
			template:Clone().Parent = backpack
		end
	elseif current > desired then
		removeExcessBackpackTools(player, toolName, current - desired)
	end
end

function InventoryBackpackService.SyncPlayer(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end

	if not InventoryService.IsLoaded(player) then
		return false
	end

	if Syncing[player] then
		return false
	end

	Syncing[player] = true

	local backpack = getBackpack(player)
	if not backpack then
		Syncing[player] = nil
		return false
	end

	for itemId, definition in pairs(ItemDefinitions.Items) do
		if definition.Type == ItemDefinitions.Types.Weapon and definition.ToolName then
			ensureToolCount(player, itemId, definition)
		end
	end

	Syncing[player] = nil
	return true
end

local function scheduleSync(player)
	task.defer(function()
		InventoryBackpackService.SyncPlayer(player)
	end)
end

local function watchContainer(player, container)
	if not container then
		return
	end

	table.insert(PlayerConnections[player], container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			scheduleSync(player)
		end
	end))

	table.insert(PlayerConnections[player], container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			scheduleSync(player)
		end
	end))
end

function InventoryBackpackService.StartPlayer(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end

	if PlayerConnections[player] then
		return true
	end

	PlayerConnections[player] = {}

	table.insert(PlayerConnections[player], player.CharacterAdded:Connect(function(character)
		local backpack = getBackpack(player)
		watchContainer(player, backpack)
		watchContainer(player, character)
		scheduleSync(player)
	end))

	local backpack = getBackpack(player)
	watchContainer(player, backpack)

	if player.Character then
		watchContainer(player, player.Character)
	end

	scheduleSync(player)
	return true
end

function InventoryBackpackService.StopPlayer(player)
	local connections = PlayerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	PlayerConnections[player] = nil
	Syncing[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	InventoryBackpackService.StopPlayer(player)
end)

return InventoryBackpackService
