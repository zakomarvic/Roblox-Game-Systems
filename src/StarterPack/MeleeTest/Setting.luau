local Setting = {
	--==================================================
	-- CORE
	--==================================================
	WeaponType = "Melee";
	BaseDamage = 35;
	AttackCooldown = 1.2;
	AttackDuration = 0.5;

	--==================================================
	-- SHAPECAST HITBOX
	--==================================================
	MeleeEnabled = true;
	MeleeHitOnce = true;
	MeleeResolution = 60;
	MeleeCastType = "Raycast";
	MeleeCastSize = Vector3.zero;
	MeleeCastCFrame = CFrame.identity;
	MeleeCastRadius = 0;

	--==================================================
	-- COMBAT
	--==================================================
	MeleeKnockback = 20;

	--==================================================
	-- THROWING
	--==================================================
	ThrowEnabled = true;
	ThrowKey = Enum.KeyCode.Q;
	ThrowCooldown = 1;
	ThrowSpeed = 200;
	ThrowGravity = Vector3.new(0, -workspace.Gravity * 0.35, 0);
	ThrowLifetime = 5;
	ThrowDamage = 50;
	ThrowSpin = true;
	ThrowStick = true;
	ThrowStickLifetime = 30;
	ThrowConsumesWeapon = true;

	--==================================================
	-- ANIMATION
	--==================================================
	IdleAnimationID = nil;
	IdleAnimationSpeed = 1;
	AttackAnimationID = 89134792;
	AttackAnimationSpeed = 1;
	ThrowAnimationID = nil;
	ThrowAnimationSpeed = 1;

	--==================================================
	-- AUDIO
	--==================================================
	SwingSoundID = "";
	HitSoundIDs = {};
}

return Setting