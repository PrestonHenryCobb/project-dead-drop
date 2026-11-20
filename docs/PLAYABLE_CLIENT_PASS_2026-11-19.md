# Client playability pass — 2026-11-19

Owner authorization: continuous work alongside Claude, no tests, no Studio automation, no desktop control.
This report covers Codex changes only. Existing uncommitted takedown wall-tuck work was preserved.

## Built

| Files | Result |
|---|---|
| `src/client/Menu/AssetDraft.luau` | Assigning an already used Asset swaps slots. Clearing preserves rarity positions with a local empty-string sentinel. `selection()` returns only four valid, distinct picks; incomplete drafts never cross the wire. |
| `src/client/Menu/Views/AssetsCodexView.luau` | Per-slot clear buttons, explicit empty states, enabled swap choices and incomplete-draft guidance. |
| `src/client/Menu/LobbyViews/PlayLobbyView.luau` | Deploy stays visible outside the scrolling rail, rejects incomplete drafts and links to Assets. Retry task is cancelled on unmount. Refreshes preserve scroll and gamepad focus. |
| `src/client/Menu/LobbyViews/PreDeployView.luau` | Lock In stays visible; incomplete picks show a reason. Four rarity controls cycle/swap Assets during selection, including when a teammate queued someone with an incomplete draft. Requests still require a complete selection and an unexpired server selection window. |
| `src/client/Controllers/HeldItemController.luau` | Shared input eligibility covers text entry, window focus, Roblox menu, client modal owners, incapacitation, inactive match phases, extraction and missing character/camera. Blocked input passes both press and release through to UI/spectator controls while cancelling held weapon inputs. |
| `src/client/Controllers/WeaponController.luau` | Reload/melee use the same input gate; automatic fire, aim and melee cancel while blocked. Lobby/Results suppress prediction as Insertion already did. Existing current-wall-only accepted-takedown handling remains intact. |
| `src/client/Controllers/AbilityController.luau` | Ability requests use the shared gate; old cooldown state clears at Lobby. |
| `src/client/Controllers/GadgetController.luau` | Equip/deploy/alternate use the shared gate. Unavailable/redundant slot requests are skipped; old round state clears at Lobby/Results. |
| `src/client/Controllers/DisguiseController.luau` | Scan/disguise/sprint/crouch use the shared gate. Focus loss, text entry, menu opening and character removal release scan/sprint/crouch; temporary crouch tracks are destroyed. |
| `src/client/Controllers/MovementController.luau` | Movement/jump respect input blockers; inactive phases explicitly zero movement. Downed crawl still reads the existing shared movement direction. |
| `src/client/Controllers/IntelController.luau`, `PackageController.luau`, `DownedController.luau`, `SecurityInteractController.luau` | Contextual objective interactions stop targeting/holding through modal UI or the Roblox menu, using their existing cancellation paths. Drone interaction origins remain unchanged. |
| `src/client/Controllers/CarrierTrackController.luau` | Tracking requests/holds stop through blocked UI; incoming tracked-rival warning cues remain independent. |
| `src/client/Controllers/BlendWheelController.luau` | Wheel blocks combat and movement, closes on focus/character/camera loss and restores its camera/mouse state. Connections, bindings, GUI and temporary emote tracks have cleanup. It cannot open during Sparrow piloting. |
| `src/client/Controllers/DroneController.luau` | Generation guards prevent a yielded drone lookup from starting after a stop/death/round transition. Removed drone parts release the camera; UI/focus loss sends zero movement and releases mouse lock. |
| `src/client/Controllers/SpectateController.luau` | Spectator orbit/drone input and mouse lock respect text entry, modal UI, window focus and Roblox menu. |
| `src/client/Controllers/CombatHudController.luau` | Normal vitals/ammo hide when the owner cannot participate; reticles hide through modal input. Respawn clears old damage markers/hit feedback. |
| `src/client/Controllers/MenuController.luau` | Server notifications appear in the menu footer while the gameplay toast is hidden, including refused deployment reasons. |
| `src/client/Combat/SoundPlayer.luau` | Pooled world emitters survive camera replacement. Preload failure still destroys temporary sounds; repeated IDs are coalesced, reused voices are stopped before replay, and pools have teardown cleanup. |

