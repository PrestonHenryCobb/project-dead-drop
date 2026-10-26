--!strict
-- The layout of "The Gala" as data (BUILD_ORDER Step 7B, re-plan in docs/MAP_BRIEF_REPLAN.md). Build.luau turns this
-- into geometry, zones, doors and NPC nodes.
--
-- Two towers on the roofs of skyscrapers, high over a city: the Gala, and east of it across a 20-stud drop, the hotel
-- and casino wing. Their ground floors are entirely indoors with windows onto the city; the outdoor spaces are terraces,
-- decks, a courtyard and roofs above. Galleries (GH, 12 studs up) are open floors inside rooms: over the ballroom and the
-- bar, staff catwalks over the kitchen and loading bay, and the casino's VIP tables.
--   B (-24)  basement: a staff ring round a security loop and Vault A; the service tunnel; the wing's laundry, security
--            and Vault D
--   G (0)    ground: lobby, atrium and pond, sculpture walk, ballroom, lounge, bar, the staff corridor and kitchens,
--            Vault C; the wing's casino, cage and high-roller lounge
--   M (24)   mezzanine: grand gallery, atrium balcony, masquerade hall, offices and the security hub, the terrace ring;
--            the skybridge to the lawn deck and the wing's hotel lobby
--   T (48)   top floor: the penthouse inside a guard ring, Vault B, the upper terrace; the wing's suites round a courtyard
--   R (72)   roof: the rooftop party with the helipad and a cantilevered pool deck; the catwalk to the wing's roof garden
--
-- Circulation (MAP_BRIEF_REPLAN): every floor has a public loop and a staff loop that meet at a few points; important
-- areas (vault wings, guard rooms, nested and Executive rooms) have one front door and one back exit, with vents into
-- a few of them; hubs have wide openings; no corridor ends blind.
--
-- Rects are { x1, z1, x2, z2 } in studs. Rooms on one level must not overlap; Build.luau reports any that do.
-- A room with `parent` is carved out of that parent room (a nested room, for example a guard room inside a staff room).
-- Doors name the two rooms they join and where along their shared wall; `gate` makes it a clearance door that stays
-- shut below that tier. Build.luau makes every other doorway between two tiers a clearance door of the higher tier
-- too (review after stage 4), except keycard doors, vault doors and open arches.
--
-- This file is data only. Tuning numbers (wall heights and so on) live in Build.luau.

export type Rect = { number }

export type Room = {
	id: string,
	level: string,
	name: string,
	tier: number,
	kind: string, -- "indoor", "outdoor", or "gallery" (an open floor inside a room, on a gallery level)
	rect: Rect,
	parent: string?,
	holes: { Rect }?, -- areas cut out of this room (used by the terrace rings and the suite arcade)
	density: number?, -- how many NPCs favour it; 1 is normal
	activities: { string }?, -- what NPC nodes in it do; defaults by tier
	props: { string }?, -- what fills it (see Build.luau)
	glass: boolean?, -- its walls facing a garden are glass above a low sill
	height: number?, -- an indoor room's wall height when it is lower than a full storey (a bridge)
	noNodes: boolean?, -- no NPC nodes (a vault strongroom: NPCs never stop at the vault)
	theme: string?, -- a vault's look: "bank", "gallery", "cold", "counting" or "observatory"
	round: number?, -- its corners are rounded off with curved walls of this radius (corners with a doorway near stay square)
	style: string?, -- its wing theme when the default (Build.luau styleOf) is not right: deco, casino, mediterranean, ...
	-- Gala re-layout (Relayout.luau):
	shaft: string?, -- a piece of a glass elevator shaft (Shaft.id): no floor, glass walls, a door onto its parent where it stops
	stop: boolean?, -- the cab stops on this level (a shaft piece)
	posts: boolean?, -- a deck held up on posts standing on the floor below (the sky deck, the roof stair deck)
	vault: string?, -- the vault this room belongs to (A to E)
	hub: string?, -- the crowd hub it is part of
}

export type Door = {
	a: string,
	b: string,
	at: number?, -- coordinate along the shared wall; the middle if omitted
	width: number?,
	gate: number?, -- a clearance door that stays shut below this tier
	keycard: boolean?, -- a keycard shortcut door between tiers (spec 4.3)
	vault: string?, -- the inner vault door (spec 10): shut until the vault is hacked; names the vault
	laser: boolean?, -- a laser grid across this doorway (spec 18.2)
	arch: boolean?, -- an open doorway with a round arch over it
	line: number?, -- the wall's own coordinate (z for a wall along x), when the two rooms share more than one wall
	-- Gala re-layout: what hacking this door costs comes from GameConfig.Doors.HackCost, by gate tier and these roles.
	core: boolean?, -- the door into a vault core (an Executive door)
	role: string?, -- "terrace" (a Sanctum terrace door) or "stairhead" (the door at the head of the Executive stair)
	package: string?, -- "front" or "back": a door into the Package room
	keycardOnly: boolean?, -- opens with a Tier 4 keycard and nothing else (the back Package door)
	elevator: string?, -- a shaft door: Shaft.id
}

-- A window in the wall two rooms share (MAP_BRIEF_REPLAN stage 2):
--   "hatch"   an open serving hatch over a counter: you see and talk through it, nobody climbs through it
--   "glass"   clear glass: you see through it, but it blocks movement, shots and sight checks like a wall
--   "oneWay"  one-way glass: clear from `inside`, a mirror from the other side; it blocks shots and sight both ways
export type Window = {
	a: string,
	b: string,
	at: number,
	width: number,
	kind: string,
	inside: string?, -- oneWay: the room that sees out
	line: number?,
}

-- A vent (see the vents list): a crawl duct through `points` at ceiling height on `level`.
export type Vent = { id: string, level: string, name: string, points: { { number } } }

-- A curved stair (MAP_BRIEF_REPLAN stage 4): it follows a circle round (x, z), climbing from `from` at fromAngle to `to`
-- at toAngle (degrees, measured from +x toward +z), and steps off onto `landing`, a short bridge out to the floor above.
-- It must stand where nothing overhangs it (an open void), since no floor is cut for it.
export type CurvedStair = {
	from: string,
	to: string,
	x: number,
	z: number,
	radius: number,
	width: number,
	fromAngle: number,
	toAngle: number,
	landing: Rect,
}

-- An open shaft through a floor, railed round; `round` rounds its corners off with curved railings and floor.
export type Void = { level: string, rect: Rect, round: number?, railed: boolean? } -- railed: a railing, not a wall, even beside an indoor room

export type Ramp = {
	from: string, -- the lower level
	to: string?, -- the level it climbs to: the next full level if not given, or a gallery level
	x: number, -- centre line (for a ramp climbing along z) or start x (along x)
	z: number, -- start z (lower end) for a ramp climbing along z, or centre line for one along x
	dir: string, -- "+z", "-z", "+x" or "-x": the way it climbs
	turn: boolean?, -- a switchback: it climbs half way, turns at a landing and climbs back to arrive beside where it began
	width: number?, -- one flight's width when it is not the standard 6 (a grand stair is 24, an escalator ramp 12)
	id: string?,
	kind: string?, -- "Grand stair", "Escalator ramp", "Switchback stair", "Staff stair", "Guard stair", "Roof stair", "Executive stair"
	tier: number?, -- who the stair is for (0 public, 1 Staff, 2 Security, 4 Tier 4)
}

