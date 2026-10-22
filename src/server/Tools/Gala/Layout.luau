--!strict
-- The layout of "The Gala" as data (BUILD_ORDER Step 7B). Build.luau turns this into geometry, zones, doors and NPC nodes.
--
-- A tower over a city street. The ground floor is entirely indoors, with windows onto a cityscape backdrop; the only
-- outdoor spaces are terraces and decks that branch off the upper floors, around a central atrium:
--   B (-24)  basement: storage halls, security corridors, Vault A in the core
--   G (0)    ground: lobby, ballroom, bar, kitchen, loading bay, catering, Vault C wing, and the atrium pond
--   M (24)   mezzanine: grand gallery, masquerade hall, atrium balcony, offices, security hub, terrace ring, skybridge and lawn deck
--   T (48)   top floor: penthouse and private gallery, guard halls, Vault B wing, upper terrace ring
--   R (72)   roof: the rooftop cocktail party, with the helipad
--
-- Rects are { x1, z1, x2, z2 } in studs. Rooms on one level must not overlap; Build.luau reports any that do.
-- A room with `parent` is carved out of that parent room (a nested room, for example a guard room inside a staff room).
-- Doors name the two rooms they join and where along their shared wall; `gate` makes it a clearance door that stays
-- shut below that tier (STEP 7B: only nested rooms, guard rooms, vault wings and the penthouse are gates).
--
-- This file is data only. Tuning numbers (wall heights and so on) live in Build.luau.

export type Rect = { number }

export type Room = {
	id: string,
	level: string,
	name: string,
	tier: number,
	kind: string, -- "indoor" or "outdoor"
	rect: Rect,
	parent: string?,
	holes: { Rect }?, -- areas cut out of this room (used by the terrace rings)
	density: number?, -- how many NPCs favour it; 1 is normal
	activities: { string }?, -- what NPC nodes in it do; defaults by tier
	props: { string }?, -- what fills it (see Build.luau)
	glass: boolean?, -- its walls facing a garden are glass above a low sill
}

export type Door = {
	a: string,
	b: string,
	at: number?, -- coordinate along the shared wall; the middle if omitted
	width: number?,
	gate: number?, -- a clearance door that stays shut below this tier
	keycard: boolean?, -- a keycard shortcut door between tiers (spec 4.3)
}

export type Ramp = {
	from: string, -- the lower level; it climbs to the next one up
	x: number, -- centre line (for a ramp climbing along z) or start x (along x)
	z: number, -- start z (lower end) for a ramp climbing along z, or centre line for one along x
	dir: string, -- "+z", "-z", "+x" or "-x": the way it climbs
	turn: boolean?, -- a switchback: it climbs half way, turns at a landing and climbs back to arrive beside where it began
}

export type Marker = { id: string, level: string, x: number, z: number }

-- Things that are not rooms: water, garden islands, bridges, a skylight, a waterfall, a statue, lanterns, a pavilion.
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
}

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

local OUT, IN = "outdoor", "indoor"

-- Footprints (referenced by the terrace rings).
local FG = { -120, -150, 120, 130 } -- tower at ground and basement
local FM = { -105, -135, 105, 115 } -- mezzanine
local FT = { -75, -105, 75, 85 } -- top floor and roof
local VOID = { -38, -35, 38, 45 } -- the atrium void, with the pond at its foot

-- B: basement (-24) -------------------------------------------------------------------------------------------------
room("b_west_n", "B", "West storage north", 1, IN, { -120, -150, -75, -10 }, { props = { "crates" } })
room("b_west_s", "B", "West storage south", 1, IN, { -120, -10, -75, 130 }, { props = { "crates" } })
room("b_east_n", "B", "East storage north", 1, IN, { 75, -150, 120, -10 }, { props = { "crates" } })
room("b_east_s", "B", "East storage south", 1, IN, { 75, -10, 120, 130 }, { props = { "crates" } })
room("b_north", "B", "North security corridor", 2, IN, { -75, -150, 75, -60 }, { props = { "pillars" } })
room("b_south", "B", "South security corridor", 2, IN, { -75, 40, 75, 130 }, { props = { "pillars" } })
room("b_west", "B", "West security corridor", 2, IN, { -75, -60, -30, 40 })
room("b_east", "B", "East security corridor", 2, IN, { 30, -60, 75, 40 })
room("b_vaulta_ante", "B", "Vault A antechamber", 2, IN, { -30, 0, 30, 40 })
room("b_vaulta", "B", "Vault A", 3, IN, { -30, -60, 30, 0 }, { density = 0.5 })

