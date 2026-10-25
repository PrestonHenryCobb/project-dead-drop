# Client fixes and graphical HUD acceptance report

## Latest: interview complete and melee input fix (ticket 8.22)

All 35 design topics are answered or preserved by owner instruction. Latest comfort target: optional light cosmetic
shake, no forced roll/blur, actual recoil unchanged; minimum HUD 1280x720. Bugs take priority over combat/loadouts,
then menus. These comfort/settings requirements are recorded, not presented as already implemented preferences.

### What was built

| File | Change |
|---|---|
| `src/shared/Util/MeleeRules.luau` | Common advisory/server range, height, swing/rear cone and default charged damage rules |
| `src/shared/GameConfig.luau` | Takedown 6.5 studs / 90 degrees; ordinary reach unchanged; charge 50 after 0.75 s |
| `src/shared/Types.luau` | Additive Takedown/Charge/Strike owner acknowledgement kinds and optional server StartedAt |
| `src/server/Services/CombatService.luau` | Server press/release/cancel state; no preliminary strike; state/LOS/cone/cooldown checks, charge timing and friendly-fire rejection |
| `src/client/Controllers/WeaponController.luau` | No audio/hit prediction on V press; release/cancel routing, acknowledged strike sound/recovery, lifecycle cancellation and no queued fire through a hold |
| `src/client/Controllers/CombatHudController.luau` | Existing bar shows blue charge or red takedown progress from server time |
| `src/client/Controllers/TakedownHintController.luau` | Same shared acquisition geometry; private TeamRoster filters known teammates |
| `tools/check-melee.cjs`, `tools/tests/melee/` | Repeatable official-Luau runner: actual service/rule bodies and config, engine/service fixtures |

No new RemoteEvent names or character identity markers. Existing RequestMelee remains rate-limited by RemoteService.
The necessary server edits are part of co-owned R5/R6; Claude's return handoff identifies them to avoid duplicate work.

### Verification

StyLua source check, Selene source/fixture lint, Rojo build and diff checks pass. Run
`node tools/check-melee.cjs <path-to-official-luau-cli>`: 29 assertions cover tap/partial/full charge, range/cone/height
boundaries, no press damage, release/completion/cancel, wall/turn/damage/disguise/downed cancellation, cooldown,
repeat input, teammate protection and server-clock acknowledgements. This executes actual server decision code
with fixture vectors/services; it does not run Roblox physics, rendering, asset loading or network delivery.

### Studio acceptance (not executed by Codex)

1. Stop, sync Rojo (Shared/Server/Client), fresh **Play**. Wait for the crowd. Use a fresh, idle NPC for each damage test.
2. From the NPC's front, inside ordinary reach, **tap V**: no sound/hit on press; release deals 35. A full-health NPC
   starts at 50, so it survives one tap. Tap before the 0.8-second cooldown ends: no second hit.
3. With a fresh NPC in front, **hold V at least 0.75 s**, then release. The blue charge bar fills and caps; release
   deals 50, enough to down a full-health NPC. Keeping V held must not auto-strike or add damage beyond 50.
4. From behind a stationary NPC, within 6.5 studs and its 90-degree rear cone, press V: red takedown progress, no
   preliminary melee sound/damage. Hold 1.2 s for 90 damage. Release early: cancel without a melee hit. Use an idle
   NPC because existing target-displacement cancellation is still 4 studs.
5. Try outside reach/from the side/through a wall: no takedown. V may prepare an ordinary charge; a release can only
   hit a valid target inside ordinary 5.5-stud reach/front arc/height and clear map sight. No lunge/teleport.
6. During a charge, try R, G, switching items when supported, Alt-Tab, text focus or walking into wall tuck. Those
   cancellations must not release a strike. Do not queue shots by holding fire during the action. Recheck after respawn.
7. **Test > Clients 2 > Start** in Duos: teammates must not damage each other with shots or melee. **Clients 4**
   gives two teams: verify rival damage, interruption when the attacker is hurt, red hold cancellation on target
   movement/turning/LOS loss, post-melee weapon recovery and each client's HUD/audio. NPC/player geometry stays generic.

