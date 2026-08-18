local RunService = game:GetService("RunService")

local MeleeHitbox = {}
MeleeHitbox.__index = MeleeHitbox

function MeleeHitbox.new(Config)
	local self = setmetatable({}, MeleeHitbox)
	self.Origin = Config.Origin
	self.Size = Config.Size or Vector3.new(4, 4, 4)
	self.Offset = Config.Offset or CFrame.identity
	self.RaycastParams = Config.RaycastParams
	self.OnHit = Config.OnHit
	self.Active = false
	self.Connection = nil
	self.LastCFrame = nil
	self.HitParts = {}
	return self
end

function MeleeHitbox:SetOrigin(Origin)
	self.Origin = Origin
end

function MeleeHitbox:SetSize(Size)
	self.Size = Size
end

function MeleeHitbox:SetOffset(Offset)
	self.Offset = Offset or CFrame.identity
end

function MeleeHitbox:_GetCFrame()
	if not self.Origin then return nil end
	if self.Origin:IsA("Attachment") then
		return self.Origin.WorldCFrame * self.Offset
	elseif self.Origin:IsA("BasePart") then
		return self.Origin.CFrame * self.Offset
	elseif self.Origin:IsA("Model") then
		local Root = self.Origin.PrimaryPart or self.Origin:FindFirstChild("HumanoidRootPart")
		return Root and Root.CFrame * self.Offset or nil
	end
	return nil
end

function MeleeHitbox:_Cast()
	local CurrentCFrame = self:_GetCFrame()
	if not CurrentCFrame then return end

	local Direction = Vector3.zero
	if self.LastCFrame then
		Direction = CurrentCFrame.Position - self.LastCFrame.Position
	end

	local Result = workspace:Blockcast(CurrentCFrame, self.Size, Direction, self.RaycastParams)
	self.LastCFrame = CurrentCFrame

	if Result and Result.Instance and not self.HitParts[Result.Instance] then
		self.HitParts[Result.Instance] = true
		if self.OnHit then
			self.OnHit(Result.Instance, Result)
		end
	end
end

function MeleeHitbox:Start()
	if self.Active then return false end
	if not self.Origin then return false end

	self.Active = true
	self.HitParts = {}
	self.LastCFrame = self:_GetCFrame()
	self:_Cast()

	self.Connection = RunService.Heartbeat:Connect(function()
		if not self.Active then return end
		self:_Cast()
	end)
	return true
end

function MeleeHitbox:Stop()
	if not self.Active then return false end
	self.Active = false
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	self.LastCFrame = nil
	self.HitParts = {}
	return true
end

function MeleeHitbox:Destroy()
	self:Stop()
	self.Origin = nil
	self.OnHit = nil
	self.RaycastParams = nil
end

return MeleeHitbox