## Running

Rojo was not running. Started hidden with `rojo serve default.project.json`; it reported localhost port 34872.
Process at launch: 29728. Logs are `%TEMP%/cover-story-codex-rojo.stdout.log` and `.stderr.log`.
No Studio window or desktop input was used. Plugin connection was not changed or observed.

## Validation and gaps

Only changed-file StyLua formatting and source inspection were performed. No tests, lint suites, Rojo build,
Studio playtests, multiplayer checks or performance measurements were run, per the owner.
These changes are implemented but runtime/native UI acceptance is unverified; this is not a claim that a full match passed.
The Sparrow controller's existing keyboard/mouse-only flight and proximity-based own-drone discovery remain.
The third-person weapon renderer's existing default-weapon-only limitation remains; no hidden loadout metadata was added.
No server files, remotes, shared types, gameplay balance, save data or new mechanics were changed by Codex.

## Coordination and next

`assets-swap`, `playable-input` and `playable-audio` are READY_FOR_REVIEW. Codex file locks are released.
No commit or push was made. Claude's concurrent server work and pre-existing edits were retained.
No new SPEC-QUESTIONs. BUILD_ORDER's remaining native acceptance/performance work is deferred under the no-tests instruction.

## Continuation: team pings

Added `src/client/Controllers/PingController.luau` and the presentation-only `GameConfig.PingHud` section against
Claude's `.ai-sync/PING_CONTRACT.md`. Middle mouse sends a contextual Look/Suspect/Intel request; Alt+middle mouse
requests Danger. Pad chords are LT+DPadRight for contextual ping, LT+RB for Danger, preserving unmodified gadget/GPS
bindings. Basic touch buttons and device-specific hints are included. Camera-center raycasts use the default collision
group so characters remain aimable despite their noncolliding character group.

Only server-confirmed PingPlaced markers are shown, with strict ExpiresAt expiry, PingCleared replacement/removal,
bounded count, public body-name following for Suspect, source display name, distance and authored floor hints.
Anchors and billboards live in a client-only folder; nothing is parented to or written onto any character.
Markers clear at Lobby/Insertion/Results. Appearance is static for both ordinary and Reduce Motion preferences.
No server, range, duration, count or gameplay changes. No tests/playtests or lint/build commands; source read and
changed-file formatting only. Gamepad chords and UI appearance remain unverified in Studio.

## Continuation: settings, replay, cameras and flight

- `Controllers/SettingsController.luau`, `Menu/Components/SettingsPanel.luau`: F10 opens session settings in play or
  from the lobby. FOV uses existing 70–100 limits; mouse sensitivity is adjustable; extra Reduce Motion never
  disables Roblox's preference. Graphics Auto/Low/Medium/High uses the existing controller. Reset, scrolling,
  fixed Close, gamepad back/focus recovery and a field-controls reference are included. Live refresh avoids
  repeatedly rebuilding unchanged button effects. Auto re-cover still uses confirmed server state. There is no
  claim that these local preferences persist across sessions. GraphicsController exposes its current mode;
  shared UiAccessibility accepts the extra comfort preference.
- `MenuController`: fixes the reviewer-reported Lobby/character-removal race in either arrival order, permits a
  dead/removing old body and retries on Character changes. Closing clears old predeploy/history state, preventing
  a blank second-match lobby. The menu only reopens on a server-confirmed Lobby, not ordinary mid-match death.
