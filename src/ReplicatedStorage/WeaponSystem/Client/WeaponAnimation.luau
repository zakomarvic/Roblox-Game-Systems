local WeaponAnimation = {}
WeaponAnimation.__index = WeaponAnimation

local function HumanoidLabel(Humanoid)
	if not Humanoid then return "nil" end
	return Humanoid.Name .. "@" .. (Humanoid.Parent and Humanoid.Parent.Name or "no-parent")
end

local function GetAnimation(Tool, Name, AnimationId)
	if AnimationId == nil then return nil end

	local Animation = Tool:FindFirstChild(Name)
	if not Animation then
		Animation = Instance.new("Animation")
		Animation.Name = Name
		Animation.Parent = Tool
	end

	Animation.AnimationId = "rbxassetid://" .. tostring(AnimationId)
	return Animation
end

function WeaponAnimation.new(Config)
	local self = setmetatable({}, WeaponAnimation)
	self.Tool = Config.Tool
	self.Humanoid = Config.Humanoid
	self.Module = Config.Module
	self.Animator = nil
	self.Tracks = {}
	self:_bindAnimator(self.Humanoid)
	return self
end

function WeaponAnimation:_bindAnimator(Humanoid)
	self.Humanoid = Humanoid
	self.Animator = nil
	if not Humanoid then return nil end

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end

	self.Animator = Animator
	self.Tracks = {}
	self:_load()
	return Animator
end

function WeaponAnimation:_load()
	local Module = self.Module
	local Animator = self.Animator
	if not Animator then return end

	local function load(Name, AnimationId, Enabled, Priority)
		if not Enabled or AnimationId == nil then return nil end
		local Animation = GetAnimation(self.Tool, Name, AnimationId)
		if not Animation then return nil end

		local Track = Animator:LoadAnimation(Animation)
		if Priority then Track.Priority = Priority end
		self.Tracks[Name] = Track
		--print(string.format("[WeaponAnimation] Loaded %s on %s Animator=%s Priority=%s", Name, HumanoidLabel(self.Humanoid), Animator.Name, tostring(Track.Priority)))
		return Track
	end

	local IdleId = Module.DualEnabled and 53610688 or Module.IdleAnimationID
	load("IdleAnim", IdleId, IdleId ~= nil)
	load("FireAnim", Module.FireAnimationID, Module.FireAnimationID ~= nil)
	load("ReloadAnim", Module.ReloadAnimationID, Module.ReloadAnimationID ~= nil)
	load("ShotgunClipinAnim", Module.ShotgunClipinAnimationID, Module.ShotgunClipinAnimationID ~= nil)
	load("AttackAnim", Module.AttackAnimationID, Module.AttackAnimationID ~= nil, Enum.AnimationPriority.Action)
	load("ThrowAnim", Module.ThrowAnimationID, Module.ThrowAnimationID ~= nil, Enum.AnimationPriority.Action)
end

function WeaponAnimation:SetHumanoid(Humanoid)
	self:StopAll()
	self:_bindAnimator(Humanoid)
end

function WeaponAnimation:Get(Name)
	return self.Tracks[Name]
end

function WeaponAnimation:GetAll()
	return self.Tracks
end

function WeaponAnimation:Play(Name, Speed, FadeTime)
	local Track = self.Tracks[Name]
	if not Track then return false end
	if Track.IsPlaying then Track:Stop(FadeTime or 0) end
	Track:Play(FadeTime or 0.05, 1, Speed or 1)
	return true
end

function WeaponAnimation:Stop(Name, FadeTime)
	local Track = self.Tracks[Name]
	if not Track then return false end
	Track:Stop(FadeTime or 0.05)
	return true
end

function WeaponAnimation:StopAll()
	for _, Track in pairs(self.Tracks) do
		if Track then Track:Stop() end
	end
	table.clear(self.Tracks)
end

return WeaponAnimation