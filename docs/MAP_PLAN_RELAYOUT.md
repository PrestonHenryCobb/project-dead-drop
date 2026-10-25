# Gala re-layout: the layout plan (2026-10-25)

For review. This is the plan the approved brief (`MAP_BRIEF_RELAYOUT.md`) asked for. Nothing is built: it is data in
`tools/relayout-plan-data.cjs`, checked and drawn by `node tools/relayout-plan.cjs`, which writes the floor plans and the
full tables to `docs/plans/relayout/`. The plan is at **zone** level (102 rooms). The generator splits big rooms into the
detail rooms (restrooms, props, nested rooms) when it is built.

**The script checks the plan, and all checks pass:** every floor tiles with no overlaps or gaps; every one of 150 doors
sits on a real shared wall at least as long as the door; Guests, Staff, Security and Executives can each reach every room
their clearance allows; every vault has 3 independent routes in; no Tier 1+ room has fewer than 2 entrances (vault wings
excepted).

## 1. The idea in one paragraph
The **grand atrium** stays the landmark: a void with a pond that you can see from every wing, wrapped on the ground and
mezzanine by a **14-wide colonnade ring** that links four themed wings: **Gallery**, **Ballroom and Bar** (the crowd
hubs), **Dining and kitchen**, and **Library, lobby and lounge**. Behind the public rings sit the Staff areas, then
Security, then the Executive penthouse: the **layered security zones** of Diamond Spire. Every wing has two doors onto the
ring and a Staff link behind it, so there are loops and no dead ends. The **five vaults** sit in five different zones, and
**The Sanctum** crowns the tower, reached by three routes.

## 2. What changes, and what it fixes
| Problem you reported | What the layout does |
|---|---|
| Hard to navigate | One landmark (the atrium, 76 x 92 void on four floors), one colour and look per wing, a ring corridor on the ground and mezzanine, and the same ring pattern at every level (the guard ring on the top floor is the same shape). |
| Awkward vertical routes | A deliberate mix: 1 grand stair, 2 escalator ramps in the colonnade, 4 corner switchbacks and 3 more switchbacks and roof stairs (public); 8 narrow Staff stairs; 4 guard stairs (Security); 4 glass elevators plus the Sanctum elevator; roof stairs; hidden routes. 38 connectors in all. |
| NPC jams and dead ends | Public portals average 20 studs (5 lanes). Only 4 rooms have a single way in (a hotel suite, the sky deck, two Sanctum landings, all deliberate). The ring gives every wing two entrances. |
| Same-looking rooms | Each room has one purpose and a tier colour; wings are themed (see section 4). |

## 3. Levels and floor plans
Heights: basement -24, ground 0, mezzanine 24, top floor 48, roof 72, **Sanctum crown 84**, wing sky deck 96. Same
footprints as today: main tower 280 x 320, wing 120 x 210, with the skybridge (mezzanine) and the service tunnel
(basement) between them. Open the SVGs in a browser; each has a legend.

| Level | Plan | What is on it |
|---|---|---|
| Basement | [plan-B.svg](plans/relayout/plan-B.svg) | Staff service ring (14), four store rooms, the **security complex** (checkpoint, camera room, barracks, muster hall, spine, armoury, mess), **Vault A** (bank vault behind a laser hall); in the wing, **Vault D** (counting room), laundry, boiler, hotel service hall. |
| Ground | [plan-G.svg](plans/relayout/plan-G.svg) | Atrium and the four-piece colonnade; Gallery hall, concierge, cloakroom (west); Ballroom, Bar (east); Dining room, kitchen, pantry, service passage and **Vault C** (north, behind the kitchen chain); Library lounge, Grand lobby (the arrival), Smoking lounge (south); wing: casino floor, entrance lobby, cashier's cage, high-roller lounge. |
| Mezzanine | [plan-M.svg](plans/relayout/plan-M.svg) | Balcony promenade round the void, gallery loft, ballroom gallery, skybridge hall, bar loft, Staff offices, **security hub** (records nested inside), catering offices, wine terrace, grand stair hall, cigar terrace; the outdoor terrace ring; the skybridge; wing: hotel lobby, sky bar, housekeeping. |
| Top floor | [plan-T.svg](plans/relayout/plan-T.svg) | Four **upper terraces** (public, outdoor, the west one is the extraction lawn); the **guard ring** (west and east halls, two north posts); the **penthouse great room** round the void; Vault B display hall and **Vault B** (art vault); private gallery; nested panic room and office; wing: suite arcade, six suites, the suite terrace. |
| Roof and crown | [plan-R.svg](plans/relayout/plan-R.svg) | The **rooftop party deck** (the biggest hub, with the helipad), plant room, **Vault E** (observatory vault), the **summit lobby**; above it at 84 the **Sanctum**, its foyer and two terraces; the wing roof garden, plant room and the **sky deck** at 96. |