- `Combat/CameraGuard.luau`, BugCam/Drone/Spectate/BlendWheel/Weapon/Settings controllers: ending a view does not
  override the reopened menu or another remote view. Obsolete Bug Cams stop at life/round boundaries, show a
  next/exit control, and prevent body input. Sparrow similarly blocks body combat while explicitly retaining
  drone-origin Intel/security interactions. Gun/ammo/arm posing are suppressed remotely while vitals remain.
  Weapon FOV restoration no longer overwrites the menu stage.
- `Combat/FlightInput.luau`, Drone/Spectate controllers: filtered left/right sticks, A/B height and device hints;
  spectator LB/RB cycles, Y changes drone mode and L3 boosts. Analog magnitude is preserved and combined input
  remains bounded. No server flight speed/range/volume change.
- `CameraComfortController.luau`: the existing optional comfort ticket is implemented, off by default, using
  confirmed damage/takedown messages. Brief pitch/yaw only; no roll/blur or weapon recoil-variable changes.
  Its own last transform is removed before the native camera and never restored over a changed/new camera.
  Reduced Motion, UI, remote views and incapacitation suppress it. The settings toggle and reset are wired.
- Intel/Package/Downed/SecurityInteract/Elevator priorities explicitly outrank gamepad reload for valid
  contextual actions. Takedown hints, GPS controls and knife prompts respect input blockers. Intel ping context
  recognizes nearby authored screen/keypad trim without classifying all props in the room as a station.
- `Menu/RequestFeedback.luau`, ViewKit, PlayLobbyView, AgentsView: readable refusal messages and visible pending/
  failure feedback for free-agent claims, with async lifetime guards. Built abilities no longer say they are
  in development. No optimistic profile/inventory updates.

The new `GameConfig` sections are PingHud, ClientSettings, ClientFlight and CameraComfort. No server code/remotes/
types, save contract or gameplay stats were changed by Codex. Existing work remains uncommitted and no push was made.
No tests, lint suites, builds or Studio operations were run. Every new/changed Luau file in this continuation was
formatted with StyLua; review was by reading source only. Native layout, gamepad feel, camera timing and multiplayer
remain unverified, as requested. Rojo was observed still running.

New SPEC-QUESTIONs: initial 150 degrees/sec stick look and optional 0.2 s / 0.18-degree damage / 0.12-degree takedown
camera feedback are local presentation tuning. Recoil values and server action timings are unchanged.

Server-owner handoffs are recorded in TASK_QUEUE: Lattice's two remaining Hardware need tracker/taser contracts
before registration, and living team chat needs authoritative recipients/filtering. Neither feature is represented
as implemented here. Next BUILD_ORDER work includes the remaining Step 8 Lattice integration, Step 19/20 polish
and native Step 24 acceptance when the owner's no-tests constraint is lifted.

## Focused follow-up: menu-spectate-latejoin

Changed only `src/client/Controllers/MenuController.luau` in gameplay code, with its lock acquired first.
The menu now subscribes to spectator state before loading views. An active mode closes the menu, destroys its
stage/tween, removes menu action bindings and restores the saved HUD enabled states, including SpectateHud.
Startup and subsequent lobby-open attempts are suppressed while spectating; a generation guard prevents a
menu waiting for PlayerGui from completing after the spectator handoff.

Transition to None allows a menu return without waiting for a Lobby phase; Lobby also clears spectator suppression.
The existing dead/removing-body and Character replication-order guards remain, with live-character/rescue guards
so a new life does not bring the menu back. Lobby/Insertion/Results reject delayed active spectator packets in
the same manner as SpectateController. Opening the menu releases any in-match settings modal first.

No server, SpectateController, remote or shared-contract changes. StyLua formatting and manual source inspection
only; no tests, lint/build commands or Studio/desktop control. Native late-join camera/HUD acceptance is unverified.
No new SPEC-QUESTION. Ready for review alongside the existing menu-reopen-race changes; no commit or push.

## Profile retry, combat volume and modal focus continuation

