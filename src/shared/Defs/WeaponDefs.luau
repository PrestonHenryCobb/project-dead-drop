--!strict
-- Every weapon an agent can carry (spec 13.2, decided in docs/STEP8_QUESTIONS.md). A player takes one of their agent's
-- three; each weapon here is the full record of how it fires, how it kicks and what it sounds like. Damage and rate are
-- tuned for about 1.2 seconds of sustained fire to down an agent with one armour plate (125 HP).
--
-- Sounds are Roblox library audio chosen for each weapon; swap the ids here to change them.
--
--   WeaponDefs.byId["GuiseSMG"] -> WeaponDef
--   WeaponDefs.get(id) -> WeaponDef?

local Shared = script.Parent.Parent
local DeepFreeze = require(Shared.Util.DeepFreeze)
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)

type WeaponDef = Types.WeaponDef

local defs: { WeaponDef } = {
	{
		Id = "GuiseSMG",
		Name = "Suppressed SMG",
		Agent = "Guise",
		Automatic = true,
		Damage = 8,
		HeadshotMult = GameConfig.Combat.HeadshotMult,
		RPM = 800,
		MagSize = 30,
		ReserveAmmo = 60, -- three magazines in all: the loaded one and two spare
		ReloadSeconds = 1.9,
		Falloff = { StartStuds = 30, EndStuds = 70, MinMult = 0.6 },
		Quiet = true,
		Spread = { Hip = 3.2, Aim = 0.7, PerShot = 0.25, MaxExtra = 3, RecoverPerSecond = 8, MoveMult = 1.5 },
		Recoil = { PitchPerShot = 0.5, YawPerShot = 0.15, RecoverRate = 2.5, ViewKick = 0.06 },
		AimZoom = 0.88,
		Sounds = {
			Fire = "rbxassetid://124763531446154",
			Reload = "rbxassetid://5652257395",
			Empty = "rbxassetid://114980515844355",
		},
	},
}

local byId: { [string]: WeaponDef } = {}
for _, def in defs do
	assert(not byId[def.Id], `Duplicate weapon {def.Id}`)
	assert(def.ReserveAmmo >= 0 and def.MagSize > 0 and def.RPM > 0, `Weapon {def.Id} has impossible ammo or rate`)
	byId[def.Id] = def
end

local WeaponDefs = {
	byId = byId,
}

function WeaponDefs.get(id: string): WeaponDef?
	return byId[id]
end

return DeepFreeze(WeaponDefs)
