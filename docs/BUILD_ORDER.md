# BUILD_ORDER.md: Cover Story

Do **one step per message**. Test each step in Studio before moving on. Each step lists the spec sections to read and a prompt you can paste into Claude Code.

> Tip: start each prompt with "Read CLAUDE.md and the listed spec sections first."

---

## Phase A: Foundation

### Step 1: Project scaffold
**Spec:** 25.1, 25.2, 22
**Prompt:** "Do Step 1. Set up the Rojo project, folder layout, Main server/client loaders, the Service/Controller Init/Start pattern, GameConfig (all values from the spec, Section 22 and every number elsewhere), Enums, Types, the Remotes list and auto-creation, a cleanup helper, and a remote rate-limiter. No gameplay yet."
**Done when:** Rojo syncs into Studio, play-test prints every service and controller starting with no errors.

### Step 2: Graybox map + zones
**Spec:** 4
**Prompt:** "Do Step 2. Build a graybox version of The Gala in code or as a Rojo model: 3 floors, all 4 tier zones with colored trim, ZoneVolume parts, and every tagged object from 4.3 as placeholder parts (correct counts). Write ZoneService that tracks each player's current tier at 4 Hz."
**Done when:** walking around prints your current tier correctly, including overlapping boundaries (higher tier wins).

### Step 3: Shared rig + hidden UI
**Spec:** 8.2, 25.3
**Prompt:** "Do Step 3. Make the custom R15 rig used by both players and NPCs, the OutfitDefs data format with 20+ outfits per role, and outfit application. Players spawn as a random Guest outfit. Disable player list, health bar, nametags, chat bubbles. Strip all Roblox avatar items."
**Done when:** a player and a test NPC wearing the same outfit look identical.

---

## Phase B: The crowd

### Step 4: NPC movement system
**Spec:** 5.1, 5.2, 25.4
**Prompt:** "Do Step 4. NPCService: precompute paths over the NPCNode graph, spawn NPCs by role with role tier limits, move them server-side cheaply, animate on clients. Walk speeds from config."
**Done when:** 74 NPCs walk around smoothly; check MicroProfiler and report server and client cost.

### Step 5: NPC activities + reactions
**Spec:** 5.3, 5.4, 5.5
**Prompt:** "Do Step 5. Node activities and idle animations, random head glances, door opening, panic reactions to gunfire/explosions/bodies (use a debug key to fire a test gunshot event), NPC death and replacement."
**Done when:** the crowd looks alive and panics correctly.

---

## Phase C: Social stealth (the core of the game)

### Step 6: Disguise system
**Spec:** 6
**Prompt:** "Do Step 6. Scan, disguise slots, apply disguise, insertion disguise, clearance, disguised movement limits, Blend emote wheel, neck follows camera."
**Done when:** you can scan any NPC and become them, and the Blend wheel works.

### Step 7: Cover, suspicion, trespass, exposure
**Spec:** 7, 8.3, 8.4
**Prompt:** "Do Step 7. CoverService with Covered/Suspicious/Exposed states, every action in 7.2 and 7.3, witness logic using Security NPCs (stationary is fine for now), trespass grace, combat lockout, re-covering, Exposed pings, Agent Sense. Add a temporary debug HUD showing state and suspicion."
**Done when:** every row of tables 7.2 and 7.3 behaves as written. Test with 2 players.

**Checkpoint:** play a 2-player session where you just try to find each other in the crowd. If this isn't fun yet, fix it before going further. Everything else builds on it.

### Step 7B: Layout pass (intricate graybox, indoors and outdoors)
**Spec:** 4 (all of it), 5.1 to 5.3, 8.1, 18.1. **Decisions:** STYLE_QUESTIONS B3, D1; OPEN_QUESTIONS G1, G3, G5.
**Why here:** stealth, suspicion and combat all depend on sight lines, cover and routes. The Step 2 graybox is a few large
empty boxes on a grid, so Steps 7 and 8 would be tuned for a map that will not exist. Rebuild the layout once, as gray
boxes, then dress it in the art pass.
**Prompt:** "Do Step 7B. Replace the graybox with an intricate layout described as data (rooms, corridors, outdoor areas,
stairs, balconies, ramps), generated into zones, doorways, tagged objects and NPC nodes as before. Keep every count and
rule in spec Section 4. Add the outdoor areas, guard rooms and NPC density rules below. Keep the self-check that
prints which spec rules pass."

