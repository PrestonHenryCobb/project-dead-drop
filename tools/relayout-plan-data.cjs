// The Gala re-layout plan as data (docs/MAP_BRIEF_RELAYOUT.md). Not wired to the generator: tools/relayout-plan.cjs
// checks it (tiling, doors, reachability, vault routes) and draws the floor plans. Coordinates are studs; north is -z.
// Rects are { x1, z1, x2, z2 }. Tiers: 0 public, 1 Staff, 2 Security, 3 Executive. A "vault" room is Tier 3 with a vault door.
"use strict";

const LEVELS = { B: -24, G: 0, GH: 12, M: 24, T: 48, R: 72, S: 84, D: 96 };
const rooms = [];
const r4 = (a) => ({ x1: a[0], z1: a[1], x2: a[2], z2: a[3] });
// room(level, id, name, tier, kind, rect, options)  kind: IN | OUT | GAL
function room(level, id, name, tier, kind, rect, o = {}) {
	rooms.push({ level, id, name, tier, kind, rect: r4(rect), tower: o.tower || "main", holes: (o.holes || []).map(r4), nested: !!o.nested, hub: o.hub || null, vault: o.vault || null, w: o.w || null, note: o.note || "" });
}
const W = { tower: "wing" };

// Footprints each level must tile (checked): level -> list of { tower, rect }
const FOOT = {
	B: [{ tower: "main", rect: r4([-140, -170, 140, 150]) }, { tower: "wing", rect: r4([160, -85, 280, 125]) }],
	G: [{ tower: "main", rect: r4([-140, -170, 140, 150]) }, { tower: "wing", rect: r4([160, -85, 280, 125]) }],
	M: [{ tower: "main", rect: r4([-140, -170, 140, 150]) }, { tower: "wing", rect: r4([160, -85, 280, 125]) }],
	T: [{ tower: "main", rect: r4([-125, -155, 125, 135]) }, { tower: "wing", rect: r4([160, -85, 280, 125]) }],
	R: [{ tower: "main", rect: r4([-90, -120, 90, 100]) }, { tower: "wing", rect: r4([205, -85, 280, 125]) }],
};
const VOIDS = [
	{ levels: ["G", "M", "T", "R"], rect: r4([-38, -40, 38, 52]), name: "Atrium void (landmark): open from the ground to a roof skylight" },
];

// ===================== MAIN TOWER, BASEMENT (B, -24): service ring, stores, the security complex, Vault A =====================
room("B", "b_ring_n", "Service ring north", 1, "IN", [-140, -170, 140, -156], { w: 14 });
room("B", "b_ring_s", "Service ring south", 1, "IN", [-140, 136, 140, 150], { w: 14 });
room("B", "b_ring_w", "Service ring west", 1, "IN", [-140, -156, -126, 136], { w: 14 });
room("B", "b_ring_e", "Service ring east", 1, "IN", [126, -156, 140, 136], { w: 14 });
room("B", "b_stores_w1", "West stores", 1, "IN", [-126, -156, -70, 0]);
room("B", "b_stores_w2", "Laundry and dry stores", 1, "IN", [-126, 0, -70, 136]);
room("B", "b_stores_e1", "East stores", 1, "IN", [70, -156, 126, 0]);
room("B", "b_cellar", "Wine cellar", 1, "IN", [70, 0, 126, 136]);
room("B", "b_gate", "Security checkpoint (basement)", 2, "IN", [-14, -156, 14, -80], { w: 28 });
room("B", "b_camera", "Camera room", 2, "IN", [-70, -156, -14, -80]);
room("B", "b_barracks", "Guard barracks", 2, "IN", [14, -156, 70, -80]);
room("B", "b_muster", "Guard muster hall", 2, "IN", [-70, -80, 70, -20], { hub: "guards" });
room("B", "b_vaulta_ante", "Vault A laser hall", 2, "IN", [-70, -20, -14, 60], { vault: "A" });
room("B", "b_spine", "Security spine", 2, "IN", [-14, -20, 14, 136], { w: 28 });
room("B", "b_armory", "Armoury", 2, "IN", [14, -20, 70, 60]);
room("B", "b_vaulta", "Vault A (bank vault)", 3, "IN", [-70, 60, -14, 136], { vault: "A", note: "terminal" });
room("B", "b_mess", "Guard mess", 2, "IN", [14, 60, 70, 136]);
room("B", "b_tunnel", "Service tunnel to the wing", 1, "IN", [140, 20, 160, 32], { w: 12 });
// wing basement
room("B", "wb_security", "Wing security office", 2, "IN", [160, -85, 280, -55], W);
room("B", "wb_linen", "Linen store", 1, "IN", [160, -55, 215, 5], W);
room("B", "wb_laundry", "Hotel laundry", 1, "IN", [160, 5, 215, 55], W);
room("B", "wb_vaultd", "Vault D (counting room)", 3, "IN", [215, -55, 250, 5], { tower: "wing", vault: "D", note: "terminal" });
room("B", "wb_vaultd_ante", "Vault D counting hall", 2, "IN", [215, 5, 250, 55], { tower: "wing", vault: "D" });
room("B", "wb_boiler", "Boiler corridor", 1, "IN", [250, -55, 280, 55], W);
room("B", "wb_service", "Hotel service hall", 1, "IN", [160, 55, 280, 125], W);

