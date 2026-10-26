// Turns the approved re-layout plan (tools/relayout-plan-data.cjs) into the generator's layout module,
// src/server/Tools/Gala/Relayout.luau (docs/MAP_PLAN_RELAYOUT.md). Usage: node tools/relayout-layout.cjs [--dry]
//
// What it adds to the plan's 103 zone rooms: restrooms and other nested rooms, the glass elevator shafts (a nested room
// on every level a shaft passes), the Sanctum's stair vestibule, door positions, and every stair, vent and secret exit,
// each placed by search so it satisfies the same rules Build.luau's self-check enforces (inside one room, clear of
// doorways and of other stairs). It then re-runs the plan's reachability, entrance and route-count checks on the real
// result and writes the layout. Nothing here is a second source of truth for the plan: rooms, doors and connectors come
// from relayout-plan-data.cjs; this file only adds what the plan leaves to the build.
"use strict";
const fs = require("fs");
const path = require("path");
const D = require("./relayout-plan-data.cjs");

const OUT = path.join(__dirname, "..", "src", "server", "Tools", "Gala", "Relayout.luau");
const REPORT = path.join(__dirname, "..", "docs", "plans", "relayout", "layout-report.md");
const DRY = process.argv.includes("--dry");
const EPS = 1e-4;
const problems = [];
const notes = [];
const bad = (m) => problems.push(m);

// ---------------------------------------------------------------- constants shared with Build.luau
const LEVELS = { B: -24, G: 0, M: 24, T: 48, R: 72, S: 96 };
const LEVEL_ORDER = ["B", "G", "M", "T", "R", "S"];
const SLAB = 2, HEADROOM = 7, LANDING = 6, LANE_GAP = 2, STAIR_CLEAR = 6, STAIR_GAP = 2, DOOR_CLEAR = 7;
const lv = (l) => (l === "D" ? "S" : l);

// ---------------------------------------------------------------- rect helpers (the same rules as Build.luau)
const R = (a) => ({ x1: a[0], z1: a[1], x2: a[2], z2: a[3] });
const overlaps = (p, q) => p.x1 < q.x2 - EPS && q.x1 < p.x2 - EPS && p.z1 < q.z2 - EPS && q.z1 < p.z2 - EPS;
const inflate = (r, a) => ({ x1: r.x1 - a, z1: r.z1 - a, x2: r.x2 + a, z2: r.z2 + a });
const eq = (a, b) => Math.abs(a - b) < EPS;
function subtract(rects, hole) {
	const out = [];
	for (const r of rects) {
		if (!overlaps(r, hole)) { out.push(r); continue; }
		if (hole.x1 > r.x1 + EPS) out.push({ x1: r.x1, z1: r.z1, x2: hole.x1, z2: r.z2 });
		if (hole.x2 < r.x2 - EPS) out.push({ x1: hole.x2, z1: r.z1, x2: r.x2, z2: r.z2 });
		const mx1 = Math.max(r.x1, hole.x1), mx2 = Math.min(r.x2, hole.x2);
		if (hole.z1 > r.z1 + EPS) out.push({ x1: mx1, z1: r.z1, x2: mx2, z2: hole.z1 });
		if (hole.z2 < r.z2 - EPS) out.push({ x1: mx1, z1: hole.z2, x2: mx2, z2: r.z2 });
	}
	return out;
}
const rectArr = (r) => [r.x1, r.z1, r.x2, r.z2];
const centre = (r) => [(r.x1 + r.x2) / 2, (r.z1 + r.z2) / 2];

// ---------------------------------------------------------------- the rooms
const rooms = [];
const roomMap = new Map();
function addRoom(o) {
	const room = { holes: [], props: [], parent: null, ...o };
	rooms.push(room);
	roomMap.set(room.id, room);
	return room;
}
for (const p of D.rooms) {
	addRoom({
		id: p.id, level: lv(p.level), name: p.name, tier: p.tier, kind: p.kind === "OUT" ? "outdoor" : "indoor",
		rect: { ...p.rect }, holes: p.holes.map((h) => ({ ...h })), hub: p.hub, vault: p.vault, w: p.w, nested: p.nested, tower: p.tower,
	});
}
const room = (id) => { const r = roomMap.get(id); if (!r) throw new Error(`unknown room ${id}`); return r; };

// The atrium void is a shaft through the mezzanine and top floors; the ground floor keeps its pond and the roof a skylight.
const ATRIUM = R([-38, -40, 38, 52]);
const VOIDS = [{ level: "M", rect: ATRIUM }, { level: "T", rect: ATRIUM }];
// The plan draws the atrium as a hole on every level; the ground floor and the two voids are handled by the generator.
for (const id of ["g_atrium", "m_balcony", "t_great"]) room(id).holes = [];
// Nested rooms: parent is the smallest room that holds them.
for (const r of rooms.filter((r) => r.nested)) {
	const parents = rooms.filter((p) => p !== r && p.level === r.level && !p.nested && p.rect.x1 <= r.rect.x1 && p.rect.z1 <= r.rect.z1 && p.rect.x2 >= r.rect.x2 && p.rect.z2 >= r.rect.z2);
	parents.sort((a, b) => (a.rect.x2 - a.rect.x1) * (a.rect.z2 - a.rect.z1) - (b.rect.x2 - b.rect.x1) * (b.rect.z2 - b.rect.z1));
	r.parent = parents[0].id;
}

// Extra nested rooms: restrooms and the smaller rooms real buildings have. [level, id, name, tier, kind, rect, parent, options]
const EXTRA = [
	["G", "g_restroom", "Lobby restrooms", 0, "indoor", [36, 130, 60, 150], "g_lobby", {}],
	["G", "g_staffwc", "Staff washroom", 1, "indoor", [20, -170, 40, -152], "g_pantry", {}],
	["G", "g_coldstore", "Kitchen cold store", 1, "indoor", [-60, -170, -36, -146], "g_kitchen", {}],
	["G", "g_privdining", "Private dining room", 0, "indoor", [-140, -170, -112, -140], "g_dining", {}],
	["G", "g_stockroom", "Bar stockroom", 1, "indoor", [118, 52, 140, 74], "g_bar", {}],
	["G", "g_humidor", "Humidor", 1, "indoor", [112, 114, 140, 150], "g_lounge", {}],
	["G", "wg_restroom", "Casino restrooms", 0, "indoor", [260, 75, 280, 95], "wg_casino", {}],
	["G", "wg_cardroom", "High-stakes card room", 0, "indoor", [160, 20, 190, 50], "wg_casino", {}],
	["M", "m_restroom", "Gallery restrooms", 0, "indoor", [-125, -84, -105, -60], "m_gallery", {}],
	["M", "wm_restroom", "Hotel restrooms", 0, "indoor", [260, 40, 280, 60], "wm_lobby", {}],
	["T", "t_washroom", "Guard washroom", 2, "indoor", [70, 78, 90, 100], "t_east", {}],
	["S", "s_stairhead", "Executive stair head", 4, "indoor", [-33, -70, -5, -50], "s_foyer", {}],
];
for (const [level, id, name, tier, kind, rect, parent, o] of EXTRA) addRoom({ id, level, name, tier, kind, rect: R(rect), parent, nested: true, ...o });