export type Marker = { id: string, level: string, x: number, z: number, room: string? }

-- Gala re-layout: a secret exit is a panel in the wall two rooms share, opened by a prop inside `a` (the restricted room).
export type SecretExit = { id: string, a: string, b: string, level: string, line: number, at: number, width: number }
-- A glass elevator: its rooms are the Room pieces with this `shaft` id, one per level it passes. Locked until the match unlocks it.
export type Shaft = { id: string, name: string, tier: number, locked: boolean? }
-- A service ladder from `level` up to the outdoor room `room` on `to`, at (x, z) beside the wall; `edge` is the terrace edge line.
export type Ladder = { id: string, level: string, to: string, x: number, z: number, room: string, edge: number }

-- Things that are not rooms: water, garden islands, bridges, a skylight, a statue, lanterns, a pavilion, and a truss
-- (the steel under a skybridge, the service tunnel or a cantilevered deck).
export type Feature = {
	kind: string,
	level: string,
	rect: Rect?,
	x: number?,
	z: number?,
	width: number?,
	height: number?,
	top: number?, -- bridges: how high the deck sits above the floor
	color: Color3?,
	count: number?,
	points: { { number } }?,
	radius: number?, -- fountain: the outer basin's radius
	userId: number?, -- fountain: whose avatar the porcelain statue on top is cast from
	text: string?, -- fountain: the words on the plaque
}

-- Things placed in rooms (BUILD_ORDER Step 7B pass 2): Build.luau finds each a free spot along a wall of its room.
--   intel     an intel station of type `station` (GameConfig.Intel.Stations: tablet, laptop cart, server rack, wall safe)
--   health    a wall health station (in the restrooms)        ammo    a wall ammo cache
--   food      a buffet with a plate of food                   safe    a safe holding an asset (rarity by room tier)
--   cache     a supply cache                                  camera  a security camera high on a wall
export type Placement = { kind: string, room: string, station: number? }

-- A zipline (spec 4.3, 2 pairs): a cable from a mast at the top down to a post at the bottom. Using it breaks Cover.
export type ZiplineEnd = { level: string, x: number, z: number, mast: number } -- mast: the cable's height above the floor
export type Zipline = { id: string, top: ZiplineEnd, bottom: ZiplineEnd }

-- The window-washer gondola: a platform that crosses between two docks at one level, along x. Riding breaks Cover.
export type Gondola = { level: string, z: number, fromX: number, toX: number, width: number, length: number }

-- A node NPCs can walk to that the grid would not place (on an island, on a bridge).
export type NodeSpec = { level: string, x: number, z: number, activity: string }

local rooms: { Room } = {}

local function room(
	id: string,
	level: string,
	name: string,
	tier: number,
	kind: string,
	rect: Rect,
	extra: { [string]: any }?
)
	local r: any = { id = id, level = level, name = name, tier = tier, kind = kind, rect = rect }
	for key, value in extra or {} do
		r[key] = value
	end
	table.insert(rooms, r :: Room)
end

local OUT, IN, GALLERY = "outdoor", "indoor", "gallery"

-- Footprints (referenced by the terrace rings).
local FG = { -140, -170, 140, 150 } -- the Gala at ground and basement
local FM = { -125, -155, 125, 135 } -- mezzanine
local FT = { -90, -120, 90, 100 } -- top floor and roof
local VOID = { -44, -40, 44, 52 } -- the atrium void, with the pond at its foot
local VOID_T = { -38, -40, 38, 52 } -- the void through the top floor: narrower, so the penthouse keeps a walkway round it
local FW = { 160, -85, 280, 125 } -- the wing, at ground and basement
local COURT = { 231, -45, 254, 95 } -- the open-air courtyard in the wing's suite floor, open to the sky above it

-- The towers' outlines at ground level: each stands on its own skyscraper in the city.
local towers: { Rect } = { FG, FW }

-- B: basement (-24) ---------------------------------------------------------------------------------------------------
-- A staff ring (storage halls and two cross corridors) runs round the floor; inside it a security loop rings Vault A.
room("b_west_n", "B", "West storage north", 1, IN, { -140, -170, -95, -10 }, { props = { "crates" } })
room("b_west_s", "B", "West storage south", 1, IN, { -140, -10, -95, 150 }, { props = { "crates" } })
room("b_east_n", "B", "East storage north", 1, IN, { 95, -170, 140, -10 }, { props = { "crates" } })
room("b_east_s", "B", "East storage south", 1, IN, { 95, -10, 140, 150 }, { props = { "crates" } })
room("b_staff_n", "B", "North service corridor", 1, IN, { -95, -170, 95, -150 })
room("b_staff_s", "B", "South service corridor", 1, IN, { -95, 130, 95, 150 })
room("b_sec_n", "B", "North security hall", 2, IN, { -95, -150, 95, -110 }, { props = { "pillars" } })
room("b_sec_s", "B", "South security hall", 2, IN, { -95, 80, 95, 130 }, { props = { "pillars" } })
room("b_sec_c", "B", "Central security hall", 2, IN, { -25, -110, 25, 80 }, { props = { "pillars" } })
room("b_camera", "B", "Camera room", 2, IN, { 25, -110, 95, -30 }, { props = { "desks" } })
room("b_barracks", "B", "Guard barracks", 2, IN, { 25, -30, 95, 80 }, { props = { "tables" } })
room("b_vaulta_ante", "B", "Vault A laser hall", 2, IN, { -95, -20, -25, 80 })
room("b_vaulta", "B", "Vault A", 3, IN, { -95, -110, -25, -20 }, { density = 0.5, theme = "bank" })
room(
	"b_vaulta_core",
	"B",
	"Vault A strongroom",
	3,
	IN,
	{ -80, -110, -40, -85 },
	{ parent = "b_vaulta", noNodes = true }
)

