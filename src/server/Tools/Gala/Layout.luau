--!strict
-- The layout of "The Gala" as data (BUILD_ORDER Step 7B). Build.luau turns this into geometry, zones, doors and NPC nodes.
--
-- Two towers on the roofs of skyscrapers, high over a city: the Gala, and east of it across a 20-stud drop, the hotel
-- and casino wing. Their ground floors are entirely indoors with windows onto the city; the outdoor spaces are terraces,
-- decks and roofs above. Galleries (GH, 12 studs up) are open floors inside rooms: round the ballroom, over the bar, staff
-- catwalks over the kitchen and loading bay, and the casino's VIP tables.
--   B (-24)  basement: storage, security corridors, Vault A; the service tunnel; the wing's laundry, security and Vault D
--   G (0)    ground: lobby, ballroom and pond, bar, kitchen, loading bay, Vault C; the wing's casino, cage, high-roller lounge
--   M (24)   mezzanine: galleries, masquerade hall, offices, security hub, terrace ring; skybridge to the lawn deck and the
--            wing's hotel lobby
--   T (48)   top floor: penthouse, guard halls, Vault B, upper terrace; the wing's suites and balconies
--   R (72)   roof: the rooftop party with the helipad and a cantilevered pool deck; the catwalk to the wing's roof garden
--   X (96)   the wing's sky deck (an extraction site)
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
	kind: string, -- "indoor", "outdoor", or "gallery" (an open floor inside a room, on a gallery level)
	rect: Rect,
	parent: string?,
	holes: { Rect }?, -- areas cut out of this room (used by the terrace rings)
	density: number?, -- how many NPCs favour it; 1 is normal
	activities: { string }?, -- what NPC nodes in it do; defaults by tier
	props: { string }?, -- what fills it (see Build.luau)
	glass: boolean?, -- its walls facing a garden are glass above a low sill
	height: number?, -- an indoor room's wall height when it is lower than a full storey (a bridge)
	noNodes: boolean?, -- no NPC nodes (a vault strongroom: NPCs never stop at the vault)
	theme: string?, -- a vault's look: "bank", "gallery", "cold" or "counting"
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
}

export type Ramp = {
	from: string, -- the lower level
	to: string?, -- the level it climbs to: the next full level if not given, or a gallery level
	x: number, -- centre line (for a ramp climbing along z) or start x (along x)
	z: number, -- start z (lower end) for a ramp climbing along z, or centre line for one along x
	dir: string, -- "+z", "-z", "+x" or "-x": the way it climbs
	turn: boolean?, -- a switchback: it climbs half way, turns at a landing and climbs back to arrive beside where it began
}

export type Marker = { id: string, level: string, x: number, z: number }

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
}

-- Things placed in rooms (BUILD_ORDER Step 7B pass 2): Build.luau finds each a free spot along a wall of its room.
--   intel     an intel station; its type follows the room's tier (tablet, laptop cart, server rack, wall safe)
--   health    a wall health station (in the restrooms)        ammo    a wall ammo cache
--   food      a buffet with a plate of food                   safe    a safe holding an asset (rarity by room tier)
--   cache     a supply cache                                  camera  a security camera high on a wall
export type Placement = { kind: string, room: string }

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
local FG = { -120, -150, 120, 130 } -- tower at ground and basement
local FM = { -105, -135, 105, 115 } -- mezzanine
local FT = { -75, -105, 75, 85 } -- top floor and roof
local VOID = { -38, -35, 38, 45 } -- the atrium void, with the pond at its foot
local FW = { 140, -70, 240, 110 } -- the wing, at ground and basement

-- The towers' outlines at ground level: each stands on its own skyscraper in the city.
local towers: { Rect } = { FG, FW }

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
room("b_vaulta", "B", "Vault A", 3, IN, { -30, -60, 30, 0 }, { density = 0.5, theme = "bank" })
room("b_vaulta_core", "B", "Vault A strongroom", 3, IN, { -15, -60, 15, -35 }, { parent = "b_vaulta", noNodes = true })