// Props, density and glass per room: what fills it and how many NPCs favour it.
const PROPS = {
	b_stores_w1: ["crates"], b_stores_w2: ["crates"], b_stores_e1: ["crates"], b_cellar: ["crates"], b_camera: ["desks"], b_barracks: ["tables"],
	b_muster: ["pillars"], b_armory: ["crates"], b_mess: ["tables"], wb_laundry: ["crates"], wb_linen: ["crates"], wb_service: ["pillars"],
	wb_boiler: ["pillars"], wb_security: ["desks"],
	g_atrium: ["planters"], g_gallery: ["partitions"], g_concierge: ["desks"], g_coat: ["desks"], g_ballroom: ["pillars", "tables"],
	g_bar: ["bar", "tables"], g_dining: ["tables"], g_kitchen: ["islands"], g_pantry: ["islands"], g_library: ["tables"],
	g_lobby: ["reception", "pillars"], g_lounge: ["tables"], wg_casino: ["pillars", "tables"], wg_entry: ["reception"], wg_cage: ["desks"],
	wg_highroller: ["tables"], g_privdining: ["tables"],
	m_balcony: ["planters"], m_gallery: ["partitions"], m_ball_gal: ["tables"], m_bridge_hall: ["planters"], m_bar_loft: ["tables"],
	m_offices: ["desks"], m_hub: ["desks"], m_catering: ["desks"], m_wine: ["tables"], m_stairhall: ["planters"], m_cigar: ["tables"],
	m_ter_n: ["planters"], m_ter_s: ["planters"], m_ter_w: ["planters"], m_ter_e: ["planters"],
	wm_lobby: ["reception"], wm_bar: ["bar", "tables"], wm_housekeeping: ["crates"],
	t_ter_n: ["planters", "trees"], t_ter_s: ["planters", "trees"], t_ter_w: ["planters", "tables", "trees"], t_ter_e: ["planters", "tables", "trees"],
	t_west: ["pillars"], t_east: ["pillars"], t_gallery: ["vitrines"], t_vaultb_ante: ["vitrines"],
	wt_arcade: ["planters"], wt_suite1: ["tables"], wt_suite2: ["tables"], wt_suite3: ["tables"], wt_suite4: ["tables"], wt_suite5: ["tables"],
	wt_terrace: ["trees", "planters", "tables"], r_deck: ["tables", "planters", "bar"], wr_garden: ["trees", "planters", "bar"], wd_skydeck: ["planters"],
};
const DENSITY = {
	g_atrium: 2, g_ballroom: 2, g_bar: 1.6, g_dining: 1.3, g_gallery: 1.4, g_lobby: 1.5, m_balcony: 1.2, wg_casino: 2, wm_lobby: 1.4, wm_bar: 1.4, r_deck: 2,
	wr_garden: 1.5, b_muster: 1, t_great: 1, wt_terrace: 1, m_ball_gal: 1.2, m_gallery: 1.2, m_stairhall: 1.2, g_privdining: 0.6, wg_cardroom: 1.2,
};
const THEME = { A: "bank", B: "gallery", C: "cold", D: "counting", E: "observatory" };
for (const r of rooms) {
	if (PROPS[r.id]) r.props = PROPS[r.id];
	if (DENSITY[r.id]) r.density = DENSITY[r.id];
	if (r.kind === "indoor" && r.tier === 0 && !r.w) r.glass = true; // windows onto the city on every public facade
	if (r.vault && r.tier === 3 && r.id !== "s_sanctum") { r.noNodes = true; r.theme = THEME[r.vault]; }
}
for (const id of ["m_bridge", "b_tunnel"]) { room(id).noNodes = true; room(id).height = 12; room(id).glass = false; }
room("m_bridge").glass = true;
room("r_deck_w").posts = true;
room("wd_skydeck").posts = true;
room("s_sanctum").noNodes = true;
room("s_sanctum").style = "crown";
for (const id of ["s_foyer", "s_stairhead", "s_ter_w", "s_ter_e"]) room(id).style = "crown";
room("s_ter_w").style = undefined; room("s_ter_e").style = undefined;
// the vault terrace rooms and the summit lobby keep the Executive deco look

// Voids cut pieces out of the rooms on their level.
function childrenOf(id) { return rooms.filter((r) => r.parent === id); }
const pieceCache = new Map();
function pieces(r) {
	if (pieceCache.has(r.id)) return pieceCache.get(r.id);
	let rs = [r.rect];
	for (const c of childrenOf(r.id)) rs = subtract(rs, c.rect);
	for (const h of r.holes) rs = subtract(rs, h);
	for (const v of VOIDS.filter((v) => v.level === r.level)) rs = subtract(rs, v.rect);
	pieceCache.set(r.id, rs);
	return rs;
}
const flushPieces = () => pieceCache.clear();
const roomsOn = (level) => rooms.filter((r) => r.level === level);
// Is rect `r` wholly on the floor of one room on `level` (restricted to `ids` if given)? Returns that room.
function insideOneRoom(level, r, ids) {
	for (const rm of roomsOn(level)) {
		if (ids && !ids.includes(rm.id)) continue;
		let left = [r];
		for (const p of pieces(rm)) left = subtract(left, p);
		if (left.length === 0) return rm;
	}
	return null;
}
function roomAt(level, x, z) {
	for (const rm of roomsOn(level)) for (const p of pieces(rm)) if (x >= p.x1 && x <= p.x2 && z >= p.z1 && z <= p.z2) return rm;
	return null;
}

// ---------------------------------------------------------------- doors
// The shared wall segments between two rooms, as Build.luau sees them (between pieces).
function segs(A, B) {
	const out = [];
	for (const pa of pieces(A)) for (const pb of pieces(B)) {
		if (eq(pa.x2, pb.x1) || eq(pb.x2, pa.x1)) {
			const line = eq(pa.x2, pb.x1) ? pa.x2 : pa.x1, lo = Math.max(pa.z1, pb.z1), hi = Math.min(pa.z2, pb.z2);
			if (hi - lo > EPS) out.push({ axis: "z", line, a: lo, b: hi });
		}
		if (eq(pa.z2, pb.z1) || eq(pb.z2, pa.z1)) {
			const line = eq(pa.z2, pb.z1) ? pa.z2 : pa.z1, lo = Math.max(pa.x1, pb.x1), hi = Math.min(pa.x2, pb.x2);
			if (hi - lo > EPS) out.push({ axis: "x", line, a: lo, b: hi });
		}
	}
	return out;
}
// Which wall of a nested room: e/w/s/n.
function sideSeg(inner, side, list) {
	const r = inner.rect;
	if (side === "e") return list.filter((s) => s.axis === "z" && eq(s.line, r.x2));
	if (side === "w") return list.filter((s) => s.axis === "z" && eq(s.line, r.x1));
	if (side === "s") return list.filter((s) => s.axis === "x" && eq(s.line, r.z2));
	return list.filter((s) => s.axis === "x" && eq(s.line, r.z1));
}

const COST = { 1: 3, 2: 6, 3: 8 }; // Staff, Security, Executive (the plan's door costs)
// Doors the build moves off the middle of their wall so a stair can stand beside them: "a|b" (sorted) -> position along the wall.
const DOOR_AT = { "m_hub|m_offices": -145, "wt_arcade|wt_suite1": -78, "wr_garden|wr_plant": -25, "m_hub|m_records": 15, "m_balcony|m_catering": 68, "s_foyer|s_sanctum": 4, "b_camera|b_gate": -145, "b_barracks|b_gate": -145, "g_kitchen|g_service_n": -50, "m_balcony|m_gallery": -45, "r_deck|r_summit": 8, "g_coat|g_concierge": -80, "g_coat|g_library": -80, "m_gallery|m_wine": -80 };
// Which wall a door uses when two rooms share several: "a|b" (sorted) -> { axis, line }.
const DOOR_PREF = { "r_deck|r_summit": { axis: "x", line: -50 } };
const doors = []; // { a, b, at, line, width, gate, arch, laser, core, cost, package, keycardOnly, level, axis, ... }
const pendingDoors = [];
function wantDoor(d) { pendingDoors.push(d); }
for (const p of D.doors) {
	const A = room(p.a), B = room(p.b);
	const d = { a: p.a, b: p.b, width: p.width, arch: p.arch, laser: p.laser, gate: p.gate, edge: p.edge, note: p.note, at: DOOR_AT[[p.a, p.b].sort().join("|")] };
	if (p.vault && !p.keycardOnly && A.id !== "s_foyer" && B.id !== "s_foyer") { d.core = true; d.gate = 3; }
	if (p.a === "s_foyer" && p.b === "s_sanctum") { d.package = "front"; d.gate = 4; d.cost = 10; d.width = 10; }
	else if (p.a === "s_ter_w" && p.b === "s_sanctum") { d.package = "back"; d.keycardOnly = true; d.gate = 4; d.cost = 0; d.width = 10; }
	else if (p.a === "s_foyer" && (p.b === "s_ter_w" || p.b === "s_ter_e")) { d.gate = 4; d.role = "terrace"; }
	if (!d.gate && !d.arch && A.tier !== B.tier) d.gate = Math.max(A.tier, B.tier); // every tier jump is a real clearance door
	if (d.gate && d.cost === undefined) d.cost = COST[d.gate];
	wantDoor(d);
}
// Restroom and other nested-room doors (a small door on the wall facing the parent's open floor).
const EXTRA_DOORS = [
	["g_restroom", "g_lobby", 6, { side: "n" }], ["g_staffwc", "g_pantry", 6, { side: "e" }], ["g_coldstore", "g_kitchen", 8, { side: "e" }],
	["g_privdining", "g_dining", 10, { side: "e" }], ["g_stockroom", "g_bar", 8, { side: "w" }], ["g_humidor", "g_lounge", 8, { side: "w" }],
	["wg_restroom", "wg_casino", 6, { side: "w" }], ["wg_cardroom", "wg_casino", 10, { side: "e" }], ["m_restroom", "m_gallery", 6, { side: "s" }],
	["wm_restroom", "wm_lobby", 6, { side: "w" }], ["t_washroom", "t_east", 6, { side: "w" }], ["s_stairhead", "s_foyer", 6, { side: "e", gate: 4, role: "stairhead", at: -66 }],
];
for (const [a, b, width, o] of EXTRA_DOORS) {
	const tierA = room(a).tier, tierB = room(b).tier;
	const d = { a, b, width, edge: o.side, at: o.at };
	if (o.gate) { d.gate = o.gate; d.role = o.role; }
	else if (tierA !== tierB) { d.gate = Math.max(tierA, tierB); d.cost = COST[d.gate]; }
	wantDoor(d);
}