-- G: ground (0). Entirely indoors: the tower footprint, with windows onto the cityscape. -------------------------------
-- West column: Vault C behind the kitchen, the loading bay, the staff lockers, the coat check.
room("g_vaultc_ante", "G", "Vault C cold room", 2, IN, { -140, -170, -100, -140 })
room("g_vaultc", "G", "Vault C", 3, IN, { -140, -140, -100, -100 }, { density = 0.5, theme = "cold" })
room(
	"g_vaultc_core",
	"G",
	"Vault C strongroom",
	3,
	IN,
	{ -140, -140, -118, -122 },
	{ parent = "g_vaultc", noNodes = true }
)
room(
	"g_dock",
	"G",
	"Loading bay",
	1,
	IN,
	{ -140, -100, -100, -40 },
	{ glass = true, density = 0.7, props = { "crates" } }
)
room("g_staff_w", "G", "Staff lockers", 1, IN, { -140, -40, -100, 70 }, { glass = true, props = { "crates" } })
room("g_coat", "G", "Coat check", 1, IN, { -140, 70, -100, 150 }, { glass = true, props = { "desks" } })
-- North band: the kitchens on one long staff corridor.
room("g_kitchen", "G", "Kitchen", 1, IN, { -100, -170, -40, -120 }, { density = 1.2, props = { "islands" } })
room("g_pantry", "G", "Service pantry", 1, IN, { -40, -170, 20, -120 }, { props = { "islands" } })
room("g_staffwc", "G", "Staff washroom", 1, IN, { -40, -170, -20, -152 }, { parent = "g_pantry" })
room("g_catering", "G", "Catering prep", 1, IN, { 20, -170, 70, -120 }, { glass = true, props = { "islands" } })
room("g_breakroom", "G", "Staff break room", 1, IN, { 70, -170, 100, -120 }, { glass = true, props = { "tables" } })
room("g_cold", "G", "Cold storage", 1, IN, { 100, -170, 140, -120 }, { glass = true, props = { "crates" } })
room("g_staff_n", "G", "Staff corridor", 1, IN, { -100, -120, 140, -100 })
-- The middle: the sculpture walk, the atrium round the pond, the ballroom and the smoking lounge.
room("g_sculpt", "G", "Sculpture walk", 0, IN, { -100, -100, -60, 70 }, { props = { "partitions" }, round = 12 })
room("g_atrium", "G", "Atrium", 0, IN, { -60, -100, 60, 70 }, { density = 2, props = { "planters" } })
room(
	"g_ballroom",
	"G",
	"Ballroom",
	0,
	IN,
	{ 60, -100, 140, 0 },
	{ glass = true, density = 2, props = { "pillars", "tables" } }
)
room("g_lounge", "G", "Smoking lounge", 0, IN, { 60, 0, 140, 70 }, { glass = true, props = { "tables" } })
room("g_humidor", "G", "Humidor", 1, IN, { 110, 40, 140, 70 }, { parent = "g_lounge" })
-- South: the grand lobby (the elevator bank) and the cocktail bar.
room(
	"g_lobby",
	"G",
	"Grand lobby",
	0,
	IN,
	{ -100, 70, 60, 150 },
	{ glass = true, density = 1.5, props = { "reception", "pillars" } }
)
room(
	"g_concierge",
	"G",
	"Concierge office",
	1,
	IN,
	{ -100, 120, -70, 150 },
	{ parent = "g_lobby", props = { "desks" } }
)
room("g_restroom", "G", "Lobby restrooms", 0, IN, { 30, 130, 60, 150 }, { parent = "g_lobby" })
room(
	"g_bar",
	"G",
	"Cocktail bar",
	0,
	IN,
	{ 60, 70, 140, 150 },
	{ glass = true, density = 1.5, props = { "bar", "tables" } }
)

-- Vents (spec 4.3; review 2026-10-23): crawl ducts at ceiling height that bypass a guarded door. Each runs through
-- `points` on its level (straight runs between them, along x or z): the first and last points are ladder shafts, each
-- with a grate at floor level, in the room it starts in and the room it leads to. Entering one breaks Cover.
local vents: { Vent } = {
	{ id = "v_vaulta", level = "B", name = "Vent to Vault A", points = { { -102, -70 }, { -88, -70 } } },
	{ id = "v_vaultb", level = "T", name = "Vent to Vault B", points = { { 35, -72 }, { 35, -90 } } },
	{
		id = "v_vaultc",
		level = "G",
		name = "Vent to Vault C",
		points = { { -70, -90 }, { -112, -90 }, { -112, -110 } },
	},
	{ id = "v_vaultd", level = "B", name = "Vent to Vault D", points = { { 208, -30 }, { 222, -30 } } },
	{ id = "v_hub", level = "M", name = "Vent to the security hub", points = { { -42, -100 }, { -28, -100 } } },
	{ id = "v_cage", level = "G", name = "Vent to the cashier's cage", points = { { 193, 4 }, { 193, -10 } } },
}

-- GH: galleries (12) ----------------------------------------------------------------------------------------------------
room("gh_ballroom", "GH", "Ballroom gallery", 0, GALLERY, { 62, -16, 138, -2 }, { density = 1.2, props = { "tables" } })
room("gh_bar", "GH", "Bar loft", 0, GALLERY, { 62, 132, 138, 148 }, { density = 1, props = { "tables" } })
room("gh_kitchen", "GH", "Kitchen catwalk", 1, GALLERY, { -96, -168, -46, -160 })
room("gh_dock", "GH", "Loading bay catwalk", 1, GALLERY, { -140, -96, -130, -50 })
room(
	"gh_vip",
	"GH",
	"VIP tables",
	0,
	GALLERY,
	{ 230, 40, 278, 90 },
	{ density = 1.2, props = { "tables" }, style = "casino" }
)

-- M: mezzanine (24) -----------------------------------------------------------------------------------------------------
-- The public loop is the atrium balcony ring, joined to the gallery, the promenade and the masquerade hall. The staff and
-- security band along the north has its front doors on the balcony and its back doors on the terrace ring.
room(
	"m_gallery",
	"M",
	"Grand gallery",
	0,
	IN,
	{ -125, -60, -60, 135 },
	{ glass = true, density = 1.5, props = { "partitions" } }
)
room("m_restroom", "M", "Gallery restrooms", 0, IN, { -80, 115, -60, 135 }, { parent = "m_gallery" })
room(
	"m_promenade",
	"M",
	"Sculpture promenade",
	0,
	IN,
	{ -60, 70, 60, 135 },
	{ glass = true, props = { "planters", "pillars" } }
)
room("m_balcony", "M", "Atrium balcony", 0, IN, { -60, -60, 60, 70 }, { density = 1.2 })
room(
	"m_masq",
	"M",
	"Masquerade hall",
	0,
	IN,
	{ 60, -60, 125, 135 },
	{ glass = true, density = 2, props = { "stage", "pillars", "tables" } }
)
room("m_offices", "M", "Staff offices", 1, IN, { -125, -155, -35, -60 }, { glass = true, props = { "desks" } })
room("m_checkpoint", "M", "Security checkpoint", 2, IN, { -125, -95, -95, -60 }, { parent = "m_offices" })
room("m_hub", "M", "Security hub", 2, IN, { -35, -155, 45, -60 }, { props = { "desks" } })
room("m_records", "M", "Executive records", 3, IN, { 15, -155, 45, -120 }, { parent = "m_hub", density = 0.5 })
room("m_cater", "M", "Catering offices", 1, IN, { 45, -155, 125, -60 }, { glass = true, props = { "desks" } })
room(
	"m_terrace",
	"M",
	"Mezzanine terrace",
	0,
	OUT,
	FG,
	{ holes = { FM }, density = 1, props = { "planters", "tables", "trees" }, round = 12 }
)

