local Tool = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = workspace

local Setting = require(Tool:WaitForChild("Setting"))
local WeaponController = require(ReplicatedStorage.WeaponSystem.Client.WeaponController)
local WeaponFire = require(ReplicatedStorage.WeaponSystem.Client.WeaponFire)
local WeaponReload = require(ReplicatedStorage.WeaponSystem.Client.WeaponReload)
local WeaponCamera = require(ReplicatedStorage.WeaponSystem.Client.WeaponCamera)
local WeaponAim = require(ReplicatedStorage.WeaponSystem.Client.WeaponAim)
local WeaponInput = require(ReplicatedStorage.WeaponSystem.Client.WeaponInput)
local WeaponLifecycle = require(ReplicatedStorage.WeaponSystem.Client.WeaponLifecycle)
local WeaponGUI = require(ReplicatedStorage.WeaponSystem.Client.WeaponGUI)
local WeaponRaycast = require(ReplicatedStorage.WeaponSystem.Utility.WeaponRaycast)
local WeaponFireCycle = require(ReplicatedStorage.WeaponSystem.Client.WeaponFireCycle)
local WeaponAnimation = require(ReplicatedStorage.WeaponSystem.Client.WeaponAnimation)
local WeaponCharacter = require(ReplicatedStorage.WeaponSystem.Client.WeaponCharacter)
local WeaponBootstrap = require(ReplicatedStorage.WeaponSystem.Client.WeaponBootstrap)
local WeaponFireEffects = require(ReplicatedStorage.WeaponSystem.Effects.WeaponFireEffects)
local WeaponReloadEffects = require(ReplicatedStorage.WeaponSystem.Effects.WeaponReloadEffects)
local CharacterController = require(ReplicatedStorage.CharacterSystem.Modules.CharacterController)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()
local Camera = Workspace.CurrentCamera
local CharacterControllerInstance = CharacterController.Get()
local Bootstrap = WeaponBootstrap.new({Tool=Tool,Module=Setting,ReplicatedStorage=ReplicatedStorage,Player=Player,Script=script,RunService=RunService})
local Character, Humanoid = Bootstrap:WaitForCharacter()
local Controller = WeaponController.new(Tool,Setting)
local Handle = Bootstrap:WaitForHandle()
local Handle2 = Bootstrap:GetHandle2()
local GUI,AimSensitivity = Bootstrap:GetGUI()
local WeaponEffects,InflictTarget = Bootstrap:GetRemotes()
local WeaponCameraInstance = WeaponCamera.new(Camera,Humanoid,Character,Setting)
local WeaponAnimationInstance = WeaponAnimation.new({Tool=Tool,Humanoid=Humanoid,Module=Setting})
local WeaponGUIInstance = WeaponGUI.new(GUI,Setting,Controller)
local WeaponFireInstance
local WeaponCharacterInstance

local WeaponAimInstance = WeaponAim.new(Camera,Player,Mouse,GUI,AimSensitivity,Setting,function(State)
	WeaponCameraInstance:SetAiming(State)
	if WeaponFireInstance then WeaponFireInstance:SetAiming(State) end
end)

WeaponFireInstance = WeaponFire.new({Tool=Tool,Module=Setting,Character=Character,Humanoid=Humanoid,Mouse=Mouse,GetFireAnim=function() return WeaponAnimationInstance:Get("FireAnim") end,Raycast=WeaponRaycast.Cast,InflictTarget=InflictTarget})
WeaponCharacterInstance = WeaponCharacter.new({Character=Character,Humanoid=Humanoid,Tool=Tool,Module=Setting,Handle2=Handle2,Mouse=Mouse,Workspace=Workspace})

local Reload = WeaponReload.new({Tool=Tool,Module=Setting,Controller=Controller,Handle=Handle,GetReloadAnim=function() return WeaponAnimationInstance:Get("ReloadAnim") end,GetShotgunClipinAnim=function() return WeaponAnimationInstance:Get("ShotgunClipinAnim") end,ReloadEffects=WeaponReloadEffects,WeaponEffects=WeaponEffects,IsSprinting=function() return Setting.SprintEnabled and CharacterControllerInstance:IsSprinting() end,IsAiming=function() return WeaponAimInstance:IsAiming() end,ResetAim=function() WeaponAimInstance:Reset() end,UpdateGUI=function() WeaponGUIInstance:Update() end,Wait=function(Time) Bootstrap:Wait(Time) end})
local FireCycle = WeaponFireCycle.new({Controller=Controller,Module=Setting,CharacterController=CharacterControllerInstance,Aim=WeaponAimInstance,Humanoid=Humanoid,WeaponFire=WeaponFireInstance,FireEffects=WeaponFireEffects,GUI=WeaponGUIInstance,Reload=Reload,Handle=Handle,Handle2=Handle2,Wait=function(Time) Bootstrap:Wait(Time) end,OnRecoil=function() WeaponCameraInstance:AddRecoil() end})
WeaponCharacterInstance.FireCycle=FireCycle

local WeaponInputInstance = WeaponInput.new(Mouse,{OnFireDown=function() FireCycle:FireDown() end,OnFireUp=function() FireCycle:FireUp() end,OnReload=function() Reload:Start() end,OnAim=function() if not Controller:GetReloading() and Setting.SniperEnabled then WeaponAimInstance:Toggle() end end})

local WeaponLifecycleInstance = WeaponLifecycle.new({Controller=Controller,Camera=WeaponCameraInstance,Aim=WeaponAimInstance,Input=WeaponInputInstance,Script=script,GetIdleAnim=function() return WeaponAnimationInstance:Get("IdleAnim") end,IdleAnimationSpeed=Setting.IdleAnimationSpeed,TriggerReleased=function() FireCycle:FireUp() end,SprintChanged=CharacterControllerInstance.SprintChanged,OnCharacterChanged=function(NewCharacter,NewHumanoid)
	WeaponCameraInstance:SetCharacter(NewCharacter,NewHumanoid)
	WeaponFireInstance:SetCharacter(NewCharacter,NewHumanoid)
	FireCycle:SetHumanoid(NewHumanoid)
	WeaponAnimationInstance:SetHumanoid(NewHumanoid)
	WeaponCharacterInstance:SetCharacter(NewCharacter,NewHumanoid)
end,OnSprint=function(IsSprinting) if IsSprinting then Controller:SetTriggerHeld(false);if Controller:GetReloading() then Controller:SetReloading(false) end;if Controller:IsCurrentlyFiring() then Controller:StopFiring() end;WeaponAimInstance:Reset() end end,OnEquip=function()
	FireCycle:SetEquipped(true)
	WeaponGUIInstance:Update()
	WeaponCharacterInstance:EquipPose()
	WeaponGUIInstance:Show()
	Mouse.Icon="rbxassetid://"..Setting.MouseIconID
end,OnUnequip=function() FireCycle:SetEquipped(false);WeaponCharacterInstance:ClearPose();WeaponGUIInstance:Hide() end,OnDeath=function() FireCycle:SetEquipped(false);WeaponCharacterInstance:ClearPose();WeaponGUIInstance:Hide() end,Player=Player,Tool=Tool,RunService=RunService})
WeaponCharacterInstance.IsEquipped=function() return WeaponLifecycleInstance:IsEquipped() end

WeaponLifecycleInstance:BindCharacter(Player,RunService,Tool)
WeaponLifecycleInstance:BindTool(Tool)