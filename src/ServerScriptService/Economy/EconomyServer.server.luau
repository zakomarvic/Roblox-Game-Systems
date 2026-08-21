local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Modules = script.Parent:WaitForChild("Modules")
local CashService = require(Modules:WaitForChild("CashService"))
local EconomyDrop = require(Modules:WaitForChild("EconomyDrop"))
local Rewards = require(Modules:WaitForChild("Rewards"))
require(Modules:WaitForChild("ShopService"))

local CashStore = DataStoreService:GetDataStore("PlayerEconomy_v1")

local DEFAULT_CASH = 0
local AUTOSAVE_INTERVAL = 60
local MAX_RETRIES = 3

local Saving = {}
local DeathConnections = {}
local NPCDeathConnections = {}

local function getKey(Player)
	return "Player_" .. Player.UserId
end

local function load(Player)
	local Data
	for Attempt = 1, MAX_RETRIES do
		local Success, Result = pcall(function()
			return CashStore:GetAsync(getKey(Player))
		end)
		if Success then
			Data = Result
			break
		end
		task.wait(Attempt)
	end

	local Amount = DEFAULT_CASH
	if type(Data) == "table" then
		Amount = tonumber(Data.Cash) or DEFAULT_CASH
	elseif type(Data) == "number" then
		Amount = Data
	end
	CashService.GetOrCreate(Player, Amount)
end

local function save(Player)
	if Saving[Player] then return false end
	Saving[Player] = true

	local Amount = CashService.Get(Player)
	local Success = false
	for Attempt = 1, MAX_RETRIES do
		Success = pcall(function()
			return CashStore:UpdateAsync(getKey(Player), function(OldData)
				local Data = type(OldData) == "table" and OldData or {}
				Data.Cash = Amount
				return Data
			end)
		end)
		if Success then break end
		task.wait(Attempt)
	end

	Saving[Player] = nil
	return Success
end

local function getKiller(Humanoid)
	local Creator = Humanoid:FindFirstChild("creator")
	local Killer = Creator and Creator.Value
	if typeof(Killer) ~= "Instance" or not Killer:IsA("Player") then return nil end
	if Killer.Parent ~= Players then return nil end
	return Killer
end

local function getReward(Name)
	return math.max(0, math.floor(tonumber(Rewards[Name]) or 0))
end

local function rewardPlayerKill(Victim)
	local Humanoid = Victim:FindFirstChildOfClass("Humanoid")
	local Killer = Humanoid and getKiller(Humanoid)
	if not Killer then return end

	local Reward = getReward("PlayerKill")
	if Reward > 0 and Killer ~= Players:GetPlayerFromCharacter(Victim) then
		CashService.Add(Killer, Reward)
	end
end

local function setupNPCDeath(Humanoid)
	if not Humanoid or not Humanoid:IsDescendantOf(workspace) then return end
	if NPCDeathConnections[Humanoid] then return end

	local Character = Humanoid.Parent
	if not Character or not Character:IsA("Model") then return end
	if Players:GetPlayerFromCharacter(Character) then return end

	NPCDeathConnections[Humanoid] = Humanoid.Died:Connect(function()
		local Killer = getKiller(Humanoid)
		if not Killer then return end

		local Reward = getReward("NPCKill")
		if Reward <= 0 then return end

		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root then return end

		local DropOptions = {
			IgnoreInstances = {Character},
		}
		EconomyDrop.DropFixedCash(Root.Position, Reward, DropOptions)
	end)
end

local function setupDeathDrop(Player, Character)
	if DeathConnections[Player] then
		DeathConnections[Player]:Disconnect()
		DeathConnections[Player] = nil
	end

	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if not Humanoid then return end

	DeathConnections[Player] = Humanoid.Died:Connect(function()
		rewardPlayerKill(Character)

		local Root = Character:FindFirstChild("HumanoidRootPart")
		if Root then
			EconomyDrop.DropPlayerCash(Player, Root.Position)
		end
	end)
end

for _, Descendant in ipairs(workspace:GetDescendants()) do
	if Descendant:IsA("Humanoid") then
		setupNPCDeath(Descendant)
	end
end

workspace.DescendantAdded:Connect(function(Descendant)
	if Descendant:IsA("Humanoid") then
		setupNPCDeath(Descendant)
	end
end)

Players.PlayerAdded:Connect(function(Player)
	CashService.GetOrCreate(Player, DEFAULT_CASH)
	load(Player)
	Player.CharacterAdded:Connect(function(Character)
		setupDeathDrop(Player, Character)
	end)
	if Player.Character then
		setupDeathDrop(Player, Player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(Player)
	if DeathConnections[Player] then
		DeathConnections[Player]:Disconnect()
		DeathConnections[Player] = nil
	end
	save(Player)
	Saving[Player] = nil
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, Player in ipairs(Players:GetPlayers()) do
			task.spawn(save, Player)
		end
	end
end)

game:BindToClose(function()
	local PlayerList = Players:GetPlayers()
	local Remaining = #PlayerList
	if Remaining == 0 then return end

	for _, Player in ipairs(PlayerList) do
		task.spawn(function()
			save(Player)
			Remaining -= 1
		end)
	end

	local Deadline = os.clock() + 25
	while Remaining > 0 and os.clock() < Deadline do
		task.wait()
	end
end)