-- An enclosed glass skybridge to the lawn deck, like the links between hospital wings, carried on a steel truss.
-- A passage, not a place to stand: no NPC nodes of its own (the nodes at its doors join its two ends).
room("m_skybridge", "M", "Skybridge", 0, IN, { 140, 26, 160, 38 }, { glass = true, height = 12, noNodes = true })
room(
	"m_belvedere",
	"M",
	"Garden lawn deck",
	0,
	OUT,
	{ 160, -15, 205, 125 },
	{ density = 1.2, props = { "trees", "planters", "tables" } }
)

-- The wing (hotel and casino) --------------------------------------------------------------------------------------------
-- B: the service tunnel from the Gala's east storage, and a staff loop through the laundry, the linen store, wing
-- security and the boiler corridor, with Vault D inside it.
room("b_tunnel", "B", "Service tunnel", 1, IN, { 140, 20, 160, 32 }, { height = 12, density = 0.3 })
room("wb_laundry", "B", "Hotel laundry", 1, IN, { 160, 5, 215, 55 }, { props = { "crates" } })
room("wb_linen", "B", "Linen store", 1, IN, { 160, -55, 215, 5 }, { props = { "crates" } })
room("wb_service", "B", "Hotel service hall", 1, IN, { 160, 55, 280, 125 }, { props = { "pillars" } })
room("wb_east", "B", "Boiler corridor", 1, IN, { 250, -55, 280, 55 }, { props = { "pillars" } })
room("wb_security", "B", "Wing security office", 2, IN, { 160, -85, 280, -55 }, { props = { "desks" } })
room("wb_vaultd_ante", "B", "Vault D counting hall", 2, IN, { 215, 5, 250, 55 })
room("wb_vaultd", "B", "Vault D", 3, IN, { 215, -55, 250, 5 }, { density = 0.5, theme = "counting" })
room(
	"wb_vaultd_core",
	"B",
	"Vault D strongroom",
	3,
	IN,
	{ 230, -55, 250, -35 },
	{ parent = "wb_vaultd", noNodes = true }
)
-- G: the casino floor, the cashier's cage and the high-roller lounge.
room(
	"wg_casino",
	"G",
	"Casino floor",
	0,
	IN,
	{ 160, -5, 280, 125 },
	{ glass = true, density = 2, props = { "pillars", "tables" } }
)
room("wg_restroom", "G", "Casino restrooms", 0, IN, { 260, 105, 280, 125 }, { parent = "wg_casino" })
room("wg_cage", "G", "Cashier's cage", 1, IN, { 160, -85, 210, -5 }, { glass = true, props = { "desks" } })
room("wg_highroller", "G", "High-roller lounge", 3, IN, { 210, -85, 280, -5 }, { glass = true, props = { "tables" } })
-- M: the hotel lobby and corridor beside the lawn deck, and housekeeping behind them.
room(
	"wm_lobby",
	"M",
	"Hotel lobby",
	0,
	IN,
	{ 205, 45, 280, 125 },
	{ glass = true, density = 1.5, props = { "reception" } }
)
room("wm_restroom", "M", "Hotel restrooms", 0, IN, { 260, 105, 280, 125 }, { parent = "wm_lobby" })
room("wm_corridor", "M", "Hotel corridor", 0, IN, { 205, -15, 280, 45 }, { glass = true, props = { "planters" } })
room("wm_housekeeping", "M", "Housekeeping", 1, IN, { 160, -85, 280, -15 }, { glass = true, props = { "crates" } })
-- T: suites round an arcaded courtyard, each opening onto a balcony that runs the length of the facade.
room("wt_arcade", "T", "Suite arcade", 0, IN, { 221, -85, 264, 125 }, { holes = { COURT }, props = { "planters" } })
room(
	"wt_court",
	"T",
	"Suite courtyard",
	0,
	OUT,
	COURT,
	{ density = 0.8, props = { "trees", "planters" }, round = 8, style = "mediterranean" }
)
room("wt_suite1", "T", "Garden suite", 0, IN, { 205, 55, 221, 125 }, { glass = true, props = { "tables" } })
room("wt_suite2", "T", "Corner suite", 0, IN, { 205, -15, 221, 55 }, { glass = true, props = { "tables" } })
room("wt_suite3", "T", "Skyline suite", 0, IN, { 205, -85, 221, -15 }, { glass = true, props = { "tables" } })
room("wt_suite4", "T", "City suite", 0, IN, { 264, 55, 280, 125 }, { glass = true, props = { "tables" } })
room("wt_suite5", "T", "Moon suite", 0, IN, { 264, -15, 280, 55 }, { glass = true, props = { "tables" } })
room("wt_exec", "T", "Executive suite", 3, IN, { 264, -85, 280, -15 }, { glass = true, density = 0.5 })
room("wt_balcony_w", "T", "West suite balcony", 0, OUT, { 197, -85, 205, 125 }, { density = 0.3 })
room("wt_balcony_e", "T", "East suite balcony", 0, OUT, { 280, -15, 288, 125 }, { density = 0.3 })
room("wt_balcony_x", "T", "Executive balcony", 3, OUT, { 280, -85, 288, -15 }, { density = 0.3 })
-- R: the roof garden (an extraction site), the plant room and the stair landing.
room(
	"wr_garden",
	"R",
	"Wing roof garden",
	0,
	OUT,
	{ 205, -15, 280, 125 },
	{ density = 1.5, props = { "trees", "planters", "bar" } }
)
-- The plant room keeps off the courtyard shaft (x 231 to 254), so none of it is open to the sky.
room("wr_plant", "R", "Rooftop plant room", 1, IN, { 205, -85, 231, -15 }, { props = { "crates" } })
room("wr_landing", "R", "Roof stair landing", 0, OUT, { 231, -85, 280, -15 }, { density = 0.4 })

-- T: top floor (48) -----------------------------------------------------------------------------------------------------
-- A guard ring (west, north, east and south halls) round the penthouse and Vault B.
room("t_west", "T", "West guard hall", 2, IN, { -90, -120, -50, 100 }, { props = { "pillars" }, round = 10 })
room("t_panic", "T", "Panic room", 3, IN, { -90, 40, -65, 65 }, { parent = "t_west", density = 0.5 })
room("t_east", "T", "East guard hall", 2, IN, { 50, -120, 90, 100 }, { props = { "pillars" }, round = 10 })
room("t_office", "T", "Executive office", 3, IN, { 65, 40, 90, 65 }, { parent = "t_east", density = 0.5 })
room("t_washroom", "T", "Guard washroom", 2, IN, { 70, 75, 90, 100 }, { parent = "t_east" })
room("t_north", "T", "North guard corridor", 2, IN, { -50, -120, 50, -104 })
room("t_south", "T", "South guard corridor", 2, IN, { -50, 88, 50, 100 })
room("t_vaultb", "T", "Vault B", 3, IN, { -50, -104, 50, -80 }, { density = 0.5, theme = "gallery" })
room("t_vaultb_core", "T", "Vault B strongroom", 3, IN, { -15, -104, 15, -94 }, { parent = "t_vaultb", noNodes = true })
room("t_vaultb_ante", "T", "Vault B display hall", 2, IN, { -50, -80, -10, -60 }, { props = { "vitrines" } })
room("t_study", "T", "Penthouse study", 3, IN, { -10, -80, 50, -60 }, { props = { "desks" } })
room("t_great", "T", "Penthouse great room", 3, IN, { -50, -60, 50, 70 }, { glass = true, density = 1 })
room("t_gallery", "T", "Private gallery", 3, IN, { -50, 70, 50, 88 })
room(
	"t_terrace",
	"T",
	"Upper terrace",
	0,
	OUT,
	FM,
	{ holes = { FT }, density = 1, props = { "planters", "tables", "trees" }, round = 12 }
)

