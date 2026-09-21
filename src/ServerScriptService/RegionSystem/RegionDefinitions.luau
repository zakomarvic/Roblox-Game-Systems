local RegionDefinitions = {}

RegionDefinitions.Types = {
	SafeZone = {
		WeaponsDisabled = true,
		DamageDisabled = true,
		CombatEnabled = false,
		ArrestAllowed = false,
	},
	CombatZone = {
		WeaponsDisabled = false,
		DamageDisabled = false,
		CombatEnabled = true,
		ArrestAllowed = true,
	},
	RestrictedZone = {
		WeaponsDisabled = false,
		DamageDisabled = false,
		CombatEnabled = true,
		ArrestAllowed = false,
	},
}

return RegionDefinitions
