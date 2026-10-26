---
name: build-map
description: Design and build a new Cover Story map (or rework The Gala) with the data-driven generator. Use when asked to design, rebuild, extend or review a map layout, add rooms, outdoor areas, doors, bridges or set pieces, or to turn reference screenshots into a layout.
---

# Build a Cover Story map

**Current map (2026-10-25):** the Gala re-layout. Its layout is `Relayout.luau`, GENERATED from `tools/relayout-plan-data.cjs` by `node tools/relayout-layout.cjs` (then `stylua` on it): change the plan or that script, never the output. `Build.run()` builds it; `Build.run({ layout = "old" })` builds the original `Layout.luau`; `Build.run({ dryRun = true })` runs only the door, window and stair checks (a second, no geometry). `node tools/relayout-plan.cjs` checks and draws the plan (SVGs in docs/plans/relayout).

A map is **data** (`Layout.luau`) turned into geometry, zones, doors, NPC nodes and props by a **generator**
(`Build.luau`). Both live in `src/server/Tools/Gala/` and sync into Studio through Rojo. To make a new map, copy that
folder (for example `Tools/<MapName>/`), write a new Layout, and run its Build. Reuse Build.luau as it is where you can.

Read first: `CLAUDE.md`, `docs/MAP_BRIEF.md` (the design brief for The Gala), `docs/BUILD_ORDER.md` Step 7B, and spec
Section 4 (map requirements and the rules the self-check enforces).

## 1. Brief before data

1. Look at every reference image the user gives (they are inspiration only: mood, proportions, flow, never a copied
   layout, name or asset, per the spec's IP note). Say what you take from each.
2. Write or update a **map brief** (`docs/MAP_BRIEF*.md`): the idea, each area with a creative description, tier colours,
   routes, NPC life, performance, and 3 to 5 questions. Get answers before rebuilding.
3. Decide the numbers with the user: footprint (about 450 x 450), levels, part budget (about 15,000 for the finished
   map), NPC count, door widths (mixed 6 to 12), time of day, nesting depth (two levels), hard-gated doors.

## 2. The layout data (`Layout.luau`)

- `levels` (name to floor height), `levelOrder`.
- `rooms`: `{ id, level, name, tier 0-3, kind "indoor"|"outdoor", rect {x1,z1,x2,z2}, options }`. Options: `parent`
  (carved out of that room: a nested room), `holes` (rects cut out, used for terrace rings and roof skylights),
  `density` (NPC weight), `activities`, `props` (names of prop builders), `glass` (walls facing a garden are glass).
  Rooms on a level must not overlap (the generator reports it) and should tile the footprint.
- `voids`: shafts through floors (the atrium) with railings round them.
- `ramps`: `{ from, x, z, dir }`, 12 wide, 48 long, climbing 24. Each must lie inside one room on the lower level and one
  room on the upper level, or the opening cuts across a wall.
- `doors`: `{ a, b, at, width, options }` joining two rooms that share a wall segment (`at` is x for a wall running along
  x, z for one along z). `gate = tier` makes a hard clearance door; `keycard = true` a shortcut door (exactly 6 per map).
  Outdoor rooms at ground level get hedge walls between them, and a door there is just a gate-sized gap.
- `features`: pool, island, bridge, skylight, waterfall, statue, lanterns, pavilion (set pieces that are not rooms).
- `nodes`: extra NPC nodes where the grid would not put one (on islands, bridges).
- `extraction`, `insertion` (12, at least 60 apart), `vaults` (3, at least 120 studs from every extraction site).

Rules to respect: every Tier 1+ room has 2 or more entrances (nested guard rooms and vault wings excepted and listed),
every vault has 3 routes out, sight lines over 150 studs are rare (2 or 3), zone colours also show on rugs and inlays.

## 3. Run it

1. Rojo must be serving and connected (see below). Edit the Layout, save, wait a few seconds for the sync.
2. In Studio **Edit mode**, run through the MCP `execute_luau` tool, on a **fresh clone** (Studio caches `require`, so a
   plain require after an edit gives you the old data):
   ```lua
   local clone = game.ServerScriptService.Server.Tools.Gala:Clone()
   local shared = game.ReplicatedStorage.Shared:Clone() -- GameConfig and Enums are cached too
   shared.Name = "SharedOverride"
   shared.Parent = clone
   clone.Parent = game.ServerStorage
   local ok, problems = pcall(function() return require(clone.Build).run() end)
   clone:Destroy()
   ```
   It deletes and rebuilds `Workspace.Gala` and prints `[Gala] ok / FAIL` lines. Zero problems means every rule it can
   check passes.
3. Read the console for the `[Gala]` lines. The console is long; the self-check lines are at the end.

## 3b. Check NPCs can walk everywhere

In a playtest (pathfinding needs the running world), run the report from a game Script so it shares the services:
```lua
local out = Instance.new("StringValue"); out.Name = "NavReport"; out.Parent = game.ServerStorage
local s = Instance.new("Script")
s.Source = [[game.ServerStorage.NavReport.Value = require(game.ServerScriptService.Server.Tools.NavReport).run()]]
s.Parent = game.ServerScriptService
-- wait until out.Value is set (about 20 s), then read it and destroy s
```
It lists, for each tier limit (Guests 0 up to Executives 3), the rooms with nodes cut off from the main group, and any
stair whose ends did not link. Fix layout causes (a public area reached only through a guarded room, a doorway or
passage narrower than 4 studs, a long corridor with too few nodes) until each tier is one group.

## 4. Review with screenshots

- `screen_capture` (Edit mode) with `camera_position` and `look_at_position` gives you the Studio viewport. The Studio
  window must be in front and not minimised, or the image is blank or the call times out. If it is hidden, click its
  taskbar icon and then its thumbnail (File Explorer access is needed for taskbar clicks).
- Useful shots: an aerial, each level in plan (temporarily set parts at or above a height to Transparency 1, restoring
  from an `OrigT` attribute), the atrium from the floor, each outdoor area, a facade.
- Send the good ones to the user with `SendUserFile`, and ask what to change.
- During a playtest, sample NPC positions from the server to confirm they use the new bridges, terraces and decks.

## 5. Performance and identity rules (do not break)

- NPC count from `GameConfig.NPC.RoleCounts`; each role favours its own tier (`RoleTierWeights`). Node cap
  `GameConfig.Map.NPCNodeCount.Max` (320). Interior lights are capped at 110. Keep part counts inside the budget.
- Players and NPCs must be indistinguishable: tiers are shown by **outfit and zone colour only** (Staff light navy suit
  with black accessories, Security black suit with purple, Executive cream suit with gold, Guests colourful, no hats),
  never by tags, attributes or names on a character.
- NPC nodes are needed on both sides of every door and at both ends of every ramp, bridge and island; narrow strips such
  as terraces still get nodes down their middle.

## 6. Environment notes (Windows)

- Start Rojo: `rojo serve default.project.json` (background). Studio: open the place, Rojo plugin panel, Connect, then
  Accept the first diff (it should list only scripts, never the map). Changing `default.project.json` needs a Rojo
  restart; changing files under `src/` does not.
- There is no Python. Use Node for scripted file edits (`node script.js`), and avoid long shell one-liners with mixed
  quotes; write the script to a file instead.
- After a code change, wait a few seconds before starting a playtest, or the playtest runs the old code.
- `require` of a service from an `execute_luau` script gives a fresh copy with no state; test through the real game.
