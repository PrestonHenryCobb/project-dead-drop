# Map re-plan brief: The Gala, pass 3 (draft, 2026-10-23)

A full re-plan of the two-tower map, written for review before any data or generator work. It keeps every earlier
decision (MAP_BRIEF.md, BUILD_ORDER Step 7B) and every placed feature, and adds the two-player checkpoint feedback and
the reference-video decisions. The Deceive Inc. videos are inspiration only: mood, proportions, readability. No layout,
name or asset is copied (spec IP note).

## What this pass fixes

From the two-player checkpoint:
1. **Too many ways in to the important areas.** Players couldn't tell which door mattered.
2. **Dead ends:** the terrace ring corners, the basement and staff areas, the wing hallways and the suites.
3. **Too boxy:** a grid of rectangles with flat walls.
4. **Hard to read:** laser-slab gates you can barely see, and similar-looking zones.

## The numbers

| Topic | Now | Re-plan |
|---|---|---|
| Footprint | About 450 × 450 overall; Gala tower 240 × 280, wing 100 × 180 | **About 520 × 520 overall; Gala 280 × 320, wing 120 × 210**, still 20 studs apart across the void |
| Where the growth goes | n/a | **Into circulation, not bigger rooms:** curved halls, loops, arches, wider corridors for the bigger doors. Room sizes stay 15 to 40 studs, and hubs stay the exception. |
| Levels | B, G (+GH galleries), M, T, R, wing sky deck X | Same, 24 studs per storey |
| Doors | 10 × 10 default; clearance doors are slabs | **Grand 16 × 16** (lobby and atrium arches), **clearance 12 × 13**, **staff 10 × 10**, narrow service doors 8 × 10 |
| Tier colours | White, navy, purple, gold | **Public white, Staff green, Security dark purple, Executive gold, Vault red** |
| NPCs | 200 | 200 (growth spreads them a little thinner; densities get retuned) |
| Part budget | About 15,000 target | Re-measured after the build. Curves and arches cost parts, and the quality setting can drop trim on Low. |

## Wing themes (approved)

| Theme | Where | Look |
|---|---|---|
| **Gala art deco** (black and gold) | Gala public: lobby, atrium, ballroom, bar, galleries, masquerade hall, penthouse, rooftop | Black lacquer, gold fluting, sunburst inlays, fan-shaped arches, amber light |
| **Casino** (red velvet and neon) | Wing ground: casino floor, VIP tables, high-roller lounge | Red velvet, neon tube trim, dark carpet with gold pattern, low warm light |
| **Mediterranean** (tile and arches) | Wing mezzanine and top: hotel lobby, suites, wing roof garden | White plaster, terracotta, blue-and-white tile bands, round arches, potted lemon trees |
| **Back of house** (green tile, utilitarian) | Kitchens, catering, storage, loading bay, laundry, housekeeping, staff offices | Green subway tile, steel, fluorescent strips, rubber floors |
| **Security** (clean white and blue) | Guard halls, the hub, checkpoints, wing security | White panels, blue strip light, glass. Tier dark purple only on handles, inlays and signs |
| **Vaults** (brass and steel) | All four vault wings | Brushed steel and brass rivets, red vault-tier lights. Each vault keeps its sub-theme: A bank, B art, C cold store, D counting room |

## Circulation rules (new, enforced by the self-check where it can)

1. **Two loops per floor.** A **public loop** (Tier 0) circles the atrium, and a **staff loop** (Tier 1) runs behind the
   rooms on the outer edge. They meet at 3 or 4 points, so you can always switch between being seen and staying hidden.
2. **Important areas get one front door and one back exit.** That covers vault wings, guard rooms, nested rooms,
   Executive rooms and intel-heavy rooms. The front door faces the public or staff loop; the back exit leads to the
   other loop, a stair or a vent. Vent links count toward a vault's 3 routes out (spec 4.4), not as doors.
3. **Hubs can be wide open.** The atrium, ballroom, casino floor, rooftop and lobbies have 3 to 5 grand arches, because
   you are meant to drift through them.
4. **No dead ends.** Every corridor, ring and balcony connects at both ends. Small rooms off a loop can have one door
   only if they hold nothing important (restrooms, closets). The self-check lists any dead-end corridor.
