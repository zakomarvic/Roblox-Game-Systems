local RegionDefinitions = {}

RegionDefinitions.Types = {
	SafeZone = {
		FireWeapon = false,
		TakeDamage = false,
		Combat = false,
		Arrest = false,
	},
	CombatZone = {
		FireWeapon = true,
		TakeDamage = true,
		Combat = true,
		Arrest = true,
	},
	RestrictedZone = {
		FireWeapon = true,
		TakeDamage = true,
		Combat = true,
		Arrest = false,
	},
}

return RegionDefinitions
