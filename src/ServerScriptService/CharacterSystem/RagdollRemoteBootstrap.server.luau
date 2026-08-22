local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterSystem = ReplicatedStorage:WaitForChild("CharacterSystem")
local Remotes = CharacterSystem:FindFirstChild("Remotes")

if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = CharacterSystem
end

local RagdollRemote = Remotes:FindFirstChild("RagdollRemote")

if not RagdollRemote then
	RagdollRemote = Instance.new("RemoteEvent")
	RagdollRemote.Name = "RagdollRemote"
	RagdollRemote.Parent = Remotes
end
