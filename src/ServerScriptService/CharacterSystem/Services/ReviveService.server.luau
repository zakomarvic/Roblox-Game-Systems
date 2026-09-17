local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterSystem = ReplicatedStorage:WaitForChild("CharacterSystem")
local Modules = CharacterSystem:WaitForChild("Modules")
local Settings = require(Modules:WaitForChild("ReviveSettings"))
local Animations = require(Modules:WaitForChild("ReviveAnimations"))

local InteractionSystem = ServerScriptService:WaitForChild("InteractionSystem")
local InteractionService = require(InteractionSystem:WaitForChild("InteractionService"))

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
local NPCAnimateStates = {}
local NPCAnimationConnections = {}

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

local function setNPCAnimateEnabled(character, enabled)
	if isPlayerCharacter(character) then
		return
	end

	local animate = character:FindFirstChild("Animate")
	if not animate or (not animate:IsA("Script") and not animate:IsA("LocalScript")) then
		return
	end

	if NPCAnimateStates[character] == nil then
		NPCAnimateStates[character] = animate.Enabled
	end

	animate.Enabled = enabled
	if enabled then
		NPCAnimateStates[character] = nil
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

local function isOwnedNPCTrack(character, track)
	local tracks = NPCTracks[character]
	if not tracks then
		return false
	end
	for _, ownedTrack in pairs(tracks) do
		if ownedTrack == track then
			return true
		end
	end
	return false
end

local function stopNPCAnimation(character, animationName, fadeTime)
	local tracks = NPCTracks[character]
	local track = tracks and tracks[animationName]
	if track and track.IsPlaying then
		track:Stop(fadeTime == nil and 0 or fadeTime)
	end
end

local function stopAllNPCAnimations(character, except)
	local animator = getNPCAnimator(character)
	if not animator then
		return
	end

	local exceptTrack = NPCTracks[character] and NPCTracks[character][except]

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track ~= exceptTrack then
			track:Stop(0)
		end
	end
end

local function getNPCTrack(character, animationName)
	local data = Animations[animationName]
	local animator = getNPCAnimator(character)
	if not data or not animator then
		return nil
	end

	NPCTracks[character] = NPCTracks[character] or {}
	local tracks = NPCTracks[character]
	local track = tracks[animationName]
	if not track then
		local animation = Instance.new("Animation")
		animation.Name = animationName
		animation.AnimationId = "rbxassetid://" .. tostring(data.Id)
		track = animator:LoadAnimation(animation)
		track.Priority = Enum.AnimationPriority.Action4
		tracks[animationName] = track
		animation:Destroy()
	end

	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = data.Looped == true
	return track
end

local function playNPCAnimation(character, animationName, fadeTime)
	if isPlayerCharacter(character) then
		return nil
	end

	local data = Animations[animationName]
	local track = getNPCTrack(character, animationName)
	if not track then
		return nil
	end

	stopAllNPCAnimations(character, animationName)
	track.Looped = data.Looped == true
	track:Play(fadeTime == nil and 0.05 or fadeTime, 1, data.Speed or 1)
	track:AdjustSpeed(data.Speed or 1)
	return track
end

local function startNPCAnimationGuard(character)
	if NPCAnimationConnections[character] then
		NPCAnimationConnections[character]:Disconnect()
	end

	local animator = getNPCAnimator(character)
	if not animator then
		return
	end

	NPCAnimationConnections[character] = animator.AnimationPlayed:Connect(function(track)
		if not character:GetAttribute(DOWNED_ATTRIBUTE) and not character:GetAttribute(REVIVING_ATTRIBUTE) then
			return
		end
		if isOwnedNPCTrack(character, track) then
			return
		end
		track:Stop(0)
	end)
end

local function stopNPCAnimationGuard(character)
	local connection = NPCAnimationConnections[character]
	if connection then
		connection:Disconnect()
		NPCAnimationConnections[character] = nil
	end
end

local function maintainNPCIdle(character, idle)
	if not character.Parent then
		return
	end

	if not isDowned(character) or character:GetAttribute(REVIVING_ATTRIBUTE) then
		return
	end

	if not idle.IsPlaying then
		idle.Looped = true
		idle:Play(0.05, 1, Animations.DownedIdle.Speed or 1)
		idle:AdjustSpeed(Animations.DownedIdle.Speed or 1)
	end
end

