local WeaponFireCycle = {}
WeaponFireCycle.__index = WeaponFireCycle

function WeaponFireCycle.new(Config)
	local self = setmetatable({}, WeaponFireCycle)
	self.Controller = Config.Controller
	self.Module = Config.Module
	self.CharacterController = Config.CharacterController
	self.Aim = Config.Aim
	self.Humanoid = Config.Humanoid
	self.WeaponFire = Config.WeaponFire
	self.FireEffects = Config.FireEffects
	self.GUI = Config.GUI
	self.Reload = Config.Reload
	self.Handle = Config.Handle
	self.Handle2 = Config.Handle2
	self.HandleToFire = self.Handle
	self.Wait = Config.Wait
	self.OnRecoil = Config.OnRecoil
	self.Equipped = false
	return self
end

function WeaponFireCycle:SetEquipped(Value)
	self.Equipped = Value == true
	if not self.Equipped then
		self.Controller:SetTriggerHeld(false)
	end
end

function WeaponFireCycle:SetHumanoid(Humanoid)
	self.Humanoid = Humanoid
end

function WeaponFireCycle:GetHandleToFire()
	return self.HandleToFire
end

function WeaponFireCycle:FireDown()
	local Module = self.Module
	local Controller = self.Controller
	local Humanoid = self.Humanoid

	if Module.SprintEnabled and self.CharacterController:IsSprinting() then
		return false
	end

	Controller:SetTriggerHeld(true)

	local IsChargedShot = false
	if not self.Equipped or not Controller:CanFireNow() or not Humanoid or Humanoid.Health <= 0 then
		return false
	end

	if not Controller:StartFiring() then
		return false
	end

	Controller:SetEnabled(false)

	if Module.ChargedShotEnabled then
		if self.FireEffects then
			self.FireEffects.PlaySound(self.HandleToFire, "ChargeSound")
		end
		self.Wait(Module.ChargingTime)
		IsChargedShot = true
	end

	if Module.MinigunEnabled then
		if self.FireEffects then
			self.FireEffects.PlaySound(self.HandleToFire, "WindUp")
		end
		self.Wait(Module.DelayBeforeFiring)
	end

	while self.Equipped
		and not Controller:GetReloading()
		and not (Module.SprintEnabled and self.CharacterController:IsSprinting())
		and (Controller:IsTriggerHeld() or IsChargedShot)
		and Controller:GetAmmo() > 0
		and Humanoid
		and Humanoid.Health > 0 do

		local BurstCount = Module.BurstFireEnabled and Module.BulletPerBurst or 1

		for _ = 1, BurstCount do
			if not self.Equipped
				or Controller:GetReloading()
				or (Module.SprintEnabled and self.CharacterController:IsSprinting())
				or not (Controller:IsTriggerHeld() or IsChargedShot)
				or Controller:GetAmmo() <= 0
				or not Humanoid
				or Humanoid.Health <= 0 then
				break
			end

			IsChargedShot = false

			if self.OnRecoil then
				task.spawn(self.OnRecoil)
			end

			local ShotCount = Module.ShotgunEnabled and Module.BulletPerShot or 1
			for _ = 1, ShotCount do
				self.WeaponFire:Fire(self.HandleToFire)
			end

			Controller:ConsumeAmmo(1)
			if self.GUI then
				self.GUI:Update()
			end

			if self.HandleToFire == self.Handle and Module.DualEnabled then
				self.HandleToFire = self.Handle2
			else
				self.HandleToFire = self.Handle
			end

			if Module.BurstFireEnabled then
				self.Wait(Module.BurstRate or 0)
			end
		end

		if not Module.Auto then
			break
		end

		self.Wait(Module.FireRate or 0)
	end

	Controller:StopFiring()
	Controller:SetEnabled(true)

	if self.FireEffects then
		self.FireEffects.StopLoopedSound(self.HandleToFire, "FireSound")
	end

	if Module.MinigunEnabled then
		if self.FireEffects then
			self.FireEffects.PlaySound(self.HandleToFire, "WindDown")
		end
		self.Wait(Module.DelayAfterFiring)
	end

	if Controller:GetAmmo() <= 0 and self.Reload then
		self.Reload:Start()
	end

	return true
end

function WeaponFireCycle:FireUp()
	self.Controller:SetTriggerHeld(false)
end

return WeaponFireCycle