// ---------------------------------------------------------------- shafts (glass elevators)
// A shaft is a nested room (tier = the shaft's) on every level it passes; stops have a door onto the parent room.
const SHAFTS = [
	{ id: "E1", name: "Gallery glass elevator", size: 12, stops: ["G", "M", "T"], parents: { G: ["g_gallery"], M: ["m_gallery"], T: ["t_west"] }, hint: [-80, -10], tier: 1 },
	{ id: "E2", name: "Atrium glass elevator", size: 12, stops: ["G", "M", "R"], parents: { G: ["g_atrium"], M: ["m_balcony"], T: ["t_great"], R: ["r_deck"] }, hint: [46, 6], tier: 1 },
	{ id: "E3", name: "Casino glass elevator", size: 12, stops: ["G", "M", "T"], parents: { G: ["wg_casino"], M: ["wm_bar"], T: ["wt_arcade"] }, hint: [250, 80], tier: 1 },
	{ id: "E4", name: "Hotel glass elevator", size: 12, stops: ["G", "M", "T", "R"], parents: { G: ["wg_entry"], M: ["wm_bar"], T: ["wt_arcade"], R: ["wr_garden"] }, hint: [230, 110], tier: 1 },
	{ id: "E5", name: "Sanctum elevator", size: 10, stops: ["T", "R", "S"], parents: { T: ["t_great"], R: ["r_summit"], S: ["s_foyer"] }, fixed: [18, -60], margin: 0, doorSide: { T: "s", R: "n", S: "n" }, tier: 3, locked: true, arrivalTier: { S: 4 }, doorCost: { T: 8, R: 8, S: 8 } },
];
const doorClearOf = (d, level) => {
	// Build.luau: the floor in front of a doorway that stairs must keep off
	const hw = d.width / 2 + 2;
	return d.axis === "x" ? { x1: d.x - hw, z1: d.z - DOOR_CLEAR, x2: d.x + hw, z2: d.z + DOOR_CLEAR } : { x1: d.x - DOOR_CLEAR, z1: d.z - hw, x2: d.x + DOOR_CLEAR, z2: d.z + hw };
};

// ---------------------------------------------------------------- placing doors (plan doors, then shaft and stair-dependent ones)
function resolveDoors() {
	flushPieces();
	// choose the wall segment for each pending door, then spread doors that share one
	const groups = new Map();
	for (const d of pendingDoors) {
		const A = room(d.a), B = room(d.b);
		let list = segs(A, B);
		if (d.edge) {
			const inner = A.parent === B.id ? A : B.parent === A.id ? B : null;
			if (inner) list = sideSeg(inner, d.edge, list);
		}
		if (list.length === 0) { bad(`door ${d.a}/${d.b}: no shared wall${d.edge ? " on side " + d.edge : ""}`); continue; }
		const pref = DOOR_PREF[[d.a, d.b].sort().join("|")];
		if (pref) list = list.filter((e) => e.axis === pref.axis && eq(e.line, pref.line));
		list.sort((p, q) => (q.b - q.a) - (p.b - p.a));
		if (list.length === 0) { bad(`door ${d.a}/${d.b}: no shared wall on the preferred side`); continue; }
		const s = list[0];
		d.seg = s; d.axis = s.axis; d.level = A.level;
		if (s.b - s.a < d.width) d.width = Math.max(4, Math.floor(s.b - s.a - 2));
		const key = `${d.level}|${s.axis}|${s.line}|${s.a}|${s.b}`;
		if (!groups.has(key)) groups.set(key, []);
		groups.get(key).push(d);
	}
	for (const list of groups.values()) {
		const fixed = list.filter((d) => d.at !== undefined);
		const free = list.filter((d) => d.at === undefined);
		const s = list[0].seg;
		const n = free.length;
		free.forEach((d, i) => { d.at = s.a + ((s.b - s.a) * (i + 1)) / (n + 1); });
		for (const d of list) {
			d.at = Math.min(Math.max(d.at, s.a + d.width / 2 + 1), s.b - d.width / 2 - 1);
			if (d.axis === "x") { d.x = d.at; d.z = s.line; } else { d.x = s.line; d.z = d.at; }
		}
	}
	doors.length = 0;
	for (const d of pendingDoors) if (d.seg) doors.push(d);
}

// ---------------------------------------------------------------- the search that places stairs, shafts, vents
const taken = {}; // level -> list of { rect, what } the other stairs, shafts and features occupy
for (const l of LEVEL_ORDER) taken[l] = [];
const reserve = (level, rect, what) => taken[level].push({ rect, what });
// extraction pads and the atrium fountain
reserve("G", R([-23, -17, 23, 29]), "fountain");
for (const e of D.extraction) reserve(lv(e.level), R([e.x - 10, e.z - 10, e.x + 10, e.z + 10]), "pad " + e.id);
reserve("R", R([-88, 2, -52, 38]), "helipad");
function freeOf(level, rect, margin = 0) {
	const r = inflate(rect, margin + STAIR_GAP / 2);
	for (const t of taken[level]) if (overlaps(r, inflate(t.rect, STAIR_GAP / 2))) return false;
	for (const d of doors) if (d.level === level && overlaps(r, doorClearOf(d, level))) return false;
	return true;
}
// posts under rooms that stand on posts: the same layout Build.luau uses (every 16 studs round the edge)
function postRects(r) {
	const out = [];
	const nx = Math.max(1, Math.round((r.x2 - r.x1) / 16)), nz = Math.max(1, Math.round((r.z2 - r.z1) / 16));
	for (let i = 0; i <= nx; i++) { const x = r.x1 + 0.6 + ((r.x2 - r.x1 - 1.2) * i) / nx; out.push({ x1: x - 0.6, z1: r.z1, x2: x + 0.6, z2: r.z1 + 1.2 }, { x1: x - 0.6, z1: r.z2 - 1.2, x2: x + 0.6, z2: r.z2 }); }
	for (let i = 1; i < nz; i++) { const z = r.z1 + 0.6 + ((r.z2 - r.z1 - 1.2) * i) / nz; out.push({ x1: r.x1, z1: z - 0.6, x2: r.x1 + 1.2, z2: z + 0.6 }, { x1: r.x2 - 1.2, z1: z - 0.6, x2: r.x2, z2: z + 0.6 }); }
	return out;
}
function registerPosts() {
	for (const r of rooms.filter((r) => r.posts)) {
		const below = LEVEL_ORDER[LEVEL_ORDER.indexOf(r.level) - 1];
		for (const p of postRects(r.rect)) reserve(below, p, "post of " + r.id);
	}
}

// ---------------------------------------------------------------- shafts: find a spot, add the rooms and the doors
const shaftOut = [];
function placeShaft(S) {
	const iBottom = LEVEL_ORDER.indexOf(S.stops[0]), iTop = LEVEL_ORDER.indexOf(S.stops[S.stops.length - 1]);
	const levelsOfShaft = LEVEL_ORDER.filter((l) => LEVEL_ORDER.indexOf(l) >= iBottom && LEVEL_ORDER.indexOf(l) <= iTop);
	const size = S.size;
	const margin = S.margin === undefined ? 1 : S.margin;
	const candidates = [];
	if (S.fixed) candidates.push({ x: S.fixed[0], z: S.fixed[1], score: 0 });
	else for (let x = -150; x <= 290; x += 1) for (let z = -180; z <= 160; z += 1) candidates.push({ x, z, score: Math.hypot(x + size / 2 - S.hint[0], z + size / 2 - S.hint[1]) });
	candidates.sort((p, q) => p.score - q.score);
	const sides = (rect) => [["n", { x: (rect.x1 + rect.x2) / 2, z: rect.z1, axis: "x", nx: 0, nz: -1 }], ["s", { x: (rect.x1 + rect.x2) / 2, z: rect.z2, axis: "x", nx: 0, nz: 1 }], ["w", { x: rect.x1, z: (rect.z1 + rect.z2) / 2, axis: "z", nx: -1, nz: 0 }], ["e", { x: rect.x2, z: (rect.z1 + rect.z2) / 2, axis: "z", nx: 1, nz: 0 }]];
	let tried = 0;
	for (const c of candidates) {
		const rect = { x1: c.x, z1: c.z, x2: c.x + size, z2: c.z + size };
		let ok = true;
		const parents = {};
		for (const l of levelsOfShaft) {
			const ids = S.parents[l];
			if (!ids) { ok = false; break; }
			const parent = insideOneRoom(l, inflate(rect, margin), ids);
			if (!parent || !freeOf(l, rect, margin)) { ok = false; break; }
			parents[l] = parent;
		}
		if (!ok || ++tried > 400) { if (tried > 400) break; continue; }
		// tentatively add the shaft's rooms, then pick a door side on every stop where the wall is whole and the floor in front is free
		const added = [];
		for (const l of levelsOfShaft) {
			const stop = S.stops.includes(l);
			const tier = (S.arrivalTier && S.arrivalTier[l]) || S.tier;
			added.push(addRoom({ id: `el_${S.id}_${l}`, level: l, name: `${S.name} (${l})`, tier, kind: "indoor", rect: { ...rect }, parent: parents[l].id, nested: true, shaft: S.id, stop, noNodes: true }));
		}
		flushPieces();
		const doorsHere = {};
		for (const sroom of added.filter((r) => r.stop)) {
			const l = sroom.level;
			const prefer = S.doorSide && S.doorSide[l];
			const order = sides(rect).sort((p, q) => (q[0] === prefer ? 1 : 0) - (p[0] === prefer ? 1 : 0));
			for (const [side, sd] of order) {
				const list = sideSeg(sroom, side, segs(sroom, room(sroom.parent)));
				const longest = list.reduce((m, e) => Math.max(m, e.b - e.a), 0);
				if (longest < 10) continue;
				const clear = doorClearOf({ x: sd.x, z: sd.z, axis: sd.axis, width: 8 }, l);
				if (subtract([inflate(clear, 0.5)], rect).every((piece) => insideOneRoom(l, piece, S.parents[l])) && freeOf(l, clear)) { doorsHere[l] = { side, ...sd }; break; }
			}
			if (!doorsHere[l]) { ok = false; break; }
		}
		if (!ok) { for (const r of added) { rooms.splice(rooms.indexOf(r), 1); roomMap.delete(r.id); } flushPieces(); continue; }
		const out = { id: S.id, name: S.name, locked: !!S.locked, tier: S.tier, rooms: [] };
		for (const r of added) {
			out.rooms.push({ level: r.level, room: r.id, parent: r.parent, stop: r.stop });
			reserve(r.level, rect, "shaft " + S.id);
			if (r.stop) {
				const dr = doorsHere[r.level];
				const cost = (S.doorCost && S.doorCost[r.level]) || COST[S.tier] || 3;
				const gate = (S.arrivalTier && S.arrivalTier[r.level]) || (S.id === "E5" ? 3 : 1);
				wantDoor({ a: r.id, b: r.parent, width: 8, gate, cost, elevator: S.id, edge: dr.side, at: dr.axis === "x" ? dr.x : dr.z });
			}
		}
		shaftOut.push(out);
		return;
	}
	bad(`shaft ${S.id}: no spot found`);
}