local function beginNPCDownedAnimation(character)
	if isPlayerCharacter(character) or not isDowned(character) then
		return
	end

	local existingTracks = NPCTracks[character]
	if existingTracks then
		local transition = existingTracks.PlayerDowned
		local idle = existingTracks.DownedIdle

		if transition and transition.IsPlaying then
			return
		end

		if idle and idle.IsPlaying then
			return
		end
	end

	setNPCAnimateEnabled(character, false)
	startNPCAnimationGuard(character)
	stopAllNPCAnimations(character)

	local transition = getNPCTrack(character, "PlayerDowned")
	local idle = getNPCTrack(character, "DownedIdle")

	if not idle then
		warn("[ReviveService] Missing DownedIdle track for NPC:", character:GetFullName())
		return
	end

	idle.Looped = true

	if not transition then
		maintainNPCIdle(character, idle)
		return
	end

	transition.Looped = false
	transition:Play(0.05, 1, Animations.PlayerDowned.Speed or 1)
	transition:AdjustSpeed(Animations.PlayerDowned.Speed or 1)

	task.spawn(function()
		local finished = false

		local connection
		connection = transition.Ended:Connect(function()
			finished = true

			if connection then
				connection:Disconnect()
				connection = nil
			end
		end)

		while character.Parent
			and isDowned(character)
			and not character:GetAttribute(REVIVING_ATTRIBUTE)
			and not finished
			and transition.IsPlaying do

			RunService.Heartbeat:Wait()
		end

		if connection then
			connection:Disconnect()
		end

		if not character.Parent
			or not isDowned(character)
			or character:GetAttribute(REVIVING_ATTRIBUTE) then
			return
		end

		if transition.IsPlaying then
			transition:Stop(0)
		end

		idle.Looped = true
		idle:Play(0.05, 1, Animations.DownedIdle.Speed or 1)
		idle:AdjustSpeed(Animations.DownedIdle.Speed or 1)
	end)
end

local function stopNPCDownedAnimations(character)
	stopNPCAnimation(character, "PlayerDowned", 0)
	stopNPCAnimation(character, "DownedIdle", 0)
	stopNPCAnimation(character, "RevivingPlayer", 0)
	stopNPCAnimation(character, "DownedSelfRevive", 0)
end

local function restoreNPCAnimationController(character)
	if isPlayerCharacter(character) then
		return
	end

	stopNPCDownedAnimations(character)
	stopNPCAnimationGuard(character)
	setNPCAnimateEnabled(character, true)
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

local function finishCancelRevive(targetCharacter, reason)
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
		Remote:FireClient(state.TargetPlayer, "ReviveCancelled", reason)
	else
		stopNPCAnimation(state.TargetCharacter, "RevivingPlayer", 0)
		beginNPCDownedAnimation(state.TargetCharacter)
	end
end

local function cancelRevive(targetCharacter, reason)
	local interaction = InteractionService.GetActive(targetCharacter)
	if interaction and interaction.Name == "Revive" then
		InteractionService.Cancel(targetCharacter, reason)
		return
	end

	finishCancelRevive(targetCharacter, reason)
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
	if targetCharacter:GetAttribute(REVIVING_ATTRIBUTE) or reviverCharacter:GetAttribute(REVIVING_ATTRIBUTE) then
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

