local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local WeaponSystem = ReplicatedStorage:WaitForChild("WeaponSystem")
local ProjectileController = require(WeaponSystem.Projectile:WaitForChild("ProjectileController"))
local MeleeUtility = require(game.ServerScriptService.WeaponSystem.Melee:WaitForChild("MeleeUtility"))
local ProjectilePickup = require(script.Parent:WaitForChild("ProjectilePickup"))

local ProjectileThrower={}; ProjectileThrower.__index=ProjectileThrower
function ProjectileThrower.new() return setmetatable({ProjectileSystem=ProjectileController.new(),LastThrows={}},ProjectileThrower) end
function ProjectileThrower:Throw(Player,Tool,Origin,Direction,Settings)
	if Settings.ThrowEnabled~=true then return nil end; local Character=Player.Character; local Humanoid=MeleeUtility.GetHumanoid(Character); local Handle=Tool:FindFirstChild("Handle"); if not Humanoid or Humanoid.Health<=0 or not Handle or not Handle:IsA("BasePart") then return nil end
	if typeof(Origin)~="Vector3" or typeof(Direction)~="Vector3" or Direction.Magnitude<=0 or (Origin-Handle.Position).Magnitude>8 then return nil end
	local Now=os.clock(); local Cooldown=math.max(0,tonumber(Settings.ThrowCooldown) or 1); local Last=self.LastThrows[Player] or -math.huge; if Now-Last<Cooldown then return nil end; self.LastThrows[Player]=Now
	local CanPickup=Settings.ThrowStick==true and Settings.PickupEnabled~=false; local PickupTemplate=CanPickup and Tool:Clone() or nil; if PickupTemplate then PickupTemplate.Parent=nil end
	local Params=RaycastParams.new(); Params.FilterType=Enum.RaycastFilterType.Exclude; Params.FilterDescendantsInstances={Character,Tool}; Params.IgnoreWater=true
	local Projectile=self.ProjectileSystem:Fire(Origin,Direction.Unit,{Speed=math.clamp(tonumber(Settings.ThrowSpeed) or 120,1,1000),Gravity=Settings.ThrowGravity or Vector3.new(0,-workspace.Gravity*0.35,0),MaxLifetime=math.clamp(tonumber(Settings.ThrowLifetime) or 5,0.1,30),Visual=Tool,ForceVisible=true,SpinSpeed=Settings.ThrowSpin and Vector3.new(math.rad(-1080),0,0) or nil,StickOnHit=Settings.ThrowStick==true,StickLifetime=Settings.ThrowStickLifetime,RaycastParams=Params,Data={Player=Player,Tool=Tool},OnHit=function(Thrown,Result)
		local TargetHumanoid; if Result.Instance then local Model=Result.Instance:FindFirstAncestorOfClass("Model"); TargetHumanoid=Model and Model:FindFirstChildOfClass("Humanoid") end
		if TargetHumanoid and TargetHumanoid.Health>0 and TargetHumanoid.Parent~=Character then local Damage=tonumber(Settings.ThrowDamage) or tonumber(Settings.BaseDamage) or 0; MeleeUtility.ApplyDamage(Player,TargetHumanoid,Damage,Debris); if type(Settings.ThrowOnCharacterHit)=="function" then Settings.ThrowOnCharacterHit(Thrown,Result,TargetHumanoid,TargetHumanoid.Parent) end elseif type(Settings.ThrowOnSurfaceHit)=="function" then Settings.ThrowOnSurfaceHit(Thrown,Result,Result.Instance) end
	end,OnStuck=function(Thrown)
		if CanPickup then ProjectilePickup.Setup(Player,Tool,PickupTemplate,Thrown,Settings,function(Projectile) self.ProjectileSystem:DestroyProjectile(Projectile) end) elseif PickupTemplate then PickupTemplate:Destroy(); PickupTemplate=nil end
	end,OnExpire=function() if PickupTemplate then PickupTemplate:Destroy(); PickupTemplate=nil end end})
	if not Projectile then if PickupTemplate then PickupTemplate:Destroy() end; return nil end; Tool:Destroy(); return Projectile
end
function ProjectileThrower:RemovePlayer(Player) self.LastThrows[Player]=nil end
function ProjectileThrower:Destroy() self.ProjectileSystem:Destroy(); table.clear(self.LastThrows) end
return ProjectileThrower
