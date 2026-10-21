--!strict
-- Named constants used across server, client and map. Strings (not numbers) so logs and remotes stay readable.
-- Every value here appears in docs/cover-story-game-spec.md; do not add values that the spec doesn't define.

local DeepFreeze = require(script.Parent.Util.DeepFreeze)

local Enums = {
	-- Spec 2: match phases.
	Phase = {
		Lobby = "Lobby",
		Insertion = "Insertion",
		Infiltration = "Infiltration",
		VaultBreach = "VaultBreach",
		PackageHeist = "PackageHeist",
		Overtime = "Overtime",
		Results = "Results",
	},

	-- Spec 7.1: cover states.
	CoverState = {
		Covered = "Covered",
		Suspicious = "Suspicious",
		Exposed = "Exposed",
	},

	-- Spec 3.1: game modes.
	Mode = {
		Squads = "Squads",
		Duos = "Duos",
		Solos = "Solos",
	},

	-- Spec 5.1: NPC roles.
	Role = {
		Guest = "Guest",
		Staff = "Staff",
		Security = "Security",
		Executive = "Executive",
	},

	-- Spec 4.2: clearance tiers. The Tier attribute on zones, nodes and outfits uses these numbers.
	Tier = {
		Public = 0,
		Staff = 1,
		Security = 2,
		Executive = 3,
	},

	-- Spec 4.3: the Activity attribute on NPCNode parts.
	Activity = {
		Walk = "Walk",
		Idle = "Idle",
		Talk = "Talk",
		Sit = "Sit",
		Lean = "Lean",
		Drink = "Drink",
		Work = "Work",
		Guard = "Guard",
	},

	-- Spec 4.3: CollectionService tags on map objects.
	Tag = {
		InsertionPoint = "InsertionPoint",
		NPCNode = "NPCNode",
		IntelSpawn = "IntelSpawn",
		VaultSpawn = "VaultSpawn",
		ExtractionSite = "ExtractionSite",
		SupplyCache = "SupplyCache",
		SecurityCamera = "SecurityCamera",
		LaserGrid = "LaserGrid",
		KeycardDoor = "KeycardDoor",
		Vent = "Vent",
		ZiplineAnchor = "ZiplineAnchor",
		PickupSpawn = "PickupSpawn",
		ClimbSurface = "ClimbSurface",
		ZoneVolume = "ZoneVolume", -- Spec 4.2: invisible volumes carrying the Tier attribute.
	},

	-- Spec 5.3, 6.7, 5.4: the code-built animations NPCs (and later the Blend wheel) play.
	NpcAnimation = {
		LookAtArt = "LookAtArt",
		Phone = "Phone",
		Talk = "Talk",
		Drink = "Drink",
		Sit = "Sit",
		Lean = "Lean",
		Typing = "Typing",
		GuardStance = "GuardStance",
		Cower = "Cower",
		Gasp = "Gasp",
		GlanceLeft = "GlanceLeft",
		GlanceRight = "GlanceRight",
	},

	-- Spec 18.4: global alarm levels.
	AlarmLevel = {
		Calm = 0,
		Alert = 1,
		Heightened = 2,
		Lockdown = 3,
	},

	-- Spec 17.2: what a PickupSpawn can hold.
	PickupType = {
		ArmorPlate = "ArmorPlate",
		AmmoBox = "AmmoBox",
		Funds = "Funds",
		MedKit = "MedKit",
	},
}

return DeepFreeze(Enums)