// ===================== MAIN TOWER, GROUND (G, 0): atrium, colonnade ring, themed wings, Vault C =====================
room("G", "g_atrium", "Grand atrium (landmark, pond)", 0, "IN", [-60, -70, 60, 60], { hub: "atrium", holes: [[-38, -40, 38, 52]] });
room("G", "g_ring_n", "Colonnade north", 0, "IN", [-74, -84, 74, -70], { w: 14 });
room("G", "g_ring_s", "Colonnade south", 0, "IN", [-74, 60, 74, 74], { w: 14 });
room("G", "g_ring_w", "Colonnade west", 0, "IN", [-74, -70, -60, 60], { w: 14 });
room("G", "g_ring_e", "Colonnade east", 0, "IN", [60, -70, 74, 60], { w: 14 });
room("G", "g_gallery", "Gallery hall", 0, "IN", [-140, -84, -74, 10], { hub: "gallery" });
room("G", "g_concierge", "Concierge", 0, "IN", [-140, 10, -74, 40]);
room("G", "g_coat", "Cloakroom", 1, "IN", [-140, 40, -74, 74]);
room("G", "g_ballroom", "Ballroom", 0, "IN", [74, -84, 140, 20], { hub: "ballroom" });
room("G", "g_bar", "Bar", 0, "IN", [74, 20, 140, 74], { hub: "bar" });
room("G", "g_dining", "Dining room", 0, "IN", [-140, -170, -60, -84], { hub: "dining" });
room("G", "g_kitchen", "Kitchen", 1, "IN", [-60, -170, 20, -100]);
room("G", "g_pantry", "Pantry and catering prep", 1, "IN", [20, -170, 80, -100]);
room("G", "g_service_n", "Service passage", 1, "IN", [-60, -100, 140, -84], { w: 16 });
room("G", "g_vaultc", "Vault C (cold-storage vault)", 3, "IN", [80, -170, 140, -140], { vault: "C", note: "terminal" });
room("G", "g_vaultc_ante", "Vault C cold room", 2, "IN", [80, -140, 140, -100], { vault: "C" });
room("G", "g_library", "Library lounge", 0, "IN", [-140, 74, -60, 150]);
room("G", "g_lobby", "Grand lobby (arrival)", 0, "IN", [-60, 74, 60, 150], { hub: "lobby" });
room("G", "g_lounge", "Smoking lounge and humidor", 0, "IN", [60, 74, 140, 150]);
// wing ground
room("G", "wg_casino", "Casino floor", 0, "IN", [160, -5, 280, 95], { tower: "wing", hub: "casino" });
room("G", "wg_entry", "Hotel entrance lobby", 0, "IN", [160, 95, 280, 125], W);
room("G", "wg_cage", "Cashier's cage", 1, "IN", [160, -85, 215, -5], W);
room("G", "wg_highroller", "High-roller lounge", 3, "IN", [215, -85, 280, -5], W);

// ===================== MAIN TOWER, MEZZANINE (M, 24): balcony promenade, galleries, security hub, terraces =====================
room("M", "m_balcony", "Atrium balcony promenade", 0, "IN", [-74, -84, 74, 74], { hub: "balcony", holes: [[-38, -40, 38, 52]] });
room("M", "m_gallery", "Gallery loft", 0, "IN", [-125, -84, -74, 74]);
room("M", "m_ball_gal", "Ballroom gallery", 0, "IN", [74, -84, 125, -20]);
room("M", "m_bridge_hall", "Skybridge hall", 0, "IN", [74, -20, 125, 40]);
room("M", "m_bar_loft", "Bar loft", 0, "IN", [74, 40, 125, 74]);
room("M", "m_offices", "Staff offices", 1, "IN", [-125, -155, -40, -84]);
room("M", "m_hub", "Security hub", 2, "IN", [-40, -155, 40, -84]);
room("M", "m_records", "Executive records", 3, "IN", [10, -155, 40, -120], { nested: true });
room("M", "m_catering", "Catering offices", 1, "IN", [40, -155, 125, -84]);
room("M", "m_wine", "Wine terrace lounge", 0, "IN", [-125, 74, -45, 135]);
room("M", "m_stairhall", "Grand stair hall", 0, "IN", [-45, 74, 45, 135]);
room("M", "m_cigar", "Cigar terrace lounge", 0, "IN", [45, 74, 125, 135]);
room("M", "m_ter_n", "Terrace north", 0, "OUT", [-140, -170, 140, -155], { w: 15 });
room("M", "m_ter_s", "Terrace south", 0, "OUT", [-140, 135, 140, 150], { w: 15 });
room("M", "m_ter_w", "Terrace west", 0, "OUT", [-140, -155, -125, 135], { w: 15 });
room("M", "m_ter_e", "Terrace east", 0, "OUT", [125, -155, 140, 135], { w: 15 });
room("M", "m_bridge", "Skybridge (glass, enclosed)", 0, "IN", [140, 26, 160, 38], { w: 12 });
// wing mezzanine
room("M", "wm_lobby", "Hotel lobby", 0, "IN", [160, -15, 280, 60], { tower: "wing", hub: "hotel" });
room("M", "wm_bar", "Sky bar", 0, "IN", [160, 60, 280, 125], { tower: "wing", hub: "skybar" });
room("M", "wm_housekeeping", "Housekeeping", 1, "IN", [160, -85, 280, -15], W);

