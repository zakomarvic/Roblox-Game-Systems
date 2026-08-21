local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local CharacterSystem = ReplicatedStorage:WaitForChild("CharacterSystem")
local Modules = CharacterSystem:WaitForChild("Modules")
local Settings = require(Modules:WaitForChild("ReviveSettings"))
local Animations = require(Modules:WaitForChild("ReviveAnimations"))

local Remote = CharacterSystem:FindFirstChild("ReviveRemote")
if not Remote then
	Remote = Instance.new("RemoteEvent")
	Remote.Name = "ReviveRemote"
	Remote.Parent = CharacterSystem
end

local DOWNED_ATTRIBUTE = "Downed"
local REVIVING_ATTRIBUTE = "Reviving"
local REVIVE_PROMPT = "RevivePrompt"

local Prompts = {}
local ActiveRevives = {}
local CharacterConnections = {}
local NPCTracks = {}

local function getCharacterRoot(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function isDowned(character)
	local humanoid = getHumanoid(character)
	return character
		and character.Parent
		and character:GetAttribute(DOWNED_ATTRIBUTE) == true
		and humanoid
		and humanoid.Health > 0
end

local function isPlayerCharacter(character)
	return Players:GetPlayerFromCharacter(character) ~= nil
end

local function getDistance(characterA, characterB)
	local rootA = getCharacterRoot(characterA)
	local rootB = getCharacterRoot(characterB)
	if not rootA or not rootB then
		return math.huge
	end
	return (rootA.Position - rootB.Position).Magnitude
end

local function stopClientAnimation(player, animationName)
	if player then
		Remote:FireClient(player, "Stop", animationName)
	end
end

local function getNPCAnimator(character)
	local humanoid = getHumanoid(character)
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function stopNPCAnimation(character, animationName)
	local tracks = NPCTracks[character]
	local track = tracks and tracks[animationName]
	if track then
		track:Stop(0.1)
	end
end

local function playNPCAnimation(character, animationName)
	if isPlayerCharacter(character) then
		return nil
	end

	local data = Animations[animationName]
	if not data then
		return nil
	end

	local animator = getNPCAnimator(character)
	if not animator then
		return nil
	end

	NPCTracks[character] = NPCTracks[character] or {}
	local tracks = NPCTracks[character]

	for name, existingTrack in pairs(tracks) do
		if name ~= animationName and existingTrack.IsPlaying then
			existingTrack:Stop(0.1)
		end
	end

	local track = tracks[animationName]
	if not track then
		local animation = Instance.new("Animation")
		animation.Name = animationName
		animation.AnimationId = "rbxassetid://" .. tostring(data.Id)
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = data.Looped == true
		animation:Destroy()
		tracks[animationName] = track
	end

	track.Looped = data.Looped == true
	track:Play(0.1, 1, data.Speed or 1)
	track:AdjustSpeed(data.Speed or 1)
	return track
end

local function playDownedNPCState(character)
	if isPlayerCharacter(character) or not isDowned(character) then
		return
	end

	local track = playNPCAnimation(character, "PlayerDowned")
	if track then
		track.Ended:Once(function()
			if character.Parent and isDowned(character) then
				playNPCAnimation(character, "DownedIdle")
			end
		end)
	else
		playNPCAnimation(character, "DownedIdle")
	end
end

local function restoreReviver(state)
	local humanoid = getHumanoid(state.ReviverCharacter)
	if humanoid then
		humanoid.WalkSpeed = state.WalkSpeed
		humanoid.JumpPower = state.JumpPower
		humanoid.AutoRotate = state.AutoRotate
	end

	if state.ReviverCharacter and state.ReviverCharacter.Parent then
		state.ReviverCharacter:SetAttribute(REVIVING_ATTRIBUTE, false)
	end
end

local function cancelRevive(targetCharacter, reason)
	local state = ActiveRevives[targetCharacter]
	if not state then
		return
	end

	ActiveRevives[targetCharacter] = nil

	if state.Prompt and state.Prompt.Parent then
		state.Prompt.Enabled = true
	end

	restoreReviver(state)
	if state.TargetCharacter and state.TargetCharacter.Parent then
		state.TargetCharacter:SetAttribute(REVIVING_ATTRIBUTE, false)
	end

	stopClientAnimation(state.ReviverPlayer, "PlayerReviving")
	if state.TargetPlayer then
		stopClientAnimation(state.TargetPlayer, "RevivingPlayer")
	else
		stopNPCAnimation(state.TargetCharacter, "RevivingPlayer")
		playDownedNPCState(state.TargetCharacter)
	end

	if state.TargetPlayer then
		Remote:FireClient(state.TargetPlayer, "ReviveCancelled", reason)
	end
end

local function canStartRevive(player, prompt)
	if not player or not prompt or prompt.Name ~= REVIVE_PROMPT then
		return false
	end

	local reviverCharacter = player.Character
	local promptParent = prompt.Parent
	local targetCharacter = promptParent and promptParent.Parent

	if not reviverCharacter or not targetCharacter or not targetCharacter:IsA("Model") then
		return false
	end
	if reviverCharacter == targetCharacter then
		return false
	end
	if not isDowned(targetCharacter) or isDowned(reviverCharacter) then
		return false
	end
	if targetCharacter:GetAttribute(REVIVING_ATTRIBUTE) then
		return false
	end
	if reviverCharacter:GetAttribute(REVIVING_ATTRIBUTE) then
		return false
	end
	if getDistance(reviverCharacter, targetCharacter) > Settings.MaxActivationDistance + 1 then
		return false
	end

	local humanoid = getHumanoid(reviverCharacter)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	return true, reviverCharacter, targetCharacter
end

local function startRevive(player, prompt)
	local valid, reviverCharacter, targetCharacter = canStartRevive(player, prompt)
	if not valid or ActiveRevives[targetCharacter] then
		return
	end

	local reviverHumanoid = getHumanoid(reviverCharacter)
	if not reviverHumanoid then
		return
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	local state = {
		ReviverPlayer = player,
		ReviverCharacter = reviverCharacter,
		TargetPlayer = targetPlayer,
		TargetCharacter = targetCharacter,
		Prompt = prompt,
		WalkSpeed = reviverHumanoid.WalkSpeed,
		JumpPower = reviverHumanoid.JumpPower,
		AutoRotate = reviverHumanoid.AutoRotate,
	}

	ActiveRevives[targetCharacter] = state
	reviverCharacter:SetAttribute(REVIVING_ATTRIBUTE, true)
	targetCharacter:SetAttribute(REVIVING_ATTRIBUTE, true)

	reviverHumanoid.WalkSpeed = 0
	reviverHumanoid.JumpPower = 0
	reviverHumanoid.AutoRotate = false

	Remote:FireClient(player, "Begin", "PlayerReviving")

	if targetPlayer then
		Remote:FireClient(targetPlayer, "Begin", "RevivingPlayer")
	else
		playNPCAnimation(targetCharacter, "RevivingPlayer")
	end
end

local function completeRevive(player, prompt)
	if not player or not prompt or prompt.Name ~= REVIVE_PROMPT then
		return
	end

	local targetCharacter = prompt.Parent and prompt.Parent.Parent
	local state = targetCharacter and ActiveRevives[targetCharacter]
	if not state or state.ReviverPlayer ~= player then
		return
	end

	local reviverCharacter = player.Character
	if not reviverCharacter or reviverCharacter ~= state.ReviverCharacter then
		cancelRevive(targetCharacter, "ReviverChanged")
		return
	end
	if not isDowned(targetCharacter) or isDowned(reviverCharacter) then
		cancelRevive(targetCharacter, "InvalidState")
		return
	end
	if getDistance(reviverCharacter, targetCharacter) > Settings.MaxActivationDistance + 1 then
		cancelRevive(targetCharacter, "OutOfRange")
		return
	end

	local targetHumanoid = getHumanoid(targetCharacter)
	if not targetHumanoid then
		cancelRevive(targetCharacter, "MissingHumanoid")
		return
	end

	local revivedHealth = math.max(1, targetHumanoid.MaxHealth * Settings.RevivedHealthPercent)

	ActiveRevives[targetCharacter] = nil
	if prompt.Parent then
		prompt.Enabled = false
	end

	-- Mark the target as being revived before changing Health. This prevents
	-- the downed health listener from treating the health transition as damage.
	targetCharacter:SetAttribute(REVIVING_ATTRIBUTE, true)
	targetCharacter:SetAttribute(DOWNED_ATTRIBUTE, false)
	targetHumanoid.Health = revivedHealth
	targetCharacter:SetAttribute(REVIVING_ATTRIBUTE, false)

	restoreReviver(state)

	stopClientAnimation(player, "PlayerReviving")
	if state.TargetPlayer then
		stopClientAnimation(state.TargetPlayer, "RevivingPlayer")
		Remote:FireClient(state.TargetPlayer, "Complete")
	else
		stopNPCAnimation(targetCharacter, "RevivingPlayer")
		local track = playNPCAnimation(targetCharacter, "DownedSelfRevive")
		if track then
			track.Ended:Once(function()
				if targetCharacter.Parent then
					stopNPCAnimation(targetCharacter, "DownedSelfRevive")
				end
			end)
		end
	end

	if prompt.Parent then
		prompt:Destroy()
	end
	Prompts[targetCharacter] = nil
end

local function createPrompt(character)
	if Prompts[character] and Prompts[character].Parent then
		return Prompts[character]
	end

	local root = getCharacterRoot(character)
	if not root then
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = REVIVE_PROMPT
	prompt.ActionText = "Revive"
	prompt.ObjectText = isPlayerCharacter(character) and "Downed Player" or "Downed NPC"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = Settings.ReviveDuration
	prompt.MaxActivationDistance = Settings.MaxActivationDistance
	prompt.RequiresLineOfSight = Settings.RequiresLineOfSight
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = root

	Prompts[character] = prompt
	return prompt
end

local function removePrompt(character)
	local prompt = Prompts[character]
	if prompt then
		Prompts[character] = nil
		if prompt.Parent then
			prompt:Destroy()
		end
	end

	if ActiveRevives[character] then
		cancelRevive(character, "TargetNoLongerDowned")
	end
end

local function updateCharacter(character)
	if character:GetAttribute(DOWNED_ATTRIBUTE) then
		createPrompt(character)
		playDownedNPCState(character)
	else
		removePrompt(character)
		stopNPCAnimation(character, "PlayerDowned")
		stopNPCAnimation(character, "DownedIdle")
	end
end

local function setupCharacter(character)
	if CharacterConnections[character] then
		return
	end

	if not getHumanoid(character) then
		return
	end

	CharacterConnections[character] = true

	character:GetAttributeChangedSignal(DOWNED_ATTRIBUTE):Connect(function()
		updateCharacter(character)
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			removePrompt(character)
			CharacterConnections[character] = nil
			NPCTracks[character] = nil
		end
	end)

	updateCharacter(character)
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
	if prompt.Name ~= REVIVE_PROMPT then
		return
	end
	startRevive(player, prompt)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, player)
	if prompt.Name ~= REVIVE_PROMPT then
		return
	end

	local targetCharacter = prompt.Parent and prompt.Parent.Parent
	local state = targetCharacter and ActiveRevives[targetCharacter]
	if state and state.ReviverPlayer == player then
		cancelRevive(targetCharacter, "Cancelled")
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt.Name ~= REVIVE_PROMPT then
		return
	end
	completeRevive(player, prompt)
end)

local function setupPlayer(player)
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Humanoid") and descendant.Parent and descendant.Parent:IsA("Model") then
		setupCharacter(descendant.Parent)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Humanoid") and descendant.Parent and descendant.Parent:IsA("Model") then
		setupCharacter(descendant.Parent)
	end
end)
