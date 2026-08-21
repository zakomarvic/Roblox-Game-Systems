local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CashUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.DisplayOrder = 20
ScreenGui.Parent = PlayerGui

local Container = Instance.new("Frame")
Container.Name = "CashContainer"
Container.AnchorPoint = Vector2.new(1, 0)
Container.Position = UDim2.new(1, -24, 0, 24)
Container.Size = UDim2.new(0, 210, 0, 58)
Container.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
Container.BackgroundTransparency = 0.08
Container.BorderSizePixel = 0
Container.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 14)
Corner.Parent = Container

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(70, 76, 86)
Stroke.Transparency = 0.35
Stroke.Thickness = 1
Stroke.Parent = Container

local Icon = Instance.new("Frame")
Icon.Name = "Icon"
Icon.Position = UDim2.new(0, 8, 0.5, -21)
Icon.Size = UDim2.new(0, 42, 0, 42)
Icon.BackgroundColor3 = Color3.fromRGB(42, 181, 92)
Icon.BorderSizePixel = 0
Icon.Parent = Container

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0)
IconCorner.Parent = Icon

local IconText = Instance.new("TextLabel")
IconText.Name = "Dollar"
IconText.BackgroundTransparency = 1
IconText.Size = UDim2.fromScale(1, 1)
IconText.Font = Enum.Font.GothamBold
IconText.Text = "$"
IconText.TextColor3 = Color3.new(1, 1, 1)
IconText.TextSize = 24
IconText.Parent = Icon

local Balance = Instance.new("TextLabel")
Balance.Name = "Balance"
Balance.BackgroundTransparency = 1
Balance.Position = UDim2.new(0, 60, 0, 5)
Balance.Size = UDim2.new(1, -70, 0, 32)
Balance.Font = Enum.Font.GothamBold
Balance.Text = "$0"
Balance.TextColor3 = Color3.new(1, 1, 1)
Balance.TextSize = 24
Balance.TextXAlignment = Enum.TextXAlignment.Left
Balance.Parent = Container

local Caption = Instance.new("TextLabel")
Caption.Name = "Caption"
Caption.BackgroundTransparency = 1
Caption.Position = UDim2.new(0, 61, 0, 34)
Caption.Size = UDim2.new(1, -70, 0, 18)
Caption.Font = Enum.Font.GothamMedium
Caption.Text = "CASH"
Caption.TextColor3 = Color3.fromRGB(170, 176, 186)
Caption.TextSize = 11
Caption.TextXAlignment = Enum.TextXAlignment.Left
Caption.Parent = Container

local Scale = Instance.new("UIScale")
Scale.Scale = 1
Scale.Parent = Container

local function formatCash(Amount)
	Amount = math.floor(tonumber(Amount) or 0)
	local Formatted = tostring(Amount)
	while true do
		local Updated, Count = Formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		Formatted = Updated
		if Count == 0 then
			break
		end
	end
	return "$" .. Formatted
end

local function animateBalance()
	Scale.Scale = 1.04
	TweenService:Create(
		Scale,
		TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = 1}
	):Play()
end

local function showDelta(Delta)
	if Delta == 0 then
		return
	end

	local DeltaLabel = Instance.new("TextLabel")
	DeltaLabel.Name = "CashDelta"
	DeltaLabel.BackgroundTransparency = 1
	DeltaLabel.AnchorPoint = Vector2.new(1, 0)
	DeltaLabel.Position = UDim2.new(1, -10, 0, 42)
	DeltaLabel.Size = UDim2.new(0, 150, 0, 24)
	DeltaLabel.Font = Enum.Font.GothamBold
	DeltaLabel.Text = string.format("%s$%d", Delta > 0 and "+" or "-", math.abs(Delta))
	DeltaLabel.TextColor3 = Delta > 0 and Color3.fromRGB(78, 220, 120) or Color3.fromRGB(255, 105, 105)
	DeltaLabel.TextSize = 15
	DeltaLabel.TextTransparency = 0
	DeltaLabel.TextXAlignment = Enum.TextXAlignment.Right
	DeltaLabel.ZIndex = 5
	DeltaLabel.Parent = Container

	local TargetPosition = UDim2.new(1, -10, 0, 62)
	local Tween = TweenService:Create(
		DeltaLabel,
		TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = TargetPosition,
			TextTransparency = 1,
		}
	)
	Tween:Play()
	Tween.Completed:Connect(function()
		DeltaLabel:Destroy()
	end)
end

local Leaderstats = Player:WaitForChild("leaderstats")
local Cash = Leaderstats:WaitForChild("Cash")
local PreviousValue = Cash.Value

Balance.Text = formatCash(PreviousValue)

Cash:GetPropertyChangedSignal("Value"):Connect(function()
	local NewValue = Cash.Value
	local Delta = NewValue - PreviousValue
	PreviousValue = NewValue

	Balance.Text = formatCash(NewValue)
	animateBalance()
	showDelta(Delta)
end)
