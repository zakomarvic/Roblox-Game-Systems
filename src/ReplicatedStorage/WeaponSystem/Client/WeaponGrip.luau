local WeaponGrip = {}

function WeaponGrip.Equip(Tool, Settings)
	if not Settings or not Settings.DualEnabled then
		return nil
	end

	local Handle2 = Tool:FindFirstChild("Handle2")
	if not Handle2 then
		error('"Dual" setting is enabled but "Handle2" is missing!')
	end

	local Character = Tool.Parent
	local LeftArm = Character:FindFirstChild("Left Arm")
	local RightArm = Character:FindFirstChild("Right Arm")

	if not LeftArm or not RightArm then
		return nil
	end

	Handle2.CanCollide = false

	local RightGrip = RightArm:FindFirstChild("RightGrip")
	if not RightGrip then
		return nil
	end

	local LeftGrip = RightGrip:Clone()
	LeftGrip.Name = "LeftGrip"
	LeftGrip.Part0 = LeftArm
	LeftGrip.Part1 = Handle2
	LeftGrip.Parent = LeftArm

	return {
		Handle2 = Handle2,
		LeftGrip = LeftGrip,
	}
end

function WeaponGrip.Unequip(GripData)
	if not GripData then
		return
	end

	if GripData.Handle2 then
		GripData.Handle2.CanCollide = true
	end

	if GripData.LeftGrip then
		GripData.LeftGrip:Destroy()
	end
end

return WeaponGrip