5. **Signs at every junction.** Small lit **EXIT** signs above stair doors and exits. Hanging **direction signs** at loop
   junctions, with icons for stairs, exits, extraction and restrooms only. Signs never point to vaults: vault
   locations come from the HUD and the objective.

## Floor by floor

North is −z. Sketches are rough proportions, not final coordinates.

### Gala basement (B): security core over back of house
```
+---------+-------------------------------------+---------+
| STORAGE |  SECURITY LOOP (white/blue, T2)     | STORAGE |
|  west   |  +-------------------------------+  |  east   |
| (green, |  |  VAULT A wing (brass/steel)   |  | (green, |
|  T1)    |  |  ante -> laser hall -> round  |  |  T1)    |
|         |  |  door -> strongroom           |  |         |
| STAFF   |  +-------------------------------+  | STAFF   |
| LOOP    |  armory - camera room - guard post  | LOOP  ->|== tunnel to wing
+---------+-------------------------------------+---------+
```
- The **staff loop** circles the whole floor through both storage halls: each hall has two doors onto it, so no more
  storage dead ends. The service tunnel to the wing leaves from the east side.
- The **security loop** (T2) rings Vault A, with the armory, camera room and a guard post on it.
- **Vault A (bank):** front door off the security loop's south side; back exit through a vent to west storage; third
  route by the security stair up to the Gala kitchen. Door order T1, T2, T3 inside, as before.

### Gala ground (G): the grand level
```
+--------+---------+-----------------------+----------+--------+
| VAULT C| KITCHEN |   STAFF LOOP (green)  | CATERING | COLD   |
| (cold) | pass-   |  break room, staff WC | PREP     | STORE  |
+--------+ windows +--+----------------+---+----------+--------+
| LOADING|  SCULPTURE  (    ATRIUM     )   BALLROOM    | SMOKING |
| BAY    |  WALK, a    (  pond, islands)   colonnade,  | LOUNGE  |
| (T1)   |  curved     (  curved grand )   gallery     | humidor |
|        |  hall       (  staircase    )   above       | (T1)    |
+--------+-----+-----arches 16-----+----------+--------+---------+
| COAT   |     GRAND LOBBY: elevator bank (6 insertions) |  BAR + loft
| CHECK  |     concierge (one-way glass onto the lobby)  |
+--------+-----------------------------------------------+-----------
```
- **Atrium:** the pond and islands stay. The straight grand stair is replaced by a **curved grand staircase** sweeping
  from the pond's edge up to the mezzanine balcony. Four 16-stud arches open it to the lobby, ballroom, sculpture walk
  and bar.
- **The Sculpture Walk** replaces the boxy sculpture hall: a **curved gallery hall** bending round the atrium's west
  side, with plinths and wide arches into the atrium.
- **Ballroom** shrinks from 120 × 120 to about 90 × 100, with a colonnade and its upper gallery (GH). The space freed
  goes to the curved halls and the staff loop.
- **Back of house:** one continuous staff loop from the loading bay to cold storage and back down the east side to the
  bar's service door. The kitchen gets **pass-through windows** into the bar (you can see in and out, and they're not
  glass).
- **Vault C (cold store):** front door off the kitchen chain (staff loop); back exit to the loading bay; vent to the
  sculpture walk.
- **Lobby:** the grand entrance, where the elevator bank is the 6 ground insertion points. The coat check and concierge
  are the staff front of house, linked to the staff loop.

### Gala mezzanine (M): galleries and offices
- **Public loop:** the curved **atrium balcony** ring, where the grand staircase lands, joined to the Grand Gallery
  (west), the Masquerade Hall (east) and the gallery restrooms.
- **Staff and security band (north):** staff offices (green) with **one-way glass** onto the balcony; the security
  checkpoint (T2) nested inside, with one-way glass; the **security hub** (white/blue) with its one-way monitor room
  and Executive records (T3) nested two deep; catering offices. One front door each from the balcony side, one back exit
  onto the staff loop.
- **Terrace ring (outdoor):** fully continuous all the way round. Each corner becomes a small **pavilion** (a planter
  court with benches) instead of a dead end. Six insertion points sit on it. The skybridge to the lawn deck (an
  extraction site) leaves from its east side.

