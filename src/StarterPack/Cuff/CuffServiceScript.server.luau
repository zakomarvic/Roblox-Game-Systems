local PhysicsService = game:GetService("PhysicsService")
local playerCollisionGroupName = "NOCOLLIDECHARACTERS"

for _, group in pairs(PhysicsService:GetRegisteredCollisionGroups()) do
	print(group.name)
end

pcall(function()
	PhysicsService:RegisterCollisionGroup(playerCollisionGroupName)
end)

PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, playerCollisionGroupName, false)

local Players = game:GetService("Players")
local Cuffing = false
local CuffServiceEvent = script.Parent.CuffService
local UncuffEevnt = script.Parent.Uncuff
local Sttng = require(game:GetService("ReplicatedStorage"):WaitForChild("CuffRep"):WaitForChild("Settings"))


local function setCollisionGroup(character:Model)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then		
			part.CollisionGroup = playerCollisionGroupName
		end
	end
end


local function resetCollisionGroup(character:Model)
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Default"
		end
	end
end


CuffServiceEvent.OnServerEvent:Connect(function(player: Player, Target) 
	--print(player, Target)
	if not Target then return end
	Target = Target.Parent
	local PlayerCharacter = player.Character
	Cuffing = true
	local animationTrack
	if Target:FindFirstChild("Torso") then
		local animationr6 = Instance.new("Animation")
		animationr6.AnimationId = Sttng.Animations.r6Anim
		animationr6.Parent = script
		animationTrack = Target:FindFirstChild("Humanoid"):LoadAnimation(animationr6)
	end

	if Target:FindFirstChild("UpperTorso") then
		local animationr15 = Instance.new("Animation")
		animationr15.AnimationId = Sttng.Animations.r15Anim
		animationr15.Parent = script
		animationTrack = Target:FindFirstChild("Humanoid"):LoadAnimation(animationr15)
	end
	
	local function update()
		while task.wait()  do
			
			if Cuffing then
				if Target:FindFirstChild("HumanoidRootPart") then								
					
					Target.HumanoidRootPart.Anchored = true
					Target.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
					if not animationTrack.IsPlaying then
						animationTrack:Play()  
					end
					
					Target.HumanoidRootPart.CFrame = PlayerCharacter.HumanoidRootPart.CFrame * CFrame.new( 0, 0, -2.8 )
					setCollisionGroup(Target)
					setCollisionGroup(PlayerCharacter)
				end
			else
										
				resetCollisionGroup(Target)
				resetCollisionGroup(PlayerCharacter)
				Target.HumanoidRootPart.Anchored = false
				if animationTrack.IsPlaying then
					animationTrack:Stop()
				end
				break 
			end
		end


	end
	task.spawn(update)

end)

UncuffEevnt.OnServerEvent:Connect(function(player: Player, ...: any) 
	Cuffing = false
	
end)