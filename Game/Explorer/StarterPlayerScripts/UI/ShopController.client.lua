local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local PurchaseItem = ReplicatedStorage:WaitForChild("EconomyRemotes"):WaitForChild("PurchaseItem")

local ShopGui = PlayerGui:WaitForChild("ShopUI")
local ShopFrame = ShopGui:WaitForChild("ShopFrame")
local Status = ShopFrame:WaitForChild("Status")

local function connectPurchase(Button, ItemId)
	Button.Activated:Connect(function()
		Button.Active = false
		local Success, Message = PurchaseItem:InvokeServer(ItemId)
		Status.Text = Message
		Button.Active = true
	end)
end

connectPurchase(ShopFrame:WaitForChild("MedkitButton"), "Medkit")
connectPurchase(ShopFrame:WaitForChild("ArmorButton"), "Armor")
connectPurchase(ShopFrame:WaitForChild("AmmoPackButton"), "AmmoPack")