### Gala top floor (T): the penthouse
- **Penthouse great room** (art deco, T3) with a balcony over the atrium, and the **private gallery** (T3).
- **Guard ring:** the west and east guard halls (today two long dead-end halls) are joined by a north guard corridor
  behind Vault B, making one **ring**. The panic room and executive office stay nested T3 rooms off it.
- **Vault B (art):** front door through the glass display hall off the guard ring; back exit to the upper terrace;
  vent to the penthouse.
- **Upper terrace ring:** continuous with corner pavilions, and the zipline arrival from the wing's sky deck.

### Gala roof (R): the rooftop party
- Rooftop cocktail party (T0) with the cantilevered pool deck and cabanas, the **helipad** (extraction), the zipline
  down to the pool deck's far end, and the open catwalk to the wing roof. Two stairs up from the terrace, at opposite
  corners, so it's a loop.

### Wing basement (WB): laundry and the counting room
- A staff loop around the laundry and the hotel service corridor, joining the service tunnel from the Gala.
- **Wing security** (T2) on the loop. **Vault D (counting room):** front door through the wing security antechamber;
  back exit up the cage stair to the casino; vent to the laundry.

### Wing ground (WG): the casino
- **Casino floor** (red velvet and neon): table islands, slot rows as cover, and the **VIP tables** half-level (GH).
  Three grand arches.
- **Cashier's cage** (T1) with a teller window you can see through; **high-roller lounge** (T3) with one-way glass onto
  the floor. Front and back doors as the rules say.

### Wing mezzanine (WM): the hotel lobby
- **Hotel lobby** (Mediterranean): a reception desk under round arches, and **housekeeping** (T1) behind it on a staff
  loop. It opens onto the **lawn deck** (extraction), next to the skybridge.

### Wing top floor (WT): the suites
- **Courtyard loop** instead of the straight 180-stud hallway: two arcaded corridors round an open-air **tiled light
  well** (Mediterranean courtyard, with a fountain and lemon trees) that you can look into from both sides.
- **Suites** on the outer side, each with a door onto the corridor and a door onto a **continuous balcony** that runs
  along the facade. So the balcony is a second, exposed route, with no dead ends. The Executive suite (T3) has its own
  private balcony section, gated.

### Wing roof (WR) and sky deck (X)
- Roof garden and plant room. The **sky deck** extraction is on top, with the zipline start down to the Gala upper
  terrace, and the gondola and catwalk links as now.

## Doors and readability (approved, built in this pass)
- **Real doors replace the slab gates:** glass double doors for public and staff, solid for security, heavy metal for
  executive and vault. Every tiered door has **glowing handle bars in the tier colour with tier pips**, and the doors
  swing open. The server owns whether a door is open and solid; each player's game animates the swing.
- **Laser grids** stay separate: bright red beams, only in vault wings and two security corridors.
- **One-way glass** on tiered offices: inside sees out, outside sees mirrored glass. It blocks shots and sight both
  ways.
- **Zone carpets** per tier inside each theme, tier-colour floor inlays at every tier boundary, and the HUD area name.

## Everything kept (the self-check counts these)
4 vaults with themed strongrooms and climbing doors; 32 intel stations (8 per type); about 6 restrooms with health
stations; 8 ammo caches; about 20 food spots; 6 supply caches; asset safes in tiered rooms; 12 cameras; laser grids; 6
vent pairs; 2 ziplines; the gondola; galleries (GH); 3 extraction sites (helipad, lawn deck, sky deck); 12 insertion
points; the two towers on skyscrapers over the procedural city; 200 NPCs; 6 keycard doors.

## Generator upgrades needed (Build.luau, NavGraph, services)
1. **Footprint growth:** new rects throughout (Layout rewrite).
2. **Curved walls and halls:** arc wall segments built from short straight parts, with NPC nodes along the arc.
3. **Arches:** a door option for wide arched openings (round for Mediterranean, fan-shaped for art deco).
4. **Interior windows and one-way glass:** a wall-segment window option (sill and head heights). One-way glass is tagged
   with the room it belongs to; each player's client shows it clear or mirrored depending on which side they stand.
