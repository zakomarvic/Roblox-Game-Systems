local WeaponFireEffects = {}

local function playFireSound(Tool, ShootingHandle)
	if not Tool or not Tool:IsA("Tool") then
		return
	end
	if not ShootingHandle or not ShootingHandle:IsA("BasePart") then
		return
	end

	local FireSound = ShootingHandle:FindFirstChild("FireSound") or ShootingHandle:FindFirstChild("shoot")
	if FireSound and FireSound:IsA("Sound") then
		FireSound:Play()
	end
end

function WeaponFireEffects.Play(Tool, ShootingHandle)
	if not Tool or not Tool:IsA("Tool") then
		return
	end

	local Handle = ShootingHandle or Tool:FindFirstChild("Handle")
	if not Handle or not Handle:IsA("BasePart") then
		return
	end

	playFireSound(Tool, Handle)

	local Bolt = Tool:FindFirstChild("Bolt")
	local BoltBack = Tool:FindFirstChild("BoltBack")
	local Shell = Tool:FindFirstChild("shell")
	local Flash = Tool:FindFirstChild("Flash")

	if Bolt then Bolt.Transparency = 1 end
	if BoltBack then BoltBack.Transparency = 0 end

	if Shell then
		local Casing = Shell:Clone()
		Casing.Parent = workspace
		Casing.Transparency = 0
		Casing:BreakJoints()
		Casing.Position = Shell.Position

		task.delay(2, function()
			if Casing and Casing.Parent then
				Casing:Destroy()
			end
		end)
	end

	if Flash then
		local Light = Flash:FindFirstChild("Light")
		local Lite = Flash:FindFirstChild("lite")
		if Light then Light.Enabled = true end
		if Lite then Lite.Enabled = true end

		task.delay(0.08, function()
			if Light then Light.Enabled = false end
			if Lite then Lite.Enabled = false end
		end)
	end

	task.delay(0.08, function()
		if Bolt then Bolt.Transparency = 0 end
		if BoltBack then BoltBack.Transparency = 1 end
	end)
end

return WeaponFireEffects