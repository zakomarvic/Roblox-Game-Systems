local AnimationController = {}
AnimationController.__index = AnimationController

-- Central character animation coordinator.
-- Systems request animation playback through this controller instead of
-- directly creating/loading/playing AnimationTracks.

local Controllers = setmetatable({}, {__mode = "k"})

local function getAnimator(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
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

function AnimationController.new(character)
	local existing = Controllers[character]
	if existing then
		return existing
	end

	local self = setmetatable({}, AnimationController)
	self.Character = character
	self.Animator = getAnimator(character)
	self.Tracks = {}
	self.InterruptedTracks = {}
	self.Connections = {}
	Controllers[character] = self
	return self
end

-- Explicitly named accessor so it cannot be confused with the instance Get()
-- method below. Both character-state and weapon systems share this singleton.
function AnimationController.GetController(character)
	if not character then
		return nil
	end
	return Controllers[character] or AnimationController.new(character)
end

function AnimationController:SetCharacter(character)
	if self.Character == character then
		self.Animator = getAnimator(character)
		return
	end

	if self.Character and Controllers[self.Character] == self then
		Controllers[self.Character] = nil
	end

	self:Destroy()
	self.Character = character
	self.Animator = getAnimator(character)
	self.Tracks = {}
	self.InterruptedTracks = {}
	self.Connections = {}
	Controllers[character] = self
end

function AnimationController:Load(name, animationId, priority, looped)
	if not self.Animator or animationId == nil then
		return nil
	end

	local existing = self.Tracks[name]
	if existing then
		return existing
	end

	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = "rbxassetid://" .. tostring(animationId)

	local track = self.Animator:LoadAnimation(animation)
	track.Priority = priority or Enum.AnimationPriority.Action4
	track.Looped = looped == true
	self.Tracks[name] = track

	animation:Destroy()
	return track
end

function AnimationController:Get(name)
	return self.Tracks[name]
end

function AnimationController:Play(name, speed, fadeTime, weight)
	local track = self.Tracks[name]
	if not track then
		return nil
	end

	if track.IsPlaying then
		track:Stop(fadeTime or 0)
	end

	track:Play(fadeTime or 0.05, weight or 1, speed or 1)
	track:AdjustSpeed(speed or 1)
	return track
end

function AnimationController:Stop(name, fadeTime)
	local track = self.Tracks[name]
	if track and track.IsPlaying then
		track:Stop(fadeTime or 0)
	end
end

function AnimationController:StopAll(fadeTime, exceptName)
	for name, track in pairs(self.Tracks) do
		if name ~= exceptName and track.IsPlaying then
			track:Stop(fadeTime or 0)
		end
	end
end

function AnimationController:InterruptOtherTracks(exceptTrack)
	if not self.Animator then
		return
	end

	table.clear(self.InterruptedTracks)

	for _, track in ipairs(self.Animator:GetPlayingAnimationTracks()) do
		if track ~= exceptTrack and not self.TracksContainTrack(self, track) then
			table.insert(self.InterruptedTracks, {
				Track = track,
				TimePosition = track.TimePosition,
				Speed = track.Speed,
				Weight = track.WeightCurrent,
			})
			track:Stop(0)
		end
	end
end

function AnimationController.TracksContainTrack(self, track)
	for _, ownedTrack in pairs(self.Tracks) do
		if ownedTrack == track then
			return true
		end
	end
	return false
end

function AnimationController:RestoreInterruptedTracks()
	for _, state in ipairs(self.InterruptedTracks) do
		local track = state.Track
		if track and not track.IsPlaying then
			track:Play(0, state.Weight or 1, state.Speed or 1)
			if track.Length > 0 then
				track.TimePosition = math.clamp(state.TimePosition or 0, 0, track.Length)
			end
		end
	end

	table.clear(self.InterruptedTracks)
end

function AnimationController:Unload(name)
	local track = self.Tracks[name]
	if not track then
		return
	end
	if track.IsPlaying then
		track:Stop(0)
	end
	self.Tracks[name] = nil
end

function AnimationController:Destroy()
	if self.Character and Controllers[self.Character] == self then
		Controllers[self.Character] = nil
	end

	for _, connection in ipairs(self.Connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	for _, track in pairs(self.Tracks) do
		if track then
			track:Stop(0)
		end
	end

	table.clear(self.Connections)
	table.clear(self.Tracks)
	table.clear(self.InterruptedTracks)
	self.Animator = nil
	self.Character = nil
end

return AnimationController
