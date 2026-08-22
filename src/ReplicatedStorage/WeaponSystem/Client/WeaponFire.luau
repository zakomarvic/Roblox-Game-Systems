local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = workspace

local WeaponFire = {}
WeaponFire.__index = WeaponFire

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Remotes = WeaponSystem:WaitForChild("Remotes")
local WeaponEffects = Remotes:WaitForChild("WeaponEffects")
local Explosion = Remotes:WaitForChild("Explosion")
local ProjectileFired = Remotes:WaitForChild("ProjectileFired")
local BulletVisualizer = require(WeaponSystem.Effects:WaitForChild("BulletVisualizer"))
local ProjectileController = require(WeaponSystem.Projectile:WaitForChild("ProjectileController"))
local WeaponFireEffects = require(WeaponSystem.Effects:WaitForChild("WeaponFireEffects"))
local WeaponProjectileVisual = require(WeaponSystem.Client:WaitForChild("WeaponProjectileVisual"))

function WeaponFire.new(Config)
	local self = setmetatable({}, WeaponFire)
	self.Tool = Config.Tool
	self.Module = Config.Module
	self.Character = Config.Character
	self.Humanoid = Config.Humanoid
	self.Mouse = Config.Mouse
	self.GetFireAnim = Config.GetFireAnim
	self.FireAnim = Config.FireAnim
	self.Raycast = Config.Raycast
	self.InflictTarget = Config.InflictTarget
	self.MuzzleEffect = Config.MuzzleEffect or self:_getEffectTemplate("MuzzleEffect")
	self.HitEffect = Config.HitEffect or self:_getEffectTemplate("HitEffect")
	self.PiercedHumanoid = {}
	self.IsAiming = false
	self.Projectiles = ProjectileController.new()
	return self
end

function WeaponFire:_getEffectTemplate(Name)
	if not self.Tool then return nil end
	local LocalScript = self.Tool:FindFirstChild("GunScript_Local")
	if LocalScript then
		local Effect = LocalScript:FindFirstChild(Name)
		if Effect then return Effect end
	end
	return self.Tool:FindFirstChild(Name, true)
end

function WeaponFire:SetCharacter(Character, Humanoid)
	self.Character = Character
	self.Humanoid = Humanoid
	self.PiercedHumanoid = {}
	self.MuzzleEffect = self:_getEffectTemplate("MuzzleEffect") or self.MuzzleEffect
	self.HitEffect = self:_getEffectTemplate("HitEffect") or self.HitEffect
end

function WeaponFire:SetAiming(State) self.IsAiming = State == true end

function WeaponFire:_GetDirection(Start)
	local Spread = self.Module.Spread or 0
	Spread *= (self.IsAiming and 1 - (self.Module.SpreadRedution or 0) or 1)
	return (CFrame.new(Start, self.Mouse.Hit.Position) * CFrame.Angles(math.rad(-Spread + math.random() * (Spread * 2)), math.rad(-Spread + math.random() * (Spread * 2)), 0)).LookVector
end

function WeaponFire:_GetRaycastParams()
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {self.Character}
	Params.IgnoreWater = true
	return Params
end

