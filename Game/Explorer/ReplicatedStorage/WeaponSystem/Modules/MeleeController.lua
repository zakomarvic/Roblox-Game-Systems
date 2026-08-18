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
	return self
end

function MeleeController:SetCharacter(Character, Humanoid)
	self.Character = Character
	self.Humanoid = Humanoid
end

function MeleeController:SetHitbox(Hitbox)
	self.Hitbox = Hitbox
end

function MeleeController:IsActive()
	return self.Active
end

function MeleeController:Start()
	if self.Active then return false end
	if not self.Character or not self.Humanoid or self.Humanoid.Health <= 0 then return false end
	if not self.Hitbox then return false end

	self.Active = true
	self.AttackId += 1
	self.HitTargets = {}

	if self.OnStart then self.OnStart(self.AttackId) end
	if self.Hitbox.Start then self.Hitbox:Start() end
	return true
end

function MeleeController:_HandleHit(HitPart, RaycastResult, Group)
	if not self.Active or not HitPart then return end
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
			Group = Group,
			TargetCharacter = TargetCharacter,
			TargetHumanoid = TargetHumanoid,
		})
	end
end

function MeleeController:Stop()
	if not self.Active then return false end
	self.Active = false
	if self.Hitbox and self.Hitbox.Stop then self.Hitbox:Stop() end
	if self.OnStop then self.OnStop(self.AttackId) end
	self.HitTargets = {}
	return true
end

function MeleeController:Attack(Duration)
	if not self:Start() then return false end
	if Duration and Duration > 0 then
		task.delay(Duration, function()
			if self.Active then self:Stop() end
		end)
	end
	return true
end

function MeleeController:Destroy()
	self:Stop()
	if self.Hitbox and self.Hitbox.Destroy then self.Hitbox:Destroy() end
	self.Hitbox = nil
	self.OnHit = nil
	self.OnStart = nil
	self.OnStop = nil
end

return MeleeController
