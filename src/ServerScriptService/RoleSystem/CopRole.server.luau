local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")

local COPS_TEAM_NAME = "Cops"
local CUFFS_NAME = "Cuffs"

local CopsTeam = Teams:FindFirstChild(COPS_TEAM_NAME)
if not CopsTeam then
	CopsTeam = Instance.new("Team")
	CopsTeam.Name = COPS_TEAM_NAME
	CopsTeam.AutoAssignable = false
	CopsTeam.TeamColor = BrickColor.new("Bright blue")
	CopsTeam.Parent = Teams
end

local function giveCuffs(player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then return end
	if backpack:FindFirstChild(CUFFS_NAME) then return end
	local character = player.Character
	if character and character:FindFirstChild(CUFFS_NAME) then return end
	local source = ServerStorage:FindFirstChild(CUFFS_NAME)
	if not source or not source:IsA("Tool") then
		warn("Cops role could not give cuffs because ServerStorage.Cuffs does not exist")
		return
	end
	source:Clone().Parent = backpack
end

local function setupPlayer(player)
	local function onTeamChanged()
		if player.Team == CopsTeam then giveCuffs(player) end
	end
	player:GetPropertyChangedSignal("Team"):Connect(onTeamChanged)
	player.CharacterAdded:Connect(function() task.defer(onTeamChanged) end)
	onTeamChanged()
end

for _, player in ipairs(Players:GetPlayers()) do setupPlayer(player) end
Players.PlayerAdded:Connect(setupPlayer)