**What the layout must have**
- **Indoors and outdoors, as one flow.** Interiors open onto outside spaces and back again: an entrance forecourt, a
  garden or courtyard, a terrace over the garden, a pool or fountain deck, a loading-dock yard, and the rooftop cocktail
  party (a Tier 0 public area, STYLE_QUESTIONS B3) with the helipad. Players should be able to cross the map through a mix of
  inside and outside routes. These maps are inspired by the way "Framed" and "Deceive Inc." mix social hubs with
  indoor and outdoor links; their layouts are not copied (spec IP note).
- **No big empty boxes.** Rooms are broken up: 15 to 40 stud rooms with several exits, loops so there is never one
  obvious route, side rooms and alcoves, balconies and mezzanines that look down on atriums, a service and back-of-house
  network that runs parallel to the public routes (Tier 1), and cover blocks (counters, planters, statues, pillars,
  furniture masses) in the open spaces. Each themed area is its own place: gallery, ballroom, masquerade hall, bar,
  kitchen, coat check, penthouse, private gallery, rooftop.
- **Guard rooms stay.** Security hub, camera room, armory and its hallways, guard posts at stairwells, doors and the vault
  approach (Tier 2, spec 4.2), and patrol loops through them. They are part of the layout, not removed for space.
- **Vertical routes.** Stairs, ramps, lifts-as-doors, vents (6 pairs) and ziplines (2 pairs) between levels and across
  outdoor gaps. Every Tier 1+ zone keeps at least 2 entrances; every Intel spawn is reachable without climbing; each
  vault spawn has at least 3 routes out; each extraction site is at least 120 studs of path from each vault spawn
  (spec 4.4).
- **Sight lines.** Long lines (over 150 studs) stay at 2 to 3 for the whole map. The rooftop is open but balanced: cover
  and the crowd break it up, with no sniper nests (STYLE_QUESTIONS B3 follow-ups).
- **Zones readable at a glance.** Each doorway keeps its colored trim and floor decal; zone colors also show on rugs
  and small colored pieces inside rooms rather than flat-colored rooms (STYLE_QUESTIONS D1).

**NPC density: a happy medium**
The map should feel alive without the crowd clogging corridors or leaving rooms empty.
- The total stays at the configured NPC count (74 by default). It is spread by an area weight, not evenly: crowded hubs
  (ballroom, rooftop party, main gallery, bar), a few NPCs in side rooms and corridors, and the guard rooms always staffed.
- Each zone gets a density weight. NPC spawns and trip choices use it, so NPCs favor hubs but do pass through quiet areas.
  The weights are data on the map (attributes on zone or node parts, never on characters), tunable in playtest.
- No room is empty for long in the early match, so hiding in one is still a risk, and no corridor is so full that the 2.5 stud
  separation pushes NPCs off their paths.
- Measure the server tick and client frame cost on the larger layout (spec 25.4, OPEN_QUESTIONS G5). If it is too
  expensive, cut NPC detail before cutting the map.

**Engineering notes**
- The generator stays data-driven. Rooms, corridors and outdoor areas are described in a table, and zones, doorways,
  NPC nodes and tagged objects are produced from it, so the layout can change without rewriting the builder.
- Outdoor NPC routes need nodes and walkable ground; the graph build (NavGraph) checks that every link is walkable.
- Part count and lighting are tracked: keep a PC and console part budget, and use StreamingEnabled with Atomic model streaming for
  large dressed areas. Lighting stays temporary (dim gala lighting arrives in the art pass).
- Re-run the Step 4, 5, 6 and 7 test scripts on the new layout: NPCs path everywhere, doors open, scans and
  re-covering work, and tiers are correct at every boundary.

