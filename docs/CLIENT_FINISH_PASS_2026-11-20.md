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

## Gameplay and menu integration

Finished the existing client pass: swapping/clearing Asset rarity slots with dense empty drafts, complete-selection
gates before Deploy/Lock In, fixed action regions outside scrolling rails, inline Asset repair during selection,
profile-safe focus/scroll retention, readable request failures and guarded free-agent claims. The selection window
remains editable until the server cutoff; the Lock In button now disables and says SELECTION CLOSED when it expires.

Integrated team pings, gamepad Sparrow/spectator flight and body-action/UI gates. Remote views suppress body
movement/weapons; Sparrow Intel/security interactions still use the remote origin. Contextual actions outrank
gamepad reload. Knife/takedown prompts respect gameplay availability; HUD hit feedback resets for a new life.
Disguise scans, crouch/sprint and the blend wheel cancel on focus/life/UI changes with camera restoration guards.

Migrated remaining control hints in gadget slots, stored disguises, takedowns, flight, spectator controls/chat and
pings to InputHints. Stored disguises refresh when the device changes; gadget cards show D-pad cycling on gamepad.
Spectator chat now passes Enter through foreground dialogs and checks again before its deferred focus capture,
so opening settings cannot have its selection/focus stolen by the spectator chat shortcut.

Native acceptance remains: swap/clear/fill Assets and try Deploy, revise a locked selection before/after cutoff,
claim a free agent through a delayed request, switch devices while hints are visible, fly Sparrow/spectator with
analog controls, ping Intel/people/surfaces and confirm teammate-only delivery, open/close settings over each view,
and perform objective interactions with X without reloading. No tests or runtime/desktop operations were performed.
No new gameplay mechanics or SPEC-QUESTIONs; stick/camera handling retains the earlier initial-tuning caveat.

## Remaining work that needs owner/server acceptance

The source now contains the complete client vertical slice described above; native gameplay is still unverified.
Two-player combat/identity permissions, full-round completion and gamepad feel need native acceptance when the
owner resumes testing. Broader unfinished systems remain server/art scope: living team-chat filtering, the public
visible-loadout contract for third-person weapons, authored audio, tutorial references, account rewards/catalogues
and matchmaking. These are not represented as finished by the client. No push is requested.
