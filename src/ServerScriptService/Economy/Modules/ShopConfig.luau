local ShopConfig = {
	Items = {
		{
			Id = "Medkit",
			DisplayName = "Medkit",
			Price = 250,
		},
		{
			Id = "Armor",
			DisplayName = "Armor",
			Price = 500,
		},
		{
			Id = "AmmoPack",
			DisplayName = "Ammo Pack",
			Price = 150,
		},
	},
}

function ShopConfig.GetItem(ItemId)
	for _, Item in ipairs(ShopConfig.Items) do
		if Item.Id == ItemId then
			return Item
		end
	end
	return nil
end

return ShopConfig