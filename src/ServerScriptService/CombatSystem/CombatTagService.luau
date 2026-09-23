local Players = game:GetService("Players")

local CombatTagService = {}

local DEFAULT_DURATION = 20
local TAG_ATTRIBUTE = "CombatTagged"
local EXPIRES_ATTRIBUTE = "CombatTagExpiresAt"
local COMBAT_LOG_ELIGIBLE_ATTRIBUTE = "CombatLogEligible"

local TaggedPlayers = {}
local TaggedCharacters = {}
local TagTokens = {}
local CharacterConnections = {}

local function isPlayer(value)
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function isCharacter(value)
	return typeof(value) == "Instance" and value:IsA("Model")
end

local function getPlayerFromCharacter(character)
	return isCharacter(character) and Players:GetPlayerFromCharacter(character) or nil
end

local function clearCharacterAttributes(character)
	if not isCharacter(character) then
		return
	end

	character:SetAttribute(TAG_ATTRIBUTE, false)
	character:SetAttribute(EXPIRES_ATTRIBUTE, nil)
end

local function disconnectCharacter(character)
	local connection = CharacterConnections[character]
	if connection then
		connection:Disconnect()
		CharacterConnections[character] = nil
	end
end

local function clearCharacter(character)
	if not isCharacter(character) then
		return
	end

	TaggedCharacters[character] = nil
	TagTokens[character] = nil
	disconnectCharacter(character)
	clearCharacterAttributes(character)
end

local function clearPlayer(player)
	TaggedPlayers[player] = nil
	TagTokens[player] = nil

	local character = player.Character
	if character then
		clearCharacter(character)
	end
end

local function watchCharacter(character)
	if not isCharacter(character) or CharacterConnections[character] then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	CharacterConnections[character] = humanoid.Died:Connect(function()
		clearCharacter(character)

		local player = getPlayerFromCharacter(character)
		if player then
			TaggedPlayers[player] = nil
			TagTokens[player] = nil
		end
	end)
end

local function scheduleExpiry(key, target, duration)
	local token = {}
	TagTokens[key] = token

	task.delay(duration, function()
		if TagTokens[key] ~= token then
			return
		end

		TagTokens[key] = nil

		if isPlayer(target) then
			if TaggedPlayers[target] and os.clock() >= TaggedPlayers[target] then
				TaggedPlayers[target] = nil
				clearCharacter(target.Character)
			end
		elseif isCharacter(target) then
			if TaggedCharacters[target] and os.clock() >= TaggedCharacters[target] then
				clearCharacter(target)
			end
		end
	end)
end

function CombatTagService.GetDuration()
	return DEFAULT_DURATION
end

function CombatTagService.TagPlayer(player, duration)
	if not isPlayer(player) then
		return false
	end

	local tagDuration = math.max(0, tonumber(duration) or DEFAULT_DURATION)
	if tagDuration <= 0 then
		return CombatTagService.ClearPlayer(player)
	end

	local expiresAt = os.clock() + tagDuration
	TaggedPlayers[player] = expiresAt

	local character = player.Character
	if character then
		TaggedCharacters[character] = expiresAt
		watchCharacter(character)
		character:SetAttribute(TAG_ATTRIBUTE, true)
		character:SetAttribute(EXPIRES_ATTRIBUTE, expiresAt)
	end

	scheduleExpiry(player, player, tagDuration)
	if character then
		scheduleExpiry(character, character, tagDuration)
	end

	return true
end

function CombatTagService.TagCharacter(character, duration)
	if not isCharacter(character) then
		return false
	end

	local tagDuration = math.max(0, tonumber(duration) or DEFAULT_DURATION)
	if tagDuration <= 0 then
		return CombatTagService.ClearCharacter(character)
	end

	local expiresAt = os.clock() + tagDuration
	TaggedCharacters[character] = expiresAt
	watchCharacter(character)
	character:SetAttribute(TAG_ATTRIBUTE, true)
	character:SetAttribute(EXPIRES_ATTRIBUTE, expiresAt)

	local player = getPlayerFromCharacter(character)
	if player then
		TaggedPlayers[player] = expiresAt
		scheduleExpiry(player, player, tagDuration)
	end

	scheduleExpiry(character, character, tagDuration)
	return true
end

function CombatTagService.IsTagged(target)
	if isPlayer(target) then
		local expiresAt = TaggedPlayers[target]
		if expiresAt and os.clock() < expiresAt then
			return true
		end

		if expiresAt then
			clearPlayer(target)
		end

		return false
	end

	if isCharacter(target) then
		local expiresAt = TaggedCharacters[target]
		if expiresAt and os.clock() < expiresAt then
			return true
		end

		if expiresAt then
			clearCharacter(target)
		end

		return false
	end

	return false
end

function CombatTagService.GetRemainingTime(target)
	if not CombatTagService.IsTagged(target) then
		return 0
	end

	local expiresAt
	if isPlayer(target) then
		expiresAt = TaggedPlayers[target]
	elseif isCharacter(target) then
		expiresAt = TaggedCharacters[target]
	end

	return math.max(0, expiresAt - os.clock())
end

function CombatTagService.ClearPlayer(player)
	if not isPlayer(player) then
		return false
	end

	clearPlayer(player)
	return true
end

function CombatTagService.ClearCharacter(character)
	if not isCharacter(character) then
		return false
	end

	local player = getPlayerFromCharacter(character)
	clearCharacter(character)

	if player then
		TaggedPlayers[player] = nil
		TagTokens[player] = nil
	end

	return true
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute(COMBAT_LOG_ELIGIBLE_ATTRIBUTE, false)
	player.CharacterAdded:Connect(function(character)
		clearPlayer(player)
		watchCharacter(character)
	end)

	if player:GetAttribute(COMBAT_LOG_ELIGIBLE_ATTRIBUTE) == nil then
		player:SetAttribute(COMBAT_LOG_ELIGIBLE_ATTRIBUTE, false)
	end

	if player.Character then
		clearPlayer(player)
		watchCharacter(player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if CombatTagService.IsTagged(player) then
		player:SetAttribute(COMBAT_LOG_ELIGIBLE_ATTRIBUTE, true)
	end

	clearPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player:GetAttribute(COMBAT_LOG_ELIGIBLE_ATTRIBUTE) == nil then
		player:SetAttribute(COMBAT_LOG_ELIGIBLE_ATTRIBUTE, false)
	end

	if player.Character then
		watchCharacter(player.Character)
	end

	player.CharacterAdded:Connect(function(character)
		clearPlayer(player)
		watchCharacter(character)
	end)
end

return CombatTagService