5. **Real doors:** hinged leaves, glowing tier handles with pips, sized by importance. DoorService keeps the authority;
   clients animate.
6. **Curved grand staircase:** a new stair builder, and a curved StairLink for NavGraph.
7. **Themes:** a per-room `theme` option driving materials, trim and carpet; tier inlays at boundaries.
8. **Signs:** EXIT signs and direction signs as tagged parts with lit text.
9. **New tier colours** in GameConfig, and suit trims in OutfitDefs.
10. **Self-check additions:** dead-end detection, front/back door counts on important rooms, door size by importance.

## Decided (2026-10-23)
| Question | Answer |
|---|---|
| Entrances | Important areas get one front door and one back exit, with vents in selected rooms only. Hubs get 3 to 5 grand arches. |
| Vents (6 pairs) | Vault A to west storage, Vault B to the penthouse, Vault C to the sculpture walk, Vault D to the laundry, the security hub to the staff offices, the casino cage to the casino floor. |
| Growth | Into circulation (curved halls, loops, wider corridors, arches), not bigger rooms. The ballroom shrinks to about 90 × 100. |
| Grand staircase | Curved, from the atrium floor to the mezzanine balcony only. The penthouse stays behind gated stairs. |
| Suites | Courtyard loop: two arcaded corridors round an open-air tiled light well, with suites opening onto a continuous outside balcony. |
| Terrace corners | Corner pavilions (a planter court with benches and a pergola) that the ring runs through. |
| Direction signs | Stairs, exits, extraction and restrooms only. Never vaults. |
| Build order | 1) Layout data at the new size with the loops, on today's generator. 2) Curves, arches, windows, one-way glass. 3) Real doors, signs, tier colours. 4) Curved staircase and themes. Screenshots go to your phone after each stage, for a remote review before the next stage starts. |

## Stage 1 built (2026-10-23): the layout at the new size, with the loops

Built on today's generator (no curves, arches, windows or new doors yet; those are stages 2 to 4). The self-check passes
with 0 problems: 109 rooms, 24 clearance doors, 6 keycard doors, 4 laser grids, 6 vents, 29 stairs, 769 NPC nodes.
Floor plans: `node tools/map-plan.js` writes one SVG per level to `docs/plans/` (or a folder you name).

**Where the build differs from the sketches above**
- Vault A's back door opens onto the central security hall, and its vent comes in from west storage. Vault B's back
  door opens onto the north guard corridor (not the terrace), and its vent comes from the penthouse study. Vault C's back
  door is the loading bay, and its vent comes from the sculpture walk through the loading bay wall.
- The mezzanine has no separate staff corridor. The terrace ring is the back loop: every office has its front door on
  the balcony and its back door on the terrace.
- One public stair reaches the roof (from the upper terrace to the pool deck), plus the two guard stairs.
- The kitchen pass-through windows wait for stage 2 (windows). The kitchen no longer touches the bar, so they will face
  the staff corridor.
- The Executive suite has its own balcony section, gated from the shared east balcony.
- The void through the top floor is 12 studs narrower than at the mezzanine, so the penthouse keeps a walkway round it.

**Fixes found while checking NPC routes**
- A row of planters down a terrace strip used to delete most of the strip's NPC nodes, so the ring corners read as dead
  ends. The generator now slides a blocked node to the nearest free spot (Build.luau, `NODE_NUDGES`).
- The bigger map needs more nodes: the cap went from 650 to 800 (GameConfig `NPCNodeCount`, SPEC-QUESTION). The graph
  still builds in about 20 s, and the NPC tick is unchanged at about 8.5 ms for 200 NPCs.
- Run NavReport with NPCs absent: a crowd on a narrow stair blocks pathfinding and makes the report look broken.

**Known leftovers.** A courtyard spot boxed in by planters, a private-gallery corner behind partitions, and door-side
nodes inside a guarded room's zone padding are cut off. NPCs never stop at them. Prop placement in small rooms is
tidied in stage 4 (themes).

## Stage 2 built (2026-10-23): curves, arches, windows, one-way glass, and the fountain

