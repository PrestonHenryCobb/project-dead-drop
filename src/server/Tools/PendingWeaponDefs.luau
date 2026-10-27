--!strict
-- The weapons whose SERVER rules are built (tickets 8.5a, 8.5b, 8.5e, 8.5f) but which are not in WeaponDefs yet, because
-- each also needs its client model, handling and prediction (Codex). The numbers are the owner-approved ones in
-- docs/STEP8_QUESTIONS.md ("Answers" and "Remaining weapon effects"); the new fields are described in Types.WeaponDef.
--
-- When a weapon's client side is finished, Codex moves its entry into WeaponDefs (replace the placeholder Spread,
-- Recoil and AimZoom with real handling) and deletes it from here. Until then a weapon here cannot be chosen anywhere.
--
-- To exercise one on the server in Studio (Server Command Bar, during a playtest with one player):
--     local Pending = require(game.ServerScriptService.Server.Tools.PendingWeaponDefs)
--     local Combat = require(game.ServerScriptService.Server.Services.CombatService)
--     Combat.testEquip(game.Players:GetPlayers()[1], Pending.ParapetPump)

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

-- Guise: V is a garrote. A tap swing deals 40 within 4 studs every 0.8 s; a rear takedown takes 0.8 s and deals 100.
-- Silent: a takedown never makes noise, so NPCs only react to what they see. No ammo, never fires.
Pending.GuiseGarrote = {
	Id = "GuiseGarrote",
	Name = "Garrote",
	Agent = "Guise",
	Automatic = false,
	Damage = 0,
	HeadshotMult = 1,
	RPM = 1,
	MagSize = 0,
	ReserveAmmo = 0,
	ReloadSeconds = 0,
	Quiet = true,
	Spread = noSpread,
	Recoil = noRecoil,
	AimZoom = 1,
	Sounds = sounds,
	Melee = { SwingDamage = 40, SwingSeconds = 0.8, SwingReach = 4, TakedownSeconds = 0.8, TakedownDamage = 100 },
}

-- Parapet: pump shotgun. 8 pellets of 11, 70 rpm, 6 loaded and 12 spare, loaded one shell (0.5 s) at a time. A full
-- health agent survives one pull whatever it hits; 5 of 8 pellets within 12 studs staggers (25% slow for 0.35 s).
Pending.ParapetPump = {
	Id = "ParapetPump",
	Name = "Pump Shotgun",
	Agent = "Parapet",
	Automatic = false,
	Damage = 11,
	HeadshotMult = headshot,
	RPM = 70,
	Pellets = 8,
	MagSize = 6,
	ReserveAmmo = 12,
	ReloadSeconds = 0.5,
	ReloadPerShell = true,
	Falloff = { StartStuds = 10, EndStuds = 30, MinMult = 0.3 },
	Quiet = false,
	SurvivesFullHealth = true,
	Stagger = { MinPellets = 5, WithinStuds = 12, SlowMult = 0.75, Seconds = 0.35, AimBumpDegrees = 1.5 },
	Spread = { Hip = 6, Aim = 4, PerShot = 0.7, MaxExtra = 2, RecoverPerSecond = 6, MoveMult = 1.3 },
	Recoil = noRecoil,
	AimZoom = 0.9,
	Sounds = sounds,
}

-- Parapet: breaching hammer. A swing deals 70 within 6 studs every 1.1 s; holding V for 1 s makes it 100 and shoves the
-- target 3 studs sideways (to the swinger's right). No ammo, never fires.
Pending.ParapetHammer = {
	Id = "ParapetHammer",
	Name = "Breaching Hammer",
	Agent = "Parapet",
	Automatic = false,
	Damage = 0,
	HeadshotMult = 1,
	RPM = 1,
	MagSize = 0,
	ReserveAmmo = 0,
	ReloadSeconds = 0,
	Quiet = false,
	Spread = noSpread,
	Recoil = noRecoil,
	AimZoom = 1,
	Sounds = sounds,
	Melee = {
		SwingDamage = 70,
		SwingSeconds = 1.1,
		SwingReach = 6,
		ChargeSeconds = 1,
		ChargeDamage = 100,
		ShoveStuds = 3,
	},
}

-- Suture: flare pistol. A slow arcing flare: 55 on a direct hit (no extra splash), 15 splash to others within 6 studs,
-- the landing area lit for 5 s, a struck character glowing for Suture's team for 4 s.
Pending.SutureFlare = {
	Id = "SutureFlare",
	Name = "Flare Pistol",
	Agent = "Suture",
	Automatic = false,
	Damage = 55,
	HeadshotMult = 1,
	RPM = 40,
	MagSize = 1,
	ReserveAmmo = 12,
	ReloadSeconds = 1.6,
	Quiet = false,
	Spread = noSpread,
	Recoil = noRecoil,
	AimZoom = 0.95,
	Sounds = sounds,
	Projectile = {
		Kind = "Flare",
		Speed = 70,
		Gravity = 45,
		MaxSeconds = 4,
		SplashDamage = 15,
		SplashRadius = 6,
		LightSeconds = 5,
		GlowSeconds = 4,
	},
}

-- Feint: smoke-burst SMG. 8 damage, 750 rpm, 32 loaded and 64 spare; each of the last 5 rounds of a magazine leaves a
-- 4-stud-wide (radius 2) smoke cloud for 2 s where it lands.
Pending.FeintSmokeSMG = {
	Id = "FeintSmokeSMG",
	Name = "Smoke-Burst SMG",
	Agent = "Feint",
	Automatic = true,
	Damage = 8,
	HeadshotMult = headshot,
	RPM = 750,
	MagSize = 32,
	ReserveAmmo = 64,
	ReloadSeconds = 2,
	Falloff = { StartStuds = 25, EndStuds = 60, MinMult = 0.55 },
	Quiet = false,
	Smoke = { Rounds = 5, Radius = 2, Seconds = 2 },
	Spread = { Hip = 3.4, Aim = 0.8, PerShot = 0.25, MaxExtra = 3, RecoverPerSecond = 8, MoveMult = 1.5 },
	Recoil = { PitchPerShot = 0.5, YawPerShot = 0.15, RecoverRate = 2.5, ViewKick = 0.06 },
	AimZoom = 0.9,
	Sounds = sounds,
}

-- Feint: throwing knives. 45 (90 on an Exposed head), one every 0.6 s, six carried and no reserve. Silent. Landed knives
-- stay until picked up; any agent holding knives can pick one up, an opponent's too.
Pending.FeintKnives = {
	Id = "FeintKnives",
	Name = "Throwing Knives",
	Agent = "Feint",
	Automatic = false,
	Damage = 45,
	HeadshotMult = 2,
	RPM = 100,
	MagSize = 6,
	ReserveAmmo = 0,
	ReloadSeconds = 0,
	Quiet = true,
	HearStuds = 0,
	Spread = noSpread,
	Recoil = noRecoil,
	AimZoom = 0.95,
	Sounds = sounds,
	Projectile = { Kind = "Knife", Speed = 120, Gravity = 25, MaxSeconds = 3, PickupStuds = 4 },
}

return Pending
