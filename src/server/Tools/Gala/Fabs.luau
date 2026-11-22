--!strict
-- Placeholder furniture "fabs" and room recipes (owner 2026-11-22: fill the whole room with fabs that make sense and feel real, with or without an art pass).
--
-- A fab is a small named assembly of plain parts (a dining table with its chairs, a bunk, a washer row) described as data: its footprint (w along x,
-- d along z, front toward +z, back toward -z) and its parts in that frame. A recipe says what a kind of room holds: ordered steps that place fabs
-- against the walls (back to the wall) or on open floor (as groups with aisles round them). Build.luau runs a room's recipe with the generator's own
-- placement helpers (passed in as ctx), so every fab respects doorways, windows, stairs, glass walls and what is already placed. An art pass can
-- replace a fab by id (swap its parts for a model) without touching placement, aisles or the task stops NPCs use.
--
--   Fabs.furnish(room, archetype, ctx)    fills the room from the archetype's recipe
--   Fabs.has(archetype) -> boolean
--
-- ctx (from Build.luau): levels, propsFolder, part(parent, name, size, cframe, color), alongWalls(room, spacing, width, depth, limit, place),
-- group(room, w, d, limit, packed, build), span(room), coverage(room) -> fraction of the floor covered so far, addStop(room, x, z, activity, faceX, faceZ), stopBefore(room, spot, depth, activity), stopsPerKind, stopClear.

local V = Vector3.new
local RAD90 = math.rad(90)

type Spec = {
	kind: string, -- "box", "cyl" or "ball"
	n: string,
	size: Vector3,
	p: Vector3,
	c: string, -- a palette key
	m: Enum.Material?,
	solid: boolean?,
	rot: CFrame?,
	clear: number?, -- transparency
}
type Sub = { any } -- { fabId, x, z, ry?, y? }
type Fab = { w: number, d: number, parts: { Spec }?, subs: { Sub }?, stop: string?, flat: boolean? }

-- Part constructors -----------------------------------------------------------------------------------------------------------------------------
local function B(
	n: string,
	sx: number,
	sy: number,
	sz: number,
	px: number,
	py: number,
	pz: number,
	c: string,
	m: Enum.Material?,
	solid: boolean?
): Spec
	return { kind = "box", n = n, size = V(sx, sy, sz), p = V(px, py, pz), c = c, m = m, solid = solid }
end
-- An upright cylinder standing on `lift` above the floor.
local function U(
	n: string,
	dia: number,
	h: number,
	px: number,
	pz: number,
	lift: number,
	c: string,
	m: Enum.Material?,
	solid: boolean?
): Spec
	return {
		kind = "cyl",
		n = n,
		size = V(h, dia, dia),
		p = V(px, lift + h / 2, pz),
		c = c,
		m = m,
		solid = solid,
		rot = CFrame.Angles(0, 0, RAD90),
	}
end
-- A horizontal cylinder along x.
local function Hx(
	n: string,
	len: number,
	dia: number,
	px: number,
	py: number,
	pz: number,
	c: string,
	m: Enum.Material?
): Spec
	return { kind = "cyl", n = n, size = V(len, dia, dia), p = V(px, py, pz), c = c, m = m, solid = false }
end
local function O(
	n: string,
	dia: number,
	px: number,
	py: number,
	pz: number,
	c: string,
	m: Enum.Material?,
	solid: boolean?
): Spec
	return { kind = "ball", n = n, size = V(dia, dia, dia), p = V(px, py, pz), c = c, m = m, solid = solid }
end
local function glass(spec: Spec): Spec
	spec.clear = 0.5
	spec.solid = false
	return spec
end

local FAB = Enum.Material.Fabric
local WOODM = Enum.Material.Wood
local METALM = Enum.Material.Metal
local NEON = Enum.Material.Neon
local GLASSM = Enum.Material.Glass
local MARBLE = Enum.Material.Marble
local PLASTIC = Enum.Material.SmoothPlastic

-- Palettes: a base and a few styles. A palette value is one colour or a list (one is picked per use; "fabric" is picked once per room so a room is coherent).
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
local base: { [string]: any } = {
	wood = rgb(120, 85, 58),
	dark = rgb(62, 43, 33),
	fabric = { rgb(110, 40, 50), rgb(45, 70, 100), rgb(70, 85, 60), rgb(95, 80, 65), rgb(60, 55, 75) },
	fabric2 = rgb(150, 120, 50),
	steel = rgb(172, 177, 184),
	brass = rgb(190, 150, 70),
	stone = rgb(190, 188, 182),
	cloth = rgb(235, 230, 220),
	glass = rgb(190, 220, 240),
	neon = rgb(90, 220, 255),
	warm = rgb(255, 214, 150),
	white = rgb(232, 233, 236),
	black = rgb(22, 22, 26),
	felt = rgb(28, 90, 62),
	leaf = { rgb(50, 110, 55), rgb(62, 128, 60), rgb(44, 96, 58) },
	pot = rgb(150, 100, 70),
	book = { rgb(120, 50, 45), rgb(50, 70, 110), rgb(70, 95, 60), rgb(140, 110, 60), rgb(85, 60, 100) },
	rug = { rgb(120, 45, 55), rgb(50, 70, 105), rgb(95, 85, 60), rgb(60, 85, 80) },
	cork = rgb(170, 130, 85),
	parquet = rgb(150, 110, 72),
	screen = rgb(40, 80, 110),
	box = { rgb(160, 125, 85), rgb(140, 110, 80), rgb(175, 140, 95) },
	coat = { rgb(40, 40, 48), rgb(90, 60, 50), rgb(60, 70, 85), rgb(110, 100, 90), rgb(30, 45, 40) },
	bottle = rgb(35, 65, 45),
	velvet = rgb(95, 25, 35),
}
local styles: { [string]: { [string]: any } } = {
	deco = {},
	service = {
		wood = rgb(150, 125, 95),
		dark = rgb(90, 80, 70),
		fabric = { rgb(90, 100, 105), rgb(70, 95, 100), rgb(110, 105, 95) },
		rug = { rgb(80, 85, 90), rgb(95, 90, 80) },
	},
	security = {
		wood = rgb(105, 105, 110),
		dark = rgb(45, 48, 55),
		fabric = { rgb(55, 65, 85), rgb(70, 75, 85), rgb(45, 60, 70) },
		rug = { rgb(50, 58, 72) },
		neon = rgb(120, 200, 255),
	},
	exec = {
		wood = rgb(34, 30, 32),
		dark = rgb(18, 18, 20),
		fabric = { rgb(20, 25, 40), rgb(70, 18, 24), rgb(28, 36, 34) },
		brass = rgb(215, 175, 85),
		stone = rgb(40, 40, 46),
		rug = { rgb(25, 30, 48), rgb(75, 20, 28) },
	},
	casino = {
		wood = rgb(60, 35, 30),
		dark = rgb(35, 20, 20),
		fabric = { rgb(95, 25, 35), rgb(25, 25, 32), rgb(60, 25, 60) },
		rug = { rgb(70, 20, 30), rgb(40, 20, 50) },
		neon = rgb(255, 90, 200),
	},
	hotel = {
		wood = rgb(180, 150, 120),
		dark = rgb(110, 85, 65),
		fabric = { rgb(205, 190, 165), rgb(120, 150, 150), rgb(190, 140, 140), rgb(160, 170, 190) },
		rug = { rgb(190, 170, 140), rgb(150, 165, 165) },
	},
	outdoor = {
		wood = rgb(140, 100, 60),
		dark = rgb(70, 50, 35),
		fabric = { rgb(235, 232, 225), rgb(40, 60, 90), rgb(230, 215, 190) },
		cloth = rgb(240, 238, 232),
	},
}