-- G: ground (0). Entirely indoors: the tower footprint, with windows onto the cityscape. -------------------------------------------
room(
	"g_dock",
	"G",
	"Loading bay",
	1,
	IN,
	{ -120, -85, -80, -50 },
	{ glass = true, density = 0.7, props = { "crates" } }
)
room("g_vaultc_ante", "G", "Vault C antechamber", 2, IN, { -120, -115, -80, -85 })
room("g_vaultc", "G", "Vault C", 3, IN, { -120, -150, -80, -115 }, { density = 0.5, theme = "cold" })
room(
	"g_vaultc_core",
	"G",
	"Vault C strongroom",
	3,
	IN,
	{ -120, -150, -95, -130 },
	{ parent = "g_vaultc", noNodes = true }
)
room("g_kitchen", "G", "Kitchen", 1, IN, { -80, -150, -40, -50 }, { density = 1.2, props = { "islands" } })
room("g_service", "G", "Service corridor", 1, IN, { -40, -150, 40, -50 }, { props = { "pillars" } })
room("g_catering", "G", "Catering prep", 1, IN, { 40, -150, 80, -50 }, { glass = true, props = { "islands" } })
room("g_breakroom", "G", "Staff break room", 1, IN, { 80, -90, 120, -50 }, { glass = true, props = { "tables" } })
room("g_cold", "G", "Cold storage", 1, IN, { 80, -150, 120, -90 }, { props = { "crates" } })
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
room("g_restroom", "G", "Lobby restrooms", 0, IN, { 25, 110, 50, 130 }, { parent = "g_lobby" })
room("g_staffwc", "G", "Staff washroom", 1, IN, { 20, -150, 40, -132 }, { parent = "g_service" })
room(
	"g_bar",
	"G",
	"Cocktail bar",
	0,
	IN,
	{ 50, 70, 120, 130 },
	{ glass = true, density = 1.5, props = { "bar", "tables" } }
)

-- GH: galleries (12) ------------------------------------------------------------------------------------------------------
room("gh_ballroom", "GH", "Ballroom gallery", 0, GALLERY, { -58, 52, 58, 68 }, { density = 1.2, props = { "tables" } })
room("gh_bar", "GH", "Bar loft", 0, GALLERY, { 52, 112, 118, 128 }, { density = 1, props = { "tables" } })
room("gh_kitchen", "GH", "Kitchen catwalk", 1, GALLERY, { -78, -148, -42, -140 })
room("gh_dock", "GH", "Loading bay catwalk", 1, GALLERY, { -120, -83, -110, -52 })
room("gh_vip", "GH", "VIP tables", 0, GALLERY, { 140, 72, 175, 110 }, { density = 1.2, props = { "tables" } })

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
room("m_restroom", "M", "Gallery restrooms", 0, IN, { -105, 95, -85, 115 }, { parent = "m_gallery" })
room(
	"m_terrace",
	"M",
	"Mezzanine terrace",
	0,
	OUT,
	FG,
	{ holes = { FM }, density = 1, props = { "planters", "tables", "trees" } }
)

-- An enclosed glass skybridge to the lawn deck, like the links between hospital wings, carried on a steel truss.
room("m_skybridge", "M", "Skybridge", 0, IN, { 120, 26, 140, 38 }, { glass = true, height = 12, density = 0.3 })
room(
	"m_belvedere",
	"M",
	"Garden lawn deck",
	0,
	OUT,
	{ 140, -10, 180, 110 },
	{ density = 1.2, props = { "trees", "planters", "tables" } }
)

