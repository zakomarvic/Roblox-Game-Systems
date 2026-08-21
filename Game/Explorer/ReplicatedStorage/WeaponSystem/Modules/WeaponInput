local WeaponInput = {}
WeaponInput.__index = WeaponInput

function WeaponInput.new(Mouse, Callbacks)
	local self = setmetatable({}, WeaponInput)
	self.Mouse = Mouse
	self.Callbacks = Callbacks or {}
	self.Connections = {}
	self.KeyConnection = nil
	self.Bound = false
	return self
end

function WeaponInput:Bind()
	if self.Bound then
		return
	end

	self.Bound = true

	table.insert(self.Connections, self.Mouse.Button1Down:Connect(function()
		if self.Callbacks.OnFireDown then
			self.Callbacks.OnFireDown()
		end
	end))

	table.insert(self.Connections, self.Mouse.Button1Up:Connect(function()
		if self.Callbacks.OnFireUp then
			self.Callbacks.OnFireUp()
		end
	end))

	self.KeyConnection = self.Mouse.KeyDown:Connect(function(Key)
		Key = string.lower(Key)
		if Key == "r" then
			if self.Callbacks.OnReload then
				self.Callbacks.OnReload()
			end
		elseif Key == "e" then
			if self.Callbacks.OnAim then
				self.Callbacks.OnAim()
			end
		end
	end)
end

function WeaponInput:Unbind()
	for _, Connection in ipairs(self.Connections) do
		Connection:Disconnect()
	end
	table.clear(self.Connections)

	if self.KeyConnection then
		self.KeyConnection:Disconnect()
		self.KeyConnection = nil
	end

	self.Bound = false
end

function WeaponInput:Destroy()
	self:Unbind()
	self.Mouse = nil
	self.Callbacks = nil
end

return WeaponInput