-- R: roof (72) ----------------------------------------------------------------------------------------------------------
room(
	"r_roof",
	"R",
	"Rooftop cocktail party",
	0,
	OUT,
	FT,
	{ holes = { VOID }, density = 2, props = { "tables", "planters", "bar" } }
)
room(
	"r_pooldeck",
	"R",
	"Cantilevered pool deck",
	0,
	OUT,
	{ -170, -50, -90, 70 },
	{ density = 1.5, props = { "planters", "tables" } }
)
-- An open catwalk from the roof to the wing's roof garden.
room("r_catwalk", "R", "Roof catwalk", 0, OUT, { 90, 30, 205, 36 }, { density = 0.2 })

-- The atrium: an open shaft through the mezzanine and top floors down to the pond, with railings round it. The wing's
-- courtyard is open to the sky through its roof.
local voids: { Void } = {
	{ level = "M", rect = VOID, round = 14 },
	{ level = "T", rect = VOID_T, round = 12 },
	{ level = "R", rect = COURT },
}

-- Stairs. Narrow (6 wide). A plain run climbs 24 over 48 studs; a switchback (turn) climbs half, turns at a landing and
-- climbs back to arrive beside where it began, in 14 x 30. Each lies inside one room on the lower level and one above,
-- with open floor beyond the arrival so there is a way left and right.
local ramps: { Ramp } = {
	-- B -> G: staff stairs from the storage ring, the security stair to the pantry, and the south hall to the lobby
	{ from = "B", x = -120, z = 50, dir = "-z", turn = true },
	{ from = "B", x = 120, z = -160, dir = "+z", turn = true },
	{ from = "B", x = 0, z = -144, dir = "+z", turn = true },
	{ from = "B", x = -40, z = 120, dir = "-z", turn = true },
	-- G -> M: the kitchen and catering stairs, and public stairs from the sculpture walk and the lounge (the grand stair
	-- is the curved stair below)
	{ from = "G", x = -70, z = -126, dir = "-z", turn = true },
	{ from = "G", x = 55, z = -126, dir = "-z", turn = true },
	{ from = "G", x = -80, z = 40, dir = "-z", turn = true },
	{ from = "G", x = 80, z = 40, dir = "-z", turn = true },
	-- M -> T: staff stairs up into the guard halls, and public stairs from the gallery and the masquerade hall to the
	-- upper terrace
	{ from = "M", x = -66, z = -70, dir = "-z", turn = true },
	{ from = "M", x = 66, z = -70, dir = "-z", turn = true },
	{ from = "M", x = -107, z = 120, dir = "-z", turn = true },
	{ from = "M", x = 107, z = 120, dir = "-z", turn = true },
	-- T -> R: the guard stairs to the roof, and a public stair from the upper terrace to the pool deck
	{ from = "T", x = -83, z = -100, dir = "+z", turn = true },
	{ from = "T", x = 83, z = -100, dir = "+z", turn = true },
	{ from = "T", x = -107, z = 60, dir = "-z", turn = true },
	-- Half stairs up to the galleries (they climb beside a gallery and arrive over its edge)
	{ from = "G", to = "GH", x = 80, z = -40, dir = "+z" },
	{ from = "G", to = "GH", x = 130, z = 108, dir = "+z" },
	{ from = "G", to = "GH", x = -52, z = -136, dir = "-z" },
	{ from = "G", to = "GH", x = -106, z = -75, dir = "-x" },
	{ from = "G", to = "GH", x = 240, z = 16, dir = "+z" },
	-- The wing
	{ from = "B", x = 175, z = 115, dir = "-z", turn = true },
	{ from = "B", x = 265, z = 30, dir = "-z", turn = true },
	{ from = "G", x = 215, z = 116, dir = "-z", turn = true },
	{ from = "G", x = 185, z = -22, dir = "-z", turn = true },
	{ from = "M", x = 230, z = -78, dir = "+z", turn = true },
	{ from = "M", x = 242, z = 118, dir = "-z", turn = true },
	{ from = "T", x = 255, z = -52, dir = "-z", turn = true },
}

-- The grand staircase: from the atrium floor it sweeps round the west side of the fountain, climbing gently inside the
-- open void, and steps onto a short bridge to the balcony's north edge.
local curvedStairs: { CurvedStair } = {
	{
		from = "G",
		to = "M",
		x = 0,
		z = 6,
		radius = 34,
		width = 8,
		fromAngle = 120,
		toAngle = 270,
		landing = { -4, -40, 4, -23 }, -- round the top step, out to the balcony
	},
}

-- Doors: { a, b, at, width, options }. `at` is x for a wall that runs along x, and z for one that runs along z.
-- Widths by importance (MAP_BRIEF_REPLAN): grand openings 16, clearance doors 12, ordinary doors 10, service doors 8,
-- restrooms 6.
local doors: { Door } = {}
local function door(a: string, b: string, at: number?, width: number?, extra: { [string]: any }?)
	local d: any = { a = a, b = b, at = at, width = width }
	for key, value in extra or {} do
		d[key] = value
	end
	table.insert(doors, d :: Door)
end

-- B: the staff ring
door("b_west_n", "b_west_s", -110, 8)
door("b_east_n", "b_east_s", 110, 8)
door("b_west_n", "b_staff_n", -160, 8)
door("b_east_n", "b_staff_n", -160, 8)
door("b_west_s", "b_staff_s", 140, 8)
door("b_east_s", "b_staff_s", 140, 8)
-- B: the ring into the security loop
door("b_west_n", "b_sec_n", -130, 8, { keycard = true })
door("b_east_n", "b_sec_n", -130, 8, { keycard = true })
door("b_staff_n", "b_sec_n", 50, 8)
door("b_west_s", "b_sec_s", 105, 8)
door("b_east_s", "b_sec_s", 105, 8)
door("b_staff_s", "b_sec_s", 40, 8)
door("b_east_s", "b_barracks", 20, 8)
-- B: the security loop
door("b_sec_n", "b_sec_c", 15, 10)
door("b_sec_n", "b_camera", 60, 10)
door("b_sec_c", "b_camera", -70, 8)
door("b_sec_c", "b_barracks", 30, 8)
door("b_camera", "b_barracks", 60, 8)
door("b_sec_s", "b_sec_c", 0, 10)
door("b_sec_s", "b_barracks", 60, 10)
-- B: Vault A: the front door from the south hall, the laser hall, the back door to the central hall, and the vent
door("b_sec_s", "b_vaulta_ante", -60, 12, { gate = 2 })
door("b_vaulta_ante", "b_vaulta", -60, 12, { gate = 3, laser = true })
door("b_vaulta", "b_sec_c", -50, 12, { gate = 3 })
door("b_vaulta", "b_vaulta_core", -60, 8, { vault = "VaultA" })

