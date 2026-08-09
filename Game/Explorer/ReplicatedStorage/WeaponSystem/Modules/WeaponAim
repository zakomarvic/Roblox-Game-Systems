local WeaponAim = {}
WeaponAim.__index = WeaponAim

function WeaponAim.new(Camera, Player, Mouse, GUI, SensitivityScript, Settings, OnAimingChanged)
	local self = setmetatable({}, WeaponAim)
	self.Camera = Camera
	self.Player = Player
	self.Mouse = Mouse
	self.GUI = GUI
	self.SensitivityScript = SensitivityScript
	self.Settings = Settings
	self.OnAimingChanged = OnAimingChanged
	self.Aiming = false
	return self
end

function WeaponAim:SetAiming(State)
	self.Aiming = State == true
	self.Camera.FieldOfView = self.Aiming and self.Settings.FieldOfView or 70
	self.GUI.Scope.Visible = self.Aiming
	self.Player.CameraMode = self.Aiming and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
	self.SensitivityScript.Disabled = not self.Aiming
	self.Mouse.Icon = self.Aiming and "http://www.roblox.com/asset?id=187746799" or "rbxassetid://" .. self.Settings.MouseIconID
	if self.OnAimingChanged then
		self.OnAimingChanged(self.Aiming)
	end
end

function WeaponAim:IsAiming()
	return self.Aiming
end

function WeaponAim:Toggle()
	self:SetAiming(not self.Aiming)
end

function WeaponAim:Reset()
	self:SetAiming(false)
end

return WeaponAim
