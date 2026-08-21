local WeaponRaycast = {}

local Workspace = workspace

function WeaponRaycast.Cast(Start, Direction, Range, Ignore, PiercedHumanoid)
	local Hit, EndPos = Workspace:FindPartOnRay(Ray.new(Start, Direction * Range), Ignore)

	if Hit then
		local Parent = Hit.Parent
		local ParentHumanoid = Parent and Parent:FindFirstChild("Humanoid")
		local ParentTeam = Parent and Parent:FindFirstChild("TEAM")

		if Hit.Transparency > 0.75
			or Hit.Name == "Handle"
			or Hit.Name == "Effect"
			or Hit.Name == "Bullet"
			or Hit.Name == "Laser"
			or string.lower(Hit.Name) == "water"
			or Hit.Name == "Rail"
			or Hit.Name == "Arrow"
			or (ParentHumanoid and ParentHumanoid.Health == 0)
			or (ParentHumanoid and ParentTeam and ParentTeam.Value == ParentTeam.Value)
			or (ParentHumanoid and PiercedHumanoid and PiercedHumanoid[ParentHumanoid]) then
			return WeaponRaycast.Cast(
				EndPos + Direction * 0.01,
				Direction,
				Range - (Start - EndPos).Magnitude,
				Ignore,
				PiercedHumanoid
			)
		end
	end

	return Hit, EndPos
end

return WeaponRaycast