# Body interaction client review — 2026-10-28

Continuation of Step 9 client correctness while Claude works on security.

## Changed files

- `src/client/Controllers/DownedController.luau`: revive/execute input requires active gameplay, a living non-downed,
  non-eliminated local character, an available camera and normal input focus. A key press rechecks generic body
  posture, range, facing and LOS. Invalid callbacks return Pass. Ineligible transitions cancel a held action once.
  Server-completed Revive/Execute holds release locally without spurious cancellation. Crawl traffic stops outside
  gameplay and during extraction success. Janitor owns all connections/action cleanup. Animation tracks are destroyed
  when released, and delayed death transitions are cancelled and invalidated on respawn, round end and teardown.
- `tools/check-body-input.cjs`: actual-source input, crawl, geometry, animation scheduling and teardown coverage.
- `.ai-sync/TASK_QUEUE.md`: continuation status and validation.

Server revive/execute rules, movement, remotes, shared config/types, security and bot files were not edited.
No identity metadata is added to any rig. The client still submits generic Body requests for both players and NPCs.

## Validation

93 new actual-source assertions pass; 1,356 across nine checked client suites. Coverage includes stale targeting,
phase/life/focus transitions, missing roots, extraction freeze, acknowledgement labels, crawl direction/stop traffic,
death-pose completion, delayed-pose cancellation, animation disposal and subscription teardown.
Changed-file StyLua, full-source `stylua --check src`, `selene src` and Rojo build pass.
No new native Studio playtest was run; fixtures cannot verify render appearance, native action priority or networking.

## How to test in Studio

1. Two-player Duos: down a teammate, approach within the existing body interaction range, face them and hold E.
   The server should show Revive and finish normally. Release early and restart. Repeat on a rival/NPC for Execute.
2. Hold E, then switch windows or focus a text field: the hold stops. Returning requires a new E press. Move or turn
   away before pressing E to check that stale targeting does not start an action or capture another contextual action.
3. Down/eliminate the helper during a hold: their interaction stops. A phase change must not restore it; revival or
   a normal respawn should restore only the appropriate life state. Spectating must not offer a body interaction.
4. While downed, crawl then stop: existing movement and poses should remain correct. Results and extraction success
   should stop crawl requests/body interactions. After respawn, no delayed dead pose should appear on the new rig.
5. Solo elimination: the normal fall should still settle to the dead pose when the old rig remains present.

## Gaps, questions and next

Native animation transitions and multiplayer/input overlap need Studio acceptance. Existing generic lying-body
discovery and server revive/execute classification are preserved. No new contract mismatch or SPEC-QUESTION found.
Ready for the remaining Step 9 multiplayer acceptance checks; Claude's security work needs no handoff from this patch.
