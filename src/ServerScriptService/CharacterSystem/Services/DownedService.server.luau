-- DownedService is the server bootstrap for the shared downed damage module.
-- Weapon systems call DownedDamageService.ApplyDamage directly with their
-- weapon's Overkill setting instead of communicating through character attributes.
require(script.Parent:WaitForChild("DownedDamageService"))
