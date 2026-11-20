# Client finish pass — 2026-11-20

## Weapon integration

Registered all 18 approved Hardware weapons, including Lattice's burst rifle and quiet taser, with local models,
handling and actual server-backed effects. Preserved the owner's Quiet = true correction. The burst uses the
existing per-round cadence; empty magazines cancel any unfinished burst. Taser impact prediction respects its
25-stud range. Confirmed taser hits suppress ability/gadget requests and show lockout feedback; gadget slot hints
now choose the current device through InputHints. Status duration is measured from receipt because the existing
packet supplies no absolute deadline.

Flagged tracker glows render through walls for the authorized receiver. Flare glows remain occluded; overlapping
effects retain independent permissions and expiry. All temporary weapon effects now clear at Lobby/Insertion.
Moved TrackerBurstGapFraction to Combat, matching the server's reader, rather than its incorrect nested location
inside WeaponEffects. PendingWeaponDefs is empty again. No server gameplay logic or remote changes.

Validation: source/diff review and StyLua formatting only. The owner requested no tests, lint, builds or desktop/
Studio control. Native acceptance remains: unlock/select both Lattice choices, fire/reload/aim, confirm three-round
bursts and quiet taser behavior, test 25-stud cutoff and victim lockout, inspect shooter-only tracker versus flare
behind walls, and return to Lobby with effects active. Existing SPEC-QUESTIONs: inside-burst 900 RPM, taser head
multiplier 1 and initial client handling/model proportions. Third-person weapon selection still needs a public
visible-loadout contract; the client must not infer it from hidden identity data.

## Continuing client integration

The next commit covers existing Asset draft/deploy UI, pings, gamepad flight and gameplay input guards, plus the
device-hint/cutoff issues found in this pass. These are source implementations, not a claim of runtime acceptance.
