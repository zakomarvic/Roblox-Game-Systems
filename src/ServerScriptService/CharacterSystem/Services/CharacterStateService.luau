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

function CharacterStateService.Get(character)
	if not isCharacter(character) then
		return nil
	end

	local state = character:GetAttribute(STATE_ATTRIBUTE)
	if type(state) == "string" and state ~= "" then
		return state
	end

	return deriveState(character)
end

function CharacterStateService.Set(character, state)
	if not isCharacter(character) then
		return false
	end
	if type(state) ~= "string" or state == "" then
		return false
	end

	character:SetAttribute(STATE_ATTRIBUTE, state)
	return true
end

function CharacterStateService.Is(character, state)
	return CharacterStateService.Get(character) == state
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
			character:SetAttribute(STATE_ATTRIBUTE, deriveState(character))
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

	sync()
	return CharacterStateService.Get(character)
end

return CharacterStateService
