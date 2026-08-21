local WeaponBootstrap = {}
WeaponBootstrap.__index = WeaponBootstrap

function WeaponBootstrap.new(Config)
	local self = setmetatable({}, WeaponBootstrap)
	self.Tool = Config.Tool
	self.Module = Config.Module
	self.ReplicatedStorage = Config.ReplicatedStorage
	self.Player = Config.Player
	self.Script = Config.Script
	self.RunService = Config.RunService
	return self
end

function WeaponBootstrap:WaitForHandle()
	return self.Tool:WaitForChild("Handle")
end

function WeaponBootstrap:GetHandle2()
	if not self.Module.DualEnabled then return nil end
	local Handle2 = self.Tool:WaitForChild("Handle2", 2)
	if not Handle2 then error('"Dual" setting is enabled but "Handle2" is missing!') end
	return Handle2
end

function WeaponBootstrap:WaitForCharacter()
	local Character = self.Player.Character or self.Player.CharacterAdded:Wait()
	local Humanoid = Character:WaitForChild("Humanoid")
	return Character, Humanoid
end

function WeaponBootstrap:GetGUI()
	return self.Script:WaitForChild("GunGUI"), self.Script:WaitForChild("Mouse Sensitivity")
end

function WeaponBootstrap:GetRemotes()
	local WeaponSystem = self.ReplicatedStorage:WaitForChild("WeaponSystem")
	local Remotes = WeaponSystem:WaitForChild("Remotes")
	return Remotes:WaitForChild("WeaponEffects"), Remotes:WaitForChild("InflictTarget")
end

function WeaponBootstrap:Wait(TimeToWait)
	if TimeToWait ~= nil then
		local TotalTime = 0
		TotalTime += self.RunService.Heartbeat:Wait()
		while TotalTime < TimeToWait do
			TotalTime += self.RunService.Heartbeat:Wait()
		end
	else
		self.RunService.Heartbeat:Wait()
	end
end

return WeaponBootstrap