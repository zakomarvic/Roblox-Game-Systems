local Setting = {
	--==================================================
	-- CORE
	--==================================================
	Auto = false;
	BaseDamage = 100;
	FireRate = 1.5;
	ReloadTime = 4.5;
	AmmoPerClip = 1;
	Overkill = false;

	--==================================================
	-- PROJECTILE
	--==================================================
	ProjectileType = "Projectile";
	ProjectileName = "RPG";
	ProjectileSpeed = 200;
	ProjectileGravity = Vector3.zero;
	ProjectileLifetime = 8;

	--==================================================
	-- EXPLOSION
	--==================================================
	ExplosiveEnabled = true;
	ExplosionRadius = 50;
	ExplosionDamage = 300;
	ExplosionKnockback = 70;
	ExplosionKnockbackDuration = 3;

	--==================================================
	-- AIM / ACCURACY
	--==================================================
	Spread = 0;
	SniperEnabled = false;
	FieldOfView = 12.5;
	MouseSensitive = 0.05;

	--==================================================
	-- RECOIL / CAMERA
	--==================================================
	RecoilEnabled = true;
	RecoilUp = 8;
	RecoilSide = 1.5;
	RecoilRecovery = 6;
	MovementSwayEnabled = true;
	MovementSwayAmount = 0.20;
	MovementSwaySpeed = 8;
	IdleSwayEnabled = true;
	IdleSwayAmount = 0.01;
	IdleSwaySpeed = 1.5;
	AimSwayEnabled = true;
	AimSwayMultiplier = 0.35;
	StrafeTiltEnabled = true;
	StrafeTiltAmount = 2;
	StrafeTiltSpeed = 8;
	AimStrafeTiltMultiplier = 0.35;
	WalkBobEnabled = true;
	WalkBobAmount = 0.06;
	WalkBobSpeed = 8;
	AimWalkBobMultiplier = 0.3;

	--==================================================
	-- ANIMATIONS
	--==================================================
	IdleAnimationID = 94331086;
	IdleAnimationSpeed = 1;
	FireAnimationID = 94332152;
	FireAnimationSpeed = 1;
	ReloadAnimationID = 94771598;
	ReloadAnimationSpeed = 1;

	--==================================================
	-- AUDIO / UI
	--==================================================
	MouseIconID = "";
	HitSoundIDs = {};

	--==================================================
	-- AIM / BODY
	--==================================================
	-- Controls the gun-specific arm/shoulder pose independently from body aim.
	WeaponPoseEnabled = true;
	BodyAimEnabled = true;
	BodyAimSpeed = 20;
	SprintEnabled = true;
	SprintWalkSpeed = 24;
	SprintOffset = CFrame.new(0.15, -0.35, 0.25);
	SprintRotation = CFrame.Angles(math.rad(-25), math.rad(15), math.rad(-5));
	SprintTransitionSpeed = 10;
}

return Setting