// ---------------------------------------------------------------- stairs
// A stair is { from, to, x, z, dir, turn, width }: the same geometry Build.luau uses.
const DIRS = { "+z": [0, 1], "-z": [0, -1], "+x": [1, 0], "-x": [-1, 0] };
function stairGeom(s) {
	const w = s.width, rise = LEVELS[s.to] - LEVELS[s.from];
	const run = rise * 2, legRise = rise / 2, legRun = rise, lane = w / 2 + LANE_GAP / 2;
	const cutFrom = rise - SLAB - HEADROOM;
	const [dx, dz] = DIRS[s.dir];
	const px = dz, pz = -dx;
	const rect = (a1, a2, c1, c2) => {
		const ax1 = s.x + dx * a1 + px * c1, az1 = s.z + dz * a1 + pz * c1, ax2 = s.x + dx * a2 + px * c2, az2 = s.z + dz * a2 + pz * c2;
		return { x1: Math.min(ax1, ax2), z1: Math.min(az1, az2), x2: Math.max(ax1, ax2), z2: Math.max(az1, az2) };
	};
	const width = s.turn ? w * 2 + LANE_GAP : w, length = s.turn ? legRun + LANDING : run;
	let h1, h2, c1, c2;
	if (s.turn) { h1 = 0; h2 = legRun * (2 - cutFrom / legRise); c1 = lane - w / 2; c2 = lane + w / 2; } else { h1 = (run * cutFrom) / rise; h2 = run; c1 = -w / 2; c2 = w / 2; }
	const entryAcross = s.turn ? -lane : 0;
	return {
		body: rect(0, length, -width / 2, width / 2), foot: rect(-STAIR_CLEAR, 0, entryAcross - w / 2, entryAcross + w / 2),
		hole: rect(h1, h2, c1, c2), head: s.turn ? rect(-STAIR_CLEAR, 0, c1, c2) : rect(run, run + STAIR_CLEAR, c1, c2),
	};
}
const stairsOut = [];
// Specs: from/to rooms the stair may use, the plan's intended spot (hint), and the kind of flight.
const STAIRS = [
	// public
	{ id: "grandstair", kind: "Grand stair", from: "G", to: "M", fromRooms: ["g_lobby"], toRooms: ["m_stairhall"], width: 24, turn: false, hint: [0, 115], prefer: "-z", tier: 0 },
	{ id: "escalator_w", kind: "Escalator ramp", from: "G", to: "M", fromRooms: ["g_atrium"], toRooms: ["m_balcony"], width: 12, turn: false, hint: [-46, 20], tier: 0 },
	{ id: "escalator_e", kind: "Escalator ramp", from: "G", to: "M", fromRooms: ["g_atrium"], toRooms: ["m_balcony"], width: 12, turn: false, hint: [46, -10], tier: 0 },
	{ id: "corner_nw", kind: "Switchback stair", from: "G", to: "M", fromRooms: ["g_gallery"], toRooms: ["m_gallery"], width: 6, turn: true, hint: [-115, -65], tier: 0 },
	{ id: "corner_ne", kind: "Switchback stair", from: "G", to: "M", fromRooms: ["g_ballroom"], toRooms: ["m_ball_gal"], width: 6, turn: true, hint: [110, -65], tier: 0 },
	{ id: "corner_sw", kind: "Switchback stair", from: "G", to: "M", fromRooms: ["g_library"], toRooms: ["m_wine"], width: 6, turn: true, hint: [-110, 120], tier: 0 },
	{ id: "corner_se", kind: "Switchback stair", from: "G", to: "M", fromRooms: ["g_lounge"], toRooms: ["m_cigar"], width: 6, turn: true, hint: [110, 120], tier: 0 },
	{ id: "terrace_stair_w", kind: "Switchback stair", from: "M", to: "T", fromRooms: ["m_gallery"], toRooms: ["t_ter_w"], width: 6, turn: true, hint: [-108, -30], tier: 0 },
	{ id: "terrace_stair_e", kind: "Switchback stair", from: "M", to: "T", fromRooms: ["m_ball_gal"], toRooms: ["t_ter_e"], width: 6, turn: true, hint: [108, -50], tier: 0 },
	{ id: "roof_stair", kind: "Roof stair", from: "T", to: "R", fromRooms: ["t_ter_w"], toRooms: ["r_deck_w"], width: 6, turn: true, hint: [-108, 70], tier: 0 },
	{ id: "wing_grand_stair", kind: "Grand stair", from: "G", to: "M", fromRooms: ["wg_casino"], toRooms: ["wm_lobby"], width: 24, turn: false, hint: [188, 65], prefer: "-z", tier: 0 },
	{ id: "wing_stair_m_t", kind: "Switchback stair", from: "M", to: "T", fromRooms: ["wm_bar"], toRooms: ["wt_terrace"], width: 6, turn: true, hint: [175, 100], tier: 0 },
	{ id: "wing_stair_t_r", kind: "Roof stair", from: "T", to: "R", fromRooms: ["wt_arcade"], toRooms: ["wr_garden"], width: 6, turn: true, hint: [243, 30], tier: 0 },
	{ id: "wing_deck_stair", kind: "Stair", from: "R", to: "S", fromRooms: ["wr_garden"], toRooms: ["wd_skydeck"], width: 6, turn: true, hint: [243, -30], tier: 0 },
	{ id: "wing_deck_stair_2", kind: "Stair", from: "R", to: "S", fromRooms: ["wr_garden"], toRooms: ["wd_skydeck"], width: 6, turn: true, hint: [268, -50], tier: 0 },
	// staff (6 wide legs)
	{ id: "staff_b_g", kind: "Staff stair", from: "B", to: "G", fromRooms: ["b_stores_e1"], toRooms: ["g_service_n", "g_pantry"], width: 6, turn: true, hint: [107, -92], tier: 1 },
	{ id: "staff_g_m", kind: "Staff stair", from: "G", to: "M", fromRooms: ["g_kitchen", "g_service_n"], toRooms: ["m_offices"], width: 6, turn: true, hint: [-50, -110], tier: 1 },
	{ id: "staff_b_g_s", kind: "Staff stair", from: "B", to: "G", fromRooms: ["b_stores_w2"], toRooms: ["g_coat"], width: 6, turn: true, hint: [-92, 57], tier: 1 },
	{ id: "staff_g_m_s", kind: "Staff stair", from: "G", to: "M", fromRooms: ["g_pantry"], toRooms: ["m_catering"], width: 6, turn: true, hint: [60, -130], tier: 1 },
	{ id: "wing_staff_b_g", kind: "Staff stair", from: "B", to: "G", fromRooms: ["wb_linen"], toRooms: ["wg_cage"], width: 6, turn: true, hint: [172, -30], tier: 1 },
	{ id: "wing_staff_g_m", kind: "Staff stair", from: "G", to: "M", fromRooms: ["wg_cage"], toRooms: ["wm_housekeeping"], width: 6, turn: true, hint: [170, -50], tier: 1 },
	{ id: "plant_stair", kind: "Staff stair", from: "T", to: "R", fromRooms: ["t_east"], toRooms: ["r_plant"], width: 6, turn: true, hint: [72, -100], tier: 1 },
	{ id: "wing_plant_stair", kind: "Staff stair", from: "T", to: "R", fromRooms: ["wt_arcade"], toRooms: ["wr_plant"], width: 6, turn: true, hint: [226, -60], tier: 1 },
	// security (guard stairs)
	{ id: "guard_b_g", kind: "Guard stair", from: "B", to: "G", fromRooms: ["b_gate"], toRooms: ["g_service_n", "g_kitchen"], width: 6, turn: true, hint: [0, -110], tier: 2 },
	{ id: "guard_m_t", kind: "Guard stair", from: "M", to: "T", fromRooms: ["m_hub"], toRooms: ["t_guard_nw"], width: 6, turn: true, hint: [-32, -110], tier: 2 },
	{ id: "wing_guard_stair", kind: "Guard stair", from: "B", to: "G", fromRooms: ["wb_security"], toRooms: ["wg_cage"], width: 6, turn: true, hint: [185, -70], tier: 2 },
	{ id: "guard_t_r", kind: "Guard stair", from: "T", to: "R", fromRooms: ["t_east"], toRooms: ["r_deck"], width: 6, turn: true, hint: [75, 10], tier: 2 },
	// the Executive stair to the Sanctum: it arrives in the stair-head room of the foyer
	{ id: "sanctum_stair", kind: "Executive stair", from: "R", to: "S", fromRooms: ["r_summit"], toRooms: ["s_stairhead"], width: 6, turn: true, hint: [-20, -60], tier: 4, marginOverride: 0.25 },
];
function placeStair(S) {
	const best = [];
	const bounds = rooms.filter((r) => S.fromRooms.includes(r.id));
	const xs = bounds.map((b) => [b.rect.x1, b.rect.x2]), zs = bounds.map((b) => [b.rect.z1, b.rect.z2]);
	const x1 = Math.min(...xs.map((v) => v[0])) - 6, x2 = Math.max(...xs.map((v) => v[1])) + 6, z1 = Math.min(...zs.map((v) => v[0])) - 6, z2 = Math.max(...zs.map((v) => v[1])) + 6;
	const margin = S.marginOverride === undefined ? 1.5 : S.marginOverride;
	const wide = S.fromRooms.map(room).some((r) => r.w && r.w <= 16); // a corridor loses a stair's width: allowed only where the plan said so
	const stage = [0, 0, 0, 0, 0, 0];
	for (let x = x1; x <= x2; x += 1) for (let z = z1; z <= z2; z += 1) for (const dir of ["+z", "-z", "+x", "-x"]) {
		const s = { ...S, x, z, dir };
		const g = stairGeom(s);
		stage[0]++;
		if (!insideOneRoom(S.from, inflate(g.body, margin), S.fromRooms)) continue;
		stage[1]++;
		if (!insideOneRoom(S.from, inflate(g.foot, margin), S.fromRooms)) continue;
		stage[2]++;
		if (!insideOneRoom(S.to, inflate(g.hole, margin), S.toRooms)) continue;
		stage[3]++;
		if (!insideOneRoom(S.to, inflate(g.head, margin), S.toRooms)) continue;
		stage[4]++;
		if (!freeOf(S.from, g.body) || !freeOf(S.from, g.foot) || !freeOf(S.to, g.hole) || !freeOf(S.to, g.head)) continue;
		stage[5]++;
		const [bx, bz] = centre(g.body);
		best.push({ x, z, dir, g, score: Math.hypot(bx - S.hint[0], bz - S.hint[1]) + (S.prefer && S.prefer !== dir ? 8 : 0) });
	}
	if (best.length === 0) { bad(`stair ${S.id}: no valid spot in ${S.fromRooms.join("/")} up to ${S.toRooms.join("/")} (candidates: tried ${stage[0]}, body ${stage[1]}, foot ${stage[2]}, hole ${stage[3]}, head ${stage[4]}, free ${stage[5]})`); return; }
	best.sort((p, q) => p.score - q.score);
	const b = best[0];
	reserve(S.from, b.g.body, S.id); reserve(S.from, b.g.foot, S.id); reserve(S.to, b.g.hole, S.id); reserve(S.to, b.g.head, S.id);
	// props and nodes also keep off the floor round it; the ends are linked by Build as a stair pair
	const [fx, fz] = centre(b.g.foot), [hx, hz] = centre(b.g.head);
	stairsOut.push({ ...S, x: b.x, z: b.z, dir: b.dir, geom: b.g, fromRoom: (roomAt(S.from, fx, fz) || {}).id, toRoom: (roomAt(S.to, hx, hz) || {}).id });
}

