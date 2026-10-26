# Gala re-layout, Phase 2 (NPC rework): hand-over (2026-10-26)

Read first: `docs/MAP_PLAN_RELAYOUT.md` (section 10 lists Phase 1 deviations), `docs/plans/relayout/layout-report.md`,
`.claude/skills/build-map/SKILL.md`, `.ai-sync/TASK_QUEUE.md` (ticket `relayout-2`).

## Done (committed as WIP in the commit that adds this file)
- **Authored routes.** `Build.luau` now makes every NPC link from the layout: a 2-stud floor grid of cells a body fits in
  (doorways closed to it), nearest-node links by path, doorway links (wide doors are several lanes), stair links along the
  treads, elevator rides, groups joined, pocket nodes moved or dropped. Stored in a `Links` attribute on each `NPCNode`
  (with `NodeId`, `Room`, cluster fields). Self-check: 0 problems, every clearance reaches all its nodes (2,407 routes).
  `Build.run({ gridReport = { level = "T", x1, z1, x2, z2 } })` prints a floor's grid for debugging.
- **`NavGraph.load`** reads them (0.1 s; PathfindingService is gone). `tripRoute` returns legs (walk, ride, walk) and the
  links used. Playtest: 4,800 floor samples all within 3.35 to 3.67 studs of the floor; 1 of 15,600 samples above clearance.
- **NPCService rewrite:** capacity holds on links, congestion cost and trip put-off, crowd clusters, tiered server updates
  (Update.* in GameConfig, sleepers), elevator Wait/Board/Ride states, wake-up via `Death` (60 s, `RiseProne/RiseSupine`
  poses). **`ElevatorService`** (new): moves cabs, opens ElevatorDoor blockers, carries NPC riders. `DoorController` swings
  ElevatorDoor and PackageDoor leaves.
- 18 crowd clusters generated into `Relayout.luau` (`tools/relayout-layout.cjs`: CLUSTERS).

## Not verified (written, never run in play)
Elevator riding (watch an NPC wait, board, ride, get out: Staff only on E1 to E4), the wake-up (down an NPC, 60 s later it
rises: needs the `Rise*` poses to look right), congestion/put-off, clusters in play, the `ElevatorDoor` leaves on the client.

## Still to do
1. **Warden and Curator** (SPEC_CHANGES rows 2026-10-25): add roles `Warden`, `Curator` to `Enums.Role` and `Types.Role`;
   one outfit each in `OutfitDefs` (red and gold; Warden scale 1.25 tall, 1.05 wide, with the Tier 4 exception to the scale
   assert; a scan copies it). Config: `RoleMaxTier = 4`, walk speed, not in `RoleCounts`. Spawn them as extra NPCs in
   `NPCService` restricted to nodes whose `graph.rooms[node]` is in their rooms (Warden: s_foyer, s_ter_w, s_ter_e,
   r_summit, no elevators; Curator: t_great, t_gallery, r_summit, r_deck, may ride). Pass a per-NPC "ridable shaft"
   function to `NavGraph.tripRoute` (skip locked shafts: add `ElevatorService.isLocked`). Downing one: alarm +2 and expose
   the shooter (hook in `NPCService.hitNpc` / `CombatService` line ~233; `CoverService.onNpcKilled` exists, the alarm does not).
2. **Playtests** of the unverified items above, then fix. Zone volume of a shaft is now exactly its floor (no pad).
3. **Measure** server tick and client frame cost at 200, 300 and 400 NPCs (`GameConfig.NPC.RoleCounts`, Debug.PrintNpcCost,
   a player standing in the lobby and one at the roof): the `[NPCService]` log line now says how many are awake.
4. Docs: SPEC_CHANGES row, PROJECT_STATUS, mark `relayout-2` READY_FOR_REVIEW, release the lock row, tell the owner.
   `relayout-art` for Codex stays blocked until the owner approves the layout.

## Tooling notes
- Rebuild in Studio edit mode with the fresh-clone snippet in the build-map skill; read results from
  `LogService:GetLogHistory()` filtered by timestamp and `[Gala]` (do not print the whole console: it is huge).
- Wait about 4 s after saving before running (Rojo sync). Patch scripts: write them with the Write tool, not shell
  heredocs with nested quotes (escaping cost hours).
- Studio screenshots need the Studio window in front. Keep the session short: one long conversation costs far more than
  the work in it.
