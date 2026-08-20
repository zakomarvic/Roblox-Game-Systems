local MeleeController = {}
MeleeController.__index = MeleeController

function MeleeController.new(Config)
	local self = setmetatable({}, MeleeController)
	self.Tool = Config.Tool
	self.Character = Config.Character
	self.Humanoid = Config.Humanoid
	self.Module = Config.Module or {}
	self.Hitbox = Config.Hitbox
	self.OnHit = Config.OnHit
	self.OnStart = Config.OnStart
	self.OnStop = Config.OnStop
	self.Active = false
	self.AttackId = 0
	self.HitTargets = {}
	self.LastAttackTime = -math.huge
	self.AttackEndTime = 0
	self.PendingAttack = false
	self.PendingDuration = nil
	self.PendingToken = 0
	self.Destroyed = false

	if self.Hitbox then
		self.Hitbox.OnHit = function(RaycastResult, Segment)
			self:_HandleHit(RaycastResult, Segment)
		end
	end

	return self
end

function MeleeController:SetCharacter(Character, Humanoid)
	self.Character = Character
	self.Humanoid = Humanoid
	if self.Active and (not Character or not Humanoid or Humanoid.Health <= 0) then
		self:Stop()
	end
end

function MeleeController:SetHitbox(Hitbox)
	if self.Active then self:Stop() end
	self.Hitbox = Hitbox

	if self.Hitbox then
		self.Hitbox.OnHit = function(RaycastResult, Segment)
			self:_HandleHit(RaycastResult, Segment)
		end
	end
end

function MeleeController:IsActive()
	return self.Active
end

function MeleeController:_GetCooldown()
	return math.max(0, self.Module.MeleeCooldown or self.Module.AttackCooldown or 0)
end

function MeleeController:_CanStartNow()
	if self.Destroyed or self.Active then return false end
	if not self.Character or not self.Humanoid or self.Humanoid.Health <= 0 then return false end
	if not self.Hitbox then return false end
	if self.Module.MeleeEnabled == false then return false end
	return os.clock() - self.LastAttackTime >= self:_GetCooldown()
end

function MeleeController:CanAttack()
	return self:_CanStartNow()
end

function MeleeController:_QueueAttack(Duration)
	self.PendingAttack = true
	self.PendingDuration = Duration
	self.PendingToken += 1
	local Token = self.PendingToken
	local Remaining = math.max(0, self:_GetCooldown() - (os.clock() - self.LastAttackTime))

	task.delay(Remaining, function()
		if self.Destroyed or not self.PendingAttack or self.PendingToken ~= Token then return end
		self.PendingAttack = false
		local QueuedDuration = self.PendingDuration
		self.PendingDuration = nil
		self:Start(QueuedDuration)
	end)
end

function MeleeController:Start(Duration)
	if Duration == nil then
		Duration = self.Module.MeleeAttackDuration or self.Module.AttackDuration or 0
	end
	Duration = math.max(0, Duration)

	if not self:_CanStartNow() then
		if not self.Destroyed and self.Module.MeleeEnabled ~= false and self.Character and self.Humanoid and self.Humanoid.Health > 0 and self.Hitbox then
			self:_QueueAttack(Duration)
		end
		return false
	end

	self.PendingAttack = false
	self.PendingDuration = nil
	self.PendingToken += 1

	self.Active = true
	self.AttackId += 1
	self.LastAttackTime = os.clock()
	self.HitTargets = {}
	self.AttackEndTime = os.clock() + Duration

	if self.OnStart then self.OnStart(self.AttackId) end

	if self.Hitbox.Start and not self.Hitbox:Start(Duration > 0 and Duration or nil) then
		self.Active = false
		self.AttackEndTime = 0
		self.HitTargets = {}
		return false
	end

	if Duration > 0 then
		local AttackId = self.AttackId
		task.delay(Duration, function()
			if self.Active and self.AttackId == AttackId then
				self:Stop()
			end
		end)
	end

	return true
end

function MeleeController:_HandleHit(RaycastResult, Segment)
	if not self.Active or not RaycastResult then return end

	local HitPart = RaycastResult.Instance
	if not HitPart then return end

	local TargetCharacter = HitPart:FindFirstAncestorOfClass("Model")
	if not TargetCharacter or TargetCharacter == self.Character then return end

	local TargetHumanoid = TargetCharacter:FindFirstChildOfClass("Humanoid")
	if not TargetHumanoid or TargetHumanoid.Health <= 0 then return end

	local HitOnce = self.Module.MeleeHitOnce
	if HitOnce ~= false and self.HitTargets[TargetHumanoid] then return end
	self.HitTargets[TargetHumanoid] = true

	if self.OnHit then
		self.OnHit({
			AttackId = self.AttackId,
			HitPart = HitPart,
			RaycastResult = RaycastResult,
			Segment = Segment,
			TargetCharacter = TargetCharacter,
			TargetHumanoid = TargetHumanoid,
		})
	end
end

function MeleeController:Stop()
	if not self.Active then return false end
	self.Active = false
	self.AttackEndTime = 0
	if self.Hitbox and self.Hitbox.Stop then self.Hitbox:Stop() end
	if self.OnStop then self.OnStop(self.AttackId) end
	self.HitTargets = {}

	-- If the player clicked during the active swing, start the buffered
	-- attack as soon as the cooldown has elapsed. Only one input is buffered.
	if self.PendingAttack and not self.Destroyed then
		local Remaining = math.max(0, self:_GetCooldown() - (os.clock() - self.LastAttackTime))
		local Token = self.PendingToken
		task.delay(Remaining, function()
			if self.Destroyed or not self.PendingAttack or self.PendingToken ~= Token then return end
			self.PendingAttack = false
			local Duration = self.PendingDuration
			self.PendingDuration = nil
			self:Start(Duration)
		end)
	end

	return true
end

function MeleeController:Attack(Duration)
	return self:Start(Duration)
end

function MeleeController:GetAttackId()
	return self.AttackId
end

function MeleeController:GetRemainingAttackTime()
	if not self.Active then return 0 end
	return math.max(0, self.AttackEndTime - os.clock())
end

function MeleeController:Destroy()
	if self.Destroyed then return end
	self:Stop()
	self.Destroyed = true
	self.PendingAttack = false
	self.PendingDuration = nil
	self.PendingToken += 1
	if self.Hitbox and self.Hitbox.Destroy then self.Hitbox:Destroy() end
	self.Hitbox = nil
	self.OnHit = nil
	self.OnStart = nil
	self.OnStop = nil
	self.HitTargets = {}
end

return MeleeController
