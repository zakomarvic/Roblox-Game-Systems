local Players = game:GetService("Players")

local MAX_HEALTH = 110
local DOWNED_HEALTH_THRESHOLD = 10
local DOWNED_HEALTH = 1
local DOWNED_INVULNERABILITY_DURATION = 1
local DOWNED_ATTRIBUTE = "Downed"
local REVIVING_ATTRIBUTE = "Reviving"
local DOWNED_IMAGE = "rbxassetid://8121963838"
local DAMAGE_OVERKILL_ATTRIBUTE = "DownedDamageOverkill"
local DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE = "DownedInvulnerableUntil"

local CharacterConnections = {}

local function removeDownedIndicator(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local indicator = head:FindFirstChild("DownedIndicator")
	if indicator then
		indicator:Destroy()
	end
end

local function addDownedIndicator(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

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
	if not character.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if character:GetAttribute(DOWNED_ATTRIBUTE) then
		return
	end

	character:SetAttribute(DOWNED_ATTRIBUTE, true)
	character:SetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE, os.clock() + DOWNED_INVULNERABILITY_DURATION)
	humanoid.Health = DOWNED_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	-- Keep the Humanoid from trying to stand while the custom downed
	-- animation tracks are playing. Dead remains enabled so a downed
	-- character can actually die after the protection window.
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	addDownedIndicator(character)
end

local function clearDowned(character)
	if not character then
		return
	end

	character:SetAttribute(DOWNED_ATTRIBUTE, false)
	character:SetAttribute(DOWNED_INVULNERABLE_UNTIL_ATTRIBUTE, nil)
	removeDownedIndicator(character)
end

local function setupCharacter(character)
	if not character:IsA("Model") or CharacterConnections[character] then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	CharacterConnections[character] = true
	clearDowned(character)

	-- Every character uses the same health pool for the downing system.
	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.BreakJointsOnDeath = false

	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	local originalAutoRotate = humanoid.AutoRotate

	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if not character.Parent then
			return
		end

		if character:GetAttribute(DOWNED_ATTRIBUTE) then
			if isDownedInvulnerable(character) and humanoid.Health < DOWNED_HEALTH then
				humanoid.Health = DOWNED_HEALTH
			end

			if humanoid.WalkSpeed ~= 0 then
				humanoid.WalkSpeed = 0
			end
			if humanoid.JumpPower ~= 0 then
				humanoid.JumpPower = 0
			end
			return
		end

		if humanoid.Health <= 0 then
			-- Overkill is supplied by the weapon that applied the damage.
			-- When disabled, convert lethal damage into a downed state.
			if character:GetAttribute(DAMAGE_OVERKILL_ATTRIBUTE) == true then
				return
			end

			humanoid.Health = DOWNED_HEALTH
			setDowned(character)
			return
		end

		if humanoid.Health <= DOWNED_HEALTH_THRESHOLD and not character:GetAttribute(REVIVING_ATTRIBUTE) then
			setDowned(character)
		end
	end)

	character:GetAttributeChangedSignal(DOWNED_ATTRIBUTE):Connect(function()
		if character:GetAttribute(DOWNED_ATTRIBUTE) then
			return
		end

		if humanoid.Health > 0 then
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.JumpPower = originalJumpPower
			humanoid.AutoRotate = originalAutoRotate
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			CharacterConnections[character] = nil
		end
	end)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(setupCharacter)

	if player.Character then
		setupCharacter(player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Humanoid") and descendant.Parent and descendant.Parent:IsA("Model") then
		if not Players:GetPlayerFromCharacter(descendant.Parent) then
			setupCharacter(descendant.Parent)
		end
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if not descendant:IsA("Humanoid") then
		return
	end

	local character = descendant.Parent
	if character and character:IsA("Model") and not Players:GetPlayerFromCharacter(character) then
		setupCharacter(character)
	end
end)