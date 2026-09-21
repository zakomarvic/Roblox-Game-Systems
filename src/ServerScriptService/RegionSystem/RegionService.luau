local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RegionService = {}

local REGION_FOLDER_NAME = "Regions"
local CURRENT_REGION_ATTRIBUTE = "CurrentRegion"
local CURRENT_REGION_ID_ATTRIBUTE = "CurrentRegionId"
local REFRESH_INTERVAL = 0.15

local RULE_NAMES = {
	"FireWeapon",
	"TakeDamage",
	"Combat",
	"Arrest",
}

local RegionDefinitions = require(script.Parent:WaitForChild("RegionDefinitions"))

local RegionsFolder = Workspace:FindFirstChild(REGION_FOLDER_NAME)
if not RegionsFolder then
	RegionsFolder = Instance.new("Folder")
	RegionsFolder.Name = REGION_FOLDER_NAME
	RegionsFolder.Parent = Workspace
end

local CharacterRegions = {}
local TrackedCharacters = {}
local Connections = {}
local Started = false

local EnteredEvent = Instance.new("BindableEvent")
EnteredEvent.Name = "RegionEntered"
EnteredEvent.Parent = script

local ExitedEvent = Instance.new("BindableEvent")
ExitedEvent.Name = "RegionExited"
ExitedEvent.Parent = script

RegionService.RegionEntered = EnteredEvent.Event
RegionService.RegionExited = ExitedEvent.Event

local function isCharacter(value)
	return value and value:IsA("Model")
end

local function getRoot(character)
	if not character or not character:IsA("Model") then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
end

local function getRegionType(region)
	local regionType = region:GetAttribute("RegionType")
	return type(regionType) == "string" and regionType or nil
end

local function getRegionId(region)
	local regionId = region:GetAttribute("RegionId")
	return type(regionId) == "string" and regionId ~= "" and regionId or region.Name
end

local function getRegionPriority(region)
	local priority = tonumber(region:GetAttribute("Priority"))
	return priority or 0
end

local function getRuleValue(region, ruleName)
	local override = region:GetAttribute(ruleName)
	if type(override) == "boolean" then
		return override
	end

	local regionType = getRegionType(region)
	if not regionType then
		return nil
	end

	local definition = RegionDefinitions.Types[regionType]
	if type(definition) ~= "table" then
		return nil
	end

	local value = definition[ruleName]
	return type(value) == "boolean" and value or nil
end

local function isRegionPart(region)
	return region:IsA("BasePart") and region:GetAttribute("RegionType") ~= nil
end

local function getRegionsAtPosition(position)
	local parts = Workspace:GetPartBoundsInBox(CFrame.new(position), Vector3.new(0.1, 0.1, 0.1), nil)
	local found = {}

	for _, part in ipairs(parts) do
		if part:IsDescendantOf(RegionsFolder) and isRegionPart(part) then
			found[part] = true
		end
	end

	return found
end

local function sortRegions(regions)
	table.sort(regions, function(a, b)
		local priorityA = getRegionPriority(a)
		local priorityB = getRegionPriority(b)
		if priorityA ~= priorityB then
			return priorityA > priorityB
		end
		return getRegionId(a) < getRegionId(b)
	end)
end

local function resolvePrimary(regions)
	sortRegions(regions)
	return regions[1]
end

local function setCurrentAttributes(character, regions)
	local primary = resolvePrimary(regions)

	if primary then
		character:SetAttribute(CURRENT_REGION_ATTRIBUTE, getRegionType(primary))
		character:SetAttribute(CURRENT_REGION_ID_ATTRIBUTE, getRegionId(primary))
	else
		character:SetAttribute(CURRENT_REGION_ATTRIBUTE, nil)
		character:SetAttribute(CURRENT_REGION_ID_ATTRIBUTE, nil)
	end
end

local function updateCharacter(character)
	local root = getRoot(character)
	if not root then
		return
	end

	local currentSet = getRegionsAtPosition(root.Position)
	local previousSet = CharacterRegions[character] or {}

	for region in pairs(previousSet) do
		if not currentSet[region] then
			ExitedEvent:Fire(character, region)
		end
	end

	for region in pairs(currentSet) do
		if not previousSet[region] then
			EnteredEvent:Fire(character, region)
		end
	end

	CharacterRegions[character] = currentSet

	local ordered = {}
	for region in pairs(currentSet) do
		table.insert(ordered, region)
	end
	setCurrentAttributes(character, ordered)
end

function RegionService.GetRegions(character)
	if not isCharacter(character) then
		return {}
	end

	local regions = CharacterRegions[character]
	if regions then
		local result = {}
		for region in pairs(regions) do
			table.insert(result, region)
		end
		sortRegions(result)
		return result
	end

	local root = getRoot(character)
	if not root then
		return {}
	end

	local found = getRegionsAtPosition(root.Position)
	local result = {}
	for region in pairs(found) do
		table.insert(result, region)
	end
	sortRegions(result)
	return result
end

function RegionService.GetRegion(character)
	return RegionService.GetRegions(character)[1]
end

function RegionService.IsInRegion(character, regionType)
	if type(regionType) ~= "string" then
		return false
	end

	for _, region in ipairs(RegionService.GetRegions(character)) do
		if getRegionType(region) == regionType then
			return true
		end
	end

	return false
end

function RegionService.GetRules(character)
	local rules = {}

	for _, region in ipairs(RegionService.GetRegions(character)) do
		for _, ruleName in ipairs(RULE_NAMES) do
			if rules[ruleName] == nil then
				local value = getRuleValue(region, ruleName)
				if value ~= nil then
					rules[ruleName] = value
				end
			end
		end
	end

	return rules
end

function RegionService.Can(character, action)
	if not isCharacter(character) or type(action) ~= "string" then
		return false, "Invalid"
	end

	local regions = RegionService.GetRegions(character)
	if #regions == 0 then
		return true
	end

	local sawRule = false
	local allowed = true

	for _, region in ipairs(regions) do
		local value = getRuleValue(region, action)
		if value ~= nil then
			sawRule = true

			if value == false then
				return false, "RegionRestricted", region
			end

			allowed = allowed and value
		end
	end

	if not sawRule then
		return true
	end

	return allowed, allowed and nil or "RegionRestricted"
end

function RegionService.Refresh(character)
	if isCharacter(character) then
		updateCharacter(character)
	end
end

local function trackCharacter(character)
	if not isCharacter(character) or not character:FindFirstChildOfClass("Humanoid") or TrackedCharacters[character] then
		return
	end

	TrackedCharacters[character] = true
	Connections[character] = character.AncestryChanged:Connect(function(_, parent)
		if parent ~= nil then
			return
		end
		TrackedCharacters[character] = nil
		CharacterRegions[character] = nil
		local connection = Connections[character]
		if connection then
			connection:Disconnect()
		end
		Connections[character] = nil
	end)
end

function RegionService.Start()
	if Started then
		return
	end
	Started = true

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			trackCharacter(player.Character)
		end
		player.CharacterAdded:Connect(trackCharacter)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(trackCharacter)
	end)

	for _, instance in ipairs(workspace:GetDescendants()) do
		if instance:IsA("Humanoid") and instance.Parent and instance.Parent:IsA("Model") then
			trackCharacter(instance.Parent)
		end
	end

	workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("Humanoid") and instance.Parent and instance.Parent:IsA("Model") then
			trackCharacter(instance.Parent)
		end
	end)

	task.spawn(function()
		while Started do
			for character in pairs(TrackedCharacters) do
				if getRoot(character) then
					updateCharacter(character)
				end
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

function RegionService.Stop()
	Started = false
end

return RegionService
