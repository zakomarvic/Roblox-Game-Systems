local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local CashUI = PlayerGui:WaitForChild("CashUI")
local Container = CashUI:WaitForChild("CashContainer")
local Scale = Container:WaitForChild("UIScale")
local Balance = Container:WaitForChild("Balance")

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