### Known gaps / SPEC-QUESTIONs / next

- Partial-charge behavior was not specified: use base 35 until fully charged at 0.75 s, then capped 50. This tuning
  choice is marked SPEC-QUESTION in MeleeRules; it can be revisited after the first gameplay test.
- Strike acknowledges an attack, not a down/elimination. No cosmetic finisher is wired to it. Directional falls/crawl,
  stable collapse, takedown body choreography, shop/Dossier cosmetics, NPC ground/tier fixes and free-exit doors remain
  queued. No authored melee/charge hand animation is claimed by this input fix.
- Hold uses the camera heading supplied at press and current victim facing/positions. Camera-only turning is not
  streamed to the server; geometry/LOS, displacement and damage still cancel. Server has no client-only wall-tuck
  fraction; the honest client sends Cancel and actual server attacks still require valid map sight.
- Hint is advisory. A private roster arriving late may briefly leave a teammate hint; server teammate validation is
  authoritative. Audio waits for strike acknowledgement, so latency feel needs Studio review.

**Ready for:** owner melee regression playtest, then remaining reported-bug work before combat/loadouts. Step 9c
spectating remains the next named build step once the higher-priority acceptance issues are resolved.

## Startup regression correction — test this before the rest

Owner screenshot showed the default third-person camera/player list and no custom HUD. Source reproduction found
the new HudTheme resolver's parenthesized assignment joined to the preceding assert call: Luau evaluated
`assert(...)(result)[key] = value`, calling assert's boolean return. Main requires all controllers before starting any,
so a HudKit/HudTheme dependency error aborts the entire custom client startup. This was Codex's theme regression.

Fix: use a named table alias for assignment, making the statement boundary unambiguous. Audit also fixed the same
call-then-parenthesized-assignment pattern in the heavy-SMG and marksman-pistol muzzle builders. Their corresponding
3D checks still require Studio.

Verification: official Luau CLI reproduced the pre-fix `attempt to call a boolean value`. The fixed resolver passed
nine runtime assertions using its actual source body and UI config with Color3/Enum fixture values. This verifies
resolver execution, overrides, default/fallback, caching and immutability; it does not execute Roblox startup or UI.
`tools/CheckHudTheme.luau` provides actual Roblox resolver and client controller-require checks in Studio.

First acceptance step: **Stop**, sync Rojo, then fresh **Play**. Expect custom first-person camera, hidden default
player list and graphical HUD. If any are absent, open **View > Output**, select Client, and report the first red error
plus its stack. Do not continue the larger visual/combat checklist until custom startup works.

## What was built

| File | Change |
|---|---|
| `src/client/Combat/ViewModel.luau` | Keep pose smoothing in camera space; bring first-person geometry/offsets closer together, retaining framing and wall compression |
| `src/client/Controllers/FirstPersonBodyController.luau` | Draw the cosmetic hands on the rendered grips every frame, eliminating independent stepped grip snapshots |
| `src/shared/GameConfig.luau` | Ticket 8.16 close-depth tuning and a ticketed graphical HUD palette, layout and timing section |
| `src/shared/Util/HudKit.luau` | Shared shadowed panel and original code-drawn health, ammo, badge, eye and alarm graphics |
| `src/client/Controllers/CombatHudController.luau` | Health/armor and ammo panels, large numbers, easing meters, damage pulse and reload progress; Janitor cleanup |
| `src/client/Controllers/WeaponController.luau` | Expose the existing reload clock and standing/alive state to the HUD; no new firing behavior or remotes |
| `src/client/Controllers/CoverController.luau` | Compact eye/state/meter, alarm pips, short backed warnings; hide diagnostics by default and recovery instructions while downed/eliminated |
| `src/client/Controllers/DisguiseController.luau` | Compact tier-colored ID badge, clearance pips and stored disguise line; hide aiming dot while incapacitated; Janitor cleanup |
| `src/client/Controllers/DownedHudController.luau` | New 9b-hud countdown, server-confirmed revive/execute progress and eliminated state; no fake spectator controls |
| `src/client/Controllers/DownedController.luau` | Read-only generic body-target readiness for the HUD; reject targets behind collidable map geometry |
| `src/client/Controllers/TakedownHintController.luau` | Generic proximity hint matching current server reach/cones and map sight checks, for both visible NPC and player rigs |
| `tools/CheckClientCombat.luau` | Add a real-ViewModel regression assertion: camera translation must not drag the settled weapon through world space |
| `docs/PROMPT_REVIEW_2026-10-24.md` | Attachment audit, overlap table, recommended edits and 35 detailed owner questions |
| `.ai-sync/CLAUDE_RETURN_HANDOFF_2026-10-25.md` | Area ownership, source evidence and acceptance tests for NPC support/tiers, doors and synchronized animations |

