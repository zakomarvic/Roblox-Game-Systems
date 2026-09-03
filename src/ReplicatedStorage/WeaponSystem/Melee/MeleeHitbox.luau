local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MeleeHitbox = {}
MeleeHitbox.__index = MeleeHitbox

local function getShapecastHitbox()
	local Container = ReplicatedStorage.WeaponSystem.Melee:WaitForChild("ShapecastHitbox")
	if Container:IsA("ModuleScript") then return require(Container) end
	local Module = Container:FindFirstChild("init") or Container:FindFirstChild("ShapecastHitbox")
	if not Module or not Module:IsA("ModuleScript") then Module = Container:FindFirstChildWhichIsA("ModuleScript", true) end
	assert(Module, "ShapecastHitbox module was not found inside WeaponSystem.Melee.ShapecastHitbox")
	return require(Module)
end
function MeleeHitbox.new(Config)
	assert(Config.Origin, "MeleeHitbox requires an Origin instance")
	local self=setmetatable({},MeleeHitbox); self.Origin=Config.Origin; self.RaycastParams=Config.RaycastParams or RaycastParams.new(); self.OnHit=Config.OnHit; self.Resolution=Config.Resolution or 60; self.CastData=Config.CastData; self.Active=false; self.Destroyed=false
	local ShapecastHitbox=getShapecastHitbox(); self.Hitbox=ShapecastHitbox.new(self.Origin,self.RaycastParams); self.Hitbox:SetResolution(self.Resolution)
	if self.CastData then self.Hitbox:SetCastData(self.CastData) end
	self.Hitbox:OnHit(function(RaycastResult,Segment) if self.OnHit then self.OnHit(RaycastResult,Segment) end end)
	return self
end
function MeleeHitbox:SetOrigin(Origin) assert(not self.Destroyed,"MeleeHitbox has been destroyed"); self.Origin=Origin; self.Hitbox.Instance=Origin; self.Hitbox:Reconcile() end
function MeleeHitbox:SetResolution(Resolution) self.Resolution=Resolution; self.Hitbox:SetResolution(Resolution) end
function MeleeHitbox:SetCastData(CastData) self.CastData=CastData; self.Hitbox:SetCastData(CastData) end
function MeleeHitbox:Reconcile() self.Hitbox:Reconcile() end
function MeleeHitbox:Start(Duration,OverrideRaycastParams) if self.Destroyed or self.Active or not self.Origin or not self.Origin.Parent then return false end; self.Active=true; self.Hitbox:HitStart(Duration,OverrideRaycastParams); return true end
function MeleeHitbox:Stop() if self.Destroyed or not self.Active then return false end; self.Active=false; self.Hitbox:HitStop(); return true end
function MeleeHitbox:IsActive() return self.Active and self.Hitbox.Active end
function MeleeHitbox:Destroy() if self.Destroyed then return end; self.Destroyed=true; self.Active=false; if self.Hitbox then self.Hitbox:Destroy() end; self.Hitbox=nil; self.Origin=nil; self.OnHit=nil end
return MeleeHitbox