// ---------------------------------------------------------------- run the placement
resolveDoors();
registerPosts();
for (const S of SHAFTS) { placeShaft(S); flushPieces(); }
resolveDoors();
for (const d of doors) reserveDoorClear(d);
function reserveDoorClear(d) { /* door clearances are read from `doors` directly by freeOf */ }
for (const S of STAIRS) { flushPieces(); placeStair(S); }
flushPieces();

// ---------------------------------------------------------------- ladders, vents, secret exits, terminals, printers
const ladders = [
	{ id: "summit_ladder_w", level: "R", to: "S", x: -47, z: -92, room: "s_ter_w", edgeLine: -45, note: "up the crown's west wall from the roof deck to the west terrace: Cover-breaking, the only way to the back Package door" },
	{ id: "summit_ladder_e", level: "R", to: "S", x: 47, z: -92, room: "s_ter_e", edgeLine: 45, note: "up the crown's east wall from the roof deck to the east terrace (the zipline landing): Cover-breaking" },
];
for (const l of ladders) { reserve("R", R([l.x - 3, l.z - 3, l.x + 3, l.z + 3]), l.id); }

// Vent: duct through the shared wall between `from` and the vault room; shafts 5x5 each side, 10 in from the wall.
function wallBetween(aId, bId, avoidAt) {
	const list = segs(room(aId), room(bId)).sort((p, q) => (q.b - q.a) - (p.b - p.a));
	return list[0] || null;
}
function crossings(seg, width, level, clearSides) {
	// candidate positions along a wall segment away from doors and other crossings, best (most central) first
	const out = [];
	for (let t = seg.a + width / 2 + 2; t <= seg.b - width / 2 - 2; t += 1) {
		let ok = true;
		for (const d of doors) if (d.level === level && ((d.axis === "x" && seg.axis === "x" && eq(d.z, seg.line)) || (d.axis === "z" && seg.axis === "z" && eq(d.x, seg.line)))) {
			const at = d.axis === "x" ? d.x : d.z;
			if (Math.abs(at - t) < d.width / 2 + width / 2 + 2) ok = false;
		}
		for (const u of usedCrossings) if (u.level === level && u.axis === seg.axis && eq(u.line, seg.line) && Math.abs(u.t - t) < u.width / 2 + width / 2 + 3) ok = false;
		if (ok) out.push(t);
	}
	return out;
}
const usedCrossings = [];
const ventsOut = [], secretOut = [];
for (const v of D.vents) {
	const seg = wallBetween(v.from, v.to);
	if (!seg) { bad(`vent ${v.id}: ${v.from} and ${v.to} share no wall`); continue; }
	const level = room(v.from).level;
	const from = room(v.from), to = room(v.to);
	let done = false;
	const ts = crossings(seg, 6, level);
	ts.sort((p, q) => Math.abs(p - (seg.a + 8)) - Math.abs(q - (seg.a + 8)));
	for (const t of ts) {
		// which side is `from`: toward the centre of `from`
		const [fcx, fcz] = centre(from.rect);
		const sign = seg.axis === "x" ? (fcz > seg.line ? 1 : -1) : (fcx > seg.line ? 1 : -1);
		for (const d1 of [9, 12, 15]) for (const d2 of [9, 12]) {
			const p1 = seg.axis === "x" ? [t, seg.line + sign * d1] : [seg.line + sign * d1, t];
			const p2 = seg.axis === "x" ? [t, seg.line - sign * d2] : [seg.line - sign * d2, t];
			const box = (p) => ({ x1: p[0] - 3.5, z1: p[1] - 3.5, x2: p[0] + 3.5, z2: p[1] + 3.5 });
			if (insideOneRoom(level, box(p1), [v.from]) && insideOneRoom(level, box(p2), [v.to]) && freeOf(level, box(p1)) && freeOf(level, box(p2))) {
				ventsOut.push({ id: v.id, level, name: `Vent to ${to.name}`, points: [p1, p2], from: v.from, to: v.to });
				reserve(level, box(p1), v.id); reserve(level, box(p2), v.id);
				usedCrossings.push({ level, axis: seg.axis, line: seg.line, t, width: 6 });
				done = true; break;
			}
		}
		if (done) break;
	}
	if (!done) bad(`vent ${v.id}: no clear spot on the wall between ${v.from} and ${v.to}`);
}
for (const s of D.secretExits) {
	const seg = wallBetween(s.room, s.to);
	if (!seg) { bad(`secret exit ${s.id}: ${s.room} and ${s.to} share no wall`); continue; }
	const level = room(s.room).level;
	const ts = crossings(seg, 6, level);
	ts.sort((p, q) => Math.abs(p - (seg.b - 10)) - Math.abs(q - (seg.b - 10)));
	// the lever sits inside the room, 4 studs along the wall from the panel
	const t = ts.find((t) => {
		const [cx, cz] = centre(room(s.room).rect);
		const sign = seg.axis === "x" ? (cz > seg.line ? 1 : -1) : (cx > seg.line ? 1 : -1);
		const lever = seg.axis === "x" ? { x1: t + 3, z1: seg.line + sign * 2 - 1.5, x2: t + 5, z2: seg.line + sign * 4 } : { x1: seg.line + sign * 2 - 1.5, z1: t + 3, x2: seg.line + sign * 4, z2: t + 5 };
		return freeOf(level, inflate(lever, 1));
	});
	if (t === undefined) { bad(`secret exit ${s.id}: no clear spot on the wall between ${s.room} and ${s.to}`); continue; }
	usedCrossings.push({ level, axis: seg.axis, line: seg.line, t, width: 6 });
	secretOut.push({ id: s.id, a: s.room, b: s.to, level, axis: seg.axis, line: seg.line, at: t });
}