The full room list (every room's tier, kind, area, width and notes) is generated in
[plan-report.md](plans/relayout/plan-report.md).

## 4. Wing themes (colour and look, so rooms are never alike)
Gallery wing: cool marble and picture lights. Ballroom wing: gold and mirrors. Dining and kitchen: warm wood and steel.
Library and lounge: green leather and smoke. Casino: red felt and neon. Hotel: cream and walnut. Security: cold steel and
cyan strips. Executive: deep walnut and brass. (Art direction stays Gala Art Deco; tier colours and the cyan clearance
cues from the art pass are kept.)

## 5. The route graph
**Horizontal:** every public wing joins the ring at two points and its neighbour through a Staff or service link; the
service passage (ground north) and the service ring (basement) are Staff loops that run behind the public layer; the
skybridge (mezzanine, 12 wide) and the tunnel (basement, 12 wide) join the towers, and the roof party deck and the two
ziplines give open-air ones.

**Vertical (38 connectors, from `plan-report.md`):**
| Kind | Count | Where | Tier |
|---|---|---|---|
| Grand stair (24 wide) | 2 | Lobby to the stair hall; the wing's casino to its hotel lobby | Public |
| Escalator ramp (12) | 2 | Up each side of the colonnade | Public |
| Switchback stair (12) | 7 | Four ground corners, two terrace stairs, the wing's sky bar to its suites | Public |
| Roof stairs | 3 | Upper west terrace to the roof party; the wing's arcade to its roof garden; garden to the sky deck | Public |
| Staff stairs (6) | 8 | Basement to ground to mezzanine, both towers, plus the two plant rooms | Staff |
| Guard stairs (6) | 4 | Security basement up to the service passage; security hub to the top floor; guard hall to the roof; wing security up to the cage | Security |
| Glass elevators | 9 hops | Atrium west (G, M, T), atrium east (G, M, R), wing A (G, M, T), wing B (G, M, T, R) | Public (arrive in the tier of the stop) |
| The Sanctum | 3 routes | Elevator (locked until all 3 terminals are hacked), Executive stair (Tier 3 clearance door), zipline from the sky deck | Executive |

**Ziplines (2):** sky deck down to the Sanctum east terrace (the third way into the Sanctum); roof party deck down to the
upper west terrace. **Vents (6 pairs):** one into each vault core and the security hub. **Secret exits (8):** one for each
vault core, the panic room, the executive office and the records room (all single-door rooms); they open outward only.

**Independent routes in, counted from all 12 insertion points (maximum flow over doors, stairs, vents, secret exits):**
| Objective | On foot to the antechamber or foyer | All routes in |
|---|---|---|
| Vault A, B, C, D, E | 2, 3, 2, 3, 2 | 3 each |
| The Sanctum (foyer) | 2 after the unlock | 3 |

**Clearance reach (from the grand lobby):** Guests reach all 44 public rooms; Staff 67; Security 85; Executives 101 (every
room but the Sanctum, which needs the unlock). No tier is cut off from anything it should reach.

## 6. Vault and terminal positions, and the Sanctum
| Vault | Level | Zone | Terminal at | Notes |
|---|---|---|---|---|
| A | Basement | Security complex, south-west | (-42, 100) | Bank vault behind a laser hall; doors to the muster hall (laser) and the spine. |
| B | Top floor | Penthouse north | (0, -110) | Art vault behind a display hall with three doors (two guard posts, the great room). |
| C | Ground | North-east, behind the kitchen chain | (110, -155) | Cold room doors from the pantry and the service passage (laser). |
| D | Basement, wing | Counting room | (232, -25) | Counting hall with three doors (laundry, boiler, service hall). |
| E | Roof | South-east of the party deck | (70, 88) | Observatory vault with two doors onto the deck. |
**The Sanctum** (Package at (0, -92), height 84): a Tier 3 vault-class room, foyer south, two terraces (the east one is the
zipline landing). Locked until all 3 active terminals are hacked. Vault-to-vault spacing is 128 to 301 studs; nearest
pair is B and C at 128. Walking from the Sanctum, the Helipad is 170 studs, the Terrace Lawn 331, the Sky Deck far longer,
all over the 120 minimum. **Extraction sites:** Helipad (roof west deck), Sky Deck (wing, 96), Terrace Lawn (top-floor west).

## 7. NPC capacity: what the plan says about 200 to 500 NPCs
All figures are estimates until measured in Studio (generated in `plan-report.md`).
- **Space is not the limit.** The plan has about 479,000 studs² of floor. Comfortable capacity is about 6,500 NPCs, and a
  500-strong crowd uses 6% of public capacity, 12% of Staff, 16% of Security and 30% of Executive.
- **Flow is not the limit either.** The 55 public portals could pass about 760 NPCs a second; 500 NPCs make about 68
  crossings a second (9%). The stair links are also well below capacity (ground to mezzanine alone: 75 a second public).
- **The crowd would look sparse.** With the Guests spread by hub share, the hubs hold about 0.2 to 0.6 Guests per 100
  studs² at 200 to 500 NPCs (the ballroom, 6,900 studs², would hold roughly 15 to 36 Guests); busy looks like 2 to 3 per 100.
  Adding NPCs alone will not fix it; the crowd has to be **concentrated**. This is the main design input to the NPC rework:
  **crowd clusters**: authored groups of 6 to 12 NPCs at the bar front, the dance floor, the gambling tables, the gallery
  pieces and the roof party, each about 25 studs across (about 2 per 100 studs²), with the rest of the crowd in motion
  between them. 12 to 16 clusters hold 100 to 180 Guests and make the hubs feel full at 300 to 400 NPCs.
- **Cost is the limit.** Today's tick measures 12.6 to 17.3 ms for 200 NPCs (0.06 to 0.09 ms each), so 400 NPCs would take
  25 to 35 ms a tick, too much on a mid-range PC. The rework's budget targets (to be measured): near NPCs full rate, mid
  NPCs half, far NPCs a quarter, and sleeping NPCs (no player within 150 studs, nothing happening) near zero, which should
  bring 400 NPCs to about today's cost. Client cost today is 0.6 ms a frame; 400 would be about 1.3 ms.

## 8. How it gets built (so the first build is right)
1. You review this plan (floor plans and tables). Change anything; I update the data and the checks rerun in seconds.
2. A new generator layout (`Layout.luau` for the new plan) with lane-authored routes (the NPC rework, section 7 of the
   brief), sub-rooms from the zones, and the self-check extended to the new rules (5 vaults, terminals, Sanctum, routes).
3. NPC rework: authored routes, capacity-aware doors, crowd clusters and tiered updates; measured against the numbers above.
4. Vault terminals, server-wide progress and the Sanctum unlock in the match steps (10 to 12); this replaces the intel unlock.
5. Art pass re-applied by Codex (generator-driven art is repeatable; sculptures and furniture are re-placed).

## 9. Decisions to confirm (my defaults are in the plan)
- **The Sanctum's tier:** Tier 3 plus a vault gate (not a new Tier 4), so Executive disguises can enter once it is
  unlocked, and an Executive NPC never wanders in. Confirm, or ask for a Tier 4 above Executives.
- **Do NPCs use elevators?** The plan lets NPCs use stairs and ramps only; elevators are for players, to avoid NPC queues
  at the shafts. Confirm, or allow Staff NPCs to ride them.
- **The Package room has one vault door**, and the foyer outside has three routes in. Confirm that "several routes" means
  to the Sanctum area, not to the Package room itself.
- **Four single-entrance rooms** (a hotel suite, the sky deck, two Sanctum landings). Tell me if any should get a second
  door.
- **The sky deck as extraction is far (887 studs) from the Sanctum on foot.** Close, or fine as the long route?
- **The 5 vault rooms' look:** the old themes (bank, art, cold storage, counting room) carry over; Vault E is new
  (an observatory with a glass dome). Anything else for E?
