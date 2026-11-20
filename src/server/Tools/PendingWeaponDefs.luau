--!strict
-- The weapons whose SERVER rules are built (ticket 8.5c-server) but which are not in WeaponDefs yet, because each also needs its
-- client model, handling and prediction (Codex). The numbers are the owner-approved ones in docs/STEP8_QUESTIONS.md ("Answers" and the
-- revised table); the new fields are described in Types.WeaponDef.
--
-- When a weapon's client side is finished, Codex moves its entry into WeaponDefs (replace the placeholder Spread, Recoil and AimZoom
-- with real handling) and deletes it from here. Until then a weapon here cannot be chosen anywhere (a Hardware item is offered only
-- once WeaponDefs.byId has it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))

type WeaponDef = Types.WeaponDef

local sounds: Types.WeaponSounds = {
	Fire = "rbxassetid://124763531446154",
	Reload = "rbxassetid://5652257395",
	Empty = "rbxassetid://114980515844355",
}
local noSpread: Types.WeaponSpread = { Hip = 0, Aim = 0, PerShot = 0, MaxExtra = 0, RecoverPerSecond = 1, MoveMult = 1 }
local noRecoil: Types.WeaponRecoil = { PitchPerShot = 0, YawPerShot = 0, RecoverRate = 1, ViewKick = 0 }
local headshot = GameConfig.Combat.HeadshotMult

local Pending: { [string]: WeaponDef } = {}

-- Lattice: burst rifle. Three rounds of 12 per pull with 0.35 s before the next burst, 24 loaded and 48 spare, 2.2 s reload, falloff
-- from 60 to 140 studs down to 70 percent. Tracker round: all three rounds of one burst landing on the same agent marks them for
-- Lattice alone for 3 s (TargetGlow to the shooter, never an NPC). SPEC-QUESTION: the rate inside a burst is not specified; 900 rpm.
Pending.LatticeBurstRifle = {
	Id = "LatticeBurstRifle",
	Name = "Burst Rifle",
	Agent = "Lattice",
	Automatic = false,
	Damage = 12,
	HeadshotMult = headshot,
	RPM = 900,
	MagSize = 24,
	ReserveAmmo = 48,
	ReloadSeconds = 2.2,
	Falloff = { StartStuds = 60, EndStuds = 140, MinMult = 0.7 },
	Quiet = false,
	Spread = noSpread,
	Recoil = noRecoil,
	AimZoom = 1,
	Sounds = sounds,
	Burst = { Count = 3, DelaySeconds = 0.35 },
	Tracker = { Seconds = 3 },
}

-- Lattice: taser. One dart for 30 damage out to 25 studs, 1 loaded and 10 spare, 2 s reload. A hit on a player slows them 60 percent
-- (speed x 0.4) for 1.5 s and stops their ability and gadgets for 3 s. NPCs take the damage only. SPEC-QUESTIONs: no head bonus, and
-- the dart is as loud as a normal shot (the answers give neither).
Pending.LatticeTaser = {
	Id = "LatticeTaser",
	Name = "Taser",
	Agent = "Lattice",
	Automatic = false,
	Damage = 30,
	HeadshotMult = 1,
	RPM = 60,
	MagSize = 1,
	ReserveAmmo = 10,
	ReloadSeconds = 2,
	MaxRange = 25,
	Quiet = false,
	Spread = noSpread,
	Recoil = noRecoil,
	AimZoom = 1,
	Sounds = sounds,
	Taser = { SlowMult = 0.4, SlowSeconds = 1.5, LockoutSeconds = 3 },
}

return Pending
