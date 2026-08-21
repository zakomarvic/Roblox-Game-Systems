local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterSystem = ReplicatedStorage:WaitForChild("CharacterSystem")
local CharacterRagdoll = require(CharacterSystem.Ragdoll:WaitForChild("CharacterRagdoll"))

local RagdollService = {}
local ActiveRagdolls = {}
local RagdollTimers = {}

local function getRagdoll(Character)
	local Ragdoll = ActiveRagdolls[Character]
	if not Ragdoll then
		Ragdoll = CharacterRagdoll.new(Character)
		ActiveRagdolls[Character] = Ragdoll
	end
	return Ragdoll
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
		if Ragdoll and Humanoid and Humanoid.Health > 0 and Ragdoll:IsRagdolled() then
			Ragdoll:Recover()
		end
	end)
end

function RagdollService:Ragdoll(Character, Duration)
	if not Character or not Character:IsDescendantOf(workspace) then
		return false
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return false
	end

	if Duration ~= nil then
		if typeof(Duration) ~= "number" or Duration <= 0 or Duration > 60 then
			return false
		end
	end

	getRagdoll(Character):SetRagdolled(true)
	scheduleRecovery(Character, Duration)
	return true
end

function RagdollService:ApplyImpulse(Character, Direction, Force)
	if not Character or typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then
		return false
	end
	if typeof(Force) ~= "number" or Force <= 0 then
		return false
	end

	local Ragdoll = ActiveRagdolls[Character]
	if not Ragdoll or not Ragdoll:IsRagdolled() then
		return false
	end

	Force = math.clamp(Force, 0, 100)
	return Ragdoll:ApplyImpulse(Direction, Force)
end

function RagdollService:Knockdown(Character, Direction, Force, Duration)
	if not Character or typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then
		return false
	end
	if typeof(Force) ~= "number" or Force <= 0 then
		return false
	end
	if Duration ~= nil and (typeof(Duration) ~= "number" or Duration <= 0 or Duration > 60) then
		return false
	end

	if not self:Ragdoll(Character, Duration) then
		return false
	end

	return self:ApplyImpulse(Character, Direction, Force)
end

function RagdollService:KnockdownFromPosition(Character, Origin, Force, Duration)
	if typeof(Origin) ~= "Vector3" then
		return false
	end

	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if not RootPart then
		return false
	end

	local Direction = RootPart.Position - Origin
	if Direction.Magnitude <= 0 then
		return false
	end

	return self:Knockdown(Character, Direction, Force, Duration)
end

function RagdollService:Recover(Character)
	local Ragdoll = ActiveRagdolls[Character]
	if not Ragdoll then
		return false
	end

	RagdollTimers[Character] = (RagdollTimers[Character] or 0) + 1
	Ragdoll:Recover()
	return true
end

function RagdollService:Destroy(Character)
	local Ragdoll = ActiveRagdolls[Character]
	if Ragdoll then
		Ragdoll:Destroy()
		ActiveRagdolls[Character] = nil
		RagdollTimers[Character] = nil
	end
end

return RagdollService
