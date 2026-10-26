# Project status (updated 2026-10-24)

**Start here if you are a new session or a new tool.** This is the one page that says where the project stands, what to read,
how to resume, and how the owner likes to work. It mirrors the assistant's private memory notes so nothing important lives
only on one machine.

Cover Story (repo folder name Dead-Drop) is a Roblox social-stealth extraction shooter: players are disguised agents in a
crowd of NPCs. Rules in `CLAUDE.md`; game design in `docs/cover-story-game-spec.md` (unedited original, see below for its
changes); build plan in `docs/BUILD_ORDER.md`.

## Where the documents are
| Document | What it holds |
|---|---|
| `CLAUDE.md` | Engineering rules, the folder layout, how a step must end. Read first. |
| `docs/cover-story-game-spec.md` | The original design spec. **Not edited**; its old agent names and some rules are superseded. |
| `docs/SPEC_CHANGES.md` | Every place the project differs from the spec, newest at the bottom. **Wins over the spec.** |
| `docs/BUILD_ORDER.md` | The build plan, step by step, with decisions and status. New steps 8B, 13B and 13C are in its last section. |
| `docs/OPEN_QUESTIONS.md`, `STEP7_QUESTIONS.md`, `STYLE_QUESTIONS.md` | The owner's earlier answers (the source of many decisions). |
| `docs/STEP8_QUESTIONS.md` | Step 8 (weapons) decisions: loadout, controls, all 18 weapons' stats and unique effects. Its "Answers" section is the source of truth. |
| `docs/STEP8_HANDOFF.md` | Step 8's exact state: what exists, what is untested, what is left, Studio gotchas. |
| `docs/IDEAS_2026-10-24.md` | The owner's batch of ideas sorted against the plan, every conflict, and all answers. |
| `docs/IDEAS_2026-10-24_BRIEF.md` | The Deceive Inc. master brief sorted the same way: what we have, conflicts, and answers Q1 to Q13. |
| `AGENTS.md`, `.ai-sync/` | Codex's rules, who owns which files, the lock table, and the shared task queue. |
| `docs/AGENTS_DRAFT.md`, `GADGETS_DRAFT.md`, `META_DRAFT.md` | The six agents, the 12-gadget pool, the progression and shop design. |
| `docs/MAP_BRIEF.md`, `MAP_BRIEF_REPLAN.md`, `docs/plans/` | The map brief, the re-plan with every review fix, and floor plans (`node tools/map-plan.js`). |
| `.claude/skills/build-map/SKILL.md` | How to build and review a map with the generator. |

## Where the project stands
- **Done:** Steps 1 to 7B. Two towers (the Gala and a hotel/casino wing) on skyscrapers over a generated night city,
  200 crowd NPCs, disguise and scanning, cover and suspicion, tier doors, vaults, ziplines, vents, a gondola, signs, and
  the map re-plan (stages 1 to 4 and every review fix). Self-check passes with 0 problems.
- **Status on 2026-10-24 (late): `.ai-sync/TASK_QUEUE.md` is the live ticket list.** The owner asked both agents to
  build ahead and commit as they go, so Steps 8, 8B and 9 run together. Every ticket below is committed (not pushed).
- **Step 8 (weapons):** Guise's SMG and Reticle's carbine; melee, takedowns, fall damage (now by height), reloads
  (swap cancels them), disguised hits count as body shots, the post-melee fire delay, tracers and muzzle flash, and the
  server side of every firing-path unique effect (pellets, bursts, spin-up, aimed rate, pierce, ambush shot, scope glint,
  displaced sound). **Left:** the other weapons' data and client rules (Codex, 8.5 and 8.5-client-rules), the
  status and projectile effects (stagger, taser, knockback, flare, knives, smoke, tracker), the SMG model (8.6) and the
  two-player test (8.4).
