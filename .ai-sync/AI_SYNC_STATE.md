# AI sync state (Claude Code and Codex)

Both agents work in this one folder, live-synced to Studio by Rojo. This file says who owns what, which files are locked
right now, and how the shared files are edited. Rules for both agents: `CLAUDE.md` (Claude Code) and `AGENTS.md` (Codex).
The owner has the last word on every row here.

## Ownership (proposed 2026-10-24, owner to confirm)
Ownership says who normally edits an area. A ticket in `TASK_QUEUE.md` can hand a file to the other agent; the lock table
below is what actually stops two edits at once.

| Area | Path | Owner | Why |
|---|---|---|---|
| Shared contract | `src/shared/Remotes.luau`, `Types.luau`, `Enums.luau`, `GameConfig.luau` | CLAUDE_CODE (both may append, see the shared-file rules) | Every feature touches them |
| Data definitions | `src/shared/Defs/` | CODEX for `WeaponDefs`; CLAUDE_CODE for `OutfitDefs`, `PoseDefs` | Weapons are Codex's feature area |
| Shared helpers | `src/shared/Util/` | CLAUDE_CODE | Used everywhere; changes ripple |
| Server boot and remotes | `src/server/Main.server.luau`, `Services/RemoteService.luau` | CLAUDE_CODE | Boot order and remote creation |
| Server gameplay | `src/server/Services/` (Cover, Disguise, Zone, Door, NPC, AgentSense, Rig, Vent, Zipline, Gondola) | CLAUDE_CODE | Server-authoritative systems |
| Server combat | `src/server/Services/CombatService.luau`, `src/server/Combat/` | CLAUDE_CODE | Validation and lag compensation; Codex adds weapon effects through a ticket |
| NPC crowd | `src/server/NPC/` | CLAUDE_CODE | Performance-critical |
| Map generator | `src/server/Tools/` | CLAUDE_CODE | Uses the build-map skill and Studio rebuild steps |
| Client boot | `src/client/Main.client.luau`, `Controllers/RemoteController.luau` | CLAUDE_CODE | Boot order |
| Client combat and HUD | `src/client/Combat/`, `Controllers/WeaponController.luau`, `CombatHudController.luau`, `ShotFxController.luau` | CODEX | Weapons, view model, HUD |
| Other client controllers | the rest of `src/client/Controllers/` | CLAUDE_CODE | Tied to server systems they mirror |
| Future UI (Step 19 menus, shop) | new files under `src/client/` | CODEX | UI work |
| Docs and plans | `docs/`, `CLAUDE.md`, `AGENTS.md`, `.ai-sync/` | CLAUDE_CODE (Codex updates its own ticket rows and locks) | Decision records |

## Active locks
Add a row before editing a file; remove it when the ticket is handed back. Never edit a file locked by the other agent.
Times are local, `YYYY-MM-DD HH:MM`.

| File | Locked by | Since | Ticket |
|---|---|---|---|
| `docs/PROMPT_REVIEW_2026-10-24.md` | CODEX | 2026-10-24 | Owner prompt review |
| `.ai-sync/CLAUDE_RETURN_HANDOFF_2026-10-25.md` | CODEX | 2026-10-24 | Owner-requested return handoff |
| `.ai-sync/TASK_QUEUE.md` | CODEX | 2026-10-24 | Own ticket rows |
| `docs/CLIENT_REVIEW_2026-10-25.md` | CODEX | 2026-10-25 | Owner acceptance report |
| `docs/SPEC_CHANGES.md` | CODEX | 2026-10-25 | Record explicit owner FPS/HUD corrections |

## Shared-file rules (`Remotes`, `Types`, `Enums`, `GameConfig`)
- Lock the file for the few minutes of the edit, not for the whole ticket.
- Add, do not reshape: new remotes, types, enums and config tables go in their own section with a one-line comment naming
  the ticket. Renaming or removing an existing entry needs a ticket for it and Claude Code's review.
- Every new client-to-server remote gets a rate limit in the same change.
- After the edit, run `stylua src` and `selene src` and release the lock.

## Committing (both agents commit as they go)
- Commit only your own work: stage your files by name, and in a shared file stage only your own hunks
  (`git add -p`, or a patch of just your hunks). Never `git add -A` or `git commit -a`: the other agent's
  uncommitted edits are in the same folder.
- If a file has the other agent's uncommitted hunks and you need to commit yours, leave theirs unstaged.
- Run `stylua` only on the files you changed, not on all of `src`, so you never reformat the other agent's
  work in progress.
- Commit the lock-table change that releases your locks together with the work.

## Audit: keep, wrap or rebuild (2026-10-24)
The project brief of 2026-10-24 asked for this triage. Every script and asset in the repo is Cover Story's own work from
Steps 1 to 8, written to `CLAUDE.md`'s rules, so none is a placeholder to rebuild.

| Area | Decision | Note |
|---|---|---|
| Map generator, city, layout data (`src/server/Tools/`) | KEEP AS-IS | Self-check passes with 0 problems |
| Crowd (`src/server/NPC/`, `NPCService`) | KEEP AS-IS | 200 NPCs; Step 8B adds easing and position stepping |
| Disguise, cover, zones, doors, Agent Sense | KEEP AS-IS | Built and tested in Steps 6 and 7 |
| Ziplines, vents, gondola | KEEP AS-IS | Playtested |
| Combat server (`CombatService`, `Combat/`) | KEEP AS-IS | Firing verified; melee, takedown, fall damage untested (Step 8 tickets) |
| View model and arms (`src/client/Combat/ViewModel.luau`) | REBUILD in Step 8B | Placeholder sleeve blocks, replaced by real arms holding the gun (decided) |
| Combat HUD | KEEP, replaced in Step 19 | Placeholder look until the real HUD |
| Shared contract and helpers | KEEP AS-IS | The single source for remotes, types and config |