// ---------------------------------------------------------------- markers
const vaults = D.vaults.map((v) => ({ id: v.id, level: lv(v.level), x: v.x, z: v.z, room: v.room }));
const printers = D.printers.map((p) => ({ id: p.id, level: lv(p.level), x: p.x, z: p.z, room: p.room }));
const sanctum = { level: "S", x: D.sanctum.x, z: D.sanctum.z, room: D.sanctum.room };
const extraction = D.extraction.map((e) => ({ id: e.id, level: lv(e.level), x: e.x, z: e.z }));
const insertion = D.insertion.map((m) => ({ id: m.id, level: lv(m.level), x: m.x, z: m.z }));
const ziplines = D.ziplines.map((z) => ({ id: z.id, top: { level: lv(z.from.level), x: z.from.x, z: z.from.z, mast: 22 }, bottom: { level: lv(z.to.level), x: z.to.x, z: z.to.z, mast: 7 } }));
for (const m of [...vaults, ...printers, sanctum, ...extraction, ...insertion]) if (!roomAt(m.level, m.x, m.z)) bad(`marker ${m.id} (${m.level} ${m.x},${m.z}) is in no room`);
for (const m of [...printers, ...vaults]) for (const t of taken[m.level]) if (/stair|escalator|corner|guard|staff|roof|grand|wing|terrace|sanctum_stair|shaft/.test(t.what) && overlaps(inflate(R([m.x - 1, m.z - 1, m.x + 1, m.z + 1]), 2), t.rect)) bad(`marker ${m.id} sits on ${t.what}`);

// ---------------------------------------------------------------- checks on the real result
const stairsAll = stairsOut;
function buildGraph(opts) {
	const g = new Map();
	const link = (a, b, w, tier, oneWay) => {
		if (!g.has(a)) g.set(a, []); if (!g.has(b)) g.set(b, []);
		g.get(a).push({ to: b, w, tier }); if (!oneWay) g.get(b).push({ to: a, w, tier });
	};
	const dist = (a, b) => { const [ax, az] = centre(room(a).rect), [bx, bz] = centre(room(b).rect); return Math.hypot(ax - bx, az - bz) + Math.abs(LEVELS[room(a).level] - LEVELS[room(b).level]); };
	for (const d of doors) {
		if (d.package === "back" && !opts.back) continue;
		link(d.a, d.b, dist(d.a, d.b), d.gate && d.gate > Math.max(room(d.a).tier, room(d.b).tier) ? d.gate : 0);
	}
	for (const s of stairsAll) if (s.fromRoom && s.toRoom) link(s.fromRoom, s.toRoom, dist(s.fromRoom, s.toRoom) + 30, s.tier);
	for (const sh of shaftOut) {
		if (sh.locked && !opts.locked) continue;
		const stops = sh.rooms.filter((r) => r.stop);
		for (let i = 0; i < stops.length; i++) for (let j = i + 1; j < stops.length; j++) link(stops[i].parent, stops[j].parent, dist(stops[i].parent, stops[j].parent) + 20, 1);
	}
	for (const l of ladders) { const up = room(l.room); const below = roomAt("R", l.x, l.z); if (below) link(below.id, up.id, 40, 0); }
	if (opts.players) {
		for (const v of ventsOut) link(v.from, v.to, dist(v.from, v.to) + 20, 0);
		for (const s of secretOut) link(s.a, s.b, dist(s.a, s.b) + 10, 0);
		for (const z of ziplines) { const a = roomAt(z.top.level, z.top.x, z.top.z), b = roomAt(z.bottom.level, z.bottom.x, z.bottom.z); if (a && b) link(a.id, b.id, 100, 0, true); else bad(`zipline ${z.id}: an end is in no room`); }
	}
	return g;
}
const walk = buildGraph({ locked: true });
const everything = buildGraph({ locked: true, players: true, back: true });
const reach = [];
for (let cap = 0; cap <= 4; cap++) {
	const ok = (id) => room(id).tier <= cap;
	const seen = new Set(["g_lobby"]), queue = ["g_lobby"];
	while (queue.length) {
		const id = queue.shift();
		for (const e of walk.get(id) || []) if (!seen.has(e.to) && ok(e.to) && (e.tier || 0) <= cap && !(room(e.to).vault && room(e.to).tier === 3 && cap < 3)) { seen.add(e.to); queue.push(e.to); }
	}
	const missing = rooms.filter((r) => ok(r.id) && !r.nested && !r.shaft && !seen.has(r.id));
	reach.push({ cap, reached: seen.size, missing: missing.map((m) => m.id) });
	if ([0, 1, 2, 3, 4].includes(cap) && missing.length) bad(`clearance ${cap} cannot reach: ${missing.map((m) => m.id).join(", ")}`);
}
const entrances = new Map();
const addEntrance = (id, other) => { if (!entrances.has(id)) entrances.set(id, new Set()); entrances.get(id).add(other); };
for (const [a, list] of walk) for (const e of list) addEntrance(a, e.to);
const few = rooms.filter((r) => r.tier >= 1 && !r.nested && !r.vault && !r.shaft && !(r.kind === "outdoor" && r.tier >= 3) && (entrances.get(r.id) || new Set()).size < 2);
for (const r of few) bad(`room ${r.id} (tier ${r.tier}) has ${(entrances.get(r.id) || new Set()).size} entrance(s)`);
function disjointPaths(g, source, sink) {
	const cap = new Map(), key = (a, b) => `${a}>${b}`;
	for (const [a, list] of g) for (const e of list) cap.set(key(a, e.to), (cap.get(key(a, e.to)) || 0) + 1);
	let flow = 0;
	for (;;) {
		const prev = new Map([[source, null]]), queue = [source];
		while (queue.length && !prev.has(sink)) { const u = queue.shift(); for (const e of g.get(u) || []) if (!prev.has(e.to) && (cap.get(key(u, e.to)) || 0) > 0) { prev.set(e.to, u); queue.push(e.to); } }
		if (!prev.has(sink)) return flow;
		for (let v = sink; prev.get(v) !== null; v = prev.get(v)) { const u = prev.get(v); cap.set(key(u, v), cap.get(key(u, v)) - 1); cap.set(key(v, u), (cap.get(key(v, u)) || 0) + 1); }
		flow++;
	}
}
function withSource(g) {
	const c = new Map(); for (const [k, v] of g) c.set(k, v.slice());
	c.set("SRC", []);
	for (const m of insertion) { const r = roomAt(m.level, m.x, m.z); if (r) { c.get("SRC").push({ to: r.id, w: 1 }); if (!c.has(r.id)) c.set(r.id, []); c.get(r.id).push({ to: "SRC", w: 1 }); } }
	return c;
}
const routeRows = [];
const objectives = [...vaults.map((v) => ({ name: `Vault ${v.id}`, room: v.room, need: 3, ante: rooms.find((r) => r.vault === v.id && r.tier === 2).id })), { name: "The Sanctum foyer", room: "s_foyer", need: 3 }, { name: "The Package room", room: "s_sanctum", need: 2, ante: "s_foyer" }];
for (const o of objectives) {
	const walking = disjointPaths(withSource(walk), "SRC", o.ante || o.room);
	const total = disjointPaths(withSource(everything), "SRC", o.room);
	routeRows.push({ name: o.name, walking, total });
	if (total < o.need) bad(`${o.name}: only ${total} independent route(s) in (need ${o.need})`);
}

