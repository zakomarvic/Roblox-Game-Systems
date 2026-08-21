local RunService = game:GetService("RunService")

local WeaponCamera = {}
WeaponCamera.__index = WeaponCamera

function WeaponCamera.new(Camera, Humanoid, Character, Settings)
	local self = setmetatable({}, WeaponCamera)

	self.Camera = Camera
	self.Humanoid = Humanoid
	self.Character = Character
	self.Settings = Settings

	self.Equipped = false
	self.AimDown = false
	self.RecoilPitch = 0
	self.RecoilYaw = 0
	self.SwayTime = 0
	self.CurrentSwayX = 0
	self.CurrentSwayY = 0
	self.CurrentStrafeTilt = 0
	self.WalkBobTime = 0
	self.UpdateConnection = nil

	return self
end

function WeaponCamera:SetCharacter(Character, Humanoid)
	if Character then
		self.Character = Character
	end
	if Humanoid then
		self.Humanoid = Humanoid
	end

	self.SwayTime = 0
	self.WalkBobTime = 0
	self.CurrentSwayX = 0
	self.CurrentSwayY = 0
	self.CurrentStrafeTilt = 0
	self.RecoilPitch = 0
	self.RecoilYaw = 0
end

function WeaponCamera:SetEquipped(State)
	self.Equipped = State == true
end

function WeaponCamera:SetAiming(State)
	self.AimDown = State == true
end

function WeaponCamera:AddRecoil()
	local Settings = self.Settings

	if not Settings.RecoilEnabled then
		return
	end

	local Up = Settings.RecoilUp or 1.5
	local Side = Settings.RecoilSide or 0.35

	if self.AimDown then
		local Sensitivity = Settings.MouseSensitive or 0.5
		Up *= Sensitivity
		Side *= Sensitivity
	end

	self.RecoilPitch += Up
	self.RecoilYaw += (math.random() * 2 - 1) * Side
end

function WeaponCamera:Start()
	if self.UpdateConnection then
		return
	end

	self.UpdateConnection = RunService.RenderStepped:Connect(function(DeltaTime)
		self:Update(DeltaTime)
	end)
end

function WeaponCamera:Stop()
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
		self.UpdateConnection = nil
	end
end

function WeaponCamera:Update(DeltaTime)
	local Camera = self.Camera
	local Humanoid = self.Humanoid
	local Character = self.Character
	local Settings = self.Settings

	if not Camera or not Humanoid or Humanoid.Health <= 0 then
		return
	end

	if not Character or Character.Parent == nil then
		return
	end

	if self.RecoilPitch ~= 0 or self.RecoilYaw ~= 0 then
		local Recovery = Settings.RecoilRecovery or 8
		local Alpha = math.clamp(DeltaTime * Recovery, 0, 1)
		local Pitch = self.RecoilPitch * Alpha
		local Yaw = self.RecoilYaw * Alpha

		Camera.CFrame *= CFrame.Angles(math.rad(Pitch), math.rad(Yaw), 0)
		self.RecoilPitch -= Pitch
		self.RecoilYaw -= Yaw

		if math.abs(self.RecoilPitch) < 0.001 then self.RecoilPitch = 0 end
		if math.abs(self.RecoilYaw) < 0.001 then self.RecoilYaw = 0 end
	end

	if not self.Equipped then
		return
	end

	local MoveDirection = Humanoid.MoveDirection
	local Speed = MoveDirection.Magnitude

	if Settings.MovementSwayEnabled and Speed > 0.05 then
		self.SwayTime += DeltaTime * (Settings.MovementSwaySpeed or 8)
		local Amount = Settings.MovementSwayAmount or 0.35
		if self.AimDown and Settings.AimSwayEnabled then
			Amount *= Settings.AimSwayMultiplier or 0.35
		end

		local TargetX = math.sin(self.SwayTime) * Amount
		local TargetY = math.cos(self.SwayTime * 2) * Amount * 0.5
		local Alpha = math.clamp(DeltaTime * 10, 0, 1)
		self.CurrentSwayX += (TargetX - self.CurrentSwayX) * Alpha
		self.CurrentSwayY += (TargetY - self.CurrentSwayY) * Alpha
	elseif Settings.IdleSwayEnabled then
		self.SwayTime += DeltaTime * (Settings.IdleSwaySpeed or 1.5)
		local Amount = Settings.IdleSwayAmount or 0.12
		if self.AimDown then Amount *= 0.5 end

		local TargetX = math.sin(self.SwayTime) * Amount
		local TargetY = math.cos(self.SwayTime * 0.7) * Amount * 0.5
		local Alpha = math.clamp(DeltaTime * 4, 0, 1)
		self.CurrentSwayX += (TargetX - self.CurrentSwayX) * Alpha
		self.CurrentSwayY += (TargetY - self.CurrentSwayY) * Alpha
	else
		local Alpha = math.clamp(DeltaTime * 10, 0, 1)
		self.CurrentSwayX += -self.CurrentSwayX * Alpha
		self.CurrentSwayY += -self.CurrentSwayY * Alpha
	end

	local TargetStrafeTilt = 0
	if Settings.StrafeTiltEnabled then
		local RootPart = Character:FindFirstChild("HumanoidRootPart")
		if RootPart and MoveDirection.Magnitude > 0.05 then
			local LocalMove = RootPart.CFrame:VectorToObjectSpace(MoveDirection)
			TargetStrafeTilt = -LocalMove.X * (Settings.StrafeTiltAmount or 2)
			if self.AimDown then
				TargetStrafeTilt *= Settings.AimStrafeTiltMultiplier or 0.35
			end
		end
	end

	local TiltAlpha = math.clamp(DeltaTime * (Settings.StrafeTiltSpeed or 8), 0, 1)
	self.CurrentStrafeTilt += (TargetStrafeTilt - self.CurrentStrafeTilt) * TiltAlpha

	local BobX = 0
	local BobY = 0
	if Settings.WalkBobEnabled then
		if Speed > 0.05 then
			self.WalkBobTime += DeltaTime * (Settings.WalkBobSpeed or 8) * Speed
			local Amount = Settings.WalkBobAmount or 0.06
			if self.AimDown then
				Amount *= Settings.AimWalkBobMultiplier or 0.3
			end
			BobX = math.sin(self.WalkBobTime) * Amount
			BobY = math.abs(math.cos(self.WalkBobTime)) * Amount
		else
			local ReturnAlpha = math.clamp(DeltaTime * 10, 0, 1)
			self.WalkBobTime += (0 - self.WalkBobTime) * ReturnAlpha
		end
	end

	Camera.CFrame *= CFrame.new(BobX, BobY, 0) * CFrame.Angles(
		math.rad(self.CurrentSwayY),
		math.rad(self.CurrentSwayX),
		math.rad(self.CurrentStrafeTilt)
	)
end

function WeaponCamera:Destroy()
	self:Stop()
	self.Equipped = false
	self.Humanoid = nil
	self.Character = nil
end

return WeaponCamera
