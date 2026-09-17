local WeaponStateService = {}

local ServerScriptService = game:GetService("ServerScriptService")
local CharacterSystem = ServerScriptService:WaitForChild("CharacterSystem")
local CharacterServices = CharacterSystem:WaitForChild("Services")
local CharacterStateService = require(CharacterServices:WaitForChild("CharacterStateService"))

WeaponStateService.States = {
	Unequipped = "Unequipped",
	Equipped = "Equipped",
	Aiming = "Aiming",
	Firing = "Firing",
	Reloading = "Reloading",
	Throwing = "Throwing",
	MeleeAttacking = "MeleeAttacking",
	Disabled = "Disabled",
}

local States = {}
local Connections = {}

local function getStateKey(Player, Tool)
	return Player.UserId .. ":" .. tostring(Tool)
end

local function getSettings(Tool)
	local Setting = Tool and Tool:FindFirstChild("Setting")
	if not Setting or not Setting:IsA("ModuleScript") then
		return nil
	end

	local Settings = require(Setting)
	if type(Settings) ~= "table" then
		return nil
	end

	return Settings
end

local function isOwned(Player, Tool)
	if not Player or not Tool or not Tool:IsA("Tool") then
		return false
	end

	local Character = Player.Character
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	return (Character and Tool:IsDescendantOf(Character))
		or (Backpack and Tool:IsDescendantOf(Backpack))
end

local function isEquipped(Player, Tool)
	return Player.Character and Tool and Tool.Parent == Player.Character
end

local function isCharacterDisabled(Player)
	local Character = Player and Player.Character
	if not Character then
		return true
	end

	local State = CharacterStateService.Get(Character)
	return State == CharacterStateService.States.Downed
		or State == CharacterStateService.States.BeingRevived
		or State == CharacterStateService.States.Dead
end

local function setStateInternal(State, NewState)
	State.Current = NewState
end

local function disconnectCharacter(Player, Tool)
	local Key = getStateKey(Player, Tool)
	local Connection = Connections[Key]
	if Connection then
		Connection:Disconnect()
		Connections[Key] = nil
	end
end

local function bindCharacterState(Player, Tool, State)
	local Character = Player.Character
	if not Character then
		return
	end

	local Key = getStateKey(Player, Tool)
	disconnectCharacter(Player, Tool)

	Connections[Key] = Character:GetAttributeChangedSignal("CharacterState"):Connect(function()
		if isCharacterDisabled(Player) then
			setStateInternal(State, WeaponStateService.States.Disabled)
		elseif State.Current == WeaponStateService.States.Disabled and isEquipped(Player, Tool) then
			setStateInternal(State, WeaponStateService.States.Equipped)
		end
	end)
end

function WeaponStateService.Get(Player, Tool)
	if not isOwned(Player, Tool) then
		return nil
	end

	local Settings = getSettings(Tool)
	if not Settings then
		return nil
	end

	local Key = getStateKey(Player, Tool)
	local State = States[Key]

	if not State then
		State = {
			Current = WeaponStateService.States.Unequipped,
			Ammo = Settings.AmmoPerClip,
			Clips = Settings.LimitedClipEnabled and Settings.Clips or 0,
			Reloading = false,
			LastShot = 0,
		}
		States[Key] = State
		bindCharacterState(Player, Tool, State)
	end

	if isCharacterDisabled(Player) then
		setStateInternal(State, WeaponStateService.States.Disabled)
	elseif State.Current == WeaponStateService.States.Disabled then
		setStateInternal(State, isEquipped(Player, Tool) and WeaponStateService.States.Equipped or WeaponStateService.States.Unequipped)
	elseif not isEquipped(Player, Tool) and State.Current ~= WeaponStateService.States.Reloading then
		setStateInternal(State, WeaponStateService.States.Unequipped)
	elseif isEquipped(Player, Tool) and State.Current == WeaponStateService.States.Unequipped then
		setStateInternal(State, WeaponStateService.States.Equipped)
	end

	return State, Settings
end

function WeaponStateService.GetState(Player, Tool)
	local State = WeaponStateService.Get(Player, Tool)
	return State and State.Current or nil
end

function WeaponStateService.Set(Player, Tool, NewState)
	local State = WeaponStateService.Get(Player, Tool)
	if not State or type(NewState) ~= "string" then
		return false
	end

	for _, Value in pairs(WeaponStateService.States) do
		if Value == NewState then
			setStateInternal(State, NewState)
			return true
		end
	end

	return false
end

function WeaponStateService.Is(Player, Tool, StateName)
	return WeaponStateService.GetState(Player, Tool) == StateName
end