**Decided (2026-10-22)**
| Topic | Decision |
|---|---|
| Footprint | About 450 x 450 studs, packed. Outdoor areas are part of that footprint. |
| Levels | Five main levels (basement, ground, mezzanine, top floor, roof), with varied heights: split levels, half-floors, balconies. |
| Part budget | About 15,000 parts for the finished map. The self-check reports the count. Detail comes from meshes and textures in the art pass. |
| Streaming | StreamingEnabled on, with a large target radius (about 250 studs). Dressed model groups stream atomically. |
| NPC count | 74, spread by area weight. Raise after phone tests if there is room. |
| Lighting | Night with lit areas: lit paths, lanterns, spotlit hubs, pools of shadow. Temporary until the art pass. |
| Widths | Mixed 6 to 12 studs: narrow service corridors and doors (6 to 8), normal doors (10), wide only for halls and the ballroom (12). |
| Layout design | I write the layout as data and show Studio screenshots for review; you give notes and I revise. |

**Design brief (2026-10-22)**
| Topic | Decision |
|---|---|
| Feel | Evokes the glamour and structure of Deceive Inc.'s "Diamond Spire" as inspiration only. No layouts copied (spec IP note). |
| Shape | A tall tower rising from grounds: a large central atrium, with the garden lawn, loading dock and forecourt around it, and the rooftop and helipad on top. |
| Focus areas | Gallery, ballroom, masquerade hall, bar, kitchen, penthouse, rooftop cocktail party. |
| Extraction points | Three outside areas: helipad, loading dock, garden lawn. |
| Nested rooms | Guard rooms can be layered two levels deep: a room with a higher-tier room inside it (for example Staff containing Security). |
| Inner doors | Opened by disguise clearance and a hard gate: a door stays shut for anyone below its tier, including Exposed players. They need another route or to pick a lock (cover-breaking). A qualified NPC or player opening it lets others slip through, which is the existing tailgating rule. |
| Vault | Three distinct vaults (different shape and door sequence each). Several tier doors inside each. Identities to steal are high-tier NPCs placed in the vault wing to scan. Intel inside the vault is extra loot after unlock (team bonuses and Funds), not part of the unlock. |
| Intel stations | Far more than 10 on the map, in four types giving 1, 2, 3 and 4 intel, each with its own model, and longer hacks the more they give. One type per tier: 1 intel in public (Tier 0), 2 in Staff (Tier 1), 3 in Security (Tier 2), 4 in Executive (Tier 3). Times scale with points (for example 4 s, 7 s, 11 s, 16 s), set in `GameConfig`. |

| NPC roles | Raised to 90 on 2026-10-23, split Guest 40, Staff 18, Security 16, Executive 16 (spec was 74: 40, 18, 10, 6), so the guard rooms, vault wings and penthouse are well staffed. Roles favour their own tier (`GameConfig.NPC.RoleTierWeights`). Config values in `GameConfig.NPC.RoleCounts`. |
| Hard gates | Only nested rooms, guard rooms, vault wings and the penthouse are clearance gates. Ordinary tier-to-tier doorways stay open with the trespass rules. |
| Vault door order | Climbing tiers inside each vault: Tier 1, then 2, then 3, so getting a Security and then an Executive disguise is the way in. Each of the three vaults has its own sequence and shape. |
| How to start | Layout data first (levels, rooms, doors, outdoor areas), generated and reviewed with screenshots before the vault interiors and the four intel station types. |

**Status (2026-10-23): pass 1 built and revised once (see the map revision above); self-check passes with 0 problems.**
- Done: the tower layout as data (`src/server/Tools/Gala/Layout.luau`) and its generator (`Build.luau`): 53 rooms over five
  levels with a central atrium, setback terraces, hedged grounds with gates, nested guard rooms, 14 clearance doors and 6
  keycard doors, 19 ramps, zone volumes, 311 NPC nodes, props and cover, 12 insertion points, 3 extraction sites and 3 vault
  placeholders. The self-check passes. `DoorService` opens clearance doors by clearance. Run it with
  `require(game.ServerScriptService.Server.Tools.Gala.Build).run()` on a fresh clone of the Gala folder in Studio's Edit mode.
