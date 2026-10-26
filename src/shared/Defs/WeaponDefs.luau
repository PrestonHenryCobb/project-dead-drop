--!strict
-- Every weapon an agent can carry (spec 13.2, decided in docs/STEP8_QUESTIONS.md). A player takes one of their agent's
-- three; each weapon here is the full record of how it fires, how it kicks and what it sounds like. Damage and rate are
-- tuned for about 1.2 seconds of sustained fire to down an agent with one armour plate (125 HP).
--
-- Sounds are Roblox library audio chosen for each weapon; swap the ids here to change them.
--
--   WeaponDefs.byId["GuiseSMG"] -> WeaponDef
--   WeaponDefs.get(id) -> WeaponDef?
--   WeaponDefs.getForAgent("Guise") -> { AgentHardware } in slot order W1, W2, W3 (Def is nil until a weapon is built)
--   WeaponDefs.isValidForAgent("Guise", "GuiseSMG") -> true: the weapon is this agent's and is built

local Shared = script.Parent.Parent
local AgentDefs = require(Shared.Defs.AgentDefs)
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

-- Ticket 8.5: these firearms use completed server firing-path rules. Weapons needing missing melee/projectile/status
-- effects are deliberately not registered. The default loadout remains GuiseSMG.
local function addFirearm(def: WeaponDef)
	table.insert(defs, def)
end

local librarySounds: Types.WeaponSounds = {
	Fire = "rbxassetid://124763531446154",
	Reload = "rbxassetid://5652257395",
	Empty = "rbxassetid://114980515844355",
}

addFirearm({
	Id = "ParapetHeavySMG",
	Name = "Heavy SMG",
	Agent = "Parapet",
	Automatic = true,
	Damage = 10,
	HeadshotMult = GameConfig.Combat.HeadshotMult,
	RPM = 750,
	MagSize = 40,
	ReserveAmmo = 80,
	ReloadSeconds = 2.6,
	Falloff = { StartStuds = 20, EndStuds = 45, MinMult = 0.55 },
	Quiet = false,
	SpinUp = { StartRPM = 500, Seconds = 1 },
	PostMeleeFireDelay = 0.25,
	Spread = { Hip = 3.6, Aim = 0.9, PerShot = 0.3, MaxExtra = 3.5, RecoverPerSecond = 7, MoveMult = 1.5 },
	Recoil = { PitchPerShot = 0.8, YawPerShot = 0.2, RecoverRate = 2.5, ViewKick = 0.08 },
	AimZoom = 0.88,
	Sounds = librarySounds,
})
addFirearm({
	Id = "ReticlePistol",
	Name = "Marksman Pistol",
	Agent = "Reticle",
	Automatic = false,
	Damage = 40,
	HeadshotMult = GameConfig.Combat.MarksmanHeadshotMult,
	RPM = 150,
	MagSize = 7,
	ReserveAmmo = 14,
	ReloadSeconds = 1.8,
	Falloff = nil,
	Quiet = false,
	Pierce = { Count = 1, DamageMult = 0.6 },
	PostMeleeFireDelay = 0.65,
	Spread = { Hip = 3, Aim = 0.2, PerShot = 0.65, MaxExtra = 2.5, RecoverPerSecond = 6, MoveMult = 1.5 },
	Recoil = { PitchPerShot = 1.6, YawPerShot = 0.12, RecoverRate = 3, ViewKick = 0.1 },
	AimZoom = 0.85,
	Sounds = librarySounds,
})
-- Ticket 8.5d-dmr: approved revised stats; existing server cadence/glint paths handle this firearm.
addFirearm({
	Id = "ReticleDMR",
	Name = "Bolt-action DMR",
	Agent = "Reticle",
	Automatic = false,
	Damage = 68,
	HeadshotMult = GameConfig.Combat.MarksmanHeadshotMult,
	RPM = 45,
	MagSize = 5,
	ReserveAmmo = 10,
	ReloadSeconds = 2.8,
	Falloff = nil,
	Quiet = false,
	ScopeGlint = true,
	-- SPEC-QUESTION: initial handling/recovery tuning, to review with the strong slow-fire kit.
	PostMeleeFireDelay = 0.8,
	Spread = { Hip = 4, Aim = 0.05, PerShot = 0.85, MaxExtra = 2.5, RecoverPerSecond = 4, MoveMult = 1.7 },
	Recoil = { PitchPerShot = 2, YawPerShot = 0.15, RecoverRate = 2.3, ViewKick = 0.11 },
	AimZoom = 1 / 3, -- legacy FOV multiplier; the optical visual below gives exact 3x magnification
	Sounds = librarySounds,
})
addFirearm({
	Id = "SutureShotgun",
	Name = "Medic Shotgun",
	Agent = "Suture",
	Automatic = false,
	Damage = 10,
	HeadshotMult = GameConfig.Combat.HeadshotMult,
	RPM = 90,
	Pellets = 6,
	MagSize = 8,
	ReserveAmmo = 16,
	ReloadSeconds = 2.6,
	Falloff = { StartStuds = 8, EndStuds = 25, MinMult = 0.3 },
	Quiet = false,
	PostMeleeFireDelay = 0.65,
	Spread = { Hip = 6, Aim = 4, PerShot = 0.7, MaxExtra = 2, RecoverPerSecond = 6, MoveMult = 1.3 },
	Recoil = { PitchPerShot = 2.2, YawPerShot = 0.2, RecoverRate = 3, ViewKick = 0.14 },
	AimZoom = 0.9,
	FlashSize = Vector3.new(0.45, 0.45, 0.9),
	Sounds = librarySounds,
})
addFirearm({
	Id = "SutureDualPistols",
	Name = "Dual Machine Pistols",
	Agent = "Suture",
	Automatic = true,
	Damage = 6,
	HeadshotMult = GameConfig.Combat.HeadshotMult,
	RPM = 1100,
	AimedRPM = 550,
	MagSize = 40,
	ReserveAmmo = 80,
	ReloadSeconds = 2.4,
	Falloff = { StartStuds = 20, EndStuds = 45, MinMult = 0.5 },
	Quiet = false,
	PostMeleeFireDelay = 0.15,
	Spread = { Hip = 6, Aim = 0.65, PerShot = 0.3, MaxExtra = 3, RecoverPerSecond = 8, MoveMult = 1.5 },
	Recoil = { PitchPerShot = 0.4, YawPerShot = 0.2, RecoverRate = 3.5, ViewKick = 0.045 },
	AimZoom = 0.9,
	Sounds = librarySounds,
})