function WeaponStateService.TryFire(Player, Tool)
	local State, Settings = WeaponStateService.Get(Player, Tool)
	if not State or not isEquipped(Player, Tool) then
		return false, State, Settings
	end
	if State.Current == WeaponStateService.States.Disabled
		or State.Current == WeaponStateService.States.Reloading
		or State.Current == WeaponStateService.States.Throwing
		or State.Current == WeaponStateService.States.MeleeAttacking then
		return false, State, Settings
	end
	if State.Ammo ~= math.huge and State.Ammo <= 0 then
		return false, State, Settings
	end

	local FireRate = math.max(tonumber(Settings.FireRate) or 0, 0.03)
	local Now = os.clock()
	if Now - State.LastShot < FireRate then
		return false, State, Settings
	end

	State.LastShot = Now
	if State.Ammo ~= math.huge then
		State.Ammo -= 1
	end
	State.Current = WeaponStateService.States.Firing
	return true, State, Settings
end

function WeaponStateService.StopFiring(Player, Tool)
	local State = WeaponStateService.Get(Player, Tool)
	if not State then return false end
	if State.Current == WeaponStateService.States.Firing then
		State.Current = WeaponStateService.States.Equipped
	end
	return true
end

function WeaponStateService.TryReload(Player, Tool)
	local State, Settings = WeaponStateService.Get(Player, Tool)
	if not State or not isEquipped(Player, Tool) then
		return false, State, Settings
	end
	if State.Current == WeaponStateService.States.Disabled
		or State.Current == WeaponStateService.States.Firing
		or State.Current == WeaponStateService.States.Reloading
		or State.Current == WeaponStateService.States.Throwing
		or State.Current == WeaponStateService.States.MeleeAttacking then
		return false, State, Settings
	end
	if State.Ammo >= Settings.AmmoPerClip then
		return false, State, Settings
	end
	if Settings.LimitedClipEnabled and State.Clips <= 0 then
		return false, State, Settings
	end

	State.Reloading = true
	State.Current = WeaponStateService.States.Reloading

	task.delay(tonumber(Settings.ReloadTime) or 0, function()
		local CurrentState = States[getStateKey(Player, Tool)]
		if CurrentState ~= State then
			return
		end

		if not Tool.Parent or isCharacterDisabled(Player) then
			State.Reloading = false
			State.Current = isCharacterDisabled(Player) and WeaponStateService.States.Disabled or WeaponStateService.States.Unequipped
			return
		end

		local Needed = Settings.AmmoPerClip - State.Ammo
		if Settings.LimitedClipEnabled then
			Needed = math.min(Needed, State.Clips)
			State.Clips -= Needed
		end

		State.Ammo += Needed
		State.Reloading = false
		State.Current = isEquipped(Player, Tool) and WeaponStateService.States.Equipped or WeaponStateService.States.Unequipped
	end)

	return true, State, Settings
end

function WeaponStateService.TryThrow(Player, Tool)
	local State, Settings = WeaponStateService.Get(Player, Tool)
	if not State or not isEquipped(Player, Tool) then
		return false, State, Settings
	end
	if State.Current == WeaponStateService.States.Disabled
		or State.Current == WeaponStateService.States.Reloading
		or State.Current == WeaponStateService.States.Firing
		or State.Current == WeaponStateService.States.MeleeAttacking then
		return false, State, Settings
	end

	State.Current = WeaponStateService.States.Throwing
	return true, State, Settings
end

function WeaponStateService.TryMeleeAttack(Player, Tool)
	local State, Settings = WeaponStateService.Get(Player, Tool)
	if not State or not isEquipped(Player, Tool) then
		return false, State, Settings
	end
	if State.Current == WeaponStateService.States.Disabled
		or State.Current == WeaponStateService.States.Reloading
		or State.Current == WeaponStateService.States.Firing
		or State.Current == WeaponStateService.States.Throwing
		or State.Current == WeaponStateService.States.MeleeAttacking then
		return false, State, Settings
	end

	State.Current = WeaponStateService.States.MeleeAttacking
	return true, State, Settings
end

function WeaponStateService.StopAction(Player, Tool)
	local State = WeaponStateService.Get(Player, Tool)
	if not State then return false end
	if State.Current == WeaponStateService.States.Firing
		or State.Current == WeaponStateService.States.Throwing
		or State.Current == WeaponStateService.States.MeleeAttacking then
		State.Current = WeaponStateService.States.Equipped
	end
	return true
end

function WeaponStateService.Disable(Player, Tool)
	local State = WeaponStateService.Get(Player, Tool)
	if not State then return false end
	State.Current = WeaponStateService.States.Disabled
	State.Reloading = false
	return true
end

function WeaponStateService.Enable(Player, Tool)
	local State = WeaponStateService.Get(Player, Tool)
	if not State then return false end
	State.Reloading = false
	State.Current = isEquipped(Player, Tool) and WeaponStateService.States.Equipped or WeaponStateService.States.Unequipped
	return true
end

function WeaponStateService.ClearPlayer(Player)
	local Prefix = Player.UserId .. ":"
	for Key in pairs(States) do
		if string.sub(Key, 1, #Prefix) == Prefix then
			States[Key] = nil
			disconnectCharacter(Player, Key)
		end
	end
end

return WeaponStateService
