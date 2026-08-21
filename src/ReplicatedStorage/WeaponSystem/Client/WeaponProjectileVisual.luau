local WeaponProjectileVisual = {}

local Cache = setmetatable({}, {__mode = "k"})

local function getTarget(Tool, Name)
	if not Tool or not Name or Name == "" then
		return nil
	end

	return Tool:FindFirstChild(Name, true)
end

local function recordAndHide(Target)
	local Original = {}

	if Target:IsA("BasePart") then
		Original[Target] = Target.Transparency
	elseif Target:IsA("Decal") or Target:IsA("Texture") then
		Original[Target] = Target.Transparency
	end

	for _, Descendant in ipairs(Target:GetDescendants()) do
		if Descendant:IsA("BasePart") or Descendant:IsA("Decal") or Descendant:IsA("Texture") then
			Original[Descendant] = Descendant.Transparency
		end
	end

	for Instance, _ in pairs(Original) do
		Instance.Transparency = 1
	end

	return Original
end

local function restore(Original)
	if not Original then
		return
	end

	for Instance, Transparency in pairs(Original) do
		if Instance and Instance.Parent then
			Instance.Transparency = Transparency
		end
	end
end

function WeaponProjectileVisual.Hide(Tool, Module)
	if not Module or Module.HideProjectileOnFire ~= true then
		return
	end

	local Name = Module.WeaponProjectileName or Module.ProjectileName
	local Target = getTarget(Tool, Name)
	if not Target then
		return
	end

	if Cache[Tool] then
		return
	end

	Cache[Tool] = recordAndHide(Target)
end

function WeaponProjectileVisual.Restore(Tool, Module)
	local Original = Cache[Tool]
	if not Original then
		return
	end

	restore(Original)
	Cache[Tool] = nil
end

function WeaponProjectileVisual.Clear(Tool)
	Cache[Tool] = nil
end

return WeaponProjectileVisual