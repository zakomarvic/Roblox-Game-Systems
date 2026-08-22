-- Compatibility entry point for legacy server service dependencies.
-- The canonical ragdoll implementation lives in CharacterSystem.Ragdoll.
local CharacterSystem = script.Parent.Parent
return require(CharacterSystem:WaitForChild("Ragdoll"):WaitForChild("CharacterRagdoll"))