The self-check passes with 0 problems. Routes are as good as stage 1 (NavReport), and the courtyard's boxed-in spot is
gone.
- **Arches:** 16 arched openings (`arch = true` on a door): the atrium's grand openings, the gallery, masquerade and
  promenade openings onto the balcony, the penthouse gallery, the hotel lobby, and six arches from the suite arcade
  into the courtyard (`line =` picks which wall a door sits on).
- **Curves:** `round = r` on a room rounds off its corners with curved walls (glass barriers on terraces), except where
  a doorway is near. Used on the sculpture walk, the guard halls, the courtyard and both terrace rings: 17 curved
  corners. `round` on a void gives the atrium opening rounded corners, with curved railings and floor fills.
- **Windows:** a `windows` list. One-way glass on the security hub, checkpoint, staff and catering offices,
  high-roller lounge and concierge. Serving hatches from the kitchen and catering onto the staff corridor. Clear glass
  for the cashier's teller window, lounge to ballroom, and gallery to promenade.
- **One-way glass:** the server builds each pane as a mirror. `OneWayGlassController` (client) draws it clear when the
  camera is on the inside. Panes block movement, shots and sight checks both ways.
- **Fountain** (your request): the atrium's pond, islands and bridges are replaced by a tiered blue-and-white porcelain
  fountain with gold trim and water spilling from its bowls. On top stands a porcelain statue cast from your avatar's
  shape (no clothes, colours, textures or face; no Humanoid, no collision). A plaque reads "IN HONOUR OF THE FOUNDER"
  (the `text` field in Layout). If the avatar can't load at build time, a plain porcelain figure stands in.
- **Bug fixed on the way:** vault hack zones were built inside the strongrooms, and two laser grids were on the vault
  side. The generator assumed which side of a wall each room is on. It now works this out from the room's position,
  so hack zones sit in front of the vault doors and lasers sit in the antechambers. Vault B's strongroom is now 10
  deep, so its hack zone fits inside the vault.

**SPEC-QUESTION:** clear interior glass blocks NPC and camera sight like a wall, the same as the city windows always
have. Letting sight through glass needs a separate collision group for sight rays. That is worth deciding before the
art pass.

## Stage 3 built (2026-10-23): real doors, signs, tier colours

The self-check passes with 0 problems.
- **Tier colours:** Staff green, Security dark purple, Executive gold, plus Vault red (`GameConfig.Zones`). Staff
  uniforms keep the navy suit and black fedora, with green ties and lapels. Guests no longer wear green accents.
- **Real doors** on all 30 clearance and keycard doors:
  - Framed glass for Public and Staff, solid wood for Security, heavy strapped steel for Executive and vault wings.
  - Glowing handle bars in the tier colour on both faces (red into vault wings), with one pip per tier.
  - The openings are 13 studs tall, and double leaves are used from 10 studs wide.
  - DoorService still owns each door. It switches an invisible blocker and sets an `Open` attribute, and
    `DoorController` swings the leaves on each client into the higher-tier room. Checked in a playtest.
- **Signs** (96, never for vaults):
  - EXIT over doorways with a stair end within 30 studs, EXTRACTION into extraction rooms, and RESTROOMS.
  - A hanging "UP TO ... / DOWN TO ..." sign at both ends of every stair.
  - Each sign is a lit panel on the wall. **Floating signs** (your request): within 40 studs the text of the side facing
    you floats out in front of the panel, faces your camera at a fixed readable size, and is fully shown by 25 studs,
    while the printed text fades out (`SignController`, `GameConfig.Map.Signs`). Walls still hide it.
- **Bug fixed:** the coloured floor strips at doorways were sometimes on the wrong side of the wall (the same cause as
  the vault hack zones in stage 2).

## Stage 4 built (2026-10-23): curved grand staircase and wing themes

The self-check passes with 0 problems at 8,270 parts. Every stair links, the grand staircase included (NavReport), and
routes are as good as stage 3. With 200 NPCs the graph builds in 20.6 s, the server NPC tick averages about 9 to 10 ms
(8.5 before), and the client NPC frame cost is about 2.3 ms.
- **Grand staircase:** a curved marble stair with gilded balustrades (`curvedStairs` in Layout). It sweeps round the west
  side of the fountain inside the open atrium void, climbing 24 studs over about 90, with a solid base where it is low
  and columns where it is high. It steps onto a short bridge through a gap in the balcony railing. It replaces the
  straight grand stair.
