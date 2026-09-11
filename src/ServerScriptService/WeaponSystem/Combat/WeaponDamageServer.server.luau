local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Remotes = WeaponSystem:WaitForChild("Remotes")
local InflictTarget = Remotes:WaitForChild("InflictTarget")
local ShotResult = Remotes:FindFirstChild("ShotResult") or Instance.new("RemoteEvent")
ShotResult.Name = "ShotResult"
ShotResult.Parent = Remotes
local Explosion = Remotes:FindFirstChild("Explosion") or Instance.new("RemoteEvent")
Explosion.Name = "Explosion"
Explosion.Parent = Remotes
local ProjectileFired = Remotes:FindFirstChild("ProjectileFired") or Instance.new("RemoteEvent")
ProjectileFired.Name = "ProjectileFired"
ProjectileFired.Parent = Remotes

local Combat = script.Parent
local WeaponState = require(Combat:WaitForChild("WeaponStateService"))
local Effects = WeaponSystem:WaitForChild("Effects")
local BulletEffects = require(Effects:WaitForChild("BulletEffects"))
local ExplosionEffects = require(Effects:WaitForChild("ExplosionEffects"))
local CombatSystem = game:GetService("ServerScriptService"):WaitForChild("CombatSystem")
local DamageService = require(CombatSystem:WaitForChild("DamageService"))

local DEBUG_RAYCASTS = false
local DEBUG_RAYCAST_DURATION = 2
local DEBUG_DAMAGE = true
local MAX_ORIGIN_ERROR = 8
local MAX_SHOT_DISTANCE = 5000

local ProjectileRecords = {}
local ShotTimes = {}
local ExplosionTimes = {}

local function debugDamage(Player, Stage, Message)
	if not DEBUG_DAMAGE then return end
	warn(string.format("[WeaponDamageDebug] %s | %s | %s", Player and Player.Name or "?", Stage, Message))
end

local function debugRay(Start, Finish, HitPosition, DidHitTarget)
	if not DEBUG_RAYCASTS then return end
	if typeof(Start) ~= "Vector3" or typeof(Finish) ~= "Vector3" then return end
	local Offset = Finish - Start
	local Length = Offset.Magnitude
	if Length <= 0 then return end
	local BeamPart = Instance.new("Part")
	BeamPart.Name = DidHitTarget and "DEBUG_GunRay_Hit" or "DEBUG_GunRay_Miss"
	BeamPart.Anchored = true
	BeamPart.CanCollide = false
	BeamPart.CanTouch = false
	BeamPart.CanQuery = false
	BeamPart.CastShadow = false
	BeamPart.Material = Enum.Material.Neon
	BeamPart.Color = DidHitTarget and Color3.fromRGB(70, 255, 90) or Color3.fromRGB(255, 70, 70)
	BeamPart.Transparency = 0.2
	BeamPart.Size = Vector3.new(0.08, 0.08, Length)
	BeamPart.CFrame = CFrame.lookAt(Start + Offset * 0.5, Finish)
	BeamPart.Parent = workspace
	Debris:AddItem(BeamPart, DEBUG_RAYCAST_DURATION)
	if HitPosition then
		local Marker = Instance.new("Part")
		Marker.Name = "DEBUG_GunRayHit"
		Marker.Shape = Enum.PartType.Ball
		Marker.Anchored = true
		Marker.CanCollide = false
		Marker.CanTouch = false
		Marker.CanQuery = false
		Marker.CastShadow = false
		Marker.Material = Enum.Material.Neon
		Marker.Color = Color3.fromRGB(255, 255, 0)
		Marker.Size = Vector3.new(0.35, 0.35, 0.35)
		Marker.Position = HitPosition
		Marker.Parent = workspace
		Debris:AddItem(Marker, DEBUG_RAYCAST_DURATION)
	end
end

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

local function getMuzzleOrigin(Tool, Module)
	local Handle = Tool and (Tool:FindFirstChild("Handle") or Tool:FindFirstChild("Handle2"))
	if not Handle or not Handle:IsA("BasePart") then return nil end
	local Offset = Module and Module.MuzzleOffset
	if typeof(Offset) == "Vector3" then
		return Handle.CFrame:PointToWorldSpace(Offset)
	end
	return Handle.Position
end

local function addCreator(TargetHumanoid, Player)
	while TargetHumanoid:FindFirstChild("creator") do TargetHumanoid.creator:Destroy() end
	local Creator = Instance.new("ObjectValue")
	Creator.Name = "creator"
	Creator.Value = Player
	Creator.Parent = TargetHumanoid
	Debris:AddItem(Creator, 5)
end

local function shouldSkipHit(HitPart)
	if not HitPart then return false end
	if HitPart.Transparency > 0.75 then return true end
	local Name = string.lower(HitPart.Name)
	return Name == "handle" or Name == "effect" or Name == "bullet" or Name == "laser" or Name == "water" or Name == "rail" or Name == "arrow"
end

local function resolveTarget(HitPart)
	if not HitPart then return nil, nil end
	local Model = HitPart:FindFirstAncestorOfClass("Model")
	while Model do
		local Humanoid = Model:FindFirstChildOfClass("Humanoid")
		if Humanoid then return Model, Humanoid end
		Model = Model.Parent and Model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