-- G: the west column
door("g_kitchen", "g_vaultc_ante", -155, 12, { gate = 2 })
door("g_vaultc_ante", "g_vaultc", -110, 12, { gate = 3, laser = true })
door("g_vaultc", "g_dock", -125, 12, { gate = 3 })
door("g_vaultc", "g_vaultc_core", -132, 8, { vault = "VaultC" })
door("g_dock", "g_staff_w", -120, 10)
door("g_dock", "g_sculpt", -50, 10)
door("g_staff_w", "g_sculpt", 0, 8)
door("g_staff_w", "g_coat", -120, 8)
door("g_coat", "g_lobby", 95, 10)
-- G: the staff corridor and the kitchens
door("g_kitchen", "g_staff_n", -90, 10)
door("g_kitchen", "g_pantry", -140, 8)
door("g_pantry", "g_staff_n", -28, 10)
door("g_pantry", "g_catering", -160, 8)
door("g_pantry", "g_staffwc", -30, 6)
door("g_catering", "g_staff_n", 30, 10)
door("g_catering", "g_breakroom", -135, 8)
door("g_breakroom", "g_staff_n", 85, 8)
door("g_breakroom", "g_cold", -145, 8)
door("g_cold", "g_staff_n", 120, 10)
-- G: where the staff corridor meets the public rooms
door("g_staff_n", "g_sculpt", -80, 8, { keycard = true })
door("g_staff_n", "g_ballroom", 100, 8, { keycard = true })
door("g_staff_n", "g_atrium", -20, 10)
-- G: the public loop round the atrium
door("g_sculpt", "g_atrium", -20, 16, { arch = true })
door("g_sculpt", "g_atrium", 40, 16, { arch = true })
door("g_sculpt", "g_lobby", -80, 10)
door("g_atrium", "g_lobby", 0, 16, { arch = true })
door("g_atrium", "g_ballroom", -50, 16, { arch = true })
door("g_atrium", "g_lounge", 35, 12)
door("g_ballroom", "g_lounge", 120, 12)
door("g_lounge", "g_bar", 100, 10)
door("g_lobby", "g_bar", 110, 16, { arch = true })
door("g_lobby", "g_concierge", -85, 8, { gate = 1 })
door("g_lobby", "g_restroom", 45, 6)
door("g_lounge", "g_humidor", 55, 8, { gate = 1 })

-- M: the public loop
door("m_gallery", "m_balcony", -20, 16, { arch = true })
door("m_gallery", "m_balcony", 40, 10)
door("m_masq", "m_balcony", 0, 16, { arch = true })
door("m_masq", "m_balcony", 50, 10)
door("m_promenade", "m_balcony", 0, 16, { arch = true })
door("m_gallery", "m_promenade", 100, 10)
door("m_masq", "m_promenade", 100, 10)
door("m_gallery", "m_restroom", -70, 6)
-- M: out onto the terrace ring
door("m_terrace", "m_gallery", -20, 10)
door("m_terrace", "m_gallery", 60, 10)
door("m_terrace", "m_masq", -20, 10)
door("m_terrace", "m_masq", 60, 10)
door("m_terrace", "m_promenade", 40, 12)
-- M: the staff and security band: front doors on the balcony, back doors on the terrace, keycards between them
door("m_offices", "m_balcony", -45, 10)
door("m_offices", "m_terrace", -130, 8)
door("m_offices", "m_checkpoint", -80, 8, { gate = 2 })
door("m_hub", "m_balcony", 30, 10)
door("m_hub", "m_terrace", -10, 8)
door("m_hub", "m_records", 30, 8, { gate = 3 })
door("m_cater", "m_balcony", 50, 6)
door("m_cater", "m_terrace", -130, 8)
door("m_offices", "m_hub", -140, 8, { keycard = true })
door("m_hub", "m_cater", -100, 8, { keycard = true })
-- M: the skybridge to the lawn deck
door("m_terrace", "m_skybridge", 32, 10)
door("m_skybridge", "m_belvedere", 32, 10)

-- The wing, B: the tunnel and the staff loop
door("b_east_s", "b_tunnel", 26, 10)
door("b_tunnel", "wb_laundry", 26, 10)
door("wb_laundry", "wb_linen", 180, 10)
door("wb_laundry", "wb_service", 190, 10)
door("wb_linen", "wb_security", 180, 8)
door("wb_security", "wb_east", 265, 8)
door("wb_east", "wb_service", 268, 8)
-- B: Vault D: the front door from the service hall, the counting hall's lasers, the back door to wing security
door("wb_service", "wb_vaultd_ante", 232, 12, { gate = 2 })
door("wb_vaultd_ante", "wb_vaultd", 232, 12, { gate = 3, laser = true })
door("wb_vaultd", "wb_security", 222, 12, { gate = 3 })
door("wb_vaultd", "wb_vaultd_core", 240, 8, { vault = "VaultD" })
-- G: the casino
door("wg_casino", "wg_cage", 170, 10)
door("wg_casino", "wg_highroller", 245, 12, { gate = 3 })
door("wg_cage", "wg_highroller", -60, 8, { gate = 3 })
door("wg_casino", "wg_restroom", 270, 6)
-- M: the lawn deck, the hotel lobby, the corridor and housekeeping
door("m_belvedere", "wm_lobby", 85, 16, { arch = true })
door("m_belvedere", "wm_corridor", 15, 10)
door("wm_lobby", "wm_corridor", 240, 12)
door("wm_corridor", "wm_housekeeping", 260, 8)
door("m_belvedere", "wm_housekeeping", 165, 8)
door("wm_lobby", "wm_restroom", 270, 6)
-- T: the suites, each onto the arcade and onto its balcony; the courtyard
door("wt_arcade", "wt_suite1", 90, 8)
door("wt_arcade", "wt_suite2", 20, 8)
door("wt_arcade", "wt_suite3", -50, 8)
door("wt_arcade", "wt_suite4", 90, 8)
door("wt_arcade", "wt_suite5", 20, 8)
door("wt_arcade", "wt_exec", -25, 12, { gate = 3 })
door("wt_suite1", "wt_balcony_w", 90, 8)
door("wt_suite2", "wt_balcony_w", 40, 8)
door("wt_suite3", "wt_balcony_w", -50, 8)
door("wt_suite4", "wt_balcony_e", 90, 8)
door("wt_suite5", "wt_balcony_e", 20, 8)
door("wt_exec", "wt_balcony_x", -50, 8)
door("wt_balcony_x", "wt_balcony_e", 284, 6, { gate = 3 })
door("wt_arcade", "wt_court", -10, 12, { arch = true, line = 231 })
door("wt_arcade", "wt_court", 40, 12, { arch = true, line = 231 })
door("wt_arcade", "wt_court", 75, 12, { arch = true, line = 231 })
door("wt_arcade", "wt_court", -25, 12, { arch = true, line = 254 })
door("wt_arcade", "wt_court", 25, 12, { arch = true, line = 254 })
door("wt_arcade", "wt_court", 70, 12, { arch = true, line = 254 })
-- R: the roof garden, the plant room and the landing
door("wr_garden", "wr_plant", 215, 8)
door("wr_garden", "wr_landing", 258, 6)
door("wr_landing", "wr_plant", -60, 8)
door("r_roof", "r_catwalk", 33, 6)
door("r_catwalk", "wr_garden", 33, 6)