The source root is `D:\Dead-Drop\Dead-Drop`. HUD controllers are discovered automatically; no boot or server edit
was necessary. Graphics are local GUI shapes with no paid generation or asset upload dependency.

## Verification completed

- StyLua formatting on changed source; read-only `stylua --check src` passes.
- `selene src tools/CheckClientCombat.luau`: 0 errors, 0 warnings, 0 parse errors.
- Rojo builds `default.project.json` successfully to a temporary check place.
- `git diff --check` passes.

These are static/lint/build checks. Studio rendering, assertions in CheckClientCombat, gamepad behavior, four-player
downed/revive checks and performance profiling have NOT been executed by Codex. No Studio result is claimed here.

## Exact Studio tests for the owner

### One player: gun, HUD and NPC hints

1. Stop any running test, connect Rojo and accept the script diff. Start a fresh **Play** session. A running test
   retains old ModuleScript results. Wait about 30 seconds for the NPC graph/crowd.
2. Look down and strafe/turn: your actual torso/legs/head must stay hidden locally. The cosmetic hands should
   remain on the gun. Make quick left/right turns, walk, crouch (C), aim (right mouse), fire (left mouse), reload (R),
   and swap disguise (G). Watch grip contact during each transition, not only when standing still.
3. Check whether the gun now feels close enough. The depth change preserves projected gun size/composition;
   if the stock still makes it look too far forward on screen, answer review question 3 about allowing the stock
   offscreen. Watch for near-plane clipping, giant hands, stretched elbows and recoil separating the hand/grip.
4. Walk toward a wall: gun tucks across the body, crossed-out OBSTRUCTED graphic replaces crosshair/dot.
   Try left mouse, right mouse and V. No shot sound, recoil, ammo spend or takedown should start. R still reloads.
   Back away while holding fire: no queued shot; release and press again when clear.
5. Check health/armor above the disguise badge at bottom left, cover centered below, ammo bottom right and alarm
   at top left. Panels need to stay readable against a bright window and a dark room. Worn role uses tier color/pips;
   the small G line describes the stored disguise. No always-on witness/debug paragraph should remain.
6. Fire several shots: exact ammo numbers update; R shows a moving reload bar. Cancel reload by changing disguise
   and verify the bar disappears. Take real damage using the existing fall/combat test: HP number updates promptly,
   health/armor bars settle smoothly and the vitals panel briefly pulses. Enter a higher-tier room: a short warning
   appears; when exposed, the recovery cue says why recovery is blocked. It must hide while downed/eliminated.
7. Approach an NPC from behind while clear of walls: a **V TAKEDOWN** prompt appears near the current allowed range.
   Turn toward the front, move out of range or put a wall between you: it disappears. Hold V: the existing hold bar
   appears and the readiness hint disappears. This does not add the missing two-body takedown animation.
8. At a downed NPC, aim at the body inside interaction range: **E INTERACT** appears without naming its identity
   or claiming a team. Hold E: after server acknowledgement, **EXECUTE** and progress appear. Release early to cancel;
   re-hold to finish. The hold UI disappears on server cancellation/completion. A wall must prevent the readiness cue.
9. Resize the viewport and repeat at 1280x720 and your normal resolution. Report overlap, unreadable captions and
   background blending. Very narrow windows still need visual review; mobile is not the target.
10. Optional regression assertions: during an alive playtest, select **Client** in the Command Bar context and paste
    `tools/CheckClientCombat.luau`. It makes temporary camera/model/wall fixtures, checks real modules and cleans
    them up. Expect the success count and no assertion error; report the first assertion verbatim if it fails.

