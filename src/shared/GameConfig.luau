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
		BannerSeconds = 3, -- spec 2: phase banners
		TickSeconds = 0.25, -- ticket 10a: MatchService checks its timers this often
	},

	-- Tickets 10b/c: client presentation; match timing remains in Match above.
	MatchHud = {
		DisplayOrder = 60,
		PanelWidthPixels = 560,
		BriefHeightPixels = 208,
		ResultsHeightPixels = 430,
		BannerTopFraction = 0.23,
		TitleSize = 28,
		BodySize = 18,
		PaddingPixels = 20,
		TimerWidthPixels = 150,
		TimerHeightPixels = 56,
		TimerTopPixels = 16,
		WaitBottomPixels = 76,
		WaitHeightPixels = 48,
		ScoreRowPixels = 32,
		MarkerSizePixels = 18,
		MarkerHeightStuds = 3.5,
		MarkerFillTransparency = 0.88,
		MarkerOutlineTransparency = 0.15,
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
		-- Ticket 21-mastery: what a finished match gives the agent the player used (SPEC_CHANGES 2026-10-25: about ten matches
		-- to level 10, the second Hardware after about two, wins and objectives speed it up). One match is one level, so level 3
		-- comes after two matches and level 10 after nine; a win adds half a level. SPEC-QUESTION: objectives add nothing yet.
		XPPerLevel = 100,
		MatchXP = 100,
		WinBonusXP = 50,
	},

	-- Ticket menu-phase0: first launch (META_DRAFT, SPEC_CHANGES 15.9/20): one free agent from each class.
	Meta = {
		StarterAgentsPerClass = 1,
	},

	-- Ticket 21.4-chat (spec 21.4): match chat is team-only (ChatService).
	Chat = {
		ChannelWaitSeconds = 15, -- how long ChatService waits for TextChatService to create its default channel
	},

	-- Ticket 19-pings (spec 21.3): team pings. How many a player may have up (UI.MaxPingsPerPlayer) and how long a Suspect ping
	-- lasts (UI.SuspectPingSeconds) are in UI. SPEC-QUESTION: the other kinds last Seconds, which the spec does not give.
	Ping = {
		Kinds = { Look = true, Suspect = true, Intel = true, Danger = true }, -- spec 21.3
		Seconds = 8,
		RangeStuds = 400, -- how far from the player a marker may be placed
	},

	-- Ticket 19-pings-client: contextual ping input and presentation. Chords preserve the existing gadget/GPS pad buttons.
	PingHud = {
		Key = Enum.UserInputType.MouseButton3,
		DangerModifier = Enum.KeyCode.LeftAlt,
		Pad = Enum.KeyCode.DPadRight,
		DangerPad = Enum.KeyCode.ButtonR1,
		ModifierPad = Enum.KeyCode.ButtonL2,
		TouchPosition = UDim2.fromScale(0.8, 0.45),
		DangerTouchPosition = UDim2.fromScale(0.9, 0.45),
	},

	-- Ticket 19-session-settings: client preferences only. FOV limits stay in UI; saving preferences is a separate contract.
	ClientSettings = {
		Key = Enum.KeyCode.F10,
		DefaultSensitivity = 1,
		SensitivityMin = 0.25,
		SensitivityMax = 2,
		SensitivityStep = 0.25,
		FovStep = 5,
		PanelFraction = 0.85,
	},

	-- Ticket playable-flight-pad: client-only controls for existing flight. Server movement bounds stay unchanged.
	ClientFlight = {
		LookDegreesPerSecond = 150, -- SPEC-QUESTION: initial stick-look feel; tune with the owner in Studio.
		DownPad = Enum.KeyCode.ButtonB,
		BoostPad = Enum.KeyCode.ButtonL3,
		NextPad = Enum.KeyCode.ButtonR1,
		PreviousPad = Enum.KeyCode.ButtonL1,
		DronePad = Enum.KeyCode.ButtonY,
	},

	-- Ticket 19-camera-comfort: optional local feedback, off by default; reduced motion always suppresses it.
	CameraComfort = {
		Seconds = 0.2,
		DamageDegrees = 0.18,
		TakedownDegrees = 0.12,
		Oscillations = 2,
		-- SPEC-QUESTION: initial cosmetic strength/duration, to tune in Studio without changing weapon recoil.
	},

	-- Ticket 19-combat-volume: session-only volume for the existing client combat sound pools.
	ClientAudio = {
		DefaultCombatVolume = 1,
		CombatVolumeStep = 0.1,
	},

	-- Ticket 21-data (spec 20.4): the saved profile. One DataStore key per player, a session lock so two servers never
	-- hold the same profile, and a save every AutosaveSeconds, on leave and when the server closes.
	Data = {
		StoreName = "CoverStoryProfiles",
		Version = 1, -- bump when the saved shape changes; ProfileStore.reconcile must then migrate older ones
		AutosaveSeconds = 120,
		-- A lock older than this is a crashed server's and may be taken. Autosave refreshes every player's lock, so it must be
		-- well above AutosaveSeconds (three saves).
		LockStaleSeconds = 360,
		LockWaitSeconds = 25, -- how long a join waits for another server to let go before taking the lock or giving up
		LockRetrySeconds = 2,
		Retries = 5, -- DataStore calls that fail are tried this many times with the backoff below
		RetryBaseSeconds = 1,
		RetryMaxSeconds = 8,
		MaxCredits = 1000000000, -- sanity bounds applied to a loaded profile
		MaxStat = 1000000000,
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
		TextSizes = { Display = 28, Title = 20, Button = 17, Body = 17, Small = 14, Chip = 12 },
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
		-- Ticket menu-art-pass: native illustration readability and explicit scroll affordance.
		Art = { BodyTextPixels = 17, ScrollbarPixels = 8 },
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
			-- Ticket menu-art-pass: original Gala set dressing, no additional lights or shadows.
			Art = {
				Glass = Color3.fromHex("8EAFA9"),
				MarbleDark = Color3.fromHex("403B37"),
				GlassReflectance = 0.12,
				ChandelierHeight = 13,
			},
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
		-- Ticket 18a (SPEC_CHANGES): hack a shut tier door open with intel. SPEC-QUESTION: the time, the reach and how long it stays
		-- open are not specified; 3 s, 8 studs and 4 s (as a lockpicked keycard door) are used.
		HackSeconds = 3,
		HackStuds = 8,
		HackOpenSeconds = 4,
		-- The Tier 4 keycard (single use) is printed at one of the printer spots; none is marked.
		-- Gap-closing (2026-10-28): one printer is made at match start on a random spot. Holding Interact within InteractStuds for
		-- Seconds costs the team Cost intel and gives that agent a Tier 4 keycard (one at a time, single use, lost on elimination).
		-- With a card a hold on a Tier 4 door (DoorTier) or the Package back door takes UseSeconds, costs no intel and does not break
		-- Cover; the card is spent. SPEC-QUESTION: the card is spent on the first Tier 4 door it is used at; no choice to hack instead.
		KeycardPrinter = {
			Cost = 10,
			Seconds = 20,
			ActiveSpots = 1,
			Printer = {
				InteractStuds = 6,
				WallSlackStuds = 1.2,
				Size = Vector3.new(2.4, 3.4, 1.6),
				Color = Color3.fromRGB(80, 220, 235),
				DoorTier = 4,
				UseSeconds = 1,
			},
		},
		-- Staff and above ride the glass elevators free; a Guest must hack the door or tailgate. Ticket 7B-glass-elevators:
		-- a call or a hack authorizes a stop for HackValidSeconds (an NPC call for NpcCallValidSeconds); the cab doors open on arrival
		-- only for an authorized stop. A player is in the cab within CabSlackStuds of its floor and up to CabHeightStuds above it.
		-- Asking for a level makes an open cab leave within DepartSeconds. The call panel is pressed (a quiet hold of CallSeconds)
		-- within CallStuds; a hack of a stop door keeps the doors open Doors.HackOpenSeconds.
		Elevators = {
			MinTier = 1,
			HackValidSeconds = 45,
			NpcCallValidSeconds = 120,
			CabHeightStuds = 10,
			CabSlackStuds = 0.5,
			DepartSeconds = 1,
			CallStuds = 6,
			CallSeconds = 0.3,
		},
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
		-- Auto re-cover (ticket auto-recover): an Exposed player who is allowed to re-cover starts a ring, and AutoRecoverSeconds
		-- later the disguise goes back on as if they had pressed Disguise. Anything that stops re-covering cancels the ring.
		-- On unless the player turns it off (Controls.ToggleAutoRecover); AutoRecoverCheckHz is how often it is looked at.
		AutoRecoverDefault = true,
		AutoRecoverSeconds = 1.5,
		AutoRecoverCheckHz = 5,
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
		HackingGraceSeconds = 0.4, -- ticket 11a: a hold counts as hacking this long after IntelService's last check of it
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

	-- Ticket 13B-a (BUILD_ORDER 13B, owner choice "crowd-NPC bots"): rival teams that fill the lobby. A bot is a crowd NPC
	-- that walks to Intel stations and vault terminals; it does not shoot, pick up the Package or win. SPEC-QUESTION:
	-- bots live beside the Player systems, not inside them, so a bot cannot be revived, carry the Package or be a teammate.
	Bots = {
		Enabled = true,
		TargetTeams = 4, -- humans and bots together; bot teams fill up to this many (Match.MaxPlayers is never exceeded)
		MaxTier = 4, -- a bot may go anywhere: it hacks its way through doors as a player would
		TeamIdBase = 100, -- bot team ids start here, clear of the human teams
		Difficulty = "Casual", -- a key of Profiles
		ThinkHz = 2,
		WarpStuds = 60, -- a bot that walked this near a terminal (a vault core has no nodes) is placed on its dais
		ArriveStuds = 3, -- close enough to a station or terminal to work it
		ResendSeconds = 3, -- a bot that stopped short of its goal (a reaction, a busy door) is sent again after this
		Profiles = {
			-- IntelGoal: stations each bot takes before it heads for a terminal. HackMult: times the station's hack time.
			-- TerminalDelaySeconds: how long a bot waits after the Vault Breach begins before it walks to a terminal.
			-- Ticket 13B-b adds: PackageDelaySeconds (after the Package Heist begins before a team's nearest bot goes for the
			-- Package), Hunts (heads for a rival carrier), and Shot: what a bot does to an Exposed agent in sight.
			Casual = {
				IntelGoal = 2,
				HackMult = 1.6,
				TerminalDelaySeconds = 25,
				PackageDelaySeconds = 20,
				Hunts = false,
				Shot = { Damage = 8, IntervalSeconds = 0.7, HitChance = 0.35, RangeStuds = 45 },
			},
			Competitive = {
				IntelGoal = 4,
				HackMult = 1,
				TerminalDelaySeconds = 0,
				PackageDelaySeconds = 0,
				Hunts = true,
				Shot = { Damage = 12, IntervalSeconds = 0.4, HitChance = 0.6, RangeStuds = 70 },
			},
		},
		WeaponId = "ReticleCarbine", -- what the shot looks like and sounds like to others (a registered weapon)
		HearStuds = 80,
		PackageFloorDrop = 6, -- the Package floats this far above the floor of its room (pedestal top plus Package.LiftStuds)
		EyeStuds = 1.5, -- a bot's eye above its feet, for sight lines
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
		-- Ticket 11a: SPEC_CHANGES scaled the map to 36 stations and never limited how many are live, so every station is
		-- usable. SPEC-QUESTION: ActiveSpawns (spec 9.2: 10 per match) is therefore not used.
		ActiveSpawns = 10,
		InteractStuds = 5, -- how close you stand to work a station
		InteractSlackStuds = 1.5, -- allowance for lag while the hold runs
		AimDegrees = 40, -- a station this far off the crosshair can be picked (client)
		GlintMax = 6, -- at most this many stations glint at once (client)
		TerminalSeconds = 6,
		TerminalProgressKeepSeconds = 20, -- per team
		BriefcaseSeconds = 1,
		PickpocketSeconds = 2,
		PickpocketRange = 3,
		ServerRackSeconds = 10,
		ServerRackValue = 2,
		GlintRange = 25,
		GlintColor = Color3.fromRGB(255, 205, 80), -- ticket 11a: the faint glint on a station you could still take
		GlintFillTransparency = 0.8,
		GlintOutlineTransparency = 0.35,
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
	},

	-- Spec 10: vault.
	Vault = {
		BaseRate = 1.25, -- percent per second, regardless of how many agents are in the zone
		BonusMult = 1.25, -- team with HackBonusAt+ intel
		HackZoneSize = 10,
		-- Ticket 12a (SPEC_CHANGES 2026-10-25: 3 of the 5 vaults are active and hacking their terminals opens the Sanctum).
		-- BaseRate and BonusMult now apply to each terminal. SPEC-QUESTION: 1.25 percent a second (80 s a terminal) is the
		-- old single-bar rate; tune in play.
		ActiveVaults = 3,
		CheckHz = 5,
		BroadcastSeconds = 0.5,
		TerminalHeightStuds = 6, -- how far above or below the dais a hacker may stand
		TerminalSize = Vector3.new(2, 3.2, 1.2),
		TerminalColor = Color3.fromRGB(70, 200, 255),
		SanctumShaftId = "E5", -- the elevator that stays locked until every active terminal is hacked
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
		-- Ticket 13a: implementation values. SPEC-QUESTION: SPEC_CHANGES 11 asks for a ping meter that fills faster while
		-- sprinting or jumping and a rival-reveal key; the fixed PingInterval is built, the meter and the key are not.
		CarrierSpeedMult = 0.9,
		PickupSlackStuds = 1.5,
		MinY = -60, -- a dropped Package below this falls out of the map and returns to the pedestal
		CheckHz = 10,
		Size = Vector3.new(1.6, 1.1, 2.4),
		Color = Color3.fromRGB(255, 200, 60),
		LiftStuds = 2.5, -- how far above the pedestal's top it floats
		LightRange = 14,
		CarryOffset = CFrame.new(0, -0.2, 1.1), -- on the carrier's back
		DropForwardStuds = 2,
		DropLiftStuds = 1.5,
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
		-- Ticket 13a: implementation values.
		CallReachStuds = 6, -- how close to a terminal to call
		SlackStuds = 1.5,
		CheckHz = 10,
		TerminalSize = Vector3.new(2, 3.2, 1.2),
		TerminalColor = Color3.fromRGB(255, 215, 0),
		BeaconSize = Vector3.new(6, 400, 6),
		BeaconColor = Color3.fromRGB(255, 215, 0),
		ZoneColor = Color3.fromRGB(60, 255, 120),
		ZoneHeightStuds = 6, -- how far above or below the pad the carrier may stand and still count as in the zone
	},

	-- Tickets 13b/c: cosmetic aircraft and extraction screen. Server Extraction owns every deadline/outcome.
	ExtractionVisuals = {
		DisplayOrder = 65,
		HoverStuds = 14,
		RiseStuds = 18,
		RotorRadiansPerSecond = 24,
		HoverBobStuds = 0.2,
		HoverBobSpeed = 2,
		LetterboxFraction = 0.16,
		BodyColor = Color3.fromRGB(36, 39, 43),
		WindowColor = Color3.fromRGB(130, 175, 185),
		AccentColor = Color3.fromRGB(190, 150, 82),
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
		SmokeMaxClouds = 40, -- how many smoke clouds the server tracks for sight checks (Combat/Smoke); the oldest goes first
		TrackerBurstGapFraction = 0.5, -- hits count as one burst while each is within this fraction of the burst pause of the last (Lattice burst rifle)
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
		-- Tickets 8.5a/b/e/f: server-simulated projectiles (flares, throwing knives). Weapon-specific numbers sit in
		-- each WeaponDef.Projectile; these are shared. SPEC-QUESTION: all are Studio tuning.
		Projectile = {
			ViewStuds = 160, -- players within this of a launch or landing are told (the shooter always is)
			MaxPerPlayer = 6, -- projectiles in flight per player; further requests are refused
			FloorProbeStuds = 10, -- how far below a point to look for the floor a landed knife rests on
			LandedNormalOffset = 0.15, -- studs a landed knife sits off the wall it hit
			KnifeSize = Vector3.new(0.12, 0.12, 1.1),
			PickupHoldSeconds = 0.2,
			PickupSlackStuds = 1.5, -- extra reach allowed for lag when a pickup is validated
		},
		-- Ticket 8.5 client effects: cosmetic values only; authoritative durations arrive in events.
		WeaponEffects = {
			PredictionSeconds = 1.5,
			MaxFlights = 96,
			MaxLights = 48,
			MaxGlows = 48,
			MaxClouds = 64,
			KnifeColor = Color3.fromRGB(180, 185, 192),
			FlareSize = Vector3.new(0.16, 0.16, 0.5),
			FlareColor = Color3.fromRGB(255, 145, 65),
			FlareBrightness = 2,
			FlareRange = 18,
			GlowFillTransparency = 0.65,
			GlowOutlineTransparency = 0.15,
			ImpactSize = 0.18,
			SmokeColor = Color3.fromRGB(90, 88, 84),
			SmokeTransparency = 0.15,
			SmokeVeilTransparency = 0.45,
			SmokeDisplayOrder = 1,
		},
		-- The hammer's shove: how long the victim's client takes to travel the distance, and the free run it needs.
		-- NpcFractions: an NPC is moved the whole distance if its floor and walls allow, else the next shorter fraction (it never falls).
		Shove = { Seconds = 0.25, ProbeUpStuds = 1.5, WallClearanceStuds = 1, NpcFractions = { 1, 0.66, 0.33 } },
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
			-- Ticket 18d: how the Agent Tag looks in the world (a small glowing badge) and how high above the floor it floats.
			TagSize = Vector3.new(1.2, 0.2, 1.2),
			TagColor = Color3.fromRGB(255, 214, 90),
			TagLiftStuds = 0.6,
			SpawnLiftStuds = 4, -- a rescued agent is put this high above their Insertion Point and drops to the floor
		},
	},

	-- Spec 17 (Funds are gone, SPEC_CHANGES: intel is the only currency): pickups and the shop.
	Economy = {
		MedKitHP = 30,
		-- Ticket 18b: the wall stations, paid in the team's intel (Funds are gone). A Health Station heals to full and an Ammo Cache
		-- fills the weapon in hand, each reusable; a Food Spot is free, heals Heal and is empty for PickupRespawnSeconds after.
		-- Each hold takes Seconds within InteractStuds of the station. Using one is Discreet. SPEC-QUESTION: all of these prices
		-- and times are proposals (owner prices of 2026-10-28), the spec's Funds prices being obsolete.
		Stations = {
			InteractStuds = 6,
			WallSlackStuds = 1.2, -- a station is set in its wall: the line of sight stops this short of its nearest face
			HealthStation = { Cost = 3, Seconds = 2 },
			AmmoCache = { Cost = 2, Seconds = 1.5 },
			FoodSpot = { Cost = 0, Seconds = 1.5, Heal = 15 },
		},
		PickupRespawnSeconds = 60,
		PickupGlintRange = 20,
		-- Percent chance per PickupSpawn when it picks what to hold.
		PickupWeights = { ArmorPlate = 35, AmmoBox = 30, Funds = 25, MedKit = 10 },
		-- Ticket 18c, the Supply Cache shop (spec 17.3), priced in intel (owner prices 2026-10-28; the rescue price is
		-- Downed.Rescue.Cost). Items lists them in the order shown. A cache in a zone of HigherTierMinTier or more is
		-- HigherTierDiscount cheaper, rounded to the nearest intel and never below 1. Buying takes PurchaseSeconds near the
		-- cache and breaks Cover; opening the shop is quiet. A cache serves one agent at a time and closes on them when they
		-- are more than InteractStuds + SlackStuds away (checked CheckHz times a second). A Security Keycard has
		-- SecurityKeycardUses uses; each opens a keycard door in KeycardSeconds, without breaking Cover.
		Shop = {
			PurchaseSeconds = 2,
			OpenSeconds = 0.3,
			InteractStuds = 6,
			SlackStuds = 2,
			CheckHz = 4,
			Items = {
				{ Id = "ArmorPlate", Name = "Armor Plate", Price = 3 },
				{ Id = "AmmoRefill", Name = "Full ammo refill", Price = 2 },
				{ Id = "HealToFull", Name = "Heal to full", Price = 3 },
				{ Id = "GadgetCharge", Name = "Gadget charge", Price = 3 },
				{ Id = "AbilityCooldownReset", Name = "Ability cooldown reset", Price = 4 },
				{ Id = "SecurityKeycard", Name = "Security Keycard", Price = 3 },
				-- Ticket 18d: priced by Downed.Rescue.Cost (Price here is not used) and takes Downed.Rescue.CacheSeconds.
				{ Id = "RescueTeammate", Name = "Rescue teammate", Price = 0 },
			},
			SecurityKeycardUses = 3,
			KeycardSeconds = 1,
			-- SPEC-QUESTION: "higher-tier caches are 20% cheaper". Applied to caches in tier 1 and above.
			HigherTierDiscount = 0.2,
			HigherTierMinTier = 1,
		},
	},

	-- Ticket 14b: client-only security presentation and bounded streamed camera scenes.
	SecurityHud = {
		FeedWidthPixels = 360,
		FeedHeightPixels = 280,
		FeedTopPixels = 260,
		SceneRadius = 75,
		MaxPartsPerFeed = 350,
		SceneSeconds = 0.5,
		RefreshSeconds = 0.1,
		CycleSeconds = 8,
		NextFeedKey = Enum.KeyCode.F6,
		NextFeedPad = Enum.KeyCode.ButtonR1, -- 17-hud: DPadRight belongs to gadget cycling
		FeedNearOffset = 0.6,
		Ambient = Color3.fromRGB(145, 145, 155),
		LightColor = Color3.fromRGB(220, 220, 210),
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
			-- Ticket 14: implementation values. SPEC-QUESTION: the spec gives no unlock delay, so a camera that loses its
			-- target for LockLoseSeconds goes back to sweeping; one lock-on raises the alarm once.
			CheckHz = 10,
			LockLoseSeconds = 1.5,
			HitRadiusStuds = 2.5, -- a shot that ends this close to a camera destroys it
			InteractStuds = 8, -- the most a hacker may drift from the camera (on the floor plan) before the hold breaks
		},
		-- Ticket 14: how a camera looks on the client (CameraController) and the outline on what Interact would use.
		CameraLook = {
			SweepColor = Color3.fromRGB(255, 244, 214),
			LockedColor = Color3.fromRGB(255, 50, 50),
			OffColor = Color3.fromRGB(40, 40, 44),
			Brightness = 1.2,
			TargetColor = Color3.fromRGB(120, 200, 255),
		},
		CameraRoom = {
			Feeds = 4,
			DisableAllSeconds = 20,
			CooldownSeconds = 120,
			HoldSeconds = 5,
			-- Ticket 14: the terminal is made at match start in this room (the generator's id) on a clear spot.
			RoomId = "b_camera",
			InteractStuds = 8,
			TerminalSize = Vector3.new(3, 3.5, 2),
		},
		LaserGrid = {
			FuseBoxSeconds = 3,
			DisabledSeconds = 30,
			AlarmRaise = 1,
			-- Ticket 14: implementation values. A body is across a grid when it is inside the doorway and within
			-- CrossDepthStuds of the beam plane; the same body sets it off again no sooner than RetriggerSeconds.
			CheckHz = 20,
			CrossDepthStuds = 1.5,
			RetriggerSeconds = 3,
			-- A fuse box is made beside each grid, on a clear spot between these distances from the doorway.
			FuseBox = { MinStuds = 5, MaxStuds = 14, InteractStuds = 8, Size = Vector3.new(2, 3, 1) },
		},
		KeycardDoor = { OpenSeconds = 4, LockpickSeconds = 4, InteractStuds = 8 },
		-- Spec 18.5. A guard never fires at anyone who is not Exposed (a disguised agent, suspicion under 100%). Its HP is
		-- NPC.MaxHP and it stands up NPC.WakeUp.Seconds (60) after it went down, where it fell (SPEC_CHANGES relayout-2).
		Guard = {
			Damage = 8,
			FireIntervalSeconds = 0.8,
			NearAccuracy = 0.6,
			NearAccuracyStuds = 15,
			FarAccuracy = 0.2,
			FarAccuracyStuds = 40, -- it does not shoot beyond this
			EngageFiringRadius = 30, -- an agent firing within this distance gets engaged
			ChaseLimitStuds = 40,
			-- Ticket 15: implementation values. SPEC-QUESTION: the spec gives none of these.
			ThinkHz = 10,
			ProvokeSeconds = 8, -- a guard that heard an agent fire, or was hit by one, goes for that agent this long
			LoseSeconds = 4, -- a target out of sight this long is given up and the guard goes back to its post
			HoldStuds = 14, -- in sight and this close, the guard stops closing in
			RepathStuds = 5, -- the guard picks a new route when its target has moved this far from the last one aimed at
			RepathSeconds = 1,
			EyeStuds = 1.5,
			MissStuds = 3, -- a shot that misses ends this far from the target's middle
			HearStuds = 70,
			WeaponId = "ReticlePistol", -- what the shot looks and sounds like to others (a registered weapon)
			-- Heightened (18.4): extra guards appear at nodes of this tier, none within SpawnAwayStuds of a player, up to
			-- MaxExtras at once. They stay until the match ends.
			ExtraTier = 1,
			MaxExtras = 6,
			SpawnAwayStuds = 40,
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
			TickHz = 4,
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

	-- Spec 15, ticket 16: what an agent changes about the common rules. The ability's name and cooldown are in AgentDefs.
	-- Guise (Two Faces): two disguise slots and a scan of 0.6 s instead of 1.2 s.
	Agents = {
		Guise = { DisguiseSlots = 2, ScanSeconds = 0.6 },
		-- Parapet: Plated (one more starting plate than the usual 1, or 2 in Solos: 2, or 3) and Riot Wall, a shield carried
		-- Offset studs in front of him: Size wide x tall x thick, it takes HP damage from shots (not his own) and ends after
		-- Seconds. Its see-through look fades as it is worn down. SPEC-QUESTION: putting it up breaks Cover.
		-- Lattice: Wired makes the hold kinds in HackKinds take HackMult of their time (tier doors cost 1 less intel when they
		-- exist, Step 18). Sparrow Drone: she flies it for Seconds from a spot HeightAbove her head, up to MaxRangeStuds from her
		-- body at Speed, ClearanceStuds off walls; it has HP and any shot at it counts; it hacks Intel stations and cameras
		-- where it hovers (the usual reach); every TagCheckSeconds it tags enemy agents in True Form it can see within TagRange
		-- for her team for TagSeconds. Her body stands still and cannot fire, and damage to it ends the flight.
		Lattice = {
			HackMult = 0.75,
			HackKinds = {
				Intel = true,
				Camera = true,
				FuseBox = true,
				CameraTerminal = true,
				Lockpick = true,
				DoorHack = true,
				ElevatorHack = true,
			},
			TierDoorDiscount = 1, -- Wired: a tier door costs 1 less intel, never below 1
			SparrowDrone = {
				Seconds = 15,
				HP = 40,
				Speed = 24,
				MaxRangeStuds = 120,
				HeightAbove = 3,
				ClearanceStuds = 1.2,
				Size = Vector3.new(1.6, 0.6, 1.6),
				Color = Color3.fromRGB(60, 64, 72),
				MoveHz = 15, -- how often the client sends its wanted direction
				CameraSmoothRate = 18, -- the client's view glides to the drone this fast (per second)
				FindSeconds = 2, -- the client looks this long for its drone to arrive, within HeightAbove + FindSlackStuds of it
				FindSlackStuds = 3,
				MoveStaleSeconds = 0.5, -- no word from the client this long: the drone hovers
				TagSeconds = 8,
				TagRange = 80,
				TagCheckSeconds = 0.5,
			},
		},
		-- Reticle: Still Water (aiming while disguised raises no suspicion until she fires; falls hurt FallDamageMult as much) and
		-- Tracer Glass: for Seconds, while she is scoped, every agent who is Exposed or over SuspicionOver of the suspicion
		-- meter inside a ConeDegrees cone ahead of her, to RangeStuds, glows for her alone (through walls), refreshed every
		-- CheckSeconds. SPEC-QUESTION: the cone follows her body's facing, not the camera's pitch.
		Reticle = {
			QuietScope = true,
			FallDamageMult = 0.5,
			TracerGlass = {
				Seconds = 6,
				ConeDegrees = 45,
				RangeStuds = 150,
				SuspicionOver = 0.5,
				CheckSeconds = 0.25,
				GlowSeconds = 0.6,
			},
		},
		-- Suture: Triage (revives take ReviveMult of the time; teammates other than him within Triage.Radius regain PerSecond HP
		-- once OutOfCombatSeconds have passed since they were hurt) and Mend Field, a first-aid kit set Ahead of him on the floor
		-- that heals his team, himself included, HealPerSecond within Radius for Seconds. In a Tier 1+ zone setting it down breaks
		-- his Cover; in a public zone it looks like any first-aid kit. SPEC-QUESTION: it is set down, not thrown.
		Suture = {
			ReviveMult = 0.5,
			Triage = { Radius = 12, PerSecond = 2, OutOfCombatSeconds = 6, TickHz = 4 },
			MendField = {
				Seconds = 8,
				HealPerSecond = 12,
				Radius = 10,
				HealHz = 4,
				Ahead = 4,
				FloorProbe = { Up = 3, Down = 10 },
				KitSize = Vector3.new(1.6, 0.9, 1),
				KitColor = Color3.fromRGB(240, 240, 240),
				CrossColor = Color3.fromRGB(210, 40, 40),
			},
		},
		-- Feint: Smoke and Mirrors (while Exposed the ping rivals get is shown PingOffset.Min to Max studs from her; a disguise change
		-- takes DisguiseSeconds) and Double: an NPC in her current look (True Form sprints) set Ahead of her that walks her aim line
		-- for Seconds, stepping the floor every StepStuds, then goes; one hit pops it with the hitmarker of an agent.
		-- SPEC-QUESTION: it is an ordinary NPC rig, not a see-through hologram, so nothing tells it from the crowd.
		Feint = {
			PingOffset = { Min = 8, Max = 15 },
			DisguiseSeconds = 0.3,
			Double = { Seconds = 8, StepStuds = 2, Ahead = 2 },
		},
		Parapet = {
			ExtraStartPlates = 1,
			PlateMult = 0.5, -- Plated: a Plate Pack takes half the time (ticket 17)
			RiotWall = {
				Size = Vector3.new(8, 6, 0.4),
				Offset = 4.5,
				HP = 400,
				Seconds = 8,
				CheckSeconds = 0.25,
				Color = Color3.fromRGB(90, 190, 255),
				Material = Enum.Material.ForceField,
				Transparency = { Full = 0.35, Worn = 0.8 },
				OwnerFade = 0.6, -- the owner's own view of it is this much clearer (client)
			},
		},
	},

	-- Spec 16 and docs/GADGETS_DRAFT.md, ticket 17: each agent carries Slots sub-gadgets, used with keys 2 and 3. Charges refill at
	-- Ticket 17-hud: category accents are UI-only, never world/tier colours.
	GadgetHud = {
		CardWidthPixels = 216,
		CardHeightPixels = 60,
		Categories = {
			Recon = { Shape = "Circle", Color = Color3.fromHex("00CFE8") },
			Infiltration = { Shape = "Diamond", Color = Color3.fromHex("4169E1") },
			Evasion = { Shape = "Chevron", Color = Color3.fromHex("F476B5") },
			Support = { Shape = "RoundedSquare", Color = Color3.fromHex("FF7F50") },
		},
	},

	-- Supply Caches for intel (Step 18). DefaultPicks are carried until agent select can pick (a loadout without GadgetIds).
	Gadgets = {
		Slots = 2,
		DefaultPicks = { "MedInjector", "PlatePack" },
		-- Med Injector: Heal HP over Seconds, self; it stops when damage is taken. HealHz is how often a bit is given.
		MedInjector = { Heal = 35, Seconds = 4, HealHz = 4 },
		-- Plate Pack: one plate onto the player, or the nearest teammate within ReachStuds who has room for one, in Seconds.
		-- Briefcase Shield: a briefcase held Offset studs in front of the user, Lift above their middle (covering head and chest),
		-- for up to Seconds (the aim button puts it away sooner), taking HP damage from other people's shots. The user walks at
		-- SpeedMult, cannot sprint or shoot meanwhile, and it breaks Cover. Parapet's Riot Wall is far stronger.
		BriefcaseShield = {
			Size = Vector3.new(3, 3.2, 0.3),
			Offset = 2,
			Lift = 0.8,
			HP = 80,
			Seconds = 5,
			SpeedMult = 0.7,
			CheckSeconds = 0.25,
			Color = Color3.fromRGB(40, 42, 48),
			Material = Enum.Material.SmoothPlastic,
			Transparency = { Full = 0.1, Worn = 0.5 },
		},
		-- Scanner Pulse: every enemy agent within RadiusStuds, disguised or not, glows for the user alone for GlowSeconds; each
		-- of them is told only that they have been scanned. Nothing shows where from.
		ScannerPulse = { RadiusStuds = 20, GlowSeconds = 2 },
		-- Tripwire: a thin beam set across the way Ahead of the user, to the walls either side (at most HalfWidthStuds each way,
		-- at least MinLengthStuds across), Height above the floor, for Seconds. An enemy agent who crosses it (within HitStuds
		-- of the beam) glows for the user's team for PingSeconds and walks at SlowMult for SlowSeconds; the same body sets it off
		-- again no sooner than RetriggerSeconds. NPCs and teammates pass. One hit destroys it. The aim button recalls it.
		Tripwire = {
			Ahead = 3,
			FloorProbe = { Up = 3, Down = 10 },
			HalfWidthStuds = 8,
			MinLengthStuds = 3,
			Height = 1.4,
			Thickness = 0.12,
			Seconds = 90,
			PingSeconds = 3,
			SlowMult = 0.7,
			SlowSeconds = 2,
			HitStuds = 1.2,
			RetriggerSeconds = 3,
			CheckHz = 10,
			HP = 1,
			Color = Color3.fromRGB(255, 50, 60),
		},
		-- Bug Cam: stuck to the surface the user aims at within ReachStuds; for Seconds it watches a cone of FovDegrees to
		-- RangeStuds and any enemy agent who breaks Cover in it, with a clear line, glows for the user's team for TagSeconds. The
		-- user views it with a key (BugCam). One hit destroys it.
		BugCam = {
			ReachStuds = 10,
			Seconds = 60,
			FovDegrees = 80,
			RangeStuds = 40,
			TagSeconds = 4,
			HP = 1,
			Size = Vector3.new(0.6, 0.6, 0.6),
			Color = Color3.fromRGB(50, 52, 58),
			ViewOffsetStuds = 0.4, -- the view sits this far in front of the cam, clear of its body
		},
		-- Long Lens: aim at a hackable thing (an Intel station, a camera, a keycard door) within RangeStuds and in sight, within
		-- AimDegrees of the crosshair, and press fire: its hack begins and goes on while it stays in sight and the user keeps
		-- hacking, taking TimeMult times as long. The hack is measured from a point NearStuds from the target. GraceSeconds is how
		-- long the lens waits for the hold to show it has begun. Tier doors (for their intel) are reachable through it; the vault
		-- terminals are not yet.
		LongLens = { RangeStuds = 30, AimDegrees = 4, TimeMult = 1.5, NearStuds = 2, GraceSeconds = 0.4 },
		-- Keycard Clone: opens the nearest closed keycard door within ReachStuds, in sight, for the door's usual open time.
		KeycardClone = { ReachStuds = 8 },
		-- Jammer: a device set Ahead of the user. For Seconds, while it stands, cameras and laser grids within RadiusStuds go dark
		-- and enemy Spring Pads there stop throwing and enemy Noise Makers there are destroyed; it is checked every CheckSeconds
		-- and HoldSeconds is how long each check keeps them down, so taking the device out frees them quickly. One hit destroys it.
		Jammer = {
			Size = Vector3.new(1, 0.8, 1),
			Ahead = 4,
			FloorProbe = { Up = 3, Down = 10 },
			RadiusStuds = 15,
			Seconds = 20,
			CheckSeconds = 0.5,
			HoldSeconds = 1,
			HP = 1,
			Color = Color3.fromRGB(80, 84, 92),
		},
		-- Spring Pad: a flat pad set Ahead of the user; anyone (a player) who steps on it is thrown LaunchHeight studs up and
		-- ForwardSpeed forward along the pad's facing, and is exposed. It goes after Seconds or MaxLaunches throwings, or one hit
		-- (HP). A body is on it within Size's footprint and StepHeight above its top; the same body is thrown again no sooner
		-- than ReLaunchSeconds. SPEC-QUESTION: it is set down, not thrown.
		SpringPad = {
			Size = Vector3.new(6, 0.5, 6),
			Ahead = 4,
			FloorProbe = { Up = 3, Down = 10 },
			Seconds = 30,
			MaxLaunches = 6,
			LaunchHeight = 25,
			ForwardSpeed = 40,
			CheckHz = 10,
			StepHeight = 4,
			ReLaunchSeconds = 1.5,
			HP = 1,
			Color = Color3.fromRGB(120, 120, 130),
			Material = Enum.Material.Metal,
		},
		-- Noise Maker: put down Ahead of the user; ArmSeconds later it sounds an alarm-like noise for Seconds that guards within
		-- InvestigateStuds walk over to and other NPCs within it turn to look at. One hit (HP) destroys it. SPEC-QUESTION: it is
		-- set down, not thrown, and SoundId is a stand-in sound until the audio pass (Step 20).
		NoiseMaker = {
			Size = Vector3.new(1, 0.6, 1),
			Ahead = 4,
			FloorProbe = { Up = 3, Down = 10 },
			ArmSeconds = 3,
			Seconds = 6,
			InvestigateStuds = 30,
			HP = 1,
			Color = Color3.fromRGB(90, 90, 96),
			SoundId = "rbxasset://sounds/electronicpingshort.wav",
			Volume = 2,
			RollOffMaxStuds = 120,
		},
		-- SlackStuds: how far the two may drift apart while it goes on.
		PlatePack = { Seconds = 1.5, ReachStuds = 4, SlackStuds = 2 },
	},

	-- Ticket 18e-hud: client-only strip geometry and opened safe dimming.
	AssetHud = { TopPixels = 280, SlotWidthPixels = 216, SlotHeightPixels = 44, SafeDimFraction = 0.65 },

	-- Ticket 18e, docs/ASSETS_DESIGN.md. A safe (tag AssetSafe) holds the rarity of the room it stands in; the first agent to finish a
	-- SafeSeconds hold within SafeStuds takes it for the intel in SafeCost (by rarity, before Deep Pockets) and the safe is empty
	-- for the rest of the match. DefaultPicks are the four Assets carried by a loadout that names none (rarity slots in order).
	-- WallSlackStuds: as for the wall stations, the line of sight stops this short of the safe's nearest face.
	Assets = {
		DefaultPicks = { "LightFeet", "QuickHands", "SteadyNerves", "DeepPockets" },
		SafeCost = { FieldAgent = 1, Infiltrator = 3, BlackOps = 5, Ghost = 8 },
		SafeSeconds = 3,
		SafeStuds = 6,
		WallSlackStuds = 1.2,
		-- Quick Hands: the hold kinds it speeds up (a hold takes 1 / (1 + the Asset's value) of its time). The vault terminals
		-- are not holds and are not covered yet.
		QuickHandsKinds = {
			Intel = true,
			DoorHack = true,
			ElevatorHack = true,
			Camera = true,
			Lockpick = true,
			FuseBox = true,
			CameraTerminal = true,
			AssetSafe = true,
		},
		-- Field Medic: the hold kinds it shortens (a hold takes 1 / (1 + the Asset's value) of its time). A Health Station already heals
		-- to full, so its heal cannot grow; Food Spots heal more instead (StationService). SPEC-QUESTION, owner's choice 2026-10-28.
		FieldMedicKinds = { HealthStation = true },
		-- Duct Rat: from this rarity up, entering a vent does not break Cover.
		QuietVentFrom = "BlackOps",
		-- The tier of a room to the rarity of its safe; a safe above the last is Ghost.
		RarityByTier = { [0] = "FieldAgent", [1] = "Infiltrator", [2] = "BlackOps", [3] = "Ghost" },
	},

	-- Spec 24: default keys. Rebinding comes with the settings menu.
	Controls = {
		BugCam = Enum.KeyCode.Y, -- view your Bug Cams, one after another
		ToggleAutoRecover = Enum.KeyCode.H, -- turns Auto re-cover on or off (until the settings menu has it)
		Weapon = Enum.KeyCode.One, -- ticket 17: equip the weapon; the gadgets are Gadget1 and Gadget2
		Gadget1 = Enum.KeyCode.Two,
		Gadget2 = Enum.KeyCode.Three,
		GadgetNextPad = Enum.KeyCode.DPadRight, -- the gamepad cycles weapon, gadget 1, gadget 2
		Ability = Enum.KeyCode.Q, -- the agent's ability (spec 15)
		AbilityPad = Enum.KeyCode.ButtonY,
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
		DropPackage = Enum.KeyCode.X, -- spec 11: the carrier drops the Package
		DropPackagePad = Enum.KeyCode.ButtonB, -- owner request 2026-11-20: the gamepad drops it too
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

	-- Ticket 9c (SPEC_CHANGES 14.4): spectating. SPEC-QUESTION: the spec gives no drone speed or camera distance; these
	-- are playtest values.
	Spectate = {
		TargetCheckSeconds = 0.5, -- how often the server re-checks that a watched player still lives
		StreamSeconds = 0.5, -- how often the map is streamed around the spectator's view
		DroneSendHz = 10, -- how often the drone sends its position
		DroneSpeed = 35, -- studs a second
		DroneBoost = 2.5, -- the speed multiplier while the boost key is held
		DroneStepSlack = 1.25, -- the server accepts this much more than the top speed, for lag
		DroneSnapStuds = 4, -- a drone further than this from where the server put it is moved back
		DroneMarginStuds = 6, -- how far past a zone volume the drone may drift
		DroneStartHeight = 8,
		ChatMaxLength = 120,
		ChatLines = 8, -- lines kept on screen
		ChatFadeSeconds = 12, -- a line stays this long once it is no longer new
		Camera = {
			Distance = 9, -- studs behind the watched player
			Height = 2.5, -- studs above their root
			PitchLimitDegrees = 70,
			DegreesPerPixel = 0.25,
			WallPadding = 0.5, -- studs kept between the camera and a wall it would otherwise sit in
		},
		Keys = {
			Next = Enum.UserInputType.MouseButton1,
			Previous = Enum.UserInputType.MouseButton2,
			Drone = Enum.KeyCode.F,
			Chat = Enum.KeyCode.Return,
			Up = Enum.KeyCode.Space,
			Down = Enum.KeyCode.LeftControl,
			Boost = Enum.KeyCode.LeftShift,
		},
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

	-- GPS carrier tracking (docs/GPS_DESIGN.md, owner answers 2026-10-28). Only the Package carrier. A press shorter than
	-- TapSeconds is a tap: it shows the nearest rival within Radius studs (through walls) for PingSeconds and costs TapCost intel
	-- (nothing if nobody is in range). A longer press is a hold: live marks of every rival in range sent SendHz times a second,
	-- HoldCostPerSecond intel at the start and each second after, ending when the team cannot pay, the key goes up, or the
	-- carrier stops being the carrier. A tracked player rival gets a cue, again only after CueRepeatSeconds. Using it does not break
	-- Cover. SPEC-QUESTION: bots count as rivals (they stand in for agents); a downed or eliminated rival is not shown.
	-- gps-carrier-client: local input and tracked-player feedback only.
	CarrierTrackHud = {
		Key = Enum.KeyCode.T,
		Pad = Enum.KeyCode.ButtonL3,
		RefreshSeconds = 0.05,
		MarkColor = Color3.fromRGB(170, 65, 110),
		CueColor = Color3.fromRGB(70, 55, 80),
		CueSeconds = 1.2,
		CueTransparency = 0.91,
		-- Breath-like bundled wind until the Step 20 authored whisper/audio pass.
		WhisperSoundId = "rbxasset://sounds/action_falling.ogg",
		WhisperVolume = 0.14,
		WhisperSpeed = 0.85,
		WhisperLowGain = -18,
		WhisperMidGain = -12,
		WhisperHighGain = -6,
	},
	CarrierTrack = {
		Radius = 60,
		TapSeconds = 0.3,
		PingSeconds = 1,
		TapCost = 1,
		HoldCostPerSecond = 1,
		SendHz = 5,
		CueRepeatSeconds = 4,
	},

	-- GPS routes (docs/GPS_DESIGN.md, owner answers 2026-10-28). RouteService searches the NPC lane graph twice for a player: the
	-- clean route keeps to the doors and zones the current disguise may enter; the fast route may also hack tier doors (an intel
	-- price counts as HackStudsPerIntel studs of walking), cross a zone above the clearance (RestrictedStuds), and use the ways
	-- that break Cover. A traversal's cost is its length times the multiplier, plus a wait for the gondola. NodeSnapStuds is how
	-- far a start or target may be from the nearest lane node (a storey of height counts FloorWeight times); a traversal end joins
	-- the nearest node within ConnectStuds (and ConnectFloorStuds up or down). A vent is hidden: the route may enter a grate only
	-- after the player has come within SeenStuds of it in sight (checked SeenHz times a second). SPEC-QUESTION: discovery is
	-- per player and a grate shows only that grate's own way through; secret exits are not built yet, so no route uses them.
	-- gps-client: presentation only; route authority stays in RouteService.
	RouteHud = {
		MapKey = Enum.KeyCode.M,
		MapPad = Enum.KeyCode.ButtonSelect,
		TargetKey = Enum.KeyCode.N,
		TargetPad = Enum.KeyCode.ButtonL1,
		ModeKey = Enum.KeyCode.J,
		ModePad = Enum.KeyCode.ButtonR1,
		FloorUpKey = Enum.KeyCode.PageUp,
		FloorDownKey = Enum.KeyCode.PageDown,
		RequestSeconds = 1,
		RefreshSeconds = 0.2,
		WidthPixels = 304,
		MapPixels = 272,
		-- Owner request 2026-11-20: the map is a small corner minimap by default (M cycles it: small, full panel, off; the shape key
		-- switches square and round). The minimap shows a window MiniPixels wide onto a plan drawn MiniZoomPixels wide, slid so the
		-- player stays in the middle.
		MiniPixels = 176,
		MiniZoomPixels = 960,
		ShapeKey = Enum.KeyCode.Comma,
		TopPixels = 208,
		LinePixels = 2,
		SelectedLinePixels = 4,
		FlagPixels = 18,
		SummaryPixels = 108,
		StepsPixels = 88,
		MapMarginStuds = 8,
		ZoneTransparency = 0.65,
		AlternateTransparency = 0.45,
		CleanColor = Color3.fromRGB(65, 155, 160),
		FastColor = Color3.fromRGB(190, 125, 70),
		ArrowSpacingStuds = 12,
		ArrowRangeStuds = 60,
		ArrowMax = 16,
		ArrowLengthStuds = 1.4,
		ArrowWidthStuds = 0.12,
		ArrowLiftStuds = 0.08,
		ArrowProbeUpStuds = 4,
		ArrowProbeDownStuds = 10,
	},
	Route = {
		NodeSnapStuds = 40,
		FootStuds = 3, -- a player's root is this far above the floor
		FloorWeight = 3,
		HackStudsPerIntel = 20,
		RestrictedStuds = 80,
		VentCostMult = 2.5,
		ZiplineCostMult = 0.35,
		LadderCostMult = 2,
		GondolaWaitStuds = 120,
		ConnectStuds = 40,
		JoinChestStuds = 2, -- the height of the line that must be clear between a traversal end and its lane node
		ConnectFloorStuds = 6,
		SeenStuds = 14,
		SeenHz = 2,
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
		-- RigService reloads a dead player after AutoRespawnSeconds and MatchService stops ending the match when everyone is out.
		-- Off since 2026-11-19: elimination, spectating and Mission Failed are the real match flow (Steps 9 and 10). Turn it on only to
		-- test something that needs a body back quickly.
		AutoRespawn = false,
		AutoRespawnSeconds = 3,
		-- Ticket menu-shell: open the menu on join and spawn only after agent select. false: spawn straight in, as before.
		MenuOnJoin = true,
		-- Studio only: the mastery level every agent starts at, so W2 and W3 can be tested before mastery XP exists.
		StudioMasteryLevel = 1,
		-- The mode a Studio test plays in until the lobby picks one (Step 10): a key of Modes. Teams fill in join order.
		TestMode = "Duos",
		-- Ticket 10a, Studio only: start the match as soon as one team has finished agent select, instead of waiting for
		-- MinPlayers or the fill countdown with 2 teams (spec 3.1). Set false to play the real lobby rules.
		FastMatchStart = true,
	},

	-- Ticket 23-audit (spec 26): the server watches each player's real speed against the WalkSpeed it set. Zipline, gondola,
	-- elevator, spring pad and vent motion are driven by the client, so those can look like speeding: Kick stays false
	-- until a playtest's log shows the flags are only real exploits (MovementGuard.grace is the hook for known traversals).
	MovementGuard = {
		SampleSeconds = 0.25,
		Tolerance = 0.2, -- spec 26: 20 percent over the server's WalkSpeed
		SlackStuds = 3, -- added to the distance allowed per sample (network jitter, a shove, a step up)
		TeleportStuds = 30, -- one sample moving further than this is a teleport, not speed
		GraceSeconds = 4, -- after a character spawns
		ViolationsToFlag = 4, -- bad samples inside one window before the player counts as flagged
		ResetSeconds = 10, -- clean time that clears the count
		Kick = false,
		KickMessage = "Disconnected: movement did not match the server.",
		WarnEverySeconds = 5, -- per player, so a log cannot be flooded
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
			-- Ticket 9c: switching view is a key press; the drone sends at Spectate.DroneSendHz; chat is slow on purpose.
			RequestDropPackage = { PerSecond = 1, Burst = 2 }, -- ticket 13a
			RequestPing = { PerSecond = 3, Burst = 5 }, -- ticket 19-pings: a button press
			RequestAbility = { PerSecond = 2, Burst = 3 }, -- ticket 16: a key press; the server holds the cooldown
			RequestSparrowMove = { PerSecond = 30, Burst = 30 }, -- ticket 16c: sent at Lattice.SparrowDrone.MoveHz
			RequestAutoRecover = { PerSecond = 2, Burst = 3 }, -- a key press
			RequestCarrierTrack = { PerSecond = 6, Burst = 8 }, -- a key down and up
			RequestRoute = { PerSecond = 2, Burst = 4 }, -- GPS: the client asks about once a second while a route shows
			RequestElevatorFloor = { PerSecond = 2, Burst = 4 }, -- ticket 7B-glass-elevators: a key press in the cab
			RequestShopBuy = { PerSecond = 2, Burst = 4 }, -- ticket 18c: a button
			RequestShopClose = { PerSecond = 2, Burst = 4 },
			RequestGadget = { PerSecond = 6, Burst = 8 }, -- ticket 17: key presses (equip, deploy, alternate)
			RequestSpectate = { PerSecond = 4, Burst = 8 },
			RequestDronePosition = { PerSecond = 15, Burst = 15 },
			RequestSpectatorChat = { PerSecond = 1, Burst = 3 },
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
