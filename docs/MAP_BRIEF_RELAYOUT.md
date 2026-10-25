# Gala re-layout and NPC rework: brief (interview 2026-10-25)

Status: **interview complete, awaiting approval; nothing built.** The owner asked for a re-layout of the Gala with the NPC system reworked
to fit it, and asked to be grilled in detail first so the first build is as polished as possible. Answers are recorded
here as they are given. The generator is not touched until the owner approves this brief (the usual process: brief,
questions, approval, build, screenshots).

## Decided by the owner
| Topic | Decision |
|---|---|
| Scope | A **re-layout of the Gala**: same setting and art direction, rooms, floors and routes rearranged. Not a second map. The NPC system is reworked to fit it. |
| Source | The owner's answers plus reference maps from **Deceive Inc.** and **Entry Point**. Inspiration only (project IP rule): no copied layouts, names, art or assets. |
| Take from the references | **Layered security zones** (public social area wrapped around staff and guard areas, wrapped around the vault areas), **several routes per objective** (a loud, a quiet and a disguise route), and **readable rooms** (one clear purpose and look per room). Not chosen: a smaller, denser scale. |
| Problems to fix | Hard to navigate; awkward vertical routes (stairs, ramps, atrium); NPC jams in corridors and doorways, and dead ends. Long walks were **not** flagged. |
| Navigation aids | A **central landmark** (the atrium) seen from many places; **themed wings** (own colour and look); a **main loop corridor** on each floor with branches; **sight lines** to the next area (windows, open galleries). |
| Vertical routes | **A mix of everything**: grand public stairs, many small stairs, ramps and escalator-style slopes, glass elevators, narrow Staff stairs and hidden Security and Executive routes, so players and NPCs have varied paths. |
| Levels | By the design (I propose). |
| NPC goals | No floating or clipping; believable routes; crowd feel (busy hubs, quiet corners, no empty rooms, no jams); better performance; and **more than 200 NPCs, planned for in the map and the budget**. |
| NPC count | "Whatever fits": the highest count that stays smooth on a mid-range PC, measured. The layout leaves room for it (wide hubs, loops, no long single-file corridors). |
| Elevators and secret exits | By the design: as many as the layout needs for route variety (both already approved in principle on 2026-10-25). |
| Reference maps | **Diamond Spire** (Deceive Inc.) and **Entry Point** maps. |
| Towers and map size | **Two towers, same size**: the Gala and the hotel/casino wing, about 520 x 520 studs, similar part budget (about 10k), re-laid out inside. |
| Vault spots | **One per zone**: the 5 vault rooms are as spread out as possible across the zones (basement, ground west, top floor, the wing's basement, and one near the summit approach); each keeps at least 3 routes out and is far from extraction. Exact rooms are proposed in the layout plan. |
| The Sanctum access | By the design (I propose, with at least 3 routes in). |
| The Package | **Inside The Sanctum.** Picking it up starts Phase 3 (carrier ping, extraction) as now. |
| Crowd hubs | **Ballroom and atrium**, **bar and casino floor**, **rooftop party**. Galleries and the lobby are ordinary busy rooms. |
| Route widths | **Mixed, 8 to 14 studs**: wide public loops (12 to 14), Staff corridors about 8 to 10, tight Security and secret routes; the tier is felt in the width. |
| Placed counts | **Scale to the design**: counts (intel stations, caches, cameras, ziplines, vents) are set from the new pacing and travel times, and the self-check is updated to match. Intel is no longer the unlock, so fewer stations are expected. |

### The new objective loop (changes the spec; see "Conflicts")
- The map has **5 vault rooms in fixed, spread-out positions**. **3 are active each match** (randomised); the other 2 are empty.
- Each active vault holds a **vault terminal** ("a computer") with a **golden asset**. Hacking a terminal gives **progress**
  and gives the **hacking team a high-level Asset (gold rarity specifically)**.
- **Vault progress is server-wide.** When all 3 active terminals are hacked, **the next phase unlocks**: the one final,
  higher-tier vault area, named **The Sanctum**, at the **tower summit**. (The other five are "vaults"; this one has its
  own name.)
- This **replaces the intel-threshold unlock** (min(35, 5 + 5 per team)). Intel remains the spending currency for doors,
  healing and ammo.

## Conflicts with the spec and earlier decisions (to confirm, nothing changed yet)
| Existing | New |
|---|---|
| Spec 10 and SPEC_CHANGES: the vault opens when a team-scaled intel threshold is reached; one of 4 vaults is chosen and opens in Phase 3. | 3 of 5 vault terminals hacked unlocks The Sanctum. Needs a SPEC_CHANGES row, a rewrite of Step 11 (intel) and Step 12 (vault), and the Phase 2 to 3 rules in Step 10. |
| Spec 9: intel stations' purpose is to reach the unlock. | Intel stations still exist (spending); how many are needed changes (48 were set for the old pacing). |
| 4 vaults with themed strongrooms (A to D), a Package inside one. | 5 vault rooms (3 active) plus The Sanctum (where the Package presumably is: to confirm). |
| Assets come from supply caches and tiered safes (four rarities, Ghost = gold at about 2%). | Terminal hacks award a gold (Ghost) Asset directly. Ghost is no longer the rarest: balance to review. |
| Art pass (Codex): sculptures, chandeliers, settees, materials and the lights are placed on the current rooms. | A re-layout invalidates that placement; the art pass must be re-applied after the new layout (the generator and the recipe-based art are repeatable, but it is real work). |

## Proposed NPC rework (my part; for approval)
The recent patches (R1 to R2) fixed the measured symptoms, but the cause of floating, wall-clipping and zone leaks is
that routes are *discovered* afterwards: PathfindingService waypoints between nearest-neighbour nodes, then fixed up. The
rework makes the layout the source of truth instead.
1. **Authored lanes.** The layout data names every walkable surface and every connection (doorway, stair, ramp, elevator),
   with width and tier. The generator emits the node graph and the route polylines **from that data, on the real floor
   surfaces**, so a route can never leave its floor, cross a wall or enter a zone above its tier. No runtime or build-time
   guessing; the build self-check verifies every route against the geometry and fails the build otherwise.
2. **Capacity-aware movement.** Each doorway, stair and lane carries a width and a throughput; NPCs reserve space, so
   crowds queue and spread instead of jamming. Hubs and quiet areas carry density weights set in the layout.
3. **Cheaper NPCs for a bigger crowd.** Server: spatial partitioning, tiered update rates by distance to the nearest
   player, and no per-NPC work for sleepers. Client: the existing cull (160 studs) plus a cheaper far figure. The target
   count is set by measurement (200 today: tick 12 to 17 ms, graph build 33 s).
4. **Reaction and tier rules unchanged**: role clearance is a hard cap, including panic and fleeing; higher tiers may visit
   lower ones; nothing on a rig reveals a player.

## Second round of decisions (2026-10-25, on the layout plan)
| Topic | Decision |
|---|---|
| The Sanctum's tier | A **new Tier 4**, above Executive. The whole crown (foyer, Package room, terraces) is Tier 4. |
| Tier 4 NPCs | **Two**: one **Warden** who stays on the summit (summit lobby, foyer, terraces) and one **Curator** who walks the penthouse, the roof and the summit lobby. Scanning either gives a Tier 4 disguise, which opens every Tier 4 door without a hack. |
| Tier 4 keycard | **Crafted from intel**: a **keycard printer** costs **10 intel**. There are **5 candidate printer spots** near the summit and **1 is active per match**; none is marked. The card opens the Tier 4 doors with no hack. |
| Door costs | Hacking costs **Staff 3, Security 6, Executive 8**, and **10** for the Sanctum's Package door and for the keycard printer (the most expensive of all). This lowers the old 4 / 7 / 10. |
| Two Package doors | The Package room has a **front door** (from the foyer: hack for 10 or use the keycard) and a **back door** (from the west terrace: **keycard only**, the quiet way in). The west terrace is reached by a Cover-breaking service ladder from the roof deck. |
| Elevators | The four glass elevators are **Staff and above**: Staff, Security and Executive disguises ride free; a Guest must hack the lobby door (3 intel) or tailgate, and is trespassing inside. **Staff NPCs ride them.** Public movement between floors is by stairs and ramps. |
| Tier 4 door costs | By door: the Executive stair's head **8**, the elevator's arrival **8**, the terrace doors **6**; the Package doors **10**. A Tier 4 keycard or a warden or curator disguise opens all of them free. |
| Keycard behaviour | **Single use**: it is spent on the first Tier 4 door it opens; another door needs another print (another 10 intel). |
| Printing | **20 seconds** at the printer. (Noise level not stated: assumed loud, like opening a supply cache, so it breaks Cover; to confirm.) |
| Vault core doors | The five vault cores' doors are **Executive doors (8 intel)**: an Executive disguise opens them free, anyone else hacks them, and the vent and secret exit are the other ways in. |
| Sky deck | Stays the **far** extraction (about 887 studs of walking from the Sanctum): the long, risky way out. |
| Package room routes | "Several routes" means the Sanctum area (three routes into the foyer) and **two doors** into the Package room itself. |

## Interview complete: what I will propose (all "by the design" answers)
These are my defaults; the first layout plan (floor plans and a list of rooms, as for the last re-plan) shows them for
review before any building, and the owner can overrule any of them.
- **Levels:** keep five (basement, ground, mezzanine, top floor, roof) with the existing half-levels; the summit gets its
  own level above the roof deck for The Sanctum.
- **The Sanctum:** an Executive-and-above tier at the tower summit with **three routes in**: a glass elevator that only
  runs once all 3 terminals are hacked, a long Executive stair behind a clearance door, and a rooftop approach (zipline
  from the wing's sky deck). Entering any of them is Cover-breaking except the disguised stair.
- **Elevators and secret exits:** two glass elevators per tower plus the Sanctum elevator, and a secret exit in each
  restricted wing room that has only one door (to keep "at least 2 entrances"), so the number follows the layout.
- **Counts:** set from travel times in the plan; the self-check is updated in the same change.
- **Art pass:** re-applied after the layout is approved and rebuilt (generator, sculptures, materials), by Codex.
- **Build order:** layout plan, then review, then the lane-authored node graph and the NPC rework together with the
  generator changes, then terminals and The Sanctum behaviour in the match steps (10 to 12), then the art pass.

## Next step
Approve (or change) this brief. Then I produce the layout plan: floor plans for every level, the room list with tiers
and widths, the route graph, vault and terminal positions, and the NPC capacity estimate.