### Two players: observer sanity check

1. Stop; use **Test > Clients 2 > Start**. Keep both clients near each other.
2. Move/turn/aim in client 1 while watching from client 2. Client 1's own view should keep the close cosmetic arms;
   client 2 should see normal world movement/facing, not the cosmetic arm rig.
3. Repeat the takedown readiness approach around a visible character and around an NPC. It is the same generic
   geometry hint, with no names, outlines or special player-only label. Server team rules remain authoritative.

### Downed/revive/execute: four clients for a normal combat setup

1. Stop; current `GameConfig.Debug.TestMode` is **Duos**. Use **Test > Clients 4 > Start** so there are two teams.
   TeamService's Studio output reports membership. Do not switch to Solos: Solos eliminate directly.
2. Have a rival shoot one member of a Duo to zero while its partner stays alive. The victim gets **DOWNED** and
   a countdown from the server's 30-second deadline. Fire/aim/reload/melee stay disabled. Movement asks to crawl;
   the missing authored crawl/death animation is separately handed to Claude.
3. The teammate approaches the body, aims at it, holds E: the server labels the hold **REVIVE**, with roughly 4 s
   progress. Release halfway: progress vanishes and does not finish. Repeat and finish: victim stands, downed HUD
   clears, weapon controls recover. Observe all clients for stale UI.
4. Down the victim again with its teammate alive. Have an enemy hold E: **EXECUTE** progresses for roughly 2 s;
   completion shows **ELIMINATED** on the victim. In a separate attempt, let the victim bleed out: countdown reaches
   zero and clears into eliminated state. A team wipe may eliminate early, which is intended existing behavior.
5. Respawn/start a fresh test: no stale eliminated/countdown/hold state, duplicated panels or duplicate callbacks.

## Gaps and SPEC-QUESTIONs

- Gun contact and HUD appearance require Studio acceptance. The owner confirmed smooth own gun/arms on October 25;
  latest owner answer removes world animation/movement stepping entirely (8.20), superseding 12/18 Hz tuning.
- Full-gun-in-frame versus a closer shoulder-stock crop remains a composition choice. Initial depth scale is tuning.
- Takedown hint is advisory against client-rendered geometry, not a server guarantee. Reach and rear cone remain
  now the approved 6.5 studs / 90 degrees through shared MeleeRules (8.22). Ordinary melee stays unchanged.
- NPC airwalking/tier incidents, exterior door reproduction, crawl/death and two-body takedown animation remain
  assigned to Claude in the return handoff. Codex has not declared those gameplay bugs resolved.
- HUD includes only live existing contracts. Timer/objective/Intel progression, Assets, gadgets, menus, elevators,
  secret exits and rescue do not appear as fabricated working systems. Keyboard labels outside the takedown hint
  still need the broader controller-glyph/rebinding pass.
- Source review and test expectations are evidence, not a runtime reproduction of the NPC/door reports.

**Ready for:** owner Studio acceptance and design answers, then Step 9c (spectating) / remaining Step 8 integration
under the existing ownership split. All new gameplay proposals in the attached brief remain pending explicit answers.

## Map HUD skins and cadence follow-up (October 25)

Added `src/shared/Util/HudTheme.luau`, consumed by HudKit and all five graphical HUD controllers. It overlays only
allowed visual fields onto the common GraphicHud config, validates override names/types, freezes and caches results,
and falls back to neutral base styling for an unregistered ID. No per-frame theme lookup or extra connections.

`GameConfig.UI.HudThemeId = "Gala"` selects charcoal panels, brass borders, a restrained gold accent rule and tighter
corners matching the selected Field notes direction. Future maps add an entry to `UI.HudThemes` and select that ID
with their startup config. Optional `HudTheme.get(id)` supports a future map bootstrap. Runtime map switching is not
claimed: no map-session metadata event exists yet. Tier/cover/health colors and HUD layout/timing cannot be overridden
by a skin, so familiar gameplay information stays consistent between maps.

Additional tests:

