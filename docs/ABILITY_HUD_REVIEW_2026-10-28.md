# Ability/disguise HUD — ticket 16-hud, 2026-10-28

Built against `.ai-sync/ABILITY_CONTRACT.md`. Client only; no server, shared config, remote or type edits.

## What was built

- `src/client/Controllers/AbilityHudController.luau`: HudTheme/HudKit panel above ammo, showing the configured ability
  key and `AbilityController.cooldown().Name`. Remaining time is `ReadyAt - workspace:GetServerTimeNow()`, rounded up
  for display; READY appears exactly at the deadline. No duplicate cooldown state, guessed name or predicted use.
  Hidden outside the match and before a confirmed record; previous-round records are suppressed until replaced.
  Uses a static countdown, with no decorative animation/easing/flashing in either Reduce Motion preference.
  Janitor owns its screen, phase subscription and render connection.
- `src/client/Controllers/DisguiseController.luau`: one numbered stored-look label per Slots entry, preserving order,
  empty/false entries and duplicate roles. Labels are reused, excess labels destroyed, and badge height follows the
  number of rows. Worn look, True Form, tier pips, scan and input behavior are preserved.
- `tools/check-ability-hud.cjs`: actual full controller source tests with UI/service fixtures and actual HUD geometry.
- `.ai-sync/TASK_QUEUE.md`: 16-hud status and validation.

## Verification

Changed-file StyLua formatting, full-source `stylua --check src`, `selene src` and Rojo build pass.
50 new assertions; 1,456 across eleven checked client suites. Tests cover server/local clock independence, fractional
deadlines, exact READY boundary, fresh packets, all match phases, stale prior-round state, controller cleanup,
empty/single/double/duplicate disguise slots, slot removal, True Form, and layout bounds at 1280x720/1920x1080/2560x1440.
One- and two-slot badge rows fit without overlapping the vitals panel; the ability panel avoids ammo and text overlap.
No new native Studio/rendering result is claimed.

## How to test in Studio

1. Solo, fresh Play, select Guise and Deploy: ability HUD shows Q / Quick Change and READY during the match.
   In a valid Quick Change situation, press Q: observe the server's 30-second countdown, then READY. A refused Q must
   not invent a cooldown. Lobby/Results must hide the panel; a new match must not show the old cooldown.
2. Scan two different disguises. Both numbered stored roles should appear, in slot order, including EMPTY before each
   slot is filled. Press G to cycle stored looks/insertion: the worn badge changes and both stored rows remain.
   Get Exposed: TRUE FORM appears while stored rows remain intact.
3. In a fresh match, select a one-slot agent: only one stored row should remain, with no stale second-slot text.
   Verify its confirmed ability name/deadline also displays when AbilityController receives it.
4. Compare 1280x720 and a larger viewport. The ability name/countdown must not overlap ammo; the two-slot badge must
   not overlap health/plates. Enable Roblox Reduce Motion: numeric feedback remains functional without animation.

## Known gaps, SPEC-QUESTIONs and next

Native typography/scaling and multiplayer timing still need Studio acceptance. READY describes cooldown completion;
the server retains all other ability eligibility rules. Badge layout covers the current one/two-slot contract.
No new SPEC-QUESTION or contract mismatch found. Ready for 16-hud Studio acceptance; no next ticket started or push.