-- T: the guard ring, out onto the terrace
door("t_terrace", "t_west", -30, 10)
door("t_terrace", "t_west", 80, 10)
door("t_terrace", "t_east", -30, 10)
door("t_terrace", "t_east", 80, 10)
door("t_terrace", "t_north", 0, 10)
door("t_terrace", "t_south", 0, 10)
door("t_west", "t_north", -112, 8)
door("t_east", "t_north", -112, 8)
door("t_west", "t_south", 94, 8)
door("t_east", "t_south", 94, 8)
-- T: the penthouse: in from the west hall, out to the east hall; the gallery's back door to the south corridor
door("t_west", "t_great", 0, 12, { gate = 3 })
door("t_east", "t_great", 0, 12, { gate = 3 })
door("t_great", "t_gallery", 0, 16, { arch = true })
door("t_gallery", "t_south", 20, 12, { gate = 3 })
door("t_great", "t_study", 20, 10)
door("t_east", "t_study", -70, 12, { gate = 3 })
door("t_west", "t_panic", 52, 8, { gate = 3 })
door("t_east", "t_office", 52, 8, { gate = 3 })
door("t_east", "t_washroom", 85, 6)
-- T: Vault B: the front door through the display hall, the back door to the north corridor
door("t_west", "t_vaultb_ante", -70, 12, { gate = 2 })
door("t_vaultb_ante", "t_vaultb", -30, 12, { gate = 3, laser = true })
door("t_vaultb", "t_north", -30, 12, { gate = 3 })
door("t_vaultb", "t_vaultb_core", 0, 8, { vault = "VaultB" })

-- R
door("r_roof", "r_pooldeck", 0, 12)

-- Windows between rooms (MAP_BRIEF_REPLAN stage 2): { a, b, at, width, kind, options }.
local windows: { Window } = {}
local function window(a: string, b: string, at: number, width: number, kind: string, extra: { [string]: any }?)
	local w: any = { a = a, b = b, at = at, width = width, kind = kind }
	for key, value in extra or {} do
		w[key] = value
	end
	table.insert(windows, w :: Window)
end
-- One-way glass: tiered rooms watch the public rooms beside them without being seen.
window("m_hub", "m_balcony", -15, 24, "oneWay", { inside = "m_hub" })
window("m_hub", "m_balcony", 12, 14, "oneWay", { inside = "m_hub" })
window("m_checkpoint", "m_gallery", -110, 20, "oneWay", { inside = "m_checkpoint" })
window("m_offices", "m_gallery", -78, 24, "oneWay", { inside = "m_offices" })
window("m_cater", "m_masq", 92, 40, "oneWay", { inside = "m_cater" })
window("wg_highroller", "wg_casino", 225, 20, "oneWay", { inside = "wg_highroller" })
window("wg_highroller", "wg_casino", 266, 16, "oneWay", { inside = "wg_highroller" })
window("g_concierge", "g_lobby", -75, 8, "oneWay", { inside = "g_concierge" })
-- Serving hatches from the kitchens onto the staff corridor, and the cashier's teller window.
window("g_kitchen", "g_staff_n", -60, 16, "hatch")
window("g_catering", "g_staff_n", 45, 12, "hatch")
window("wg_cage", "wg_casino", 204, 8, "glass")
-- Clear glass between public rooms.
window("g_lounge", "g_ballroom", 85, 24, "glass")
window("m_gallery", "m_promenade", 82, 14, "glass")

-- Water, islands, bridges and set pieces. The atrium floor is a shallow reflecting pond at the foot of the open void, with
-- two garden islands joined to the south shore by short bridges; the lawn deck has a statue, lanterns and a glass pavilion.
local features: { Feature } = {
	-- The atrium's centrepiece under the open void: a tiered porcelain fountain, crowned by a porcelain statue cast from
	-- the avatar of the user who asked for it, with a plaque facing the lobby.
	{
		kind = "fountain",
		level = "G",
		x = 0,
		z = 6,
		radius = 18,
		userId = 80171669,
		text = "IN HONOUR OF THE FOUNDER",
	},
	{ kind = "skylight", level = "R", rect = VOID },
	{ kind = "statue", level = "M", x = 176, z = 45 },
	{
		kind = "lanterns",
		level = "M",
		points = { { 164, -11 }, { 164, 121 }, { 201, -11 }, { 201, 121 }, { 164, 55 }, { 201, 55 } },
	},
	{ kind = "pavilion", level = "M", rect = { 190, 0, 202, 60 }, count = 5 },
	{ kind = "truss", level = "M", rect = { 140, 26, 160, 38 } },
	{ kind = "truss", level = "B", rect = { 140, 20, 160, 32 } },
	-- The pool deck reaches past the tower's west edge on a truss, with a pool and a row of cabanas.
	{ kind = "truss", level = "R", rect = { -170, -50, -90, 70 } },
	-- The open catwalk between the roofs rides on a truss for its whole length.
	{ kind = "truss", level = "R", rect = { 90, 30, 205, 36 } },
	{ kind = "pool", level = "R", rect = { -165, -40, -145, 0 } },
	{ kind = "pavilion", level = "R", rect = { -162, 15, -150, 55 }, count = 3 },
}

local placements: { Placement } = {}
local function place(kind: string, list: { string })
	for _, roomId in list do
		table.insert(placements, { kind = kind, room = roomId })
	end
end
local function placeIntel(station: number, list: { string })
	for _, roomId in list do
		table.insert(placements, { kind = "intel", room = roomId, station = station })
	end
