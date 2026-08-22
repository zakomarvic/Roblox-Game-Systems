local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Remotes = WeaponSystem:WaitForChild("Remotes")
local InflictTarget = Remotes:WaitForChild("InflictTarget")
local Explosion = Remotes:FindFirstChild("Explosion") or Instance.new("RemoteEvent")
Explosion.Name = "Explosion"
Explosion.Parent = Remotes
local ProjectileFired = Remotes:FindFirstChild("ProjectileFired") or Instance.new("RemoteEvent")
ProjectileFired.Name = "ProjectileFired"
ProjectileFired.Parent = Remotes

-- These are shared server-side services/modules, not ReplicatedStorage.Modules.
local Combat = script.Parent
local WeaponState = require(Combat:WaitForChild("WeaponStateService"))
local Effects = WeaponSystem:WaitForChild("Effects")
local BulletEffects = require(Effects:WaitForChild("BulletEffects"))
local ExplosionEffects = require(Effects:WaitForChild("ExplosionEffects"))
local ProjectileRecords = {}
local ShotTimes = {}
local ExplosionTimes = {}
local DAMAGE_OVERKILL_ATTRIBUTE = "DownedDamageOverkill"

local function getOwnedWeapon(Player, Tool)
	if not Tool or not Tool:IsA("Tool") then return nil, nil end
	local Character = Player.Character
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	if not ((Character and Tool:IsDescendantOf(Character)) or (Backpack and Tool:IsDescendantOf(Backpack))) then return nil, nil end
	local Setting = Tool:FindFirstChild("Setting")
	if not Setting or not Setting:IsA("ModuleScript") then return nil, nil end
	local Module = require(Setting)
	if type(Module) ~= "table" then return nil, nil end
	return Tool, Module
end

local function getEquippedWeapon(Player)
	local Character = Player.Character
	local Tool = Character and Character:FindFirstChildOfClass("Tool")
	return getOwnedWeapon(Player, Tool)
end

local function getTorso(Character)
	return Character and (Character:FindFirstChild("Torso") or Character:FindFirstChild("HumanoidRootPart"))
end

local function addCreator(TargetHumanoid, Player)
	while TargetHumanoid:FindFirstChild("creator") do TargetHumanoid.creator:Destroy() end
	local Creator = Instance.new("ObjectValue")
	Creator.Name = "creator"
	Creator.Value = Player
	Creator.Parent = TargetHumanoid
	Debris:AddItem(Creator, 5)
end

local function applyWeaponDamage(TargetHumanoid, Damage, Overkill)
	TargetHumanoid:SetAttribute(DAMAGE_OVERKILL_ATTRIBUTE, Overkill == true)
	TargetHumanoid:TakeDamage(Damage)
	TargetHumanoid:SetAttribute(DAMAGE_OVERKILL_ATTRIBUTE, nil)
end

ProjectileFired.OnServerEvent:Connect(function(Player, Tool, Origin, Direction)
	if typeof(Origin) ~= "Vector3" or typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then return end
	local OwnedTool, Module = getOwnedWeapon(Player, Tool)
	if not OwnedTool or Module.ProjectileType ~= "Projectile" or Module.ExplosiveEnabled ~= true then return end
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local ShooterTorso = getTorso(Character)
	if not Humanoid or Humanoid.Health <= 0 or not ShooterTorso then return end
	if (Origin - (ShooterTorso.CFrame * CFrame.new(0, 1.5, 0)).Position).Magnitude > 8 then return end
	local State = WeaponState.Get(Player, Tool)
	if State and State.Reloading then return end
	ProjectileRecords[Player] = ProjectileRecords[Player] or {}
	ProjectileRecords[Player][Tool] = {Time = os.clock(), Origin = Origin, Direction = Direction.Unit, Speed = tonumber(Module.ProjectileSpeed) or 500, Lifetime = tonumber(Module.ProjectileLifetime) or 10}
end)

