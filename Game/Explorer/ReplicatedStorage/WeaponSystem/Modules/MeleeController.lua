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
	self.Destroyed = false

	-- Bind the wrapper callback once. MeleeHitbox owns the underlying
	-- ShapecastHitbox:OnHit listener, so rebinding this on every swing
	-- is unnecessary and could make callback lifecycle harder to reason about.
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

function MeleeController:CanAttack()
	if self.Destroyed or self.Active then return false end
	if not self.Character or not self.Humanoid or self.Humanoid.Health <= 0 then return false end
	if not self.Hitbox then return false end
	if self.Module.MeleeEnabled == false then return false end
	local Cooldown = math.max(0, self.Module.MeleeCooldown or self.Module.AttackCooldown or 0)
	return os.clock() - self.LastAttackTime >= Cooldown
end

function MeleeController:Start()
	if not self:CanAttack() then return false end

	local Duration = math.max(0, self.Module.MeleeAttackDuration or self.Module.AttackDuration or 0)

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
	return true
end

function MeleeController:Attack(Duration)
	if Duration ~= nil then
		local PreviousDuration = self.Module.MeleeAttackDuration
		self.Module.MeleeAttackDuration = Duration
		local Result = self:Start()
		self.Module.MeleeAttackDuration = PreviousDuration
		return Result
	end
	return self:Start()
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
	if self.Hitbox and self.Hitbox.Destroy then self.Hitbox:Destroy() end
	self.Hitbox = nil
	self.OnHit = nil
	self.OnStart = nil
	self.OnStop = nil
	self.HitTargets = {}
end

return MeleeController
