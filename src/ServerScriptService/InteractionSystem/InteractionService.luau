local InteractionService = {}

local Interactions = {}
local Active = {}

local function isCharacter(value)
	return value and value:IsA("Model")
end

local function getCharacter(player)
	return player and player.Character
end

local function getRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getDistance(player, targetCharacter)
	local playerRoot = getRoot(getCharacter(player))
	local targetRoot = getRoot(targetCharacter)
	if not playerRoot or not targetRoot then
		return math.huge
	end
	return (playerRoot.Position - targetRoot.Position).Magnitude
end

function InteractionService.Register(name, definition)
	if type(name) ~= "string" or name == "" or type(definition) ~= "table" then
		return false
	end

	Interactions[name] = definition
	return true
end

function InteractionService.Get(name)
	return Interactions[name]
end

function InteractionService.IsRegistered(name)
	return Interactions[name] ~= nil
end

function InteractionService.Validate(player, name, targetCharacter, context)
	local definition = Interactions[name]
	if not definition or not player or not isCharacter(targetCharacter) then
		return false, "InvalidInteraction"
	end

	local playerCharacter = getCharacter(player)
	if not playerCharacter then
		return false, "MissingCharacter"
	end

	if definition.MaxDistance then
		local maxDistance = tonumber(definition.MaxDistance)
		if maxDistance and getDistance(player, targetCharacter) > maxDistance then
			return false, "OutOfRange"
		end
	end

	if definition.CanInteract then
		local success, allowed, reason = pcall(definition.CanInteract, player, targetCharacter, context)
		if not success then
			warn("[InteractionService] CanInteract failed for " .. name .. ": " .. tostring(allowed))
			return false, "ValidationError"
		end
		if allowed ~= true then
			return false, reason or "NotAllowed"
		end
	end

	return true
end

function InteractionService.Start(player, name, targetCharacter, context)
	local definition = Interactions[name]
	if not definition then
		return false, "InvalidInteraction"
	end

	local valid, reason = InteractionService.Validate(player, name, targetCharacter, context)
	if not valid then
		return false, reason
	end

	local activeForTarget = Active[targetCharacter]
	if activeForTarget then
		return false, "AlreadyActive"
	end

	local state = {
		Player = player,
		Name = name,
		Target = targetCharacter,
		Context = context,
		StartedAt = os.clock(),
		Cancelled = false,
	}
	Active[targetCharacter] = state

	if definition.Start then
		local success, result, resultReason = pcall(definition.Start, state)
		if not success then
			Active[targetCharacter] = nil
			warn("[InteractionService] Start failed for " .. name .. ": " .. tostring(result))
			return false, "StartError"
		end
		if result == false then
			Active[targetCharacter] = nil
			return false, resultReason or "StartRejected"
		end
	end

	return true, state
end

function InteractionService.GetActive(targetCharacter)
	return Active[targetCharacter]
end

function InteractionService.Cancel(targetCharacter, reason)
	local state = Active[targetCharacter]
	if not state then
		return false
	end

	state.Cancelled = true
	Active[targetCharacter] = nil

	local definition = Interactions[state.Name]
	if definition and definition.Cancel then
		local success, err = pcall(definition.Cancel, state, reason)
		if not success then
			warn("[InteractionService] Cancel failed for " .. state.Name .. ": " .. tostring(err))
		end
	end

	return true
end

function InteractionService.Complete(targetCharacter, context)
	local state = Active[targetCharacter]
	if not state then
		return false, "NotActive"
	end

	Active[targetCharacter] = nil

	local definition = Interactions[state.Name]
	if definition and definition.Complete then
		local success, result, reason = pcall(definition.Complete, state, context)
		if not success then
			warn("[InteractionService] Complete failed for " .. state.Name .. ": " .. tostring(result))
			return false, "CompleteError"
		end
		if result == false then
			return false, reason or "CompleteRejected"
		end
	end

	return true
end

function InteractionService.ClearCharacter(character)
	if not isCharacter(character) then
		return
	end

	if Active[character] then
		InteractionService.Cancel(character, "CharacterRemoved")
	end
end

return InteractionService