end
-- 48 intel stations (SPEC_CHANGES, intel amounts). The type is chosen per station, not by the room's tier, except that
-- wall safes (the richest) stand only in Security and Executive rooms; four sit in the vault rooms themselves.
-- Tablets (2 intel), mostly where the party is.
placeIntel(0, { "g_lobby", "g_atrium", "g_ballroom", "g_bar", "g_lounge", "m_gallery", "m_masq" })
placeIntel(0, { "wg_casino", "wm_lobby", "wt_arcade", "wt_suite1", "r_roof", "wr_garden", "m_terrace" })
-- Laptop carts (4 intel), mostly in the back of house.
placeIntel(1, { "g_kitchen", "g_pantry", "g_catering", "g_coat", "g_breakroom", "m_offices", "m_cater" })
placeIntel(1, { "wb_laundry", "wb_linen", "wm_housekeeping", "wg_cage", "b_east_s", "wt_suite3", "t_great" })
-- Server racks (6 intel).
placeIntel(2, { "b_sec_n", "b_sec_s", "b_sec_c", "b_camera", "m_hub", "t_west", "t_east", "wb_security" })
placeIntel(2, { "wr_plant", "g_staff_w", "g_vaultc", "wb_vaultd" })
-- Wall safes (10 intel).
placeIntel(3, { "t_gallery", "t_office", "t_panic", "m_records", "wg_highroller", "wt_exec", "b_vaulta", "t_vaultb" })
place("health", { "g_restroom", "g_staffwc", "m_restroom", "t_washroom", "wm_restroom", "wg_restroom" })
place("ammo", { "g_staff_n", "g_dock", "m_hub", "b_sec_n", "t_west", "wg_cage", "wm_corridor", "wt_arcade" })
-- Food: plenty where the party is, little in the guard areas.
place(
	"food",
	{ "g_ballroom", "g_ballroom", "g_ballroom", "g_bar", "g_bar", "g_lounge", "m_masq", "m_masq", "m_promenade" }
)
place("food", { "wg_casino", "wg_casino", "wm_lobby", "wr_garden", "wr_garden", "r_roof", "r_roof", "g_kitchen" })
place("food", { "g_kitchen", "wt_suite1", "t_great" })
-- Safes: four each in Staff, Security and Executive rooms.
place("safe", { "g_coat", "m_cater", "wb_laundry", "wr_plant" })
place("safe", { "b_barracks", "m_checkpoint", "t_east", "wb_security" })
place("safe", { "t_office", "t_panic", "wg_highroller", "wt_exec" })
place("cache", { "g_sculpt", "m_balcony", "t_terrace", "wg_cage", "b_west_s", "wr_garden" })
place("camera", { "g_staff_n", "g_kitchen", "g_dock", "m_hub", "m_offices", "b_sec_n", "b_sec_s", "t_west", "t_east" })
place("camera", { "wb_service", "wg_cage", "wm_housekeeping" })

-- Ziplines: the Gala's roof down to the lawn deck, and the wing's roof garden down to the Gala's upper terrace. The masts
-- are tall enough that a rider clears every glass barrier on the way down.
local ziplines: { Zipline } = {
	{
		id = "Zipline1",
		top = { level = "R", x = 80, z = 80, mast = 22 },
		bottom = { level = "M", x = 180, z = 100, mast = 7 },
	},
	{
		id = "Zipline2",
		top = { level = "R", x = 215, z = 112, mast = 22 },
		bottom = { level = "T", x = 115, z = 112, mast = 7 },
	},
}

-- The gondola: from the Gala's upper terrace (its east edge) across the drop to the west suite balcony.
local gondola: Gondola = { level = "T", z = 20, fromX = 125, toX = 197, width = 8, length = 8 }

local nodes: { NodeSpec } = {
	{ level = "B", x = 146, z = 26, activity = "Walk" },
	{ level = "B", x = 154, z = 26, activity = "Walk" },
	{ level = "R", x = 110, z = 33, activity = "Walk" },
	{ level = "R", x = 150, z = 33, activity = "Walk" },
	{ level = "R", x = 190, z = 33, activity = "Walk" },
	-- The terrace rings' outer corners. Without them, a path between two sides of a ring cuts the inner corner, where it
	-- brushes the guard halls' zones, and the corner reads as off limits to Guests.
	{ level = "M", x = -132, z = -162, activity = "Walk" },
	{ level = "M", x = 132, z = -162, activity = "Walk" },
	{ level = "M", x = -132, z = 142, activity = "Walk" },
	{ level = "M", x = 132, z = 142, activity = "Walk" },
	{ level = "T", x = -108, z = -138, activity = "Walk" },
	{ level = "T", x = 108, z = -138, activity = "Walk" },
	{ level = "T", x = -118, z = 130, activity = "Walk" },
	{ level = "T", x = 118, z = 130, activity = "Walk" },
}

-- Places that are not rooms: where teams arrive and where the Package leaves (spec 4.3).
local extraction: { Marker } = {
	{ id = "Helipad", level = "R", x = 0, z = 75 },
	{ id = "WingRoof", level = "R", x = 222, z = 100 },
	{ id = "GardenLawn", level = "M", x = 182, z = 70 },
}

-- Six on the ground floor (the lobby's elevator bank and the public rooms) and six on the mezzanine terrace, at least 60
-- apart.
local insertion: { Marker } = {
	{ id = "Insertion1", level = "G", x = -50, z = 105 },
	{ id = "Insertion2", level = "G", x = -80, z = -60 },
	{ id = "Insertion3", level = "G", x = 30, z = -75 },
	{ id = "Insertion4", level = "G", x = 100, z = -60 },
	{ id = "Insertion5", level = "G", x = 100, z = 25 },
	{ id = "Insertion6", level = "G", x = 110, z = 115 },
	{ id = "Insertion7", level = "M", x = -132, z = -110 },
	{ id = "Insertion8", level = "M", x = -132, z = 40 },
	{ id = "Insertion9", level = "M", x = 132, z = -130 },
	{ id = "Insertion10", level = "M", x = -60, z = -162 },
	{ id = "Insertion11", level = "M", x = 40, z = -162 },
	{ id = "Insertion12", level = "M", x = 10, z = 142 },
}

local vaults: { Marker } = {
	{ id = "VaultA", level = "B", x = -60, z = -97.5 },
	{ id = "VaultB", level = "T", x = 0, z = -99 },
	{ id = "VaultC", level = "G", x = -129, z = -131 },
	{ id = "VaultD", level = "B", x = 240, z = -45 },
}

-- Rooms with direction signposts just inside their doorways (halls, junctions and terraces people cross to get around).
local signposts: { string } = {
	"g_atrium",
	"g_lobby",
	"g_staff_n",
	"g_sculpt",
	"m_balcony",
	"m_terrace",
	"m_belvedere",
	"t_terrace",
	"t_west",
	"t_east",
	"b_staff_n",
	"b_staff_s",
	"b_sec_n",
	"b_sec_s",
	"b_sec_c",
	"wb_service",
	"wg_casino",
	"wm_corridor",
	"wm_lobby",
	"wt_arcade",
	"r_roof",
	"wr_garden",
}

return {
	levels = { B = -24, G = 0, GH = 12, M = 24, T = 48, R = 72 },
	levelOrder = { "B", "G", "M", "T", "R" }, -- full storeys; GH is a gallery level
	towers = towers,
	rooms = rooms,
	voids = voids,
	ramps = ramps,
	curvedStairs = curvedStairs,
	vents = vents,
	doors = doors,
	windows = windows,
	extraction = extraction,
	insertion = insertion,
	vaults = vaults,
	features = features,
	placements = placements,
	ziplines = ziplines,
	gondola = gondola,
	nodes = nodes,
	signposts = signposts,
}
