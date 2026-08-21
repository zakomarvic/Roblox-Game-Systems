local Players = game:GetService("Players")

local CashService = {}

local DEFAULT_CASH = 0
local MAX_CASH = 2_147_483_647

local function getCashValue(Player)
	local Leaderstats = Player:FindFirstChild("leaderstats")
	local Cash = Leaderstats and Leaderstats:FindFirstChild("Cash")
	if Cash and Cash:IsA("IntValue") then
		return Cash
	end
	return nil
end

function CashService.Get(Player)
	local Cash = getCashValue(Player)
	return Cash and Cash.Value or 0
end

function CashService.Set(Player, Amount)
	local Cash = getCashValue(Player)
	if not Cash then return false end
	Cash.Value = math.clamp(math.floor(tonumber(Amount) or DEFAULT_CASH), 0, MAX_CASH)
	return true
end

function CashService.Add(Player, Amount)
	local Cash = getCashValue(Player)
	if not Cash then return false end
	local Delta = math.floor(tonumber(Amount) or 0)
	Cash.Value = math.clamp(Cash.Value + Delta, 0, MAX_CASH)
	return true
end

function CashService.Remove(Player, Amount)
	local Cash = getCashValue(Player)
	if not Cash then return false end
	local Delta = math.max(0, math.floor(tonumber(Amount) or 0))
	Cash.Value = math.max(0, Cash.Value - Delta)
	return true
end

function CashService.Reset(Player)
	return CashService.Set(Player, DEFAULT_CASH)
end

function CashService.GetOrCreate(Player, InitialAmount)
	local Existing = getCashValue(Player)
	if Existing then return Existing end

	local Leaderstats = Player:FindFirstChild("leaderstats")
	if not Leaderstats then
		Leaderstats = Instance.new("Folder")
		Leaderstats.Name = "leaderstats"
		Leaderstats.Parent = Player
	end

	local Cash = Instance.new("IntValue")
	Cash.Name = "Cash"
	Cash.Value = math.clamp(math.floor(tonumber(InitialAmount) or DEFAULT_CASH), 0, MAX_CASH)
	Cash.Parent = Leaderstats
	return Cash
end

return CashService
