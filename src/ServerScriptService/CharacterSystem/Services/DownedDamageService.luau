local DownedService = {}

local Players = game:GetService("Players")

local MAX_HEALTH = 110
local DOWNED_HEALTH = 1
local DOWNED_INVULNERABILITY_DURATION = 0.3
local DOWNED_ATTRIBUTE = "Downed"
local REVIVING_ATTRIBUTE = "Reviving"
local DOWNED_IMAGE = "rbxassetid://8121963838"
local DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE = "DownedInvulnerableUntil"

local CharacterConnections = {}

local function removeDownedIndicator(character)
	local head = character:FindFirstChild("Head")
	if not head then return end
	local indicator = head:FindFirstChild("DownedIndicator")
	if indicator then indicator:Destroy() end
end

local function addDownedIndicator(character)
	local head = character:FindFirstChild("Head")
	if not head then return end
	removeDownedIndicator(character)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DownedIndicator"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(56, 56)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.ResetOnSpawn = false
	billboard.Parent = head

	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = DOWNED_IMAGE
	image.Parent = billboard
end

local function setDowned(character, humanoid)
	if not character.Parent or not humanoid or humanoid.Health <= 0 then return false end
	if character:GetAttribute(DOWNED_ATTRIBUTE) then return false end

	character:SetAttribute(DOWNED_ATTRIBUTE, true)
	character:SetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE, os.clock() + DOWNED_INVULNERABILITY_DURATION)
	humanoid.Health = DOWNED_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	addDownedIndicator(character)
	return true
end

local function clearDowned(character, humanoid)
	if not character then return false end
	local wasDowned = character:GetAttribute(DOWNED_ATTRIBUTE) == true
	character:SetAttribute(DOWNED_ATTRIBUTE, false)
	character:SetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE, nil)
	removeDownedIndicator(character)
	return wasDowned
end

local function setupCharacter(character)
	if not character:IsA("Model") or CharacterConnections[character] then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	CharacterConnections[character] = true
	clearDowned(character, humanoid)
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)

	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	local originalAutoRotate = humanoid.AutoRotate

	character:GetAttributeChangedSignal(DOWNED_ATTRIBUTE):Connect(function()
		if character:GetAttribute(DOWNED_ATTRIBUTE) then return end
		if humanoid.Health > 0 then
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.JumpPower = originalJumpPower
			humanoid.AutoRotate = originalAutoRotate
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then CharacterConnections[character] = nil end
	end)
end

function DownedService.Down(targetHumanoid)
	if not targetHumanoid or not targetHumanoid:IsA("Humanoid") then return false end
	local character = targetHumanoid.Parent
	if not character or not character:IsA("Model") then return false end
	return setDowned(character, targetHumanoid)
end

function DownedService.Clear(targetHumanoid)
	if not targetHumanoid or not targetHumanoid:IsA("Humanoid") then return false end
	local character = targetHumanoid.Parent
	if not character or not character:IsA("Model") then return false end
	return clearDowned(character, targetHumanoid)
end

function DownedService.IsDowned(targetHumanoid)
	local character = targetHumanoid and targetHumanoid.Parent
	return character ~= nil and character:IsA("Model") and character:GetAttribute(DOWNED_ATTRIBUTE) == true
end

function DownedService.IsInvulnerable(targetHumanoid)
	local character = targetHumanoid and targetHumanoid.Parent
	if not character or not character:IsA("Model") then return false end
	local untilTime = character:GetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE)
	return type(untilTime) == "number" and os.clock() < untilTime
end

function DownedService.SetupCharacter(character)
	setupCharacter(character)
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then setupCharacter(player.Character) end
	player.CharacterAdded:Connect(setupCharacter)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then setupCharacter(player.Character) end
end)

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Humanoid") and descendant.Parent and descendant.Parent:IsA("Model") then
		if not Players:GetPlayerFromCharacter(descendant.Parent) then setupCharacter(descendant.Parent) end
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if not descendant:IsA("Humanoid") then return end
	local character = descendant.Parent
	if character and character:IsA("Model") and not Players:GetPlayerFromCharacter(character) then
		setupCharacter(character)
	end
end)

return DownedService