-- The wing (hotel and casino) --------------------------------------------------------------------------------------------
-- B: the service tunnel from the Gala's east storage, laundry, wing security and Vault D.
room("b_tunnel", "B", "Service tunnel", 1, IN, { 120, 20, 140, 32 }, { height = 12, density = 0.3 })
room("wb_laundry", "B", "Hotel laundry", 1, IN, { 140, -10, 190, 50 }, { props = { "crates" } })
room("wb_service", "B", "Hotel service corridor", 1, IN, { 140, 50, 240, 110 }, { props = { "pillars" } })
room("wb_security", "B", "Wing security office", 2, IN, { 140, -70, 190, -10 }, { props = { "desks" } })
room("wb_vaultd_ante", "B", "Vault D antechamber", 2, IN, { 190, -10, 240, 50 })
room("wb_vaultd", "B", "Vault D", 3, IN, { 190, -70, 240, -10 }, { density = 0.5, theme = "counting" })
room(
	"wb_vaultd_core",
	"B",
	"Vault D strongroom",
	3,
	IN,
	{ 215, -70, 240, -45 },
	{ parent = "wb_vaultd", noNodes = true }
)
-- G: the casino floor, the cashier's cage and the high-roller lounge.
room(
	"wg_casino",
	"G",
	"Casino floor",
	0,
	IN,
	{ 140, 10, 240, 110 },
	{ glass = true, density = 2, props = { "pillars", "tables" } }
)
room("wg_cage", "G", "Cashier's cage", 1, IN, { 140, -70, 180, 10 }, { glass = true, props = { "desks" } })
room("wg_restroom", "G", "Casino restrooms", 0, IN, { 215, 90, 240, 110 }, { parent = "wg_casino" })
room("wg_highroller", "G", "High-roller lounge", 3, IN, { 180, -70, 240, 10 }, { glass = true, props = { "tables" } })
-- M: the hotel lobby and corridor beside the lawn deck, and housekeeping.
room(
	"wm_lobby",
	"M",
	"Hotel lobby",
	0,
	IN,
	{ 180, 40, 240, 110 },
	{ glass = true, density = 1.5, props = { "reception" } }
)
room("wm_restroom", "M", "Hotel restrooms", 0, IN, { 220, 90, 240, 110 }, { parent = "wm_lobby" })
room("wm_corridor", "M", "Hotel corridor", 0, IN, { 180, -10, 240, 40 }, { glass = true, props = { "planters" } })
room("wm_housekeeping", "M", "Housekeeping", 1, IN, { 140, -70, 240, -10 }, { glass = true, props = { "crates" } })
-- T: suites either side of a hallway, with balconies over the lawn deck.
room("wt_hall", "T", "Suite hallway", 0, IN, { 200, -70, 220, 110 })
room("wt_suite1", "T", "Garden suite", 0, IN, { 180, 50, 200, 110 }, { glass = true, props = { "tables" } })
room("wt_suite2", "T", "Corner suite", 0, IN, { 180, -10, 200, 50 }, { glass = true, props = { "tables" } })
room("wt_suite3", "T", "Skyline suite", 0, IN, { 180, -70, 200, -10 }, { glass = true, props = { "tables" } })
room("wt_suite4", "T", "City suite", 0, IN, { 220, 50, 240, 110 }, { glass = true, props = { "tables" } })
room("wt_suite5", "T", "Moon suite", 0, IN, { 220, -10, 240, 50 }, { glass = true, props = { "tables" } })
room("wt_exec", "T", "Executive suite", 3, IN, { 220, -70, 240, -10 }, { glass = true, density = 0.5 })
room("wt_balcony1", "T", "Garden suite balcony", 0, OUT, { 172, 60, 180, 100 }, { density = 0.3 })
room("wt_balcony2", "T", "Corner suite balcony", 0, OUT, { 172, 0, 180, 40 }, { density = 0.3 })
room("wt_balcony3", "T", "Skyline suite balcony", 0, OUT, { 172, -60, 180, -20 }, { density = 0.3 })
-- R: the roof garden and the plant room under the sky deck.
room(
	"wr_garden",
	"R",
	"Wing roof garden",
	0,
	OUT,
	{ 180, 20, 240, 110 },
	{ density = 1.5, props = { "trees", "planters", "bar" } }
)
room("wr_plant", "R", "Rooftop plant room", 1, IN, { 180, -70, 240, 20 }, { props = { "crates" } })
-- X: the sky deck, the wing's top and an extraction site.
room("wx_skydeck", "X", "Sky deck", 0, OUT, { 180, -70, 240, 20 }, { density = 0.8, props = { "planters" } })

