local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Items = {
	{Id = "Medkit", DisplayName = "Medkit", Price = 250},
	{Id = "Armor", DisplayName = "Armor", Price = 500},
	{Id = "AmmoPack", DisplayName = "Ammo Pack", Price = 150},
}

local function formatCash(Value)
	local Text = tostring(math.floor(tonumber(Value) or 0))
	while true do
		local New, Count = Text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		Text = New
		if Count == 0 then break end
	end
	return "$" .. Text
end

local function corner(Object, Radius)
	local C = Instance.new("UICorner")
	C.CornerRadius = UDim.new(0, Radius)
	C.Parent = Object
end

local function stroke(Object, Transparency)
	local S = Instance.new("UIStroke")
	S.Color = Color3.fromRGB(70, 76, 86)
	S.Transparency = Transparency or 0
	S.Thickness = 1
	S.Parent = Object
end

local function label(Name, Parent, Text, Position, Size, TextSize, Color, Font)
	local L = Instance.new("TextLabel")
	L.Name = Name
	L.BackgroundTransparency = 1
	L.Position = Position
	L.Size = Size
	L.Font = Font or Enum.Font.GothamMedium
	L.Text = Text
	L.TextColor3 = Color
	L.TextSize = TextSize
	L.TextXAlignment = Enum.TextXAlignment.Left
	L.Parent = Parent
	return L
end

local UI = PlayerGui:WaitForChild("ShopUI")

local ShopButton = UI:WaitForChild("ShopButton")
local ShopFrame = UI:WaitForChild("ShopFrame")
local CloseButton = ShopFrame:WaitForChild("Header"):WaitForChild("CloseButton")
local CashBalance = ShopFrame:WaitForChild("CashBalance")
local ItemsFrame = ShopFrame:WaitForChild("Items")
local Status = ShopFrame:WaitForChild("Status")
local PurchaseRemote = ReplicatedStorage:WaitForChild("EconomyRemotes"):WaitForChild("PurchaseItem")
local Cash = Player:WaitForChild("leaderstats"):WaitForChild("Cash")

local OpenPosition = ShopFrame.Position
local ClosedPosition = UDim2.new(OpenPosition.X.Scale, OpenPosition.X.Offset, OpenPosition.Y.Scale, OpenPosition.Y.Offset + 12)
local Busy = false

local function updateCash()
	CashBalance.Text = formatCash(Cash.Value)
end

local function setStatus(Text, Success)
	Status.Text = Text
	Status.TextColor3 = Success and Color3.fromRGB(78,220,120) or Color3.fromRGB(255,105,105)
end

local function openShop()
	if Busy or ShopFrame.Visible then return end
	Busy = true
	ShopFrame.Position = ClosedPosition
	ShopFrame.Visible = true
	local Tween = TweenService:Create(ShopFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = OpenPosition})
	Tween:Play()
	Tween.Completed:Wait()
	Busy = false
end

local function closeShop()
	if Busy or not ShopFrame.Visible then return end
	Busy = true
	local Tween = TweenService:Create(ShopFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = ClosedPosition})
	Tween:Play()
	Tween.Completed:Wait()
	ShopFrame.Visible = false
	ShopFrame.Position = OpenPosition
	Busy = false
end

ShopButton.MouseEnter:Connect(function()
	TweenService:Create(ShopButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(34,37,43)}):Play()
end)
ShopButton.MouseLeave:Connect(function()
	TweenService:Create(ShopButton, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(18,20,24)}):Play()
end)
ShopButton.Activated:Connect(openShop)
CloseButton.Activated:Connect(closeShop)

for _, Item in ipairs(Items) do
	local Button = ItemsFrame:WaitForChild(Item.Id)
	Button.MouseEnter:Connect(function()
		TweenService:Create(Button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(36,40,47)}):Play()
	end)
	Button.MouseLeave:Connect(function()
		TweenService:Create(Button, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(28,31,37)}):Play()
	end)
	Button.Activated:Connect(function()
		if Busy then return end
		Button.Active = false
		setStatus("Purchasing...", true)
		local CallSuccess, Purchased, Message = pcall(function()
			local Result, ResultMessage = PurchaseRemote:InvokeServer(Item.Id)
			return Result, ResultMessage
		end)
		Button.Active = true
		if not CallSuccess then
			setStatus("Purchase failed. Try again.", false)
			return
		end
		if not Purchased then
			setStatus(Message or "Purchase failed.", false)
			return
		end
		setStatus(Message or "Purchase complete.", true)
		updateCash()
	end)
end

Cash:GetPropertyChangedSignal("Value"):Connect(updateCash)
updateCash()