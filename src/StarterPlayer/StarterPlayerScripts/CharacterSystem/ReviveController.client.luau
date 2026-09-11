local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local CharacterSystem = ReplicatedStorage:WaitForChild("CharacterSystem")
local Modules = CharacterSystem:WaitForChild("Modules")
local Animations = require(Modules:WaitForChild("ReviveAnimations"))
local Remote = CharacterSystem:WaitForChild("ReviveRemote")

local TRANSITION_LEAD_TIME = 0.08
local TRANSITION_FADE_TIME = 0.04
local LOOP_RESET_LEAD_TIME = 0.04

local Character
local Humanoid
local Animator
local Tracks = {}
local DownedConnection
local AnimationPlayedConnection
local RecoveryPlaying = false

local function isOwnedTrack(track)
	for _, ownedTrack in pairs(Tracks) do
		if ownedTrack == track then
			return true
		end
	end
	return false
end

local function stopTrack(name, fadeTime)
	local track = Tracks[name]
	if track and track.IsPlaying then
		track:Stop(fadeTime == nil and 0 or fadeTime)
	end
end

local function stopAllReviveTracks(except)
	for name, track in pairs(Tracks) do
		if name ~= except and track.IsPlaying then
			track:Stop(0)
		end
	end
end

local function stopConflictingTracks(except)
	if not Animator then
		return
	end

	for _, track in ipairs(Animator:GetPlayingAnimationTracks()) do
		if track ~= except and not isOwnedTrack(track) then
			track:Stop(0)
		end
	end
end

local function loadTracks(character)
	Character = character
	Humanoid = character:WaitForChild("Humanoid")
	Animator = Humanoid:WaitForChild("Animator")
	Tracks = {}
	RecoveryPlaying = false

	for name, data in pairs(Animations) do
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = "rbxassetid://" .. tostring(data.Id)

		local track = Animator:LoadAnimation(animation)
		track.Looped = data.Looped == true
		track.Priority = Enum.AnimationPriority.Action4
		Tracks[name] = track

		animation:Destroy()
	end

	if AnimationPlayedConnection then
		AnimationPlayedConnection:Disconnect()
	end

	AnimationPlayedConnection = Animator.AnimationPlayed:Connect(function(track)
		if not Character then
			return
		end
		if not Character:GetAttribute("Downed") and not Character:GetAttribute("Reviving") and not RecoveryPlaying then
			return
		end
		if isOwnedTrack(track) then
			return
		end
		track:Stop(0)
	end)
end

local function playTrack(name, fadeTime)
	local data = Animations[name]
	local track = Tracks[name]
	if not data or not track then
		warn("[ReviveClient] Missing animation track:", name)
		return nil
	end

	stopAllReviveTracks(name)
	stopConflictingTracks(track)

	track.Looped = data.Looped == true
	track.Priority = Enum.AnimationPriority.Action4
	track:Play(fadeTime == nil and 0.05 or fadeTime, 1, data.Speed or 1)
	track:AdjustSpeed(data.Speed or 1)
	return track
end

local function maintainDownedIdle()
	task.spawn(function()
		while Character and Character.Parent and Character:GetAttribute("Downed") == true and not RecoveryPlaying do
			local idle = Tracks.DownedIdle
			if idle then
				idle.Looped = true
				if not idle.IsPlaying then
					playTrack("DownedIdle", 0)
				elseif idle.Length > 0 and idle.TimePosition >= math.max(0, idle.Length - LOOP_RESET_LEAD_TIME) then
					-- Prevent an uploaded loop clip from exposing a standing final
					-- keyframe before the next loop begins.
					idle.TimePosition = 0
				end
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

local function playDownedState()
	if RecoveryPlaying then
		return
	end
	if not Character or Character:GetAttribute("Downed") ~= true then
		return
	end

	local downedTrack = Tracks.PlayerDowned
	local idleTrack = Tracks.DownedIdle
	if not downedTrack or not idleTrack then
		playTrack("DownedIdle", 0)
		maintainDownedIdle()
		return
	end

	stopAllReviveTracks()
	stopConflictingTracks(downedTrack)

	downedTrack.Looped = false
	downedTrack.Priority = Enum.AnimationPriority.Action4
	downedTrack:Play(0, 1, Animations.PlayerDowned.Speed or 1)
	downedTrack:AdjustSpeed(Animations.PlayerDowned.Speed or 1)

	task.spawn(function()
		local length = downedTrack.Length
		local waited = 0
		while length <= 0 and downedTrack.IsPlaying and waited < 2 do
			waited += task.wait()
			length = downedTrack.Length
		end

		if not Character or not Character.Parent or Character:GetAttribute("Downed") ~= true or RecoveryPlaying then
			return
		end

		local switchTime = math.max(0, length - TRANSITION_LEAD_TIME)
		if switchTime > 0 then
			task.wait(switchTime)
		end

		if not Character or not Character.Parent or Character:GetAttribute("Downed") ~= true or RecoveryPlaying then
			return
		end

		idleTrack.Looped = true
		idleTrack.Priority = Enum.AnimationPriority.Action4
		idleTrack:Play(TRANSITION_FADE_TIME, 1, Animations.DownedIdle.Speed or 1)
		idleTrack:AdjustSpeed(Animations.DownedIdle.Speed or 1)
		if downedTrack.IsPlaying then
			downedTrack:Stop(TRANSITION_FADE_TIME)
		end

		maintainDownedIdle()
	end)
end

local function playRecoveryAnimation()
	RecoveryPlaying = true
	stopAllReviveTracks()

	local track = Tracks.DownedSelfRevive
	if not track then
		RecoveryPlaying = false
		return
	end

	stopConflictingTracks(track)
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action4
	track:Play(0.05, 1, Animations.DownedSelfRevive.Speed or 1)
	track:AdjustSpeed(Animations.DownedSelfRevive.Speed or 1)

	track.Ended:Once(function()
		if Character and Character.Parent then
			stopTrack("DownedSelfRevive", 0)
		end
		RecoveryPlaying = false
	end)
end

local function onCharacter(character)
	if DownedConnection then
		DownedConnection:Disconnect()
		DownedConnection = nil
	end
	if AnimationPlayedConnection then
		AnimationPlayedConnection:Disconnect()
		AnimationPlayedConnection = nil
	end

	loadTracks(character)

	DownedConnection = character:GetAttributeChangedSignal("Downed"):Connect(function()
		if character:GetAttribute("Downed") then
			RecoveryPlaying = false
			playDownedState()
		else
			if RecoveryPlaying then
				return
			end
			stopTrack("PlayerDowned", 0)
			stopTrack("DownedIdle", 0)
			stopTrack("RevivingPlayer", 0)
		end
	end)

	if character:GetAttribute("Downed") then
		playDownedState()
	end
end

Remote.OnClientEvent:Connect(function(action, animationName)
	if action == "Downed" then
		playDownedState()

	elseif action == "Begin" then
		playTrack(animationName, 0.05)

	elseif action == "Stop" then
		stopTrack(animationName, 0)
		if Character and Character:GetAttribute("Downed") == true and not RecoveryPlaying then
			playTrack("DownedIdle", 0)
			maintainDownedIdle()
		end

	elseif action == "Complete" then
		playRecoveryAnimation()

	elseif action == "ReviveCancelled" then
		RecoveryPlaying = false
		if Character and Character:GetAttribute("Downed") == true then
			playTrack("DownedIdle", 0)
			maintainDownedIdle()
		end
	end
end)

if LocalPlayer.Character then
	onCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(onCharacter)