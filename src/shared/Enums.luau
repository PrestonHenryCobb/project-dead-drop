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
		Sanctum = 4, -- Tier 4, above Executive: The Sanctum's foyer, Package room and terraces (relayout-1)
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
		ClearanceDoor = "ClearanceDoor", -- a door that opens only for a disguise of its Tier or higher (STEP 7B)
		Vent = "Vent",
		ZiplineAnchor = "ZiplineAnchor",
		PickupSpawn = "PickupSpawn",
		ClimbSurface = "ClimbSurface",
		Seat = "Seat", -- a place the Blend wheel's Sit emote works near (spec 6.7)
		ZoneVolume = "ZoneVolume", -- Spec 4.2: invisible volumes carrying the Tier attribute.
		-- Step 7B pass 2: vault parts, and things players use (bought with intel, free, or looted).
		VaultDoor = "VaultDoor", -- the inner vault door (spec 10); VaultId names its vault
		VaultHackZone = "VaultHackZone", -- the 10 x 10 floor zone in front of the inner door (spec 10.2)
		PackagePedestal = "PackagePedestal", -- where the Package sits, and returns to (spec 11)
		HealthStation = "HealthStation", -- wall health station in a restroom, bought with intel
		AmmoCache = "AmmoCache", -- wall ammo cache, bought with intel
		FoodSpot = "FoodSpot", -- free food: heals less than a health station
		AssetSafe = "AssetSafe", -- a safe holding an asset; its Tier sets the rarity odds
		VentDuct = "VentDuct", -- the inside of a vent duct; VentService breaks the Cover of anyone in it
		Gondola = "Gondola", -- the gondola floor, with Start and End positions (GondolaService)
		GondolaCall = "GondolaCall", -- a gondola call button at the dock named by End ("Start" or "End")
		-- Map re-plan stage 2: a one-way window pane. Its Inside attribute (a unit vector) points into the room that sees
		-- out; OneWayGlassController draws it clear for a camera on that side and mirrored for everyone else.
		OneWayGlass = "OneWayGlass",
		-- Map re-plan stage 3: a lit sign. Text1/Color1/Normal1 (and Text2/Color2/Normal2 for a sign read from both sides)
		-- say what each side reads; SignController floats that text toward a nearby camera.
		Sign = "Sign",
		-- Gala re-layout (relayout-1): the five vault terminal spots (three are active a match), the five keycard printer
		-- spots (one is active), prop-triggered secret exits, glass elevators, the Package doors and the service ladders.
		VaultTerminalSpot = "VaultTerminalSpot", -- VaultId; the terminal itself is made at match start
		KeycardPrinterSpot = "KeycardPrinterSpot", -- PrinterId, Cost, Seconds; the printer is made at match start
		SecretExit = "SecretExit", -- the panel that opens; ExitId
		SecretExitTrigger = "SecretExitTrigger", -- the prop inside that opens it; ExitId
		ElevatorCab = "ElevatorCab", -- ShaftId, Stops ("G:0,M:24,T:48"), Locked
		ElevatorDoor = "ElevatorDoor", -- ShaftId, Level, Tier, HackCost
		ElevatorCall = "ElevatorCall", -- ShaftId, Level
		PackageDoor = "PackageDoor", -- Side ("Front" or "Back"), HackCost, KeycardOnly
		ServiceLadder = "ServiceLadder", -- a Cover-breaking ladder up the crown
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
		-- R4-body-animation (Util/Knockdown names them by stage, fall and posture).
		KnockdownForward = "KnockdownForward",
		KnockdownBackward = "KnockdownBackward",
		KnockdownLeft = "KnockdownLeft",
		KnockdownRight = "KnockdownRight",
		LieProne = "LieProne",
		LieSupine = "LieSupine",
		CrawlProne = "CrawlProne",
		CrawlSupine = "CrawlSupine",
		DeadProne = "DeadProne",
		DeadSupine = "DeadSupine",
		-- R5-takedown: the two bodies of a takedown hold.
		TakedownGrab = "TakedownGrab",
		TakedownStruggle = "TakedownStruggle",
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
