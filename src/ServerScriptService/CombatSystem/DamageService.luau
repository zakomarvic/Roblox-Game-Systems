local DamageService = {}

local CharacterSystem = game:GetService("ServerScriptService"):WaitForChild("CharacterSystem")
local DownedService = require(CharacterSystem:WaitForChild("Services"):WaitForChild("DownedDamageService"))

local MAX_HEALTH = 110
local DOWNED_HEALTH_THRESHOLD = 10
local DOWNED_INVULNERABILITY_DURATION = 0.3

local function getCharacter(humanoid)
	local character = humanoid and humanoid.Parent
	if not character or not character:IsA("Model") then return nil end
	return character
end

local function isDowned(character)
	return character:GetAttribute("Downed") == true
end

local function isInvulnerable(character)
	local untilTime = character:GetAttribute("DownedInvulnerableUntil")
	return type(untilTime) == "number" and os.clock() < untilTime
end

function DamageService.ApplyDamage(targetHumanoid, damage, overkill)
	if not targetHumanoid or not targetHumanoid:IsA("Humanoid") then return false end
	if type(damage) ~= "number" or damage <= 0 then return false end
	if targetHumanoid.Health <= 0 then return false end

	local character = getCharacter(targetHumanoid)
	if not character then return false end

	local isOverkill = overkill == true
	local currentlyDowned = isDowned(character)
	local currentHealth = targetHumanoid.Health

	-- A Downed character has a short protection window after entering Downed.
	-- Overkill bypasses this protection because it is specifically allowed to
	-- execute a Downed character immediately.
	if currentlyDowned and not isOverkill and isInvulnerable(character) then
		return false
	end

	local resultingHealth = currentHealth - damage

	if resultingHealth <= 0 then
		if currentlyDowned then
			-- The target is already Downed. Once the protection window has ended,
			-- normal weapons are allowed to finish them. Clear the custom state
			-- first so the Humanoid can receive normal lethal damage.
			DownedService.Clear(targetHumanoid)
			targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			targetHumanoid:TakeDamage(damage)
			if targetHumanoid.Health <= 0 then
				targetHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
			end
			return true
		end

		if isOverkill then
			-- Remove the custom Downed state and let the Humanoid receive the
			-- lethal damage normally. No forced Health = 0 is used.
			DownedService.Clear(targetHumanoid)
			targetHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			targetHumanoid:TakeDamage(damage)
			if targetHumanoid.Health <= 0 then
				targetHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
			end
			return true
		end

		-- Non-overkill lethal damage becomes Downed instead of death.
		DownedService.Down(targetHumanoid)
		return true
	end

	-- Non-lethal damage is applied normally, regardless of Overkill.
	targetHumanoid:TakeDamage(damage)

	-- Crossing the Downed threshold is handled by the damage system itself,
	-- so there is no need to infer the weapon's Overkill setting from
	-- Humanoid.HealthChanged.
	if targetHumanoid.Health > 0
		and targetHumanoid.Health <= DOWNED_HEALTH_THRESHOLD
		and not isDowned(character)
		and character:GetAttribute("Reviving") ~= true then
		DownedService.Down(targetHumanoid)
	end

	return true
end

function DamageService.SetupCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.MaxHealth = MAX_HEALTH
	humanoid.Health = MAX_HEALTH
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
end

return DamageService
