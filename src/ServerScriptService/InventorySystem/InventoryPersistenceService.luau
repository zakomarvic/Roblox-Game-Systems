local DataStoreService = game:GetService("DataStoreService")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))

local InventoryPersistenceService = {}

local InventoryStore = DataStoreService:GetDataStore("PlayerInventory_v1")

local MAX_RETRIES = 3
local Saving = {}
local Loaded = {}

local function getKey(player)
	return "Player_" .. player.UserId
end

local function sanitizeInventory(data)
	local inventory = {}
	if type(data) ~= "table" then
		return inventory
	end

	for itemId, count in pairs(data) do
		if type(itemId) == "string" and type(count) == "number" then
			local amount = math.max(0, math.floor(count))
			if amount > 0 then
				inventory[itemId] = amount
			end
		end
	end

	return inventory
end

function InventoryPersistenceService.IsLoaded(player)
	return Loaded[player] == true
end

function InventoryPersistenceService.Load(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false, "Invalid player."
	end

	InventoryService.Initialize(player)

	local data
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			return InventoryStore:GetAsync(getKey(player))
		end)

		if success then
			data = result
			break
		end

		if attempt < MAX_RETRIES then
			task.wait(attempt)
		end
	end

	if data == nil then
		-- No saved inventory yet. Starter weapon seeding remains a separate concern.
		Loaded[player] = true
		return true
	end

	local savedInventory = type(data) == "table" and data.Inventory or data
	InventoryService.Replace(sanitizeInventory(savedInventory))
	Loaded[player] = true
	return true
end

function InventoryPersistenceService.Save(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end

	if not Loaded[player] or Saving[player] then
		return false
	end

	Saving[player] = true

	local snapshot = InventoryService.GetSnapshot(player)
	local success = false

	for attempt = 1, MAX_RETRIES do
		success = pcall(function()
			InventoryStore:UpdateAsync(getKey(player), function()
				return {
					Inventory = snapshot or {},
				}
			end)
		end)

		if success then
			break
		end

		if attempt < MAX_RETRIES then
			task.wait(attempt)
		end
	end

	Saving[player] = nil
	return success
end

function InventoryPersistenceService.Release(player)
	Loaded[player] = nil
	Saving[player] = nil
end

return InventoryPersistenceService