- **Wing themes** (`STYLES` and `styleOf` in Build): Gala art deco (warm black lacquer, cream marble, gold trim),
  casino (red velvet, dark carpet, gold), Mediterranean hotel (white plaster, terracotta tiles, a blue tile band), back
  of house (green tile, rubber floors), security (white panels, blue-grey floors, a blue light strip), and vaults
  (brushed steel, diamond plate, brass). Each wall shows each room's own style on its side. Every Staff, Security
  and Executive room has a carpet in its tier colour.
- **Props:** the private gallery's partitions are gone (they boxed a corner off).
- **Not themed yet:** props (pillars, tables, planters) keep their old plain colours. Theming them is art-pass work.

## Review after stage 4 (2026-10-23): your notes and the fixes decided

| Your note | Fix |
|---|---|
| The gondola isn't realistically connected to its wire | Hang the platform from the rail on a trolley with cables, all moving together. |
| Platforms on the roof float; the roof staff room has an open wall and a missing ceiling | The sky deck only sits on walls (over the plant room and an enclosed stair hall), the plant room keeps off the courtyard shaft, and the roof catwalk gets a truss. New self-checks: no floating floors, no indoor room open to the sky. |
| The zipline is blocked by the glass | A gap in every glass barrier where a zipline crosses it. |
| Helipad and zipline mast look like placeholders | A proper helipad (H marking, edge lights) and a steel zipline tower. |
| Vent ducts look like broken cubicles | Ducts run at ceiling height in a steel casing. A floor-level grate at each end opens into a ladder shaft up to the duct, and the duct passes through the wall high up. |
| Carpets overlap the stairs | Carpets are cut round stairs, stair openings and doorways. |
| Grand staircase rails are heavy, zig-zag, and cross the landing; there's an opening at the landing | Slim gilded handrails on posts, a smoother curve, landing rails that line up, and the landing closed round the top step. |
| Signs: the dark panel shows behind the floating word, it doesn't fade gradually, and it's too sharp and too far | Up close the whole wall sign fades out. The floating word is soft text with no box, fades smoothly, and shows only within about 12 to 20 studs. A tier-colour outline shows the tier of the area beyond. |
| More floating signs | Room names at doorways, and direction arrows (stairs, exits, restrooms, extraction, never vaults) at corridor junctions. The arrow turns to point at the target from where you stand. A first-visit room animation is left for a later polish step. |
| Staff and guard doors are free to pass | Every doorway into a higher tier becomes a real door. NPCs and disguised players with clearance open it free; anyone else hacks it with intel (built in Step 18). |
| Door prices like Deceive Inc., far more intel, stations not tied to tiers, intel in vaults | The intel economy is scaled up (SPEC_CHANGES): stations give 2, 4, 6 or 10; doors cost Staff 4, Security 7, Executive 10; the vault unlock rises to match. There are about 50% more stations (48). Station type no longer follows the room's tier, except the 10-intel safe, which is only in Security and Executive rooms. Vault rooms hold some intel. |

## Review fixes built (2026-10-23)

Every note above is fixed. The self-check passes with 0 problems at 9,483 parts (8,270 after stage 4). NavReport gives
the same routes with and without the new doors (one more node joined at tier 3 with them), and every stair links. In a
playtest with 200 NPCs, NPCs opened 23 different clearance doors in 20 s, and a player climbed the security hub vent
(in through the grate, up the ladder, along the duct to the far shaft).
- **Levels:** the sky deck (X) is gone; the plant room sits off the courtyard shaft; the wing's roof extraction and
  Zipline 2 start on the roof (R). Trusses carry the pool deck and the roof catwalk. New self-checks: no floating
  floors, no indoor room open to the sky.
- **Gondola, ziplines, helipad:** the gondola hangs from its rail on a trolley; each zipline crosses a glass barrier
  through a gap with a low rail; extraction sites are landing pads (H, ring, rim lights); zipline masts are lattice
  towers.
