local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local ServerWeaponSystem = ServerScriptService:WaitForChild("WeaponSystem")
local ServerModules = ServerWeaponSystem:WaitForChild("Modules")
local Remotes = WeaponSystem:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = WeaponSystem

local MeleeRemote = Remotes:FindFirstChild("Melee") or Instance.new("RemoteEvent")
MeleeRemote.Name = "Melee"
MeleeRemote.Sandboxed = true
MeleeRemote.Parent = Remotes

local MeleeUtility = require(ServerModules:WaitForChild("MeleeUtility"))
local ProjectileThrower = require(ServerModules:WaitForChild("ProjectileThrower"))
local DestructibleService = require(ServerScriptService.Destruction.Modules:WaitForChild("DestructibleService"))
local Thrower = ProjectileThrower.new()

local ActiveAttacks = {}
local LastAttacks = {}

local function clearAttack(Player, Tool)
	local PlayerAttacks = ActiveAttacks[Player]
	if not PlayerAttacks then return end
	PlayerAttacks[Tool] = nil
	if next(PlayerAttacks) == nil then ActiveAttacks[Player] = nil end
end

local function getValidTarget(Player, TargetHumanoid, HitPart)
	if typeof(TargetHumanoid) ~= "Instance" or not TargetHumanoid:IsA("Humanoid") then return end
	if typeof(HitPart) ~= "Instance" or not HitPart:IsA("BasePart") then return end
	if TargetHumanoid.Health <= 0 then return end
	local TargetCharacter = TargetHumanoid.Parent
	local Character = Player.Character
	if not TargetCharacter or not TargetCharacter:IsA("Model") or TargetCharacter == Character then return end
	if TargetCharacter:FindFirstChildOfClass("Humanoid") ~= TargetHumanoid then return end
	if not HitPart:IsDescendantOf(TargetCharacter) then return end
	local TargetTorso = MeleeUtility.GetTorso(TargetCharacter)
	if not TargetTorso then return end
	return TargetCharacter, TargetTorso
end

local function validateLineOfSight(Character, Tool, Handle, HitPart, TargetRoot)
	local Offset = HitPart.Position - Handle.Position
	if Offset.Magnitude <= 0 then return false end

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, Tool}
	Params.IgnoreWater = true

	local Result = workspace:Raycast(Handle.Position, Offset, Params)
	return not Result or Result.Instance:IsDescendantOf(TargetRoot)
end

local function createAttack(Player, Tool, Now, Cooldown, Duration)
	local Last = LastAttacks[Player] and LastAttacks[Player][Tool] or -math.huge
	if Now - Last < Cooldown then return nil end
	LastAttacks[Player] = LastAttacks[Player] or {}
	LastAttacks[Player][Tool] = Now
	ActiveAttacks[Player] = ActiveAttacks[Player] or {}
	local Attack = {EndTime = Now + Duration, HitTargets = {}}
	ActiveAttacks[Player][Tool] = Attack
	return Attack
end

MeleeRemote.OnServerEvent:Connect(function(Player, Action, Tool, TargetOrOrigin, HitOrDirection)
	if type(Action) ~= "string" then return end
	local OwnedTool, Module = MeleeUtility.GetOwnedEquippedWeapon(Player, Tool)
	if not OwnedTool then return end

	if Action == "Throw" then
		Thrower:Throw(Player, Tool, TargetOrOrigin, HitOrDirection, Module)
		return
	end

	local Character = Player.Character
	local Humanoid = MeleeUtility.GetHumanoid(Character)
	local Handle = Tool:FindFirstChild("Handle")
	if not Humanoid or Humanoid.Health <= 0 or not Handle or not Handle:IsA("BasePart") then return end

	local Now = os.clock()
	local Cooldown = math.max(0, tonumber(Module.AttackCooldown) or 0)
	local Duration = math.clamp(tonumber(Module.AttackDuration) or 0, 0, 2)

	if Action == "Start" then
		createAttack(Player, Tool, Now, Cooldown, Duration)
		return
	end
	if Action ~= "Hit" then return end

	local PlayerAttacks = ActiveAttacks[Player]
	local Attack = PlayerAttacks and PlayerAttacks[Tool]
	if not Attack or Now > Attack.EndTime + 0.05 then
		clearAttack(Player, Tool)
		return
	end

	local HitPart = HitOrDirection
	if typeof(HitPart) ~= "Instance" or not HitPart:IsA("BasePart") then return end

	local TargetCharacter, TargetTorso = getValidTarget(Player, TargetOrOrigin, HitPart)
	if TargetCharacter then
		if Attack.HitTargets[TargetOrOrigin] then return end
		if (TargetTorso.Position - Handle.Position).Magnitude > math.max(10, Handle.Size.Magnitude + 6) then return end
		if not validateLineOfSight(Character, Tool, Handle, HitPart, TargetCharacter) then return end

		Attack.HitTargets[TargetOrOrigin] = true
		MeleeUtility.ApplyDamage(Player, TargetOrOrigin, tonumber(Module.BaseDamage) or 0, Debris, Module.Overkill)

		local Knockback = tonumber(Module.MeleeKnockback) or 0
		if Knockback > 0 then
			local KnockDirection = TargetTorso.Position - Handle.Position
			if KnockDirection.Magnitude > 0 then TargetTorso.AssemblyLinearVelocity += KnockDirection.Unit * Knockback end
		end
		return
	end

	local TargetRoot = DestructibleService.GetRoot(TargetOrOrigin) or DestructibleService.GetRoot(HitPart)
	if not TargetRoot then return end
	if Attack.HitTargets[TargetRoot] then return end
	if not TargetRoot:IsDescendantOf(workspace) then return end

	local TargetPart = HitPart:IsDescendantOf(TargetRoot) and HitPart or DestructibleService.GetHitPart(TargetRoot)
	if not TargetPart then return end
	if (TargetPart.Position - Handle.Position).Magnitude > math.max(10, Handle.Size.Magnitude + 6) then return end
	if not validateLineOfSight(Character, Tool, Handle, TargetPart, TargetRoot) then return end

	Attack.HitTargets[TargetRoot] = true
	DestructibleService.Damage(TargetRoot, tonumber(Module.BaseDamage) or 0, Player)
end)

Players.PlayerRemoving:Connect(function(Player)
	ActiveAttacks[Player] = nil
	LastAttacks[Player] = nil
	Thrower:RemovePlayer(Player)
end)