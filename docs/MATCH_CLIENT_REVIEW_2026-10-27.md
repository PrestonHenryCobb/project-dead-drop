# Match client integration (10b / 10c)

Built against `.ai-sync/MATCH_CONTRACT.md`, server commit `77077ff`. No Studio playtest, per owner instruction.

## What changed

- `src/client/Controllers/MatchController.luau`: server-timed phase banner, insertion blackout fading over the actual
  insertion interval, private briefing (mode, team color, player/team totals and the Intel/Vault/Package/extract line),
  main timer, ready-team lobby wait, winner/Mission Failed scoreboard and return countdown.
- `src/client/Combat/MatchPresentation.luau`: pure projection of PhaseChanged data. No local transitions or fabricated
  clock when the server supplies no deadline. Brief and result data are only presented in their appropriate phases.
- `src/client/Controllers/TeammateMarkerController.luau`: diamond and outline for living private-roster teammates.
  Client-owned folder contains every visual; only Adornee references a character. No world population scan, enemy
  discovery, self-marker, tag, attribute or child on a character. Follows replacement rigs, hides dead/missing rigs,
  removes departed roster members, and hides in Lobby/Results. Downed but living teammates remain marked.
- `src/client/Controllers/WeaponController.luau`: blocks prediction during Insertion, clears held/burst/aim/reload
  state and hides the model. Separate phase and incapacitation flags ensure Infiltration cannot revive a downed
  player or carry a held trigger through the freeze. This closes a source-detected mismatch: server rejection alone
  prevented damage but still allowed local firing audio, recoil and ammo prediction during Insertion.
- `src/shared/GameConfig.luau`: MatchHud presentation dimensions, marker appearance and display order only.
- `tools/check-match-client.cjs`: actual presentation/controller source with deterministic clock/UI/service fixtures.
- `tools/check-weapon-clients.cjs`: insertion gate regression cases added to existing source-based tests.
- `.ai-sync/TASK_QUEUE.md`: review status and this handoff. Existing unrelated edits are preserved.

No match/service logic, shared types, remotes or MenuController changes. No local prediction of score or match outcome.
Player display names/agent/team results are rendered as plain text only after the server's Results payload.

## Verification

- Changed Luau files pass StyLua and Selene.
- Match suite: **39 assertions**, including clock expiry, waiting at a zero fill timer, phase-data privacy, scoreboard
  cleanup, listener teardown, private roster filtering, living/downed/dead rigs, respawn and roster/color changes.
- Weapon suite: **225 assertions**, including frozen-input suppression, clearing queued inputs/reloads and preserving
  incapacitation on phase release.
- Rojo build passes. Fixtures do not verify engine rendering, actual viewport bounds or multiplayer replication.

## Later Studio acceptance (not run)

1. Deploy solo with FastMatchStart: after select, see the eight-second briefing/fade; firing, aiming, reloading and V
   must predict nothing while frozen. Infiltration starts the main timer and shows its banner for three seconds.
2. Release and repress fire after insertion; verify no held shot is queued across the freeze. Infiltration while
   downed must not reactivate weapons. Reload/camera/respawn regressions remain part of weapon acceptance.
3. With FastMatchStart off and fewer than the required teams, see the private ready count/fill countdown above the
   menu. Reaching zero must still say waiting if the server has not started insertion.
4. Four clients in Duos: each sees only their living partner's diamond/outline through walls; no own/enemy marker.
   Downed partner remains marked, eliminated partner loses it, new character/disguise follows the new rig.
5. Force a short main timer in a Studio-only config copy: Mission Failed, scrolling result roster, return countdown,
   then Lobby/menu. Repeat a full second cycle; no stale scoreboard/banner/markers. Also exercise server winner data.
6. Check 1280x720 plus narrow/wide windows and Reduce Motion. Long scoreboard names truncate without RichText parsing.

## Gaps, questions and coordination

Engine visuals and network timing remain unverified because the owner explicitly requested no playtest. Source checks
do not promote this work to DONE. Presentation values are initial tuning; no new gameplay decision was made.

The server owns phase transitions, fill eligibility and results. The client does not fabricate kills/objective stats,
world resets, mid-match takeover or matchmaking. Initial UI waits for server data instead of assuming a match phase.

Claude has since supplied Intel/Vault contracts. The next client work is the queued Intel/Vault HUD against those
contracts; server changes stay with Claude. Keep round-state changes documented and avoid both agents editing the
same contract/config at once. No playtest is needed to continue source work.
