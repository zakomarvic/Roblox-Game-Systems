local RunService = game:GetService("RunService")

local WeaponController = {}
WeaponController.__index = WeaponController

local ProjectileController
if RunService:IsClient() then
	local WeaponSystem = script.Parent.Parent
	ProjectileController = require(WeaponSystem:WaitForChild("Projectile"):WaitForChild("ProjectileController"))
end

function WeaponController.new(Tool, Settings)
	local self = setmetatable({}, WeaponController)

	self.Tool = Tool
	self.Settings = Settings
	self.Ammo = Settings.AmmoPerClip
	self.Clips = Settings.LimitedClipEnabled and Settings.Clips or 0
	self.IsFiring = false
	self.IsReloading = false
	self.LastFireTime = 0
	self.Enabled = true
	self.TriggerHeld = false
	self.Projectiles = ProjectileController and ProjectileController.new() or nil

	return self
end

function WeaponController:GetSetting(Name) return self.Settings[Name] end
function WeaponController:GetAmmo() return self.Ammo end
function WeaponController:GetClips() return self.Clips end
function WeaponController:SetAmmo(Amount) self.Ammo = Amount end
function WeaponController:SetClips(Amount) self.Clips = Amount end

function WeaponController:ConsumeAmmo(Amount)
	Amount = Amount or 1
	if self.Ammo == math.huge then return true end
	if self.Ammo < Amount then return false end
	self.Ammo -= Amount
	return true
end

function WeaponController:CanFire()
	if not self.Enabled or self.IsFiring or self.IsReloading then return false end
	return self.Ammo > 0 or self.Ammo == math.huge
end

function WeaponController:CanFireNow()
	if not self:CanFire() then return false end
	return os.clock() - self.LastFireTime >= (self.Settings.FireRate or 0)
end

function WeaponController:SetFiring(Value) self.IsFiring = Value end
function WeaponController:IsCurrentlyFiring() return self.IsFiring end
function WeaponController:SetReloading(Value) self.IsReloading = Value end
function WeaponController:IsCurrentlyReloading() return self.IsReloading end

function WeaponController:CanReload()
	if not self.Enabled or self.IsFiring or self.IsReloading then return false end
	if self.Ammo >= self.Settings.AmmoPerClip then return false end
	if self.Settings.LimitedClipEnabled and self.Clips <= 0 then return false end
	return true
end

function WeaponController:StartReload()
	if not self:CanReload() then return false end
	self.IsReloading = true
	return true
end

function WeaponController:FinishReload()
	if not self.IsReloading then return end
	local Needed = self.Settings.AmmoPerClip - self.Ammo
	if self.Settings.LimitedClipEnabled then
		Needed = math.min(Needed, self.Clips)
		self.Clips -= Needed
	end
	self.Ammo += Needed
	self.IsReloading = false
end

function WeaponController:SetEnabled(Value) self.Enabled = Value end
function WeaponController:IsEnabled() return self.Enabled end
function WeaponController:SetTriggerHeld(Value) self.TriggerHeld = Value end
function WeaponController:IsTriggerHeld() return self.TriggerHeld end
function WeaponController:GetReloading() return self.IsReloading end

function WeaponController:StartFiring()
	if not self:CanFire() then return false end
	self.IsFiring = true
	self.LastFireTime = os.clock()
	return true
end

function WeaponController:StopFiring() self.IsFiring = false end
function WeaponController:IsProjectile() return self.Settings.ProjectileType == "Projectile" end
function WeaponController:IsHitscan() return self.Settings.ProjectileType ~= "Projectile" end

function WeaponController:FireProjectile(Origin, Direction, Data)
	if not self.Projectiles or not self:IsProjectile() then return nil end
	Data = Data or {}
	Data.Speed = Data.Speed or self.Settings.ProjectileSpeed or 500
	Data.Gravity = Data.Gravity or self.Settings.ProjectileGravity or Vector3.zero
	Data.Lifetime = Data.Lifetime or self.Settings.ProjectileLifetime or 10
	return self.Projectiles:Fire(Origin, Direction, Data)
end

function WeaponController:Destroy()
	if self.Projectiles then
		self.Projectiles:Destroy()
		self.Projectiles = nil
	end
end

return WeaponController