function WeaponFire:_GetHitSound()
	local HitSounds = self.Module.HitSoundIDs
	if typeof(HitSounds) ~= "table" or #HitSounds == 0 then return nil end
	return HitSounds[math.random(1, #HitSounds)]
end

function WeaponFire:_VisualizeHit(ShootingHandle, Position, Piercing, ExplosionData)
	local Module = self.Module
	WeaponFireEffects.VisualizeAndBroadcast(self.Tool, ShootingHandle, Module.MuzzleOffset, Position, self.MuzzleEffect, self.HitEffect, self:_GetHitSound(), ExplosionData or {false, 0, 0}, {Module.BulletSpeed, Module.BulletSize, Module.BulletColor, Module.BulletTransparency, Module.BulletMaterial, Module.FadeTime}, Piercing and Module.VisualizerEnabled == true, BulletVisualizer, WeaponEffects)
end

function WeaponFire:_FireProjectile(Start, Direction, ShootingHandle)
	local Module = self.Module
	local EndPosition = Start + Direction * ((Module.ProjectileSpeed or 500) * (Module.ProjectileLifetime or 10))
	WeaponProjectileVisual.Hide(self.Tool, Module)

	ProjectileFired:FireServer(self.Tool, Start, Direction)

	self.Projectiles:Fire(Start, Direction, {
		Speed = Module.ProjectileSpeed or 500,
		Gravity = Module.ProjectileGravity or Vector3.zero,
		MaxLifetime = Module.ProjectileLifetime or 10,
		ProjectileName = Module.ProjectileName,
		ProjectileFolderName = Module.ProjectileFolderName or "Projectiles",
		RaycastParams = self:_GetRaycastParams(),
		Data = {Tool=self.Tool, Character=self.Character, ShootingHandle=ShootingHandle},
		OnStep = function(Projectile) Projectile.LastPosition = Projectile.Position end,
		OnHit = function(Projectile, Result)
			local DirectionAtImpact = Projectile.Velocity.Magnitude > 0 and Projectile.Velocity.Unit or Direction
			if Module.ExplosiveEnabled == true then
				Explosion:FireServer(Result.Position, DirectionAtImpact, self.Tool, Start)
			else
				local Hit = Result.Instance
				local TargetModel = Hit and Hit:FindFirstAncestorOfClass("Model")
				local TargetHumanoid = TargetModel and TargetModel:FindFirstChildOfClass("Humanoid")
				local TargetTorso = TargetModel and (TargetModel:FindFirstChild("Torso") or TargetModel:FindFirstChild("HumanoidRootPart"))
				if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then self.InflictTarget:FireServer(TargetHumanoid, TargetTorso, Hit, DirectionAtImpact) end
			end
			self:_VisualizeHit(ShootingHandle, Result.Position, false, {Module.ExplosiveEnabled == true, Module.ExplosionRadius or 0, 0})
		end,
	})
	return EndPosition
end

function WeaponFire:Fire(ShootingHandle)
	local Module = self.Module
	local PierceAvailable = Module.Piercing or 0
	self.PiercedHumanoid = {}
	WeaponFireEffects.PlayFirePresentation(self.Tool, ShootingHandle, WeaponEffects)
	local FireAnim = self.GetFireAnim and self.GetFireAnim() or self.FireAnim
	if FireAnim then FireAnim:Play(nil, nil, Module.FireAnimationSpeed or 1) end
	local Start = (self.Humanoid.Torso.CFrame * CFrame.new(0, 1.5, 0)).Position
	local Direction = self:_GetDirection(Start)
	if Module.ProjectileType == "Projectile" then self:_FireProjectile(Start, Direction, ShootingHandle) return end

	while PierceAvailable >= 0 do
		local Hit, EndPos = self.Raycast(Start, Direction, 5000, self.Character, self.PiercedHumanoid)
		if not Module.ExplosiveEnabled then
			if Hit and Hit.Parent then
				local TargetHumanoid = Hit.Parent:FindFirstChild("Humanoid")
				local TargetTorso = Hit.Parent:FindFirstChild("Torso")
				if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then
					self.InflictTarget:FireServer(TargetHumanoid, TargetTorso, Hit, Direction)
					self.PiercedHumanoid[TargetHumanoid] = true
				else PierceAvailable = 0 end
			end
		else
			local ExplosionInstance = Instance.new("Explosion")
			ExplosionInstance.BlastRadius = Module.Radius or Module.ExplosionRadius or 0
			ExplosionInstance.BlastPressure = 0
			ExplosionInstance.Position = EndPos
			ExplosionInstance.Parent = Workspace.CurrentCamera
			ExplosionInstance.Hit:Connect(function(HitPart)
				if HitPart and HitPart.Parent and HitPart.Name == "Torso" then
					local TargetHumanoid = HitPart.Parent:FindFirstChild("Humanoid")
					local TargetTorso = HitPart.Parent:FindFirstChild("Torso")
					if TargetHumanoid and TargetHumanoid.Health > 0 and TargetTorso then self.InflictTarget:FireServer(TargetHumanoid, TargetTorso, HitPart, Direction) end
				end
			end)
			PierceAvailable = 0
		end
		PierceAvailable = Hit and (PierceAvailable - 1) or -1
		self:_VisualizeHit(ShootingHandle, EndPos, PierceAvailable == -1, {Module.ExplosiveEnabled == true, Module.BlastRadius or Module.ExplosionRadius or 0, Module.BlastPressure or 0})
		Start = EndPos + Direction * 0.01
	end
end

function WeaponFire:Destroy()
	if self.Projectiles then self.Projectiles:Destroy(); self.Projectiles = nil end
	WeaponProjectileVisual.Clear(self.Tool)
end

return WeaponFire