- **Vents** (`vents` in Layout): ladder shafts with a floor grate at each end, and a steel duct at ceiling height
  (14.5 to 21 studs) that passes through walls high up.
- **Carpets** are cut round stairs, openings, doorways, vent shafts and the curved stair. The grand staircase has slim
  gilded handrails on posts, smaller steps, and a railed landing.
- **Signs** (`SignController`, `GameConfig.Map.Signs`): soft floating text with no box and a tier-colour outline (the
  tier of the area it leads to), fading smoothly between 20 and 12 studs. There are no sign panels at all (your
  follow-up): every sign is an invisible anchor, so from further away there is nothing on the walls.
  Billboards exist only while a sign is in range. New: the room's name floats over every doorway (144), and 78
  direction signposts (`signposts` in Layout) list the nearest stairs, restrooms and extraction on the same level and
  tower, each with an arrow that turns toward it and the distance in metres. Stairs and restrooms only count in rooms
  of the signpost's tier or lower, so a sign never sends a guest into staff areas. Signposts stand at least 18 studs
  apart, so two rooms sharing a doorway get one.
- **Clearance doors:** Build makes every doorway between two tiers a clearance door of the higher tier unless the
  layout made it a keycard door, a vault door or an open arch: 28 new doors, 54 in all. A new self-check makes sure
  every clearance door has a wall to stand in; it found the Executive balcony's gate standing on an open line between
  two balconies (a free pass until now), which now has a privacy screen. Hack prices (Staff 4, Security 7, Executive 10)
  are recorded for Step 18.
- **Intel:** 48 stations (`placeIntel` in Layout): 14 tablets (2 intel), 14 laptop carts (4), 12 server racks (6),
  8 wall safes (10), 236 intel in all. Safes stand only in Security and Executive rooms (self-checked), and four
  stations sit in vault rooms. The vault unlock is min(35, 5 + 5 per team).
- **Plans** (`node tools/map-plan.js`): vents drawn as ducts with their shafts; doorways between tiers show as
  clearance doors.

## Follow-up walkthrough fixes (2026-10-23)

- **Roof stair:** the switchback opening calculation already covers the high end of the upper flight. Rebuild
  `Workspace.Gala` from the current builder before changing it; the screenshot may show an older generated map.
- **Roof plant room wall:** indoor room edges beside a shaft now build a full-height, room-styled wall; only outdoor
  edges keep the low railing. This closes the plant room side facing the roof courtyard.
- In Studio, rebuild `Workspace.Gala`, then walk the roof stair and inspect the plant room's courtyard-facing wall.

## Owner-approved traversal expansion (2026-10-25; planned, not built)

- Add a small original set of prop-triggered secret exits inside restricted rooms. Use Gala's own geometry and
  escape-route needs; reference videos are not a layout or prop-placement specification.
- Activation requires inside-room position, proximity, facing and clear line of sight. The server rechecks these;
  Codex's prompt mirrors them. No activation prompt or request should work through a wall/from outside the room.
- Exit locations, footprint and support must be reviewed alongside crowd navigation, tier bounds and safe landings.
  Once open, anyone can pass in either direction; activation remains inside-only and Discreet, breaking Cover only
  under existing witness rules. Do not create one-way invisible passage restrictions.
- Add functioning glass elevators to the plan now. Floors/stops use the map's actual named floor bands. Claude owns
  shaft/car/door geometry, server travel and passenger safety; Codex owns floor selector/status/interaction graphics.
  Riding preserves Cover like walking; destination rooms retain normal clearance rules.
- Before calling either feature implemented: define shared contracts under locks, run generator/self-check/NavReport,
  then test calls/activation from both sides, obstruction, riders, death/disconnect, crowd behavior and performance.
  Existing traversal remains available; this addendum does not claim generated parts or working remotes exist yet.

## Pickup and station distribution review (owner answer 2026-10-25)

The attachment's counts are illustrative, not required totals. Balance pickups, health/ammo/food stations, safes and
caches around travel time, room tiers and safe routes; then validate and document actual totals. Funds pickups remain
removed. Keep layout data, GameConfig bounds and self-checks consistent with reviewed changes; do not disable a
validation failure merely to accept a new count. This is a distribution policy, not a claim that placement was rebuilt.
