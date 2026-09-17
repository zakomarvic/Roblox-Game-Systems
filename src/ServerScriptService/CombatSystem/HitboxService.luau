local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatSystem = ServerScriptService:WaitForChild("CombatSystem")
local HurtboxService = require(CombatSystem:WaitForChild("HurtboxService"))

local HitboxService = {}

function HitboxService.Raycast(origin, direction, raycastParams)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return nil
	end
	if direction.Magnitude <= 0 then
		return nil
	end

	return Workspace:Raycast(origin, direction, raycastParams)
end

function HitboxService.GetPartsInRadius(position, radius, overlapParams)
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" or radius <= 0 then
		return {}
	end

	return Workspace:GetPartBoundsInRadius(position, radius, overlapParams)
end

function HitboxService.ResolveCharacterHit(instance)
	if not HurtboxService.IsHurtbox(instance) then
		return nil, nil, nil
	end

	local character = HurtboxService.GetCharacter(instance)
	local humanoid = HurtboxService.GetHumanoid(instance)
	local bodyPartName = HurtboxService.GetBodyPartName(instance)

	if not character or not humanoid or not bodyPartName then
		return nil, nil, nil
	end

	return character, humanoid, bodyPartName
end

function HitboxService.IsHurtbox(instance)
	return HurtboxService.IsHurtbox(instance)
end

function HitboxService.GetCharacter(instance)
	return HurtboxService.GetCharacter(instance)
end

function HitboxService.GetHumanoid(instance)
	return HurtboxService.GetHumanoid(instance)
end

function HitboxService.GetBodyPartName(instance)
	return HurtboxService.GetBodyPartName(instance)
end

return HitboxService