-- Ticket 8.5c-pdw: revised approved stats; no projectile/status rule is needed for this firearm.
addFirearm({
	Id = "LatticePDW",
	Name = "Compact PDW",
	Agent = "Lattice",
	Automatic = true,
	Damage = 7,
	HeadshotMult = GameConfig.Combat.HeadshotMult,
	RPM = 950,
	MagSize = 45,
	ReserveAmmo = 90,
	ReloadSeconds = 2,
	Falloff = { StartStuds = 25, EndStuds = 55, MinMult = 0.55 },
	Quiet = false,
	-- SPEC-QUESTION: initial fast-handling recoil, spread and post-melee recovery tuning for playtests.
	PostMeleeFireDelay = 0.15,
	Spread = { Hip = 4.5, Aim = 0.6, PerShot = 0.22, MaxExtra = 3, RecoverPerSecond = 9, MoveMult = 1.2 },
	Recoil = { PitchPerShot = 0.4, YawPerShot = 0.1, RecoverRate = 4, ViewKick = 0.045 },
	AimZoom = 0.9,
	Sounds = librarySounds,
})

local byId: { [string]: WeaponDef } = {}
for _, def in defs do
	assert(not byId[def.Id], `Duplicate weapon {def.Id}`)
	assert(def.ReserveAmmo >= 0 and def.MagSize > 0 and def.RPM > 0, `Weapon {def.Id} has impossible ammo or rate`)
	byId[def.Id] = def
	-- Ticket menu-phase0: every playable weapon is one of its agent's three Hardware items (AgentDefs).
	assert(AgentDefs.hardwareOwner[def.Id] == def.Agent, `Weapon {def.Id} is not in {def.Agent}'s Hardware`)
end

-- Ticket menu-phase0: each agent's Hardware with its slot, unlock level and firing record, built once.
local hardwareByAgent: { [string]: { Types.AgentHardware } } = {}
for _, agentId in AgentDefs.order do
	local agent = AgentDefs.byId[agentId]
	local list: { Types.AgentHardware } = {}
	for slot, item in agent.Hardware do
		table.insert(list, {
			Id = item.Id,
			Agent = agentId,
			Slot = slot,
			UnlockMasteryLevel = GameConfig.Mastery.HardwareUnlockLevels[slot],
			Name = item.Name,
			Category = item.Category,
			Def = byId[item.Id],
		})
	end
	hardwareByAgent[agentId] = list
end
DeepFreeze(hardwareByAgent)

-- Ticket 8.5d-dmr: presentation-only data; kept here alongside ShotDefaults, outside the authoritative WeaponDef.
type WeaponVisual = {
	Magnification: number?,
	BoltCycleSeconds: number?,
	BoltTravelStuds: number?,
	DualSeparationStuds: number?,
	AimBlendRate: number?,
	PoseSpeed: number?,
	Poses: { [string]: { Position: Vector3, Rotation: Vector3 } }?,
}
local visuals: { [string]: WeaponVisual } = {
	-- Ticket 8.5c-pdw: fastest normal automatic handling. Preserve the carbine's exceptional near-zero draw.
	LatticePDW = { AimBlendRate = 24, PoseSpeed = 24 },
	ReticleCarbine = { PoseSpeed = 36 },
	ReticleDMR = { Magnification = 3, BoltCycleSeconds = 0.65, BoltTravelStuds = 0.32 },
	-- Ticket R8-pistol-pose: centre the pair, not the right-hand gun, in the ready view.
	SutureDualPistols = {
		DualSeparationStuds = 0.8,
		Poses = {
			Ready = { Position = Vector3.new(0, -0.95, -1.35), Rotation = Vector3.zero },
			-- Both wrists lower together; a single-gun across-chest yaw would stack the pair on one side.
			Tucked = { Position = Vector3.new(0, -1.15, -0.85), Rotation = Vector3.new(-55, 0, 0) },
		},
	},
}

local WeaponDefs = {
	byId = byId,
	Visuals = visuals,
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

-- An agent's three Hardware items in slot order; empty for an unknown agent.
function WeaponDefs.getForAgent(agentId: string): { Types.AgentHardware }
	return hardwareByAgent[agentId] or {}
end

-- True when the weapon is one of this agent's Hardware and is built. Mastery is checked by the caller, which knows the
-- player's level (compare with the item's UnlockMasteryLevel).
function WeaponDefs.isValidForAgent(agentId: string, weaponId: string): boolean
	return AgentDefs.hardwareOwner[weaponId] == agentId and byId[weaponId] ~= nil
end

return DeepFreeze(WeaponDefs)
