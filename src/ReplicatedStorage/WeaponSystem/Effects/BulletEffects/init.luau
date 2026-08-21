local BulletEffects = {}

local Effects = {}

function BulletEffects.Register(Name, Handler)
	assert(type(Name) == "string" and Name ~= "", "Bullet effect name must be a non-empty string")
	assert(type(Handler) == "function", "Bullet effect handler must be a function")

	Effects[Name] = Handler
end

function BulletEffects.Has(Name)
	return Effects[Name] ~= nil
end

function BulletEffects.Apply(Name, Context)
	if not Name or Name == "None" then
		return true
	end

	local Handler = Effects[Name]
	if not Handler then
		return false
	end

	return Handler(Context) ~= false
end

function BulletEffects.Get(Name)
	return Effects[Name]
end

function BulletEffects.GetRegistered()
	local Names = {}

	for Name in pairs(Effects) do
		table.insert(Names, Name)
	end

	table.sort(Names)
	return Names
end

local Incendiary = require(script:WaitForChild("IncendiaryEffect"))
BulletEffects.Register("Incendiary", Incendiary.Apply)

return BulletEffects