ProjectileFired.OnServerEvent:Connect(function(Player, Tool, Origin, Direction)
	if typeof(Origin) ~= "Vector3" or typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then return end
	local OwnedTool, Module = getOwnedWeapon(Player, Tool)
	if not OwnedTool or Module.ProjectileType ~= "Projectile" or Module.ExplosiveEnabled ~= true then return end
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end
	local ExpectedOrigin = getMuzzleOrigin(Tool, Module)
	if not ExpectedOrigin or (Origin - ExpectedOrigin).Magnitude > MAX_ORIGIN_ERROR then return end
	local State = WeaponState.Get(Player, Tool)
	if State and State.Reloading then return end
	ProjectileRecords[Player] = ProjectileRecords[Player] or {}
	ProjectileRecords[Player][Tool] = {Time = os.clock(), Origin = Origin, Direction = Direction.Unit, Speed = tonumber(Module.ProjectileSpeed) or 500, Lifetime = tonumber(Module.ProjectileLifetime) or 10}
end)

InflictTarget.OnServerEvent:Connect(function(Player, Origin, AimPoint, ShotDirection)
	local function reject(Reason)
		debugDamage(Player, "REJECT", Reason)
	end
	if not Player then return end
	if typeof(Origin) ~= "Vector3" then return reject("invalid shot origin") end
	if typeof(AimPoint) ~= "Vector3" then return reject("invalid aim point") end
	if AimPoint.X ~= AimPoint.X or AimPoint.Y ~= AimPoint.Y or AimPoint.Z ~= AimPoint.Z then return reject("invalid aim point") end
	if ShotDirection ~= nil and (typeof(ShotDirection) ~= "Vector3" or ShotDirection.Magnitude <= 0) then return reject("invalid shot direction") end

	local Character = Player.Character
	local ShooterHumanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not ShooterHumanoid or ShooterHumanoid.Health <= 0 then return reject("shooter invalid/dead") end
	local Tool, Module = getEquippedWeapon(Player)
	if not Tool then return reject("no equipped weapon/Setting") end
	if Module.ProjectileType == "Projectile" then return reject("projectile sent to hitscan remote") end
	if Module.ExplosiveEnabled == true then return reject("explosive weapon sent to hitscan remote") end

	local ExpectedOrigin = getMuzzleOrigin(Tool, Module)
	if not ExpectedOrigin then return reject("weapon has no Handle/muzzle") end
	if (Origin - ExpectedOrigin).Magnitude > MAX_ORIGIN_ERROR then return reject("shot origin too far from weapon muzzle") end
	if (AimPoint - Origin).Magnitude > MAX_SHOT_DISTANCE then return reject("aim point too far from muzzle") end

	ShotTimes[Player] = ShotTimes[Player] or {}
	local Now = os.clock()
	local LastShot = ShotTimes[Player][Tool] or 0
	local FireRate = math.max(tonumber(Module.FireRate) or 0, 0.03)
	if Now - LastShot < FireRate then return reject(string.format("fire-rate gate: %.3fs remaining", FireRate - (Now - LastShot))) end
	ShotTimes[Player][Tool] = Now

	local AimVector = AimPoint - Origin
	if AimVector.Magnitude <= 0 then return reject("aim point is at shooter origin") end
	local AimDirection = AimVector.Unit
	local Direction = AimDirection
	if ShotDirection then
		Direction = ShotDirection.Unit
		local Dot = math.clamp(Direction:Dot(AimDirection), -1, 1)
		local Angle = math.deg(math.acos(Dot))
		local MaxSpread = tonumber(Module.Spread) or 0
		if Angle > MaxSpread + 2 then return reject(string.format("shot direction outside spread: %.2f deg", Angle)) end
	end

	local PierceRemaining = math.max(math.floor(tonumber(Module.Piercing) or 0), 0)
	local FilterInstances = {Character, Tool}
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = FilterInstances
	Params.IgnoreWater = true

	local ShotEndPosition = Origin + Direction * MAX_SHOT_DISTANCE
	local HitAnyCharacter = false
	local LastHitPosition = nil
	local RayStart = Origin

	debugDamage(Player, "RAY", string.format("origin=(%.2f, %.2f, %.2f) aim=(%.2f, %.2f, %.2f) direction=(%.4f, %.4f, %.4f)", Origin.X, Origin.Y, Origin.Z, AimPoint.X, AimPoint.Y, AimPoint.Z, Direction.X, Direction.Y, Direction.Z))

	while true do
		local Result = workspace:Raycast(RayStart, Direction * MAX_SHOT_DISTANCE, Params)
		if not Result then
			debugDamage(Player, "MISS", "server raycast found no hit")
			break
		end

		local HitPart = Result.Instance
		ShotEndPosition = Result.Position
		LastHitPosition = Result.Position
		if shouldSkipHit(HitPart) then
			table.insert(FilterInstances, HitPart)
			Params.FilterDescendantsInstances = FilterInstances
			RayStart = Result.Position + Direction * 0.01
			continue
		end

		local TargetCharacter, TargetHumanoid = resolveTarget(HitPart)
		local TargetTorso = getTorso(TargetCharacter)
		if not TargetCharacter or not TargetHumanoid then
			debugDamage(Player, "MISS", string.format("server ray stopped on %s", HitPart:GetFullName()))
			break
		end
		if TargetCharacter == Character then
			debugDamage(Player, "MISS", "server ray hit shooter")
			break
		end
		if TargetHumanoid.Health <= 0 then
			table.insert(FilterInstances, TargetCharacter)
			Params.FilterDescendantsInstances = FilterInstances
			RayStart = Result.Position + Direction * 0.01
			continue
		end
		if not TargetTorso then
			debugDamage(Player, "MISS", string.format("target %s has no torso", TargetCharacter.Name))
			break
		end

		local Damage = tonumber(Module.BaseDamage)
		if not Damage or Damage <= 0 then return reject("invalid BaseDamage") end
		if HitPart.Name == "Head" and Module.HeadshotEnabled then
			Damage *= tonumber(Module.HeadshotDamageMultiplier) or 1
		end
		local Knockback = tonumber(Module.Knockback) or 0
		local Lifesteal = tonumber(Module.Lifesteal) or 0
		local BeforeHealth = TargetHumanoid.Health
		local DownedBefore = TargetCharacter:GetAttribute("Downed") == true
		debugDamage(Player, "APPLY", string.format("weapon=%s target=%s hit=%s damage=%.2f overkill=%s healthBefore=%.2f downedBefore=%s", Tool.Name, TargetCharacter.Name, HitPart.Name, Damage, tostring(Module.Overkill == true), BeforeHealth, tostring(DownedBefore)))
		addCreator(TargetHumanoid, Player)
		local Applied = DamageService.ApplyDamage(TargetHumanoid, Damage, Module.Overkill)
		debugDamage(Player, "RESULT", string.format("target=%s DamageService=%s healthAfter=%.2f downedAfter=%s", TargetCharacter.Name, tostring(Applied), TargetHumanoid.Health, tostring(TargetCharacter:GetAttribute("Downed") == true)))
		HitAnyCharacter = true
		if Knockback > 0 then TargetTorso.AssemblyLinearVelocity += Direction * Knockback end
		if Lifesteal > 0 and ShooterHumanoid.Health > 0 then ShooterHumanoid.Health += Damage * Lifesteal end
		if Module.FlamingBullet == true then
			BulletEffects.Apply("Incendiary", {Player=Player, Tool=Tool, Module=Module, TargetCharacter=TargetCharacter, TargetHumanoid=TargetHumanoid, TargetTorso=TargetTorso, HitPart=HitPart, Direction=Direction, Duration=Module.FlamingBulletDuration})
		end
		if PierceRemaining <= 0 then break end
		PierceRemaining -= 1
		table.insert(FilterInstances, TargetCharacter)
		Params.FilterDescendantsInstances = FilterInstances
		RayStart = Result.Position + Direction * 0.01
	end

	-- This visualization uses the exact final result of the same raycast loop above.
	-- There is intentionally no second debug raycast.
	debugRay(Origin, ShotEndPosition, LastHitPosition, HitAnyCharacter)
	ShotResult:FireClient(Player, Tool, ShotEndPosition, HitAnyCharacter)
end)

