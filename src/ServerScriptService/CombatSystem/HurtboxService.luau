local HurtboxService = {}

local Players = game:GetService("Players")

local HURTBOX_FOLDER_NAME = "Hurtboxes"
local HURTBOX_ATTRIBUTE = "Hurtbox"
local BODY_PART_ATTRIBUTE = "HurtboxBodyPart"
local HURTBOX_SIZE_MULTIPLIER = 1.05

local R6_PARTS = {
	"Head",
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

local R15_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local Characters = {}

local function getPartNames(humanoid)
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return R15_PARTS
	end
	return R6_PARTS
end

local function getFolder(character)
	return character:FindFirstChild(HURTBOX_FOLDER_NAME)
end

local function isHurtbox(instance)
	return instance
		and instance:IsA("BasePart")
		and instance:GetAttribute(HURTBOX_ATTRIBUTE) == true
end

local function createHurtbox(character, bodyPart)
	local hurtbox = Instance.new("Part")
	hurtbox.Name = "Hurtbox_" .. bodyPart.Name:gsub("%s+", "_")
	hurtbox.Size = bodyPart.Size * HURTBOX_SIZE_MULTIPLIER
	hurtbox.CFrame = bodyPart.CFrame
	hurtbox.Transparency = 1
	hurtbox.Anchored = false
	hurtbox.CanCollide = false
	hurtbox.CanTouch = false
	hurtbox.CanQuery = true
	hurtbox.Massless = true
	hurtbox.CastShadow = false
	hurtbox:SetAttribute(HURTBOX_ATTRIBUTE, true)
	hurtbox:SetAttribute(BODY_PART_ATTRIBUTE, bodyPart.Name)
	hurtbox.Parent = getFolder(character)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hurtbox
	weld.Part1 = bodyPart
	weld.Parent = hurtbox

	return hurtbox
end

local function destroyHurtboxes(character)
	local folder = getFolder(character)
	if folder then
		folder:Destroy()
	end
end

local function setupCharacter(character)
	if not character or not character:IsA("Model") or Characters[character] then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local folder = Instance.new("Folder")
	folder.Name = HURTBOX_FOLDER_NAME
	folder.Parent = character

	local originalQueryStates = {}
	Characters[character] = {
		Folder = folder,
		OriginalQueryStates = originalQueryStates,
	}

	for _, partName in ipairs(getPartNames(humanoid)) do
		local bodyPart = character:FindFirstChild(partName)
		if bodyPart and bodyPart:IsA("BasePart") then
			originalQueryStates[bodyPart] = bodyPart.CanQuery
			bodyPart.CanQuery = false
			createHurtbox(character, bodyPart)
		end
	end

	character.AncestryChanged:Connect(function(_, parent)
		if parent ~= nil then
			return
		end

		local state = Characters[character]
		if state then
			for bodyPart, canQuery in pairs(state.OriginalQueryStates) do
				if bodyPart and bodyPart.Parent then
					bodyPart.CanQuery = canQuery
				end
			end
		end
		Characters[character] = nil
	end)

	return true
end

function HurtboxService.SetupCharacter(character)
	return setupCharacter(character)
end

function HurtboxService.IsHurtbox(instance)
	return isHurtbox(instance)
end

function HurtboxService.GetCharacter(instance)
	if not isHurtbox(instance) then
		return nil
	end
	return instance:FindFirstAncestorOfClass("Model")
end

function HurtboxService.GetHumanoid(instance)
	local character = HurtboxService.GetCharacter(instance)
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function HurtboxService.GetBodyPartName(instance)
	if not isHurtbox(instance) then
		return nil
	end
	return instance:GetAttribute(BODY_PART_ATTRIBUTE)
end

function HurtboxService.GetHurtbox(character, bodyPartName)
	local folder = character and getFolder(character)
	if not folder then
		return nil
	end

	for _, instance in ipairs(folder:GetChildren()) do
		if isHurtbox(instance) and instance:GetAttribute(BODY_PART_ATTRIBUTE) == bodyPartName then
			return instance
		end
	end

	return nil
end

function HurtboxService.GetHurtboxes(character)
	local folder = character and getFolder(character)
	if not folder then
		return {}
	end

	local result = {}
	for _, instance in ipairs(folder:GetChildren()) do
		if isHurtbox(instance) then
			table.insert(result, instance)
		end
	end
	return result
end

function HurtboxService.DestroyCharacter(character)
	local state = Characters[character]
	if not state then
		return false
	end

	for bodyPart, canQuery in pairs(state.OriginalQueryStates) do
		if bodyPart and bodyPart.Parent then
			bodyPart.CanQuery = canQuery
		end
	end

	destroyHurtboxes(character)
	Characters[character] = nil
	return true
end

-- Server bootstrap: every player/NPC character receives its hurtboxes.
local function watchPlayer(player)
	if player.Character then
		setupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(setupCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

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

return HurtboxService
