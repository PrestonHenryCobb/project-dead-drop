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
owner resumes testing. Broader unfinished systems remain server/art scope: the public
visible-loadout contract for third-person weapons, authored audio, tutorial references, purchase catalogues
and matchmaking. These are not represented as finished by the client. No push is requested.

## Account reward presentation — 21-rewards-client

Read REWARDS_CONTRACT.md and the now-committed server settlement path. MatchRewardsView shows the player's
actual XP lines in earned order, total XP, confirmed level/progress, level-up notice and separate level/win/daily
Credit awards above the final roster. It retains a packet arriving before Results, displays one arriving afterward,
and clears at Lobby/Insertion. No profile mutation, client award requests or estimated payouts. Results scrolling
is selectable on gamepad, and selection releases on the next phase. Profile's header now shows account XP and a
progress bar from the confirmed Level/XP and the server's configured threshold; later content shifts to make room.

Source review and StyLua only. Native checks remain: results/reward arrival in either order, repeat XP events in
order, level-up versus no level-up, first-win Credits, long scoreboards on gamepad, Profile updates and a second
round with no stale reward details. No new SPEC-QUESTION. The rewards service and team-chat filtering are now
server implementations supplied by Claude, superseding the earlier server follow-up list in the older report.

## Secret-exit client — 7B-secret-exits-client

Read SECRET_EXIT_CONTRACT.md and the server's lever-side geometry/hold rules. SecurityInteract now discovers
SecretExitTrigger levers and tracks their streamed panel partners. The existing client-only outline and InputHints
prompt offer Pull the lever only near a shut paired panel, on the lever's inside side, facing it, with a clear body
and camera line of sight. Sparrow does not offer a physical lever action. The existing RequestInteract path sends
SecretExit and ExitId; SecurityHud recognizes both the kind and the server's Pull the lever progress label.
Panel tags can arrive in either order or stream out/in. No character metadata, extra remote or optimistic door
opening. Looking at a different target cancels the old hold; pressing Interact rechecks eligibility immediately,
including a modal that opened since the last targeting refresh. The server still owns timing and panel behavior.

Source review and StyLua only. Native checks remain: inside near/facing versus outside/obstructed/out-of-range,
keyboard E and gamepad X hints/hold, look-away cancellation, streamed panel/lever arrival, already-open doorway,
and settings/Sparrow suppression. Server tuning questions remain the contract's 1.5 s hold, 12 s open and 4-stud/
50-degree reach/facing. NPC/GPS routing and door audio/animation remain outside this client ticket.

## Camera-feed foreground input follow-up

A second client source pass found Camera Room feed paging checked only text-box focus. Both the feed button and
its keyboard/gamepad shortcut now use the shared remote-aware input gate, so Settings, native menus, lost window
focus and newer dialogs block manual paging. Sparrow's authorized remote interaction path remains usable.
Automatic feed rotation and all server feed permissions/timers remain unchanged. StyLua/source inspection only;
native check: try the feed shortcut with Settings open, close it, then try it while using the Sparrow terminal path.