// ===================== MAIN TOWER, TOP FLOOR (T, 48): terraces, guard ring, penthouse, Vault B =====================
room("T", "t_ter_n", "Upper terrace north", 0, "OUT", [-125, -155, 125, -120], { w: 35 });
room("T", "t_ter_s", "Upper terrace south", 0, "OUT", [-125, 100, 125, 135], { w: 35 });
room("T", "t_ter_w", "Upper terrace west (lawn)", 0, "OUT", [-125, -120, -90, 100], { w: 35 });
room("T", "t_ter_e", "Upper terrace east", 0, "OUT", [90, -120, 125, 100], { w: 35 });
room("T", "t_west", "West guard hall", 2, "IN", [-90, -120, -60, 100], { w: 30 });
room("T", "t_east", "East guard hall", 2, "IN", [60, -120, 90, 100], { w: 30 });
room("T", "t_guard_nw", "North guard post west", 2, "IN", [-60, -120, -30, -60]);
room("T", "t_guard_ne", "North guard post east", 2, "IN", [30, -120, 60, -60]);
room("T", "t_vaultb_ante", "Vault B display hall", 2, "IN", [-30, -100, 30, -60], { vault: "B" });
room("T", "t_vaultb", "Vault B (art vault)", 3, "IN", [-30, -120, 30, -100], { vault: "B", note: "terminal" });
room("T", "t_great", "Penthouse great room (void railing)", 3, "IN", [-60, -60, 60, 70], { holes: [[-38, -40, 38, 52]], w: 22 });
room("T", "t_gallery", "Private gallery", 3, "IN", [-60, 70, 60, 100]);
room("T", "t_panic", "Panic room", 3, "IN", [-85, 38, -65, 62], { nested: true });
room("T", "t_office", "Executive office", 3, "IN", [65, 38, 85, 62], { nested: true });
// wing top floor: suites and the setback terrace (the mezzanine roof)
room("T", "wt_terrace", "Suite terrace", 0, "OUT", [160, -85, 205, 125], { tower: "wing" });
room("T", "wt_arcade", "Suite arcade", 0, "IN", [221, -85, 264, 125], { tower: "wing" });
room("T", "wt_suite1", "Skyline suite", 0, "IN", [205, -85, 221, -15], W);
room("T", "wt_suite2", "Corner suite", 0, "IN", [205, -15, 221, 55], W);
room("T", "wt_suite3", "Garden suite", 0, "IN", [205, 55, 221, 125], W);
room("T", "wt_exec", "Executive suite", 3, "IN", [264, -85, 280, -15], W);
room("T", "wt_suite5", "Moon suite", 0, "IN", [264, -15, 280, 55], W);
room("T", "wt_suite4", "City suite", 0, "IN", [264, 55, 280, 125], W);

// ===================== MAIN TOWER, ROOF (R, 72) and the Sanctum crown (S, 84) =====================
room("R", "r_deck", "Rooftop party deck", 0, "OUT", [-90, -120, 90, 100], { hub: "rooftop", holes: [[-38, -40, 38, 52], [-45, -115, 45, -50], [50, 50, 90, 100], [55, -115, 90, -85]] });
room("R", "r_summit", "Summit lobby (elevator, Executive stair)", 3, "IN", [-45, -115, 45, -50], { w: 30 });
room("R", "r_vaulte_ante", "Vault E observatory hall", 2, "IN", [50, 50, 90, 75], { vault: "E" });
room("R", "r_vaulte", "Vault E (observatory vault)", 3, "IN", [50, 75, 90, 100], { vault: "E", note: "terminal" });
room("R", "r_plant", "Rooftop plant room", 1, "IN", [55, -115, 90, -85]);
room("R", "wr_garden", "Wing roof garden", 0, "OUT", [205, -85, 280, 125], { tower: "wing", holes: [[205, -85, 231, -15]] });
room("R", "wr_plant", "Wing plant room", 1, "IN", [205, -85, 231, -15], W);
room("S", "s_sanctum", "THE SANCTUM", 4, "IN", [-35, -115, 35, -70], { vault: "S", note: "package" });
room("S", "s_foyer", "Sanctum foyer", 4, "IN", [-45, -70, 45, -50]);
room("S", "s_ter_w", "Sanctum terrace west (back door)", 4, "OUT", [-45, -115, -35, -70]);
room("S", "s_ter_e", "Sanctum terrace east (zipline landing)", 4, "OUT", [35, -115, 45, -70]);
room("D", "wd_skydeck", "Sky deck (extraction)", 0, "OUT", [231, -85, 280, -15], W);

