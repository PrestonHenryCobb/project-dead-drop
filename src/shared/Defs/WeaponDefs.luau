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
		PostMeleeFireDelay = 0.2, -- Ticket 8.9: initial SMG recovery, tuned per weapon rather than a global lockout
		Spread = { Hip = 3.2, Aim = 0.7, PerShot = 0.25, MaxExtra = 3, RecoverPerSecond = 8, MoveMult = 1.5 },
		Recoil = { PitchPerShot = 0.5, YawPerShot = 0.15, RecoverRate = 2.5, ViewKick = 0.06 },
		AimZoom = 0.88,
		Sounds = {
			Fire = "rbxassetid://124763531446154",
			Reload = "rbxassetid://5652257395",
			Empty = "rbxassetid://114980515844355",
		},
	},
	-- Ticket 8.5a: Guise keeps an ambush-damage advantage over Feint's misdirection pistol.
	{
		Id = "GuisePistol",
		Name = "Silenced Pistol",
		Agent = "Guise",
		Automatic = false,
		Damage = 22,
		HeadshotMult = GameConfig.Combat.HeadshotMult,
		RPM = 300,
		MagSize = 12,
		ReserveAmmo = 24,
		ReloadSeconds = 1.4,
		Falloff = { StartStuds = 50, EndStuds = 110, MinMult = 0.7 },
		Quiet = true,
		AmbushMult = 1.5,
		PostMeleeFireDelay = 0.3,
		Spread = { Hip = 2.6, Aim = 0.4, PerShot = 0.35, MaxExtra = 2, RecoverPerSecond = 7, MoveMult = 1.4 },
		Recoil = { PitchPerShot = 0.75, YawPerShot = 0.1, RecoverRate = 3.5, ViewKick = 0.05 },
		AimZoom = 0.9,
		Sounds = {
			Fire = "rbxassetid://124763531446154",
			Reload = "rbxassetid://5652257395",
			Empty = "rbxassetid://114980515844355",
		},
	},
	-- Ticket 8.5f: owner delegated balance on 2026-10-24. Lower damage/range pays for shorter, displaced sound.
	{
		Id = "FeintPistol",
		Name = "Silent Pistol",
		Agent = "Feint",
		Automatic = false,
		Damage = 20,
		HeadshotMult = GameConfig.Combat.HeadshotMult,
		RPM = 320,
		MagSize = 12,
		ReserveAmmo = 24,
		ReloadSeconds = 1.5,
		Falloff = { StartStuds = 35, EndStuds = 85, MinMult = 0.65 },
		Quiet = true,
		HearStuds = 12,
		SoundOffset = NumberRange.new(8, 15),
		PostMeleeFireDelay = 0.25,
		Spread = { Hip = 2.8, Aim = 0.5, PerShot = 0.3, MaxExtra = 2, RecoverPerSecond = 7.5, MoveMult = 1.4 },
		Recoil = { PitchPerShot = 0.65, YawPerShot = 0.12, RecoverRate = 3.5, ViewKick = 0.045 },
		AimZoom = 0.9,
		Sounds = {
			Fire = "rbxassetid://124763531446154",
			Reload = "rbxassetid://5652257395",
			Empty = "rbxassetid://114980515844355",
		},
	},
	-- Ticket 8.5d: folding carbine is a complete standard semi-auto path with no new server effect.
	{
		Id = "ReticleCarbine",
		Name = "Folding Carbine",
		Agent = "Reticle",
		Automatic = false,
		Damage = 22,
		HeadshotMult = GameConfig.Combat.HeadshotMult,
		RPM = 400,
		MagSize = 20,
		ReserveAmmo = 40,
		ReloadSeconds = 2.0,
		Falloff = nil, -- Reticle's weapons retain full damage at range (STEP8 answers)
		Quiet = false,
		PostMeleeFireDelay = 0.35,
		Spread = { Hip = 2.8, Aim = 0.3, PerShot = 0.4, MaxExtra = 2, RecoverPerSecond = 7, MoveMult = 1.4 },
		Recoil = { PitchPerShot = 0.85, YawPerShot = 0.1, RecoverRate = 3, ViewKick = 0.07 },
		AimZoom = 0.88,
		TracerColor = Color3.fromRGB(255, 230, 175),
		TracerWidth = 0.06,
		TracerLength = 9,
		TracerSpeed = 1800,
		FlashSize = Vector3.new(0.3, 0.3, 0.75),
		-- Existing verified library sounds; art/audio tuning can replace these without changing the firing path.
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
	-- Ticket 8.11: default look for non-Quiet weapons; individual definitions may override each field.
	ShotDefaults = {
		-- Ticket 8.5-client-rules: scope flare appearance; duration/range come from the server's glint contract.
		ScopeGlintPixels = 18,
		ScopeGlintColor = Color3.fromRGB(255, 245, 210),
		ScopeGlintBarFraction = 0.12,
		ScopeGlintCoreFraction = 0.25,
		TracerColor = Color3.fromRGB(255, 218, 140),
		TracerWidth = 0.07,
		TracerLength = 7,
		TracerSpeed = 1600,
		FlashColor = Color3.fromRGB(255, 193, 80),
		FlashSize = Vector3.new(0.28, 0.28, 0.65),
	},
}

function WeaponDefs.get(id: string): WeaponDef?
	return byId[id]
end

return DeepFreeze(WeaponDefs)
