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

local function isCharacter(character)
	return character and character:IsA("Model")
end

function CharacterStateService.Get(character)
	if not isCharacter(character) then
		return nil
	end

	local state = character:GetAttribute(STATE_ATTRIBUTE)
	if type(state) == "string" and state ~= "" then
		return state
	end

	-- Backward-compatible fallback for characters that have not been initialized.
	if character:GetAttribute(REVIVING_ATTRIBUTE) == true then
		return CharacterStateService.States.Reviving
	end
	if character:GetAttribute(DOWNED_ATTRIBUTE) == true then
		return CharacterStateService.States.Downed
	end
	return CharacterStateService.States.Normal
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

	local state = CharacterStateService.Get(character)
	character:SetAttribute(STATE_ATTRIBUTE, state)
	return state
end

return CharacterStateService
