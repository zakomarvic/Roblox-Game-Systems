local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponAnimation = {}
WeaponAnimation.__index = WeaponAnimation

local AnimationController = require(ReplicatedStorage.CharacterSystem.Modules:WaitForChild("AnimationController"))

local function GetAnimationName(Tool, Name)
	return "Weapon:" .. Tool.Name .. ":" .. Name
end

function WeaponAnimation.new(Config)
	local self = setmetatable({}, WeaponAnimation)
	self.Tool = Config.Tool
	self.Humanoid = Config.Humanoid
	self.Module = Config.Module
	self.IdleAnimationSpeed = Config.IdleAnimationSpeed or 1
	self.Equipped = false
	self.CharacterAnimationController = nil
	self.TrackNames = {}
	self.ReviveConnection = nil
	self:_bindAnimator(self.Humanoid)
	return self
end

function WeaponAnimation:_disconnectReviveConnection()
	if self.ReviveConnection and self.ReviveConnection.Connected then
		self.ReviveConnection:Disconnect()
	end
	self.ReviveConnection = nil
end

function WeaponAnimation:_bindReviveState(Character)
	self:_disconnectReviveConnection()
	if not Character then return end

	self.ReviveConnection = Character:GetAttributeChangedSignal("Reviving"):Connect(function()
		if Character:GetAttribute("Reviving") == false and self.Equipped then
			self:Play("IdleAnim", self.IdleAnimationSpeed)
		end
	end)
end

function WeaponAnimation:_unloadTracks()
	if self.CharacterAnimationController then
		for _, ControllerName in pairs(self.TrackNames) do
			self.CharacterAnimationController:Unload(ControllerName)
		end
	end
	self.TrackNames = {}
end

function WeaponAnimation:_bindAnimator(Humanoid)
	self:_disconnectReviveConnection()
	self:_unloadTracks()
	self.Humanoid = Humanoid
	self.CharacterAnimationController = nil
	if not Humanoid then return nil end

	local Character = Humanoid.Parent
	if not Character or not Character:IsA("Model") then return nil end

	self.CharacterAnimationController = AnimationController.GetController(Character)
	self:_bindReviveState(Character)
	self:_load()
	return self.CharacterAnimationController.Animator
end

function WeaponAnimation:_load()
	local Module = self.Module
	local Controller = self.CharacterAnimationController
	if not Controller then return end

	local function load(Name, AnimationId, Enabled, Priority, Looped)
		if not Enabled or AnimationId == nil then return nil end
		local ControllerName = GetAnimationName(self.Tool, Name)
		local Track = Controller:Load(ControllerName, AnimationId, Priority, Looped)
		self.TrackNames[Name] = ControllerName
		return Track
	end

	local IdleId = Module.DualEnabled and 53610688 or Module.IdleAnimationID
	load("IdleAnim", IdleId, IdleId ~= nil, nil, true)
	load("FireAnim", Module.FireAnimationID, Module.FireAnimationID ~= nil)
	load("ReloadAnim", Module.ReloadAnimationID, Module.ReloadAnimationID ~= nil)
	load("ShotgunClipinAnim", Module.ShotgunClipinAnimationID, Module.ShotgunClipinAnimationID ~= nil)
	load("AttackAnim", Module.AttackAnimationID, Module.AttackAnimationID ~= nil, Enum.AnimationPriority.Action)
	load("ThrowAnim", Module.ThrowAnimationID, Module.ThrowAnimationID ~= nil, Enum.AnimationPriority.Action)
end

function WeaponAnimation:SetHumanoid(Humanoid)
	self:_bindAnimator(Humanoid)
end

function WeaponAnimation:SetEquipped(Equipped)
	self.Equipped = Equipped == true
	if not self.Equipped then
		self:Stop("IdleAnim")
	elseif self.Humanoid and self.Humanoid.Parent then
		local Character = self.Humanoid.Parent
		if Character:GetAttribute("Reviving") ~= true then
			self:Play("IdleAnim", self.IdleAnimationSpeed)
		end
	end
end

function WeaponAnimation:Get(Name)
	local ControllerName = self.TrackNames[Name]
	return ControllerName and self.CharacterAnimationController and self.CharacterAnimationController:Get(ControllerName) or nil
end

function WeaponAnimation:GetAll()
	local Tracks = {}
	for Name in pairs(self.TrackNames) do
		Tracks[Name] = self:Get(Name)
	end
	return Tracks
end

function WeaponAnimation:Play(Name, Speed, FadeTime, Weight)
	local ControllerName = self.TrackNames[Name]
	if not ControllerName or not self.CharacterAnimationController then return false end
	return self.CharacterAnimationController:Play(ControllerName, Speed, FadeTime, Weight) ~= nil
end

function WeaponAnimation:Stop(Name, FadeTime)
	local ControllerName = self.TrackNames[Name]
	if not ControllerName or not self.CharacterAnimationController then return false end
	self.CharacterAnimationController:Stop(ControllerName, FadeTime)
	return true
end

function WeaponAnimation:StopAll()
	if not self.CharacterAnimationController then return end
	for _, ControllerName in pairs(self.TrackNames) do
		self.CharacterAnimationController:Stop(ControllerName)
	end
end

function WeaponAnimation:Destroy()
	self:_disconnectReviveConnection()
	self:_unloadTracks()
	self.CharacterAnimationController = nil
	self.Humanoid = nil
	self.Equipped = false
end

return WeaponAnimation
