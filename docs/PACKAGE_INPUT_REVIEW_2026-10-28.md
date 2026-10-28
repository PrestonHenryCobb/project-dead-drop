# Package contextual input review — 2026-10-28

Continuation of Codex 13b: source-confirmed input bugs in the existing Package controller.

## Files changed

- `src/client/Controllers/PackageController.luau`: restrict contextual objective input to PackageHeist/Overtime,
  a living, non-downed, non-eliminated local character and unfocused text input. Cancel active holds once when
  those conditions stop, window focus is lost, a character is replaced or extraction reaches Extracted.
  Revalidate on key press; invalid stale callbacks return Pass. Unrelated extraction terminals no longer capture E.
  Match existing server pad-height and repeat-call checks using existing config and private team state.
  Janitor owns every subscription, both action bindings and cached state.
- `tools/check-package-input.cjs`: execute actual controller source with deterministic service/input fixtures.
- `.ai-sync/TASK_QUEUE.md`: record this continuation and its validation.

## Validation

Changed-file formatting, full-source `stylua --check src`, `selene src` and Rojo build pass.
82 new actual-source assertions cover stale callbacks, public Package pickup beside a terminal, carrier/team call
eligibility, running extractions, zone height, Overtime, phase changes, downed/eliminated/revived/respawn transitions,
focus, health, cinematic freeze, cancellation count and complete teardown. Existing suites pass:
673 data + 228 weapons + 41 match + 29 objectives + 30 Package + 76 floor markers; 1,159 assertions including input.
Fixtures do not verify native Roblox ContextActionService ordering or networking. No new Studio playtest was run.

## Later Studio checks

1. Solo: reach PackageHeist. At an extraction terminal without the Package, E must remain available for other
   contextual actions. Take a Package beside the terminal: the pickup must work. Carry it to the terminal and call.
2. During Countdown, E must not attempt another call for your team; X still drops. In Open, E channels only on the
   actual pad level, not on another floor above it. Results/cinematic must stop objective input.
3. Hold an objective action, then focus a text field or switch windows. The hold cancels; returning requires a new
   key press. Typing X must not drop the Package. Resume normal pickup/call/channel/drop afterward.
4. Two-player Duos: down or eliminate a carrier while holding E. Input stops; changing phase must not revive it.
   Revive a downed player or respawn normally and verify eligible interactions return without stuck E/X bindings.

## Gaps, contract notes and next

Server remains authoritative, including exact teammate-to-carrier distance and living pass-recipient selection.
The client does not discover a carrier's identity or add anything to rigs. Existing Intel/body contextual bindings
have independent lifecycle handling and were not changed here. Their relative native input priority still needs
Studio acceptance. No contract/server mismatch found and no SPEC-QUESTION added. No Claude server action required.
Ready for owner review of 13b input fixes alongside named-floor markers; Claude's bot work can continue independently.
