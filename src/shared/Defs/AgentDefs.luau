--!strict
-- The six agents (docs/AGENTS_DRAFT.md, classes from META_DRAFT). Each has three Hardware items in slot order (W1 to W3,
-- the weapons decided in docs/STEP8_QUESTIONS.md), plus its Talents and Instincts. Read Hardware through
-- WeaponDefs.getForAgent, which adds the slot, the unlock level and the firing record.
--
--   AgentDefs.byId["Guise"] -> AgentDef
--   AgentDefs.get(id) -> AgentDef?
--   AgentDefs.order -> { AgentId } in menu order

local Shared = script.Parent.Parent
local DeepFreeze = require(Shared.Util.DeepFreeze)
local Types = require(Shared.Types)

type AgentDef = Types.AgentDef

-- SPEC-QUESTION: slot order is not decided. W1 (the item every agent starts with) is a weapon that is already playable,
-- so a new player never starts with an unbuilt one; otherwise the order is AGENTS_DRAFT's. Feint's silent pistol replaced
-- the heavy revolver (STEP8_QUESTIONS, 2026-10-24).
local defs: { AgentDef } = {
	{
		Id = "Guise",
		DisplayName = "Guise",
		Epithet = "the Chameleon",
		Class = "Deceiver",
		Role = "Disguise master",
		Hardware = {
			{ Id = "GuiseSMG", Name = "Suppressed SMG", Category = "SMG" },
			{ Id = "GuisePistol", Name = "Silenced Pistol", Category = "Pistol" },
			{ Id = "GuiseGarrote", Name = "Garrote", Category = "Melee" },
		},
		Talents = {
			{
				Name = "Quick Change",
				Description = "Instantly switch to your stored disguise, even in combat lockout. Not while tracked by "
					.. "Security or carrying the Package.",
				CooldownSeconds = 30,
			},
		},
		Instincts = {
			{ Name = "Two Faces", Description = "Two disguise slots, and scanning takes 0.6 s instead of 1.2 s." },
		},
	},
	{
		Id = "Parapet",
		DisplayName = "Parapet",
		Epithet = "the Bulwark",
		Class = "Enforcer",
		Role = "Frontline anchor",
		Hardware = {
			{ Id = "ParapetHeavySMG", Name = "Heavy SMG", Category = "SMG" },
			{ Id = "ParapetShotgun", Name = "Pump Shotgun", Category = "Shotgun" },
			{ Id = "ParapetHammer", Name = "Breaching Hammer", Category = "Melee" },
		},
		Talents = {
			{
				Name = "Riot Wall",
				Description = "A carried energy shield, 8 x 6 studs, 400 HP, for 8 s. You fire through it; others can't.",
				CooldownSeconds = 35,
			},
		},
		Instincts = {
			{
				Name = "Plated",
				Description = "Start every life with 2 armour plates and put plates on twice as fast. No disguise bonuses.",
			},
		},
	},
	{
		Id = "Lattice",
		DisplayName = "Lattice",
		Epithet = "the Technician",
		Class = "Specialist",
		Role = "Hacker and scout",
		Hardware = {
			{ Id = "LatticePDW", Name = "Compact PDW", Category = "PDW" },
			{ Id = "LatticeBurstRifle", Name = "Burst Rifle", Category = "Burst rifle" },
			{ Id = "LatticeTaser", Name = "Taser", Category = "Taser" },
		},
		Talents = {
			{
				Name = "Sparrow Drone",
				Description = "Fly a drone for 15 s that hacks stations, cameras and doors remotely and tags agents in "
					.. "True Form for your team for 8 s. 40 HP.",
				CooldownSeconds = 40,
			},
		},
		Instincts = {
			{
				Name = "Wired",
				Description = "Every hack is 25% faster, and tier doors cost you 1 less intel (never below 1).",
			},
		},
	},
	{
		Id = "Reticle",
		DisplayName = "Reticle",
		Epithet = "the Marksman",
		Class = "Enforcer",
		Role = "Overwatch",
		Hardware = {
			{ Id = "ReticleDMR", Name = "Bolt-action DMR", Category = "DMR" },
			{ Id = "ReticlePistol", Name = "Marksman Pistol", Category = "Pistol" },
			{ Id = "ReticleCarbine", Name = "Folding Carbine", Category = "Carbine" },
		},
		Talents = {
			{
				Name = "Tracer Glass",
				Description = "For 6 s your scope highlights any Exposed agent, and anyone over 50% suspicion, in a "
					.. "45 degree cone to 150 studs.",
				CooldownSeconds = 30,
			},
		},
		Instincts = {
			{
				Name = "Still Water",
				Description = "Scoping while disguised raises no suspicion until you fire; falls hurt half as much.",
			},
		},
	},
	{
		Id = "Suture",
		DisplayName = "Suture",
		Epithet = "the Field Medic",
		Class = "Specialist",
		Role = "Sustain",
		Hardware = {
			{ Id = "SutureDualPistols", Name = "Dual Machine Pistols", Category = "Machine pistols" },
			{ Id = "SutureShotgun", Name = "Medic Shotgun", Category = "Shotgun" },
			{ Id = "SutureFlarePistol", Name = "Flare Pistol", Category = "Flare pistol" },
		},
		Talents = {
			{
				Name = "Mend Field",
				Description = "A canister that heals allies within 10 studs by 12 HP/s for 8 s. Disguised in a public "
					.. "zone it passes as a first-aid kit; elsewhere it breaks Cover.",
				CooldownSeconds = 45,
			},
		},
		Instincts = {
			{
				Name = "Triage",
				Description = "Teammates within 12 studs regain 2 HP/s after 6 s out of combat, and you revive in 2 s "
					.. "instead of 4.",
			},
		},
	},
	{
		Id = "Feint",
		DisplayName = "Feint",
		Epithet = "the Illusionist",
		Class = "Deceiver",
		Role = "Misdirection",
		Hardware = {
			{ Id = "FeintPistol", Name = "Silent Pistol", Category = "Pistol" },
			{ Id = "FeintSmokeSMG", Name = "Smoke-burst SMG", Category = "SMG" },
			{ Id = "FeintKnives", Name = "Throwing Knives", Category = "Thrown" },
		},
		Talents = {
			{
				Name = "Double",
				Description = "A hologram of your current look walks your aim line for 8 s, acting like an NPC if you "
					.. "are disguised. 1 HP; it gives a red hitmarker, then pops.",
				CooldownSeconds = 30,
			},
		},
		Instincts = {
			{
				Name = "Smoke and Mirrors",
				Description = "While you are Exposed, your ping shows 8 to 15 studs away from you, and re-disguising "
					.. "takes 0.3 s.",
			},
		},
	},
}

local byId: { [string]: AgentDef } = {}
local order: { Types.AgentId } = {}
local hardwareOwner: { [string]: Types.AgentId } = {}
for _, def in defs do
	assert(not byId[def.Id], `Duplicate agent {def.Id}`)
	assert(#def.Hardware == 3, `Agent {def.Id} must have exactly three Hardware items`)
	byId[def.Id] = def
	table.insert(order, def.Id)
	for _, item in def.Hardware do
		assert(not hardwareOwner[item.Id], `Hardware {item.Id} is listed for two agents`)
		hardwareOwner[item.Id] = def.Id
	end
end

local AgentDefs = {
	byId = byId,
	order = order,
	hardwareOwner = hardwareOwner, -- Hardware id -> the one agent who can carry it
}

function AgentDefs.get(id: string): AgentDef?
	return byId[id]
end

return DeepFreeze(AgentDefs)