-- T: top floor (48) -----------------------------------------------------------------------------------------------------
room("t_great", "T", "Penthouse great room", 3, IN, { -45, -45, 45, 55 }, { glass = true, density = 1 })
room("t_gallery", "T", "Private gallery", 3, IN, { -45, 55, 45, 85 }, { glass = true, props = { "partitions" } })
room("t_vaultb_ante", "T", "Vault B antechamber", 2, IN, { -45, -75, 45, -45 }, { props = { "vitrines" } })
room("t_vaultb", "T", "Vault B", 3, IN, { -45, -105, 45, -75 }, { density = 0.5, theme = "gallery" })
room("t_vaultb_core", "T", "Vault B strongroom", 3, IN, { -15, -105, 15, -90 }, { parent = "t_vaultb", noNodes = true })
room("t_west", "T", "West guard hall", 2, IN, { -75, -105, -45, 85 }, { props = { "pillars" } })
room("t_panic", "T", "Panic room", 3, IN, { -75, 20, -45, 45 }, { parent = "t_west", density = 0.5 })
room("t_east", "T", "East guard hall", 2, IN, { 45, -105, 75, 85 }, { props = { "pillars" } })
room("t_office", "T", "Executive office", 3, IN, { 45, 20, 75, 45 }, { parent = "t_east", density = 0.5 })
room("t_washroom", "T", "Guard washroom", 2, IN, { 55, 60, 75, 85 }, { parent = "t_east" })
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
room(
	"r_pooldeck",
	"R",
	"Cantilevered pool deck",
	0,
	OUT,
	{ -150, -40, -75, 60 },
	{ density = 1.5, props = { "planters", "tables" } }
)
-- An open catwalk from the roof to the wing's roof garden.
room("r_catwalk", "R", "Roof catwalk", 0, OUT, { 75, 30, 180, 36 }, { density = 0.2 })

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
	{ from = "B", x = 25, z = -120, dir = "+z", turn = true },
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
	-- Half stairs up to the galleries (they climb beside a gallery and arrive over its edge)
	{ from = "G", to = "GH", x = -50, z = 28, dir = "+z" },
	{ from = "G", to = "GH", x = 110, z = 88, dir = "+z" },
	{ from = "G", to = "GH", x = -50, z = -116, dir = "-z" },
	{ from = "G", to = "GH", x = -86, z = -62, dir = "-x" },
	{ from = "G", to = "GH", x = 170, z = 48, dir = "+z" },
	-- The wing
	{ from = "B", x = 160, z = 100, dir = "-z", turn = true },
	{ from = "G", x = 210, z = 80, dir = "-z", turn = true },
	{ from = "G", x = 160, z = -20, dir = "-z", turn = true },
	{ from = "M", x = 210, z = 33, dir = "-z", turn = true },
	{ from = "T", x = 210, z = 100, dir = "-z", turn = true },
	{ from = "R", x = 210, z = -60, dir = "+z", turn = true },
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
door("b_vaulta_ante", "b_vaulta", 0, 8, { gate = 3, laser = true })
door("b_west", "b_vaulta", -30, 8, { gate = 3 })
door("b_vaulta", "b_vaulta_core", 0, 8, { vault = "VaultA" })

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
door("g_dock", "g_kitchen", -78, 8)
door("g_dock", "g_vaultc_ante", -100, 8, { gate = 2 })
door("g_kitchen", "g_vaultc_ante", -100, 8, { gate = 2 })
door("g_vaultc_ante", "g_vaultc", -100, 8, { gate = 3, laser = true })
door("g_kitchen", "g_vaultc", -122, 8, { gate = 3 })
door("g_vaultc", "g_vaultc_core", -108, 8, { vault = "VaultC" })
door("g_lobby", "g_restroom", 38, 6)
door("g_service", "g_staffwc", -141, 6)
door("g_sculpt", "g_kitchen", -70, 8, { keycard = true })
door("g_ballroom", "g_service", 0, 10, { keycard = true })
door("g_lounge", "g_catering", 70, 8)
door("g_lounge", "g_humidor", 45, 6, { gate = 1 })
door("g_lounge", "g_breakroom", 100, 8)
door("g_kitchen", "g_service", -100, 10)
door("g_service", "g_catering", -100, 10)
door("g_catering", "g_breakroom", -70, 8)
door("g_breakroom", "g_cold", 100, 8)
door("g_catering", "g_cold", -120, 8)

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
door("m_gallery", "m_restroom", -95, 6)

