# Auto re-cover HUD — 2026-10-28

Built against `.ai-sync/AUTO_RECOVER_CONTRACT.md`. Client only; no server/shared-contract changes.

## What was built

- `src/client/Controllers/CoverController.luau`: an accent-colored re-cover bar occupies the existing Cover meter
  while AutoRecoverController.state().Active is true, with a RE-COVERING caption. Progress uses only the returned
  receipt timestamp and Seconds. It clamps at full until the server ends Active; cancellation restores the original
  suspicion meter/caption. No new layout footprint, guessed delay, easing, flash or completion prediction.
- `src/client/Menu/Components/SettingsPanel.luau`: session Settings modal with Auto re-cover ON/OFF. It reads Enabled
  from the same controller (defaulting to Cover.AutoRecoverDefault before the first record), sends only
  RequestAutoRecover(boolean), and never changes the displayed value optimistically. H-driven state changes are
  reflected too. Existing MenuTheme styling, focus restoration, Back/B and complete lifetime cleanup are retained.
- `src/client/Controllers/MenuController.luau`: Settings entry in the footer without adding a main tab or changing
  navigation types. Back closes the modal first; section cycling cannot navigate behind it; menu close cleans it up.
- `tools/check-auto-recover-hud.cjs`: actual controller receipt timing, Cover refresh, modal and menu entry/back tests.
- `.ai-sync/TASK_QUEUE.md`: status and handoff.

## Validation

Changed-file StyLua, full-source `stylua --check src`, `selene src` and Rojo build pass. 30 new assertions pass;
1,541 across thirteen checked client suites. Checks cover default-on/confirmed-off state, boolean-only requests,
no optimistic toggle, exact receipt time, reported duration rather than config fallback, clamped progress,
server-owned completion/cancellation, modal focus/entry/back, duplicate-open prevention and teardown.
The bar uses functional progress only; no decorative motion is introduced. Native Studio rendering/input remains
unverified by these fixtures.

## How to test in Studio

1. Solo, fresh Play: from the lobby footer open SETTINGS. Auto re-cover initially shows ON. Toggle OFF/ON and verify
   the label follows the server response. Close with the button or B/Backspace; check ordinary menu navigation returns.
2. Deploy, become Exposed, then meet the server's re-cover conditions. The existing Cover indicator should say
   RE-COVERING and fill its bar over the received Seconds (currently 1.5). It returns to the normal meter when the
   server ends Active. Being seen/entering lockout or pressing G must cancel it on the server's message.
3. Press H to disable: no automatic re-cover bar should start. Return to the lobby Settings panel and verify OFF.
   Turn it back on. The preference is session-only; no persistence is added.
4. With Roblox Reduce Motion enabled, functional progress still fills, without decorative flashes or easing.
   Check 1280x720 and larger windows: the Cover footprint is unchanged and the footer Settings button is accessible.
5. Two players: repeat while the other player causes lockout/visibility changes; ensure the HUD never completes
   re-cover locally or changes the server's eligibility/timing.

## Gaps, SPEC-QUESTIONs and next

Native layout/focus and multiplayer cancellation timing need Studio acceptance. Settings is reached through the
existing lobby/agent-select menu; H remains the in-match shortcut. No in-match pause menu or persistence was added.
No new SPEC-QUESTION or contract mismatch found. Ready for auto-recover-hud Studio acceptance; no next ticket or push.
