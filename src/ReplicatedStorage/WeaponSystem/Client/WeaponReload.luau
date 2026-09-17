local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponReload = {}
WeaponReload.__index = WeaponReload

local WeaponProjectileVisual = require(ReplicatedStorage.WeaponSystem.Client:WaitForChild("WeaponProjectileVisual"))

function WeaponReload.new(Options)
	local self = setmetatable({}, WeaponReload)

	self.Tool = Options.Tool
	self.Module = Options.Module
	self.Controller = Options.Controller
	self.Handle = Options.Handle
	self.PlayReloadAnim = Options.PlayReloadAnim
	self.PlayShotgunClipinAnim = Options.PlayShotgunClipinAnim
	self.GetReloadAnim = Options.GetReloadAnim
	self.GetShotgunClipinAnim = Options.GetShotgunClipinAnim
	self.ReloadEffects = Options.ReloadEffects
	self.WeaponEffects = Options.WeaponEffects
	self.IsSprinting = Options.IsSprinting
	self.IsAiming = Options.IsAiming
	self.ResetAim = Options.ResetAim
	self.UpdateGUI = Options.UpdateGUI
	self.Wait = Options.Wait or task.wait

	return self
end

function WeaponReload:Start()
	local Module = self.Module
	local Controller = self.Controller

	if self.IsSprinting and self.IsSprinting() then return false end
	if not Controller:CanReload() then return false end
	if not Controller:StartReload() then return false end

	if self.IsAiming and self.IsAiming() and self.ResetAim then self.ResetAim() end
	if self.UpdateGUI then self.UpdateGUI() end

	local Shells = Module.AmmoPerClip - Controller:GetAmmo()
	if Module.ShotgunReload then
		for _ = 1, Shells do
			if self.PlayShotgunClipinAnim then
				self.PlayShotgunClipinAnim(Module.ShotgunClipinAnimationSpeed)
			elseif self.GetShotgunClipinAnim then
				local Track = self.GetShotgunClipinAnim()
				if Track then Track:Play(nil, nil, Module.ShotgunClipinAnimationSpeed) end
			end

			if self.ReloadEffects then self.ReloadEffects.PlayShotgunInsert(self.Handle) end
			self.Wait(Module.ShellClipinSpeed)
		end
	end

	if self.PlayReloadAnim then
		self.PlayReloadAnim(Module.ReloadAnimationSpeed)
	elseif self.GetReloadAnim then
		local Track = self.GetReloadAnim()
		if Track then Track:Play(nil, nil, Module.ReloadAnimationSpeed) end
	end

	if self.ReloadEffects then
		self.ReloadEffects.PlayReload(self.Handle)
		self.ReloadEffects.Broadcast(self.Tool, self.WeaponEffects)
	end

	self.Wait(Module.ReloadTime)
	Controller:FinishReload()
	WeaponProjectileVisual.Restore(self.Tool, Module)
	if self.UpdateGUI then self.UpdateGUI() end
	return true
end

return WeaponReload