- **Step 8B (feel):** done in code: taller, slimmer bodies and narrower hit boxes; full-body first person with real
  arms (Codex); gun framing and wall tuck (Codex); eased movement for players and NPCs with gravity 150 (walking now
  goes through `MovementController`; Roblox's own keyboard controls are off); other characters drawn in 12 Hz steps
  with shots rewound to match. All waiting for the owner's review.
- **Brief items built early:** the disguise-swap marker replaces the swap puff (brief Q6).
- **Step 9:** 9a teams (`TeamService`, mode from `GameConfig.Debug.TestMode`) and 9b downed, revive, execute, team wipe
  and elimination (`InteractService`, `DownedService`, `DownedController`) are done. Tested solo; crawling, bleed-out,
  revive and executing a player need two players. **Left:** 9b-hud (Codex), 9c spectating, 9d Agent Tag and rescue
  (blocked on Step 18 and a cost now that Funds are gone).
- **Next, in order:** the two-player test session (8.4 plus everything marked "needs 2 players"), 9c spectating, then
  Step 10 onward as in `BUILD_ORDER.md`, with **13B** (bots that fill empty slots) and **13C** (a first-run tutorial).
- **Waiting on the owner:** the Deceive Inc. tutorial videos (files or links) so the tutorial can be shaped by them;
  designing the new Talents and Instincts before Step 16 (brief Q8); confirming the proposed file ownership in `.ai-sync/AI_SYNC_STATE.md`.
- **Two agents:** Claude Code and Codex share this folder. Codex reads `AGENTS.md`; both use `.ai-sync/` for locks and tickets.

- **Gala re-layout (2026-10-25):** Phase 1 (the new layout, `Relayout.luau`, generated from the plan; self-check 0 problems) is built and waiting for the owner's review. Phase 2 (NPC rework) and the art re-pass wait for that review. See `docs/MAP_PLAN_RELAYOUT.md` section 10 and `.ai-sync/TASK_QUEUE.md`.

## Names
The six agents are **Guise, Parapet, Lattice, Reticle, Suture, Feint** (the spec file still has Vesper, Halden, Juno,
Sable, Ozzy, Mirage). Weapons: three per agent, the player picks one.

## How the owner likes to work
- One step at a time; do not start the next until told. Questions first ("grill me") for anything with real choices,
  decisions recorded in the docs, screenshots to review maps.
- **Ask before committing or pushing.** Recent habit: the owner says "commit" or "push" explicitly.
- Inspiration only from Deceive Inc. and other games: never copy layouts, names, art or assets.
- End every step with the report in `CLAUDE.md` (what was built, how to test in Studio, gaps, SPEC-QUESTIONs, what is next).
- Say plainly when something is wrong, risky or impossible on Roblox. Never leave stubs or dead code.

## How to resume work
1. Tools come from `rokit.toml` (Rojo, StyLua, Selene). Run `rojo serve default.project.json` in the background.
2. Open the place `CoverStory.rbxl` in Studio (it is **not in the repo**: `*.rbxl` is ignored, and the map is generated from
   `src/server/Tools/Gala/Layout.luau` and `Build.luau`, so it can be rebuilt; back the place up through Publish).
3. In the Rojo plugin, Connect and accept the script-only diff. If syncing stops (the panel says "synced hours ago"),
   restart `rojo serve` and Disconnect then Connect.
4. Before finishing any change: `stylua src` and `selene src` must both be clean.
5. Rebuild the map in Studio (edit mode) with the SharedOverride clone shown in the build-map skill; the self-check must report 0 problems.
6. Check NPC routes with `Tools/NavReport` in a playtest, with NPC role counts set to 0 in Studio's copy of `GameConfig` only (a crowd blocks
   pathfinding); restore them afterwards.

## Testing and tooling gotchas
- A running playtest keeps the old code: **restart it after every change**. The NPC graph takes about 25 to 30 s to build after Play.
- `execute_luau` gives a fresh module copy. To see live server state, create a Script from `execute_luau` that requires the module and
  writes into a StringValue, then read it.
- A server-side `CFrame` set on a client-owned character snaps back; move the player from the **Client** datamodel.
- The game has no PlayerModule. To move a test character, use a `BindToRenderStep` calling `Humanoid:Move` with a world direction.
- Mouse input in a playtest works with the Studio mouse tool (give it a `moveTo` first and always release the button).
- Roblox's default camera builds each frame on the `camera.CFrame` it finds, so code must never assign absolute rotations
  (recoil is applied as a change per frame).
- Studio screenshots go blank unless the Studio window is in front. Do **not** launch Studio from computer-use (it opens a new instance).
- ProximityPrompts do not show under remote control. `Lighting.Technology` must be set to Future by hand.
- Write Node edit scripts to a file rather than long shell one-liners (quoting breaks). There is no Python.
- ffmpeg is installed (WinGet Gyan.FFmpeg): it can pull frames from reference videos.

## Outside the repo
- **ForgeGUI** (forgegui.com/create, AI game art) is the planned source of UI art at Step 19. The owner signed in in the
  desktop app's browser. Ask before each generation that spends credits and before downloading files.
- The Roblox place file and any Roblox uploads (images, meshes, sounds the owner uploads) live in Studio and on Roblox.
- Remote: `github.com/PrestonHenryCobb/project-dead-drop` (private; renamed from cover-story, the old URL redirects).
