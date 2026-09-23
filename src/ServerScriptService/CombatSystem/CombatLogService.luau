local CombatTagService = require(game:GetService("ServerScriptService"):WaitForChild("CombatSystem"):WaitForChild("CombatTagService"))
local ItemDefinitions = require(game:GetService("ServerScriptService"):WaitForChild("InventorySystem"):WaitForChild("ItemDefinitions"))
local InventoryService = require(game:GetService("ServerScriptService"):WaitForChild("InventorySystem"):WaitForChild("InventoryService"))
local CashService = require(game:GetService("ServerScriptService"):WaitForChild("Economy"):WaitForChild("Modules"):WaitForChild("CashService"))

local CombatLogService = {}

local CASH_PENALTY_PERCENT = 0.25
local Penalized = {}

local function getWeaponItemId(tool)
	if not tool or not tool:IsA("Tool") then
		return nil
	end

	for itemId, definition in pairs(ItemDefinitions.Items) do
		if definition.Type == ItemDefinitions.Types.Weapon and definition.ToolName == tool.Name then
			return itemId
		end
	end

	return nil
end

local function getBackpackWeaponLoss(player)
	local loss = {}

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return loss
	end

	for _, child in ipairs(backpack:GetChildren()) do
		local itemId = getWeaponItemId(child)
		if itemId then
			loss[itemId] = (loss[itemId] or 0) + 1
		end
	end

	return loss
end

function CombatLogService.GetCashPenaltyPercent()
	return CASH_PENALTY_PERCENT
end

function CombatLogService.IsEligible(player)
	return typeof(player) == "Instance"
		and player:IsA("Player")
		and player:GetAttribute("CombatLogEligible") == true
end

function CombatLogService.ApplyPenalty(player)
	if not CombatLogService.IsEligible(player) or Penalized[player] then
		return false, "Not eligible."
	end

	Penalized[player] = true

	local cash = CashService.Get(player)
	local cashPenalty = math.floor(cash * CASH_PENALTY_PERCENT)
	if cashPenalty > 0 then
		CashService.Remove(player, cashPenalty)
	end

	local weaponLoss = getBackpackWeaponLoss(player)
	for itemId, count in pairs(weaponLoss) do
		InventoryService.RemoveItem(player, itemId, count)
	end

	player:SetAttribute("CombatLogEligible", false)
	task.defer(function()
		Penalized[player] = nil
	end)

	return true, {
		CashLost = cashPenalty,
		WeaponsLost = weaponLoss,
	}
end

function CombatLogService.Clear(player)
	Penalized[player] = nil
	return true
end

return CombatLogService