// ---------------------------------------------------------------- Luau output
const q = (s) => JSON.stringify(s);
const num = (n) => (Number.isInteger(n) ? String(n) : String(+n.toFixed(3)));
const rectLua = (r) => `{ ${num(r.x1)}, ${num(r.z1)}, ${num(r.x2)}, ${num(r.z2)} }`;
function opts(o) {
	const parts = [];
	for (const [k, v] of Object.entries(o)) {
		if (v === undefined || v === null || v === false) continue;
		if (typeof v === "boolean") parts.push(`${k} = true`);
		else if (typeof v === "number") parts.push(`${k} = ${num(v)}`);
		else if (typeof v === "string") parts.push(`${k} = ${q(v)}`);
		else if (Array.isArray(v)) parts.push(`${k} = { ${v.map((e) => (typeof e === "string" ? q(e) : rectLua(e))).join(", ")} }`);
	}
	return parts.length ? `{ ${parts.join(", ")} }` : "";
}
const lines = [];
const push = (s) => lines.push(s);
push("--!strict");
push("-- The Gala re-layout as data (docs/MAP_PLAN_RELAYOUT.md). GENERATED by tools/relayout-layout.cjs from");
push("-- tools/relayout-plan-data.cjs: change the plan or the generator and run `node tools/relayout-layout.cjs`, not this file.");
push("--");
push("-- Levels: B -24, G 0, M 24, T 48, R 72, S 96 (the Sanctum crown over the summit lobby, and the wing's sky deck).");
push("-- Rects are { x1, z1, x2, z2 } in studs; north is -z. Build.luau turns this into geometry, zones, doors and NPC nodes.");
push("");
push('local Layout = require(script.Parent.Layout)');
push("");
push("local rooms: { Layout.Room } = {}");
push("local function room(id: string, level: string, name: string, tier: number, kind: string, rect: Layout.Rect, extra: { [string]: any }?)");
push("\tlocal r: any = { id = id, level = level, name = name, tier = tier, kind = kind, rect = rect }");
push("\tfor key, value in extra or {} do");
push("\t\tr[key] = value");
push("\tend");
push("\ttable.insert(rooms, r :: Layout.Room)");
push("end");
push('local OUT, IN = "outdoor", "indoor"');
push("");
for (const lvl of LEVEL_ORDER) {
	push(`-- ${lvl} (${LEVELS[lvl]}) ${"-".repeat(100)}`);
	for (const r of roomsOn(lvl)) {
		const o = {
			parent: r.parent || undefined, holes: r.holes.length ? r.holes.map(rectArr).map((a) => ({ x1: a[0], z1: a[1], x2: a[2], z2: a[3] })) : undefined,
			density: r.density, props: r.props.length ? r.props : undefined, glass: r.glass, height: r.height, noNodes: r.noNodes, theme: r.theme, style: r.style,
			shaft: r.shaft, stop: r.shaft ? r.stop : undefined, posts: r.posts, vault: r.vault, hub: r.hub,
		};
		const optStr = opts(o);
		push(`room(${q(r.id)}, ${q(r.level)}, ${q(r.name)}, ${r.tier}, ${r.kind === "indoor" ? "IN" : "OUT"}, ${rectLua(r.rect)}${optStr ? ", " + optStr : ""})`);
	}
	push("");
}
push("local voids: { Layout.Void } = {");
for (const v of VOIDS) push(`\t{ level = ${q(v.level)}, rect = ${rectLua(v.rect)}, railed = true },`);
push("}");
push("");
push("local doors: { Layout.Door } = {}");
push("local function door(a: string, b: string, at: number, width: number, extra: { [string]: any }?)");
push("\tlocal d: any = { a = a, b = b, at = at, width = width }");
push("\tfor key, value in extra or {} do");
push("\t\td[key] = value");
push("\tend");
push("\ttable.insert(doors, d :: Layout.Door)");
push("end");
for (const d of doors) {
	const o = { line: d.seg.line, gate: d.gate, arch: d.arch, laser: d.laser, core: d.core, role: d.role, package: d.package, keycardOnly: d.keycardOnly, elevator: d.elevator };
	const doorOpts = opts(o);
	push(`door(${q(d.a)}, ${q(d.b)}, ${num(d.at)}, ${num(d.width)}${doorOpts ? ", " + doorOpts : ""})`);
}
push("");
push("local ramps: { Layout.Ramp } = {");
for (const s of stairsOut) push(`\t{ id = ${q(s.id)}, kind = ${q(s.kind)}, from = ${q(s.from)}, to = ${q(s.to)}, x = ${num(s.x)}, z = ${num(s.z)}, dir = ${q(s.dir)}${s.turn ? ", turn = true" : ""}${s.width !== 6 ? `, width = ${s.width}` : ""}, tier = ${s.tier} },`);
push("}");
push("");
push("local vents: { Layout.Vent } = {");
for (const v of ventsOut) push(`\t{ id = ${q(v.id)}, level = ${q(v.level)}, name = ${q(v.name)}, points = { { ${num(v.points[0][0])}, ${num(v.points[0][1])} }, { ${num(v.points[1][0])}, ${num(v.points[1][1])} } } },`);
push("}");
push("");
push("local secretExits: { Layout.SecretExit } = {");
for (const s of secretOut) push(`\t{ id = ${q(s.id)}, a = ${q(s.a)}, b = ${q(s.b)}, level = ${q(s.level)}, line = ${num(s.line)}, at = ${num(s.at)}, width = 6 },`);
push("}");
push("");
push("local shafts: { Layout.Shaft } = {");
for (const s of shaftOut) push(`\t{ id = ${q(s.id)}, name = ${q(s.name)}, tier = ${s.tier}${s.locked ? ", locked = true" : ""} },`);
push("}");
push("");
push("local ladders: { Layout.Ladder } = {");
for (const l of ladders) push(`\t{ id = ${q(l.id)}, level = ${q(l.level)}, to = ${q(l.to)}, x = ${l.x}, z = ${l.z}, room = ${q(l.room)}, edge = ${l.edgeLine} },`);
push("}");
push("");
const windows = [
	["m_hub", "m_balcony", -30, 12, "oneWay", "m_hub"], ["m_hub", "m_balcony", 20, 10, "oneWay", "m_hub"], ["b_camera", "b_muster", -24, 8, "oneWay", "b_camera"],
	["g_kitchen", "g_service_n", -15, 12, "hatch"], ["g_pantry", "g_service_n", 30, 8, "hatch"], ["g_dining", "g_gallery", -85, 14, "glass"],
	["wg_cage", "wg_casino", 200, 8, "glass"], ["wg_highroller", "wg_casino", 250, 8, "oneWay", "wg_highroller"], ["wg_highroller", "wg_casino", 272, 8, "oneWay", "wg_highroller"],
];
push("local windows: { Layout.Window } = {");
for (const w of windows) push(`\t{ a = ${q(w[0])}, b = ${q(w[1])}, at = ${w[2]}, width = ${w[3]}, kind = ${q(w[4])}${w[5] ? `, inside = ${q(w[5])}` : ""} },`);
push("}");
push("");
push("local features: { Layout.Feature } = {");
push('\t{ kind = "fountain", level = "G", x = 0, z = 6, radius = 18, userId = 80171669, text = "IN HONOUR OF THE FOUNDER" },');
push(`\t{ kind = "skylight", level = "R", rect = ${rectLua(ATRIUM)} },`);
push('\t{ kind = "truss", level = "M", rect = { 140, 26, 160, 38 } },');
push('\t{ kind = "truss", level = "B", rect = { 140, 20, 160, 32 } },');
push("}");
push("");
push("local placements: { Layout.Placement } = {}");
push("local function place(kind: string, list: { string })");
push("\tfor _, roomId in list do");
push("\t\ttable.insert(placements, { kind = kind, room = roomId })");
push("\tend");
push("end");
push("local function placeIntel(station: number, list: { string })");
push("\tfor _, roomId in list do");
push("\t\ttable.insert(placements, { kind = \"intel\", room = roomId, station = station })");
push("\tend");
push("end");
const PLACE = {
	intel0: ["g_lobby", "g_atrium", "g_ballroom", "g_bar", "g_lounge", "g_gallery", "m_gallery", "wg_casino", "wm_lobby", "r_deck", "wr_garden", "t_ter_s"],
	intel1: ["g_kitchen", "g_pantry", "g_coat", "m_offices", "m_catering", "wb_laundry", "wm_housekeeping", "wg_cage", "b_stores_e1", "g_concierge"],
	intel2: ["b_camera", "b_muster", "m_hub", "t_west", "t_east", "wb_security", "wr_plant", "r_plant"],
	intel3: ["t_gallery", "b_armory", "wg_highroller", "wt_exec", "t_great", "m_records"],
	health: ["g_restroom", "g_staffwc", "m_restroom", "t_washroom", "wm_restroom", "wg_restroom"],
	ammo: ["g_service_n", "b_barracks", "m_hub", "b_gate", "t_west", "wg_cage", "wm_housekeeping", "wt_arcade"],
	food: ["g_ballroom", "g_ballroom", "g_ballroom", "g_bar", "g_bar", "g_lounge", "g_dining", "g_dining", "wg_casino", "wg_casino", "wm_lobby", "wm_bar", "wr_garden", "wr_garden", "r_deck", "r_deck", "m_ball_gal", "m_cigar", "g_kitchen", "g_kitchen"],
	safeStaff: ["g_coat", "m_catering", "wb_laundry", "wr_plant"], safeSec: ["b_barracks", "m_hub", "t_east", "wb_security"], safeExec: ["t_office", "t_panic", "wg_highroller", "wt_exec"],
	cache: ["g_gallery", "m_balcony", "t_ter_n", "wg_cage", "b_stores_w1", "wr_garden"],
	camera: ["g_service_n", "g_kitchen", "m_hub", "m_offices", "b_gate", "b_muster", "t_west", "t_east", "wb_service", "wg_cage", "wm_housekeeping", "b_spine"],
};
for (const [k, list] of Object.entries(PLACE)) {
	for (const id of list) if (!roomMap.has(id)) bad(`placement room ${id} (${k}) does not exist`);
}
push(`placeIntel(0, { ${PLACE.intel0.map(q).join(", ")} })`);
push(`placeIntel(1, { ${PLACE.intel1.map(q).join(", ")} })`);
push(`placeIntel(2, { ${PLACE.intel2.map(q).join(", ")} })`);
push(`placeIntel(3, { ${PLACE.intel3.map(q).join(", ")} })`);
for (const [k, kind] of [["health", "health"], ["ammo", "ammo"], ["food", "food"], ["safeStaff", "safe"], ["safeSec", "safe"], ["safeExec", "safe"], ["cache", "cache"], ["camera", "camera"]]) push(`place(${q(kind)}, { ${PLACE[k].map(q).join(", ")} })`);
push("");
push("local ziplines: { Layout.Zipline } = {");
for (const z of ziplines) push(`\t{ id = ${q(z.id)}, top = { level = ${q(z.top.level)}, x = ${z.top.x}, z = ${z.top.z}, mast = ${z.top.mast} }, bottom = { level = ${q(z.bottom.level)}, x = ${z.bottom.x}, z = ${z.bottom.z}, mast = ${z.bottom.mast} } },`);
push("}");
push("");
push("-- The window-washer gondola crosses the drop from the Gala's upper east terrace to the wing's suite terrace.");
push('local gondola: Layout.Gondola = { level = "T", z = 20, fromX = 125, toX = 160, width = 8, length = 8 }');
push("");
push("local nodes: { Layout.NodeSpec } = {");
push('\t{ level = "B", x = 146, z = 26, activity = "Walk" },');
push('\t{ level = "B", x = 154, z = 26, activity = "Walk" },');
for (const [l, x, z] of [["M", -132, -162], ["M", 132, -162], ["M", -132, 142], ["M", 132, 142], ["T", -108, -138], ["T", 108, -138], ["T", -108, 118], ["T", 108, 118]]) push(`\t{ level = ${q(l)}, x = ${x}, z = ${z}, activity = "Walk" },`);
push("}");
push("");
push("local extraction: { Layout.Marker } = {");
for (const e of extraction) push(`\t{ id = ${q(e.id)}, level = ${q(e.level)}, x = ${e.x}, z = ${e.z} },`);
push("}");
push("");
push("local insertion: { Layout.Marker } = {");
for (const m of insertion) push(`\t{ id = ${q("Insertion" + m.id)}, level = ${q(m.level)}, x = ${m.x}, z = ${m.z} },`);
push("}");
push("");
push("-- The five vault terminal spots. A match makes three of them active; the others stay empty.");
push("local vaults: { Layout.Marker } = {");
for (const v of vaults) push(`\t{ id = ${q("Vault" + v.id)}, level = ${q(v.level)}, x = ${v.x}, z = ${v.z}, room = ${q(v.room)} },`);
push("}");
push("");
push("-- The five candidate keycard printer spots near the summit. A match makes one of them active; none is marked.");
push("local printers: { Layout.Marker } = {");
for (const p of printers) push(`\t{ id = ${q("Printer" + p.id)}, level = ${q(p.level)}, x = ${p.x}, z = ${p.z}, room = ${q(p.room)} },`);
push("}");
push("");
push("local signposts: { string } = {");
const SIGNPOSTS = ["g_atrium", "g_lobby", "g_ring_n", "g_ring_s", "g_ring_w", "g_ring_e", "g_service_n", "m_balcony", "m_ter_n", "m_ter_s", "m_ter_w", "m_ter_e", "t_ter_n", "t_ter_s", "t_ter_w", "t_ter_e", "t_west", "t_east", "b_ring_n", "b_ring_s", "b_spine", "b_muster", "wb_service", "wg_casino", "wm_lobby", "wt_arcade", "r_deck", "wr_garden", "s_foyer"];
for (const id of SIGNPOSTS) if (!roomMap.has(id)) bad(`signpost room ${id} does not exist`);
push(`\t${SIGNPOSTS.map(q).join(", ")},`);
push("}");
push("");
const counts = {
	InsertionPoint: insertion.length, IntelSpawn: PLACE.intel0.length + PLACE.intel1.length + PLACE.intel2.length + PLACE.intel3.length, VaultSpawn: vaults.length, ExtractionSite: extraction.length,
	SupplyCache: PLACE.cache.length, SecurityCamera: PLACE.camera.length, LaserGrid: doors.filter((d) => d.laser).length, KeycardDoor: 0, VentPairs: ventsOut.length, ZiplineAnchorPairs: ziplines.length,
	HealthStation: PLACE.health.length, AmmoCache: PLACE.ammo.length, FoodSpot: PLACE.food.length, AssetSafe: PLACE.safeStaff.length + PLACE.safeSec.length + PLACE.safeExec.length,
	SecretExit: secretOut.length, KeycardPrinter: printers.length, VaultTerminal: vaults.length, Elevator: shaftOut.length, Ladder: ladders.length,
};
push("-- What the self-check expects to find (Build.luau compares the built map with these).");
push(`local counts: { [string]: number } = { ${Object.entries(counts).map(([k, v]) => `${k} = ${v}`).join(", ")} }`);
push("");
push("return {");
push("\tlevels = { B = -24, G = 0, M = 24, T = 48, R = 72, S = 96 },");
push('\tlevelOrder = { "B", "G", "M", "T", "R", "S" },');
push("\ttowers = { { -140, -170, 140, 150 }, { 160, -85, 280, 125 } },");
push("\trooms = rooms,");
push("\tvoids = voids,");
push("\tramps = ramps,");
push("\tcurvedStairs = {},");
push("\tvents = vents,");
push("\tdoors = doors,");
push("\twindows = windows,");
push("\textraction = extraction,");
push("\tinsertion = insertion,");
push("\tvaults = vaults,");
push("\tprinters = printers,");
push(`\tsanctum = { level = "S", x = ${sanctum.x}, z = ${sanctum.z}, room = ${q(sanctum.room)} },`);
push("\tfeatures = features,");
push("\tplacements = placements,");
push("\tziplines = ziplines,");
push("\tgondola = gondola,");
push("\tnodes = nodes,");
push("\tsignposts = signposts,");
push("\tsecretExits = secretExits,");
push("\tshafts = shafts,");
push("\tladders = ladders,");
push("\tcounts = counts,");
push("\ttestSpawn = { x = 40, z = 112 },");
push("}");
push("");