local function beginReviveInteraction(player, prompt, interactionState)
	local valid, reviverCharacter, targetCharacter = canStartRevive(player, prompt)
	if not valid then
		return false, "InvalidState"
	end

	local reviverHumanoid = getHumanoid(reviverCharacter)
	if not reviverHumanoid then
		return false, "MissingHumanoid"
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	local state = {
		ReviverPlayer = player,
		ReviverCharacter = reviverCharacter,
		TargetPlayer = targetPlayer,
		TargetCharacter = targetCharacter,
		Prompt = prompt,
		InteractionState = interactionState,
		WalkSpeed = reviverHumanoid.WalkSpeed,
		JumpPower = reviverHumanoid.JumpPower,
		AutoRotate = reviverHumanoid.AutoRotate,
		Completing = false,
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
		playNPCAnimation(targetCharacter, "RevivingPlayer", 0.05)
	end

	return true
end

local function startRevive(player, prompt)
	local promptParent = prompt and prompt.Parent
	local targetCharacter = promptParent and promptParent.Parent
	if not targetCharacter or not targetCharacter:IsA("Model") then
		return
	end

	InteractionService.Start(player, "Revive", targetCharacter, {
		Prompt = prompt,
	})
end

local function finishCompleteRevive(player, prompt)
	if not player or not prompt or prompt.Name ~= REVIVE_PROMPT then
		return false, "InvalidInteraction"
	end

	local targetCharacter = prompt.Parent and prompt.Parent.Parent
	local state = targetCharacter and ActiveRevives[targetCharacter]
	if not state or state.ReviverPlayer ~= player or state.Completing then
		return false, "NotActive"
	end
	state.Completing = true

	local reviverCharacter = player.Character
	if not reviverCharacter or reviverCharacter ~= state.ReviverCharacter then
		state.Completing = false
		cancelRevive(targetCharacter, "ReviverChanged")
		return false, "ReviverChanged"
	end
	if not isDowned(targetCharacter) or isDowned(reviverCharacter) then
		state.Completing = false
		cancelRevive(targetCharacter, "InvalidState")
		return false, "InvalidState"
	end
	if getDistance(reviverCharacter, targetCharacter) > Settings.MaxActivationDistance + 1 then
		state.Completing = false
		cancelRevive(targetCharacter, "OutOfRange")
		return false, "OutOfRange"
	end

	local targetHumanoid = getHumanoid(targetCharacter)
	if not targetHumanoid then
		state.Completing = false
		cancelRevive(targetCharacter, "MissingHumanoid")
		return false, "MissingHumanoid"
	end

	local revivedHealth = math.max(1, targetHumanoid.MaxHealth * Settings.RevivedHealthPercent)
	ActiveRevives[targetCharacter] = nil
	if prompt.Parent then
		prompt.Enabled = false
	end

	targetCharacter:SetAttribute(REVIVING_ATTRIBUTE, true)
	targetCharacter:SetAttribute(DOWNED_ATTRIBUTE, false)
	targetHumanoid.Health = revivedHealth

	if state.TargetPlayer then
		stopClientAnimation(state.TargetPlayer, "RevivingPlayer")
	else
		stopNPCDownedAnimations(targetCharacter)
	end

	targetCharacter:SetAttribute(REVIVING_ATTRIBUTE, false)
	restoreReviver(state)
	stopClientAnimation(player, "PlayerReviving")

	if state.TargetPlayer then
		Remote:FireClient(state.TargetPlayer, "Complete")
	else
		restoreNPCAnimationController(targetCharacter)
	end

	local head = targetCharacter:FindFirstChild("Head")
	if head then
		local indicator = head:FindFirstChild("DownedIndicator")
		if indicator then
			indicator:Destroy()
		end
	end

	if prompt.Parent then
		prompt:Destroy()
	end
	Prompts[targetCharacter] = nil

	return true
end

local function completeRevive(player, prompt)
	if not player or not prompt or prompt.Name ~= REVIVE_PROMPT then
		return
	end

	local targetCharacter = prompt.Parent and prompt.Parent.Parent
	if not targetCharacter then
		return
	end

	local interaction = InteractionService.GetActive(targetCharacter)
	if not interaction or interaction.Name ~= "Revive" or interaction.Player ~= player then
		return
	end

	InteractionService.Complete(targetCharacter, {
		Prompt = prompt,
	})
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
		if not character:GetAttribute(REVIVING_ATTRIBUTE) and not isPlayerCharacter(character) then
			beginNPCDownedAnimation(character)
		end
	else
		removePrompt(character)
		if not character:GetAttribute(REVIVING_ATTRIBUTE) then
			restoreNPCAnimationController(character)
		end
	end
end

local function setupCharacter(character)
	if CharacterConnections[character] or not getHumanoid(character) then
		return
	end

	CharacterConnections[character] = true

	character:GetAttributeChangedSignal(DOWNED_ATTRIBUTE):Connect(function()
		updateCharacter(character)
	end)

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			removePrompt(character)
			stopNPCAnimationGuard(character)
			CharacterConnections[character] = nil
			NPCTracks[character] = nil
			NPCAnimateStates[character] = nil
		end
	end)

	updateCharacter(character)
end

InteractionService.Register("Revive", {
	MaxDistance = Settings.MaxActivationDistance + 1,

	CanInteract = function(player, targetCharacter, context)
		local prompt = context and context.Prompt
		local valid, _, resolvedTarget = canStartRevive(player, prompt)
		if not valid or resolvedTarget ~= targetCharacter then
			return false, "InvalidRevive"
		end
		return true
	end,

	Start = function(interactionState)
		local context = interactionState.Context or {}
		local prompt = context.Prompt
		return beginReviveInteraction(interactionState.Player, prompt, interactionState)
	end,

	Cancel = function(interactionState, reason)
		finishCancelRevive(interactionState.Target, reason)
	end,

	Complete = function(interactionState, context)
		local prompt = context and context.Prompt
		return finishCompleteRevive(interactionState.Player, prompt)
	end,
})

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
	if prompt.Name == REVIVE_PROMPT then
		startRevive(player, prompt)
	end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, player)
	if prompt.Name ~= REVIVE_PROMPT then
		return
	end

	local targetCharacter = prompt.Parent and prompt.Parent.Parent
	local interaction = targetCharacter and InteractionService.GetActive(targetCharacter)
	if interaction and interaction.Name == "Revive" and interaction.Player == player then
		task.defer(function()
			local current = InteractionService.GetActive(targetCharacter)
			if current and current.Name == "Revive" and current.Player == player then
				cancelRevive(targetCharacter, "Cancelled")
			end
		end)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt.Name == REVIVE_PROMPT then
		completeRevive(player, prompt)
	end
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
