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
				Id = "QuickChange",
				Name = "Quick Change",
				Description = "Instantly switch to your stored disguise, even in combat lockout. Not while tracked by "
					.. "Security or carrying the Package.",
				CooldownSeconds = 30,
			},
			{
				Id = "FaceValue",
				Name = "Face Value",
				Description = "For 8 s witnesses fill your suspicion meter at 40% of the usual rate. Nothing changes about "
					.. "what they can see.",
				CooldownSeconds = 40,
			},
			{
				Id = "ColdRead",
				Name = "Cold Read",
				Description = "For 8 s scanning takes 40% of the time and reaches 60% further.",
				CooldownSeconds = 30,
			},
		},
		Instincts = {
			{
				Id = "TwoFaces",
				Name = "Two Faces",
				Description = "Two disguise slots, and scanning takes 0.6 s instead of 1.2 s.",
			},
			{
				Id = "DeepCover",
				Name = "Deep Cover",
				Description = "The combat lockout after you fire is 40% shorter, so you can re-cover sooner.",
			},
			{
				Id = "SocialClimber",
				Name = "Social Climber",
				Description = "Sprinting and jumping raise suspicion 35% more slowly.",
			},
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
			{ Id = "ParapetPump", Name = "Pump Shotgun", Category = "Shotgun" },
			{ Id = "ParapetHammer", Name = "Breaching Hammer", Category = "Melee" },
		},
		Talents = {
			{
				Id = "RiotWall",
				Name = "Riot Wall",
				Description = "A carried energy shield, 8 x 6 studs, 400 HP, for 8 s. You fire through it; others can't.",
				CooldownSeconds = 35,
			},
			{
				Id = "Brace",
				Name = "Brace",
				Description = "For 5 s you take half damage from every source.",
				CooldownSeconds = 30,
			},
			{
				Id = "PlateSlam",
				Name = "Plate Slam",
				Description = "Slap one armour plate on at once, if you have room for it.",
				CooldownSeconds = 40,
			},
		},
		Instincts = {
			{
				Id = "Plated",
				Name = "Plated",
				Description = "Start every life with 2 armour plates and put plates on twice as fast. No disguise bonuses.",
			},
			{ Id = "ThickSkin", Name = "Thick Skin", Description = "Every hit you take hurts 10% less." },
			{
				Id = "Anchor",
				Name = "Anchor",
				Description = "Stagger, shove and slowing effects on you last half as long.",
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
				Id = "SparrowDrone",
				Name = "Sparrow Drone",
				Description = "Fly a drone for 15 s that hacks stations, cameras and doors remotely and tags agents in "
					.. "True Form for your team for 8 s. 40 HP.",
				CooldownSeconds = 40,
			},
			{
				Id = "Overclock",
				Name = "Overclock",
				Description = "For 10 s every hack you run takes 60% of the usual time.",
				CooldownSeconds = 35,
			},
			{
				Id = "SignalJam",
				Name = "Signal Jam",
				Description = "Every working camera within 45 studs goes dark for 8 s.",
				CooldownSeconds = 40,
			},
		},
		Instincts = {
			{
				Id = "Wired",
				Name = "Wired",
				Description = "Every hack is 25% faster, and tier doors cost you 1 less intel (never below 1).",
			},
			{
				Id = "DataMiner",
				Name = "Data Miner",
				Description = "Every Intel station you finish pays your team 1 more intel.",
			},
			{ Id = "LowProfile", Name = "Low Profile", Description = "Hacking raises suspicion half as fast." },
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
				Id = "TracerGlass",
				Name = "Tracer Glass",
				Description = "For 6 s your scope highlights any Exposed agent, and anyone over 50% suspicion, in a "
					.. "45 degree cone to 150 studs.",
				CooldownSeconds = 30,
			},
			{
				Id = "Focus",
				Name = "Focus",
				Description = "For 8 s your shots hurt 20% more.",
				CooldownSeconds = 30,
			},
			{
				Id = "MarkedMan",
				Name = "Marked Man",
				Description = "The nearest Exposed agent you can see within 100 studs glows for you, through walls, for 6 s.",
				CooldownSeconds = 35,
			},
		},
		Instincts = {
			{
				Id = "StillWater",
				Name = "Still Water",
				Description = "Scoping while disguised raises no suspicion until you fire; falls hurt half as much.",
			},
			{
				Id = "PatientHunter",
				Name = "Patient Hunter",
				Description = "Your shots hurt an Exposed agent 10% more.",
			},
			{ Id = "ColdBlood", Name = "Cold Blood", Description = "Your suspicion meter drains half again as fast." },
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
			{ Id = "SutureFlare", Name = "Flare Pistol", Category = "Flare pistol" },
		},
		Talents = {
			{
				Id = "MendField",
				Name = "Mend Field",
				Description = "A canister that heals allies within 10 studs by 12 HP/s for 8 s. Disguised in a public "
					.. "zone it passes as a first-aid kit; elsewhere it breaks Cover.",
				CooldownSeconds = 45,
			},
			{
				Id = "Adrenaline",
				Name = "Adrenaline",
				Description = "Heal 40 HP at once and shake off any slowing effect. Not while downed.",
				CooldownSeconds = 35,
			},
			{
				Id = "Screen",
				Name = "Screen",
				Description = "Set a smoke cloud just ahead of you for 6 s. It blocks sight, not bullets.",
				CooldownSeconds = 40,
			},
		},
		Instincts = {
			{
				Id = "Triage",
				Name = "Triage",
				Description = "Teammates within 12 studs regain 2 HP/s after 6 s out of combat, and you revive in 2 s "
					.. "instead of 4.",
			},
			{
				Id = "SecondWind",
				Name = "Second Wind",
				Description = "When you are downed you bleed out 30% more slowly.",
			},
			{
				Id = "SelfCare",
				Name = "Self-Care",
				Description = "You regain 1.5 HP/s after 6 s out of combat.",
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
				Id = "Double",
				Name = "Double",
				Description = "A hologram of your current look walks your aim line for 8 s, acting like an NPC if you "
					.. "are disguised. 1 HP; it gives a red hitmarker, then pops.",
				CooldownSeconds = 30,
			},
			{
				Id = "Lure",
				Name = "Lure",
				Description = "Make a loud noise 25 studs ahead: guards investigate it and the crowd looks.",
				CooldownSeconds = 30,
			},
			{
				Id = "TwinDouble",
				Name = "Twin Double",
				Description = "Two Doubles of your current look walk off at 25 degrees either side of your aim for 8 s.",
				CooldownSeconds = 45,
			},
		},
		Instincts = {
			{
				Id = "SmokeAndMirrors",
				Name = "Smoke and Mirrors",
				Description = "While you are Exposed, your ping shows 8 to 15 studs away from you, and re-disguising "
					.. "takes 0.3 s.",
			},
			{ Id = "CheapTricks", Name = "Cheap Tricks", Description = "Every Talent cools down 20% faster." },
			{
				Id = "GhostTrail",
				Name = "Ghost Trail",
				Description = "The ping rivals get when you are Exposed lasts half as long.",
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

for _, def in defs do
	assert(
		#def.Talents == 3 and #def.Instincts == 3,
		`Agent {def.Id} must have exactly three Talents and three Instincts`
	)
	for _, list in { def.Talents, def.Instincts } do
		local seen: { [string]: boolean } = {}
		for _, item in list do
			assert(not seen[item.Id], `Agent {def.Id} lists kit item {item.Id} twice`)
			seen[item.Id] = true
		end
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

-- The position (1 to 3) of a Talent or Instinct in the agent's list, or nil if the agent has no such item. Its slot decides when
-- mastery unlocks it (GameConfig.Mastery.TalentUnlockLevels and InstinctUnlockLevels).
function AgentDefs.talentSlot(agentId: string, talentId: string): number?
	local def = byId[agentId]
	if def then
		for slot, item in def.Talents do
			if item.Id == talentId then
				return slot
			end
		end
	end
	return nil
end

function AgentDefs.instinctSlot(agentId: string, instinctId: string): number?
	local def = byId[agentId]
	if def then
		for slot, item in def.Instincts do
			if item.Id == instinctId then
				return slot
			end
		end
	end
	return nil
end

return DeepFreeze(AgentDefs)