// ---------------------------------------------------------------- report
const md = ["# Re-layout, as generated (tools/relayout-layout.cjs)\n", `Checks on the placed layout: **${problems.length === 0 ? "all pass" : problems.length + " problem(s)"}**${problems.length ? "\n\n" + problems.map((p) => "- " + p).join("\n") : ""}\n`];
md.push(`${rooms.length} rooms (${rooms.filter((r) => r.shaft).length} are elevator shaft pieces), ${doors.length} doors, ${stairsOut.length} stairs and ramps, ${shaftOut.length} elevator shafts, ${ventsOut.length} vents, ${secretOut.length} secret exits, ${ladders.length} ladders, ${ziplines.length} ziplines.\n`);
md.push("## Stairs and ramps as placed\n| Id | Kind | From | To | Position | Direction | Width | Tier |\n|---|---|---|---|---|---|---|---|");
for (const s of stairsOut) md.push(`| ${s.id} | ${s.kind} | ${s.from} ${s.fromRoom} | ${s.to} ${s.toRoom} | (${num(s.x)}, ${num(s.z)}) | ${s.dir}${s.turn ? " switchback" : ""} | ${s.turn ? s.width * 2 + 2 : s.width} | ${s.tier} |`);
md.push("\n## Elevator shafts\n| Shaft | Level | Room | In | Stop | Rect |\n|---|---|---|---|---|---|");
for (const s of shaftOut) for (const r of s.rooms) { const rr = room(r.room).rect; md.push(`| ${s.id} ${s.name}${s.locked ? " (locked)" : ""} | ${r.level} | ${r.room} | ${r.parent} | ${r.stop ? "yes" : "passes"} | (${rr.x1}, ${rr.z1}) to (${rr.x2}, ${rr.z2}) |`); }
md.push("\n## Clearance reach (from the grand lobby, Sanctum elevator unlocked)\n| Cap | Rooms reached | Not reached |\n|---|---|---|");
for (const r of reach) md.push(`| ${r.cap} | ${r.reached} | ${r.missing.join(", ") || "none"} |`);
md.push("\n## Independent routes in (from the 12 insertion points)\n| Objective | On foot, to the antechamber or foyer | All routes |\n|---|---|---|");
for (const r of routeRows) md.push(`| ${r.name} | ${r.walking} | ${r.total} |`);
if (!DRY) { fs.writeFileSync(OUT, lines.join("\n")); fs.writeFileSync(REPORT, md.join("\n") + "\n"); }
console.log(`${rooms.length} rooms, ${doors.length} doors, ${stairsOut.length} stairs, ${shaftOut.length} shafts, ${ventsOut.length} vents, ${secretOut.length} secret exits; ${problems.length} problem(s)`);
for (const p of problems) console.log("  - " + p);
console.log("routes:", routeRows.map((r) => `${r.name} ${r.walking}/${r.total}`).join(", "));
if (process.env.RL_DEBUG) module.exports = { freeOf, stairGeom, insideOneRoom, taken, doors, rooms, room, STAIRS, inflate, overlaps, doorClearOf, pieces, roomAt, segs, usedCrossings };
