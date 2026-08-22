local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterSystem = ReplicatedStorage:WaitForChild("CharacterSystem")
local Modules = CharacterSystem:WaitForChild("Modules")
local CharacterRagdoll = require(Modules:WaitForChild("CharacterRagdoll"))

local Remote = CharacterSystem:FindFirstChild("RagdollRemote")
if not Remote then
	Remote = Instance.new("RemoteEvent")
	Remote.Name = "RagdollRemote"
	Remote.Parent = CharacterSystem
end

local ActiveRagdolls = {}
local RagdollTimers = {}
local CharacterConnections = {}

local function getRagdoll(Character)
	local Ragdoll = ActiveRagdolls[Character]
	if not Ragdoll then
		Ragdoll = CharacterRagdoll.new(Character)
		ActiveRagdolls[Character] = Ragdoll
	end
	return Ragdoll
end

local function cancelTimer(Character)
	RagdollTimers[Character] = (RagdollTimers[Character] or 0) + 1
end

local function cleanupCharacter(Character)
	cancelTimer(Character)

	local Ragdoll = ActiveRagdolls[Character]
	if Ragdoll then
		Ragdoll:Destroy()
		ActiveRagdolls[Character] = nil
	end

	RagdollTimers[Character] = nil
	CharacterConnections[Character] = nil
end

local function scheduleRecovery(Character, Duration)
	if not Duration then
		return
	end

	local Token = (RagdollTimers[Character] or 0) + 1
	RagdollTimers[Character] = Token

	task.delay(Duration, function()
		if RagdollTimers[Character] ~= Token then
			return
		end

		local Ragdoll = ActiveRagdolls[Character]
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		if not Ragdoll or not Humanoid or Humanoid.Health <= 0 then
			return
		end

		if Ragdoll:IsRagdolled() then
			Ragdoll:Recover()
			local Player = Players:GetPlayerFromCharacter(Character)
			if Player then
				Remote:FireClient(Player, false)
			end
		end
	end)
end

local function setupCharacter(Character)
	if not Character or not Character:IsA("Model") or CharacterConnections[Character] then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	CharacterConnections[Character] = true
	Humanoid.BreakJointsOnDeath = false
	Humanoid.RequiresNeck = false

	Humanoid.Died:Connect(function()
		cancelTimer(Character)
		getRagdoll(Character):SetRagdolled(true)

		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			Remote:FireClient(Player, true)
		end
	end)

	Character.AncestryChanged:Connect(function(_, Parent)
		if Parent == nil then
			cleanupCharacter(Character)
		end
	end)
end

local function setupPlayer(Player)
	Player.CharacterAdded:Connect(function(Character)
		ActiveRagdolls[Character] = nil
		RagdollTimers[Character] = nil
		setupCharacter(Character)
	end)

	if Player.Character then
		setupCharacter(Player.Character)
	end
end

for _, Player in ipairs(Players:GetPlayers()) do
	setupPlayer(Player)
end

for _, Instance in ipairs(Workspace:GetDescendants()) do
	if Instance:IsA("Humanoid") and Instance.Parent and Instance.Parent:IsA("Model") then
		setupCharacter(Instance.Parent)
	end
end

Workspace.DescendantAdded:Connect(function(Instance)
	if Instance:IsA("Humanoid") then
		local Character = Instance.Parent
		if Character and Character:IsA("Model") then
			task.defer(setupCharacter, Character)
		end
	end
end)

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(Player)
	if Player.Character then
		cleanupCharacter(Player.Character)
	end
end)

Remote.OnServerEvent:Connect(function(Player, Action, Value, Extra, Duration)
	local Character = Player.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	local Ragdoll = getRagdoll(Character)

	if typeof(Action) == "boolean" then
		local RagdollDuration = Value
		if RagdollDuration ~= nil and (typeof(RagdollDuration) ~= "number" or RagdollDuration <= 0 or RagdollDuration > 60) then
			return
		end

		if Action then
			Ragdoll:SetRagdolled(true)
			Remote:FireClient(Player, true)
			scheduleRecovery(Character, RagdollDuration)
		else
			cancelTimer(Character)
			Ragdoll:SetRagdolled(false)
			Remote:FireClient(Player, false)
		end
		return
	end

	if Action == "Impulse" then
		local Direction = Value
		local Force = Extra

		if not Ragdoll:IsRagdolled() then
			return
		end
		if typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then
			return
		end
		if typeof(Force) ~= "number" or Force <= 0 then
			return
		end

		Force = math.clamp(Force, 0, 100)
		Ragdoll:ApplyImpulse(Direction, Force)
		return
	end

	if Action == "Knockdown" then
		local KnockdownDirection = Value
		local KnockdownForce = Extra
		local KnockdownDuration = Duration

		if typeof(KnockdownDirection) ~= "Vector3" or KnockdownDirection.Magnitude <= 0 then
			return
		end
		if typeof(KnockdownForce) ~= "number" or KnockdownForce <= 0 then
			return
		end
		if KnockdownDuration ~= nil and (typeof(KnockdownDuration) ~= "number" or KnockdownDuration <= 0 or KnockdownDuration > 60) then
			return
		end

		KnockdownForce = math.clamp(KnockdownForce, 0, 100)
		KnockdownDuration = KnockdownDuration and math.clamp(KnockdownDuration, 0.05, 60) or nil

		Ragdoll:SetRagdolled(true)
		Remote:FireClient(Player, true)
		Ragdoll:ApplyImpulse(KnockdownDirection, KnockdownForce)
		scheduleRecovery(Character, KnockdownDuration)
	end
end)