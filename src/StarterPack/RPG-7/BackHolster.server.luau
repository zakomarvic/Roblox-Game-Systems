local Tool = script.Parent
local Handle = script.Parent:WaitForChild("Handle")
function Equipped(Mouse)
	Player = script.Parent.Parent
	if Player:FindFirstChild("BackHolster") then
		Player.BackHolster:remove()
	end
end

function Unequipped(Mouse)
	if Player:FindFirstChild("Holster")==nil then
	local Holster = Handle:Clone()
local BackAttachment = Instance.new("Attachment")
BackAttachment.Axis = Vector3.new(0, -1, 1) --change to (0,-1,-1) if you want it on the torso's front
BackAttachment.Name = "WaistAttachment"
BackAttachment.Parent = Holster
Holster.Parent = Player
Holster.Name = "BackHolster"
local Torso = Player:FindFirstChild("UpperTorso") or Player:FindFirstChild("Torso")
	if Torso then
	local w=Instance.new("Motor")
		w.Part0=Holster
		w.Part1=Torso
		w.C0=BackAttachment.CFrame+Vector3.new(.5,0,0)
		w.Parent=Holster
	end
end
end
Tool.Equipped:connect(Equipped)
Tool.Unequipped:connect(Unequipped)