door("m_terrace", "m_skybridge", 32, 10)
door("m_skybridge", "m_belvedere", 32, 10)

-- The wing
door("b_east_s", "b_tunnel", 26, 10)
door("b_tunnel", "wb_laundry", 26, 10)
door("wb_laundry", "wb_service", 165, 10)
door("wb_laundry", "wb_security", 165, 8)
door("wb_laundry", "wb_vaultd_ante", 20, 8, { gate = 2 })
door("wb_service", "wb_vaultd_ante", 215, 8, { gate = 2 })
door("wb_vaultd_ante", "wb_vaultd", 215, 8, { gate = 3, laser = true })
door("wb_security", "wb_vaultd", -40, 8, { gate = 3 })
door("wb_vaultd", "wb_vaultd_core", 227, 8, { vault = "VaultD" })
door("wg_casino", "wg_restroom", 227, 6)
door("wm_lobby", "wm_restroom", 227, 6)
door("wg_casino", "wg_cage", 160, 8)
door("wg_casino", "wg_highroller", 210, 10)
door("wg_cage", "wg_highroller", -30, 8)
door("m_belvedere", "wm_lobby", 75, 12)
door("m_belvedere", "wm_corridor", 15, 8)
door("wm_lobby", "wm_corridor", 230, 10)
door("wm_corridor", "wm_housekeeping", 210, 8)
door("m_belvedere", "wm_housekeeping", 172, 8)
door("wt_hall", "wt_suite1", 60, 8)
door("wt_hall", "wt_suite2", 45, 8)
door("wt_hall", "wt_suite3", -40, 8)
door("wt_hall", "wt_suite4", 60, 8)
door("wt_hall", "wt_suite5", 45, 8)
door("wt_hall", "wt_exec", -40, 8)
door("wt_suite5", "wt_exec", 230, 8)
door("wt_suite1", "wt_balcony1", 80, 8)
door("wt_suite2", "wt_balcony2", 20, 8)
door("wt_suite3", "wt_balcony3", -40, 8)
door("wr_garden", "wr_plant", 200, 8)
door("wr_garden", "wr_plant", 230, 8)

-- T
door("t_terrace", "t_gallery", 0, 12, { gate = 3 })
door("t_terrace", "t_west", 0, 8)
door("t_terrace", "t_west", 50, 8)
door("t_terrace", "t_east", -40, 8)
door("t_great", "t_gallery", 0, 14)
door("t_great", "t_west", 10, 8)
door("t_great", "t_east", 10, 8)
door("t_gallery", "t_west", 70, 8)
door("t_gallery", "t_east", 70, 8)
door("t_great", "t_vaultb_ante", 0, 10, { gate = 2 })
door("t_vaultb_ante", "t_vaultb", 0, 8, { gate = 3, laser = true })
door("t_vaultb", "t_vaultb_core", 0, 8, { vault = "VaultB" })
door("t_east", "t_washroom", 65, 6)
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
	{ kind = "statue", level = "M", x = 156, z = 45 },
	{
		kind = "lanterns",
		level = "M",
		points = { { 144, -6 }, { 144, 106 }, { 176, -6 }, { 176, 106 }, { 144, 50 }, { 176, 50 } },
	},
	{ kind = "pavilion", level = "M", rect = { 166, 14, 178, 76 }, count = 5 },
	{ kind = "truss", level = "M", rect = { 120, 26, 140, 38 } },
	{ kind = "truss", level = "B", rect = { 120, 20, 140, 32 } },
	-- The pool deck reaches past the tower's west edge on a truss, with a pool and a row of cabanas.
	{ kind = "truss", level = "R", rect = { -150, -40, -120, 60 } },
	{ kind = "pool", level = "R", rect = { -145, -30, -125, 10 } },
	{ kind = "pavilion", level = "R", rect = { -142, 22, -130, 56 }, count = 3 },
}

local placements: { Placement } = {}
local function place(kind: string, list: { string })
	for _, roomId in list do
		table.insert(placements, { kind = kind, room = roomId })
	end
