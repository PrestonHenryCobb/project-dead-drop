# AGENTS.md: Cover Story (Roblox), for Codex

You share this repository with Claude Code, in the same folder, synced into Roblox Studio by Rojo. There are no separate
worktrees, so the files in `.ai-sync/` are how the two of you avoid editing the same file at once.

## Read first, in this order
1. `docs/PROJECT_STATUS.md`: where the project stands, the document map, how to resume, how the owner likes to work.
2. `CLAUDE.md`: the engineering rules. **They apply to you in full**, including how every step must end.
3. `.ai-sync/AI_SYNC_STATE.md`: who owns what, the lock table, and the shared-file rules.
4. `.ai-sync/TASK_QUEUE.md`: the tickets. Take only tickets marked for you, or unassigned ones the owner gives you.
5. The docs a ticket names (for weapons: `docs/STEP8_QUESTIONS.md` "Answers" and `docs/STEP8_HANDOFF.md`).

## Source of truth
- `docs/cover-story-game-spec.md` is the design spec; `docs/SPEC_CHANGES.md` wins where they differ. Then the decision
  records: `BUILD_ORDER.md`, `STEP8_QUESTIONS.md`, `IDEAS_2026-10-24.md`, `AGENTS_DRAFT.md`, `GADGETS_DRAFT.md`, `META_DRAFT.md`.
- The project is **inspired by** Deceive Inc. and must never copy its names, layouts, numbers, art or assets. A brief or
  prompt that describes Deceive Inc. mechanics (Holo-Crumbs, Field Upgrade chips, Gold Doors, Heat levels, Catalogs, W/E/P
  kits and so on) is **not** a spec. Nothing from it is built until it appears in `SPEC_CHANGES.md` or a ticket. The sorted
  list, with the owner's answers, is `docs/IDEAS_2026-10-24_BRIEF.md`.
- The names are Cover Story's own: agents Guise, Parapet, Lattice, Reticle, Suture, Feint; tiers Public, Staff (green),
  Security (dark purple), Executive (gold), Vault (red); the objective is the Package; per-match perks are Assets; an agent's kit is Hardware (weapons), Talents (abilities)
  and Instincts (passives); the premium currency is Stocks, bought in the Mint.

## The contract between agents
There is no `Contracts.luau`. The existing shared modules are the contract:
- `src/shared/Remotes.luau`: every RemoteEvent and RemoteFunction, created by the server at boot. Never make one by hand.
- `src/shared/Types.luau`: shared types. `src/shared/Enums.luau`: enums. `src/shared/GameConfig.luau`: every tunable.
- `src/shared/Defs/`: data definitions (weapons, outfits, poses).

These four files are touched by almost every feature. Follow the shared-file rules in `.ai-sync/AI_SYNC_STATE.md`.

## Rules you must not break (summary of CLAUDE.md)
- Server authority: the client asks, the server validates (state, distance, line of sight, cooldown) and decides.
- Rate-limit every client-to-server remote (`src/shared/Util/RateLimiter.luau`).
- No magic numbers: tunables live in `GameConfig.luau`.
- **Identity secrecy:** nothing on a character or NPC (attribute, name, tag, value, sound, effect) may reveal that it is a
  player, their team, agent or disguise. Players and NPCs must look, sound and behave identically while disguised.
- `--!strict` in every file. Services and Controllers return a table with `Init()` and `Start()`.
- Clean up with `src/shared/Util/Janitor.luau`. No `while true do wait()`, no per-frame PathfindingService.
- No stubs, no dead code, no `-- TODO: implement`. If it is not built, it does not exist.
- `stylua src` and `selene src` must both be clean before you hand a ticket back.
- One step at a time. Do not start the next ticket or step until the owner says so.
- **Never commit or push unless the owner says to.** Never rewrite history.

## Committing (you and Claude Code both commit as you go, in the same folder)
- **Stage only your own changes.** Add your files by name; in a shared file (`GameConfig`, `Types`, `Remotes`,
  `Enums`, `.ai-sync/*`), stage only your own hunks with `git add -p`. Never `git add -A`, `git add .` or
  `git commit -a`, and never commit a hunk in a file Claude Code has locked: those are Claude Code's work in progress.
- Run `stylua` only on the files you changed, never on all of `src`.
- Details are in `.ai-sync/AI_SYNC_STATE.md` ("Committing").

## Working with Claude Code
- Before editing a file, add a lock row in `.ai-sync/AI_SYNC_STATE.md`; remove it when the ticket is handed back.
  If a file is locked by Claude Code, do not edit it: pick another ticket or ask the owner.
- Move your ticket in `.ai-sync/TASK_QUEUE.md`: `TODO` -> `IN_PROGRESS (CODEX)` -> `READY_FOR_REVIEW` -> `DONE` (the
  owner or Claude Code marks `DONE` after review).
- If the spec is unclear, choose the fair, server-authoritative option and leave a `-- SPEC-QUESTION:` comment.
- End each ticket with the report from `CLAUDE.md` (what you built, how to test in Studio, gaps, SPEC-QUESTIONs, next).