// ===================== DOORS: a, b, width, options. Both rooms must share a wall at least that long. =====================
// kind: arch (open), gate (clearance door by the higher tier), vault (vault door), laser, keycard
const doors = [];
const dr = (a, b, width, o = {}) => doors.push({ a, b, width, ...o });
// -- basement
for (const [a, b] of [["b_ring_n", "b_ring_w"], ["b_ring_n", "b_ring_e"], ["b_ring_s", "b_ring_w"], ["b_ring_s", "b_ring_e"]]) dr(a, b, 14, { arch: true });
dr("b_stores_w1", "b_ring_w", 10); dr("b_stores_w1", "b_ring_n", 10); dr("b_stores_w2", "b_ring_w", 10); dr("b_stores_w2", "b_ring_s", 10); dr("b_stores_w1", "b_stores_w2", 8);
dr("b_stores_e1", "b_ring_e", 10); dr("b_stores_e1", "b_ring_n", 10); dr("b_cellar", "b_ring_e", 10); dr("b_cellar", "b_ring_s", 10); dr("b_stores_e1", "b_cellar", 8);
dr("b_gate", "b_ring_n", 10, { gate: 2 }); dr("b_gate", "b_muster", 12); dr("b_camera", "b_gate", 8); dr("b_barracks", "b_gate", 8);
dr("b_camera", "b_muster", 8); dr("b_barracks", "b_muster", 8); dr("b_muster", "b_vaulta_ante", 8, { laser: true }); dr("b_muster", "b_spine", 12); dr("b_muster", "b_armory", 8);
dr("b_spine", "b_vaulta_ante", 8, { gate: 2 }); dr("b_spine", "b_armory", 8); dr("b_spine", "b_mess", 8); dr("b_vaulta_ante", "b_vaulta", 8, { vault: true });
dr("b_spine", "b_ring_s", 10, { gate: 2 }); dr("b_mess", "b_ring_s", 8, { gate: 2 }); dr("b_ring_e", "b_tunnel", 8); dr("b_tunnel", "wb_laundry", 8);
dr("wb_security", "wb_linen", 8, { gate: 2 }); dr("wb_security", "wb_boiler", 8, { gate: 2 }); dr("wb_linen", "wb_laundry", 8); dr("wb_laundry", "wb_service", 10);
dr("wb_laundry", "wb_vaultd_ante", 8, { gate: 2 }); dr("wb_vaultd_ante", "wb_boiler", 8, { gate: 2 }); dr("wb_vaultd_ante", "wb_service", 8, { gate: 2 }); dr("wb_vaultd_ante", "wb_vaultd", 8, { vault: true });
dr("wb_boiler", "wb_service", 10);
// -- ground
for (const k of ["g_ring_n", "g_ring_s", "g_ring_w", "g_ring_e"]) dr("g_atrium", k, 50, { arch: true });
for (const [a, b] of [["g_ring_n", "g_ring_w"], ["g_ring_n", "g_ring_e"], ["g_ring_s", "g_ring_w"], ["g_ring_s", "g_ring_e"]]) dr(a, b, 14, { arch: true });
dr("g_ring_w", "g_gallery", 24, { arch: true }); dr("g_ring_w", "g_concierge", 14); dr("g_gallery", "g_concierge", 14); dr("g_concierge", "g_coat", 10, { gate: 1 }); dr("g_coat", "g_library", 10, { gate: 1 });
dr("g_ring_e", "g_ballroom", 30, { arch: true }); dr("g_ring_e", "g_bar", 20, { arch: true }); dr("g_ballroom", "g_bar", 16, { arch: true });
dr("g_gallery", "g_dining", 20, { arch: true }); dr("g_ring_n", "g_service_n", 10, { gate: 1 }); dr("g_ballroom", "g_service_n", 10, { gate: 1 });
dr("g_dining", "g_kitchen", 10, { gate: 1 }); dr("g_kitchen", "g_service_n", 12); dr("g_pantry", "g_service_n", 12); dr("g_kitchen", "g_pantry", 10);
dr("g_pantry", "g_vaultc_ante", 8, { gate: 2 }); dr("g_service_n", "g_vaultc_ante", 8, { gate: 2, laser: true }); dr("g_vaultc_ante", "g_vaultc", 8, { vault: true });
dr("g_ring_s", "g_lobby", 50, { arch: true }); dr("g_lobby", "g_library", 16, { arch: true }); dr("g_lobby", "g_lounge", 16, { arch: true });
dr("g_ring_s", "g_library", 14); dr("g_ring_s", "g_lounge", 14);
dr("wg_casino", "wg_entry", 40, { arch: true }); dr("wg_casino", "wg_cage", 12, { gate: 1 }); dr("wg_casino", "wg_highroller", 14, { gate: 3 }); dr("wg_cage", "wg_highroller", 8, { gate: 3 });
// -- mezzanine
dr("m_balcony", "m_gallery", 24, { arch: true }); dr("m_balcony", "m_ball_gal", 20, { arch: true }); dr("m_balcony", "m_bridge_hall", 24, { arch: true }); dr("m_balcony", "m_bar_loft", 20, { arch: true });
dr("m_balcony", "m_hub", 12, { gate: 2 }); dr("m_balcony", "m_offices", 10, { gate: 1 }); dr("m_balcony", "m_catering", 10, { gate: 1 });
dr("m_balcony", "m_stairhall", 40, { arch: true }); dr("m_balcony", "m_wine", 14); dr("m_balcony", "m_cigar", 14);
dr("m_gallery", "m_offices", 10, { gate: 1 }); dr("m_ball_gal", "m_catering", 10, { gate: 1 }); dr("m_gallery", "m_wine", 14); dr("m_bar_loft", "m_cigar", 14);
dr("m_hub", "m_offices", 8, { gate: 2 }); dr("m_hub", "m_catering", 8, { gate: 2 });
dr("m_gallery", "m_ter_w", 14); dr("m_wine", "m_ter_w", 12); dr("m_wine", "m_ter_s", 12); dr("m_cigar", "m_ter_s", 12); dr("m_cigar", "m_ter_e", 12); dr("m_bridge_hall", "m_ter_e", 14);
dr("m_ter_n", "m_ter_w", 15, { arch: true }); dr("m_ter_n", "m_ter_e", 15, { arch: true }); dr("m_ter_s", "m_ter_w", 15, { arch: true }); dr("m_ter_s", "m_ter_e", 15, { arch: true });
dr("m_offices", "m_ter_n", 10, { gate: 1 }); dr("m_catering", "m_ter_n", 10, { gate: 1 });
dr("m_ter_e", "m_bridge", 12); dr("m_bridge", "wm_lobby", 12);
dr("wm_lobby", "wm_bar", 30, { arch: true }); dr("wm_lobby", "wm_housekeeping", 12, { gate: 1 });
// -- top floor
for (const t of ["t_ter_w", "t_ter_e"]) { dr("t_ter_n", t, 35, { arch: true }); dr("t_ter_s", t, 35, { arch: true }); }
dr("t_ter_w", "t_west", 12, { gate: 2 }); dr("t_ter_e", "t_east", 12, { gate: 2 }); dr("t_ter_n", "t_guard_nw", 10, { gate: 2 }); dr("t_ter_n", "t_guard_ne", 10, { gate: 2 });
dr("t_ter_s", "t_gallery", 10, { gate: 3 });
dr("t_guard_nw", "t_west", 10); dr("t_guard_ne", "t_east", 10); dr("t_guard_nw", "t_vaultb_ante", 8); dr("t_guard_ne", "t_vaultb_ante", 8);
dr("t_vaultb_ante", "t_great", 12, { gate: 3 }); dr("t_guard_nw", "t_great", 10, { gate: 3 }); dr("t_guard_ne", "t_great", 10, { gate: 3 });
dr("t_west", "t_great", 12, { gate: 3 }); dr("t_east", "t_great", 12, { gate: 3 }); dr("t_gallery", "t_great", 14, { arch: true });
dr("t_gallery", "t_west", 8, { gate: 3 }); dr("t_gallery", "t_east", 8, { gate: 3 }); dr("t_vaultb_ante", "t_vaultb", 8, { vault: true });
dr("t_west", "t_panic", 8, { gate: 3, edge: "e" }); dr("t_east", "t_office", 8, { gate: 3, edge: "w" });
dr("wt_terrace", "wt_suite1", 10); dr("wt_terrace", "wt_suite2", 10); dr("wt_terrace", "wt_suite3", 10);
for (const s of ["wt_suite1", "wt_suite2", "wt_suite3"]) dr("wt_arcade", s, 8);
dr("wt_arcade", "wt_exec", 8, { gate: 3 }); dr("wt_exec", "wt_suite5", 8, { gate: 3 }); dr("wt_arcade", "wt_suite5", 8); dr("wt_arcade", "wt_suite4", 8);
// -- roof and crown
dr("r_deck", "r_plant", 8, { gate: 1, edge: "w" }); dr("r_deck", "r_summit", 12, { gate: 3, edge: "s" });
dr("r_deck", "r_vaulte_ante", 8, { gate: 2, edge: "w" }); dr("r_deck", "r_vaulte_ante", 8, { gate: 2, edge: "n" }); dr("r_vaulte_ante", "r_vaulte", 8, { vault: true });
dr("wr_garden", "wr_plant", 8, { gate: 1, edge: "s" });
dr("s_foyer", "s_sanctum", 10, { vault: true, cost: 10, note: "front Package door: hack for 10 intel, or the Tier 4 keycard" });
dr("s_ter_w", "s_sanctum", 10, { vault: true, keycardOnly: true, note: "back Package door: the Tier 4 keycard only" });
dr("s_foyer", "s_ter_w", 8, { arch: true }); dr("s_foyer", "s_ter_e", 8, { arch: true });

