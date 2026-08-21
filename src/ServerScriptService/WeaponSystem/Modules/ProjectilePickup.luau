local MeleeUtility = require(script.Parent:WaitForChild("MeleeUtility"))

local ProjectilePickup = {}

function ProjectilePickup.Setup(Player, Tool, PickupTemplate, Projectile, Settings, DestroyProjectile)
	local Visual = Projectile and Projectile.Visual
	local PromptPart = Visual and MeleeUtility.GetPromptPart(Visual)
	if not PromptPart then return nil end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "ProjectilePickupPrompt"
	Prompt.ActionText = Settings.PickupActionText or "Pick Up"
	Prompt.ObjectText = Settings.PickupObjectText or (Tool and Tool.Name) or "Projectile"
	Prompt.HoldDuration = math.max(0, tonumber(Settings.PickupHoldDuration) or 0.15)
	Prompt.MaxActivationDistance = math.clamp(tonumber(Settings.PickupDistance) or 10, 1, 50)
	Prompt.RequiresLineOfSight = Settings.PickupRequiresLineOfSight == true
	Prompt.Enabled = true
	Prompt.Parent = PromptPart

	local State = {Claimed = false}

	local function GiveTool()
		local Parent = Player:FindFirstChildOfClass("Backpack") or Player.Character
		if not Parent then return false end
		if Tool and Tool.Parent then
			MeleeUtility.SetToolVisible(Tool, true)
			Tool.Parent = Parent
			return true
		end
		if PickupTemplate then
			PickupTemplate.Parent = Parent
			PickupTemplate = nil
			return true
		end
		return false
	end

	local function Cleanup()
		if Prompt.Parent then Prompt:Destroy() end
		if PickupTemplate and PickupTemplate.Parent then PickupTemplate:Destroy() end
	end

	Prompt.Triggered:Connect(function(Picker)
		if State.Claimed or Picker ~= Player then return end
		if not Player.Parent or not Picker.Character then return end
		local PickerTorso = MeleeUtility.GetTorso(Picker.Character)
		if not PickerTorso or not PromptPart:IsDescendantOf(workspace) then return end
		if (PickerTorso.Position - PromptPart.Position).Magnitude > Prompt.MaxActivationDistance + 2 then return end
		if not GiveTool() then return end
		State.Claimed = true
		Prompt.Enabled = false
		Cleanup()
		DestroyProjectile(Projectile)
	end)

	local Lifetime = math.max(0, tonumber(Settings.PickupLifetime or Settings.ThrowStickLifetime) or 30)
	if Lifetime > 0 then
		task.delay(Lifetime, function()
			if State.Claimed then return end
			State.Claimed = true
			Cleanup()
		end)
	end

	return State
end

return ProjectilePickup