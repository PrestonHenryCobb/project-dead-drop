# Gala re-layout and NPC rework: brief (interview 2026-10-25)

Status: **interview in progress, nothing built.** The owner asked for a re-layout of the Gala with the NPC system reworked
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
| Towers and map size | Up to the design / not decided: I propose them with trade-offs. |

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

## Still to ask
Map footprint and number of towers; where the 5 vault rooms go (which floors and wings); how The Sanctum is reached
(routes, tier, entrances); whether the Package is in The Sanctum; elevator and secret-exit placement rules; the crowd hubs
(which rooms are the big ones); corridor and doorway widths; which Deceive Inc. and Entry Point maps are the references;
how many of the existing counts (intel stations, caches, cameras, ziplines, vents) to keep; and when to re-apply the art
pass.
