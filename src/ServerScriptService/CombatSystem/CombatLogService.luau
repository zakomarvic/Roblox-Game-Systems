local CombatTagService = require(game:GetService("ServerScriptService"):WaitForChild("CombatSystem"):WaitForChild("CombatTagService"))
local InventoryService = require(game:GetService("ServerScriptService"):WaitForChild("InventorySystem"):WaitForChild("InventoryService"))
local CashService = require(game:GetService("ServerScriptService"):WaitForChild("Economy"):WaitForChild("Modules"):WaitForChild("CashService"))

local CombatLogService = {}

local CASH_PENALTY_PERCENT = 0.25
local Penalized = {}

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

	-- Combat logging uses the same inventory wipe as dying/resetting.
	-- StarterCount grants are restored when the player next loads.
	local inventory = InventoryService.GetSnapshot(player)
	InventoryService.Clear(player)

	player:SetAttribute("CombatLogEligible", false)
	task.defer(function()
		Penalized[player] = nil
	end)

	return true, {
		CashLost = cashPenalty,
		InventoryLost = inventory or {},
	}
end

function CombatLogService.Clear(player)
	Penalized[player] = nil
	return true
end

return CombatLogService