1. Restart **Play** after Rojo sync. Compare bright/dark rooms: every panel should share the Gala charcoal/brass look
   and short gold top rule. Health, armor, tier and warning colors must retain their usual meanings.
2. **Test > Clients 2 > Start**: strafe/circle and watch NPCs alongside the other client. World models should feel
   less choppy; your own gun/arms stay smooth. Fire at moving NPCs and rivals in a separate multi-team test, checking
   that hit feedback follows the visible target. Full smooth motion now replaces the interim 12/18 Hz tuning.
3. Optional **Client** Command Bar theme check:
   `local s=game.ReplicatedStorage.Shared; local t=require(s.Util.HudTheme); assert(t.get().AccentColor==require(s.GameConfig).UI.HudThemes.Gala.AccentColor); assert(t.get("UnknownPreview").PanelColor==require(s.GameConfig).UI.GraphicHud.PanelColor); print("HUD theme checks passed")`
   This checks the real resolver without mutating the live theme or config. It does not repaint the GUI.

StyLua/Selene/Rojo checks are required for this follow-up as well. Studio tests above remain owner-run.

## Smooth combat movement (ticket 8.20)

Owner requested removing choppiness before resuming design questions. Changes:

- Deleted StepAnimationController: Animator poses are no longer sampled/held; players and NPCs animate smoothly.
- Deleted PositionStepController: other players retain Roblox's smooth replicated motion, with no local root freezes.
- NPCController now interpolates at continuous server time minus its existing delay.
- Ballistics uses continuous shot time minus the existing target delay; history bounds/future clamps stay intact.
  This small server edit was necessary to avoid rewinding against the removed stepped presentation clock.
- Removed the unused PositionStep helper and GameConfig.Animation stepping section. No disabled stubs remain.

Verification: StyLua/Selene/Rojo pass. Official Luau CLI ran the actual Ballistics trace body and Combat config with
engine/history fixtures: eight assertions verify NPC/player continuous timestamps and lower/future clamps, plus shooter
exclusion and unchanged empty trace. This is timing logic verification, not Roblox physics, animation or latency testing.

Studio: Stop, sync Rojo (accept the deleted stepping scripts), fresh Play. Watch nearby NPC walk/idle/turn animations
and your gun/arms. Use Test > Clients 2 > Start to strafe/circle and observe the other client alongside NPCs: no deliberate
pose/position freezes should remain. For rival-player hit registration, use four clients in Duos/two teams and shoot
moving opponents; verify hitmarkers track visible targets. Network jitter or actual path/ground defects may still occur;
those are distinct from the removed stylized stepping. Existing NPC animation distance culling remains intentional.

Ready for owner smooth-motion acceptance and the design interview; Step 9c spectating remains the next planned step.

## Shoulder-stock crop (ticket 8.21) and interview answers

Owner approved cropping the shoulder stock to bring first-person gun framing closer. ViewModel now caches separate
framing points: both grip centers and actual visible-part vertices, excluding Stock/Butt. Framing no longer fits an
artificial bounding-box corner combining the stock's rear depth with the magazine's low edge. Full eight-corner
geometry bounds remain for wall-depth protection; third-person size/placement is unchanged. No per-frame tables.

CheckClientCombat now checks the visible geometry/grip framing contract for all eight guns over FOV/aspect variants.
StyLua/Selene/Rojo pass; those Studio geometry assertions and visual acceptance remain owner-run, not claimed executed.

Test: Stop, Rojo sync, fresh Play. Compare tucked/ready/aim and reload, including fast camera turns and wall approach.
The shoulder stock may crop; hands, active gun body, sights and muzzle should remain readable. Check for near-camera
clipping and report any stretched hand/arm contact or framing that is still too far out. Repeat on a pistol and carbine
with the existing temporary Studio weapon-selection workflow when convenient.

Recorded separately in SPEC_CHANGES/META_DRAFT/Claude handoff: 90 damage, first-person takedowns, conditional
confirmed-result cosmetics in shop/Dossier rewards, directional downed/crawl poses, stable elimination collapse,
charged melee request and ordinary-door free exit. These are not represented as completed server/animation mechanics.
Three selectable follow-ups cover ambiguous input/result/direction semantics. Ready for further owner answers and
Studio framing acceptance; Step 9c spectating remains the next planned step.
## Reduce Motion follow-up (ticket 19-hud-motion, 2026-10-25)

