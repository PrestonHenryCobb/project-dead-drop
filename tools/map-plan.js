// Draws floor plans of The Gala from src/server/Tools/Gala/Layout.luau, one SVG per level, for reviewing a layout
// without Studio (for example from a phone). Usage: node tools/map-plan.js [outDir]
// It reads the Layout data with a few patterns, not a Luau parser, so it understands the shapes Layout.luau uses:
// room(...), door(...), the ramps table, the voids table, the markers, and the named rect constants.
"use strict";
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const outDir = process.argv[2] || path.join(root, "docs", "plans");
const src = fs.readFileSync(path.join(root, "src/server/Tools/Gala/Layout.luau"), "utf8");
const flat = src.replace(/--[^\n]*/g, "").replace(/\s+/g, " ");

// Named rects: local FG = { -140, -170, 140, 150 }
const consts = {};
for (const m of flat.matchAll(/local (\w+) = \{ (-?[\d.]+), (-?[\d.]+), (-?[\d.]+), (-?[\d.]+) \}/g)) {
	consts[m[1]] = [m[2], m[3], m[4], m[5]].map(Number);
}
const rectOf = (text) => {
	const t = text.trim();
	if (consts[t]) return consts[t];
	const nums = t.replace(/[{}]/g, "").split(",").map(Number);
	return nums.length === 4 && nums.every((n) => !Number.isNaN(n)) ? nums : null;
};
const RECT = String.raw`(\{ -?[\d.]+, -?[\d.]+, -?[\d.]+, -?[\d.]+ \}|[A-Z_]+)`;

const rooms = [];
const roomRe = new RegExp(String.raw`room\( ?"(\w+)", "(\w+)", "([^"]+)", (\d), (IN|OUT|GALLERY), ${RECT}(?:, \{([^)]*)\})? ?\)`, "g");
for (const m of flat.matchAll(roomRe)) {
	const extra = m[7] || "";
	const holes = [];
	const holesMatch = extra.match(/holes = \{ ([^}]*\}?) \}/);
	if (holesMatch) {
		for (const h of holesMatch[1].split(/,(?![^{]*\})/)) {
			const r = rectOf(h);
			if (r) holes.push(r);
		}
	}
	rooms.push({
		id: m[1], level: m[2], name: m[3], tier: Number(m[4]), kind: m[5], rect: rectOf(m[6]), holes,
		parent: (extra.match(/parent = "(\w+)"/) || [])[1],
	});
}
// Vent ducts: duct("v_x", "B", "Name", 3, { ... }, "parent")
for (const m of flat.matchAll(new RegExp(String.raw`duct\("(\w+)", "(\w+)", "([^"]+)", (\d), ${RECT}, "(\w+)"\)`, "g"))) {
	rooms.push({ id: m[1], level: m[2], name: m[3], tier: Number(m[4]), kind: "DUCT", rect: rectOf(m[5]), holes: [], parent: m[6] });
}
const byId = Object.fromEntries(rooms.map((r) => [r.id, r]));

const doors = [];
for (const m of flat.matchAll(/door\("(\w+)", "(\w+)", (-?[\d.]+|nil), (-?[\d.]+|nil)(?:, \{([^}]*)\})?\)/g)) {
	const o = m[5] || "";
	doors.push({
		a: m[1], b: m[2], at: m[3] === "nil" ? null : Number(m[3]), width: m[4] === "nil" ? 10 : Number(m[4]),
		gate: Number((o.match(/gate = (\d)/) || [])[1]) || 0, keycard: /keycard/.test(o), vault: /vault =/.test(o), laser: /laser/.test(o),
	});
}

