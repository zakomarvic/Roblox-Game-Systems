local Players = game:GetService("Players")

local DOWNED_HEALTH_THRESHOLD = 10
local DOWNED_HEALTH = 1
local DOWNED_ATTRIBUTE = "Downed"
local DOWNED_IMAGE = "rbxassetid://8121963838"

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
	humanoid.Health = DOWNED_HEALTH
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

	addDownedIndicator(character)
end

local function clearDowned(character)
	if not character then
		return
	end

	character:SetAttribute(DOWNED_ATTRIBUTE, false)
	removeDownedIndicator(character)
end

local function setupCharacter(character)
	clearDowned(character)

	local humanoid = character:WaitForChild("Humanoid")
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower

	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if not character.Parent then
			return
		end

		if humanoid.Health <= 0 then
			clearDowned(character)
			return
		end

		if character:GetAttribute(DOWNED_ATTRIBUTE) then
			if humanoid.WalkSpeed ~= 0 then
				humanoid.WalkSpeed = 0
			end
			if humanoid.JumpPower ~= 0 then
				humanoid.JumpPower = 0
			end
			return
		end

		if humanoid.Health <= DOWNED_HEALTH_THRESHOLD then
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
			humanoid.AutoRotate = true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
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