// ===================== VERTICAL CONNECTORS =====================
// id, kind, from (level, rect inside a room there), to (level, landing point inside a room there), width, notes
const conns = [];
const vc = (id, kind, fromLevel, fromRect, toLevel, landing, width, tier, o = {}) => conns.push({ id, kind, fromLevel, from: r4(fromRect), toLevel, landing, width, tier, ...o });
// public: grand stair, two escalators, four corner switchbacks (ground to mezzanine)
vc("grandstair", "Grand stair", "G", [-12, 90, 12, 140], "M", [0, 100], 24, 0, { note: "double-width, in the lobby; arrives in the stair hall" });
vc("escalator_w", "Escalator ramp", "G", [-72, 10, -62, 58], "M", [-68, -10], 12, 0, { note: "up along the west colonnade" });
vc("escalator_e", "Escalator ramp", "G", [62, -58, 72, -10], "M", [68, 10], 12, 0, { note: "up along the east colonnade" });
vc("corner_nw", "Switchback stair", "G", [-86, -80, -74, -50], "M", [-100, -40], 12, 0, { note: "gallery hall to the gallery loft" });
vc("corner_ne", "Switchback stair", "G", [74, -80, 86, -50], "M", [100, -50], 12, 0, { note: "ballroom to its gallery" });
vc("corner_sw", "Switchback stair", "G", [-86, 118, -74, 148], "M", [-100, 110], 12, 0, { note: "library to the wine terrace lounge" });
vc("corner_se", "Switchback stair", "G", [74, 118, 86, 148], "M", [100, 110], 12, 0, { note: "lounge to the cigar terrace lounge" });
// mezzanine to top: public roof-terrace stairs; the guard stairs are Security tier
vc("terrace_stair_w", "Switchback stair", "M", [-138, -20, -126, 10], "T", [-110, 0], 12, 0, { note: "terrace to the upper terrace (west lawn)" });
vc("terrace_stair_e", "Switchback stair", "M", [126, -60, 138, -30], "T", [110, -40], 12, 0, { note: "terrace to the upper terrace (east)" });
vc("roof_stair", "Roof stair", "T", [-124, 40, -112, 70], "R", [-80, 55], 12, 0, { note: "public stair from the upper west terrace to the rooftop party" });
// staff service stairs, narrow, down to the basement and up to the mezzanine
vc("staff_b_g", "Staff stair", "B", [100, -110, 114, -80], "G", [107, -92], 6, 1, { note: "east stores to the service passage" });
vc("staff_g_m", "Staff stair", "G", [-56, -98, -44, -86], "M", [-50, -110], 6, 1, { note: "service passage to the staff offices" });
vc("staff_b_g_s", "Staff stair", "B", [-110, 90, -96, 120], "G", [-104, 55], 6, 1, { note: "laundry to the cloakroom" });
vc("staff_g_m_s", "Staff stair", "G", [-136, 44, -124, 70], "M", [-130, 40], 6, 1, { note: "cloakroom to the west terrace" });
vc("wing_staff_b_g", "Staff stair", "B", [165, 60, 179, 90], "G", [172, 0], 6, 1, { note: "hotel service hall to the cage" });
vc("wing_staff_g_m", "Staff stair", "G", [162, -40, 176, -10], "M", [170, -50], 6, 1, { note: "cage to housekeeping" });
// security: guard stairs between the security zones, then to the top floor
vc("guard_b_g", "Guard stair", "B", [-12, -150, 12, -125], "G", [0, -92], 6, 2, { note: "basement checkpoint up to the service passage (gated)" });
vc("guard_m_t", "Guard stair", "M", [-30, -145, -18, -115], "T", [-45, -100], 6, 2, { note: "security hub to the north guard post" });
vc("plant_stair", "Staff stair", "T", [62, -110, 74, -90], "R", [72, -100], 6, 1, { note: "east guard hall up to the rooftop plant room (the plant room's second way in)" });
vc("wing_plant_stair", "Staff stair", "T", [222, -80, 234, -50], "R", [225, -60], 6, 1, { note: "suite arcade up to the wing plant room" });
vc("wing_guard_stair", "Guard stair", "B", [240, -82, 246, -58], "G", [200, -70], 6, 2, { note: "wing security office up to the cashier's cage (the wing basement's third way in)" });
vc("guard_t_r", "Guard stair", "T", [64, 60, 76, 90], "R", [70, 40], 6, 2, { note: "east guard hall to the rooftop party" });
// glass elevators: atrium (main), two in the wing; the Sanctum elevator is separate
vc("elev_atrium_w_gm", "Glass elevator", "G", [-60, -30, -46, -16], "M", [-53, -23], 6, 1, { note: "atrium west shaft, ground to mezzanine" });
vc("elev_atrium_w_mt", "Glass elevator", "M", [-60, -30, -46, -16], "T", [-75, 0], 6, 1, { note: "atrium west shaft, mezzanine to the top floor: arrives in the west guard hall (Security tier on arrival)" });
vc("elev_atrium_e_gm", "Glass elevator", "G", [46, 20, 60, 34], "M", [53, 27], 6, 1, { note: "atrium east shaft, ground to mezzanine" });
vc("elev_atrium_e_mr", "Glass elevator", "M", [46, 20, 60, 34], "R", [75, 10], 6, 1, { note: "atrium east shaft, mezzanine to the rooftop party deck (passes the top floor without a stop)" });
vc("elev_wing_a_gm", "Glass elevator", "G", [250, 70, 262, 82], "M", [256, 76], 6, 1, { note: "casino to the sky bar" });
vc("elev_wing_a_mt", "Glass elevator", "M", [250, 70, 262, 82], "T", [250, 80], 6, 1, { note: "sky bar to the suite arcade" });
vc("elev_wing_b_gm", "Glass elevator", "G", [168, 100, 180, 112], "M", [174, 106], 6, 1, { note: "entrance lobby to the sky bar" });
vc("elev_wing_b_mt", "Glass elevator", "M", [168, 100, 180, 112], "T", [174, 106], 6, 1, { note: "sky bar to the suite terrace" });
vc("elev_wing_b_tr", "Glass elevator", "T", [168, 100, 180, 112], "R", [250, 100], 6, 1, { note: "suite terrace to the roof garden" });
vc("wing_grand_stair", "Grand stair", "G", [176, 40, 200, 90], "M", [180, 10], 24, 0, { note: "casino floor up to the hotel lobby" });
vc("wing_stair_m_t", "Switchback stair", "M", [162, 95, 174, 125], "T", [182, 100], 12, 0, { note: "sky bar to the suite terrace" });
vc("wing_stair_t_r", "Roof stair", "T", [235, 20, 247, 50], "R", [250, 45], 12, 0, { note: "suite arcade to the roof garden" });
vc("wing_deck_stair", "Stair", "R", [236, -20, 248, -2], "D", [250, -40], 6, 0, { note: "roof garden to the sky deck (extraction)" });
// The Sanctum: three routes in (locked until all 3 terminals are hacked, except the stair door which is a clearance door)
vc("sanctum_elevator", "Sanctum elevator", "T", [46, -58, 58, -46], "R", [40, -90], 12, 3, { note: "penthouse great room up to the summit lobby; only runs once all 3 terminals are hacked", locked: true });
vc("sanctum_stair", "Executive stair", "R", [-25, -75, -13, -55], "S", [-20, -60], 6, 4, { note: "summit lobby up to the Sanctum foyer; a Tier 4 clearance door at the head of the stair (hack 10, keycard, or a warden or curator disguise)" });
vc("sanctum_lift_top", "Sanctum elevator (upper)", "R", [30, -95, 42, -83], "S", [30, -60], 6, 4, { note: "second leg of the elevator, to the foyer (Tier 4 door on arrival)", locked: true });
vc("summit_ladder", "Service ladder", "R", [-60, -110, -48, -98], "S", [-40, -100], 6, 0, { note: "up the crown's west wall from the roof deck to the west terrace: Cover-breaking, trespass on arrival, and the only way to the back Package door" });
// Tunnel, bridge and exposed links are rooms (m_bridge, b_tunnel); ziplines below.
const ziplines = [
	{ id: "zip_sky", from: { level: "D", x: 235, z: -45 }, to: { level: "S", x: 40, z: -95 }, note: "wing sky deck down to the Sanctum east terrace: the third route into the Sanctum (Cover-breaking)" },
	{ id: "zip_roof", from: { level: "R", x: -85, z: -100 }, to: { level: "T", x: -118, z: -100 }, note: "roof party deck down to the upper west terrace (Cover-breaking)" },
];
// 6 vent pairs, one into each vault wing and the security hub, each from a room outside the wing
const vents = [
	{ id: "vent_a", from: "b_stores_w1", to: "b_vaulta" }, { id: "vent_b", from: "t_ter_n", to: "t_vaultb" },
	{ id: "vent_c", from: "g_pantry", to: "g_vaultc" }, { id: "vent_d", from: "wb_linen", to: "wb_vaultd" },
	{ id: "vent_e", from: "r_deck", to: "r_vaulte" }, { id: "vent_hub", from: "m_catering", to: "m_hub" },
];
// prop-triggered secret exits (inside the room, out to a neighbour): the single-door restricted rooms
const secretExits = [
	{ id: "sx_a", room: "b_vaulta", to: "b_stores_w2" }, { id: "sx_b", room: "t_vaultb", to: "t_ter_n" }, { id: "sx_c", room: "g_vaultc", to: "g_pantry" },
	{ id: "sx_d", room: "wb_vaultd", to: "wb_linen" }, { id: "sx_e", room: "r_vaulte", to: "r_deck" }, { id: "sx_panic", room: "t_panic", to: "t_ter_w" },
	{ id: "sx_office", room: "t_office", to: "t_ter_e" }, { id: "sx_records", room: "m_records", to: "m_catering" },
];