- Still to do after you approve the shape: the three vault interiors with their tier doors and identities, the four intel
  station types and far more intel points, supply caches, cameras, laser grids, vents, ziplines, pickups and climb
  surfaces, then the Step 4 to 7 test pass and the two-player checkpoint.

**Map revision (2026-10-23, after your review of pass 1)**
| Topic | Decision |
|---|---|
| Setting | The Gala sits on the roof of a skyscraper, high above a city. A sheer shaft drops under the tower, cloud decks and haze lie below, lower towers poke through, a few tall ones stand in the distance (one persistent model, `Cityscape`). |
| Ground floor | Entirely indoors, with windows onto the cityscape. No outdoor rooms at ground level (no forecourt, garden, pond court, hedges, orchard or yard). |
| Outdoors | Only the mezzanine terrace ring, the upper terrace ring, the roof, the skybridge and the lawn deck (the Garden Lawn extraction site, now on the mezzanine). |
| Stairs | 6 studs wide (was 12). Mixed: one grand straight stair along the atrium, and switchbacks (14 x 30, climb half, turn at a landing, arrive beside where they began, with open floor beyond). 13 stairs in all. |
| Atrium | The void is 76 x 80 (was 60 x 60) from the mezzanine up through the skylight, with the pond at its foot. |
| Loading dock | Now an indoor loading bay (Tier 1) at the west end of the ground floor. |
| Insertion | 6 points on the ground floor and 6 on the mezzanine terrace, at least 80 apart. |

**Platform and scale change (2026-10-23)**
| Topic | Decision |
|---|---|
| Platforms | PC and console are the targets. Mobile is dropped as a target; basic touch controls stay as a fallback only. |
| Hardware floor | Mid-range PC and consoles (about GTX 1060 or Xbox One S). A graphics quality setting lowers city detail, lights and shadows, and effects (atmosphere, haze, particles, water) for weaker machines such as MacBooks. |
| NPC count | 200: Guest 120, Staff 40, Security 25, Executive 15. Measure server tick and client frame after the raise. |
| Map growth | About 30% more space: a new wing (a second, smaller tower joined by skybridges), extra half-levels and split levels inside floors, and bigger outdoor decks. |
| Stairwells | The floor opening around a stair is only as large as headroom needs, railed on every open side. No stair may pass through another stair or its opening; the self-check enforces it. |
| City backdrop | Procedural: varied tower styles (setbacks, spires, crowns, glass curtain walls), window textures with randomly lit rooms, rooftop props, layered depth bands to the horizon. |
| Sky | Night: deep blue sky with stars and a moon, an orange glow rising from the city below, distant aircraft lights. |
| Void | Below the city, haze layers darken from the orange city glow to a solid black floor at y -560, which is also the kill height (Workspace.FallenPartsDestroyHeight). Open edges of terraces and decks have 9-stud glass barriers. |
| Skybridge | Enclosed and glass-walled (12 wide, 12 high), like a link between hospital wings, on a steel Warren truss bracketed into both buildings. The lawn deck is the roof of a neighbouring tower. |
| Palette | The Gala follows the city: slate-blue shell and roofs, warm stone interior walls, warm-tinted floors, city-blue glass, steel rails. Set Lighting.Technology to Future in Studio (scripts cannot). |
| Order | 1) Fix the stairs and the openings beside them. 2) Grow the map and raise NPCs to 200, then measure. 3) The detailed city and night sky. 4) The quality setting. Then pass 2 (vaults and intel). |

**Follow-ups this brief creates** (to settle before or during the step)
- **Spec changes:** intel gets four station types (spec Section 9), doors become clearance gates (Sections 4.3 and 7), and the vault gets an interior with door tiers and NPC identities (Section 10).
- **NPC roles for the vault:** the spec has only 6 Executives. Plenty of identities in the vault wing means more high-tier NPCs, while the total stays 74. The role counts need a decision.
- **Door count:** the spec has 6 keycard doors. Clearance doors need many more. Which doors are hard gates and how many is set in the layout data.
- **Systems affected later:** `DoorService` gains clearance checks (Step 14 builds keycards, lock picking and alarms on top), and Step 11 (Intel) builds the four station types.

