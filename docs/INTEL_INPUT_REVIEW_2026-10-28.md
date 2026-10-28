# Intel client input review — 2026-10-28

Source-confirmed correctness continuation of Codex's Step 11 client work while Claude develops bots.

## Files changed

- `src/client/Controllers/IntelController.luau`: contextual E and pooled station glints now require an active gameplay
  phase, living local character, usable camera and normal input focus. Downed/eliminated state is independent of phase;
  Revived does not clear elimination. Extraction's cinematic also suppresses input and glints.
  Key press rechecks current target membership, ID, used state, reach, aim and existing line-of-sight rule.
  Stream-out cancels a held hack on that station. Inactive server Hack acknowledgement releases the local hold without
  sending an unnecessary cancellation. Janitor owns every connection, the client visual folder, binding and caches.
- `tools/check-intel-input.cjs`: actual controller source tests using deterministic Roblox service/geometry fixtures.
- `.ai-sync/TASK_QUEUE.md`: continuation status and validation.

No character/NPC metadata, server files, shared config, remotes, types or bot code changed.

## Checks

104 new assertions pass, including live/stale input, facing, range, occlusion, the existing station-stand LOS exception,
all gameplay phases, downed/revived/eliminated/respawn transitions, text/window focus, health, camera and character
loss, extraction freeze, completed Hack acknowledgement, stream-out/in, private updates, bounded pooled glints,
round resets and complete teardown. All eight checked client suites pass: 1,263 assertions total.

Changed-file StyLua formatting, full-source `stylua --check src`, `selene src` and Rojo build pass.
No new Studio playtest was run. Fixtures do not validate native action priority, rendering or network timing.

## How to test in Studio

1. Solo, fresh Play: deploy and wait for Infiltration. An untaken station should glint within 25 studs. Look toward it
   within 5 studs and hold E: Hack progress and private Intel rewards behave as before. Taken stations stop glinting.
2. Cancel by releasing E; resume to verify the server's retained progress. Move away or turn before pressing E again:
   stale client targeting must not start a hack or swallow another contextual action.
3. Hold E and focus a text field or switch windows: the hold stops and glints clear. Return and press E afresh.
   Leave gameplay for Results/Lobby: no lingering station glints or Intel E binding should remain.
4. Two-player Duos: down an agent while hacking. Their Intel input/glints stop. Revival restores eligibility;
   elimination keeps it disabled while spectating. A new character restores normal behavior in the next gameplay phase.
5. During an extraction success cinematic, Intel input/glints stop even before Results arrives.

## Limits, questions and next

Clearance, hack duration/progress retention, spending/rewards, slack and final LOS validation remain server-owned.
The pre-existing own-station-folder LOS exception matches current IntelService and is preserved. No mismatch found
between the reviewed contract and server interaction path. The client still uses the existing contextual action
priority; overlap with body/Package actions needs native Studio acceptance. No SPEC-QUESTION added.

Ready for Step 11 client review and the remaining multiplayer acceptance checks. Claude's bot work needs no change
or handoff from this patch.
