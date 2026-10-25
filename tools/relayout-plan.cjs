// Checks the re-layout plan (tools/relayout-plan-data.cjs) and draws it. Usage: node tools/relayout-plan.cjs [outDir]
// Writes one SVG per level and plan-report.md (tables and check results) to docs/plans/relayout by default.
"use strict";
const fs = require("fs");
const path = require("path");
const D = require("./relayout-plan-data.cjs");

const outDir = process.argv[2] || path.join(__dirname, "..", "docs", "plans", "relayout");
fs.mkdirSync(outDir, { recursive: true });
const { LEVELS, rooms, FOOT, VOIDS, doors, conns, ziplines, vents, secretExits, vaults, sanctum, extraction, insertion, hubShare } = D;
const byId = Object.fromEntries(rooms.map((r) => [r.id, r]));
const problems = [];
const bad = (m) => problems.push(m);
const inRect = (r, x, z) => x >= r.x1 && x <= r.x2 && z >= r.z1 && z <= r.z2;
const inRoom = (r, x, z) => inRect(r.rect, x, z) && !r.holes.some((h) => x > h.x1 && x < h.x2 && z > h.z1 && z < h.z2);
const area = (r) => (r.rect.x2 - r.rect.x1) * (r.rect.z2 - r.rect.z1) - r.holes.reduce((s, h) => s + (h.x2 - h.x1) * (h.z2 - h.z1), 0);
const centre = (r) => [(r.rect.x1 + r.rect.x2) / 2, (r.rect.z1 + r.rect.z2) / 2];
const unique = (rs) => rs.length === new Set(rs.map((r) => r.id)).size;
if (!unique(rooms)) bad("duplicate room ids");

// ---------- 1. tiling: every footprint is covered by exactly one non-nested room (voids excepted)
const tiling = [];
for (const [level, foots] of Object.entries(FOOT)) {
	for (const f of foots) {
		let over = 0, gap = 0;
		const overs = new Set(), gaps = [];
		for (let x = f.rect.x1 + 0.5; x < f.rect.x2; x += 1) {
			for (let z = f.rect.z1 + 0.5; z < f.rect.z2; z += 1) {
				if (VOIDS.some((v) => v.levels.includes(level) && inRect(v.rect, x, z))) continue;
				const hits = rooms.filter((r) => r.level === level && !r.nested && inRoom(r, x, z));
				if (hits.length > 1) { over++; overs.add(hits.map((h) => h.id).sort().join("+")); }
				if (hits.length === 0) { gap++; if (gaps.length < 3) gaps.push(`(${x},${z})`); }
			}
		}
		tiling.push({ level, tower: f.tower, over, gap });
		if (over) bad(`tiling ${level}/${f.tower}: ${over} overlapping cells (${[...overs].join(", ")})`);
		if (gap) bad(`tiling ${level}/${f.tower}: ${gap} uncovered cells, e.g. ${gaps.join(" ")}`);
	}
}
// every room lies inside its level's footprints (or is a connector room), nested rooms inside a parent
for (const r of rooms) {
	const foots = FOOT[r.level];
	if (foots && !foots.some((f) => f.rect.x1 <= r.rect.x1 && f.rect.z1 <= r.rect.z1 && f.rect.x2 >= r.rect.x2 && f.rect.z2 >= r.rect.z2)) {
		if (!["m_bridge", "b_tunnel"].includes(r.id)) bad(`room ${r.id} sticks out of its level's footprint`);
	}
}