// ===================== MARKERS =====================
const vaults = [
	{ id: "A", level: "B", room: "b_vaulta", x: -42, z: 100 }, { id: "B", level: "T", room: "t_vaultb", x: 0, z: -110 },
	{ id: "C", level: "G", room: "g_vaultc", x: 110, z: -155 }, { id: "D", level: "B", room: "wb_vaultd", x: 232, z: -25 },
	{ id: "E", level: "R", room: "r_vaulte", x: 70, z: 88 },
];
const printers = [
	{ id: "P1", level: "R", room: "r_plant", x: 72, z: -100 }, { id: "P2", level: "R", room: "r_vaulte_ante", x: 70, z: 62 },
	{ id: "P3", level: "R", room: "r_summit", x: 40, z: -85 }, { id: "P4", level: "T", room: "t_gallery", x: 0, z: 85 },
	{ id: "P5", level: "T", room: "t_guard_ne", x: 45, z: -90 },
];
const tier4Npcs = [
	{ role: "Warden", rooms: ["s_foyer", "s_ter_w", "s_ter_e", "r_summit"], note: "stays on the summit" },
	{ role: "Curator", rooms: ["t_great", "t_gallery", "r_summit", "r_deck"], note: "walks the penthouse, the roof and the summit lobby" },
];
const doorCosts = { Staff: 3, Security: 6, Executive: 8, "Vault core doors": 8, "Tier 4 stair head": 8, "Tier 4 elevator arrival": 8, "Tier 4 terrace doors": 6, "Package doors": 10, "Keycard printer (20 s, single-use card)": 10 };
const sanctum = { level: "S", room: "s_sanctum", x: 0, z: -92 };
const extraction = [
	{ id: "Helipad", level: "R", x: -70, z: 45 }, { id: "SkyDeck", level: "D", x: 255, z: -50 }, { id: "TerraceLawn", level: "T", x: -108, z: 20 },
];
const insertion = [
	{ id: 1, level: "G", x: -45, z: 138 }, { id: 2, level: "G", x: 0, z: 92 }, { id: 3, level: "G", x: 45, z: 138 },
	{ id: 4, level: "G", x: 100, z: 110 }, { id: 5, level: "G", x: -100, z: 110 }, { id: 6, level: "G", x: 220, z: 110 },
	{ id: 7, level: "M", x: -132, z: -100 }, { id: 8, level: "M", x: -132, z: 60 }, { id: 9, level: "M", x: 132, z: -100 },
	{ id: 10, level: "M", x: 132, z: 60 }, { id: 11, level: "M", x: 0, z: 143 }, { id: 12, level: "M", x: 0, z: -163 },
];

// Hubs: where the crowd gathers, with the share of the Guest crowd (sums to 1) used for the capacity estimate
const hubShare = { atrium: 0.14, ballroom: 0.12, bar: 0.07, dining: 0.06, casino: 0.12, rooftop: 0.1, lobby: 0.05, gallery: 0.05, balcony: 0.08, hotel: 0.07, skybar: 0.07, guards: 0.0, other: 0.07 };

module.exports = { printers, tier4Npcs, doorCosts, LEVELS, rooms, FOOT, VOIDS, doors, conns, ziplines, vents, secretExits, vaults, sanctum, extraction, insertion, hubShare };