-- G: ground (0). Entirely indoors: the tower footprint, with windows onto the cityscape. -------------------------------------------
room(
	"g_dock",
	"G",
	"Loading bay",
	1,
	IN,
	{ -120, -150, -80, -50 },
	{ glass = true, density = 0.7, props = { "crates", "trucks" } }
)
room("g_kitchen", "G", "Kitchen", 1, IN, { -80, -150, -40, -50 }, { density = 1.2, props = { "islands" } })
room("g_service", "G", "Service corridor", 1, IN, { -40, -150, 40, -50 }, { props = { "pillars" } })
room("g_catering", "G", "Catering prep", 1, IN, { 40, -150, 80, -50 }, { glass = true, props = { "islands" } })
room("g_vaultc_ante", "G", "Vault C antechamber", 2, IN, { 80, -90, 120, -50 })
room("g_vaultc", "G", "Vault C", 3, IN, { 80, -150, 120, -90 }, { density = 0.5 })
room("g_sculpt", "G", "Sculpture hall", 0, IN, { -120, -50, -60, 70 }, { glass = true, props = { "partitions" } })
room("g_ballroom", "G", "Ballroom", 0, IN, { -60, -50, 60, 70 }, { density = 2, props = { "pillars", "tables" } })
room("g_lounge", "G", "Smoking lounge", 0, IN, { 60, -50, 120, 70 }, { glass = true, props = { "tables" } })
room("g_humidor", "G", "Humidor", 1, IN, { 90, 30, 120, 70 }, { parent = "g_lounge" })
room("g_coat", "G", "Coat check", 1, IN, { -120, 70, -80, 130 }, { glass = true, props = { "desks" } })
room(
	"g_lobby",
	"G",
	"Grand lobby",
	0,
	IN,
	{ -80, 70, 50, 130 },
	{ glass = true, density = 1.5, props = { "reception", "pillars" } }
)
room("g_concierge", "G", "Concierge office", 1, IN, { -80, 100, -50, 130 }, { parent = "g_lobby", props = { "desks" } })
room(
	"g_bar",
	"G",
	"Cocktail bar",
	0,
	IN,
	{ 50, 70, 120, 130 },
	{ glass = true, density = 1.5, props = { "bar", "tables" } }
)

-- M: mezzanine (24) -----------------------------------------------------------------------------------------------------
room(
	"m_gallery",
	"M",
	"Grand gallery",
	0,
	IN,
	{ -105, -45, -45, 115 },
	{ glass = true, density = 1.5, props = { "partitions" } }
)
room(
	"m_promenade",
	"M",
	"Sculpture promenade",
	0,
	IN,
	{ -45, 55, 45, 115 },
	{ glass = true, props = { "planters", "pillars" } }
)
room("m_balcony", "M", "Atrium balcony", 0, IN, { -45, -45, 45, 55 }, { density = 1.2 })
room(
	"m_masq",
	"M",
	"Masquerade hall",
	0,
	IN,
	{ 45, -45, 105, 115 },
	{ glass = true, density = 2, props = { "stage", "pillars", "tables" } }
)
room("m_offices", "M", "Staff offices", 1, IN, { -105, -135, -15, -45 }, { glass = true, props = { "desks" } })
room("m_checkpoint", "M", "Security checkpoint", 2, IN, { -75, -80, -45, -45 }, { parent = "m_offices" })
room("m_hub", "M", "Security hub", 2, IN, { -15, -135, 45, -45 }, { props = { "desks" } })
room("m_records", "M", "Executive records", 3, IN, { 15, -135, 45, -100 }, { parent = "m_hub", density = 0.5 })
room("m_cater", "M", "Catering offices", 1, IN, { 45, -135, 105, -45 }, { props = { "desks" } })
room(
	"m_terrace",
	"M",
	"Mezzanine terrace",
	0,
	OUT,
	FG,
	{ holes = { FM }, density = 1, props = { "planters", "tables", "trees" } }
)

