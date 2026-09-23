local ItemDefinitions = {}

ItemDefinitions.Types = {
	Weapon = "Weapon",
	Consumable = "Consumable",
	Equipment = "Equipment",
	Misc = "Misc",
}

ItemDefinitions.Items = {
	Medkit = {
		Id = "Medkit",
		Type = ItemDefinitions.Types.Consumable,
		DisplayName = "Medkit",
	},

	Armor = {
		Id = "Armor",
		Type = ItemDefinitions.Types.Equipment,
		DisplayName = "Armor",
	},

	AmmoPack = {
		Id = "AmmoPack",
		Type = ItemDefinitions.Types.Consumable,
		DisplayName = "Ammo Pack",
	},

	AK47 = {
		Id = "AK47",
		Type = ItemDefinitions.Types.Weapon,
		DisplayName = "AK-47",
		ToolName = "AK-47(but better)",
		StarterCount = 1,
	},

	RPG7 = {
		Id = "RPG7",
		Type = ItemDefinitions.Types.Weapon,
		DisplayName = "RPG-7",
		ToolName = "RPG-7",
		StarterCount = 1,
	},

	MeleeTest = {
		Id = "MeleeTest",
		Type = ItemDefinitions.Types.Weapon,
		DisplayName = "Melee Test",
		ToolName = "MeleeTest",
		StarterCount = 1,
	},
}

function ItemDefinitions.Get(itemId)
	if type(itemId) ~= "string" then
		return nil
	end

	return ItemDefinitions.Items[itemId]
end

function ItemDefinitions.Exists(itemId)
	return ItemDefinitions.Get(itemId) ~= nil
end

return ItemDefinitions