InflictTarget.OnServerEvent:Connect(function(Player, TargetHumanoid, TargetTorso, HitPart, Direction)
	if not Player or not TargetHumanoid or not TargetHumanoid:IsA("Humanoid") or not TargetTorso or not TargetTorso:IsA("BasePart") or not HitPart or not HitPart:IsA("BasePart") or TargetHumanoid.Health <= 0 then return end
	local TargetCharacter = TargetHumanoid.Parent
	if not TargetCharacter or not TargetCharacter:IsA("Model") or HitPart:FindFirstAncestorOfClass("Model") ~= TargetCharacter or TargetCharacter:FindFirstChildOfClass("Humanoid") ~= TargetHumanoid or not HitPart:IsDescendantOf(TargetCharacter) or not TargetTorso:IsDescendantOf(TargetCharacter) or TargetCharacter == Player.Character then return end
	if typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then return end
	Direction = Direction.Unit
	local Character = Player.Character
	local ShooterHumanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local ShooterTorso = getTorso(Character)
	if not ShooterHumanoid or not ShooterTorso or ShooterHumanoid.Health <= 0 then return end
	local Tool, Module = getEquippedWeapon(Player)
	if not Tool then return end
	ShotTimes[Player] = ShotTimes[Player] or {}
	local Now = os.clock()
	local LastShot = ShotTimes[Player][Tool] or 0
	local FireRate = math.max(tonumber(Module.FireRate) or 0, 0.03)
	if Now - LastShot < FireRate then return end
	local Start = (ShooterTorso.CFrame * CFrame.new(0, 1.5, 0)).Position
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, Tool}
	Params.IgnoreWater = true
	local ToTarget = HitPart.Position - Start
	if ToTarget.Magnitude <= 0 or ToTarget.Magnitude > 5000 then return end
	local Result = workspace:Raycast(Start, ToTarget, Params)
	if Result and Result.Instance:FindFirstAncestorOfClass("Model") ~= TargetCharacter then return end
	local AlongShot = ToTarget:Dot(Direction)
	if AlongShot <= 0 or AlongShot > 5000 or (HitPart.Position - (Start + Direction * AlongShot)).Magnitude > 8 then return end
	local Damage = tonumber(Module.BaseDamage)
	if not Damage or Damage <= 0 then return end
	ShotTimes[Player][Tool] = Now
	if HitPart.Name == "Head" and Module.HeadshotEnabled then Damage *= tonumber(Module.HeadshotDamageMultiplier) or 1 end
	local Knockback = tonumber(Module.Knockback) or 0
	local Lifesteal = tonumber(Module.Lifesteal) or 0
	addCreator(TargetHumanoid, Player)
	applyWeaponDamage(TargetHumanoid, Damage, Module.Overkill)
	if Knockback > 0 then TargetTorso.AssemblyLinearVelocity += Direction * Knockback end
	if Lifesteal > 0 and ShooterHumanoid.Health > 0 then ShooterHumanoid.Health += Damage * Lifesteal end
	if Module.FlamingBullet == true then BulletEffects.Apply("Incendiary", {Player=Player, Tool=Tool, Module=Module, TargetCharacter=TargetCharacter, TargetHumanoid=TargetHumanoid, TargetTorso=TargetTorso, HitPart=HitPart, Direction=Direction, Duration=Module.FlamingBulletDuration}) end
end)

Explosion.OnServerEvent:Connect(function(Player, Position, Direction, Tool, ClientOrigin)
	if typeof(Position) ~= "Vector3" or typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then return end
	local Character = Player.Character
	local ShooterHumanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local ShooterTorso = getTorso(Character)
	if not ShooterHumanoid or ShooterHumanoid.Health <= 0 or not ShooterTorso then return end
	local OwnedTool, Module = getOwnedWeapon(Player, Tool)
	if not OwnedTool or Module.ProjectileType ~= "Projectile" or Module.ExplosiveEnabled ~= true then return end
	local Radius = tonumber(Module.ExplosionRadius) or 0
	local Damage = tonumber(Module.ExplosionDamage) or 0
	local Knockback = tonumber(Module.ExplosionKnockback) or 0
	if Radius <= 0 or Damage <= 0 then return end
	ExplosionTimes[Player] = ExplosionTimes[Player] or {}
	local Now = os.clock()
	local FireRate = math.max(tonumber(Module.FireRate) or 0, 0.03)
	local LastExplosion = ExplosionTimes[Player][Tool] or 0
	if Now - LastExplosion < FireRate then return end
	local Record = ProjectileRecords[Player] and ProjectileRecords[Player][Tool]
	local Origin = ClientOrigin
	local MaxLifetime = tonumber(Module.ProjectileLifetime) or 10
	local Speed = tonumber(Module.ProjectileSpeed) or 500
	if Record then
		Origin = Record.Origin
		if os.clock() - Record.Time > Record.Lifetime + 1 then Record = nil end
	end
	if typeof(Origin) ~= "Vector3" then return end
	local ExpectedOrigin = (ShooterTorso.CFrame * CFrame.new(0, 1.5, 0)).Position
	if (Origin - ExpectedOrigin).Magnitude > 8 then return end
	if (Position - Origin).Magnitude > Speed * MaxLifetime + Radius then return end
	ExplosionTimes[Player][Tool] = Now
	if ProjectileRecords[Player] then ProjectileRecords[Player][Tool] = nil end
	Direction = Direction.Unit
	ExplosionEffects.Create(Position, {Radius = Radius, Tool = Tool})
	local OverlapParams = OverlapParams.new()
	OverlapParams.FilterType = Enum.RaycastFilterType.Exclude
	OverlapParams.FilterDescendantsInstances = {Character, Tool}
	local Parts = workspace:GetPartBoundsInRadius(Position, Radius, OverlapParams)
	local Processed = {}
	for _, Part in ipairs(Parts) do
		local TargetCharacter = Part:FindFirstAncestorOfClass("Model")
		local TargetHumanoid = TargetCharacter and TargetCharacter:FindFirstChildOfClass("Humanoid")
		local TargetTorso = getTorso(TargetCharacter)
		if TargetCharacter and TargetCharacter ~= Character and TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso and not Processed[TargetCharacter] then
			Processed[TargetCharacter] = true
			local Offset = TargetTorso.Position - Position
			local Distance = Offset.Magnitude
			if Distance <= Radius then
				local Falloff = 1 - math.clamp(Distance / Radius, 0, 1)
				local AppliedDamage = Damage * Falloff
				local ExplosionDirection = Distance > 0 and Offset.Unit or Direction
				if AppliedDamage > 0 then
					addCreator(TargetHumanoid, Player)
					applyWeaponDamage(TargetHumanoid, AppliedDamage, Module.Overkill)
				end
				if Knockback > 0 then TargetTorso.AssemblyLinearVelocity += ExplosionDirection * (Knockback * Falloff) end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(Player)
	ProjectileRecords[Player] = nil
	ShotTimes[Player] = nil
	ExplosionTimes[Player] = nil
	WeaponState.ClearPlayer(Player)
end)