// ---------- 2. doors: the two rooms share a wall at least as long as the door
const holds = (o, i) => o.x1 <= i.x1 && o.z1 <= i.z1 && o.x2 >= i.x2 && o.z2 >= i.z2;
function innerWall(inner, edge) {
	const r = inner.rect;
	if (edge === "e") return { axis: "x", at: r.x2, from: r.z1, to: r.z2 };
	if (edge === "w") return { axis: "x", at: r.x1, from: r.z1, to: r.z2 };
	if (edge === "s") return { axis: "z", at: r.z2, from: r.x1, to: r.x2 };
	return { axis: "z", at: r.z1, from: r.x1, to: r.x2 };
}
function sharedWall(a, b, edge) {
	const A = a.rect, B = b.rect;
	if (edge && holds(A, B)) return innerWall(b, edge);
	if (edge && holds(B, A)) return innerWall(a, edge);
	if (A.x2 === B.x1 || B.x2 === A.x1) {
		const x = A.x2 === B.x1 ? A.x2 : A.x1, z1 = Math.max(A.z1, B.z1), z2 = Math.min(A.z2, B.z2);
		if (z2 - z1 > 0) return { axis: "x", at: x, from: z1, to: z2 };
	}
	if (A.z2 === B.z1 || B.z2 === A.z1) {
		const z = A.z2 === B.z1 ? A.z2 : A.z1, x1 = Math.max(A.x1, B.x1), x2 = Math.min(A.x2, B.x2);
		if (x2 - x1 > 0) return { axis: "z", at: z, from: x1, to: x2 };
	}
	return null;
}
const pairCount = {};
for (const d of doors) {
	const a = byId[d.a], b = byId[d.b];
	if (!a || !b) { bad(`door ${d.a}-${d.b}: unknown room`); continue; }
	if (a.level !== b.level) { bad(`door ${d.a}-${d.b}: rooms are on different levels`); continue; }
	const wall = sharedWall(a, b, d.edge);
	if (!wall) { bad(`door ${d.a}-${d.b}: rooms share no wall`); continue; }
	const len = wall.to - wall.from;
	if (len < d.width) bad(`door ${d.a}-${d.b}: width ${d.width} but the shared wall is ${len}`);
	const key = [d.a, d.b].sort().join("|");
	const i = (pairCount[key] = (pairCount[key] || 0) + 1) - 1;
	d.wall = wall; d.level = a.level; d.index = i;
	d.mid = (wall.from + wall.to) / 2 + i * (d.width + 2);
}

// ---------- 3. vertical connectors: footprint inside a room below, landing inside a room above
const roomAt = (level, x, z) => rooms.find((r) => r.level === level && inRoom(r, x, z) && !r.nested) || rooms.find((r) => r.level === level && inRoom(r, x, z));
for (const c of conns) {
	const [fx, fz] = [(c.from.x1 + c.from.x2) / 2, (c.from.z1 + c.from.z2) / 2];
	const fr = roomAt(c.fromLevel, fx, fz), tr = roomAt(c.toLevel, c.landing[0], c.landing[1]);
	if (!fr) bad(`connector ${c.id}: footprint centre is in no room on ${c.fromLevel}`);
	if (!tr) bad(`connector ${c.id}: landing is in no room on ${c.toLevel}`);
	c.fromRoom = fr && fr.id; c.toRoom = tr && tr.id;
	if (fr && !(inRect(fr.rect, c.from.x1, c.from.z1) && inRect(fr.rect, c.from.x2, c.from.z2))) bad(`connector ${c.id}: footprint leaves ${fr.id}`);
	if (fr && tr && fr.tower !== tr.tower && !["m_bridge"].includes(fr.id)) bad(`connector ${c.id}: joins two towers`);
}

// ---------- 4. the walking graph: doors and connectors (NPCs), plus vents, secret exits and ziplines (players)
function graph(opts) {
	const g = {};
	const link = (a, b, w = 1, oneWay = false) => {
		(g[a] = g[a] || []).push({ to: b, w });
		if (!oneWay) (g[b] = g[b] || []).push({ to: a, w });
	};
	const dist = (a, b) => { const [ax, az] = centre(byId[a]), [bx, bz] = centre(byId[b]); return Math.hypot(ax - bx, az - bz) + Math.abs(LEVELS[byId[a].level] - LEVELS[byId[b].level]); };
	for (const d of doors) if (byId[d.a] && byId[d.b] && d.wall) link(d.a, d.b, dist(d.a, d.b));
	for (const c of conns) if (c.fromRoom && c.toRoom && c.fromRoom !== c.toRoom && (opts.locked || !c.locked)) link(c.fromRoom, c.toRoom, dist(c.fromRoom, c.toRoom) + 30);
	if (opts.players) {
		for (const v of vents) link(v.from, v.to, dist(v.from, v.to) + 20);
		for (const s of secretExits) link(s.room, s.to, dist(s.room, s.to) + 10);
		for (const z of ziplines) {
			const a = roomAt(z.from.level, z.from.x, z.from.z), b = roomAt(z.to.level, z.to.x, z.to.z);
			if (a && b) link(a.id, b.id, dist(a.id, b.id), true); else bad(`zipline ${z.id}: an end is in no room`);
		}
	}
	return g;
}
const walk = graph({ locked: false, players: false });
const walkAfterUnlock = graph({ locked: true, players: false });
const all = graph({ locked: true, players: true });

