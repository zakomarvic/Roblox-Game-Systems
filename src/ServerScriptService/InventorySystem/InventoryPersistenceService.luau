local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ItemDefinitions = require(script.Parent:WaitForChild("ItemDefinitions"))
local CombatLogService = require(game:GetService("ServerScriptService"):WaitForChild("CombatSystem"):WaitForChild("CombatLogService"))

local InventoryPersistenceService = {}

local InventoryStore = DataStoreService:GetDataStore("PlayerInventory_v1")

local MAX_RETRIES = 3
local AUTOSAVE_INTERVAL = 60
local INVENTORY_DATA_VERSION = 2

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
		if ItemDefinitions.Exists(itemId) and type(count) == "number" then
			local amount = math.max(0, math.floor(count))
			if amount > 0 then
				inventory[itemId] = amount
			end
		end
	end

	return inventory
end

local function getStarterInventory()
	local inventory = {}

	for itemId, definition in pairs(ItemDefinitions.Items) do
		local starterCount = math.max(0, math.floor(tonumber(definition.StarterCount) or 0))
		if starterCount > 0 then
			inventory[itemId] = starterCount
		end
	end

	return inventory
end

local function mergeMissingStarterItems(inventory)
	local starterInventory = getStarterInventory()

	for itemId, count in pairs(starterInventory) do
		if inventory[itemId] == nil then
			inventory[itemId] = count
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
	local success = false

	for attempt = 1, MAX_RETRIES do
		success, data = pcall(function()
			return InventoryStore:GetAsync(getKey(player))
		end)

		if success then
			break
		end

		if attempt < MAX_RETRIES then
			task.wait(attempt)
		end
	end

	if not success then
		warn(("InventoryPersistenceService: failed to load inventory for %s."):format(player.Name))
		return false, "Failed to load inventory."
	end

	if data == nil then
		InventoryService.Replace(player, getStarterInventory())
	else
		local savedInventory = type(data) == "table" and data.Inventory or data
		local inventory = sanitizeInventory(savedInventory)

		-- Existing saves from before the inventory version marker did not
		-- contain the current StarterPack weapon entries. Give those legacy
		-- saves the configured starter items once, then persist the version.
		local dataVersion = type(data) == "table" and data.Version or nil
		if dataVersion ~= INVENTORY_DATA_VERSION then
			inventory = mergeMissingStarterItems(inventory)
		end

		InventoryService.Replace(player, inventory)
	end

	Loaded[player] = true
	InventoryService.MarkLoaded(player)
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
			return InventoryStore:UpdateAsync(getKey(player), function()
				return {
					Version = INVENTORY_DATA_VERSION,
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
	InventoryService.Destroy(player)
end

Players.PlayerRemoving:Connect(function(player)
	CombatLogService.ApplyPenalty(player)
	InventoryPersistenceService.Save(player)
	InventoryPersistenceService.Release(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(InventoryPersistenceService.Save, player)
		end
	end
end)

game:BindToClose(function()
	local players = Players:GetPlayers()
	local remaining = #players
	if remaining == 0 then
		return
	end

	for _, player in ipairs(players) do
		task.spawn(function()
			InventoryPersistenceService.Save(player)
			remaining -= 1
		end)
	end

	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do
		task.wait()
	end
end)

return InventoryPersistenceService
