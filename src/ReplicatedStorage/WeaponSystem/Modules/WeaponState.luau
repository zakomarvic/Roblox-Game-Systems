local WeaponState = {}
WeaponState.__index = WeaponState

WeaponState.States = {
	Unequipped = "Unequipped",
	Equipped = "Equipped",
	Aiming = "Aiming",
	Firing = "Firing",
	Reloading = "Reloading",
	Throwing = "Throwing",
	MeleeAttacking = "MeleeAttacking",
	Disabled = "Disabled",
}

function WeaponState.new(weapon)
	local self = setmetatable({}, WeaponState)
	self.Weapon = weapon
	self.Current = WeaponState.States.Unequipped
	return self
end

function WeaponState:Get()
	return self.Current
end

function WeaponState:Set(state)
	if type(state) ~= "string" or state == "" then
		return false
	end

	self.Current = state
	return true
end

function WeaponState:Is(state)
	return self.Current == state
end

function WeaponState:Destroy()
	self.Weapon = nil
	self.Current = WeaponState.States.Unequipped
end

return WeaponState
