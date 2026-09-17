-- Initializes the centralized character state service for every player and NPC.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CharacterStateService = require(script.Parent:WaitForChild("CharacterStateService"))

local function setupCharacter(character)
	if character and character:IsA("Model") and character:FindFirstChildOfClass("Humanoid") then
		CharacterStateService.Initialize(character)
	end
end

local function setupPlayer(player)
	if player.Character then
		setupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, descendant in ipairs(Workspace:GetDescendants()) do
	if descendant:IsA("Humanoid") and descendant.Parent and descendant.Parent:IsA("Model") then
		setupCharacter(descendant.Parent)
	end
end

Workspace.DescendantAdded:Connect(function(descendant)
	if not descendant:IsA("Humanoid") then
		return
	end

	local character = descendant.Parent
	if character and character:IsA("Model") then
		task.defer(setupCharacter, character)
	end
end)
