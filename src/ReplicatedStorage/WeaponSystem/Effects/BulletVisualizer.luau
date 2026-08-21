local BulletVisualizer = {}

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

function BulletVisualizer.Visualize(
	Handle,
	MuzzleOffset,
	EndPos,
	MuzzleEffect,
	HitEffect,
	HitSound,
	ExplosiveData,
	BulletData,
	VisualizeExplosion,
	VisualizeEnabled
)
	if not Handle or not MuzzleEffect or not HitEffect then
		return
	end

	local LaserAttachment = Handle:FindFirstChild("wow")
	if not LaserAttachment then
		return
	end

	BulletData = BulletData or {}
	local BulletSpeed = tonumber(BulletData[1]) or math.huge
	local BulletSize = typeof(BulletData[2]) == "Vector3" and BulletData[2] or Vector3.new(0.25, 0.25, 100)
	local BulletColor = BulletData[3] or BrickColor.new("Bright yellow")
	local BulletTransparency = tonumber(BulletData[4]) or 0.25
	local BulletMaterial = BulletData[5] or Enum.Material.SmoothPlastic
	local FadeTime = math.max(tonumber(BulletData[6]) or 0.1, 0.01)

	local MuzzlePos = LaserAttachment.WorldPosition
	local Distance = (MuzzlePos - EndPos).Magnitude / 2

	local Muzzle = Instance.new("Part")
	Muzzle.Name = "Bullet"
	Muzzle.Size = Vector3.new(0.01, 0.01, 0.01)
	Muzzle.Transparency = 1
	Muzzle.Anchored = false
	Muzzle.CanCollide = false
	Muzzle.CanQuery = false
	Muzzle.CanTouch = false
	Muzzle.TopSurface = Enum.SurfaceType.SmoothNoOutlines
	Muzzle.BottomSurface = Enum.SurfaceType.SmoothNoOutlines

	local MuzzleParticle = MuzzleEffect:Clone()
	MuzzleParticle.Parent = Muzzle

	local Weld = Instance.new("Weld")
	Weld.Part0 = Handle
	Weld.Part1 = Muzzle
	Weld.C0 = CFrame.new(MuzzleOffset.X, MuzzleOffset.Y, MuzzleOffset.Z)
	Weld.Parent = Muzzle

	Muzzle.CFrame = Handle.CFrame * CFrame.new(MuzzleOffset.X, MuzzleOffset.Y, MuzzleOffset.Z)
	Muzzle.Parent = workspace.CurrentCamera
	MuzzleParticle:Emit(5)
	Debris:AddItem(Muzzle, 2)

	local HitPart = Instance.new("Part")
	HitPart.Name = "Bullet"
	HitPart.Size = Vector3.new(0.01, 0.01, 0.01)
	HitPart.Transparency = 1
	HitPart.Anchored = true
	HitPart.CanCollide = false
	HitPart.CanQuery = false
	HitPart.CanTouch = false
	HitPart.TopSurface = Enum.SurfaceType.SmoothNoOutlines
	HitPart.BottomSurface = Enum.SurfaceType.SmoothNoOutlines

	local HitParticle = HitEffect:Clone()
	HitParticle.Parent = HitPart

	local Sound = Instance.new("Sound")
	Sound.SoundId = "rbxassetid://" .. tostring(HitSound or "")
	Sound.Volume = 1
	Sound.Parent = HitPart

	HitPart.Position = EndPos
	HitPart.Parent = workspace.CurrentCamera

	task.spawn(function()
		HitParticle:Emit(2)
		if HitSound then
			Sound:Play()
		end
	end)

	Debris:AddItem(HitPart, 2)

	if ExplosiveData and ExplosiveData[1] and VisualizeExplosion then
		local Explosion = Instance.new("Explosion")
		Explosion.BlastRadius = ExplosiveData[2] or 0
		Explosion.BlastPressure = 0
		Explosion.Position = EndPos
		Explosion.Parent = workspace.CurrentCamera
	end

	if VisualizeEnabled then
		local Bullet = Instance.new("Part")
		Bullet.Name = "Bullet"
		Bullet.Size = Vector3.new(0.2, 0.2, 0.2)
		Bullet.BrickColor = BulletColor
		Bullet.Transparency = BulletTransparency
		Bullet.Material = BulletMaterial
		Bullet.Anchored = true
		Bullet.CanCollide = false
		Bullet.CanQuery = false
		Bullet.CanTouch = false
		Bullet.TopSurface = Enum.SurfaceType.SmoothNoOutlines
		Bullet.BottomSurface = Enum.SurfaceType.SmoothNoOutlines

		local Mesh = Instance.new("SpecialMesh")
		Mesh.MeshType = Enum.MeshType.Brick
		Mesh.Scale = BulletSize * 5
		Mesh.Offset = Vector3.new(0, 0, -Mesh.Scale.Z / 10)
		Mesh.Parent = Bullet

		Bullet.CFrame = CFrame.new(MuzzlePos, EndPos)
		Bullet.Parent = workspace.CurrentCamera
		Debris:AddItem(Bullet, 10)

		if BulletSpeed ~= math.huge then
			for i = 0, Distance, BulletSpeed do
				if i ~= 0 then
					Bullet.CFrame = Bullet.CFrame * CFrame.new(0, 0, -BulletSpeed)
				end
				if (Bullet.Position - EndPos).Magnitude < BulletSize.Z then
					Mesh.Scale = Vector3.new(BulletSize.X, BulletSize.Y, (Bullet.Position - EndPos).Magnitude) * 5
					Mesh.Offset = Vector3.new(0, 0, -Mesh.Scale.Z / 10)
				end
				RunService.Stepped:Wait()
			end
		else
			Mesh.Scale = Vector3.new(BulletSize.X, BulletSize.Y, (Bullet.Position - EndPos).Magnitude) * 5
			Mesh.Offset = Vector3.new(0, 0, -Mesh.Scale.Z / 10)
			local Time = RunService.Heartbeat:Wait()
			while Bullet.Parent and Bullet.Transparency < 1 do
				Bullet.Transparency = math.min(1, Bullet.Transparency + Time / FadeTime)
				Time = RunService.Heartbeat:Wait()
			end
		end

		if Bullet then
			Bullet:Destroy()
		end
	end
end

return BulletVisualizer