// reachability by clearance cap, from the grand lobby, over rooms at or below the cap (vault cores need tier 3)
const reach = [];
for (let cap = 0; cap <= 3; cap++) {
	const ok = (id) => byId[id].tier <= cap;
	const seen = new Set(["g_lobby"]);
	const queue = ["g_lobby"];
	while (queue.length) {
		const id = queue.shift();
		for (const e of walkAfterUnlock[id] || []) if (!seen.has(e.to) && ok(e.to) && !(byId[e.to].vault && byId[e.to].tier === 3 && cap < 3)) { seen.add(e.to); queue.push(e.to); }
	}
	const missing = rooms.filter((r) => ok(r.id) && !r.nested && !seen.has(r.id) && r.id !== "g_lobby");
	reach.push({ cap, reached: seen.size, missing: missing.map((m) => m.id) });
	if (cap === 0) { const m0 = missing.filter((m) => m.tier === 0); if (m0.length) bad(`Guests (cap 0) cannot reach: ${m0.map((m) => m.id).join(", ")}`); }
	if (cap === 3) { const m3 = missing.filter((m) => m.id !== "s_sanctum" && m.id !== "s_foyer"); if (m3.length) bad(`Executives (cap 3) cannot reach: ${m3.map((m) => m.id).join(", ")}`); }
	if (cap === 1) { const m1 = missing.filter((m) => m.tier <= 1); if (m1.length) bad(`Staff (cap 1) cannot reach: ${m1.map((m) => m.id).join(", ")}`); }
	if (cap === 2) { const m2 = missing.filter((m) => m.tier <= 2); if (m2.length) bad(`Security (cap 2) cannot reach: ${m2.map((m) => m.id).join(", ")}`); }
}

// entrances: every Tier 1+ room, except nested rooms and vault cores, has two or more neighbours by door or stair
const neighbours = {};
for (const [a, list] of Object.entries(walkAfterUnlock)) neighbours[a] = new Set(list.map((e) => e.to));
const fewEntrances = rooms.filter((r) => r.tier >= 1 && !r.nested && !r.vault && !(r.kind === "OUT" && r.tier === 3) && (neighbours[r.id] || new Set()).size < 2);
for (const r of fewEntrances) bad(`room ${r.id} (tier ${r.tier}) has only ${(neighbours[r.id] || new Set()).size} entrance(s)`);

// ---------- 5. routes into each vault: edge-disjoint paths from the lobby (max-flow, unit capacities)
function disjointPaths(g, source, sink) {
	const cap = {};
	const key = (a, b) => `${a}>${b}`;
	for (const [a, list] of Object.entries(g)) for (const e of list) cap[key(a, e.to)] = (cap[key(a, e.to)] || 0) + 1;
	let flow = 0;
	for (;;) {
		const prev = { [source]: null };
		const queue = [source];
		while (queue.length && !(sink in prev)) {
			const u = queue.shift();
			for (const e of g[u] || []) if (!(e.to in prev) && (cap[key(u, e.to)] || 0) > 0) { prev[e.to] = u; queue.push(e.to); }
		}
		if (!(sink in prev)) return flow;
		for (let v = sink; prev[v] !== null; v = prev[v]) { cap[key(prev[v], v)]--; cap[key(v, prev[v])] = (cap[key(v, prev[v])] || 0) + 1; }
		flow++;
	}
}
function withSource(g) {
	const c = {};
	for (const [k, v] of Object.entries(g)) c[k] = v.slice();
	c.SRC = [];
	for (const m of insertion) { const r = roomAt(m.level, m.x, m.z); if (r) c.SRC.push({ to: r.id, w: 1 }), (c[r.id] = c[r.id] || []).push({ to: "SRC", w: 1 }); }
	return c;
}
const objectives = [...vaults.map((v) => ({ name: `Vault ${v.id}`, room: v.room, what: "core", ante: rooms.find((r) => r.vault === v.id && r.tier === 2).id })), { name: "The Sanctum", room: "s_foyer", what: "foyer" }];
const routes = objectives.map((o) => {
	const walking = disjointPaths(withSource(walkAfterUnlock), "SRC", o.ante || o.room);
	const total = disjointPaths(withSource(all), "SRC", o.room);
	if (total < 3) bad(`${o.name}: only ${total} routes in (need 3 or more)`);
	return { name: o.name, walking, total, what: o.what };
});