Explosion.OnServerEvent:Connect(function(Player, Position, Direction, Tool, ClientOrigin)
	if typeof(Position) ~= "Vector3" or typeof(Direction) ~= "Vector3" or Direction.Magnitude <= 0 then return end
	local Character = Player.Character
	local ShooterHumanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not ShooterHumanoid or ShooterHumanoid.Health <= 0 then return end
	local OwnedTool, Module = getOwnedWeapon(Player, Tool)
	if not OwnedTool or Module.ProjectileType ~= "Projectile" or Module.ExplosiveEnabled ~= true then return end
	local Radius = tonumber(Module.ExplosionRadius) or 0
	local Damage = tonumber(Module.ExplosionDamage) or 0
	local Knockback = tonumber(Module.ExplosionKnockback) or 0
	if Radius <= 0 or Damage <= 0 then return end
	ExplosionTimes[Player] = ExplosionTimes[Player] or {}
	local Now = os.clock()
	local FireRate = math.max(tonumber(Module.FireRate) or 0.03, 0.03)
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
	local ExpectedOrigin = getMuzzleOrigin(Tool, Module)
	if not ExpectedOrigin or (Origin - ExpectedOrigin).Magnitude > MAX_ORIGIN_ERROR then return end
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
		local TargetCharacter, TargetHumanoid = resolveTarget(Part)
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
					local BeforeHealth = TargetHumanoid.Health
					local Applied = DamageService.ApplyDamage(TargetHumanoid, AppliedDamage, Module.Overkill)
					debugDamage(Player, "EXPLOSION", string.format("target=%s damage=%.2f applied=%s health %.2f -> %.2f", TargetCharacter.Name, AppliedDamage, tostring(Applied), BeforeHealth, TargetHumanoid.Health))
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