Profile failure now offers RETRY PROFILE in the menu footer. Duplicate fetches are gated; menu generations discard
closed-menu replies, and newer profile pushes win over older requests. Retry remains available without rejoining.
Settings includes a session combat-effects volume stepper, including mute, through a local SoundGroup for both
SoundPlayer pools. Existing authored levels and separate tracking cues remain intact; reset restores the default.
Supply and elevator callbacks no longer act through foreground settings or steal its gamepad focus on refresh.
Input blockers follow ScreenGui display order, then opening order; remote views remain behind interface dialogs.
Closing settings restores surviving selection or lets the underlying dialog select a usable button.

Source inspection and StyLua formatting only. No tests, lint, builds or desktop/Studio control. Native acceptance
still needs profile failure/retry, stale profile replies, volume changes during playback and gamepad settings over
Supply/elevator. No new SPEC-QUESTION; all three tickets are ready for review, uncommitted.

## Final Hardware integration: 8.5c-client

Read Claude's 8.5c server contract and the revised owner-approved weapon table. Registered LatticeBurstRifle and
LatticeTaser in WeaponDefs with nonzero spread/recoil, aim zoom, handling and original local models. PendingWeaponDefs
is empty again. All 18 Hardware choices now have registered definitions and first-person/Armory builders; existing
mastery/loadout validation still decides availability. The rifle uses the existing per-round burst prediction and
FireRequest cadence; releasing the trigger completes the burst, while UI/obstruction/reload cancels it. Emptying
the last reserve magazine now clears the pending burst so dry clicks cannot continue after trigger release.

Taser map-impact prediction and tracer endpoints respect MaxRange (25 studs). The existing private TargetGlow
receiver already draws the tracker with line of sight, server-clock expiry and client-owned Highlights; no new
character metadata or enemy discovery was added. TaserStatusController consumes victim-only CombatStatus and exposes
the confirmed slowdown plus ability/gadget lockout. HUDs show LOCKED countdowns and the movement-slowed caption;
ability and gadget input suppress requests until the local countdown ends. Server authority is unchanged. Timers
use event receipt time because this contract has no absolute status deadline; feedback may end slightly later than
the server lock. Death, new life and round boundaries clear presentation. Armory summaries explain burst timing,
private marks, taser range, slow and kit lock rather than presenting the burst as sustained 900 RPM fire.

Manual source inspection and StyLua formatting only; no tests, lint/builds or Studio/desktop control. Native review
remains: select both Hardware after unlocking, confirm their models/aim/reload, three rounds per trigger, private
tracker visibility with a second player, taser range cutoff and victim feedback recovery. Existing server contract
SPEC-QUESTIONs remain: 900 RPM inside the burst, line-of-sight tracker, taser head multiplier 1 and normal shot noise.
Client handling/model proportions are initial tuning. Third-person weapons still use the preexisting default weapon
because there is no authorized visible-loadout contract; no hidden roster inference was introduced. No commit/push.

## Owner correction: tracker-through-walls (2026-11-20)

WeaponEffects now renders only explicitly flagged ThroughWalls marks with AlwaysOnTop and bypasses their local
line-of-sight ray. Unflagged flare glows remain Occluded and retain the ray check. Entries are keyed by body and
visibility permission, so overlapping flare/tracker packets refresh their own expiry without extending or removing
the other effect's permission. Existing target resolution, server-clock expiry and local-folder ownership remain.
Armory tracker copy now says THROUGH WALLS. This supersedes the earlier line-of-sight tracker limitation above.
The owner's WeaponDefs taser Quiet = true edit is preserved; it supersedes the earlier normal-noise assumption.

StyLua formatting and manual source inspection only; no tests or Studio/desktop control. Native acceptance remains:
shooter-only tracker behind a wall, occluded flare, overlapping marks with different expiry times, and refresh in
either arrival order. No new SPEC-QUESTION. Ticket ready for review; changes remain uncommitted.
