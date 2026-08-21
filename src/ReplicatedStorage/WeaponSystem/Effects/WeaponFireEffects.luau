local WeaponFireEffects = {}
local FlashTokens = setmetatable({}, {__mode = "k"})

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

function WeaponFireEffects.PlaySound(Handle, SoundName)
	if not Handle or not Handle:IsA("BasePart") then
		return
	end

	local Sound = Handle:FindFirstChild(SoundName)
	if Sound and Sound:IsA("Sound") then
		Sound:Play()
	end
end

function WeaponFireEffects.StopLoopedSound(Handle, SoundName)
	if not Handle or not Handle:IsA("BasePart") then
		return
	end

	local Sound = Handle:FindFirstChild(SoundName)
	if Sound and Sound:IsA("Sound") and Sound.Playing and Sound.Looped then
		Sound:Stop()
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

function WeaponFireEffects.ShowMuzzleFlash(Tool)
	local Flash = Tool and Tool:FindFirstChild("Flash")
	local FlashGui = Flash and Flash:FindFirstChild("LightBG")
	local FlashImage = FlashGui and FlashGui:FindFirstChild("Light")
	local FlashLight = Flash and Flash:FindFirstChild("lite")
	if not FlashImage or not FlashImage:IsA("ImageLabel") then return end

	local Billboard = FlashImage.Parent
	if Billboard and Billboard:IsA("BillboardGui") then
		Billboard.Adornee = Flash
		Billboard.Enabled = true
	end
	if FlashLight and FlashLight:IsA("PointLight") then
		FlashLight.Enabled = true
	end

	local Token = (FlashTokens[Tool] or 0) + 1
	FlashTokens[Tool] = Token
	FlashImage.Visible = true

	task.delay(0.05, function()
		if FlashTokens[Tool] ~= Token or not FlashImage.Parent then return end
		FlashImage.Visible = false
		if Billboard and Billboard.Parent and Billboard:IsA("BillboardGui") then
			Billboard.Enabled = false
		end
		if FlashLight and FlashLight.Parent and FlashLight:IsA("PointLight") then
			FlashLight.Enabled = false
		end
	end)
end

function WeaponFireEffects.PlayFirePresentation(Tool, ShootingHandle, WeaponEffects)
	WeaponFireEffects.ShowMuzzleFlash(Tool)
	playFireSound(Tool, ShootingHandle)
	if WeaponEffects then
		WeaponEffects:FireServer(Tool, "Fire")
	end
end

function WeaponFireEffects.VisualizeAndBroadcast(Tool, ShootingHandle, MuzzleOffset, EndPos, MuzzleEffect, HitEffect, HitSound, ExplosiveData, BulletData, VisualizeEnabled, BulletVisualizer, WeaponEffects)
	if BulletVisualizer then
		task.spawn(function()
			BulletVisualizer.Visualize(ShootingHandle, MuzzleOffset, EndPos, MuzzleEffect, HitEffect, HitSound, ExplosiveData, BulletData, false, VisualizeEnabled)
		end)
	end
	if WeaponEffects then
		WeaponEffects:FireServer(Tool, "Bullet", ShootingHandle, MuzzleOffset, EndPos, MuzzleEffect, HitEffect, HitSound, ExplosiveData, BulletData, true, VisualizeEnabled)
	end
end

return WeaponFireEffects