// ---------- 6. spacing rules and distances
const pos = (p) => [p.x, p.z, LEVELS[p.level]];
const d3 = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
const vaultSpacing = [];
for (let i = 0; i < vaults.length; i++) for (let j = i + 1; j < vaults.length; j++) vaultSpacing.push({ a: vaults[i].id, b: vaults[j].id, d: Math.round(d3(pos(vaults[i]), pos(vaults[j]))) });
const minVault = Math.min(...vaultSpacing.map((s) => s.d));
if (minVault < 100) bad(`two vaults are only ${minVault} studs apart`);
for (const v of vaults) if (!inRoom(byId[v.room], v.x, v.z)) bad(`vault ${v.id} terminal is outside its room`);
if (!inRoom(byId[sanctum.room], sanctum.x, sanctum.z)) bad("the Sanctum marker is outside its room");
for (const e of extraction) if (!roomAt(e.level, e.x, e.z)) bad(`extraction ${e.id} is in no room`);
let minIns = Infinity;
for (const a of insertion) {
	if (!roomAt(a.level, a.x, a.z)) bad(`insertion ${a.id} is in no room`);
	for (const b of insertion) if (a.id < b.id && a.level === b.level) minIns = Math.min(minIns, Math.hypot(a.x - b.x, a.z - b.z));
}
if (minIns < 60) bad(`two insertion points on one level are only ${Math.round(minIns)} studs apart`);
// walking distance from the Sanctum to each extraction site (Dijkstra over room centres, after the unlock)
function shortest(g, source) {
	const dist = { [source]: 0 };
	const todo = new Set([source]);
	while (todo.size) {
		let u = null;
		for (const n of todo) if (u === null || dist[n] < dist[u]) u = n;
		todo.delete(u);
		for (const e of g[u] || []) if (!(e.to in dist) || dist[u] + e.w < dist[e.to]) { dist[e.to] = dist[u] + e.w; todo.add(e.to); }
	}
	return dist;
}
const fromSanctum = shortest(walkAfterUnlock, "s_sanctum");
const extractionDist = extraction.map((e) => { const r = roomAt(e.level, e.x, e.z); return { id: e.id, d: Math.round(fromSanctum[r.id] ?? Infinity) }; });
for (const e of extractionDist) if (e.d < 120) bad(`extraction ${e.id} is only ${e.d} studs of walking from the Sanctum`);

// ---------- 7. NPC capacity model (estimates, to be measured)
const DENS = { hub: 35, public: 70, corridor: 90, outdoor: 60, 1: 130, 2: 180, 3: 220 }; // studs of floor per NPC, comfortable
function densityOf(r) {
	if (r.vault && r.tier === 3) return Infinity;
	if (r.hub && r.hub !== "guards") return DENS.hub;
	if (r.w && r.tier === 0) return DENS.corridor;
	if (r.tier === 0) return r.kind === "OUT" ? DENS.outdoor : DENS.public;
	return DENS[r.tier];
}
let capacity = 0;
const byTier = { 0: 0, 1: 0, 2: 0, 3: 0 }, areaTier = { 0: 0, 1: 0, 2: 0, 3: 0 };
for (const r of rooms) {
	if (r.nested) continue;
	const a = area(r), d = densityOf(r);
	areaTier[r.tier] += a;
	if (d !== Infinity) { capacity += a / d; byTier[r.tier] += a / d; }
}
const mix = { 0: 0.6, 1: 0.2, 2: 0.125, 3: 0.075 }; // today's role split
const crowdRows = [200, 300, 400, 500].map((n) => {
	const rowsT = {};
	for (const t of [0, 1, 2, 3]) rowsT[t] = { npcs: Math.round(n * mix[t]), cap: Math.round(byTier[t]), pct: Math.round((100 * n * mix[t]) / byTier[t]) };
	const hubs = {};
	for (const [h, share] of Object.entries(hubShare)) {
		if (share === 0 || h === "other") continue;
		const a = rooms.filter((r) => r.hub === h).reduce((s, r) => s + area(r), 0);
		if (a > 0) hubs[h] = { area: Math.round(a), perHundred: +((n * mix[0] * share * 100) / a).toFixed(2) };
	}
	return { n, tiers: rowsT, hubs };
});
// flow: lanes at 3.5 studs, 10 studs/s, 4 studs headway
const lanes = (w) => Math.max(1, Math.floor(w / 3.5));
const throughput = (w) => lanes(w) * 2.5;
const portalWidths = doors.filter((d) => byId[d.a].tier === 0 && byId[d.b].tier === 0).map((d) => d.width);
const avgPublicPortal = portalWidths.reduce((s, w) => s + w, 0) / portalWidths.length;
const cycle = 37; // seconds from one trip start to the next (walk plus activity), as measured today
const flowRows = [200, 300, 400, 500].map((n) => ({ n, tripsPerS: +(n / cycle).toFixed(1), crossingsPerS: +((5 * n) / cycle).toFixed(1) }));
const portalCap = portalWidths.reduce((s, w) => s + throughput(w), 0);

