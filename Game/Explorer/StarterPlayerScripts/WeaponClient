local Player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local Remotes = WeaponSystem:WaitForChild("Remotes")

local BulletVisualizer = require(
	WeaponSystem.Modules:WaitForChild("BulletVisualizer")
)
local WeaponFireEffects = require(
	WeaponSystem.Modules:WaitForChild("WeaponFireEffects")
)

local WeaponEffects = Remotes:WaitForChild("WeaponEffects")

local function getEffectTemplate(Tool, Name)
	if not Tool then
		return nil
	end

	return Tool:FindFirstChild(Name, true)
end

WeaponEffects.OnClientEvent:Connect(function(
	Effect,
	Shooter,
	Tool,
	ShootingHandle,
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
	if Effect == "Fire" then
		if Shooter and Shooter ~= Player then
			local Character = Shooter.Character
			Tool = Tool or (Character and Character:FindFirstChildOfClass("Tool"))

			if Tool then
				WeaponFireEffects.Play(Tool, ShootingHandle)
			end
		end

		return
	end

	if Effect ~= "Bullet" then
		return
	end

	-- Don't visualize our own bullet here; the firing client already does it locally.
	if Shooter == Player then
		return
	end

	if not Tool and Shooter and Shooter.Character then
		Tool = Shooter.Character:FindFirstChildOfClass("Tool")
	end

	ShootingHandle = ShootingHandle or (Tool and Tool:FindFirstChild("Handle"))

	MuzzleEffect = MuzzleEffect or getEffectTemplate(Tool, "MuzzleEffect")
	HitEffect = HitEffect or getEffectTemplate(Tool, "HitEffect")

	if not ShootingHandle or not EndPos or not MuzzleEffect or not HitEffect then
		return
	end

	BulletVisualizer.Visualize(
		ShootingHandle,
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
end)
