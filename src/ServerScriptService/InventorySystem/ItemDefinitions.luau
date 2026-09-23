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
