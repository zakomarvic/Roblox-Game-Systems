local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = workspace

local WeaponFire = {}
WeaponFire.__index = WeaponFire

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Remotes = WeaponSystem:WaitForChild("Remotes")
local WeaponEffects = Remotes:WaitForChild("WeaponEffects")
local Explosion = Remotes:WaitForChild("Explosion")
local ProjectileFired = Remotes:WaitForChild("ProjectileFired")
local RaycastDebug = Remotes:WaitForChild("RaycastDebug")
local ShotResult = Remotes:WaitForChild("ShotResult")
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

	self.ShotResultConnection = ShotResult.OnClientEvent:Connect(function(ResultTool, EndPosition, DidHitTarget)
		if ResultTool ~= self.Tool then return end
		if typeof(EndPosition) ~= "Vector3" then return end
		if not self.Tool or not self.Tool.Parent then return end

		local ShootingHandle = self.Tool:FindFirstChild("Handle") or self.Tool:FindFirstChild("Handle2")
		if not ShootingHandle or not ShootingHandle:IsA("BasePart") then return end

		local Module = self.Module
		local HitSounds = Module.HitSoundIDs
		local HitSound = nil
		if typeof(HitSounds) == "table" and #HitSounds > 0 then
			HitSound = HitSounds[math.random(1, #HitSounds)]
		end

		-- The server chose this endpoint. Do not perform another client raycast and
		-- do not send the visual back to the server again.
		BulletVisualizer.Visualize(
			ShootingHandle,
			Module.MuzzleOffset,
			EndPosition,
			self.MuzzleEffect,
			self.HitEffect,
			HitSound,
			{false, 0, 0},
			{Module.BulletSpeed, Module.BulletSize, Module.BulletColor, Module.BulletTransparency, Module.BulletMaterial, Module.FadeTime},
			false,
			Module.VisualizerEnabled == true
		)
	end)

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
	local Camera = Workspace.CurrentCamera
	local MouseLocation = UserInputService:GetMouseLocation()
	local AimDirection

	if Camera then
		local CameraRay = Camera:ViewportPointToRay(MouseLocation.X, MouseLocation.Y)
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {self.Character, self.Tool}
		Params.IgnoreWater = true

		local CameraResult = Workspace:Raycast(CameraRay.Origin, CameraRay.Direction * 5000, Params)
		local AimPoint = CameraResult and CameraResult.Position or (CameraRay.Origin + CameraRay.Direction * 5000)
		AimDirection = (AimPoint - Start).Magnitude > 0 and (AimPoint - Start).Unit or CameraRay.Direction
	else
		AimDirection = (self.Mouse.Hit.Position - Start).Magnitude > 0 and (self.Mouse.Hit.Position - Start).Unit or Vector3.zAxis
	end

	local Spread = self.Module.Spread or 0
	Spread *= (self.IsAiming and 1 - (self.Module.SpreadRedution or 0) or 1)
	return (CFrame.lookAt(Start, Start + AimDirection) * CFrame.Angles(math.rad(-Spread + math.random() * (Spread * 2)), math.rad(-Spread + math.random() * (Spread * 2)), 0)).LookVector
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
	WeaponFireEffects.PlayFirePresentation(self.Tool, ShootingHandle, WeaponEffects)
	local FireAnim = self.GetFireAnim and self.GetFireAnim() or self.FireAnim
	if FireAnim then FireAnim:Play(nil, nil, Module.FireAnimationSpeed or 1) end
	local Start = (self.Humanoid.Torso.CFrame * CFrame.new(0, 1.5, 0)).Position
	local Direction = self:_GetDirection(Start)
	if Module.ProjectileType == "Projectile" then self:_FireProjectile(Start, Direction, ShootingHandle) return end

	-- Hitscan is now fully server-authoritative. The client only supplies the
	-- shot origin and direction; the server selects the hit and sends the final
	-- endpoint back for the tracer.
	self.InflictTarget:FireServer(Start, Direction)

	-- Optional diagnostic ray. This is never involved in damage or visuals.
	RaycastDebug:FireServer(self.Tool, Start, Direction)
end

function WeaponFire:Destroy()
	if self.ShotResultConnection then
		self.ShotResultConnection:Disconnect()
		self.ShotResultConnection = nil
	end
	if self.Projectiles then self.Projectiles:Destroy(); self.Projectiles = nil end
	WeaponProjectileVisual.Clear(self.Tool)
end

return WeaponFire