room("m_skybridge", "M", "Skybridge", 0, OUT, { 120, 29, 138, 35 }, { density = 0.3 })
room(
	"m_belvedere",
	"M",
	"Garden lawn deck",
	0,
	OUT,
	{ 138, 0, 198, 90 },
	{ density = 1.2, props = { "trees", "planters", "tables" } }
)

-- T: top floor (48) -----------------------------------------------------------------------------------------------------
room("t_great", "T", "Penthouse great room", 3, IN, { -45, -45, 45, 55 }, { glass = true, density = 1 })
room("t_gallery", "T", "Private gallery", 3, IN, { -45, 55, 45, 85 }, { glass = true, props = { "partitions" } })
room("t_vaultb_ante", "T", "Vault B antechamber", 2, IN, { -45, -75, 45, -45 })
room("t_vaultb", "T", "Vault B", 3, IN, { -45, -105, 45, -75 }, { density = 0.5 })
room("t_west", "T", "West guard hall", 2, IN, { -75, -105, -45, 85 }, { props = { "pillars" } })
room("t_panic", "T", "Panic room", 3, IN, { -75, 20, -45, 45 }, { parent = "t_west", density = 0.5 })
room("t_east", "T", "East guard hall", 2, IN, { 45, -105, 75, 85 }, { props = { "pillars" } })
room("t_office", "T", "Executive office", 3, IN, { 45, 20, 75, 45 }, { parent = "t_east", density = 0.5 })
room(
	"t_terrace",
	"T",
	"Upper terrace",
	0,
	OUT,
	FM,
	{ holes = { FT }, density = 1, props = { "planters", "tables", "trees" } }
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

-- The atrium: an open shaft through the mezzanine and top floors down to the pond, with railings round it.
local voids = {
	{ level = "M", rect = VOID },
	{ level = "T", rect = VOID },
}

-- Stairs. Narrow (6 wide). A plain run climbs 24 over 48 studs; a switchback (turn) climbs half, turns at a landing and
-- climbs back to arrive beside where it began, in 14 x 30. Each lies inside one room on the lower level and one above,
-- with open floor beyond the arrival so there is a way left and right.
local ramps: { Ramp } = {
	-- B -> G
	{ from = "B", x = -30, z = 110, dir = "-z", turn = true },
	{ from = "B", x = -97, z = 110, dir = "-z", turn = true },
	{ from = "B", x = 97, z = 110, dir = "-z", turn = true },
	{ from = "B", x = 0, z = -120, dir = "+z", turn = true },
	-- G -> M: the grand stair along the atrium, then wing and service stairs
	{ from = "G", x = -44, z = -40, dir = "+x" },
	{ from = "G", x = -85, z = 0, dir = "+z", turn = true },
	{ from = "G", x = 85, z = 0, dir = "+z", turn = true },
	{ from = "G", x = -5, z = -110, dir = "+z", turn = true },
	{ from = "G", x = 62, z = -118, dir = "+z", turn = true },
	-- M -> T
	{ from = "M", x = -66, z = -20, dir = "+z", turn = true },
	{ from = "M", x = 66, z = -20, dir = "+z", turn = true },
	-- T -> R
	{ from = "T", x = -60, z = -90, dir = "+z", turn = true },
	{ from = "T", x = 60, z = -90, dir = "+z", turn = true },
}

-- Doors: { a, b, at, width, options }. `at` is x for a wall that runs along x, and z for one that runs along z.
local doors: { Door } = {}
local function door(a: string, b: string, at: number?, width: number?, extra: { [string]: any }?)
	local d: any = { a = a, b = b, at = at, width = width }
	for key, value in extra or {} do
		d[key] = value
	end
	table.insert(doors, d :: Door)
end

-- B
door("b_west_n", "b_west_s", -97, 8)
door("b_east_n", "b_east_s", 97, 8)
door("b_west_n", "b_north", -100, 8, { keycard = true })
door("b_east_n", "b_north", 100, 8, { keycard = true })
door("b_west_s", "b_south", 80, 8)
door("b_east_s", "b_south", 80, 8)
door("b_west_s", "b_west", 15, 8)
door("b_east_s", "b_east", 15, 8)
door("b_north", "b_west", -52, 10)
door("b_north", "b_east", 52, 10)
door("b_south", "b_west", -52, 10)
door("b_south", "b_east", 52, 10)
door("b_west", "b_vaulta_ante", 20, 8)
door("b_east", "b_vaulta_ante", 20, 8)
door("b_south", "b_vaulta_ante", 0, 10)
door("b_vaulta_ante", "b_vaulta", 0, 8, { gate = 3 })
door("b_west", "b_vaulta", -30, 8, { gate = 3 })

-- G
door("g_coat", "g_lobby", 85, 8)
door("g_lobby", "g_bar", 100, 12)
door("g_lobby", "g_concierge", -65, 6, { gate = 1 })
door("g_lobby", "g_ballroom", -10, 14)
door("g_lobby", "g_ballroom", 30, 10)
door("g_coat", "g_sculpt", -100, 8)
door("g_lobby", "g_sculpt", -70, 8)
door("g_bar", "g_lounge", 75, 10)
door("g_sculpt", "g_ballroom", 10, 12)
door("g_lounge", "g_ballroom", 10, 12)
door("g_sculpt", "g_dock", -100, 10)
door("g_dock", "g_kitchen", -100, 12)
door("g_dock", "g_kitchen", -70, 8)
door("g_sculpt", "g_kitchen", -70, 8, { keycard = true })
door("g_ballroom", "g_service", 0, 10, { keycard = true })
door("g_lounge", "g_catering", 70, 8)
door("g_lounge", "g_humidor", 45, 6, { gate = 1 })
door("g_lounge", "g_vaultc_ante", 100, 8, { gate = 2 })
door("g_kitchen", "g_service", -100, 10)
door("g_service", "g_catering", -100, 10)
door("g_catering", "g_vaultc_ante", -70, 8, { gate = 2 })
door("g_vaultc_ante", "g_vaultc", 100, 8, { gate = 3 })

-- M
door("m_terrace", "m_gallery", 40, 10)
door("m_terrace", "m_gallery", -20, 8)
door("m_terrace", "m_promenade", 0, 12)
door("m_terrace", "m_masq", 30, 10)
door("m_terrace", "m_masq", 75, 12)
door("m_terrace", "m_offices", -90, 8)
door("m_terrace", "m_offices", -60, 8)
door("m_terrace", "m_cater", -90, 8)
door("m_gallery", "m_balcony", 10, 12)
door("m_gallery", "m_balcony", -30, 8)
door("m_promenade", "m_balcony", 0, 14)
door("m_promenade", "m_balcony", -30, 8)
door("m_masq", "m_balcony", 10, 12)
door("m_masq", "m_balcony", -30, 8)
door("m_gallery", "m_promenade", 85, 10)
door("m_masq", "m_promenade", 85, 10)
door("m_offices", "m_gallery", -75, 8)
door("m_hub", "m_balcony", 15, 8)
door("m_cater", "m_masq", 75, 8)
door("m_offices", "m_hub", -90, 8, { keycard = true })
door("m_hub", "m_cater", -90, 8, { keycard = true })
door("m_offices", "m_checkpoint", -60, 8, { gate = 2 })
door("m_hub", "m_records", -115, 8, { gate = 3 })

-- T
door("t_terrace", "t_gallery", 0, 12, { gate = 3 })
door("t_terrace", "t_west", 0, 8)
door("t_terrace", "t_west", 50, 8)
door("t_terrace", "t_east", 0, 8)
door("t_great", "t_gallery", 0, 14)
door("t_great", "t_west", 10, 8)
door("t_great", "t_east", 10, 8)
door("t_gallery", "t_west", 70, 8)
door("t_gallery", "t_east", 70, 8)
door("t_great", "t_vaultb_ante", 0, 10, { gate = 2 })
door("t_vaultb_ante", "t_vaultb", 0, 8, { gate = 3 })
door("t_west", "t_vaultb_ante", -60, 8)
door("t_east", "t_vaultb_ante", -60, 8)
door("t_west", "t_panic", -60, 8, { gate = 3 })
door("t_east", "t_office", 60, 8, { gate = 3 })

-- Water, islands, bridges and set pieces. The atrium floor is a shallow reflecting pond at the foot of the open void, with two
-- garden islands joined to the south shore by short bridges; the lawn deck has a statue, lanterns and a glass pavilion.
local features: { Feature } = {
	{ kind = "pool", level = "G", rect = { -38, -35, 38, 45 } },
	{ kind = "island", level = "G", rect = { -32, -12, -16, 28 } },
	{ kind = "island", level = "G", rect = { 16, -12, 32, 28 } },
	{ kind = "bridge", level = "G", rect = { -26, 28, -20, 46 } },
	{ kind = "bridge", level = "G", rect = { 20, 28, 26, 46 } },
	{ kind = "skylight", level = "R", rect = VOID },
	{ kind = "statue", level = "M", x = 160, z = 45 },
	{
		kind = "lanterns",
		level = "M",
		points = { { 144, 8 }, { 144, 82 }, { 170, 8 }, { 170, 82 }, { 192, 8 }, { 192, 82 } },
	},
	{ kind = "pavilion", level = "M", rect = { 180, 14, 194, 76 }, count = 5 },
}

local nodes: { NodeSpec } = {
	{ level = "G", x = -24, z = 8, activity = "Idle" },
	{ level = "G", x = 24, z = 8, activity = "Talk" },
	{ level = "G", x = -23, z = 36, activity = "Walk" },
	{ level = "G", x = 23, z = 36, activity = "Walk" },
	{ level = "M", x = 126, z = 32, activity = "Walk" },
	{ level = "M", x = 134, z = 32, activity = "Walk" },
	{ level = "M", x = 142, z = 32, activity = "Walk" },
}

-- Places that are not rooms: where teams arrive and where the Package leaves (spec 4.3).
local extraction: { Marker } = {
	{ id = "Helipad", level = "R", x = 0, z = 50 },
	{ id = "LoadingDock", level = "G", x = -105, z = -135 },
	{ id = "GardenLawn", level = "M", x = 160, z = 60 },
}

-- Six on the ground floor and six on the mezzanine terrace, at least 80 apart.
local insertion: { Marker } = {
	{ id = "Insertion1", level = "G", x = -39, z = 76 },
	{ id = "Insertion2", level = "G", x = -115, z = 38 },
	{ id = "Insertion3", level = "G", x = 68, z = 49 },
	{ id = "Insertion4", level = "G", x = 28, z = -45 },
	{ id = "Insertion5", level = "G", x = 115, z = 124 },
	{ id = "Insertion6", level = "G", x = -44, z = -5 },
	{ id = "Insertion7", level = "M", x = -115, z = -46 },
	{ id = "Insertion8", level = "M", x = 109, z = -28 },
	{ id = "Insertion9", level = "M", x = 115, z = -135 },
	{ id = "Insertion10", level = "M", x = -111, z = 126 },
	{ id = "Insertion11", level = "M", x = 30, z = 122 },
	{ id = "Insertion12", level = "M", x = -113, z = -138 },
}

local vaults: { Marker } = {
	{ id = "VaultA", level = "B", x = 0, z = -30 },
	{ id = "VaultB", level = "T", x = 0, z = -90 },
	{ id = "VaultC", level = "G", x = 100, z = -120 },
}

return {
	levels = { B = -24, G = 0, M = 24, T = 48, R = 72 },
	levelOrder = { "B", "G", "M", "T", "R" },
	rooms = rooms,
	voids = voids,
	ramps = ramps,
	doors = doors,
	extraction = extraction,
	insertion = insertion,
	vaults = vaults,
	features = features,
	nodes = nodes,
}
