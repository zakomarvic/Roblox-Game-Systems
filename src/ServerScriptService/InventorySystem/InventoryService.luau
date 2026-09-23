local ItemDefinitions = require(script.Parent:WaitForChild("ItemDefinitions"))

local InventoryService = {}

local Inventories = {}
local Loaded = {}

local function validatePlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player")
end

local function getInventoryTable(player)
	if not validatePlayer(player) then
		return nil
	end

	local inventory = Inventories[player]
	if not inventory then
		inventory = {}
		Inventories[player] = inventory
	end

	return inventory
end

function InventoryService.Initialize(player)
	if not validatePlayer(player) then
		return false
	end

	getInventoryTable(player)
	return true
end

function InventoryService.IsInitialized(player)
	return validatePlayer(player) and Inventories[player] ~= nil
end

function InventoryService.IsLoaded(player)
	return validatePlayer(player) and Loaded[player] == true
end

function InventoryService.MarkLoaded(player)
	if not validatePlayer(player) then
		return false
	end

	Loaded[player] = true
	return true
end

function InventoryService.HasItem(player, itemId, amount)
	local inventory = getInventoryTable(player)
	if not inventory then
		return false
	end

	if not ItemDefinitions.Exists(itemId) then
		return false
	end

	local required = math.max(1, math.floor(tonumber(amount) or 1))
	return (inventory[itemId] or 0) >= required
end

function InventoryService.GetItemCount(player, itemId)
	local inventory = getInventoryTable(player)
	if not inventory or not ItemDefinitions.Exists(itemId) then
		return 0
	end

	return inventory[itemId] or 0
end

function InventoryService.AddItem(player, itemId, amount)
	local inventory = getInventoryTable(player)
	if not inventory then
		return false, "Invalid player."
	end

	if not ItemDefinitions.Exists(itemId) then
		return false, "Unknown item."
	end

	local count = math.max(1, math.floor(tonumber(amount) or 1))
	inventory[itemId] = (inventory[itemId] or 0) + count

	return true
end

function InventoryService.RemoveItem(player, itemId, amount)
	local inventory = getInventoryTable(player)
	if not inventory then
		return false, "Invalid player."
	end

	if not ItemDefinitions.Exists(itemId) then
		return false, "Unknown item."
	end

	local count = math.max(1, math.floor(tonumber(amount) or 1))
	local current = inventory[itemId] or 0

	if current < count then
		return false, "Not enough items."
	end

	local remaining = current - count
	if remaining > 0 then
		inventory[itemId] = remaining
	else
		inventory[itemId] = nil
	end

	return true
end

function InventoryService.GetSnapshot(player)
	local inventory = getInventoryTable(player)
	if not inventory then
		return nil
	end

	local snapshot = {}
	for itemId, count in pairs(inventory) do
		snapshot[itemId] = count
	end

	return snapshot
end

function InventoryService.Replace(player, snapshot)
	local inventory = getInventoryTable(player)
	if not inventory then
		return false
	end

	table.clear(inventory)

	if type(snapshot) ~= "table" then
		return true
	end

	for itemId, count in pairs(snapshot) do
		if ItemDefinitions.Exists(itemId) and type(count) == "number" then
			local amount = math.max(0, math.floor(count))
			if amount > 0 then
				inventory[itemId] = amount
			end
		end
	end

	return true
end

function InventoryService.Clear(player)
	local inventory = getInventoryTable(player)
	if not inventory then
		return false
	end

	table.clear(inventory)
	return true
end

function InventoryService.Destroy(player)
	if not validatePlayer(player) then
		return false
	end

	Inventories[player] = nil
	Loaded[player] = nil
	return true
end

return InventoryService
