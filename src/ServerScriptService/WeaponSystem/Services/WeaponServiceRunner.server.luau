local Players = game:GetService("Players")

local WeaponService = require(script.Parent:WaitForChild("WeaponService"))

local function TryInitialize(Instance)
	if not Instance:IsA("Tool") then
		return
	end

	if not Instance:FindFirstChild("Setting") then
		return
	end

	WeaponService.Initialize(Instance)
end

local function WatchContainer(Container)
	for _, Child in ipairs(Container:GetChildren()) do
		TryInitialize(Child)
	end

	Container.ChildAdded:Connect(TryInitialize)
end

local function WatchPlayer(Player)
	WatchContainer(Player:WaitForChild("Backpack"))

	local function OnCharacter(Character)
		WatchContainer(Character)
	end

	if Player.Character then
		OnCharacter(Player.Character)
	end

	Player.CharacterAdded:Connect(OnCharacter)
end

for _, Player in ipairs(Players:GetPlayers()) do
	WatchPlayer(Player)
end

Players.PlayerAdded:Connect(WatchPlayer)