**Done when:** a walkthrough shows the layout is intricate and has outdoor areas; the self-check passes every rule in spec
Section 4; NPC server and client cost is within budget with the new density; two players can play the Step 7
checkpoint (finding each other in the crowd) and the routes feel varied.

---

## Phase D: Combat

### Step 8: Weapons + hitreg
**Spec:** 13
**Prompt:** "Do Step 8. WeaponDefs for all 8 weapons, client fire with prediction, server validation with lag compensation, damage, armor plates, headshots, falloff, reload, ammo, melee and takedowns, hitmarker types (grey NPC, red agent). Start with Vesper's SMG fully polished, then add the others."
**Done when:** 2 players can fight; firing breaks cover; hitmarkers are correct.

### Step 9: Downed, revive, elimination, spectate
**Spec:** 14
**Prompt:** "Do Step 9. Downed state, crawl, bleed-out, revive, execute, team wipe rule, Agent Tag drop, Solos rules, spectate."
**Done when:** tested with 3 players on 2 teams.

---

## Phase E: Match loop

### Step 10: Lobby, teams, match phases
**Spec:** 2, 3
**Prompt:** "Do Step 10. MatchService phase state machine, timers, modes, team assignment with parties, team colors and teammate markers (client-side only), agent select screen (placeholder art), insertion freeze and briefing, results screen."
**Done when:** a full empty match runs from lobby to results with the right timers.

### Step 11: Intel
**Spec:** 9
**Prompt:** "Do Step 11. IntelService: random active spawns, all 4 Intel sources, per-team usage, glint, team thresholds and rewards, global unlock counter."
**Done when:** collecting intel triggers Phase 3 at the right threshold.

### Step 12: Vault
**Spec:** 10
**Prompt:** "Do Step 12. Random vault from 3, reveal, hack zone with global progress, bonus rate, contest pause, open animation, extra guards."

### Step 13: Package + extraction + overtime
**Spec:** 11, 12, 19
**Prompt:** "Do Step 13. Package pickup, carrier rules, pass, drop, return timer, pings; extraction call, countdown, beacon, zone, channel, expiry; win/lose; overtime."
**Done when:** a full match can be won end to end.

**Checkpoint:** play full matches with friends. Tune numbers in GameConfig only.

---

## Phase F: Security

### Step 14: Cameras, lasers, doors, alarm
**Spec:** 18.1–18.4
**Prompt:** "Do Step 14. Cameras (sweep, cone, lock-on, hack, destroy), Camera Room, laser grids and fuse boxes, keycard doors and lockpicking, alarm levels with decay and Lockdown."

### Step 15: Security NPC combat
**Spec:** 18.5
**Prompt:** "Do Step 15. Make Security NPCs patrol, act as witnesses, engage by the rules, shoot with accuracy falloff, chase limit, respawn."

---

## Phase G: Content

### Step 16: Agents + abilities
**Spec:** 15
**Prompt:** "Do Step 16. All 8 agents: ability, passive, cover perk. Build them one at a time and give me a test plan for each."
(It's fine to split this into 16a to 16h.)

### Step 17: Gadgets + loadout perks
**Spec:** 16, 15.10

### Step 18: Funds, pickups, Supply Caches, Rescue
**Spec:** 17, 14.2

---

## Phase H: Polish and launch

### Step 19: Real HUD + minimap + pings + settings
**Spec:** 21, 24 (replace debug HUD; keyboard and mouse plus gamepad controls, with basic touch as a fallback)

### Step 20: Audio
**Spec:** 23

### Step 21: Data + progression + shop
**Spec:** 20 (DataStore with session locking, XP, Credits, unlocks, cosmetics)

### Step 22: Matchmaking + lobby place
**Spec:** 25.7

### Step 23: Anti-exploit pass
**Spec:** 26 ("Audit every remote and system against Section 26 and CLAUDE.md rule 1. List and fix gaps.")

### Step 24: Edge case + acceptance pass
**Spec:** 27, 28 ("Go through all 27 edge cases and the final checklist. For each, point to the code that handles it or fix it.")

### Step 25: Performance pass
"Profile a full 12-player match with 74 NPCs on low graphics. Report costs, then optimize the top 5."