// ---------- 8. drawing
const S = 2.6, MARGIN = 30;
const TIER = ["#e8e6dc", "#6fbf73", "#8d5fc7", "#e3b23c"], VAULT = "#c0392b";
function drawLevel(key, title, levels, bounds) {
	const [x1, z1, x2, z2] = bounds;
	const W = Math.round((x2 - x1) * S + MARGIN * 2), H = Math.round((z2 - z1) * S + MARGIN * 2);
	const px = (x) => ((x - x1) * S + MARGIN).toFixed(1), pz = (z) => ((z - z1) * S + MARGIN).toFixed(1);
	const rect = (r, fill, stroke, extra = "") => `<rect x="${px(r.x1)}" y="${pz(r.z1)}" width="${((r.x2 - r.x1) * S).toFixed(1)}" height="${((r.z2 - r.z1) * S).toFixed(1)}" fill="${fill}" stroke="${stroke}" ${extra}/>`;
	const out = [`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H + 120}" viewBox="0 0 ${W} ${H + 120}" font-family="Segoe UI, Arial, sans-serif"><rect width="100%" height="100%" fill="#1c1f26"/>`];
	out.push(`<text x="16" y="22" fill="#fff" font-size="18" font-weight="700">Gala re-layout plan: ${title}</text>`);
	const onLevel = rooms.filter((r) => levels.includes(r.level));
	for (const r of onLevel.filter((r) => !r.nested).sort((a, b) => b.holes.length - a.holes.length)) {
		const isVault = r.vault && r.tier >= 2 && r.id !== "s_sanctum";
		const fill = r.id === "s_sanctum" ? "#7b1e1e" : isVault && r.tier === 3 ? VAULT : TIER[r.tier];
		out.push(rect(r.rect, fill, "#111", `fill-opacity="${r.kind === "OUT" ? 0.45 : 0.85}" stroke-width="1.4"`));
		for (const h of r.holes) out.push(rect(h, "#1c1f26", "#111"));
	}
	for (const r of onLevel.filter((r) => r.nested)) out.push(rect(r.rect, TIER[r.tier], "#111", `fill-opacity="0.95" stroke-width="1.4"`));
	for (const v of VOIDS.filter((v) => v.levels.some((l) => levels.includes(l)))) out.push(rect(v.rect, "#0b2b4a", "#5aa0e0", `stroke-dasharray="4 3" stroke-width="2"`));
	for (const r of onLevel) {
		const [cx, cz] = centre(r), wide = (r.rect.x2 - r.rect.x1) * S, tall = (r.rect.z2 - r.rect.z1) * S;
		if (wide < 42 && tall < 30) continue;
		const size = Math.max(8, Math.min(12, wide / 9));
		const label = r.name + (r.hub ? " *" : "");
		out.push(`<text x="${px(cx)}" y="${pz(r.holes.length ? r.rect.z1 + 6 : cz)}" text-anchor="middle" font-size="${size}" fill="${r.tier === 2 || (r.vault && r.tier === 3) ? "#fff" : "#111"}">${label}</text>`);
	}
	for (const d of doors.filter((d) => d.wall && levels.includes(d.level))) {
		const w = d.wall, half = d.width / 2;
		const colour = d.vault ? "#ff2d2d" : d.laser ? "#ff7a7a" : d.gate ? ["#fff", "#2f9e44", "#5b2a9a", "#e3a400"][d.gate] : d.arch ? "#ffe9a8" : "#fff";
		const box = w.axis === "x" ? { x1: w.at - 0.8, x2: w.at + 0.8, z1: d.mid - half, z2: d.mid + half } : { x1: d.mid - half, x2: d.mid + half, z1: w.at - 0.8, z2: w.at + 0.8 };
		out.push(rect(box, colour, "#000", `stroke-width="0.7"`));
	}
	for (const c of conns) {
		if (levels.includes(c.fromLevel)) {
			const cyan = /elevator/i.test(c.kind);
			out.push(rect(c.from, cyan ? "#1fb5c9" : "#3b3f4a", cyan ? "#fff" : "#ffd23f", `stroke-width="1.4"`));
			const [fx, fz] = [(c.from.x1 + c.from.x2) / 2, (c.from.z1 + c.from.z2) / 2];
			out.push(`<text x="${px(fx)}" y="${(Number(pz(fz)) + 3).toFixed(1)}" text-anchor="middle" font-size="8" fill="#ffd23f">&#8593;${c.toLevel}</text>`);
		}
		if (levels.includes(c.toLevel) && !levels.includes(c.fromLevel)) {
			out.push(`<circle cx="${px(c.landing[0])}" cy="${pz(c.landing[1])}" r="4" fill="none" stroke="#ffd23f" stroke-dasharray="2 2"/><text x="${px(c.landing[0])}" y="${(Number(pz(c.landing[1])) - 6).toFixed(1)}" text-anchor="middle" font-size="7" fill="#ffd23f">&#8595;${c.fromLevel}</text>`);
		}
	}
	for (const z of ziplines) {
		if (levels.includes(z.from.level)) out.push(`<circle cx="${px(z.from.x)}" cy="${pz(z.from.z)}" r="5" fill="#f08a24" stroke="#fff"/><text x="${px(z.from.x)}" y="${(Number(pz(z.from.z)) - 8).toFixed(1)}" text-anchor="middle" font-size="8" fill="#f08a24">zip &#8594;${z.to.level}</text>`);
		if (levels.includes(z.to.level)) out.push(`<circle cx="${px(z.to.x)}" cy="${pz(z.to.z)}" r="4" fill="none" stroke="#f08a24" stroke-width="2"/>`);
	}
	for (const v of vaults.filter((v) => levels.includes(v.level))) out.push(`<text x="${px(v.x)}" y="${(Number(pz(v.z)) + 4).toFixed(1)}" text-anchor="middle" font-size="15" fill="#fff" font-weight="900">&#9635;</text><text x="${px(v.x)}" y="${(Number(pz(v.z)) + 17).toFixed(1)}" text-anchor="middle" font-size="9" fill="#fff" font-weight="700">terminal ${v.id}</text>`);
	if (levels.includes(sanctum.level)) out.push(`<text x="${px(sanctum.x)}" y="${(Number(pz(sanctum.z)) + 5).toFixed(1)}" text-anchor="middle" font-size="18" fill="#ffd23f" font-weight="900">&#9733; Package</text>`);
	for (const m of insertion.filter((m) => levels.includes(m.level))) out.push(`<circle cx="${px(m.x)}" cy="${pz(m.z)}" r="6" fill="#3d8bfd" stroke="#fff"/><text x="${px(m.x)}" y="${(Number(pz(m.z)) + 3).toFixed(1)}" text-anchor="middle" font-size="8" fill="#fff">${m.id}</text>`);
	for (const m of extraction.filter((m) => levels.includes(m.level))) out.push(`<circle cx="${px(m.x)}" cy="${pz(m.z)}" r="9" fill="#18c26b" stroke="#fff" stroke-width="2"/><text x="${px(m.x)}" y="${(Number(pz(m.z)) - 13).toFixed(1)}" text-anchor="middle" font-size="10" fill="#18c26b" font-weight="700">EXTRACT ${m.id}</text>`);
	for (const s of secretExits.filter((s) => levels.includes(byId[s.room].level))) { const [cx, cz] = centre(byId[s.room]); out.push(`<circle cx="${px(cx + 4)}" cy="${pz(cz + 4)}" r="3.5" fill="#e83fb0" stroke="#fff"/>`); }
	for (const v of vents.filter((v) => levels.includes(byId[v.to].level))) { const [cx, cz] = centre(byId[v.to]); out.push(`<rect x="${px(cx - 5)}" y="${pz(cz - 5)}" width="${(7 * S).toFixed(0)}" height="${(7 * S).toFixed(0)}" fill="#f08a24" fill-opacity="0.35" stroke="#f08a24"/>`); }
	const legend = [["Public", TIER[0]], ["Staff", TIER[1]], ["Security", TIER[2]], ["Executive", TIER[3]], ["Vault / Sanctum", VAULT], ["Stair or ramp", "#3b3f4a"], ["Glass elevator", "#1fb5c9"], ["Insertion", "#3d8bfd"], ["Extraction", "#18c26b"], ["Secret exit", "#e83fb0"], ["Vent shaft", "#f08a24"], ["Arch / open", "#ffe9a8"]];
	legend.forEach(([label, color], i) => { const x = 16 + (i % 6) * 160, y = H + 20 + Math.floor(i / 6) * 22; out.push(`<rect x="${x}" y="${y - 11}" width="14" height="14" fill="${color}" stroke="#fff"/><text x="${x + 20}" y="${y}" fill="#ddd" font-size="12">${label}</text>`); });
	out.push(`<text x="16" y="${H + 80}" fill="#999" font-size="11">North is up (-z). * = crowd hub. Doors are coloured by the clearance they need (green Staff, purple Security, gold Executive, red vault). Plan zones: the build splits them into rooms.</text></svg>`);
	fs.writeFileSync(path.join(outDir, `plan-${key}.svg`), out.join("\n"));
}
drawLevel("B", "Basement (B, -24): service ring, stores, the security complex, Vault A and Vault D", ["B"], [-150, -180, 290, 160]);
drawLevel("G", "Ground (G, 0): the atrium, colonnade ring, themed wings, Vault C", ["G"], [-150, -180, 290, 160]);
drawLevel("M", "Mezzanine (M, 24): balcony promenade, galleries, security hub, terraces, skybridge", ["M"], [-150, -180, 290, 160]);
drawLevel("T", "Top floor (T, 48): upper terraces, guard ring, penthouse, Vault B, wing suites", ["T"], [-135, -165, 290, 145]);
drawLevel("R", "Roof (R, 72) with the Sanctum crown (S, 84) and the sky deck (96)", ["R", "S", "D"], [-100, -130, 290, 135]);

