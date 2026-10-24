--!strict
-- Every tunable number in the game (CLAUDE.md rule 2). Values come from docs/cover-story-game-spec.md;
-- the section each group comes from is noted above it. Frozen, so nothing can change it at runtime.
--
-- Per-content stats (weapons, agents, gadgets, perks, outfits) live in shared/Defs and are added in the
-- build steps that use them. Numbers that apply to many systems belong here.
--
-- SPEC-QUESTION markers below are places where the spec gives no value; each one is listed in the
-- end-of-step summary.

local DeepFreeze = require(script.Parent.Util.DeepFreeze)

local GameConfig = {
	-- Spec 2: phase timeline. All times in seconds.
	Match = {
		LobbySeconds = 30,
		InsertionSeconds = 8,
		MainTimerSeconds = 14 * 60, -- counts down from the start of Phase 2
		ForcedVaultUnlockElapsed = 6 * 60, -- Phase 2 ends at this elapsed time at the latest
		ResultsSeconds = 15,
		FillCountdownMax = 60, -- 3.1: wait this long for players, then start if >= 2 teams
		MinTeamsToStart = 2,
		MaxPlayers = 12,
	},

	-- Spec 3.1: modes.
	Modes = {
		Squads = { TeamSize = 3, MaxTeams = 4, MinPlayers = 4, MaxPlayers = 12 },
		Duos = { TeamSize = 2, MaxTeams = 6, MinPlayers = 4, MaxPlayers = 12 },
		Solos = { TeamSize = 1, MaxTeams = 8, MinPlayers = 3, MaxPlayers = 8 },
	},

	-- Spec 3.2 / 3.3: agent select and team colors (in the order teams are assigned).
	Lobby = {
		AgentSelectSeconds = 30,
		TeamColors = {
			{ Name = "Cyan", Color = Color3.fromRGB(0, 220, 255) },
			{ Name = "Magenta", Color = Color3.fromRGB(255, 0, 200) },
			{ Name = "Lime", Color = Color3.fromRGB(150, 255, 0) },
			{ Name = "Amber", Color = Color3.fromRGB(255, 190, 0) },
			{ Name = "Violet", Color = Color3.fromRGB(150, 90, 255) },
			{ Name = "Coral", Color = Color3.fromRGB(255, 110, 100) },
			{ Name = "Teal", Color = Color3.fromRGB(0, 170, 150) },
			{ Name = "White", Color = Color3.fromRGB(255, 255, 255) },
		},
	},

	-- Spec 4.2: clearance zones.
	Zones = {
		CheckInterval = 0.25, -- server samples each player's tier at 4 Hz
		-- Brighter, easier to tell apart (SPEC_CHANGES 4.2, 2026-10-23): door handles, pips, floor inlays, signs and the
		-- uniform trims all use these. Asset rarities follow them too (Field Agent grey, Infiltrator green, Black Ops
		-- dark purple, Ghost gold).
		TierColors = {
			[0] = Color3.fromRGB(215, 215, 215), -- Public: white/grey
			[1] = Color3.fromRGB(60, 175, 90), -- Staff: green, matching the green ties and lapels on the navy suits
			[2] = Color3.fromRGB(105, 45, 160), -- Security: dark purple, matching the black suits with purple trim
			[3] = Color3.fromRGB(225, 190, 95), -- Executive: gold, matching the cream suits with gold trim
		},
		VaultColor = Color3.fromRGB(205, 45, 45), -- vault doors, vault-wing trim and the vault strongroom lights
		-- How many pips a tier door's handles carry (Public doors have plain handles).
		TierPips = { [0] = 0, [1] = 1, [2] = 2, [3] = 3 },
	},

	-- Spec 4.3 / 4.4: what the map must contain (used by map validation).
	Map = {
		FootprintStuds = 520, -- the map re-plan (docs/MAP_BRIEF_REPLAN.md)
		Counts = {
			InsertionPoint = 12,
			IntelSpawn = 48, -- SPEC_CHANGES (intel amounts): about 50% more, since intel also opens doors
			VaultSpawn = 4, -- the spec has 3; a fourth sits in the hotel wing (BUILD_ORDER Step 7B)
			ExtractionSite = 3,
			SupplyCache = 6,
			SecurityCamera = 12,
			LaserGrid = 4,
			KeycardDoor = 6,
			VentPairs = 6,
			ZiplineAnchorPairs = 2,
			PickupSpawn = 30,
			HealthStation = 6,
			AmmoCache = 8,
			FoodSpot = 20,
			AssetSafe = 12,
		},
		NPCNodeCount = { Min = 150, Max = 800 }, -- spec says 150 to 250; 200 NPCs on the larger re-planned layout need more (SPEC-QUESTION)
		SupplyCachesPerTier = { [0] = 2, [1] = 2, [2] = 1, [3] = 1 },
		InsertionMinSpacing = 60,
		TeamSpawnRadius = 8, -- teammates spawn within this many studs of each other
		MinEntrancesPerRestrictedZone = 2,
		MinExtractionPathDistanceFromVault = 120,
		MinVaultRoutesOut = 3,
		MaxLongSightLines = 3, -- sight lines over 150 studs
		LongSightLineStuds = 150,
		MinIntelPerTierOnActivation = 2,
		-- Tier and keycard doors (MAP_BRIEF_REPLAN stage 3): how the visible leaves swing when DoorService opens one.
		Doors = {
			SwingSeconds = 0.35,
			SwingDegrees = 95,
		},
		-- Signs (MAP_BRIEF_REPLAN stage 3): from close by, a sign's text floats in front of it facing the camera at a
		-- fixed readable size, fading in between FadeOutStuds and FadeInStuds while the wall text fades out.
		Signs = {
			FadeInStuds = 12, -- fully shown at this distance or closer
			FadeOutStuds = 20, -- hidden at this distance or further
			FadeSeconds = 0.25, -- how long a fade takes to catch up with the distance, so it never pops
			FloatSize = UDim2.fromOffset(170, 30), -- on-screen size of the floating text, the same at any distance
			FloatOffset = 1.5, -- studs: how far it floats out from the sign, toward the reader
			OutlineThickness = 1.5, -- the tier-colour outline round the floating text
			RowSize = UDim2.fromOffset(190, 24), -- one row of a direction signpost (arrow, place, distance)
			MetersPerStud = 0.28, -- distances on signposts are shown in metres
		},
		-- One-way windows (MAP_BRIEF_REPLAN stage 2): how a pane looks from the room that sees out, and from outside.
		-- Each client decides from its own camera; the pane blocks movement, shots and sight checks either way.
		OneWayGlass = {
			InsideTransparency = 0.6,
			OutsideReflectance = 0.5,
		},
	},

	-- Spec 5.1 to 5.5: NPCs.
	NPC = {
		-- Raised from the spec's 74 (Guest 40, Staff 18, Security 10, Executive 6): to 90, then to 200 for PC and console
		-- (BUILD_ORDER Step 7B). Guests fill the party; guards and Executives staff the guard rooms, vaults and penthouse.
		TargetCount = 200,
		RoleCounts = { Guest = 120, Staff = 40, Security = 25, Executive = 15 },
		-- Where each role likes to be, by tier: how often a node of that tier is picked when an NPC spawns and when it
		-- chooses where to walk next. Guards favour their own tier and Executives the top one; every role may still pass
		-- through any tier it is allowed in (RoleMaxTier), so the building stays alive and nobody is confined.
		RoleTierWeights = {
			Guest = { [0] = 1 },
			Staff = { [0] = 1, [1] = 3 },
			Security = { [0] = 0.5, [1] = 1, [2] = 3 },
			Executive = { [0] = 0.6, [1] = 0.3, [2] = 1, [3] = 4 },
		},
		-- Highest tier each role may stand in (it may also use tier 0).
		RoleMaxTier = { Guest = 0, Staff = 1, Security = 2, Executive = 3 },
		-- Walk speed per role, in studs/s. A disguised agent's speed is capped to their disguise's role (spec 6.8).
		-- SPEC-QUESTION: the spec gives Guest 10 and Staff 12 only. Security and Executive use 10 until it says more.
		WalkSpeed = { Guest = 10, Staff = 12, Security = 10, Executive = 10 },
		MinOutfitsPerRole = 20,
		MaxHP = 50,
		ServerTickHz = 10, -- 25.4: server moves NPC roots along paths at 10 Hz, clients interpolate
		ActivitySeconds = { Min = 6, Max = 20 },
		MaxYawRate = 270, -- degrees per second
		SeparationStuds = 2.5,
		DoorCloseDelay = 3,
		GlanceInterval = { Min = 4, Max = 10 }, -- 8.1: random head glances
		GlanceDegrees = 40,
		CorpseSeconds = 30,
		ReplacementSeconds = 45,
		MobileRenderDistance = 120, -- 27 #27: NPC visuals beyond this are not shown on low-end mobile
		Panic = {
			GunfireRadius = 40,
			CowerSeconds = 3,
			FleeSeconds = 8,
			FleeSpeed = 16,
			BodyRadius = 15,
			ExplosionRadius = 25,
			ExplosionDownRadius = 6, -- NPCs this close to a blast are downed (spec 5.5, reworked: no ragdoll)
			-- Who panics at gunfire and explosions (5.4: Guests and Staff), and who gasps at a body (Guests).
			PanicRoles = { Guest = true, Staff = true },
			BodyRoles = { Guest = true },
			GaspSeconds = 1.4,
			BackAwayStuds = 5,
		},
		-- Spec 5.3: what each node Activity looks like. Idle picks one at random; Walk is a pass-through, no stop.
		ActivityAnimations = {
			Walk = {},
			Idle = { "Idle", "LookAtArt", "Phone" },
			Talk = { "Talk" },
			Sit = { "Sit" },
			Lean = { "Lean" },
			Drink = { "Drink" },
			Work = { "Typing" },
			Guard = { "GuardStance" },
		},
		ActivityResyncSeconds = 5, -- the server repeats every NPC's animation this often, so late joiners catch up
		-- Spec 5.2: NPCs open doors automatically and the doors close DoorCloseDelay after the last body passes.
		-- SPEC-QUESTION: the spec doesn't say whether NPCs open keycard shortcut doors. They do here, which lets a
		-- player slip through behind an NPC. Set OpenForNpcs to false to keep them shut.
		Door = { OpenStuds = 8, OpenForNpcs = true, PlayerCheckSeconds = 0.1 },
		-- Guards investigate gunfire and explosions (OPEN_QUESTIONS A6). SPEC-QUESTION: the spec has Security ignore
		-- noise. A guard on the same floor within SameFloorStuds goes to look. A guard on another floor goes only if it
		-- is within OpenFloorStuds and can see the source, which is how a stair or balcony open to the floor counts.
		-- It goes back to its post once ReturnAfterQuietSeconds pass with no further noise within range.
		Investigate = {
			Roles = { Security = true },
			SameFloorStuds = 60,
			OpenFloorStuds = 40,
			FloorHeightStuds = 12, -- guards whose feet are within this height of the noise are on its floor
			ReturnAfterQuietSeconds = 15,
		},
		-- NPCs are never killed outright (OPEN_QUESTIONS A7). At 0 HP they go down under the same rules as a downed
		-- player (spec 14.1): they crawl at Downed.CrawlSpeed, are Exposed-equivalent, and bleed out after
		-- Downed.BleedOutSeconds. A bled-out NPC lies still for CorpseSeconds, fades, and is replaced.
		-- SPEC-QUESTION: nothing revives an NPC, since a revive only ever happening to NPCs would tell them from players.
		Death = {
			FadeSeconds = 1,
			ReplacementMinStuds = 100, -- implementation tuning: "far-away node" means at least this far from the body
			CrawlSpeed = 4, -- spec 14.1
			CrawlStuds = 6, -- how far a downed NPC drags itself away from the shot before it stops
			RootLiftStuds = 1.2, -- height of the lying body's centre above the floor
		},
		CivilianKill = {
			ExposedSeconds = 10,
			FundsPenalty = 50,
			AlarmRaise = 1,
		},
		SecurityKillAlarmRaise = 1,
		-- Implementation tuning for the node graph and crowd movement (not spec values).
		Graph = {
			NeighborsPerNode = 6, -- each node tries to link to this many of its nearest nodes on the same level
			CrossLevelNeighbors = 3, -- and to this many on the levels above and below (kept only if a ramp is close)
			SameLevelStuds = 6, -- nodes whose heights differ by less than this are on the same level
			MaxEdgeStuds = 90, -- nodes further apart than this are never linked directly
			MaxDetourRatio = 2, -- a link is dropped if its walking path is this many times the straight distance
			AgentRadius = 2,
			AgentHeight = 5,
			ConcurrentPaths = 24, -- paths computed at the same time while the graph builds
			TierSampleStuds = 4, -- how often a link is sampled to find the highest tier it passes through
		},
		MinTripStuds = 30, -- an NPC's next destination is at least this far away
		TripPreferStuds = 120, -- destinations this far (walking) are half as likely as near ones; keeps long trips rare
		ArrivalSpread = 3, -- NPCs stand within this many studs of a node, so they don't stack on one point
		NodeCapacity = 2, -- NPCs that may stand at or head to one node at once (a pair chatting at a spot)
		SeparationMaxOffset = 1.25, -- how far separation may push an NPC off its path
		SeparationStrength = 4,
		SeparationDecayPerSecond = 2,
		-- Client side: NPCs are drawn this far in the past, between the two latest server updates.
		InterpolationDelay = 0.15,
		AnimationSpeedReference = 14.5, -- the default Animate script plays walk at speed / 14.5; NPCs must match
		WalkAnimationMinSpeed = 0.5,
		AnimationFadeSeconds = 0.2,
		AnimationCullStuds = 160, -- NPCs further than this from the camera are not animated (client performance)
	},

	-- The low-frame-rate look every character shares (StepAnimationController): poses change this many times a second.
	Animation = {
		StepHz = 8,
		StepCullStuds = 120, -- characters further from the camera than this animate normally
		MinJoints = 12, -- a rig with fewer animated joints than this has not finished arriving
	},

	-- Spec 6, 7, 8: disguise, cover, suspicion.
	Cover = {
		ScanRange = 8,
		ScanSeconds = 1.2,
		ExposedScanSeconds = 3, -- scanning an Exposed agent copies their last disguise (OPEN_QUESTIONS C2)
		DisguiseSeconds = 0.8,
		DisguiseSwishRadius = 10, -- visible puff and audible swish
		DisguiseSlots = 1,
		-- Spec 7.4's 3 s grace countdown is not used: trespass is a rate that builds suspicion while witnessed
		-- (STEP7_QUESTIONS C1). Vesper's "grace 6 s" perk is reinterpreted when she is built in Step 16.
		TrespassGrace = 3,
		CombatLockout = 5,
		ExposeStripSeconds = 0.3,
		ExposedPingRadius = 60,
		ExposedPingSeconds = 2,
		SuspicionMax = 100,
		SuspicionDecayPerSecond = 10,
		-- Spec 7.3 says 1.5 s; STEP7_QUESTIONS B1 asks for another 1.5 s before decay starts.
		SuspicionDecayDelay = 3,
		TrespassGainPerSecond = 70, -- percent per second at one tier over, while witnessed (doubled 2026-10-23: too slow)
		-- Multiplier on that rate by how many tiers the zone is above the disguise's clearance (1, 2, 3 tiers over).
		TrespassTierMultipliers = { 1, 1.5, 2 },
		ReCoverTrackingSeconds = 3, -- a Security NPC "tracks" you this long after last seeing you (re-covering)
		WitnessEyeHeight = 1.5, -- studs above an NPC's feet
		WitnessTargetHeight = 1.5, -- studs above a player's feet the sight line aims at
		-- Each witness kind's share of a witnessed suspicious action; shares add up but never count for more than the cap.
		-- Civilians (every NPC but Security) only notice CivilianNotices; Security and cameras notice everything.
		WitnessWeights = { Security = 1, Camera = 0.6, Npc = 0.5 },
		CivilianNotices = { Sprint = true, Jump = true },
		WitnessCap = 1,
		CrouchCameraDrop = 1.2, -- studs the camera lowers while crouching
		-- Percent. Sprint, Crouch, Terminal, WeaponDrawn, NearBody and VaultLinger are per second; Jump is per jump.
		-- Doubled 2026-10-23 (suspicion rose too slowly). Sprint and Jump count in every tier; the rest in Tier 1 and up.
		SuspicionGain = {
			Sprint = 50,
			Jump = 40,
			Crouch = 30,
			Terminal = 40,
			WeaponDrawn = 80,
			NearBody = 20,
			VaultLinger = 30,
		},
		NearBodyRadius = 6,
		VaultLingerRadius = 5,
		VaultLingerSeconds = 3,
		-- Witnesses (7.3, with OPEN_QUESTIONS C1): every NPC and active camera counts, not only Security. Every NPC
		-- sees the same range and field of view, and only walls block sight.
		WitnessCheckHz = 5,
		WitnessRange = 35,
		WitnessFov = 110,
		-- Neck follows the camera (8.1).
		NeckMaxYaw = 60,
		NeckMaxPitch = 40,
		-- Implementation tuning for scanning (6.3). The server checks range and sight itself; the client only aims.
		ScanRangeSlack = 1.5, -- studs of allowance for lag when the server checks ScanRange
		ScanSightHeight = 1.5, -- studs above the feet the sight line is drawn between
		ScanCheckSeconds = 0.1, -- how often the server re-checks every scan in progress
		-- Facing while disguised (OPEN_QUESTIONS C5, STYLE_QUESTIONS A3): the body faces where it walks, not where the
		-- camera looks. Standing still, it turns slowly to the camera after IdleTurnDelay, like an NPC glancing.
		IdleTurnDelay = 1.5,
		IdleTurnRate = 60, -- degrees per second
		IdleTurnDeadband = 25, -- degrees between body and camera before it turns at all
		DisguisePuffParticles = 20,
		DisguisePuffSeconds = 1.5,
		SeatRange = 6, -- Sit on the Blend wheel works within this many studs of a Seat-tagged part
		-- Agent Sense (8.3).
		AgentSenseRange = 6,
		AgentSenseSeconds = 1.5,
		AgentSenseShimmerSeconds = 1,
		AgentSenseCooldown = 8,
		AgentSenseCheckSeconds = 0.2, -- how often the server checks looks and nearby exposed enemies
		-- Blend wheel (6.7): the emotes it offers.
		BlendEmotes = { "Idle", "Look Around", "Phone", "Drink", "Talk", "Lean", "Sit", "Cower" },
		-- The pose each emote plays (Defs/PoseDefs). Idle plays none: it just stops the current emote.
		BlendEmoteAnimations = {
			["Look Around"] = "LookAtArt",
			Phone = "Phone",
			Drink = "Drink",
			Talk = "Talk",
			Lean = "Lean",
			Sit = "Sit",
			Cower = "Cower",
		},
	},

	-- Spec 6.8, 11, 14.1, 18.4, 5.4: speeds in studs/s.
	Speeds = {
		Sprint = 18,
		ExposedWalk = 16, -- STEP7_QUESTIONS D2: walk speed in True Form
		CrouchMult = 0.6, -- of the walk speed, while crouching (STEP7_QUESTIONS, crouch)
		Crawl = 4,
		CarrierMult = 0.9,
	},

	-- Spec 9: intel.
	Intel = {
		-- Four station types (SPEC_CHANGES, intel amounts), chosen per station on the map. Points is the intel a station
		-- gives; HackSeconds how long it takes; MinRoomTier the lowest room tier it may stand in.
		Stations = {
			[0] = { Name = "Tablet", Points = 2, HackSeconds = 4, MinRoomTier = 0 },
			[1] = { Name = "Staff laptop", Points = 4, HackSeconds = 7, MinRoomTier = 0 },
			[2] = { Name = "Server rack", Points = 6, HackSeconds = 11, MinRoomTier = 0 },
			[3] = { Name = "Wall safe", Points = 10, HackSeconds = 16, MinRoomTier = 2 },
		},
		ActiveSpawns = 10,
		TerminalSeconds = 6,
		TerminalProgressKeepSeconds = 20, -- per team
		BriefcaseSeconds = 1,
		PickpocketSeconds = 2,
		PickpocketRange = 3,
		ServerRackSeconds = 10,
		ServerRackValue = 2,
		GlintRange = 25,
		-- 9.3: team thresholds.
		Thresholds = {
			FundsAt1 = 100,
			VaultArrowAt = 2,
			HackBonusAt = 3,
			CarrierRevealAt = 4,
			CarrierRevealInterval = 15,
			CarrierRevealSeconds = 1,
			ExtraIntelFunds = 50, -- at 5 and above, per extra Intel
			ExtraIntelFrom = 5,
		},
		-- 9.4: vault unlocks when GlobalIntel >= min(Cap, Base + teams * PerTeam).
		Unlock = { Base = 5, PerTeam = 5, Cap = 35 },
	},

	-- Spec 10: vault.
	Vault = {
		BaseRate = 1.25, -- percent per second, regardless of how many agents are in the zone
		BonusMult = 1.25, -- team with HackBonusAt+ intel
		HackZoneSize = 10,
		OpenAnimSeconds = 4,
		ExtraSecurityOnOpen = 2,
	},

	-- Spec 11: package.
	Package = {
		PickupSeconds = 1,
		PickupRange = 4,
		ReturnSeconds = 30, -- dropped and untouched
		PingInterval = 10,
		PingPulseSeconds = 2,
		PassRange = 6,
		PassSeconds = 0.5,
	},

	-- Spec 12: extraction.
	Extraction = {
		CallSeconds = 2,
		CallRange = 10, -- a teammate within this many studs of the carrier may also call
		Countdown = 45,
		HoverSeconds = 2,
		ZoneSize = 16,
		ChannelSeconds = 3,
		LingerAfterFailSeconds = 20,
		CinematicSeconds = 5,
	},

	-- Spec 19: overtime.
	Overtime = {
		CapSeconds = 90,
		DroppedGraceSeconds = 10,
		ExtractionCountdown = 20,
	},

	-- Spec 13: combat.
	Combat = {
		MaxHP = 100,
		PlateHP = 25,
		MaxPlates = 3,
		StartPlates = 1,
		SoloStartPlates = 2,
		HeadshotMult = 1.5,
		MarksmanHeadshotMult = 2,
		FallSafeStuds = 30,
		FallDamagePerStud = 2,
		SelfExplosionMult = 0.5,
		-- 13.3: server validation of FireRequest.
		LagCompSeconds = 0.25,
		LagCompHistoryHz = 20,
		FireRateToleranceSeconds = 0.04,
		FireOriginToleranceStuds = 4,
		Melee = {
			Damage = 35,
			CooldownSeconds = 0.8,
			Range = 4,
			SwingConeDegrees = 90,
			ReachSlackStuds = 1.5,
			HeightStuds = 3,
		},
		Takedown = { ConeDegrees = 60, HoldSeconds = 1.2, Damage = 90, BreakDistance = 4, CheckSeconds = 0.1 },
		-- Weapons (STEP8_QUESTIONS). The weapon every player carries until agent select exists (Step 10).
		DefaultWeapon = "GuiseSMG",
		MaxShotStuds = 400, -- the longest ray the server casts for a shot
		FireDirectionTolerance = 0.02, -- a FireRequest direction must be a unit vector within this
		PlayerRenderDelay = 0.1, -- how far behind the server a client sees other players; the rewind adds it (NPCs: NPC.InterpolationDelay)
		GunfireReactSeconds = 0.5, -- NPCs react to a shooter's gunfire at most this often
		MovingSpeedStuds = 2, -- a body faster than this counts as moving for spread
		-- Hit boxes the server tests rewound shots against: a vertical cylinder from the feet to the head, and the head.
		Hitbox = { BodyRadius = 1.25, HeadRadiusScale = 0.6, HeadMinRadius = 0.5, CullStuds = 4.5 },
		ViolationLogEvery = 10, -- the server warns about a player's impossible requests this often (spec 26: log, never ban on it)
		-- Client side: what a shot, a hit and a wound look and sound like. All of it is feedback only; the server decides.
		Feedback = {
			HitmarkerSeconds = 0.18,
			HitmarkerPixels = 14,
			HeadshotHitmarkerScale = 1.6,
			NpcHitColor = Color3.fromRGB(190, 190, 195), -- grey: an NPC (spec 8.4)
			AgentHitColor = Color3.fromRGB(235, 60, 60), -- red: an agent
			HitSounds = {
				Npc = "rbxassetid://6607204501",
				Agent = "rbxassetid://6607339542",
				Head = "rbxassetid://6607113255",
			},
			HitSoundVolume = 0.6,
			HeadshotPitch = 1.3,
			DamageIndicatorSeconds = 1.2,
			DamageIndicatorPixels = 90, -- distance of the marker from the centre of the screen
			DamageIndicatorColor = Color3.fromRGB(235, 60, 60),
			ImpactSound = "rbxassetid://85805517776968",
			ImpactParticles = 6,
			ImpactSeconds = 0.4,
			ShotVolume = 0.8,
			ShotRollOff = 8, -- studs: the shot sound is full volume within this and fades to nothing at its hearing range
			MeleeSound = "rbxassetid://113744400706298",
			CrosshairGapPixels = 6, -- the weapon crosshair's resting gap, before spread opens it
			CrosshairLengthPixels = 8,
			CrosshairColor = Color3.fromRGB(240, 240, 245),
			HealthColor = Color3.fromRGB(90, 200, 120),
			ArmorColor = Color3.fromRGB(110, 170, 235),
			LowHealthFraction = 0.3,
			LowHealthColor = Color3.fromRGB(235, 70, 70),
		},
		-- The first-person view model (client only): where the gun sits in each pose, in studs from the camera (+x right,
		-- -y down, -z forward) with a rotation in degrees (pitch, yaw, roll), and how fast it moves between poses.
		ViewModel = {
			Poses = {
				-- Disguised: tucked across the chest, barrel angled down (STEP8 answers).
				Tucked = { Position = Vector3.new(0.1, -1.35, -1.25), Rotation = Vector3.new(-38, 80, 8) },
				-- Exposed: up and combat ready, in the right third of the screen.
				Ready = { Position = Vector3.new(1.05, -0.95, -1.85), Rotation = Vector3.new(0, -3, 0) },
				-- Aiming: centred on the line of sight.
				Aim = { Position = Vector3.new(0, -0.62, -1.55), Rotation = Vector3.zero },
			},
			PoseSpeed = 12, -- how quickly the gun settles into a pose (per second)
			SwayStrength = 0.04, -- studs of lag per radian of view movement per second
			SwayLimitStuds = 0.25, -- the most the gun lags behind a fast turn
			SwaySettle = 10, -- per second, how fast that lag catches up
			AimBobFraction = 0.2, -- the walking bob while aiming, as a share of the usual
			BobSpeed = 7, -- walking bob cycles per second at full speed
			BobStuds = 0.035,
			KickRecoverSpeed = 14, -- per second, how quickly the gun returns from a shot's jolt
			ReloadDipStuds = 0.9, -- how far the gun lowers while reloading
			ReloadTilt = 25, -- degrees of roll while reloading
			GunColor = Color3.fromRGB(32, 33, 38),
			AccentColor = Color3.fromRGB(70, 72, 80),
		},
	},

	-- Spec 14: downed, revive, rescue.
	Downed = {
		BleedOutSeconds = 30,
		ReviveSeconds = 4,
		ReviveHP = 30,
		ReviveArmor = 0,
		ExecuteSeconds = 2,
		AgentTagSeconds = 90,
		Rescue = {
			Cost = 150,
			TagPickupSeconds = 1,
			CacheSeconds = 3,
			HP = 100,
			Plates = 1,
			AbilityCooldownMult = 0.5,
			MaxPerPlayer = 1,
		},
	},

	-- Spec 17: funds, pickups, shop.
	Economy = {
		StartFunds = 100,
		FundsPickup = { Min = 25, Max = 75 },
		FundsForDowning = 50,
		FundsForElimination = 25,
		FundsForCameraHack = 10,
		MedKitHP = 30,
		PickupRespawnSeconds = 60,
		PickupGlintRange = 20,
		-- Percent chance per PickupSpawn when it picks what to hold.
		PickupWeights = { ArmorPlate = 35, AmmoBox = 30, Funds = 25, MedKit = 10 },
		Shop = {
			PurchaseSeconds = 2,
			Prices = {
				ArmorPlate = 50,
				AmmoRefill = 40,
				HealToFull = 75,
				GadgetCharge = 75,
				AbilityCooldownReset = 100,
				RescueTeammate = 150,
				SecurityKeycard = 60,
			},
			SecurityKeycardUses = 3,
			-- SPEC-QUESTION: "higher-tier caches are 20% cheaper". Applied to caches in tier 1 and above.
			HigherTierDiscount = 0.2,
			HigherTierMinTier = 1,
		},
	},

	-- Spec 18: security systems.
	Security = {
		Camera = {
			SweepDegrees = 90,
			SweepSeconds = 6,
			ConeDegrees = 60,
			Range = 50,
			LockOnSeconds = 1.5,
			AlertGuards = 2,
			HackSeconds = 2,
			HackRange = 6,
			HackDisabledSeconds = 30,
			HackImmuneSeconds = 30,
			DestroyedSeconds = 60,
		},
		CameraRoom = { Feeds = 4, DisableAllSeconds = 20, CooldownSeconds = 120, HoldSeconds = 5 },
		LaserGrid = { FuseBoxSeconds = 3, DisabledSeconds = 30, AlarmRaise = 1 },
		KeycardDoor = { OpenSeconds = 4, LockpickSeconds = 4 },
		Guard = {
			MaxHP = 50,
			Damage = 8,
			FireIntervalSeconds = 0.8,
			NearAccuracy = 0.6,
			NearAccuracyStuds = 15,
			FarAccuracy = 0.2,
			FarAccuracyStuds = 40,
			EngageFiringRadius = 30, -- an agent firing within this distance gets engaged
			ChaseLimitStuds = 40,
			RespawnSeconds = 60,
			SuspicionImmuneBelow = 100, -- never fires at disguised agents with suspicion under this
		},
		Alarm = {
			MaxLevel = 3,
			DecayIntervalSeconds = 45,
			LockdownSeconds = 20,
			AlertWalkSpeed = 14,
			AlertDetectionMult = 1.2,
			HeightenedExtraGuards = 2,
			LockdownDoorSealSeconds = 20,
			LockdownCameraSweepMult = 1.5,
		},
	},

	-- Spec 20: scoring and progression.
	Progression = {
		XP = {
			MatchPlayed = 100,
			Intel = 25,
			VaultHackParticipation = 50,
			VaultHackMinSeconds = 10,
			PackagePickedUp = 50,
			PackageCarriedPer10s = 10,
			EnemyDowned = 30,
			EnemyEliminated = 20,
			TeammateRevived = 30,
			TeammateRescued = 50,
			ExtractionWin = 500,
			SurvivedToEnd = 50,
		},
		Level = { BaseXP = 500, XPPerLevel = 100, XPCap = 3000 },
		CreditsPerLevel = 250,
		CosmeticEveryLevels = 5,
		WinCredits = 200,
		DailyFirstWinCredits = 300,
		AgentUnlockCredits = 2500,
		SaveIntervalSeconds = 120,
	},

	-- Spec 21: HUD and UI.
	UI = {
		PhaseBannerSeconds = 3,
		TimerWarningSeconds = 60,
		FovMin = 70,
		FovMax = 100,
		MaxPingsPerPlayer = 3,
		SuspectPingSeconds = 8,
		-- STYLE_QUESTIONS D2: a minimal HUD in a bold, pixel-style font. These are the first pieces of it (Step 6).
		Font = Enum.Font.Arcade,
		TextSize = 18,
		TextColor = Color3.fromRGB(240, 240, 245),
		DimTextColor = Color3.fromRGB(150, 150, 160),
		ToastSeconds = 2.5,
		CrosshairPixels = 4, -- the centre dot
		ScanRingSegments = 32,
		ScanRingRadius = 30, -- pixels
		ScanRingColor = Color3.fromRGB(240, 240, 245),
		ScanRingDimColor = Color3.fromRGB(70, 70, 80),
		BlendWheelRadius = 150, -- pixels
		BlendWheelDeadZone = 0.3, -- fraction of the radius the cursor must leave before a slice is chosen
		BlendWheelDisabledColor = Color3.fromRGB(90, 90, 98),
		-- Cover HUD (Step 7). Debug-style for now; the real HUD comes in Step 19.
		CoverColors = {
			Covered = Color3.fromRGB(90, 200, 120),
			Suspicious = Color3.fromRGB(235, 200, 70),
			Exposed = Color3.fromRGB(235, 70, 70),
		},
		WarningColor = Color3.fromRGB(245, 150, 40), -- the restricted-area warning
		GlowPixels = 90, -- how far in from the screen edge an edge glow reaches
		ExposedFlashSeconds = 0.5,
		ExposedTextSeconds = 2,
		ExposedVignetteSeconds = 3,
		ExposedFlashTransparency = 0.5, -- the full-screen flash when you are exposed
		PingFlashTransparency = 0.85, -- the fainter flash when an enemy within range is exposed
		SenseGlowTransparency = 0.85, -- the very faint edge glow for an exposed enemy close by (STEP7 G2)
		SenseLookCosine = 0.85, -- looking within about 30 degrees of someone counts as looking at them
		MeterWidthPixels = 220,
		MeterHeightPixels = 8,
	},

	-- Spec 24: default keys. Rebinding comes with the settings menu.
	Controls = {
		Scan = Enum.KeyCode.F,
		ScanPad = Enum.KeyCode.DPadUp,
		Disguise = Enum.KeyCode.G,
		DisguisePad = Enum.KeyCode.DPadDown,
		Blend = Enum.KeyCode.B,
		BlendPad = Enum.KeyCode.DPadLeft,
		Sprint = Enum.KeyCode.LeftShift,
		Crouch = Enum.KeyCode.C, -- held; a toggle option arrives with the settings menu in Step 19
		Fire = Enum.UserInputType.MouseButton1, -- spec 24; STEP8 B1: it draws and fires in one
		FirePad = Enum.KeyCode.ButtonR2,
		Aim = Enum.UserInputType.MouseButton2,
		AimPad = Enum.KeyCode.ButtonL2,
		Reload = Enum.KeyCode.R,
		ReloadPad = Enum.KeyCode.ButtonX,
		Melee = Enum.KeyCode.V, -- tap to strike; from behind, hold to take down (spec 13.4)
		MeleePad = Enum.KeyCode.ButtonR3,
	},

	-- Spec 23: audio radii in studs.
	Audio = {
		ExposedStingRadius = 60,
		DefaultWeaponRadius = 120,
		SuppressedWeaponRadius = 25,
		LastSecondsTicking = 60,
	},

	-- Spec 8.2: players and NPCs share one rig, so their size ranges must match.
	-- SPEC-QUESTION: the spec says "identical scale ranges" but gives no numbers. Every outfit scales 5% either way.
	Rig = {
		ScaleMin = 0.95,
		ScaleMax = 1.05,
		-- Spec 8.2: players and NPCs share one collision group. NPCs have an anchored root, so if characters
		-- collided with each other a shove would move a player but not an NPC, which is a tell. Characters pass
		-- through each other instead, and still collide with the map.
		-- SPEC-QUESTION: the spec says "same collision group" but not whether the group collides with itself.
		CollisionGroup = "Characters",
		CharactersCollideWithEachOther = false,
	},

	-- Ziplines, vents and the gondola (BUILD_ORDER Step 7B pass 2b). Using any of them breaks Cover (spec 7.2).
	Traversal = {
		Zipline = {
			Speed = 45, -- studs per second down the cable
			HangStuds = 3, -- how far below the cable a rider's root hangs
			PromptDistance = 8,
			PromptHoldSeconds = 0.3,
			MountHeight = 3, -- the prompt sits this far up the mast, at a standing rider's height
		},
		Vent = {
			CheckHz = 5, -- how often VentService looks for players inside a duct
		},
		Gondola = {
			CrossSeconds = 8, -- one crossing, either way
			RiderHeight = 8, -- studs above the floor that still count as riding
			PromptDistance = 10,
			PromptHoldSeconds = 0.3, -- a short hold, so nobody sends it off by accident
		},
	},

	-- Graphics quality (BUILD_ORDER Step 7B): scenery detail for weaker machines, applied on each client. Auto follows the
	-- Roblox graphics slider; a player can override it. Only scenery changes: the map, NPCs and players are the same.
	Graphics = {
		-- The Roblox graphics level (1 to 10) at which Auto moves up to Medium and to High. Roblox's own Automatic counts
		-- as High.
		AutoMediumFrom = 4,
		AutoHighFrom = 7,
		CycleKey = Enum.KeyCode.F7, -- cycles Auto, Low, Medium, High until the Step 19 settings menu
		NoticeSeconds = 2, -- how long the "Graphics: ..." note stays on screen after a change
		Levels = {
			High = {
				WindowBands = { near = true, mid = true, far = true }, -- city towers that keep their window textures
				RoofDetail = true, -- roof plant, water tanks, masts and spires
				LightEvery = 1, -- keep one ceiling light in this many
				Shadows = true,
				Bloom = true,
				HazeScale = 1, -- times the atmosphere's density and haze
				MergeVoid = false, -- keep only the top and bottom void haze layers
			},
			Medium = {
				WindowBands = { near = true, mid = true },
				RoofDetail = true,
				LightEvery = 2,
				Shadows = true,
				Bloom = true,
				HazeScale = 1,
				MergeVoid = false,
			},
			Low = {
				WindowBands = { near = true },
				RoofDetail = false,
				LightEvery = 3,
				Shadows = false,
				Bloom = false,
				HazeScale = 0.5,
				MergeVoid = true,
			},
		},
	},

	-- Temporary development switches. Turn off before release.
	Debug = {
		PrintZoneChanges = true, -- ZoneService prints a line whenever a player's zone tier changes
		PrintNpcCost = true, -- NPCService and NPCController print their average per-update cost every few seconds
		CostReportSeconds = 10,
		PrintShots = false, -- enable temporarily when diagnosing FireRequest validation
		PrintEvents = true, -- cover, guards and doors print a line when they act (exposures, investigations, door holds)
		AutoRespawn = true, -- RigService respawns a dead player (replaced by the match flow in Step 10)
		AutoRespawnSeconds = 3,
	},

	-- Spec 25.6: client -> server remotes are rate-limited. Overrides are by remote name.
	Network = {
		DefaultRateLimit = { PerSecond = 20, Burst = 20 },
		RateLimits = {
			-- Fastest weapon fires 900 rpm (15/s); 30/s leaves room for jitter. The server also checks fire rate itself.
			FireRequest = { PerSecond = 30, Burst = 30 },
		},
	},
}

return DeepFreeze(GameConfig)