const ramps = [];
for (const m of flat.matchAll(/\{ from = "(\w+)",(?: to = "(\w+)",)? x = (-?[\d.]+), z = (-?[\d.]+), dir = "([+-][xz])"(, turn = true)? \}/g)) {
	ramps.push({ from: m[1], to: m[2], x: Number(m[3]), z: Number(m[4]), dir: m[5], turn: !!m[6] });
}
const voids = [];
for (const m of flat.matchAll(new RegExp(String.raw`\{ level = "(\w+)", rect = ${RECT} \}`, "g"))) voids.push({ level: m[1], rect: rectOf(m[2]) });
// Water and garden islands (the other set pieces are left out of the plan).
const features = [];
for (const m of flat.matchAll(new RegExp(String.raw`\{ kind = "(pool|island)", level = "(\w+)", rect = ${RECT} \}`, "g"))) {
	features.push({ kind: m[1], level: m[2], rect: rectOf(m[3]) });
}
const markers = (name) => {
	const block = flat.match(new RegExp(`local ${name}: \\{ Marker \\} = \\{(.*?)\\},? \\}`));
	return block ? [...block[1].matchAll(/id = "(\w+)", level = "(\w+)", x = (-?[\d.]+), z = (-?[\d.]+)/g)].map((m) => ({ id: m[1], level: m[2], x: Number(m[3]), z: Number(m[4]) })) : [];
};
const insertion = markers("insertion"), extraction = markers("extraction"), vaults = markers("vaults");

// Drawing -----------------------------------------------------------------------------------------------------------
const S = 2; // pixels per stud
const X0 = -180, X1 = 300, Z0 = -185, Z1 = 165;
const W = (X1 - X0) * S, H = (Z1 - Z0) * S;
const px = (x) => ((x - X0) * S).toFixed(1);
const pz = (z) => ((z - Z0) * S + 40).toFixed(1);
const TIER = { 0: "#e9e6df", 1: "#7fc47f", 2: "#8a5cc0", 3: "#e3bb4f" };
const VAULT = "#d9534f";
const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
const rectSvg = (r, fill, stroke, extra = "") =>
	`<rect x="${px(Math.min(r[0], r[2]))}" y="${pz(Math.min(r[1], r[3]))}" width="${(Math.abs(r[2] - r[0]) * S).toFixed(1)}" height="${(Math.abs(r[3] - r[1]) * S).toFixed(1)}" fill="${fill}" stroke="${stroke}" ${extra}/>`;

// The walls a room has: its rect's four sides and its holes' four sides, as { axis, line, a, b }.
const sides = (r) => [
	{ axis: "x", line: r[1], a: r[0], b: r[2] }, { axis: "x", line: r[3], a: r[0], b: r[2] },
	{ axis: "z", line: r[0], a: r[1], b: r[3] }, { axis: "z", line: r[2], a: r[1], b: r[3] },
];
const wallsOf = (room) => [...sides(room.rect), ...room.holes.flatMap(sides)];
function doorSpot(d) {
	const A = byId[d.a], B = byId[d.b];
	if (!A || !B) return null;
	let best = null;
	for (const s of wallsOf(A)) for (const t of wallsOf(B)) {
		if (s.axis !== t.axis || Math.abs(s.line - t.line) > 1e-6) continue;
		const lo = Math.max(s.a, t.a), hi = Math.min(s.b, t.b);
		if (hi - lo <= 0) continue;
		const has = d.at !== null && d.at >= lo && d.at <= hi;
		if (!best || has || (!best.has && hi - lo > best.hi - best.lo)) best = { axis: s.axis, line: s.line, lo, hi, has };
	}
	if (!best) return null;
	const w = Math.min(d.width, best.hi - best.lo - 2);
	const c = Math.min(Math.max(d.at ?? (best.lo + best.hi) / 2, best.lo + w / 2 + 1), best.hi - w / 2 - 1);
	return best.axis === "x" ? { x1: c - w / 2, z1: best.line - 1.5, x2: c + w / 2, z2: best.line + 1.5 } : { x1: best.line - 1.5, z1: c - w / 2, x2: best.line + 1.5, z2: c + w / 2 };
}
function stairFoot(r) {
	const rise = r.to === "GH" ? 12 : 24;
	const [w, len] = r.turn ? [14, rise + 6] : [6, rise * 2];
	const sign = r.dir[0] === "+" ? 1 : -1;
	if (r.dir[1] === "z") return [r.x - w / 2, r.z, r.x + w / 2, r.z + sign * len];
	return [r.x, r.z - w / 2, r.x + sign * len, r.z + w / 2];
}

