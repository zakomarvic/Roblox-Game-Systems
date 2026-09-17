local CharacterStateService = {}

local STATE_ATTRIBUTE = "CharacterState"
local DOWNED_ATTRIBUTE = "Downed"
local REVIVING_ATTRIBUTE = "Reviving"

CharacterStateService.States = {
	Normal = "Normal",
	Downed = "Downed",
	Reviving = "Reviving",
	BeingRevived = "BeingRevived",
	Dead = "Dead",
}

local ValidStates = {}
for _, state in pairs(CharacterStateService.States) do
	ValidStates[state] = true
end

local Connections = {}

local function isCharacter(character)
	return character and character:IsA("Model")
end

local function deriveState(character)
	if not isCharacter(character) then
		return nil
	end

	if character:GetAttribute(REVIVING_ATTRIBUTE) == true then
		if character:GetAttribute(DOWNED_ATTRIBUTE) == true then
			return CharacterStateService.States.BeingRevived
		end
		return CharacterStateService.States.Reviving
	end

	if character:GetAttribute(DOWNED_ATTRIBUTE) == true then
		return CharacterStateService.States.Downed
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return CharacterStateService.States.Dead
	end

	return CharacterStateService.States.Normal
end

local function applyStateAttributes(character, state)
	if state == CharacterStateService.States.Downed then
		character:SetAttribute(DOWNED_ATTRIBUTE, true)
		character:SetAttribute(REVIVING_ATTRIBUTE, false)
	elseif state == CharacterStateService.States.Reviving then
		character:SetAttribute(DOWNED_ATTRIBUTE, false)
		character:SetAttribute(REVIVING_ATTRIBUTE, true)
	elseif state == CharacterStateService.States.BeingRevived then
		character:SetAttribute(DOWNED_ATTRIBUTE, true)
		character:SetAttribute(REVIVING_ATTRIBUTE, true)
	elseif state == CharacterStateService.States.Normal or state == CharacterStateService.States.Dead then
		character:SetAttribute(DOWNED_ATTRIBUTE, false)
		character:SetAttribute(REVIVING_ATTRIBUTE, false)
	end
end

function CharacterStateService.Get(character)
	if not isCharacter(character) then
		return nil
	end

	local state = character:GetAttribute(STATE_ATTRIBUTE)
	if type(state) == "string" and ValidStates[state] then
		return state
	end

	return deriveState(character)
end

function CharacterStateService.Set(character, state)
	if not isCharacter(character) or not ValidStates[state] then
		return false
	end

	character:SetAttribute(STATE_ATTRIBUTE, state)
	applyStateAttributes(character, state)
	return true
end

function CharacterStateService.Is(character, state)
	return CharacterStateService.Get(character) == state
end

function CharacterStateService.Refresh(character)
	if not isCharacter(character) then
		return nil
	end

	local state = deriveState(character)
	character:SetAttribute(STATE_ATTRIBUTE, state)
	return state
end

function CharacterStateService.Initialize(character)
	if not isCharacter(character) then
		return nil
	end

	if Connections[character] then
		return CharacterStateService.Get(character)
	end

	local function sync()
		if character.Parent then
			CharacterStateService.Refresh(character)
		end
	end

	Connections[character] = {
		character:GetAttributeChangedSignal(DOWNED_ATTRIBUTE):Connect(sync),
		character:GetAttributeChangedSignal(REVIVING_ATTRIBUTE):Connect(sync),
	}

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(Connections[character], humanoid.Died:Connect(sync))
	end

	character.AncestryChanged:Connect(function(_, parent)
		if parent ~= nil then
			return
		end

		local connections = Connections[character]
		if connections then
			for _, connection in ipairs(connections) do
				if connection.Connected then
					connection:Disconnect()
				end
			end
		end
		Connections[character] = nil
	end)

	return CharacterStateService.Refresh(character)
end

function CharacterStateService.Destroy(character)
	local connections = Connections[character]
	if connections then
		for _, connection in ipairs(connections) do
			if connection.Connected then
				connection:Disconnect()
			end
		end
		Connections[character] = nil
	end
end

return CharacterStateService