end
-- 32 intel stations, 8 per tier; the room's tier sets the type.
place("intel", { "g_lobby", "g_ballroom", "g_bar", "g_sculpt", "m_gallery", "m_masq", "wg_casino", "wm_lobby" })
place(
	"intel",
	{ "g_kitchen", "g_service", "g_catering", "g_coat", "m_offices", "m_cater", "wb_laundry", "wm_housekeeping" }
)
place("intel", { "b_north", "b_south", "b_west", "b_east", "m_hub", "t_west", "t_east", "wb_security" })
place("intel", { "t_great", "t_great", "t_gallery", "t_office", "t_panic", "m_records", "wg_highroller", "wt_exec" })
place("health", { "g_restroom", "g_staffwc", "m_restroom", "t_washroom", "wm_restroom", "wg_restroom" })
place("ammo", { "g_service", "g_dock", "m_hub", "b_north", "t_west", "wg_cage", "wm_corridor", "wt_hall" })
-- Food: plenty where the party is, little in the guard areas.
place(
	"food",
	{ "g_ballroom", "g_ballroom", "g_ballroom", "g_bar", "g_bar", "g_lounge", "m_masq", "m_masq", "m_promenade" }
)
place("food", { "wg_casino", "wg_casino", "wm_lobby", "wr_garden", "wr_garden", "r_roof", "r_roof", "g_kitchen" })
place("food", { "g_kitchen", "wt_suite1", "t_great" })
-- Safes: four each in Staff, Security and Executive rooms.
place("safe", { "g_coat", "m_cater", "wb_laundry", "wr_plant" })
place("safe", { "b_east", "m_checkpoint", "t_east", "wb_security" })
place("safe", { "t_office", "t_panic", "wg_highroller", "wt_exec" })
place("cache", { "g_sculpt", "m_balcony", "t_terrace", "wg_cage", "b_west_s", "wr_garden" })
place("camera", { "g_service", "g_kitchen", "g_dock", "m_hub", "m_offices", "b_north", "b_south", "t_west", "t_east" })
place("camera", { "wb_service", "wg_cage", "wm_housekeeping" })

local nodes: { NodeSpec } = {
	{ level = "G", x = -24, z = 8, activity = "Idle" },
	{ level = "G", x = 24, z = 8, activity = "Talk" },
	{ level = "G", x = -23, z = 36, activity = "Walk" },
	{ level = "G", x = 23, z = 36, activity = "Walk" },
	{ level = "M", x = 126, z = 32, activity = "Walk" },
	{ level = "M", x = 134, z = 32, activity = "Walk" },
	{ level = "M", x = 142, z = 32, activity = "Walk" },
	{ level = "B", x = 126, z = 26, activity = "Walk" },
	{ level = "B", x = 134, z = 26, activity = "Walk" },
	{ level = "R", x = 100, z = 33, activity = "Walk" },
	{ level = "R", x = 130, z = 33, activity = "Walk" },
	{ level = "R", x = 160, z = 33, activity = "Walk" },
}

-- Places that are not rooms: where teams arrive and where the Package leaves (spec 4.3).
local extraction: { Marker } = {
	{ id = "Helipad", level = "R", x = 0, z = 50 },
	{ id = "WingRoof", level = "X", x = 210, z = -25 },
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
	{ id = "VaultA", level = "B", x = 0, z = -47.5 },
	{ id = "VaultB", level = "T", x = 0, z = -97.5 },
	{ id = "VaultC", level = "G", x = -107.5, z = -140 },
	{ id = "VaultD", level = "B", x = 227.5, z = -57.5 },
}

return {
	levels = { B = -24, G = 0, GH = 12, M = 24, T = 48, R = 72, X = 96 },
	levelOrder = { "B", "G", "M", "T", "R", "X" }, -- full storeys; GH is a gallery level
	towers = towers,
	rooms = rooms,
	voids = voids,
	ramps = ramps,
	doors = doors,
	extraction = extraction,
	insertion = insertion,
	vaults = vaults,
	features = features,
	placements = placements,
	nodes = nodes,
}