const LEVELS = [
	{ key: "B", title: "Basement (B)", levels: ["B"] },
	{ key: "G", title: "Ground (G), galleries (GH) dashed", levels: ["G", "GH"] },
	{ key: "M", title: "Mezzanine (M)", levels: ["M"] },
	{ key: "T", title: "Top floor (T)", levels: ["T"] },
	{ key: "R", title: "Roof (R) and sky deck (X, dashed)", levels: ["R", "X"] },
];
const NEXT = { B: "G", G: "M", M: "T", T: "R", R: "X" };

fs.mkdirSync(outDir, { recursive: true });
for (const L of LEVELS) {
	const out = [];
	out.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H + 120}" viewBox="0 0 ${W} ${H + 120}" font-family="Segoe UI, Arial, sans-serif">`);
	out.push(`<rect width="100%" height="100%" fill="#1c1f26"/>`);
	out.push(`<text x="16" y="28" fill="#fff" font-size="20" font-weight="700">The Gala re-plan: ${esc(L.title)}</text>`);
	const [main, second] = L.levels;
	for (const lvl of [main, second].filter(Boolean)) {
		const dashed = lvl === second;
		// Rings first (their holes are painted as background), then the rooms inside them.
		const onLevel = rooms.filter((q) => q.level === lvl && q.kind !== "DUCT").sort((p, q) => q.holes.length - p.holes.length);
		for (const r of onLevel) {
			const isVault = /vault/.test(r.id);
			let fill = isVault ? VAULT : TIER[r.tier];
			let op = r.kind === "OUT" ? 0.45 : r.parent ? 0.95 : 0.8;
			if (dashed) op = 0.35;
			out.push(rectSvg(r.rect, fill, "#111", `fill-opacity="${op}" stroke-width="${dashed ? 2 : 1.5}" ${dashed ? 'stroke-dasharray="6 4"' : ""}`));
			for (const h of r.holes) out.push(rectSvg(h, "#1c1f26", "#111", `stroke-width="1.5"`));
		}
	}
	for (const f of features.filter((q) => q.level === main)) {
		out.push(rectSvg(f.rect, f.kind === "pool" ? "#2f6fa3" : "#5f8f4f", "#111", `fill-opacity="0.85"`));
	}
	for (const v of voids.filter((q) => q.level === main)) out.push(rectSvg(v.rect, "#0b2b4a", "#5aa0e0", `stroke-dasharray="4 3" stroke-width="2"`));
	// Ducts
	for (const r of rooms.filter((q) => q.level === main && q.kind === "DUCT")) out.push(rectSvg(r.rect, "#f08a24", "#f08a24", `fill-opacity="0.8"`));
	// Labels
	for (const lvl of [main, second].filter(Boolean)) {
		for (const r of rooms.filter((q) => q.level === lvl && q.kind !== "DUCT")) {
			const [x1, z1, x2, z2] = r.rect;
			const wide = Math.abs(x2 - x1) * S;
			if (wide < 40 && Math.abs(z2 - z1) * S < 40) continue;
			const size = Math.max(9, Math.min(13, wide / 10));
			let cx = (x1 + x2) / 2, cz = (z1 + z2) / 2;
			if (r.holes.length) cz = z1 + 7; // a ring: label its north side
			out.push(`<text x="${px(cx)}" y="${pz(cz)}" text-anchor="middle" font-size="${size}" fill="${r.tier === 2 || /vault/.test(r.id) ? "#fff" : "#111"}" ${lvl === second ? 'font-style="italic"' : ""}>${esc(r.name)}</text>`);
		}
	}
	// Doors
	for (const d of doors) {
		const A = byId[d.a];
		if (!A || !L.levels.includes(A.level)) continue;
		const s = doorSpot(d);
		if (!s) continue;
		const isVent = byId[d.a].kind === "DUCT" || byId[d.b].kind === "DUCT";
		const color = d.vault ? "#ff2d2d" : isVent ? "#f08a24" : d.keycard ? "#28d7e8" : d.gate ? ["#fff", "#2f9e44", "#5b2a9a", "#e3a400"][d.gate] : "#ffffff";
		out.push(rectSvg([s.x1, s.z1, s.x2, s.z2], color, d.laser ? "#ff2d2d" : "#000", `stroke-width="${d.laser ? 2.5 : 0.8}"`));
	}
	// Stairs: footprint where they start, an arrow where they arrive
	for (const r of ramps) {
		const f = stairFoot(r);
		if (r.from === main) {
			out.push(rectSvg(f, "#3b3f4a", "#ffd23f", `stroke-width="1.5"`));
			out.push(`<text x="${px((f[0] + f[2]) / 2)}" y="${pz((f[1] + f[3]) / 2)}" text-anchor="middle" font-size="10" fill="#ffd23f">&#8593;${r.to || NEXT[r.from]}</text>`);
		}
		const arrives = r.to || NEXT[r.from];
		if (L.levels.includes(arrives) && r.from !== main) {
			out.push(rectSvg(f, "none", "#ffd23f", `stroke-dasharray="3 3" stroke-width="1.2"`));
			out.push(`<text x="${px((f[0] + f[2]) / 2)}" y="${pz((f[1] + f[3]) / 2)}" text-anchor="middle" font-size="10" fill="#ffd23f">&#8595;${r.from}</text>`);
		}
	}
	// Markers
	for (const m of insertion.filter((q) => L.levels.includes(q.level))) out.push(`<circle cx="${px(m.x)}" cy="${pz(m.z)}" r="6" fill="#3d8bfd" stroke="#fff"/><text x="${px(m.x)}" y="${(Number(pz(m.z)) + 3.5).toFixed(1)}" text-anchor="middle" font-size="8" fill="#fff">${m.id.replace("Insertion", "")}</text>`);
	for (const m of extraction.filter((q) => L.levels.includes(q.level))) out.push(`<circle cx="${px(m.x)}" cy="${pz(m.z)}" r="9" fill="#18c26b" stroke="#fff" stroke-width="2"/><text x="${px(m.x)}" y="${(Number(pz(m.z)) - 13).toFixed(1)}" text-anchor="middle" font-size="11" fill="#18c26b" font-weight="700">EXTRACT ${m.id}</text>`);
	for (const m of vaults.filter((q) => L.levels.includes(q.level))) out.push(`<text x="${px(m.x)}" y="${(Number(pz(m.z)) + 5).toFixed(1)}" text-anchor="middle" font-size="16" fill="#fff" font-weight="900">&#9670;</text><text x="${px(m.x)}" y="${(Number(pz(m.z)) + 18).toFixed(1)}" text-anchor="middle" font-size="10" fill="#fff" font-weight="700">${m.id}</text>`);
	// Legend
	const ly = H + 60;
	const legend = [
		["Public", TIER[0]], ["Staff", TIER[1]], ["Security", TIER[2]], ["Executive", TIER[3]], ["Vault wing", VAULT],
		["Keycard door", "#28d7e8"], ["Vent", "#f08a24"], ["Stair (start)", "#3b3f4a"], ["Insertion", "#3d8bfd"], ["Extraction", "#18c26b"],
	];
	legend.forEach(([label, color], i) => {
		const x = 16 + (i % 5) * 190, y = ly + Math.floor(i / 5) * 26;
		out.push(`<rect x="${x}" y="${y - 12}" width="16" height="16" fill="${color}" stroke="#fff"/><text x="${x + 22}" y="${y + 1}" fill="#ddd" font-size="13">${label}</text>`);
	});
	out.push(`<text x="16" y="${ly + 50}" fill="#999" font-size="12">North is up (-z). 1 grid stud = ${S} px. Clearance doors are coloured by the tier they need; a red outline is a laser grid; red fill is a vault door. Dashed yellow = a stair arriving from below.</text>`);
	out.push(`</svg>`);
	fs.writeFileSync(path.join(outDir, `plan-${L.key}.svg`), out.join("\n"));
}
console.log(`rooms ${rooms.length}, doors ${doors.length}, ramps ${ramps.length}, voids ${voids.length}, markers ${insertion.length}/${extraction.length}/${vaults.length} -> ${outDir}`);
