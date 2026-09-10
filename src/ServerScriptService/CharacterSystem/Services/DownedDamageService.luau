local DownedDamageService = {}

local Players = game:GetService("Players")

local MAX_HEALTH = 110
local DOWNED_HEALTH_THRESHOLD = 10
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

local function isDownedInvulnerable(character)
	local untilTime = character:GetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE)
	return type(untilTime) == "number" and os.clock() < untilTime
end

local function setDowned(character)
	if not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if character:GetAttribute(DOWNED_ATTRIBUTE) then return end

	character:SetAttribute(DOWNED_ATTRIBUTE, true)
	character:SetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE, os.clock() + DOWNED_INVULNERABILITY_DURATION)
	humanoid.Health = DOWNED_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	addDownedIndicator(character)
end

local function clearDowned(character)
	if not character then return end
	character:SetAttribute(DOWNED_ATTRIBUTE, false)
	character:SetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE, nil)
	removeDownedIndicator(character)
end

local function setupCharacter(character)
	if not character:IsA("Model") or CharacterConnections[character] then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	CharacterConnections[character] = true
	clearDowned(character)
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.BreakJointsOnDeath = false

	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	local originalAutoRotate = humanoid.AutoRotate

	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if not character.Parent then return end
		if character:GetAttribute(DOWNED_ATTRIBUTE) then
			if isDownedInvulnerable(character) and humanoid.Health < DOWNED_HEALTH then
				humanoid.Health = DOWNED_HEALTH
			end
			if humanoid.WalkSpeed ~= 0 then humanoid.WalkSpeed = 0 end
			if humanoid.JumpPower ~= 0 then humanoid.JumpPower = 0 end
			return
		end

		if humanoid.Health <= 0 then
			-- Damage routed through DownedDamageService decides whether a lethal
			-- hit becomes Downed or remains a normal Humanoid death. This fallback
			-- keeps direct external Health changes using the normal downed behavior.
			humanoid.Health = DOWNED_HEALTH
			setDowned(character)
			return
		end

		if humanoid.Health <= DOWNED_HEALTH_THRESHOLD and not character:GetAttribute(REVIVING_ATTRIBUTE) then
			setDowned(character)
		end
	end)

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

function DownedDamageService.ApplyDamage(targetHumanoid, damage, overkill)
	if not targetHumanoid or not targetHumanoid:IsA("Humanoid") then return false end
	if type(damage) ~= "number" or damage <= 0 or targetHumanoid.Health <= 0 then return false end

	local character = targetHumanoid.Parent
	if not character or not character:IsA("Model") then return false end

	local isOverkill = overkill == true

	-- Overkill explicitly bypasses the 0.3 second protection after Downed.
	if character:GetAttribute(DOWNED_ATTRIBUTE) then
		if not isOverkill and isDownedInvulnerable(character) then
			return false
		end

		targetHumanoid:TakeDamage(damage)
		return true
	end

	-- For normal weapons, never let a lethal hit pass through to Roblox death.
	-- Convert it directly to Downed using the damage request's Overkill value.
	if not isOverkill and targetHumanoid.Health - damage <= 0 then
		setDowned(character)
		return true
	end

	targetHumanoid:TakeDamage(damage)
	return true
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

return DownedDamageService
