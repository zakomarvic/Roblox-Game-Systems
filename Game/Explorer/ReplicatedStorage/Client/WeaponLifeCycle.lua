local WeaponLifecycle = {}
WeaponLifecycle.__index = WeaponLifecycle

function WeaponLifecycle.new(dependencies)
	local self = setmetatable({}, WeaponLifecycle)
	self.Equipped = false
	self.HasActiveState = false
	self.Blocked = false
	self.Connections = {}
	self.PersistentConnections = {}
	self.Cleanups = {}
	self.Dependencies = dependencies or {}
	self.Character = nil
	self.Humanoid = nil
	return self
end

function WeaponLifecycle:AddConnection(Connection)
	if Connection then table.insert(self.Connections, Connection) end
	return Connection
end

function WeaponLifecycle:AddPersistentConnection(Connection)
	if Connection then table.insert(self.PersistentConnections, Connection) end
	return Connection
end

function WeaponLifecycle:AddCleanup(Cleanup)
	if typeof(Cleanup) == "function" then table.insert(self.Cleanups, Cleanup) end
end

function WeaponLifecycle:IsEquipped() return self.Equipped end
function WeaponLifecycle:IsBlocked() return self.Blocked end

function WeaponLifecycle:SetDependency(Name, Value)
	if not self.Dependencies then self.Dependencies = {} end
	self.Dependencies[Name] = Value
end

function WeaponLifecycle:SetCharacter(Character, Humanoid)
	if not Character or not Humanoid then return false end
	self.Character = Character
	self.Humanoid = Humanoid

	local D = self.Dependencies
	if D.OnCharacterChanged then
		D.OnCharacterChanged(Character, Humanoid, self)
	end
	return true
end

function WeaponLifecycle:SetBackpackEnabled(Enabled)
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, Enabled)
	end)
end

function WeaponLifecycle:BindTool(Tool)
	if not Tool then return false end
	self:AddPersistentConnection(Tool.Equipped:Connect(function()
		self:Equip()
	end))
	self:AddPersistentConnection(Tool.Unequipped:Connect(function()
		self:Unequip()
	end))
	return true
end

function WeaponLifecycle:BindCharacter(Player, RunService, Tool)
	if not Player or not RunService then return false end

	local function BindDeath(Humanoid)
		self:AddPersistentConnection(Humanoid.Died:Connect(function()
			self:Block()
			self:Died()
			Humanoid:UnequipTools()
			self:SetBackpackEnabled(false)
		end))
	end

	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")
	if Humanoid.Health <= 0 then
		self:Block()
	else
		self:Unblock()
		self:SetBackpackEnabled(true)
	end
	self:SetCharacter(Character, Humanoid)
	BindDeath(Humanoid)

	self:AddPersistentConnection(Player.CharacterAdded:Connect(function(NewCharacter)
		local NewHumanoid = NewCharacter:WaitForChild("Humanoid")

		self:Block()
		self:SetBackpackEnabled(false)
		NewHumanoid:UnequipTools()
		if Tool and Tool.Parent == NewCharacter then
			Tool.Parent = Player.Backpack
		end

		self:SetCharacter(NewCharacter, NewHumanoid)
		BindDeath(NewHumanoid)

		if NewHumanoid.Health > 0 then
			RunService.Heartbeat:Wait()
			if NewHumanoid.Health > 0 and NewHumanoid.Parent == NewCharacter then
				self:Unblock()
				self:SetBackpackEnabled(true)
			end
		end
	end))
	return true
end

function WeaponLifecycle:Equip()
	if self.Blocked or self.Equipped then return false end
	self:CleanupConnections()
	self.Equipped = true
	self.HasActiveState = true
	local D = self.Dependencies
	if D.Controller then D.Controller:SetEnabled(true) end
	if D.Camera then
		D.Camera:SetEquipped(true)
		D.Camera:Start()
	end
	if D.Aim then D.Aim:Reset() end
	if D.Input then D.Input:Bind() end
	if D.GetIdleAnim then
		local IdleAnim = D.GetIdleAnim()
		if IdleAnim then IdleAnim:Play(nil, nil, D.IdleAnimationSpeed or 1) end
	end
	if D.SprintChanged and D.OnSprint then
		local SprintEvent = D.SprintChanged
		self:AddConnection(SprintEvent.Event:Connect(function(IsSprinting)
			if self.Equipped and not self.Blocked then D.OnSprint(IsSprinting) end
		end))
	end
	if D.OnEquip then D.OnEquip(self) end
	return true
end

function WeaponLifecycle:Unequip()
	if not self.Equipped and not self.HasActiveState then
		self:CleanupConnections()
		return
	end
	self.Equipped = false
	self.HasActiveState = false
	local D = self.Dependencies
	if D.TriggerReleased then D.TriggerReleased() end
	if D.Input then D.Input:Unbind() end
	if D.Camera then
		D.Camera:SetEquipped(false)
		D.Camera:Stop()
	end
	if D.Aim then D.Aim:Reset() end
	if D.GetIdleAnim then
		local IdleAnim = D.GetIdleAnim()
		if IdleAnim then IdleAnim:Stop() end
	end
	if D.Controller then D.Controller:SetEnabled(not self.Blocked) end
	self:CleanupConnections()
	if D.OnUnequip then D.OnUnequip(self) end
end

function WeaponLifecycle:Block()
	self.Blocked = true
	if self.Equipped or self.HasActiveState then self:Unequip() end
	local D = self.Dependencies
	if D.Controller then D.Controller:SetEnabled(false) end
end

function WeaponLifecycle:Unblock()
	self.Blocked = false
	local D = self.Dependencies
	if D.Controller then D.Controller:SetEnabled(true) end
end

function WeaponLifecycle:Died()
	local D = self.Dependencies
	if D.OnDeath then D.OnDeath(self) end
end

function WeaponLifecycle:CleanupConnections()
	for _, Connection in ipairs(self.Connections) do
		if Connection and Connection.Connected then Connection:Disconnect() end
	end
	table.clear(self.Connections)
end

function WeaponLifecycle:Destroy()
	self:Unequip()
	for _, Connection in ipairs(self.PersistentConnections) do
		if Connection and Connection.Connected then Connection:Disconnect() end
	end
	for _, Cleanup in ipairs(self.Cleanups) do pcall(Cleanup) end
	table.clear(self.Connections)
	table.clear(self.PersistentConnections)
	table.clear(self.Dependencies)
	self.Character = nil
	self.Humanoid = nil
end

return WeaponLifecycle
