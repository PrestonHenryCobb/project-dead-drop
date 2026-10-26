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
	-- Ticket gala-art-direction: numerical art targets; exact PBR maps are installed in Studio.
	Art = {
		Materials = {
			Ivory = {
				Color = Color3.fromHex("EFE8DA"),
				Base = Enum.Material.SmoothPlastic,
				Roughness = 0.78,
				Metalness = 0,
			},
			Walnut = {
				Color = Color3.fromHex("2A1B15"),
				Base = Enum.Material.SmoothPlastic,
				Roughness = 0.42,
				Metalness = 0,
			},
			Brass = { Color = Color3.fromHex("C89D54"), Base = Enum.Material.Metal, Roughness = 0.22, Metalness = 0.92 },
			Steel = {
				Color = Color3.fromHex("1E242B"),
				Base = Enum.Material.SmoothPlastic,
				Roughness = 0.72,
				Metalness = 0.8,
			},
			Velvet = {
				Color = Color3.fromHex("581825"),
				Base = Enum.Material.SmoothPlastic,
				Roughness = 0.9,
				Metalness = 0,
			},
			Suit = { Color = Color3.new(1, 1, 1), Base = Enum.Material.SmoothPlastic, Roughness = 0.82, Metalness = 0 },
		},
		Emerald = Color3.fromHex("12382F"),
		Glass = {
			Color = Color3.fromHex("DCE6E8"),
			Transparency = 0.35,
			PatternStrokePixels = 3,
			PatternTransparency = 0.35,
			PatternLightInfluence = 0.65,
		},
		-- Ticket gala-sculptures: baked once in Studio; no runtime CSG or altered hitboxes.
		Sculptures = {
			AssetFolder = "GalaArtAssets",
			ChandelierScale = 0.85,
			ChandelierDrop = 1.5,
			SeatingInset = 9,
			SeatingLift = 1.65,
		},
		MaterialTileStuds = 16,
		ClearanceCyan = Color3.fromHex("2CE8F5"),
		ClearanceStripPixels = 5,
		BadgeSize = Vector3.new(0.16, 0.32, 0.06),
		BadgeOffset = CFrame.new(0.55, 0.3, -0.16),
		LapelAngleDegrees = 18,
		LapelWidth = 0.26,
		PanelHeightStuds = 6,
		PanelDepthStuds = 0.08,
		LampRimSize = Vector3.new(3.5, 0.18, 3.5),
		LampRimLift = 0.22,
		ImpactPoolSize = 16,
		ImpactSpokes = 4,
		ImpactLength = 0.4,
		ImpactWidth = 0.035,
		ImpactSoundGap = 0.08,
		Lighting = {
			-- relayout-1 (owner, 2026-10-25): a deep sunset, not midnight. The room fill comes from ambient light and the
			-- sun low on the horizon; the lamps are mood lights, soft and warm, not the main light.
			ClockTime = 17.9,
			Ambient = Color3.fromHex("56404C"),
			OutdoorAmbient = Color3.fromHex("8A5A62"),
			LowAmbient = Color3.fromHex("6A5560"),
			LowOutdoorAmbient = Color3.fromHex("8C6A70"),
			Top = Color3.fromHex("FFB27A"),
			AtmosphereColor = Color3.fromRGB(226, 120, 84),
			AtmosphereDecay = Color3.fromRGB(96, 44, 78),
			AtmosphereDensity = 0.3,
			AtmosphereHaze = 0.9,
			Key = Color3.fromRGB(255, 160, 100), -- a warm mood-light amber
			Brightness = 2.6,
			Exposure = 0.3,
			BloomIntensity = 0.35,
			BloomThreshold = 1.8,
			Contrast = 0.12,
			Saturation = 0.05,
			Tint = Color3.fromHex("FFE9DA"),
			LampBrightness = 0.7,
			LampRange = 38,
		},
		-- SPEC-QUESTION: initial surface/lighting tuning for unspecified steel, velvet and suit roughness; review in Studio.
	},
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

	-- Ticket menu-phase0: agent mastery (SPEC_CHANGES 2026-10-25: levels 1 to 10 over about ten matches with an agent).
	Mastery = {
		MaxLevel = 10,
		-- The mastery level that opens each Hardware slot, W1 to W3. IDEAS brief Q8: the second item after about two matches.
		-- SPEC-QUESTION: W3 at level 6 is from the menu handoff; the decided pace only says "everything in about ten matches".
		HardwareUnlockLevels = { 1, 3, 6 },
	},

	-- Ticket menu-phase0: first launch (META_DRAFT, SPEC_CHANGES 15.9/20): one free agent from each class.
	Meta = {
		StarterAgentsPerClass = 1,
	},

	-- Ticket menu-phase0: the menu's look (client/Menu/MenuTheme.luau builds every shared component from these).
	-- Dark charcoal surfaces, ivory text, emerald for the main action, brass trim, burgundy for locked/danger and a cyan
	-- controller focus ring. Sizes are pixels at the 1280 x 720 reference (GameConfig.UI.PanelScale).
	Menu = {
		Colors = {
			Canvas = Color3.fromHex("0E1014"),
			Surface = Color3.fromHex("161920"),
			SurfaceRaised = Color3.fromHex("1F242D"),
			InfoPanel = Color3.fromHex("12151C"),
			Walnut = Color3.fromHex("261914"),
			Text = Color3.fromHex("F5F0E6"),
			TextDim = Color3.fromHex("B8B0A0"),
			TextOnBright = Color3.fromHex("14161A"),
			Emerald = Color3.fromHex("149A74"),
			EmeraldBright = Color3.fromHex("22D39F"),
			EmeraldDeep = Color3.fromHex("0B3B2D"),
			Slate = Color3.fromHex("272D38"), -- secondary button fill
			Brass = Color3.fromHex("D4A856"),
			BrassBright = Color3.fromHex("F3C978"),
			Burgundy = Color3.fromHex("7A1C30"),
			BurgundyBright = Color3.fromHex("B82947"),
			Focus = Color3.fromHex("38E8FC"),
			Border = Color3.fromHex("3A4150"),
		},
		Fonts = {
			Display = Enum.Font.Antique, -- short section headers only
			Bold = Enum.Font.GothamBold, -- buttons, tabs, titles
			Body = Enum.Font.GothamMedium,
			Mono = Enum.Font.RobotoMono, -- timers, stats, key hints
		},
		TextSizes = { Display = 28, Title = 20, Button = 17, Body = 15, Small = 13, Chip = 12 },
		SurfaceTransparency = 0.1,
		InfoPanelTransparency = 0.12,
		CornerPixels = 4,
		StrokePixels = 1,
		TrimPixels = 1.5,
		AccentBarPixels = 3,
		FocusPixels = 2,
		PaddingPixels = 12,
		PrimaryHeightPixels = 64,
		SecondaryHeightPixels = 46,
		ChipHeightPixels = 22,
		ChipPaddingPixels = 8,
		PressScale = 0.97,
		DisabledTransparency = 0.55,
		HoverSeconds = 0.16,
		ScreenFadeSeconds = 0.22,
		CameraPanSeconds = 0.55,
		-- Ticket menu-shell: the frame every screen sits in, and the two lobby screens' columns.
		HeaderPixels = 68,
		FooterPixels = 44,
		TabWidthPixels = 104, -- six tabs and two bumpers must fit between the title and the balances at 1280 wide
		BumperWidthPixels = 40,
		TabGapPixels = 4,
		GapPixels = 12,
		LeftRailPixels = 420,
		RightRailPixels = 340,
		RosterCardPixels = 92,
		DisplayOrder = 50,
		MinScale = 0.5, -- the menu shrinks below the 1280 x 720 reference on smaller windows, down to this
		ProfileAttempts = 5, -- asks for the profile this many times on join before giving up
		ProfileRetrySeconds = 1,
		DeployRetrySeconds = 3, -- Deploy is offered again if agent select has not started by then
		-- The 3D stage behind the menu: a small walnut-and-brass mezzanine built on the client only, far from the map.
		Stage = {
			Origin = Vector3.new(0, 1600, 2600),
			RoomSize = Vector3.new(44, 22, 34),
			Walnut = Color3.fromHex("3B2418"),
			Floor = Color3.fromHex("D9D2C3"),
			Carpet = Color3.fromHex("5A1626"),
			Brass = Color3.fromHex("C9A04F"),
			LampColor = Color3.fromHex("FFD9A0"),
			LampBrightness = 0.6, -- the map's Future lighting and bloom wash the room out above about 1
			LampRange = 20,
			-- Shadow-casting lights are the stage's one real cost under Future lighting (about 13 fps and a long first-frame
			-- hitch measured with five of them); the room is small, so the menu goes without.
			LampShadows = false,
			RimColor = Color3.fromHex("38E8FC"),
			RimBrightness = 0.5,
			RigTurnDegrees = -18, -- the operative stands angled toward the camera
			FieldOfView = 45,
			DefaultFieldOfView = 70, -- what the game camera returns to after deploy (Roblox's default)
			-- Camera framings, as an eye offset and a look-at offset from the operative's feet.
			Cameras = {
				Play = { Eye = Vector3.new(5.5, 4.4, -16), Focus = Vector3.new(4.2, 3, 0) }, -- operative right of centre
				Agents = { Eye = Vector3.new(0, 3.2, -17), Focus = Vector3.new(0, 0.6, 0) }, -- the whole body, above the mastery panel
				PreDeploy = { Eye = Vector3.new(0.4, 3.8, -13), Focus = Vector3.new(0.4, 3.2, 0) },
			},
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
			[4] = Color3.fromRGB(150, 28, 52), -- Tier 4, The Sanctum (relayout-1): deep crimson; its NPCs wear red and gold
		},
		VaultColor = Color3.fromRGB(205, 45, 45), -- vault doors, vault-wing trim and the vault strongroom lights
		-- How many pips a tier door's handles carry (Public doors have plain handles).
		TierPips = { [0] = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4 },
	},

	-- Gala re-layout (relayout-1, docs/MAP_PLAN_RELAYOUT.md): what hacking a door costs in intel. By clearance tier, then by
	-- the special doors. An Executive disguise or a Tier 4 keycard opens a door free; the cost is for anyone else.
	Doors = {
		HackCost = {
			[1] = 3, -- Staff
			[2] = 6, -- Security
			[3] = 8, -- Executive
			VaultCore = 8, -- the door into each vault core (an Executive door)
			Tier4Terrace = 6, -- the Sanctum terraces' doors to the foyer
			Tier4StairHead = 8, -- the door at the head of the Executive stair
			Tier4ElevatorArrival = 8, -- the Sanctum elevator's arrival
			PackageDoor = 10, -- the Package room's front door (the back door takes the keycard only)
		},
		-- The Tier 4 keycard (single use) is printed at one of the printer spots; none is marked.
		KeycardPrinter = { Cost = 10, Seconds = 20, ActiveSpots = 1 },
		Elevators = { MinTier = 1 }, -- Staff and above ride the glass elevators free; a Guest must hack the door or tailgate
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
		MinVaultSpacing = 100, -- relayout-1: the five vault terminals are at least this far apart
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
		RoleMaxTier = { Guest = 0, Staff = 1, Security = 2, Executive = 3, Warden = 4, Curator = 4 },
		-- The two Tier 4 NPCs (SPEC_CHANGES 2026-10-25): one each, on top of RoleCounts. Each stays in its Rooms (a room and
		-- the rooms inside it) and rides only the glass elevators that are not locked, if Elevators is set.
		Tier4 = {
			Warden = { Rooms = { "s_foyer", "s_stairhead", "s_ter_w", "s_ter_e", "r_summit" }, Elevators = false },
			Curator = { Rooms = { "t_great", "t_gallery", "r_summit", "r_deck" }, Elevators = true },
			-- Downing one raises the alarm by this much (the alarm itself is a later step) and exposes the shooter.
			DownedAlarmRaise = 2,
		},
		-- Walk speed per role, in studs/s. A disguised agent's speed is capped to their disguise's role (spec 6.8).
		-- SPEC-QUESTION: the spec gives Guest 10 and Staff 12 only. Security and Executive use 10 until it says more.
		WalkSpeed = { Guest = 10, Staff = 12, Security = 10, Executive = 10, Warden = 10, Curator = 10 },
		MinOutfitsPerRole = 20,
		MaxHP = 50,
		ServerTickHz = 10, -- 25.4: server moves NPC roots along paths at 10 Hz, clients interpolate
		ActivitySeconds = { Min = 6, Max = 20 },
		MaxYawRate = 270, -- degrees per second
		SeparationStuds = 2.5,
		DoorCloseDelay = 3,
		GlanceInterval = { Min = 4, Max = 10 }, -- 8.1: random head glances
		GlanceDegrees = 40,
		-- Ticket crowd-readability: ordinary walking only; panic/investigation keep direct routes.
		WalkVariation = {
			OffsetMin = 0.35,
			OffsetMax = 0.8,
			WaveStuds = { Min = 18, Max = 30 },
			MaxRiseStuds = 0.08,
			StraightDot = 0.98,
			SpeedMin = 0.9,
			SpeedMax = 1,
		},
		-- Shared client presentation for all upright rigs, without identity/team information.
		SocialGlance = {
			ScanSeconds = 0.3,
			NearStuds = 6,
			HeightStuds = 3,
			RenderStuds = 90,
			FrontDot = -0.2,
			UprightDot = 0.7,
			Cooldown = { Min = 4, Max = 8 },
		},
		CorpseSeconds = 30, -- a player's eliminated body lies this long before it fades (DownedService)
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
		Door = {
			OpenStuds = 8,
			OpenForNpcs = true,
			PlayerCheckSeconds = 0.1,
			-- R3-doors: each doorway's inside is the side whose zone volume, this far out and this high, has the higher tier.
			SideProbeStuds = 3,
			SideProbeHeight = 2,
		},
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
		-- How far above and below a point to look for floor when a body steps off the stored routes (R1-ground).
		Graph = {
			SupportWindow = { Above = 3, Below = 2 },
		},
		-- relayout-2: the authored routes Build.luau stores on the NPC nodes (replacing PathfindingService discovery).
		Routes = {
			ReachStuds = 80, -- a node walks to its nearest neighbours up to this far away (more than the widest node spacing)
			Neighbors = 7, -- ... at most this many
			FloorTolerance = 0.8, -- studs: floor under a stride may differ this much from the line between the two nodes
			StairTolerance = 1.3, -- studs: a stair route may differ this much from the tread under it
			SampleStuds = 2, -- a route has a point at least this often
			BodyRadius = 0.8, -- the walk is checked for walls and props this far either side
			ChestHeight = 2.5,
			Bends = { 5, 10, 16 }, -- a doorway's walk blocked by a prop goes round a corner this far (studs) off its middle
			DoorLaneStuds = 12, -- a doorway is one lane for each this much width
			JoinStuds = 140, -- a separate group of nodes is joined to the nearest outside node within this walk
			PocketCells = 80, -- a region of fewer cells than this (a gap between a wall and a table) is a pocket, not a place to stand
			GridStuds = 2, -- the cells a floor is cut into to find where a body fits
			BodyHeight = 3.6, -- the volume that must be free above a cell, from BodyLift up
			BodyLift = 1.2,
			CellFloorTolerance = 0.3,
			ProbeUp = 2.5,
			ProbeDown = 2.5,
			LaneStuds = 3.5, -- one NPC's width in a queue
			HeadwayStuds = 4, -- NPCs keep this far apart in a lane
			WalkWidthStuds = 14, -- how wide an ordinary walk between nodes is taken to be
			DoorNodeStuds = 9, -- a doorway's nodes are found this close to the point beside the door, in that room
			CabCapacity = 4, -- NPCs one elevator carries at once
		},
		MinTripStuds = 30, -- an NPC's next destination is at least this far away
		TripPreferStuds = 120, -- destinations this far (walking) are half as likely as near ones; keeps long trips rare
		ArrivalSpread = 3, -- NPCs stand within this many studs of a node, so they don't stack on one point
		ArrivalSpreadTries = 4, -- R2-tiers: random spots tried (on floor, in tier, wall-free) before using the node itself
		NodeCapacity = 2, -- NPCs that may stand at or head to one node at once (a pair chatting at a spot)
		-- relayout-2: how many NPCs the doors, stairs and lanes take. Each authored link carries its capacity (Build.luau,
		-- from its width); a trip steers round a busy one and is put off while one on its route is overloaded.
		Capacity = {
			CongestionWeight = 1.5, -- a link at capacity costs this much more to walk (times its fill, up to twice)
			OverloadFactor = 1.5, -- a trip waits while a link on its route holds this many times its capacity
			RetrySeconds = { Min = 1, Max = 3 }, -- ... and tries again after this long
			HoldMarginSeconds = 1, -- a trip keeps its room on a link this long after it should have passed
		},
		-- relayout-2: crowd clusters (Layout.clusters): authored groups at the bar, the dance floor, the tables, the roof party.
		Crowd = {
			ClusterWeight = 5, -- how much likelier a cluster is as a destination than an ordinary node
			ClusterRadiusStuds = 9, -- NPCs at a cluster stand within this of its middle, facing it
		},
		-- relayout-2: who the server moves how often. By distance to the nearest player: near every tick, mid every
		-- MidEvery-th, far every FarEvery-th; beyond FarStuds an NPC sleeps (nothing moves it until a player comes within
		-- FarStuds, or something happens to it).
		Update = {
			NearStuds = 60,
			MidStuds = 110,
			FarStuds = 150,
			MidEvery = 2,
			FarEvery = 4,
			PlayerCheckSeconds = 0.5, -- how often the nearest player to each NPC is looked for
		},
		-- relayout-2 (owner, 2026-10-25): every downed or executed NPC stands up slowly this long after it went down and
		-- returns to its routine; nothing replaces it. A body that stands up is always an NPC (a player's body fades).
		WakeUp = { Seconds = 60, RiseSeconds = 3.5 },
		-- relayout-2: the glass elevators. Staff and above ride them; an NPC waits beside the door for a cab.
		Elevator = {
			SpeedStuds = 16,
			DwellSeconds = 3, -- doors stay open this long at each stop
			DoorSeconds = 0.4,
			WaitGiveUpSeconds = 40, -- an NPC waits this long for a cab, then picks another trip
			WaitCostStuds = 60, -- how much walking an elevator wait is worth when a trip is planned
			RiderSpreadStuds = 2.2, -- riders stand this far from the cab's middle
		},
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
		-- The puff when a disguise is stripped on exposure (spec 7.2). A disguise change has no puff (brief Q6).
		DisguisePuffParticles = 20,
		DisguisePuffSeconds = 1.5,
		-- Brief Q6 (SPEC_CHANGES 6.4): where someone changes disguise, rival agents see a marker for longer the higher
		-- the tier put on. The server tells a rival only once they come within SwapMarkerRange, so nobody learns of
		-- swaps across the map. SPEC-QUESTION: the range was left to tune in play; 60 matches the exposed ping.
		SwapMarkerSeconds = { [0] = 5, [1] = 10, [2] = 15, [3] = 20 }, -- by tier: Guest, Staff, Security, Executive
		SwapMarkerRange = 60,
		SwapMarkerCheckHz = 4,
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

	-- Step 8B.5 (SPEC_CHANGES 6.8 / 8.1): floatier movement. Lower gravity with the jump height kept, so a jump lasts
	-- longer without reaching anything new; smooth starts and stops on the ground for players and NPCs alike, from the
	-- same two numbers, so easing is never a tell.
	Movement = {
		Gravity = 150,
		JumpHeight = 6.4, -- studs; what the old default jump reached, so no new ledge comes in reach
		AccelSeconds = 0.18, -- from standing to full speed
		DecelSeconds = 0.15, -- from full speed to standing
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
		-- Ticket 8B.4: fire/aim, reload and melee share the same input precedence.
		InputPriority = 3000,
		-- Ticket 8.5c-pdw: shared default aim response; exceptional handling stays in WeaponDefs.Visuals.
		Handling = { AimBlendRate = 14 },
		-- Ticket 8B.8: recognise the visible True Form look, never a player/agent attribute or roster.
		ThirdPersonWeapon = { ScanSeconds = 0.25, CullStuds = 140 },
		-- Ticket 8.15: cosmetic first-person arms are independent of the real avatar's movement-facing body.
		FirstPersonArms = {
			Scale = Vector3.new(0.6, 0.8, 0.6),
			ShoulderOffset = Vector3.new(0.55, -0.9, 0.35),
			ReachSlackFraction = 0.03, -- keep cosmetic elbows slightly bent while keeping hands on the gun
			MinimumSegmentStuds = 0.01,
		},
		-- Ticket 8B.3: camera-space framing and wall tuck. These affect presentation; hits remain server-authoritative.
		Presentation = {
			-- Ticket 8.16: bring geometry and grips closer together without changing their screen projection.
			ViewDepthScale = 0.65,
			ScreenMarginFraction = 0.12,
			NearDepthStuds = 0.15,
			WallReachStuds = 3.5,
			WallRayRadiusStuds = 0.25,
			FullTuckStuds = 0.65,
			-- Ticket 8.15: wall tuck blends to ViewModel.Poses.Tucked, across the body, rather than high-ready.
			AttackBlockTuckFraction = 0.02, -- both collision-driven and visibly recovering tuck block every attack
			TuckBlendSpeed = 20,
			WallDepthFraction = 0.8, -- compress the local camera model into available depth while preserving its projection
		},
		MaxHP = 100,
		PlateHP = 25,
		MaxPlates = 3,
		StartPlates = 1,
		SoloStartPlates = 2,
		HeadshotMult = 1.5,
		MarksmanHeadshotMult = 2,
		FallSafeStuds = 30,
		FallDamagePerStud = 2,
		-- Ticket 8.1: a player is on the ground when the map is within this many studs below their feet (falls are
		-- measured by height on the server, from the highest point since they were last on the ground).
		GroundProbeSlackStuds = 1.5,
		-- Step 9: a height change bigger than this between two checks (one frame) is a teleport, not a fall.
		TeleportStuds = 30,
		SelfExplosionMult = 0.5,
		-- 13.3: server validation of FireRequest.
		LagCompSeconds = 0.25,
		LagCompHistoryHz = 20,
		FireRateToleranceSeconds = 0.04,
		FireOriginToleranceStuds = 4,
		Melee = {
			-- Ticket 8.22: default charge is server-timed; partial holds retain tap damage until fully charged.
			FullChargeDamage = 50,
			FullChargeSeconds = 0.75,
			DirectionEpsilonStuds = 0.001,
			Damage = 35,
			CooldownSeconds = 0.8,
			Range = 4,
			SwingConeDegrees = 90,
			ReachSlackStuds = 1.5,
			HeightStuds = 3,
		},
		Takedown = {
			-- Ticket 8.22: independent of ordinary melee reach/slack, per final owner answer.
			RangeStuds = 6.5,
			ConeDegrees = 90,
			HoldSeconds = 1.2,
			Damage = 90,
			BreakDistance = 4,
			CheckSeconds = 0.1,
		},
		-- Weapons (STEP8_QUESTIONS). The weapon every player carries until agent select exists (Step 10).
		DefaultWeapon = "GuiseSMG",
		MaxShotStuds = 400, -- the longest ray the server casts for a shot
		FireDirectionTolerance = 0.02, -- a FireRequest direction must be a unit vector within this
		PlayerRenderDelay = 0.1, -- how far behind the server a client sees other players; the rewind adds it (NPCs: NPC.InterpolationDelay)
		GunfireReactSeconds = 0.5, -- NPCs react to a shooter's gunfire at most this often
		-- Ticket 8.5: the server's part of the weapons' unique effects (fields in WeaponDefs, see Types.WeaponDef).
		-- Held fire on a spin-up weapon keeps spinning while shots come no more than this many times its slowest gap.
		SpinUpGapMult = 1.5,
		-- Reticle's DMR (STEP8 unique effects): while she aims, rival agents she can see within RangeStuds get a glint at
		-- her scope, refreshed CheckHz times a second; each lasts Seconds unless refreshed.
		-- SPEC-QUESTION: "enemies she is scoping" would need her aim direction from the client; the server instead shows
		-- the glint to every rival with a clear line to her, which needs nothing the client could misreport.
		ScopeGlint = { RangeStuds = 200, CheckHz = 4, Seconds = 0.4 },
		MovingSpeedStuds = 2, -- a body faster than this counts as moving for spread
		-- Hit boxes the server tests rewound shots against: a vertical cylinder from the feet to the head, and the head.
		-- Step 8B.7: the body radius narrows with the slimmer bodies (from 1.25), still slightly generous.
		Hitbox = { BodyRadius = 1.0, HeadRadiusScale = 0.6, HeadMinRadius = 0.5, CullStuds = 4.5 },
		ViolationLogEvery = 10, -- the server warns about a player's impossible requests this often (spec 26: log, never ban on it)
		-- Client side: what a shot, a hit and a wound look and sound like. All of it is feedback only; the server decides.
		Feedback = {
			-- Ticket 8.11: shared limits and timing for client-only pooled shot visuals.
			TracerPoolSize = 64,
			FlashPoolSize = 24,
			FlashSeconds = 0.045,
			ShotVisualMinStuds = 0.01,
			RemoteMuzzleOffset = Vector3.new(0.65, -0.65, -1.2), -- right, down, forward from the shot's head frame
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
			DamageIndicatorSeconds = 0.22,
			DamageIndicatorPixels = 90, -- distance of the marker from the centre of the screen
			DamageIndicatorColor = Color3.fromRGB(235, 60, 60),
			ImpactSound = "rbxassetid://85805517776968",
			ImpactParticles = 6,
			ImpactSeconds = 0.2,
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
		-- Ticket 8.3: keep combat vitals above the disguise badge (16 px bottom margin + 44 px height).
		Hud = {
			VitalsBottomPixels = 76, -- plate bottom is 68 px above the screen edge, leaving an 8 px gap
			-- Ticket 8.15: crossed-out reticle replaces the crosshair and disguise dot while obstructed.
			BlockedReticlePixels = 26,
			BlockedLabelGapPixels = 8,
			BlockedLabelWidthPixels = 180,
		},
		-- The first-person view model (client only): where the gun sits in each pose, in studs from the camera (+x right,
		-- -y down, -z forward) with a rotation in degrees (pitch, yaw, roll), and how fast it moves between poses.
		ViewModel = {
			Poses = {
				-- Disguised: tucked across the chest, barrel angled down (STEP8 answers).
				-- Ticket R8-pistol-pose: bring the disguised carry closer to the chest.
				Tucked = { Position = Vector3.new(0.1, -1.2, -0.9), Rotation = Vector3.new(-38, 80, 8) },
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

	-- Spec 24: Interact is held. InteractService times every hold on the server and re-checks it this often.
	Interact = {
		CheckHz = 10,
		MaxTargetLength = 64, -- longest target name a RequestInteract may carry
	},

	-- Spec 14: downed, revive, rescue.
	Downed = {
		BleedOutSeconds = 30,
		ReviveSeconds = 4,
		ReviveHP = 30,
		ReviveArmor = 0,
		ExecuteSeconds = 2,
		AgentTagSeconds = 90,
		-- Step 9: implementation values. SPEC-QUESTION: the spec gives no reach for revive or execute; 6 studs matches
		-- the Blend wheel's seat range and is close enough to need committing to it.
		InteractStuds = 6,
		InteractSlackStuds = 1.5, -- allowance for lag while the hold runs
		CrawlRequestHz = 10, -- how often a downed client sends the way it is crawling
		BodyAimDegrees = 35, -- a body this far off the crosshair can still be picked to revive or execute
		-- R4-body-animation: how bodies go down (Util/Knockdown, Defs/PoseDefs). Shared by NPCs and players.
		Knockdown = {
			FrontBackDegrees = 90, -- a hit within this cone in front (or behind) is a front (or rear) hit; the rest are sides
			MinSourceStuds = 0.5, -- a hit source closer than this to the body has no direction: the standard forward fall
			Seconds = 0.75, -- the fall itself; crawling can start after it
			RiseStuds = 1.2, -- how far a standing root sits above a lying one (the fall starts from standing height)
			SideLiftStuds = 0.4, -- lying on a side holds the body this much higher than lying flat
			CrawlCycleSeconds = 1.2, -- one full reach-and-pull of the crawl
			CollapseSeconds = 0.5, -- the settle into stillness on death
			DeadHoldSeconds = 600, -- how long the dead pose holds before its loop could repeat (far beyond any corpse)
		},
		Rescue = {
			-- Ticket 9d: owner-approved initial Intel price, replacing the removed Funds price.
			Cost = 10,
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
		-- Ticket map HUD themes: one layout/behavior, palette-only skins. Select this alongside a map's config.
		HudThemeId = "Gala",
		HudThemes = {
			Gala = {
				PanelColor = Color3.fromHex("F4EFE6"),
				PanelTransparency = 0.08,
				TextColor = Color3.fromHex("1A1918"),
				DimTextColor = Color3.fromRGB(84, 78, 67),
				Font = Enum.Font.GothamMedium,
				BorderColor = Color3.fromHex("B88E44"),
				BorderTransparency = 0,
				AccentColor = Color3.fromHex("B88E44"),
				CornerPixels = 3,
			},
		},
		-- Ticket 19-hud-scale: scale panel contents/margins together; reticles retain viewport-based aiming math.
		PanelScale = {
			ReferenceWidthPixels = 1280,
			ReferenceHeightPixels = 720,
			Minimum = 1,
			Maximum = 2,
		},
		-- Ticket HUD refresh: code-drawn graphics need no uploaded images; numbers remain authoritative.
		GraphicHud = {
			-- Ticket gala-art-direction: skins can set legible ink and typography independently of world markers.
			TextColor = Color3.fromRGB(240, 240, 245),
			DimTextColor = Color3.fromRGB(150, 150, 160),
			Font = Enum.Font.GothamMedium,
			AccentColor = Color3.fromRGB(108, 154, 165),
			AccentWidthFraction = 0.24,
			AccentThicknessPixels = 2,
			PanelColor = Color3.fromRGB(14, 22, 32),
			PanelTransparency = 0.18,
			BorderColor = Color3.fromRGB(88, 116, 133),
			BorderTransparency = 0.48,
			ShadowTransparency = 0.48,
			ShadowOffsetPixels = 4,
			CornerPixels = 8,
			StrokePixels = 1,
			IconStrokeFraction = 0.13,
			PaddingPixels = 12,
			MarginPixels = 24,
			VitalsWidthPixels = 224,
			VitalsHeightPixels = 72,
			AmmoWidthPixels = 216,
			AmmoHeightPixels = 84,
			NumberSize = 28,
			CaptionSize = 12,
			IconPixels = 20,
			MeterSettleSpeed = 12,
			DamagePulseSeconds = 0.5,
			DamagePulseTransparency = 0.08,
			ReloadBarPixels = 3,
			CoverWidthPixels = 248,
			CoverHeightPixels = 60,
			CoverBottomPixels = 14,
			ShowDiagnostics = false,
			ActionWidthPixels = 252,
			ActionHeightPixels = 58,
			ActionOffsetPixels = 112,
			DownedTopFraction = 0.68,
			DirectionEpsilonStuds = 0.001,
		},
		-- Ticket 19-traversal-warnings: presentation only; server traversal rules remain authoritative.
		TraversalWarnings = {
			CheckSeconds = 0.1,
			VentDistanceStuds = 8,
			VentFacingDot = 0.25,
			HeightPixels = 44,
		},
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
		-- Brief Q6: the disguise-swap marker rivals see (placeholder look until the art pass, Step 19).
		SwapMarkerColor = Color3.fromRGB(235, 70, 120),
		SwapMarkerSizeStuds = 1.6,
		SwapMarkerHeightStuds = 3, -- above the floor where the swap happened, about chest height
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
		ExposedTextSeconds = 2,
		-- Ticket 19-coverbreak-feedback: brief, peripheral geometry replaces full-screen exposure flashes.
		CoverBreak = {
			Seconds = 0.2,
			StartTransparency = 0.2,
			EdgeInsetFraction = 0.16,
			ArmPixels = 34,
			StrokePixels = 3,
			BannerWidthPixels = 172,
			BannerHeightPixels = 36,
		},
		SenseGlowTransparency = 0.85, -- the very faint edge glow for an exposed enemy close by (STEP7 G2)
		-- Ticket 19-agent-sense-lifecycle: fixed local highlight budget; no instances on character models.
		SenseShimmer = { PoolSize = 12, OutlineTransparency = 0.3 },
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
		-- Step 8B.5: walking is ours (MovementController), so its keys live here too. The gamepad uses the left stick.
		MoveForward = { Enum.KeyCode.W, Enum.KeyCode.Up },
		MoveBack = { Enum.KeyCode.S, Enum.KeyCode.Down },
		MoveLeft = { Enum.KeyCode.A, Enum.KeyCode.Left },
		MoveRight = { Enum.KeyCode.D, Enum.KeyCode.Right },
		Interact = Enum.KeyCode.E, -- spec 24: hold
		InteractPad = Enum.KeyCode.ButtonX, -- bound only while there is something to interact with (spec 24 note)
		Jump = Enum.KeyCode.Space,
		JumpPad = Enum.KeyCode.ButtonA,
		StickDeadzone = 0.2,
	},

	-- Spec 23: audio radii in studs.
	Audio = {
		ExposedStingRadius = 60,
		DefaultWeaponRadius = 120,
		SuppressedWeaponRadius = 25,
		LastSecondsTicking = 60,
	},

	-- Spec 8.2: players and NPCs share one rig, so their size ranges must match.
	-- Step 8B.1 (SPEC_CHANGES 8.2): taller and slimmer for everyone, the same ranges for players and NPCs, so size still
	-- tells nothing. True Form sits in the middle of each range.
	Rig = {
		HeightScaleMin = 1.05,
		HeightScaleMax = 1.15,
		WidthScaleMin = 0.8, -- width and depth share this range
		WidthScaleMax = 0.9,
		-- SPEC_CHANGES 8.2: the Warden (Tier 4) is the one exception to the ranges above; a scan copies it.
		WardenScale = { Height = 1.25, Width = 1.05, Depth = 1.05, Head = 1 },
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
		-- Ticket studio-test-loadout: runtime-gated by IsStudio on BOTH sides; no saved unlock/progression effects.
		TestLoadout = {
			AgentKey = Enum.KeyCode.F8,
			-- Ticket studio-key-conflict: F9 opens Roblox's console; F7 already cycles graphics.
			WeaponKey = Enum.KeyCode.RightBracket,
			AgentOrder = { "Guise", "Parapet", "Lattice", "Reticle", "Suture", "Feint" },
		},
		PrintZoneChanges = true, -- ZoneService prints a line whenever a player's zone tier changes
		PrintNpcCost = true, -- NPCService and NPCController print their average per-update cost every few seconds
		CostReportSeconds = 10,
		PrintShots = false, -- enable temporarily when diagnosing FireRequest validation
		PrintEvents = true, -- cover, guards and doors print a line when they act (exposures, investigations, door holds)
		AutoRespawn = true, -- RigService respawns a dead player (replaced by the match flow in Step 10)
		AutoRespawnSeconds = 3,
		-- Ticket menu-shell: open the menu on join and spawn only after agent select. false: spawn straight in, as before.
		MenuOnJoin = true,
		-- Studio only: the mastery level every agent starts at, so W2 and W3 can be tested before mastery XP exists.
		StudioMasteryLevel = 1,
		-- The mode a Studio test plays in until the lobby picks one (Step 10): a key of Modes. Teams fill in join order.
		TestMode = "Duos",
	},

	-- Spec 25.6: client -> server remotes are rate-limited. Overrides are by remote name.
	Network = {
		DefaultRateLimit = { PerSecond = 20, Burst = 20 },
		RateLimits = {
			-- Ticket studio-test-loadout: separate from gameplay input budgets.
			RequestTestLoadout = { PerSecond = 2, Burst = 4 },
			-- Fastest weapon fires 900 rpm (15/s); 30/s leaves room for jitter. The server also checks fire rate itself.
			FireRequest = { PerSecond = 30, Burst = 30 },
			RequestCrawl = { PerSecond = 15, Burst = 15 }, -- sent at Downed.CrawlRequestHz
			-- Ticket menu-phase0: menu requests are button presses; a burst covers fast tab and card switching.
			GetPlayerMetaProfile = { PerSecond = 1, Burst = 3 },
			RequestEquipLoadout = { PerSecond = 3, Burst = 6 },
			RequestClaimStarterAgent = { PerSecond = 1, Burst = 3 },
			RequestClaimDossierTier = { PerSecond = 2, Burst = 5 },
			RequestSelectActiveDossier = { PerSecond = 1, Burst = 3 },
			RequestBlackMarketPurchase = { PerSecond = 1, Burst = 2 },
			RequestMintStrikeStocks = { PerSecond = 1, Burst = 2 },
			RequestQueueMode = { PerSecond = 2, Burst = 4 },
			RequestStartPreDeploy = { PerSecond = 1, Burst = 2 },
			RequestLockInPreDeploy = { PerSecond = 3, Burst = 6 },
		},
	},
}

return DeepFreeze(GameConfig)