local function resolve(palette: { [string]: any }, key: string, rng: Random): Color3
	local value = palette[key] or base.white
	if typeof(value) == "Color3" then
		return value
	end
	return (value :: { Color3 })[rng:NextInteger(1, #(value :: { Color3 }))]
end

-- Fabs ------------------------------------------------------------------------------------------------------------------------------------------
local defs: { [string]: Fab } = {}

-- Seating
defs.chair = {
	w = 2,
	d = 2,
	parts = {
		B("ChairSeat", 2, 1.9, 2, 0, 0.95, 0, "fabric", FAB),
		B("ChairBack", 2, 2.3, 0.4, 0, 3, -0.8, "fabric", FAB),
	},
}
defs.stool = { w = 2, d = 2, parts = { U("Stool", 1.8, 2.6, 0, 0, 0, "fabric", FAB) } }
defs.armchair = {
	w = 3.6,
	d = 3.6,
	parts = {
		B("ArmchairSeat", 3.4, 1.8, 3.2, 0, 0.9, 0.1, "fabric", FAB),
		B("ArmchairBack", 3.4, 3.2, 0.9, 0, 3.4, -1.4, "fabric", FAB),
		B("ArmchairArm", 0.7, 2.6, 3.2, -1.4, 1.3, 0.1, "fabric", FAB),
		B("ArmchairArm", 0.7, 2.6, 3.2, 1.4, 1.3, 0.1, "fabric", FAB),
	},
}
defs.sofa = {
	w = 7.6,
	d = 3.4,
	stop = "Sit",
	parts = {
		B("SofaSeat", 7, 2.2, 3.2, 0, 1.1, 0.1, "fabric", FAB),
		B("SofaBack", 7, 3.4, 1, 0, 3.9, -1.3, "fabric", FAB),
		B("SofaArm", 0.8, 3.2, 3.4, -3.2, 1.6, 0, "fabric", FAB),
		B("SofaArm", 0.8, 3.2, 3.4, 3.2, 1.6, 0, "fabric", FAB),
	},
}
defs.bench = {
	w = 7,
	d = 2.4,
	stop = "Sit",
	parts = {
		B("BenchSeat", 7, 0.5, 2.2, 0, 1.9, 0, "wood", WOODM),
		B("BenchLeg", 0.6, 1.8, 2, -3, 0.9, 0, "dark", WOODM),
		B("BenchLeg", 0.6, 1.8, 2, 3, 0.9, 0, "dark", WOODM),
	},
}
defs.coffeeTable = {
	w = 4.4,
	d = 2.6,
	parts = {
		B("CoffeeTop", 4, 0.3, 2.4, 0, 1.5, 0, "wood", WOODM),
		B("CoffeeBase", 3.4, 1.35, 1.6, 0, 0.68, 0, "dark", WOODM),
	},
}
defs.floorLamp = {
	w = 1.8,
	d = 1.8,
	parts = {
		U("LampBase", 1.6, 0.3, 0, 0, 0, "brass", METALM),
		U("LampPost", 0.3, 5.6, 0, 0, 0.3, "brass", METALM),
		O("LampShade", 1.8, 0, 6.6, 0, "warm", NEON, false),
	},
}
defs.bigPlant = {
	w = 3.6,
	d = 3.6,
	parts = {
		U("Pot", 2.8, 2.4, 0, 0, 0, "pot"),
		O("Plant", 4.4, 0, 4.9, 0, "leaf", nil, false),
		O("Plant", 3, 0.8, 6.6, 0.3, "leaf", nil, false),
	},
}
defs.rugLounge = {
	w = 13,
	d = 9,
	flat = true,
	parts = {
		B("Rug", 13, 0.12, 9, 0, 0.06, 0, "brass", FAB, false),
		B("Rug", 11.6, 0.16, 7.6, 0, 0.08, 0, "rug", FAB, false),
	},
}
defs.loungeSet = {
	w = 15,
	d = 11,
	stop = "Talk",
	subs = {
		{ "rugLounge", 0, 0.4 },
		{ "sofa", 0, -3.6 },
		{ "armchair", -5.4, 0.6, math.rad(90) },
		{ "armchair", 5.4, 0.6, math.rad(-90) },
		{ "coffeeTable", 0, 0.6 },
		{ "floorLamp", 6.6, -4.4 },
	},
}
defs.diningSet = {
	w = 14,
	d = 11,
	stop = "Talk",
	parts = {
		B("DiningTable", 9, 0.4, 4, 0, 3.4, 0, "wood", WOODM),
		B("TableBase", 6, 3.2, 1.6, 0, 1.6, 0, "dark", WOODM),
		B("Cloth", 9.4, 0.15, 2.2, 0, 3.65, 0, "cloth", FAB, false),
		B("Centerpiece", 0.9, 1.4, 0.9, 0, 4.4, 0, "brass", METALM, false),
	},
	subs = {
		{ "chair", -2.4, -3.6, 0 },
		{ "chair", 2.4, -3.6, 0 },
		{ "chair", -2.4, 3.6, math.pi },
		{ "chair", 2.4, 3.6, math.pi },
		{ "chair", -6, 0, math.rad(90) },
		{ "chair", 6, 0, math.rad(-90) },
	},
}
defs.longTable = {
	w = 22,
	d = 8,
	stop = "Talk",
	parts = {
		B("LongTable", 20, 0.5, 3.6, 0, 3.2, 0, "wood", WOODM),
		B("TableBase", 15, 3, 1.4, 0, 1.5, 0, "dark", WOODM),
		B("MessBench", 18, 0.5, 1.4, 0, 1.8, -3.2, "dark", WOODM),
		B("MessBench", 18, 0.5, 1.4, 0, 1.8, 3.2, "dark", WOODM),
		B("BenchLeg", 0.6, 1.8, 1.2, -8, 0.9, -3.2, "dark", WOODM),
		B("BenchLeg", 0.6, 1.8, 1.2, 8, 0.9, -3.2, "dark", WOODM),
		B("BenchLeg", 0.6, 1.8, 1.2, -8, 0.9, 3.2, "dark", WOODM),
		B("BenchLeg", 0.6, 1.8, 1.2, 8, 0.9, 3.2, "dark", WOODM),
	},
}
defs.cocktail = {
	w = 10,
	d = 10,
	stop = "Talk",
	parts = {
		U("CocktailBase", 3.4, 3.6, 0, 0, 0, "wood", WOODM),
		U("CocktailTop", 4.2, 0.3, 0, 0, 3.6, "dark", WOODM),
		U("Stool", 1.8, 2.6, 0, 3.6, 0, "fabric", FAB),
		U("Stool", 1.8, 2.6, 3.1, -1.8, 0, "fabric", FAB),
		U("Stool", 1.8, 2.6, -3.1, -1.8, 0, "fabric", FAB),
	},
}
defs.parasolTable = {
	w = 10,
	d = 10,
	stop = "Talk",
	parts = {
		U("PatioBase", 3.4, 3.4, 0, 0, 0, "wood", WOODM),
		U("PatioTop", 4.4, 0.3, 0, 0, 3.4, "wood", WOODM),
		U("ParasolPole", 0.3, 9, 0, 0, 3.7, "steel", METALM),
		U("ParasolCanopy", 10, 0.4, 0, 0, 12.7, "cloth", FAB, false),
		U("PatioStool", 1.8, 2.6, 0, 3.6, 0, "fabric", FAB),
		U("PatioStool", 1.8, 2.6, 3.1, -1.8, 0, "fabric", FAB),
		U("PatioStool", 1.8, 2.6, -3.1, -1.8, 0, "fabric", FAB),
	},
}
defs.readingTable = {
	w = 10,
	d = 8,
	stop = "Idle",
	parts = {
		B("ReadingTable", 7, 0.4, 3.4, 0, 3.4, 0, "wood", WOODM),
		B("TableBase", 4.6, 3.2, 1.4, 0, 1.6, 0, "dark", WOODM),
		B("Book", 1.6, 0.3, 1.2, -1.8, 3.75, 0.2, "book", PLASTIC, false),
		B("Book", 1.4, 0.3, 1.1, 1.6, 3.75, -0.4, "book", PLASTIC, false),
		O("DeskLamp", 1.1, 0, 4.4, -1, "warm", NEON, false),
	},
	subs = { { "chair", -2, -3, 0 }, { "chair", 2, -3, 0 }, { "chair", -2, 3, math.pi }, { "chair", 2, 3, math.pi } },
}
defs.deskPod = {
	w = 11,
	d = 10,
	stop = "Work",
	parts = {
		B("Desk", 7, 3, 3, 0, 1.5, -2, "wood", WOODM),
		B("Desk", 7, 3, 3, 0, 1.5, 2, "wood", WOODM),
		B("Monitor", 2.4, 1.6, 0.2, 0, 4.2, -2.8, "neon", NEON, false),
		B("Monitor", 2.4, 1.6, 0.2, 0, 4.2, 2.8, "neon", NEON, false),
		B("Paper", 1.6, 0.1, 2, 2.4, 3.1, -1.8, "cloth", PLASTIC, false),
		B("Paper", 1.6, 0.1, 2, -2.4, 3.1, 1.8, "cloth", PLASTIC, false),
	},
	subs = { { "chair", 0, -4.6, 0 }, { "chair", 0, 4.6, math.pi } },
}
defs.officeDesk = {
	w = 7,
	d = 6,
	stop = "Work",
	parts = {
		B("Desk", 6, 3, 2.6, 0, 1.5, -1.7, "wood", WOODM),
		B("Monitor", 2.4, 1.6, 0.2, 0, 4.2, -2.4, "neon", NEON, false),
		B("Keyboard", 2, 0.15, 0.8, 0, 3.1, -1.1, "black", PLASTIC, false),
		O("DeskLamp", 1.1, -2.2, 4.4, -2.1, "warm", NEON, false),
	},
	subs = { { "chair", 0, 1.2, math.pi } },
}
defs.consoleTable = {
	w = 6.4,
	d = 2.4,
	parts = {
		B("ConsoleTop", 6, 0.3, 2.2, 0, 3, 0, "dark", WOODM),
		B("ConsoleLeg", 0.4, 2.9, 1.8, -2.7, 1.45, 0, "dark", WOODM),
		B("ConsoleLeg", 0.4, 2.9, 1.8, 2.7, 1.45, 0, "dark", WOODM),
		U("Vase", 1, 1.6, 1.8, 0, 3.15, "pot"),
		O("LampShade", 1.2, -2, 4.6, 0, "warm", NEON, false),
		U("LampStem", 0.2, 1.1, -2, 0, 3.15, "brass", METALM),
	},
}
defs.sideboard = {
	w = 9,
	d = 2.8,
	parts = {
		B("Sideboard", 9, 3.4, 2.6, 0, 1.7, 0, "dark", WOODM),
		B("SideboardTop", 9.2, 0.2, 2.8, 0, 3.5, 0, "stone", MARBLE),
		U("Decanter", 0.9, 1.8, -2.4, 0, 3.6, "glass", GLASSM, false),
		U("Decanter", 0.9, 1.5, -1.2, 0.3, 3.6, "glass", GLASSM, false),
		B("Tray", 2.4, 0.15, 1.4, 2, 3.65, 0, "brass", METALM, false),
	},
}
defs.buffet = {
	w = 15,
	d = 4,
	stop = "Talk",
	parts = {
		B("BuffetTable", 14, 3, 3, 0, 1.5, 0, "dark", WOODM),
		B("BuffetCloth", 14.4, 0.15, 3.2, 0, 3.1, 0, "cloth", FAB, false),
		B("Tray", 2.6, 0.8, 1.8, -5, 3.6, 0, "brass", METALM, false),
		B("Tray", 2.6, 0.8, 1.8, -1.7, 3.6, 0, "brass", METALM, false),
		B("Tray", 2.6, 0.8, 1.8, 1.7, 3.6, 0, "brass", METALM, false),
		B("Tray", 2.6, 0.8, 1.8, 5, 3.6, 0, "brass", METALM, false),
	},
}
defs.fireplace = {
	w = 11,
	d = 3.2,
	parts = {
		B("Hearth", 10, 0.5, 3, 0, 0.25, 0.2, "stone", MARBLE),
		B("Surround", 10, 8, 1.6, 0, 4, -0.8, "stone", MARBLE),
		B("FireOpening", 4.6, 3.4, 0.4, 0, 2.4, 0.1, "black", PLASTIC, false),
		B("Fire", 3.2, 1.2, 0.3, 0, 1.4, 0.2, "warm", NEON, false),
		B("Mantel", 11, 0.5, 2.2, 0, 6.4, 0.2, "dark", WOODM),
	},
}
defs.bookcase = {
	w = 9,
	d = 1.8,
	parts = {
		B("Bookcase", 9, 12, 1.8, 0, 6, 0, "dark", WOODM),
		B("Books", 8.2, 1.9, 1.2, 0, 2.2, 0.6, "book", PLASTIC, false),
		B("Books", 8.2, 1.9, 1.2, 0, 4.9, 0.6, "book", PLASTIC, false),
		B("Books", 8.2, 1.9, 1.2, 0, 7.6, 0.6, "book", PLASTIC, false),
		B("Books", 8.2, 1.9, 1.2, 0, 10.3, 0.6, "book", PLASTIC, false),
	},
}
defs.bookRow = {
	w = 10.4,
	d = 3.6,
	stop = "Idle",
	parts = {
		B("BookRowCore", 10, 11, 1, 0, 5.5, 0, "dark", WOODM),
		B("BookRowEnd", 0.4, 11, 3.6, -5.1, 5.5, 0, "dark", WOODM),
		B("BookRowEnd", 0.4, 11, 3.6, 5.1, 5.5, 0, "dark", WOODM),
		B("Books", 9.4, 1.8, 1, 0, 2.2, 1.1, "book", PLASTIC, false),
		B("Books", 9.4, 1.8, 1, 0, 5, 1.1, "book", PLASTIC, false),
		B("Books", 9.4, 1.8, 1, 0, 7.8, 1.1, "book", PLASTIC, false),
		B("Books", 9.4, 1.8, 1, 0, 2.2, -1.1, "book", PLASTIC, false),
		B("Books", 9.4, 1.8, 1, 0, 5, -1.1, "book", PLASTIC, false),
		B("Books", 9.4, 1.8, 1, 0, 7.8, -1.1, "book", PLASTIC, false),
	},
}
defs.statue = {
	w = 5,
	d = 5,
	stop = "Art",
	parts = {
		B("StatueBase", 4, 2, 4, 0, 1, 0, "stone", MARBLE),
		B("StatuePedestal", 2, 2.6, 2, 0, 3.3, 0, "stone", MARBLE),
		B("StatueBody", 1.6, 3.2, 1, 0, 6.2, 0, "stone", MARBLE),
		O("StatueHead", 1.3, 0, 8.5, 0, "stone", MARBLE),
		B("StatueArm", 0.5, 2.4, 0.5, -1.1, 6.4, 0, "stone", MARBLE),
		B("StatueArm", 0.5, 2.4, 0.5, 1.1, 6.4, 0, "stone", MARBLE),
	},
}
defs.exhibit = {
	w = 9,
	d = 9,
	stop = "Art",
	parts = {
		B("Plinth", 3.2, 3.2, 3.2, 0, 1.6, 0, "stone", MARBLE),
		glass(B("Case", 2.8, 2.8, 2.8, 0, 4.6, 0, "glass", GLASSM, false)),
		B("Exhibit", 1.2, 1.6, 1.2, 0, 4.2, 0, "brass", METALM, false),
		U("Stanchion", 0.4, 3, -3.6, -3.6, 0, "brass", METALM),
		U("Stanchion", 0.4, 3, 3.6, -3.6, 0, "brass", METALM),
		U("Stanchion", 0.4, 3, -3.6, 3.6, 0, "brass", METALM),
		U("Stanchion", 0.4, 3, 3.6, 3.6, 0, "brass", METALM),
		B("Rope", 7.2, 0.2, 0.2, 0, 2.8, -3.6, "velvet", FAB, false),
		B("Rope", 7.2, 0.2, 0.2, 0, 2.8, 3.6, "velvet", FAB, false),
	},
}
defs.infoKiosk = {
	w = 3.6,
	d = 3.6,
	stop = "Idle",
	parts = {
		U("KioskBase", 3, 3.6, 0, 0, 0, "dark", WOODM),
		B("KioskScreen", 2.4, 1.8, 0.3, 0, 4.6, 0.4, "neon", NEON, false),
	},
}
defs.luggageCart = {
	w = 5,
	d = 3,
	parts = {
		B("CartFrame", 4.4, 0.3, 2.4, 0, 0.9, 0, "brass", METALM),
		B("CartPost", 0.3, 5.4, 0.3, -2.1, 3.3, 0, "brass", METALM),
		B("CartPost", 0.3, 5.4, 0.3, 2.1, 3.3, 0, "brass", METALM),
		B("Suitcase", 2.2, 1.8, 1.4, -1, 2, 0, "fabric", PLASTIC),
		B("Suitcase", 1.8, 1.4, 1.2, 1.2, 1.8, 0, "dark", PLASTIC),
	},
}
defs.coatRack = {
	w = 10,
	d = 3,
	parts = {
		B("RackRail", 9, 0.3, 0.3, 0, 7, 0, "brass", METALM),
		B("RackPost", 0.3, 7, 0.3, -4.5, 3.5, 0, "dark", WOODM),
		B("RackPost", 0.3, 7, 0.3, 4.5, 3.5, 0, "dark", WOODM),
		B("Coat", 1.4, 3.4, 0.7, -3.4, 5, 0, "coat", FAB, false),
		B("Coat", 1.4, 3.4, 0.7, -1.7, 5, 0, "coat", FAB, false),
		B("Coat", 1.4, 3.4, 0.7, 0, 5, 0, "coat", FAB, false),
		B("Coat", 1.4, 3.4, 0.7, 1.7, 5, 0, "coat", FAB, false),
		B("Coat", 1.4, 3.4, 0.7, 3.4, 5, 0, "coat", FAB, false),
	},
}

-- Casino and bar
defs.slotWall = {
	w = 3.8,
	d = 3.4,
	parts = {
		B("SlotMachine", 3.4, 7, 2.6, 0, 3.5, -0.2, "velvet", PLASTIC),
		B("SlotScreen", 2.6, 2.2, 0.15, 0, 5, 1.15, "neon", NEON, false),
	},
	subs = { { "stool", 0, 2.4 } },
}
defs.slotIsland = {
	w = 13,
	d = 9,
	parts = {
		B("SlotSpine", 12, 7, 2.2, 0, 3.5, 0, "velvet", PLASTIC),
		B("SlotScreen", 2.4, 2, 0.15, -4.5, 5, 1.2, "neon", NEON, false),
		B("SlotScreen", 2.4, 2, 0.15, -1.5, 5, 1.2, "neon", NEON, false),
		B("SlotScreen", 2.4, 2, 0.15, 1.5, 5, 1.2, "neon", NEON, false),
		B("SlotScreen", 2.4, 2, 0.15, 4.5, 5, 1.2, "neon", NEON, false),
		B("SlotScreen", 2.4, 2, 0.15, -4.5, 5, -1.2, "neon", NEON, false),
		B("SlotScreen", 2.4, 2, 0.15, -1.5, 5, -1.2, "neon", NEON, false),
		B("SlotScreen", 2.4, 2, 0.15, 1.5, 5, -1.2, "neon", NEON, false),
		B("SlotScreen", 2.4, 2, 0.15, 4.5, 5, -1.2, "neon", NEON, false),
	},
	subs = {
		{ "stool", -4.5, 3.4 },
		{ "stool", 0, 3.4 },
		{ "stool", 4.5, 3.4 },
		{ "stool", -4.5, -3.4 },
		{ "stool", 0, -3.4 },
		{ "stool", 4.5, -3.4 },
	},
}
defs.casinoTable = {
	w = 16,
	d = 14,
	stop = "Talk",
	parts = {
		U("TableBase", 4, 3, 0, 0, 0, "dark", WOODM),
		U("Felt", 9, 0.4, 0, 0, 3, "felt", FAB),
		U("TableRim", 9.8, 0.2, 0, 0, 2.9, "dark", WOODM),
		O("Chips", 1.2, -1.5, 3.9, 0.5, "neon", NEON, false),
		U("DealerStool", 1.8, 3.2, 0, 5.8, 0, "black", FAB),
		U("Stool", 1.8, 2.6, -5.6, -3.2, 0, "velvet", FAB),
		U("Stool", 1.8, 2.6, -3, -5.4, 0, "velvet", FAB),
		U("Stool", 1.8, 2.6, 0, -6.3, 0, "velvet", FAB),
		U("Stool", 1.8, 2.6, 3, -5.4, 0, "velvet", FAB),
		U("Stool", 1.8, 2.6, 5.6, -3.2, 0, "velvet", FAB),
	},
}
defs.cardTable = {
	w = 10,
	d = 10,
	stop = "Talk",
	parts = {
		B("CardTable", 7, 0.4, 4.4, 0, 3.4, 0, "felt", FAB),
		B("TableBase", 4.6, 3.2, 1.8, 0, 1.6, 0, "dark", WOODM),
		O("Chips", 1, -1, 3.9, 0, "neon", NEON, false),
		O("Chips", 1, 1.4, 3.9, 0.6, "warm", NEON, false),
	},
	subs = {
		{ "chair", -2, -3.4, 0 },
		{ "chair", 2, -3.4, 0 },
		{ "chair", -2, 3.4, math.pi },
		{ "chair", 2, 3.4, math.pi },
	},
}
defs.booth = {
	w = 8.6,
	d = 8,
	stop = "Talk",
	subs = { { "sofa", 0, -2.1 }, { "coffeeTable", 0, 1.8 }, { "stool", -2, 3.4 }, { "stool", 2, 3.4 } },
}
defs.pianoSet = {
	w = 9,
	d = 10,
	parts = {
		B("PianoBody", 8, 2.4, 5.6, 0, 3.4, -1, "black", PLASTIC),
		B("PianoLid", 8, 0.3, 5.6, 0, 4.75, -1, "black", PLASTIC),
		B("PianoKeys", 7, 0.3, 1.4, 0, 3.4, 2.2, "white", PLASTIC),
		U("PianoLeg", 0.6, 2.2, -3.4, 1, 0, "black", PLASTIC),
		U("PianoLeg", 0.6, 2.2, 3.4, 1, 0, "black", PLASTIC),
		U("PianoLeg", 0.6, 2.2, 0, -3, 0, "black", PLASTIC),
		B("PianoBench", 3.6, 1.8, 1.6, 0, 0.9, 4, "dark", WOODM),
	},
}
defs.bandStage = {
	w = 16,
	d = 11,
	parts = {
		B("StageDeck", 16, 1.6, 11, 0, 0.8, 0, "wood", WOODM),
		B("StageCurtain", 16, 13, 0.5, 0, 8.1, -5.2, "velvet", FAB, false),
		B("StageSpeaker", 2.4, 5, 2.4, -6.4, 4.1, 1, "black", PLASTIC),
		B("StageSpeaker", 2.4, 5, 2.4, 6.4, 4.1, 1, "black", PLASTIC),
		U("MicStand", 0.2, 4.6, 0, 3, 1.6, "steel", METALM),
		B("MusicStand", 1.6, 2.6, 0.4, -5.6, 2.9, 2, "black", PLASTIC),
		B("MusicStand", 1.6, 2.6, 0.4, -2.5, 2.9, 2, "black", PLASTIC),
	},
	subs = { { "pianoSet", 3.6, -0.5, 0, 1.6 } },
}
defs.djBooth = {
	w = 12,
	d = 5,
	parts = {
		B("DjTable", 8, 3, 2.4, 0, 1.5, 0, "black", PLASTIC),
		U("Deck", 1.9, 0.2, -1.8, 0, 3, "neon", NEON, false),
		U("Deck", 1.9, 0.2, 1.8, 0, 3, "neon", NEON, false),
		B("DjSpeaker", 2, 5, 2, -5.5, 2.5, 0, "black", PLASTIC),
		B("DjSpeaker", 2, 5, 2, 5.5, 2.5, 0, "black", PLASTIC),
	},
}
defs.cashierCounter = {
	w = 15,
	d = 4.4,
	stop = "Work",
	parts = {
		B("Counter", 14, 3.4, 2.6, 0, 1.7, -0.8, "dark", WOODM),
		B("CounterTop", 14.4, 0.3, 3, 0, 3.55, -0.7, "stone", MARBLE),
		glass(B("TellerScreen", 14, 3.6, 0.2, 0, 5.5, -0.4, "glass", GLASSM, false)),
		U("TellerStool", 1.8, 2.6, 0, -1.6, 0, "fabric", FAB),
	},
}
defs.safeWall = {
	w = 5.4,
	d = 3.6,
	parts = {
		B("Safe", 5, 7, 3, 0, 3.5, -0.3, "steel", METALM),
		B("SafeDoor", 3.8, 5, 0.3, 0, 3.8, 1.3, "black", METALM),
		O("SafeDial", 1.2, 0, 3.8, 1.6, "brass", METALM, false),
	},
}

-- Offices and security
defs.filingRow = {
	w = 14,
	d = 2.4,
	parts = {
		B("FilingCabinet", 3.2, 6, 2.2, -5, 3, 0, "steel", METALM),
		B("FilingCabinet", 3.2, 6, 2.2, -1.6, 3, 0, "steel", METALM),
		B("FilingCabinet", 3.2, 6, 2.2, 1.8, 3, 0, "steel", METALM),
		B("FilingCabinet", 3.2, 6, 2.2, 5.2, 3, 0, "steel", METALM),
	},
}
defs.copier = {
	w = 4,
	d = 3,
	stop = "Lean",
	parts = {
		B("Copier", 3.6, 3.6, 2.6, 0, 1.8, -0.2, "white", PLASTIC),
		B("CopierLid", 3.6, 0.3, 2.4, 0, 3.75, -0.2, "dark", PLASTIC),
		B("CopierLight", 0.6, 0.2, 0.2, 1.2, 3.95, 0.8, "neon", NEON, false),
	},
}
defs.waterCooler = {
	w = 1.8,
	d = 1.8,
	stop = "Talk",
	parts = {
		B("CoolerBase", 1.4, 3, 1.4, 0, 1.5, 0, "white", PLASTIC),
		U("CoolerJug", 1.2, 1.7, 0, 0, 3, "glass", GLASSM, false),
	},
}
defs.whiteboard = {
	w = 7,
	d = 0.8,
	parts = {
		B("Whiteboard", 7, 4, 0.3, 0, 8, -0.2, "white", PLASTIC, false),
		B("BoardFrame", 7.4, 4.4, 0.2, 0, 8, -0.3, "steel", METALM, false),
		B("BoardMarks", 4.6, 0.12, 0.1, -0.4, 8.6, 0, "neon", PLASTIC, false),
	},
}
defs.noticeboard = {
	w = 6,
	d = 0.8,
	parts = {
		B("Noticeboard", 6, 4, 0.3, 0, 7.5, -0.2, "cork", PLASTIC, false),
		B("Notice", 1.2, 1.6, 0.1, -1.8, 7.8, 0, "cloth", PLASTIC, false),
		B("Notice", 1.2, 1.6, 0.1, 0, 7.4, 0, "cloth", PLASTIC, false),
		B("Notice", 1.2, 1.6, 0.1, 1.8, 7.9, 0, "cloth", PLASTIC, false),
	},
}
defs.monitorWall = {
	w = 16,
	d = 6,
	stop = "Work",
	parts = {
		B("MonitorPanel", 16, 7, 0.8, 0, 6, -2.4, "black", PLASTIC),
		B("Screen", 3.4, 2.4, 0.2, -5.7, 4.6, -1.9, "neon", NEON, false),
		B("Screen", 3.4, 2.4, 0.2, -1.9, 4.6, -1.9, "neon", NEON, false),
		B("Screen", 3.4, 2.4, 0.2, 1.9, 4.6, -1.9, "neon", NEON, false),
		B("Screen", 3.4, 2.4, 0.2, 5.7, 4.6, -1.9, "neon", NEON, false),
		B("Screen", 3.4, 2.4, 0.2, -5.7, 7.6, -1.9, "neon", NEON, false),
		B("Screen", 3.4, 2.4, 0.2, -1.9, 7.6, -1.9, "neon", NEON, false),
		B("Screen", 3.4, 2.4, 0.2, 1.9, 7.6, -1.9, "neon", NEON, false),
		B("Screen", 3.4, 2.4, 0.2, 5.7, 7.6, -1.9, "neon", NEON, false),
		B("ControlDesk", 14, 3, 2.4, 0, 1.5, 0.2, "dark", PLASTIC),
	},
	subs = { { "chair", -3, 2.6, math.pi }, { "chair", 3, 2.6, math.pi } },
}
defs.securityDesk = {
	w = 10,
	d = 5,
	stop = "Guard",
	parts = {
		B("SecurityDesk", 9, 3.4, 2.6, 0, 1.7, 0, "dark", PLASTIC),
		B("DeskScreen", 2.4, 1.6, 0.2, -2, 4.3, -0.6, "neon", NEON, false),
		B("Radio", 0.8, 1.2, 0.6, 2.4, 4, 0, "black", PLASTIC, false),
	},
	subs = { { "chair", 0, -2.8, 0 } },
}
defs.weaponRack = {
	w = 10,
	d = 2,
	parts = {
		B("RackBoard", 10, 7, 0.5, 0, 5, -0.75, "dark", WOODM),
		B("Rifle", 0.5, 4.6, 0.5, -3.6, 5.4, -0.2, "black", PLASTIC),
		B("RifleStock", 0.7, 1.4, 0.5, -3.6, 2.6, -0.2, "dark", WOODM),
		B("Rifle", 0.5, 4.6, 0.5, -1.2, 5.4, -0.2, "black", PLASTIC),
		B("RifleStock", 0.7, 1.4, 0.5, -1.2, 2.6, -0.2, "dark", WOODM),
		B("Rifle", 0.5, 4.6, 0.5, 1.2, 5.4, -0.2, "black", PLASTIC),
		B("RifleStock", 0.7, 1.4, 0.5, 1.2, 2.6, -0.2, "dark", WOODM),
		B("Rifle", 0.5, 4.6, 0.5, 3.6, 5.4, -0.2, "black", PLASTIC),
		B("RifleStock", 0.7, 1.4, 0.5, 3.6, 2.6, -0.2, "dark", WOODM),
	},
}
defs.lockerRow = {
	w = 15,
	d = 2.2,
	stop = "Lean",
	parts = {
		B("Locker", 3.6, 9, 2, -5.4, 4.5, 0, "steel", METALM),
		B("Locker", 3.6, 9, 2, -1.8, 4.5, 0, "steel", METALM),
		B("Locker", 3.6, 9, 2, 1.8, 4.5, 0, "steel", METALM),
		B("Locker", 3.6, 9, 2, 5.4, 4.5, 0, "steel", METALM),
		B("LockerVent", 2.4, 0.3, 0.1, -5.4, 7.4, 1.05, "black", PLASTIC, false),
		B("LockerVent", 2.4, 0.3, 0.1, -1.8, 7.4, 1.05, "black", PLASTIC, false),
		B("LockerVent", 2.4, 0.3, 0.1, 1.8, 7.4, 1.05, "black", PLASTIC, false),
		B("LockerVent", 2.4, 0.3, 0.1, 5.4, 7.4, 1.05, "black", PLASTIC, false),
	},
}
defs.bunk = {
	w = 8,
	d = 4.2,
	stop = "Lean",
	parts = {
		B("BunkMattress", 7, 0.8, 3.2, 0, 2.6, 0, "fabric", FAB),
		B("BunkMattress", 7, 0.8, 3.2, 0, 5.6, 0, "fabric", FAB),
		B("Blanket", 6, 0.3, 2.6, 0.4, 3.15, 0, "cloth", FAB, false),
		B("Pillow", 1.6, 0.5, 1.4, -2.6, 6.2, 0, "cloth", FAB, false),
		B("BunkPost", 0.4, 7.6, 0.4, -3.6, 3.8, -1.7, "steel", METALM),
		B("BunkPost", 0.4, 7.6, 0.4, 3.6, 3.8, -1.7, "steel", METALM),
		B("BunkPost", 0.4, 7.6, 0.4, -3.6, 3.8, 1.7, "steel", METALM),
		B("BunkPost", 0.4, 7.6, 0.4, 3.6, 3.8, 1.7, "steel", METALM),
	},
}
defs.workbench = {
	w = 9,
	d = 4.4,
	stop = "Work",
	parts = {
		B("Workbench", 8, 0.5, 3.2, 0, 3.2, 0, "wood", WOODM),
		B("BenchBase", 7, 3, 0.6, 0, 1.5, -1.2, "dark", WOODM),
		B("BenchBase", 7, 3, 0.6, 0, 1.5, 1.2, "dark", WOODM),
		B("Vise", 1, 1, 1, 3, 4, 0, "steel", METALM, false),
		B("Tool", 2, 0.2, 0.5, -2, 3.55, 0.4, "steel", METALM, false),
	},
}
defs.cot = {
	w = 3.6,
	d = 7.4,
	parts = {
		B("CotFrame", 3.2, 1.4, 7, 0, 0.7, 0, "steel", METALM),
		B("CotMattress", 3, 0.6, 6.4, 0, 1.7, 0, "fabric", FAB),
		B("CotBlanket", 2.8, 0.3, 4, 0, 2.1, 1, "cloth", FAB, false),
	},
}

-- Kitchen and stores
defs.rangeStove = {
	w = 7.4,
	d = 3.8,
	stop = "Work",
	parts = {
		B("Range", 7, 3.4, 3.2, 0, 1.7, -0.3, "steel", METALM),
		U("Burner", 1.6, 0.2, -1.8, -0.6, 3.4, "black", PLASTIC),
		U("Burner", 1.6, 0.2, 1.8, -0.6, 3.4, "black", PLASTIC),
		U("Burner", 1.6, 0.2, -1.8, 1, 3.4, "black", PLASTIC),
		U("Burner", 1.6, 0.2, 1.8, 1, 3.4, "black", PLASTIC),
		B("RangeHood", 7, 2.4, 3, 0, 10, -0.4, "steel", METALM),
		B("HoodDuct", 2.2, 9, 2.2, 0, 15.7, -0.8, "steel", METALM),
		U("Pot", 1.8, 1.4, -1.8, -0.6, 3.6, "steel", METALM),
	},
}
defs.fridge = {
	w = 4.2,
	d = 3.8,
	parts = {
		B("Fridge", 4, 8.4, 3.4, 0, 4.2, -0.2, "steel", METALM),
		B("FridgeSeam", 3.6, 0.15, 0.1, 0, 5.4, 1.5, "black", PLASTIC, false),
		B("FridgeHandle", 0.3, 2.4, 0.3, 1.5, 3.2, 1.7, "black", PLASTIC, false),
	},
}
defs.sinkUnit = {
	w = 8.2,
	d = 3.6,
	stop = "Work",
	parts = {
		B("SinkCounter", 8, 3.4, 3.2, 0, 1.7, -0.2, "steel", METALM),
		B("SinkBasin", 3, 0.3, 2, -1.6, 3.5, 0, "black", PLASTIC, false),
		U("Faucet", 0.3, 1.6, -1.6, -1.1, 3.4, "steel", METALM),
		B("FaucetHead", 0.3, 0.3, 0.9, -1.6, 5, -0.7, "steel", METALM, false),
		B("DishRack", 2.6, 1, 1.8, 2.4, 3.9, 0, "steel", METALM, false),
	},
}
defs.counterRun = {
	w = 10.4,
	d = 3.4,
	stop = "Lean",
	parts = {
		B("Counter", 10, 3.4, 3, 0, 1.7, -0.2, "steel", METALM),
		B("CounterTop", 10.2, 0.3, 3.2, 0, 3.55, -0.1, "white", PLASTIC),
		B("CounterDoor", 0.1, 2.6, 2.6, 0, 1.6, 1.3, "black", PLASTIC, false),
		B("Utensils", 1.4, 0.2, 0.8, -3, 3.8, 0, "steel", METALM, false),
	},
}
defs.prepIsland = {
	w = 11,
	d = 6,
	stop = "Work",
	parts = {
		B("PrepTable", 10, 3.4, 4, 0, 1.7, 0, "steel", METALM),
		B("CuttingBoard", 3, 0.2, 2, -2.6, 3.5, 0, "wood", WOODM, false),
		U("Pot", 1.8, 1.4, 2.2, 0.4, 3.4, "steel", METALM),
		U("Pot", 1.4, 1, 3.8, -0.6, 3.4, "steel", METALM),
		B("Knife", 1.2, 0.1, 0.2, -1.2, 3.65, 0.6, "steel", METALM, false),
	},
}
defs.shelfRow = {
	w = 12,
	d = 4.6,
	stop = "Idle",
	parts = {
		B("ShelfPost", 0.4, 10, 4.2, -5.8, 5, 0, "steel", METALM),
		B("ShelfPost", 0.4, 10, 4.2, 0, 5, 0, "steel", METALM),
		B("ShelfPost", 0.4, 10, 4.2, 5.8, 5, 0, "steel", METALM),
		B("Shelf", 12, 0.3, 4.2, 0, 2.5, 0, "steel", METALM),
		B("Shelf", 12, 0.3, 4.2, 0, 5.5, 0, "steel", METALM),
		B("Shelf", 12, 0.3, 4.2, 0, 8.5, 0, "steel", METALM),
		B("StoredBox", 2.6, 1.8, 1.7, -3, 3.55, 1.1, "box", Enum.Material.Cardboard, false),
		B("StoredBox", 2.2, 1.6, 1.7, 2.6, 3.45, -1.1, "box", Enum.Material.Cardboard, false),
		B("StoredBox", 2.8, 1.8, 1.7, 1, 6.55, 1.1, "box", Enum.Material.Cardboard, false),
		B("StoredBox", 2.2, 1.6, 1.7, -3.4, 6.45, -1.1, "box", Enum.Material.Cardboard, false),
		B("StoredBox", 2.6, 1.8, 1.7, -1, 9.55, 1.1, "box", Enum.Material.Cardboard, false),
		B("StoredBox", 2.4, 1.6, 1.7, 3.6, 9.45, -1.1, "box", Enum.Material.Cardboard, false),
	},
}
defs.wallShelf = {
	w = 10,
	d = 2.4,
	parts = {
		B("ShelfPost", 0.4, 10, 2.2, -4.8, 5, 0, "steel", METALM),
		B("ShelfPost", 0.4, 10, 2.2, 4.8, 5, 0, "steel", METALM),
		B("Shelf", 10, 0.3, 2.2, 0, 2.5, 0, "steel", METALM),
		B("Shelf", 10, 0.3, 2.2, 0, 5.5, 0, "steel", METALM),
		B("Shelf", 10, 0.3, 2.2, 0, 8.5, 0, "steel", METALM),
		B("StoredBox", 2.6, 1.8, 1.6, -2.4, 3.55, 0, "box", Enum.Material.Cardboard, false),
		B("StoredBox", 2.2, 1.6, 1.6, 2.4, 6.45, 0, "box", Enum.Material.Cardboard, false),
		B("StoredBox", 2.8, 1.8, 1.6, 0, 9.55, 0, "box", Enum.Material.Cardboard, false),
	},
}
defs.palletStack = {
	w = 5.4,
	d = 5.4,
	parts = {
		B("Pallet", 4.6, 0.6, 4.6, 0, 0.3, 0, "wood", WOODM),
		B("Crate", 2.2, 2.2, 2.2, -1.2, 1.7, -1.2, "box", WOODM),
		B("Crate", 2.2, 2.2, 2.2, 1.2, 1.7, -1.2, "box", WOODM),
		B("Crate", 2.2, 2.2, 2.2, -1.2, 1.7, 1.2, "box", WOODM),
		B("Crate", 2.2, 2.2, 2.2, 1.2, 1.7, 1.2, "box", WOODM),
		B("Crate", 2.2, 2.2, 2.2, 0, 3.9, 0, "box", WOODM),
	},
}
defs.crateStack = {
	w = 6.4,
	d = 5,
	parts = {
		B("Crate", 3, 3, 3, -1.4, 1.5, -0.6, "box", WOODM),
		B("Crate", 2.6, 2.6, 2.6, 1.8, 1.3, 0.6, "box", WOODM),
		B("Crate", 2.4, 2.4, 2.4, 0.2, 4.2, -0.4, "box", WOODM),
	},
}
defs.wineRack = {
	w = 8.4,
	d = 2.6,
	stop = "Idle",
	parts = {
		B("WineRack", 8, 9, 2.4, 0, 4.5, -0.1, "dark", WOODM),
		B("Bottles", 7.4, 1.1, 1.4, 0, 1.8, 0.9, "bottle", GLASSM, false),
		B("Bottles", 7.4, 1.1, 1.4, 0, 3.9, 0.9, "bottle", GLASSM, false),
		B("Bottles", 7.4, 1.1, 1.4, 0, 6, 0.9, "bottle", GLASSM, false),
		B("Bottles", 7.4, 1.1, 1.4, 0, 8, 0.9, "bottle", GLASSM, false),
	},
}
defs.barrelStack = {
	w = 8,
	d = 6,
	parts = {
		U("Barrel", 3.2, 3.8, -2, -1, 0, "wood", WOODM),
		U("Barrel", 3.2, 3.8, 1.4, -1, 0, "wood", WOODM),
		U("Barrel", 3.2, 3.8, -0.3, 1.8, 0, "wood", WOODM),
		B("BarrelHoop", 3.3, 0.2, 3.3, -2, 1.2, -1, "steel", METALM, false),
		B("BarrelHoop", 3.3, 0.2, 3.3, 1.4, 1.2, -1, "steel", METALM, false),
	},
}
defs.humidor = {
	w = 8.4,
	d = 2.8,
	parts = {
		B("Humidor", 8, 8, 2.4, 0, 4, -0.2, "dark", WOODM),
		glass(B("HumidorGlass", 7.4, 6.4, 0.2, 0, 4.2, 1.1, "glass", GLASSM, false)),
		B("CigarBox", 6.8, 1.2, 1.4, 0, 2, 0.2, "wood", WOODM, false),
		B("CigarBox", 6.8, 1.2, 1.4, 0, 4.4, 0.2, "wood", WOODM, false),
		B("CigarBox", 6.8, 1.2, 1.4, 0, 6.6, 0.2, "wood", WOODM, false),
	},
}

-- Laundry and housekeeping
defs.washerRow = {
	w = 13,
	d = 4,
	stop = "Work",
	parts = {
		B("Washer", 4, 5, 3.4, -4.4, 2.5, -0.2, "white", PLASTIC),
		B("Porthole", 2.2, 2.2, 0.2, -4.4, 2.8, 1.5, "glass", GLASSM, false),
		B("Washer", 4, 5, 3.4, 0, 2.5, -0.2, "white", PLASTIC),
		B("Porthole", 2.2, 2.2, 0.2, 0, 2.8, 1.5, "glass", GLASSM, false),
		B("Washer", 4, 5, 3.4, 4.4, 2.5, -0.2, "white", PLASTIC),
		B("Porthole", 2.2, 2.2, 0.2, 4.4, 2.8, 1.5, "glass", GLASSM, false),
	},
}
defs.foldingTable = {
	w = 9,
	d = 4.4,
	stop = "Work",
	parts = {
		B("FoldingTable", 8, 0.4, 3.4, 0, 3.2, 0, "white", PLASTIC),
		B("TableBase", 7, 3, 1.2, 0, 1.5, 0, "steel", METALM),
		B("LinenStack", 2, 0.9, 1.6, -2.6, 3.85, 0, "cloth", FAB, false),
		B("LinenStack", 2, 0.7, 1.6, 0, 3.75, 0.3, "fabric", FAB, false),
		B("LinenStack", 2, 1.1, 1.6, 2.6, 3.95, -0.2, "cloth", FAB, false),
	},
}
defs.cart = {
	w = 4.6,
	d = 2.8,
	parts = {
		B("CartDeck", 4, 0.3, 2.2, 0, 1.6, 0, "steel", METALM),
		B("CartShelf", 4, 0.2, 2, 0, 0.8, 0, "steel", METALM),
		B("CartPost", 0.2, 3.4, 0.2, -1.9, 2.6, -1, "steel", METALM),
		B("CartPost", 0.2, 3.4, 0.2, 1.9, 2.6, -1, "steel", METALM),
		B("CartLoad", 3, 1.4, 1.8, 0, 2.5, 0, "fabric", FAB, false),
	},
}
defs.laundryCart = {
	w = 4.4,
	d = 3.4,
	parts = {
		B("LaundryBin", 4, 3, 3, 0, 1.6, 0, "steel", METALM),
		B("Laundry", 3.6, 1, 2.6, 0, 3.4, 0, "cloth", FAB, false),
	},
}

-- Machinery
defs.boiler = {
	w = 9,
	d = 9,
	parts = {
		U("BoilerTank", 7, 10, 0, 0, 0, "steel", METALM),
		U("BoilerCap", 5, 1.4, 0, 0, 10, "steel", METALM),
		Hx("BoilerPipe", 9, 0.9, 0, 11.4, 0, "steel", METALM),
		B("Gauge", 0.9, 0.9, 0.3, 0, 6, 3.5, "neon", NEON, false),
		U("Valve", 0.8, 2, 3.6, 3.6, 0, "brass", METALM),
	},
}
defs.generator = {
	w = 10,
	d = 6,
	parts = {
		B("Generator", 9, 5, 5, 0, 2.5, 0, "steel", METALM),
		U("Exhaust", 0.9, 6, 3, -1, 5, "black", METALM),
		B("GeneratorVent", 5, 0.6, 0.2, -1.5, 3.4, 2.55, "black", PLASTIC, false),
		B("StatusLight", 0.9, 0.5, 0.2, 3, 4, 2.55, "neon", NEON, false),
	},
}
defs.pipeRun = {
	w = 14,
	d = 1.8,
	parts = {
		Hx("Pipe", 14, 1.2, 0, 9, -0.5, "steel", METALM),
		Hx("Pipe", 14, 0.8, 0, 6.6, -0.5, "brass", METALM),
		B("PipeBracket", 0.4, 3, 0.8, -5, 7.8, -0.5, "dark", METALM, false),
		B("PipeBracket", 0.4, 3, 0.8, 5, 7.8, -0.5, "dark", METALM, false),
	},
}
defs.serverRack = {
	w = 4,
	d = 3.4,
	parts = {
		B("ServerRack", 3.6, 8, 3, 0, 4, -0.2, "black", PLASTIC),
		B("RackLights", 3, 0.2, 0.2, 0, 6.6, 1.35, "neon", NEON, false),
		B("RackLights", 3, 0.2, 0.2, 0, 4.4, 1.35, "neon", NEON, false),
		B("RackLights", 3, 0.2, 0.2, 0, 2.2, 1.35, "neon", NEON, false),
	},
}
defs.serverRow = {
	w = 16,
	d = 3.4,
	stop = "Work",
	subs = { { "serverRack", -6, 0 }, { "serverRack", -2, 0 }, { "serverRack", 2, 0 }, { "serverRack", 6, 0 } },
}

-- Bedrooms and bathrooms
defs.suiteBed = {
	w = 14,
	d = 9.8,
	parts = {
		B("BedFrame", 7, 1.6, 9.5, 0, 0.8, 0.1, "dark", WOODM),
		B("Mattress", 6.6, 1, 9, 0, 2.1, 0.1, "cloth", FAB),
		B("Duvet", 6.6, 0.4, 6, 0, 2.8, 1.5, "fabric", FAB, false),
		B("Headboard", 7, 4.5, 0.6, 0, 2.25, -4.6, "dark", WOODM),
		B("Pillow", 2.8, 0.7, 1.6, -1.8, 2.9, -3.3, "cloth", FAB, false),
		B("Pillow", 2.8, 0.7, 1.6, 1.8, 2.9, -3.3, "cloth", FAB, false),
		B("Nightstand", 2, 2.2, 2, -5, 1.1, -3.8, "dark", WOODM),
		B("Nightstand", 2, 2.2, 2, 5, 1.1, -3.8, "dark", WOODM),
		O("BedLamp", 1.1, -5, 3, -3.8, "warm", NEON, false),
		O("BedLamp", 1.1, 5, 3, -3.8, "warm", NEON, false),
	},
}
defs.wardrobe = {
	w = 8.2,
	d = 3,
	parts = {
		B("Wardrobe", 8, 9, 2.6, 0, 4.5, -0.2, "dark", WOODM),
		B("WardrobeSeam", 0.12, 8, 0.1, 0, 4.5, 1.1, "black", PLASTIC, false),
		B("WardrobeHandle", 0.3, 1.2, 0.3, -0.6, 4.5, 1.25, "brass", METALM, false),
		B("WardrobeHandle", 0.3, 1.2, 0.3, 0.6, 4.5, 1.25, "brass", METALM, false),
	},
}
defs.dresser = {
	w = 6.4,
	d = 2.8,
	parts = {
		B("Dresser", 6, 3.6, 2.4, 0, 1.8, -0.1, "dark", WOODM),
		glass(B("DresserMirror", 4, 4.4, 0.2, 0, 6.4, -1.1, "glass", GLASSM, false)),
		B("DresserLamp", 1, 1, 1, -2, 4.2, 0, "warm", NEON, false),
	},
}
defs.tvConsole = {
	w = 8.2,
	d = 2.6,
	parts = {
		B("TvConsole", 8, 2.4, 2, 0, 1.2, -0.2, "dark", WOODM),
		B("Television", 5.6, 3.2, 0.3, 0, 4.4, -0.4, "black", PLASTIC),
		B("TvScreen", 5.2, 2.8, 0.1, 0, 4.4, -0.2, "screen", NEON, false),
	},
}
defs.stallRow = {
	w = 10,
	d = 4.8,
	parts = {
		B("StallWall", 0.2, 7, 4.4, -4.9, 3.5, -0.2, "steel", PLASTIC),
		B("StallWall", 0.2, 7, 4.4, 0, 3.5, -0.2, "steel", PLASTIC),
		B("StallWall", 0.2, 7, 4.4, 4.9, 3.5, -0.2, "steel", PLASTIC),
		B("StallDoor", 4.6, 6.4, 0.15, -2.5, 3.4, 2, "steel", PLASTIC),
		B("StallDoor", 4.6, 6.4, 0.15, 2.5, 3.4, 2, "steel", PLASTIC),
		B("Toilet", 1.6, 1.6, 2.2, -2.5, 0.8, -1.2, "white", PLASTIC),
		B("ToiletTank", 1.6, 1.8, 0.8, -2.5, 2.2, -2.1, "white", PLASTIC),
		B("Toilet", 1.6, 1.6, 2.2, 2.5, 0.8, -1.2, "white", PLASTIC),
		B("ToiletTank", 1.6, 1.8, 0.8, 2.5, 2.2, -2.1, "white", PLASTIC),
	},
}
defs.sinkRow = {
	w = 9,
	d = 2.8,
	stop = "Lean",
	parts = {
		B("VanityCounter", 9, 3.2, 2.4, 0, 1.6, -0.2, "stone", MARBLE),
		B("Basin", 2.4, 0.2, 1.6, -2.4, 3.3, 0, "white", PLASTIC, false),
		B("Basin", 2.4, 0.2, 1.6, 2.4, 3.3, 0, "white", PLASTIC, false),
		glass(B("Mirror", 8, 5, 0.2, 0, 7.5, -1.2, "glass", GLASSM, false)),
	},
}

-- Outdoor
defs.outdoorLounge = {
	w = 14,
	d = 11,
	stop = "Talk",
	parts = {
		B("DaybedBase", 6.6, 1.4, 3, -3.6, 0.7, -3, "wood", WOODM),
		B("DaybedCushion", 6.2, 0.8, 2.6, -3.6, 1.8, -3, "cloth", FAB, false),
		B("DaybedBase", 6.6, 1.4, 3, 3.6, 0.7, -3, "wood", WOODM),
		B("DaybedCushion", 6.2, 0.8, 2.6, 3.6, 1.8, -3, "cloth", FAB, false),
		B("SideTable", 3, 1.6, 3, 0, 0.8, 2.6, "wood", WOODM),
		U("ParasolPole", 0.3, 9, 0, -3, 1, "steel", METALM),
		U("ParasolCanopy", 11, 0.4, 0, -3, 10, "cloth", FAB, false),
	},
}
defs.fireBowl = {
	w = 4.4,
	d = 4.4,
	parts = {
		U("BowlBase", 2.2, 2, 0, 0, 0, "stone", MARBLE),
		U("Bowl", 3.6, 0.9, 0, 0, 2, "black", METALM),
		O("Flame", 2, 0, 3.8, 0, "warm", NEON, false),
	},
}
defs.lanternPost = {
	w = 1.6,
	d = 1.6,
	parts = { U("LanternPost", 0.4, 8, 0, 0, 0, "black", METALM), O("Lantern", 1.6, 0, 8.6, 0, "warm", NEON, false) },
}

-- Recipes ---------------------------------------------------------------------------------------------------------------------------------------
type Step = { m: string, f: string, n: number, gap: number?, aisle: number? }
type Recipe = { style: string, steps: { Step } }
local function W(f: string, n: number, gap: number?): Step
	return { m = "wall", f = f, n = n, gap = gap }
end
local function F(f: string, n: number, aisle: number?): Step
	return { m = "free", f = f, n = n, aisle = aisle }
end

local recipes: { [string]: Recipe } = {
	atrium = {
		style = "deco",
		steps = {
			F("statue", 3, 3),
			F("bench", 8, 3),
			F("bigPlant", 10, 2),
			W("bench", 4),
			W("bigPlant", 6),
			W("floorLamp", 6),
		},
	},
	colonnade = {
		style = "deco",
		steps = { W("consoleTable", 4, 10), W("bench", 3, 14), W("bigPlant", 4, 12), W("floorLamp", 4, 14) },
	},
	gallery = {
		style = "deco",
		steps = {
			F("exhibit", 8, 2),
			F("statue", 3, 3),
			F("bench", 4, 3),
			W("consoleTable", 3, 14),
			W("bigPlant", 4),
			W("floorLamp", 4),
		},
	},
	concierge = {
		style = "deco",
		steps = {
			W("officeDesk", 2, 6),
			F("loungeSet", 1, 2),
			W("consoleTable", 3, 8),
			W("filingRow", 1),
			W("bigPlant", 3),
			W("floorLamp", 3),
			F("luggageCart", 2, 2),
			F("infoKiosk", 1, 2),
		},
	},
	cloakroom = {
		style = "service",
		steps = { F("coatRack", 8, 2), W("cashierCounter", 1), W("lockerRow", 3), W("bench", 2) },
	},
	ballroom = {
		style = "deco",
		steps = {
			W("bandStage", 1),
			W("buffet", 2, 4),
			F("cocktail", 14, 1.5),
			W("bench", 3),
			W("bigPlant", 6),
			W("floorLamp", 6),
			W("sideboard", 2),
		},
	},
	bar = {
		style = "deco",
		steps = { W("booth", 4, 3), F("cocktail", 6, 2), W("bigPlant", 3), W("floorLamp", 3), W("sideboard", 2) },
	},
	dining = {
		style = "deco",
		steps = {
			F("diningSet", 14, 1.5),
			W("sideboard", 3, 8),
			W("bigPlant", 4),
			W("floorLamp", 4),
			W("consoleTable", 2),
		},
	},
	privdining = {
		style = "exec",
		steps = { F("diningSet", 2, 2), W("sideboard", 2), W("bigPlant", 2), W("floorLamp", 2) },
	},
	kitchen = {
		style = "service",
		steps = {
			W("rangeStove", 3, 2),
			W("fridge", 3, 1),
			W("sinkUnit", 2, 2),
			W("counterRun", 5, 1),
			F("prepIsland", 4, 2),
			W("wallShelf", 3, 2),
			F("cart", 2, 2),
		},
	},
	pantry = {
		style = "service",
		steps = {
			F("shelfRow", 8, 1.5),
			W("counterRun", 3),
			W("fridge", 2),
			F("palletStack", 4, 1.5),
			F("cart", 2, 1.5),
		},
	},
	coldstore = { style = "service", steps = { F("shelfRow", 2, 1.5), W("fridge", 2), F("palletStack", 2, 1.5) } },
	stockroom = { style = "service", steps = { F("shelfRow", 2, 1.5), F("crateStack", 3, 1.5), W("wallShelf", 2) } },
	library = {
		style = "deco",
		steps = {
			W("fireplace", 1),
			W("bookcase", 12, 0),
			F("bookRow", 5, 3),
			F("readingTable", 5, 2),
			F("loungeSet", 2, 2),
			W("bigPlant", 4),
			W("floorLamp", 4),
		},
	},
	lobby = {
		style = "hotel",
		steps = {
			F("loungeSet", 8, 1.5),
			F("infoKiosk", 2, 3),
			F("luggageCart", 3, 3),
			W("bench", 4),
			W("consoleTable", 4, 10),
			W("bigPlant", 8),
			W("floorLamp", 6),
			F("statue", 2, 3),
		},
	},
	lounge = {
		style = "deco",
		steps = {
			W("fireplace", 1),
			F("loungeSet", 4, 2),
			F("cocktail", 4, 2),
			W("humidor", 2, 2),
			W("bookcase", 4, 0),
			F("pianoSet", 1, 3),
			W("bigPlant", 3),
			W("floorLamp", 4),
		},
	},
	casino = {
		style = "casino",
		steps = {
			F("casinoTable", 8, 1),
			F("slotIsland", 8, 1.5),
			F("cardTable", 8, 1.5),
			W("slotWall", 14, 0),
			F("cocktail", 6, 1.5),
			W("bench", 3),
			W("bigPlant", 4),
		},
	},
	cardroom = {
		style = "casino",
		steps = { F("cardTable", 3, 2), W("sideboard", 2), W("bigPlant", 2), W("floorLamp", 2) },
	},
	hotelLobby = {
		style = "hotel",
		steps = {
			F("loungeSet", 3, 2),
			F("luggageCart", 2, 3),
			W("bench", 3),
			W("consoleTable", 3, 10),
			W("bigPlant", 5),
			W("floorLamp", 3),
		},
	},
	cage = {
		style = "service",
		steps = { W("cashierCounter", 3, 2), W("safeWall", 3, 2), F("deskPod", 2, 2), W("filingRow", 2) },
	},
	highroller = {
		style = "exec",
		steps = {
			F("loungeSet", 4, 2),
			F("cardTable", 2, 2),
			F("cocktail", 3, 2),
			W("sideboard", 2),
			W("bookcase", 2, 0),
			W("bigPlant", 3),
			W("floorLamp", 3),
		},
	},
	restroom = { style = "service", steps = { W("stallRow", 2, 1), W("sinkRow", 2, 1) } },
	balcony = {
		style = "deco",
		steps = {
			F("loungeSet", 8, 2),
			F("cocktail", 4, 2),
			W("bench", 6),
			W("bigPlant", 6),
			W("floorLamp", 4),
			F("statue", 2, 3),
		},
	},
	gallerylift = {
		style = "deco",
		steps = { F("exhibit", 6, 2), F("bench", 4, 3), W("consoleTable", 2, 12), W("bigPlant", 3) },
	},
	loft = { style = "deco", steps = { F("cocktail", 5, 2), W("booth", 2, 3), W("bigPlant", 2), W("floorLamp", 2) } },
	winelounge = {
		style = "deco",
		steps = { W("wineRack", 4, 2), F("cocktail", 6, 2), F("loungeSet", 2, 2), W("bigPlant", 3), W("floorLamp", 3) },
	},
	cigarlounge = {
		style = "deco",
		steps = {
			W("fireplace", 1),
			F("loungeSet", 4, 2),
			W("humidor", 2, 2),
			W("bookcase", 3, 0),
			W("bigPlant", 3),
			W("floorLamp", 3),
		},
	},
	stairhall = {
		style = "deco",
		steps = {
			F("statue", 2, 3),
			F("bench", 3, 3),
			F("loungeSet", 2, 2),
			W("bigPlant", 4),
			W("floorLamp", 4),
			W("consoleTable", 2, 10),
		},
	},
	bridgehall = { style = "deco", steps = { W("bench", 2), W("consoleTable", 2, 8), W("bigPlant", 2) } },
	offices = {
		style = "service",
		steps = {
			F("deskPod", 8, 2),
			W("filingRow", 3),
			W("copier", 2, 3),
			W("waterCooler", 2, 6),
			W("whiteboard", 2, 6),
			W("bigPlant", 3),
			W("bookcase", 2, 0),
		},
	},
	security = {
		style = "security",
		steps = {
			W("monitorWall", 2, 2),
			F("deskPod", 3, 2),
			W("filingRow", 2),
			W("noticeboard", 2, 4),
			W("lockerRow", 2),
		},
	},
	camera = {
		style = "security",
		steps = { W("monitorWall", 3, 2), F("deskPod", 3, 2), W("filingRow", 1), W("noticeboard", 1) },
	},
	records = { style = "exec", steps = { F("readingTable", 1, 2), W("filingRow", 2) } },
	housekeeping = {
		style = "service",
		steps = {
			W("washerRow", 2, 2),
			F("foldingTable", 3, 2),
			F("cart", 6, 1.5),
			F("shelfRow", 4, 1.5),
			F("laundryCart", 3, 1.5),
		},
	},
	servicehall = {
		style = "service",
		steps = {
			F("cart", 8, 2),
			W("wallShelf", 4, 3),
			F("crateStack", 5, 2),
			W("pipeRun", 2, 4),
			F("laundryCart", 3, 2),
		},
	},
	laundry = {
		style = "service",
		steps = {
			W("washerRow", 4, 2),
			F("foldingTable", 3, 2),
			F("laundryCart", 4, 1.5),
			F("shelfRow", 3, 1.5),
			F("cart", 3, 1.5),
		},
	},
	linen = { style = "service", steps = { F("shelfRow", 8, 1.5), F("cart", 2, 1.5), F("foldingTable", 1, 2) } },
	stores = {
		style = "service",
		steps = { F("shelfRow", 10, 1.5), F("palletStack", 8, 1.5), F("crateStack", 6, 1.5), W("wallShelf", 4, 2) },
	},
	cellar = {
		style = "service",
		steps = { W("wineRack", 8, 1), F("barrelStack", 6, 2), F("cocktail", 2, 2), F("palletStack", 2, 2) },
	},
	barracks = {
		style = "security",
		steps = { F("bunk", 16, 1.5), W("lockerRow", 6, 1), F("longTable", 1, 2), W("noticeboard", 2, 4) },
	},
	mess = {
		style = "security",
		steps = {
			F("longTable", 6, 2),
			W("counterRun", 3, 1),
			W("fridge", 2, 1),
			W("rangeStove", 1, 2),
			W("sinkUnit", 1, 1),
		},
	},
	armory = {
		style = "security",
		steps = { W("weaponRack", 10, 1), F("workbench", 2, 2), F("crateStack", 6, 1.5), W("lockerRow", 4, 1) },
	},
	muster = {
		style = "security",
		steps = {
			F("longTable", 3, 3),
			W("bench", 6),
			W("noticeboard", 3, 6),
			W("weaponRack", 3, 4),
			W("whiteboard", 2, 6),
		},
	},
	checkpoint = {
		style = "security",
		steps = { F("securityDesk", 1, 2), W("monitorWall", 1, 2), W("lockerRow", 2), W("bench", 2) },
	},
	spine = { style = "security", steps = { W("bench", 4, 12), W("noticeboard", 3, 14), W("bigPlant", 3, 18) } },
	servicering = { style = "service", steps = { W("crateStack", 4, 22), W("pipeRun", 3, 16), W("cart", 2, 30) } },
	tunnel = { style = "service", steps = { W("pipeRun", 1, 2) } },
	boiler = { style = "service", steps = { F("boiler", 5, 2), W("pipeRun", 4, 4), W("generator", 1, 2) } },
	plant = {
		style = "service",
		steps = { F("generator", 2, 2), W("serverRow", 3, 2), F("boiler", 1, 2), W("pipeRun", 2, 4) },
	},
	guardhall = {
		style = "security",
		steps = { W("bench", 6, 18), W("weaponRack", 2, 30), W("lockerRow", 3, 20), W("noticeboard", 3, 24) },
	},
	guardpost = { style = "security", steps = { F("deskPod", 1, 2), W("monitorWall", 1, 2), W("weaponRack", 2, 2) } },
	countinghall = { style = "security", steps = { F("deskPod", 3, 2), W("filingRow", 2), W("safeWall", 2) } },
	coldroom = { style = "service", steps = { F("shelfRow", 3, 1.5), F("palletStack", 3, 1.5), W("fridge", 2) } },
	displayhall = { style = "exec", steps = { F("exhibit", 5, 2), F("bench", 2, 3), W("bigPlant", 2) } },
	observatory = { style = "exec", steps = { W("bench", 2), W("bigPlant", 2), F("statue", 1, 3) } },
	suite = {
		style = "hotel",
		steps = {
			W("suiteBed", 1, 2),
			W("wardrobe", 1, 2),
			W("dresser", 1, 2),
			W("tvConsole", 1, 2),
			W("sofa", 1, 2),
			W("consoleTable", 2, 4),
			W("bigPlant", 2),
			W("floorLamp", 2),
		},
	},
	execsuite = {
		style = "exec",
		steps = { W("suiteBed", 1, 2), W("wardrobe", 1, 2), W("dresser", 1, 2), W("tvConsole", 1, 2) },
	},
	arcade = {
		style = "casino",
		steps = { W("slotWall", 10, 0), F("bench", 8, 3), F("cocktail", 4, 2), W("bigPlant", 4), W("floorLamp", 4) },
	},
	greatroom = {
		style = "exec",
		steps = {
			F("loungeSet", 6, 2),
			F("pianoSet", 1, 3),
			F("exhibit", 3, 2),
			F("cocktail", 2, 2),
			F("statue", 2, 3),
			W("fireplace", 1),
			W("bookcase", 6, 0),
			W("sideboard", 2),
			W("bigPlant", 4),
			W("floorLamp", 4),
		},
	},
	execoffice = { style = "exec", steps = { W("officeDesk", 1, 2), W("bookcase", 2, 0) } },
	panic = { style = "security", steps = { F("cot", 2, 0.5), F("crateStack", 1, 0.5) } },
	summit = {
		style = "exec",
		steps = {
			F("loungeSet", 2, 2),
			F("statue", 2, 3),
			W("bigPlant", 3),
			W("floorLamp", 3),
			W("consoleTable", 2, 8),
		},
	},
	sanctum = {
		style = "exec",
		steps = {
			F("loungeSet", 2, 2),
			F("exhibit", 2, 2),
			W("bookcase", 3, 0),
			W("sideboard", 1),
			W("bigPlant", 2),
			W("floorLamp", 2),
		},
	},
	foyer = {
		style = "exec",
		steps = { W("consoleTable", 2, 12), W("bigPlant", 2, 14), W("floorLamp", 2, 14), F("statue", 1, 3) },
	},
	terrace = {
		style = "outdoor",
		steps = {
			F("outdoorLounge", 6, 2),
			F("parasolTable", 8, 2),
			F("fireBowl", 6, 2),
			F("lanternPost", 10, 2),
			F("bench", 4, 2),
		},
	},
	roofdeck = {
		style = "outdoor",
		steps = {
			F("djBooth", 1, 3),
			F("outdoorLounge", 10, 2),
			F("parasolTable", 14, 2),
			F("fireBowl", 8, 2),
			F("lanternPost", 12, 2),
		},
	},
	garden = {
		style = "outdoor",
		steps = {
			F("outdoorLounge", 4, 2),
			F("parasolTable", 8, 2),
			F("fireBowl", 4, 2),
			F("lanternPost", 10, 2),
			F("bench", 6, 2),
		},
	},
	skydeck = { style = "outdoor", steps = { F("bench", 4, 2), F("fireBowl", 2, 2), F("lanternPost", 4, 2) } },
}

-- The engine ------------------------------------------------------------------------------------------------------------------------------------
local Fabs = {}

function Fabs.has(archetype: string): boolean
	return recipes[archetype] ~= nil
end

local function palette(style: string, rng: Random): { [string]: any }
	local merged: { [string]: any } = table.clone(base)
	for key, value in styles[style] or {} do
		merged[key] = value
	end
	-- The room's fabric is chosen once so its chairs, sofas and bunks match.
	local fabric = merged.fabric
	if typeof(fabric) == "table" then
		merged.fabric = (fabric :: { Color3 })[rng:NextInteger(1, #(fabric :: { Color3 }))]
	end
	return merged
end

local function build(ctx: any, frame: CFrame, id: string, pal: { [string]: any }, rng: Random)
	local def = defs[id]
	assert(def, `Unknown fab {id}`)
	for _, spec in def.parts or {} do
		local cf = frame * CFrame.new(spec.p) * (spec.rot or CFrame.identity)
		local p: Part = ctx.part(ctx.propsFolder, spec.n, spec.size, cf, resolve(pal, spec.c, rng))
		if spec.kind == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif spec.kind == "ball" then
			p.Shape = Enum.PartType.Ball
		end
		if spec.m then
			p.Material = spec.m
		end
		if spec.solid == false then
			p.CanCollide = false
		end
		if spec.clear then
			p.Transparency = spec.clear
		end
		if def.flat then
			p.CanQuery, p.CanTouch, p.CastShadow = false, false, false
		end
	end
	for _, sub in def.subs or {} do
		local at = frame
			* CFrame.new(sub[2] :: number, (sub[5] :: number?) or 0, sub[3] :: number)
			* CFrame.Angles(0, (sub[4] :: number?) or 0, 0)
		build(ctx, at, sub[1] :: string, pal, rng)
	end
end

local function hash(text: string): number
	local h = 17
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 1000003
	end
	return h
end

-- How much of a room's floor its furniture covers (each footprint counts with its aisles) before the rest is left open to walk. Owner 2026-11-22:
-- the rooms were still mostly empty, so free-standing groups keep being added, round after round, until the target is met or nothing more fits.
local FILL_TARGET = 0.5
local FILL_PASSES = 8
-- Real furniture sets (tables, bunks, shelves, desks) asked for in numbers may grow to GROWTH times as many to fill the floor; decoration (lanterns, fire
-- bowls, statues, carts) keeps to its number, or it would wall off the walkways.
local GROWABLE: { [string]: boolean } = {
	diningSet = true,
	cocktail = true,
	loungeSet = true,
	deskPod = true,
	bunk = true,
	longTable = true,
	shelfRow = true,
	casinoTable = true,
	slotIsland = true,
	cardTable = true,
	foldingTable = true,
	exhibit = true,
	barrelStack = true,
	palletStack = true,
	readingTable = true,
	bookRow = true,
}
local FILL_NARROW = 24 -- no gap fillers in a room narrower than this: corridors stay clear
local FILLERS = { "bigPlant", "floorLamp", "bench", "armchair" }
local GROWTH = 4

function Fabs.furnish(room: any, archetype: string, ctx: any)
	local recipe = recipes[archetype]
	assert(recipe, `Unknown furnishing recipe {archetype} on {room.id}`)
	local rng = Random.new(hash(room.id))
	local pal = palette(recipe.style, rng)
	local floorY = ctx.levels[room.level]
	local stops: { [string]: number } = {}
	local report: { string } = {}

	local function placeWall(step: Step): number
		local def = defs[step.f]
		local spacing = def.w + (step.gap or 2)
		return ctx.alongWalls(room, spacing, def.w, def.d + 1.5, step.n, function(spot: any): boolean
			local frame = CFrame.new(spot.wallX + spot.nx * def.d / 2, floorY, spot.wallZ + spot.nz * def.d / 2)
				* CFrame.Angles(0, math.atan2(spot.nx, spot.nz), 0)
			build(ctx, frame, step.f, pal, rng)
			if def.stop and (stops[step.f] or 0) < ctx.stopsPerKind then
				stops[step.f] = (stops[step.f] or 0) + 1
				ctx.stopBefore(room, spot, def.d + 1.5, def.stop)
			end
			return true
		end)
	end

	local function placeFree(step: Step, limit: number): number
		local def = defs[step.f]
		local aisle = step.aisle or 2
		return ctx.group(room, def.w + aisle * 2, def.d + aisle * 2, limit, step.n >= 6, function(frame: CFrame)
			build(ctx, frame, step.f, pal, rng)
			if def.stop and (stops[step.f] or 0) < ctx.stopsPerKind then
				stops[step.f] = (stops[step.f] or 0) + 1
				local at = frame:PointToWorldSpace(Vector3.new(0, 0, def.d / 2 + aisle + ctx.stopClear + 0.4))
				local middle = frame.Position
				ctx.addStop(room, at.X, at.Z, def.stop, middle.X, middle.Z)
			end
		end)
	end

	-- Pieces against the walls first: they claim the walls.
	local frees: { Step } = {}
	for _, step in recipe.steps do
		assert(defs[step.f], `Unknown fab {step.f} in recipe {archetype}`)
		if step.m == "wall" then
			table.insert(report, `{step.f} {placeWall(step)}/{step.n}`)
		else
			table.insert(frees, step)
		end
	end
	-- Then the free-standing groups, a round at a time so every kind gets its share of the floor.
	local total: { [Step]: number } = {}
	for _ = 1, FILL_PASSES do
		if ctx.coverage(room) >= FILL_TARGET then
			break
		end
		local progressed = false
		for _, step in frees do
			local cap = if GROWABLE[step.f] then step.n * GROWTH else step.n
			local done = total[step] or 0
			if done < cap then
				local placed = placeFree(step, math.min(cap - done, math.max(1, math.ceil(step.n / 3))))
				total[step] = done + placed
				if placed > 0 then
					progressed = true
				end
			end
		end
		if not progressed then
			break
		end
	end
	for _, step in frees do
		table.insert(report, `{step.f} {total[step] or 0}/{step.n}`)
	end
	-- Last, small pieces (plants, lamps, benches) tucked into whatever gaps are left, for the indoor rooms that are still bare (outdoors the walkways stay open).
	local tucked = 0
	for _ = 1, FILL_PASSES do
		if room.kind ~= "indoor" or ctx.span(room) < FILL_NARROW or ctx.coverage(room) >= FILL_TARGET + 0.1 then
			break
		end
		local progressed = false
		for _, filler in FILLERS do
			if placeFree({ m = "free", f = filler, n = 4, aisle = 1.5 }, 4) > 0 then
				progressed = true
				tucked += 1
			end
		end
		if not progressed then
			break
		end
	end
	if tucked > 0 then
		table.insert(report, `gap fillers {tucked}`)
	end
	print(`[Gala]      furnish {room.id} ({archetype}): {table.concat(report, ", ")}`)
end

return Fabs