// ---------- 9. report
const md = [];
md.push("# Re-layout plan report (generated by tools/relayout-plan.cjs)\n");
md.push(`Checks: **${problems.length === 0 ? "all pass" : problems.length + " problem(s)"}**${problems.length ? "\n\n" + problems.map((p) => "- " + p).join("\n") : ""}\n`);
md.push("## Rooms by level\n| Level | Room | Tier | Kind | Area (studs²) | Width | Notes |\n|---|---|---|---|---|---|---|");
for (const r of rooms) md.push(`| ${r.level} | ${r.name} (\`${r.id}\`) | ${r.tier} | ${r.kind} | ${Math.round(area(r))} | ${r.w ? r.w : Math.min(r.rect.x2 - r.rect.x1, r.rect.z2 - r.rect.z1)} | ${[r.hub ? "hub: " + r.hub : "", r.vault ? "vault " + r.vault : "", r.nested ? "nested" : "", r.note].filter(Boolean).join("; ")} |`);
md.push("\n## Vertical connectors\n| Id | Kind | From | To | Width | Tier | Note |\n|---|---|---|---|---|---|---|");
for (const c of conns) md.push(`| ${c.id} | ${c.kind} | ${c.fromLevel} (${c.fromRoom}) | ${c.toLevel} (${c.toRoom}) | ${c.width} | ${c.tier} | ${c.note || ""}${c.stops ? " Stops: " + c.stops.join(", ") + "." : ""}${c.locked ? " Locked until all 3 terminals are hacked." : ""} |`);
md.push("\n## Reachability from the grand lobby, by clearance cap (doors and stairs, Sanctum elevator unlocked)\n| Cap | Rooms reached | Not reached |\n|---|---|---|");
for (const r of reach) md.push(`| ${r.cap} | ${r.reached} | ${r.missing.join(", ") || "none"} |`);
md.push("\n## Independent routes in, counted from all 12 insertion points\nA vault is measured at its antechamber on foot (doors and stairs) and at its core with vents and secret exits; the Sanctum is measured at its foyer, with the elevator unlocked and the zipline.\n| Objective | On foot, to the antechamber or foyer | All routes, to the core or foyer |\n|---|---|---|");
for (const r of routes) md.push(`| ${r.name} | ${r.walking} | ${r.total} |`);
md.push("\n## Spacing\n- Vault pairs (3D studs): " + vaultSpacing.map((s) => `${s.a}-${s.b} ${s.d}`).join(", ") + `\n- Nearest insertion points on one level: ${Math.round(minIns)} studs\n- Walking distance from the Sanctum to each extraction site: ` + extractionDist.map((e) => `${e.id} ${e.d}`).join(", "));
md.push("\n## NPC capacity (estimate, comfortable densities: hubs 1 per 35 studs², public 70, corridors 90, outdoors 60, Staff 130, Security 180, Executive 220)\n| Tier | Floor area (studs²) | Comfortable NPCs |\n|---|---|---|");
for (const t of [0, 1, 2, 3]) md.push(`| ${["Public", "Staff", "Security", "Executive"][t]} | ${Math.round(areaTier[t])} | ${Math.round(byTier[t])} |`);
md.push(`| **All** | ${Math.round(Object.values(areaTier).reduce((a, b) => a + b, 0))} | **${Math.round(capacity)}** |`);
md.push("\n### Load at each crowd size (60% Guests, 20% Staff, 12.5% Security, 7.5% Executive)\n| NPCs | Guests vs public capacity | Staff | Security | Executive |\n|---|---|---|---|---|");
for (const c of crowdRows) md.push(`| ${c.n} | ${c.tiers[0].npcs} / ${c.tiers[0].cap} (${c.tiers[0].pct}%) | ${c.tiers[1].npcs} / ${c.tiers[1].cap} (${c.tiers[1].pct}%) | ${c.tiers[2].npcs} / ${c.tiers[2].cap} (${c.tiers[2].pct}%) | ${c.tiers[3].npcs} / ${c.tiers[3].cap} (${c.tiers[3].pct}%) |`);
md.push("\n### Hub density (Guests per 100 studs² at each crowd size; comfortable is 2.9)\n| Hub | Area | " + crowdRows.map((c) => c.n).join(" | ") + " |\n|---|---|" + crowdRows.map(() => "---|").join(""));
for (const h of Object.keys(crowdRows[0].hubs)) md.push(`| ${h} | ${crowdRows[0].hubs[h].area} | ${crowdRows.map((c) => c.hubs[h].perHundred).join(" | ")} |`);
md.push(`\n### Flow\nA lane takes 3.5 studs and passes 2.5 NPCs a second (10 studs/s, 4 studs apart). Average public portal is ${avgPublicPortal.toFixed(1)} studs wide (${lanes(avgPublicPortal)} lanes, ${throughput(avgPublicPortal).toFixed(1)}/s); the ${portalWidths.length} public portals together pass ${portalCap.toFixed(0)} NPCs a second.\n| NPCs | Trips started per second | Portal crossings per second (about 5 per trip) | Share of total portal capacity |\n|---|---|---|---|`);
for (const f of flowRows) md.push(`| ${f.n} | ${f.tripsPerS} | ${f.crossingsPerS} | ${Math.round((100 * f.crossingsPerS) / portalCap)}% |`);
// dead ends: rooms with a single way in or out (vault cores, nested rooms and landings excepted)
const deadEnds = rooms.filter((r) => !r.nested && !(r.vault && r.tier === 3) && (neighbours[r.id] || new Set()).size === 1);
md.push("\n## Dead ends (rooms with one way in or out, by door or stair)");
md.push(deadEnds.length ? deadEnds.map((r) => `- ${r.name} (\`${r.id}\`, tier ${r.tier})`).join("\n") : "none");
// vertical capacity for NPCs (stairs and ramps; elevators are for players first), by level pair and tier
const pairs = {};
for (const c of conns.filter((c) => !/elevator/i.test(c.kind))) {
	const k = `${c.fromLevel} to ${c.toLevel}`;
	pairs[k] = pairs[k] || { n: 0, cap: { 0: 0, 1: 0, 2: 0, 3: 0 } };
	pairs[k].n++;
	pairs[k].cap[c.tier] += throughput(c.width);
}
md.push("\n## Vertical links NPCs can use (stairs and ramps; people per second each way)\n| Levels | Links | Public | Staff | Security | Executive |\n|---|---|---|---|---|---|");
for (const [k, v] of Object.entries(pairs)) md.push(`| ${k} | ${v.n} | ${v.cap[0]} | ${v.cap[1]} | ${v.cap[2]} | ${v.cap[3]} |`);
md.push(`\nAt 400 NPCs about a quarter of the ${(400 / cycle).toFixed(1)} trips a second change level, about ${((400 / cycle) * 0.25).toFixed(1)} a second, spread over every link above.`);
fs.writeFileSync(path.join(outDir, "plan-report.md"), md.join("\n") + "\n");
console.log(`${rooms.length} rooms, ${doors.length} doors, ${conns.length} connectors; ${problems.length} problem(s)`);
for (const p of problems) console.log("  - " + p);
console.log("routes:", routes.map((r) => `${r.name} ${r.walking}/${r.total}`).join(", "));
console.log("capacity:", Math.round(capacity), "| extraction from Sanctum:", extractionDist.map((e) => `${e.id} ${e.d}`).join(", "));
