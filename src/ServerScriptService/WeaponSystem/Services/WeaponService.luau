local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponPose = require(ReplicatedStorage.WeaponSystem.Client.WeaponPose)
local WeaponGrip = require(ReplicatedStorage.WeaponSystem.Client.WeaponGrip)

local WeaponService = {}
local ActiveWeapons = {}

function WeaponService.Initialize(Tool)
	if not Tool or not Tool:IsA("Tool") then return nil end
	if ActiveWeapons[Tool] then return ActiveWeapons[Tool] end
	local Setting = Tool:FindFirstChild("Setting")
	if not Setting or not Setting:IsA("ModuleScript") then return nil end
	local Module = require(Setting)
	local State = {Tool=Tool,Module=Module,CurrentPose=nil,GripData=nil,Character=nil,Humanoid=nil}
	local function ClearCharacterState()
		if State.CurrentPose then WeaponPose.Unequip(State.CurrentPose); State.CurrentPose=nil end
		if State.GripData then WeaponGrip.Unequip(State.GripData); State.GripData=nil end
		State.Character=nil; State.Humanoid=nil
	end
	State.EquippedConnection=Tool.Equipped:Connect(function()
		local Character=Tool.Parent
		if not Character or not Character:IsA("Model") then return end
		local Humanoid=Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid or Humanoid.Health<=0 then return end
		ClearCharacterState(); State.Character=Character; State.Humanoid=Humanoid; State.CurrentPose=WeaponPose.Equip(Character,Module)
		if Module.DualEnabled and not workspace.FilteringEnabled then State.GripData=WeaponGrip.Equip(Tool,Module) end
		State.CharacterDiedConnection=Humanoid.Died:Connect(ClearCharacterState)
	end)
	State.UnequippedConnection=Tool.Unequipped:Connect(function()
		if State.CharacterDiedConnection then State.CharacterDiedConnection:Disconnect(); State.CharacterDiedConnection=nil end
		ClearCharacterState()
	end)
	State.DestroyingConnection=Tool.Destroying:Connect(function() WeaponService.Destroy(Tool) end)
	ActiveWeapons[Tool]=State
	return State
end

function WeaponService.Destroy(Tool)
	local State=ActiveWeapons[Tool]
	if not State then return end
	if State.CharacterDiedConnection then State.CharacterDiedConnection:Disconnect(); State.CharacterDiedConnection=nil end
	if State.CurrentPose then WeaponPose.Unequip(State.CurrentPose); State.CurrentPose=nil end
	if State.GripData then WeaponGrip.Unequip(State.GripData); State.GripData=nil end
	if State.EquippedConnection then State.EquippedConnection:Disconnect() end
	if State.UnequippedConnection then State.UnequippedConnection:Disconnect() end
	if State.DestroyingConnection then State.DestroyingConnection:Disconnect() end
	ActiveWeapons[Tool]=nil
end

return WeaponService
