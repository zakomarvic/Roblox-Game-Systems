local Debris = game:GetService("Debris")

local ExplosionEffects = {}

local function createPart(Name, Position, Size, Shape)
	local Part = Instance.new("Part")
	Part.Name = Name
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.CastShadow = false
	Part.Transparency = 1
	Part.Size = Size
	Part.Shape = Shape or Enum.PartType.Ball
	Part.Position = Position
	Part.Parent = workspace
	return Part
end

function ExplosionEffects.Create(Position, Settings)
	Settings = Settings or {}
	local Radius = Settings.Radius or 12
	local Duration = Settings.Duration or 0.3

	local Core = createPart("ExplosionCore", Position, Vector3.new(1, 1, 1))
	local CoreLight = Instance.new("PointLight")
	CoreLight.Brightness = Settings.Brightness or 12
	CoreLight.Range = Settings.LightRange or Radius * 2
	CoreLight.Parent = Core

	local Shockwave = createPart("ExplosionShockwave", Position, Vector3.new(1, 1, 1))
	Shockwave.Transparency = 0.35
	Shockwave.Material = Enum.Material.Neon

	local Fire = createPart("ExplosionFire", Position, Vector3.new(1, 1, 1))
	local FireEmitter = Instance.new("ParticleEmitter")
	FireEmitter.Rate = 0
	FireEmitter.Lifetime = NumberRange.new(0.15, 0.3)
	FireEmitter.Speed = NumberRange.new(Radius * 0.4, Radius)
	FireEmitter.SpreadAngle = Vector2.new(180, 180)
	FireEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Radius * 0.18),
		NumberSequenceKeypoint.new(0.5, Radius * 0.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	FireEmitter:Emit(Settings.FireCount or 35)
	FireEmitter.Parent = Fire

	local Smoke = createPart("ExplosionSmoke", Position, Vector3.new(1, 1, 1))
	local SmokeEmitter = Instance.new("ParticleEmitter")
	SmokeEmitter.Rate = 0
	SmokeEmitter.Lifetime = NumberRange.new(0.5, 1.2)
	SmokeEmitter.Speed = NumberRange.new(Radius * 0.15, Radius * 0.5)
	SmokeEmitter.SpreadAngle = Vector2.new(180, 180)
	SmokeEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Radius * 0.12),
		NumberSequenceKeypoint.new(0.5, Radius * 0.2),
		NumberSequenceKeypoint.new(1, Radius * 0.3),
	})
	SmokeEmitter:Emit(Settings.SmokeCount or 20)
	SmokeEmitter.Parent = Smoke

	local SoundId = Settings.SoundId
	if not SoundId and Settings.Tool then
		local Handle = Settings.Tool:FindFirstChild("Handle")
		local Sound = Handle and (Handle:FindFirstChild("Explosion") or Handle:FindFirstChild("Rocket") or Handle:FindFirstChild("Blast") or Handle:FindFirstChild("Boom"))
		if Sound and Sound:IsA("Sound") then
			SoundId = Sound.SoundId
		end
	end
	if SoundId and SoundId ~= "" then
		local Sound = Instance.new("Sound")
		Sound.SoundId = SoundId
		Sound.Volume = Settings.Volume or 1
		Sound.RollOffMaxDistance = Settings.SoundDistance or 150
		Sound.Parent = Core
		Sound:Play()
	end

	task.spawn(function()
		local Start = os.clock()
		while Core.Parent and os.clock() - Start < Duration do
			local Alpha = math.clamp((os.clock() - Start) / Duration, 0, 1)
			local Scale = math.max(0.05, Alpha * Radius)
			Shockwave.Size = Vector3.new(Scale, Scale, Scale)
			CoreLight.Brightness = (1 - Alpha) * (Settings.Brightness or 12)
			task.wait()
		end
		if Core.Parent then Core:Destroy() end
		if Shockwave.Parent then Shockwave:Destroy() end
		if Fire.Parent then Debris:AddItem(Fire, 1.5) end
		if Smoke.Parent then Debris:AddItem(Smoke, 2) end
	end)
end

return ExplosionEffects