What I built:
- `src/shared/Util/UiAccessibility.luau`: reads Roblox's live Reduce Motion preference, with a compatibility fallback for older engines.
- `CombatHudController.luau`: immediate health/armor meter updates and static hit/damage indicators when enabled; disables the decorative damage pulse.
- `CoverController.luau`: removes the fullscreen exposure flash/glow when enabled while retaining EXPOSED text and the existing warning duration.
- `ReviewHarness.luau`: checks the real native preference on both test clients and gives cold-start clients longer to load.

How to test in Studio:
1. Stop the current test, sync Rojo, then start **Play** with one player. In Roblox's in-game Settings, enable **Reduce Motion**.
2. Take damage and break Cover by firing. Health/armor should update immediately, hit/damage indicators should stay readable, and EXPOSED text should appear without a fullscreen flash or glow.
3. Turn Reduce Motion off during the same session and repeat. Normal meter easing, feedback fading and exposure effects should return. Weapon recoil, ammunition and action durations must remain identical in both modes.
4. For the integration regression, run the fresh-clone `ReviewHarness.run()` workflow in `GALA_ART_REVIEW.md`, or **Test > Clients 2 > Start** for manual review. Require both client PASS lines as well as the server result.

Validation: StyLua check, Selene (0 errors/warnings), and Rojo build passed. Live two-client outcome is recorded in the handoff after the run. Enabled-mode visual acceptance remains owner review; no native setting was changed on the owner's behalf.

Known gaps: this covers HUD presentation only; no claim that all world effects support reduced motion. Texture uploads remain blocked separately.
SPEC-QUESTIONs: none added. Ready for: Step 19 traversal warnings; the main build plan still lists Step 9c spectating as the next gameplay step.

## Traversal Cover-break badge (ticket 19-traversal-warnings, 2026-10-25)

What I built:
- `TraversalFeedbackController.luau`: one reusable crossed-eye badge on the shared map-themed panel. Zipline/gondola warnings follow native prompt visibility; vents require proximity, facing and clear line of sight. Hidden when downed/eliminated, restored on revival/respawn. Janitor owns the GUI and connections; no per-frame instance/table creation.
- `GameConfig.luau` UI.TraversalWarnings: presentation scan interval, vent distance/facing and badge height in a ticket section. Shared-file lock released after formatting/linting.
- `ReviewHarness.luau`: temporary client vent/wall fixtures check real visibility, occlusion and facing; fixtures always clean up.

How to test in Studio:
1. Stop, Rojo sync, then **Play** with one player. Approach a zipline mount until its normal prompt appears. Expect a crossed-eye badge reading ZIPLINE · BREAKS COVER. Use the original input/hold; no additional confirmation is required.
2. Approach a gondola call button. Expect GONDOLA · RIDING BREAKS COVER. Calling alone must retain Cover; riding the moving car retains the existing exposure behavior.
3. Look at a vent entrance within 8 studs. Expect VENT · BREAKS COVER. Turn away, back out, or put a wall between yourself and it: the badge disappears. Entering still uses the existing automatic server volume rule.
4. Check 1280×720 and a larger viewport. The card sits above the Cover panel without replacing the crosshair or interaction input. Repeat after respawn. With **Test > Clients 2 > Start**, each client should see only their own contextual badge, with no new character effect.

Validation: StyLua, Selene, Rojo build and the existing 29 server-melee regression assertions passed. At 15:36 UTC both Studio clients passed the isolated vent visibility/occlusion/facing fixtures and the server passed outfit parity. Manual zipline/gondola input and visual layout remain owner review.
Known gaps: a vent badge is an approach warning, not a prediction of the exact server entry tick. Gondola warnings accompany its call prompt; they do not claim that calling exposes you.
SPEC-QUESTIONs: none added; the 8-stud approach distance and facing dot 0.25 are presentation tuning, not a gameplay requirement. Ready for: remaining Step 19 HUD review; Step 9c spectating remains the next gameplay-plan step.

