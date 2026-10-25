# Codex client handoff — 2026-10-24

## Owner test correction — ticket 8.15 (supersedes the earlier full-body notes below)

Root causes: the old controller deliberately exposed the actual avatar and posed its real arms, so torso/legs and
movement-facing rotation were visible locally. The gun started tucking at 3.5 studs, but blocked firing only at
0.65 studs (usually inside the character's wall clearance), and the melee/aim handlers had no wall gate.

Changed files:
- FirstPersonBodyController: hides the actual avatar in its owner's view; clones only arm/hand meshes into a
  camera-relative cosmetic rig, strips all joints/scripts/constraints, copies outfit colors and scales with the gun's
  camera-depth compression. No real avatar joints or root rotations are modified. Camera-space poses step at 8 Hz.
- StepAnimationController: only the real neck is excluded again; the cosmetic rig needs no real arm joint exclusions.
- ViewModel/WeaponPlacement: blend wall tuck to the disguised across-body pose. A single attackBlocked rule uses both
  sampled wall proximity and visible tuck recovery, replacing the unreachable full-tuck-only firing condition.
  Wall blend is applied after ordinary pose settling so a second filter cannot leave visual tuck behind the gate.
- WeaponController: runs that gate before fire feedback/requests, before aiming and before melee/takedown. Entering
  obstruction cancels queued fire/bursts and releases aim/takedown; backing away requires a new attack press.
  getHandTargets now also returns drawScale for the cosmetic rig. Reload and respawn paths are unchanged.
- CombatHudController/DisguiseController: crossed-out reticle and OBSTRUCTED caption replace weapon crosshair/dot
  using the exact same attackBlocked state.
- GameConfig: FirstPersonArms and blocked-graphic tuning added; obsolete high-ready TuckPosition/TuckRotation removed.
- CheckClientCombat: covers reachable-distance gates, visible recovery, temporary-wall sampling, HUD/dot agreement,
  cosmetic rig isolation and hidden actual-avatar parts. Fixtures are removed on success or failure.

Validation: StyLua, Selene and Rojo build pass. The Studio assertions and actual visuals require owner verification.

Retest after STOP, Rojo sync, PLAY (running tests keep old modules):
1. Look down, walk in each direction and rotate the view. See only cosmetic arms/gun, no torso/legs/hats or real body
   swiveling through the gun. Swap outfits and verify arm colors update. A second client still sees normal facing.
2. Walk toward a wall and test oblique approaches. The gun crosses the body; the orange prohibited reticle and
   OBSTRUCTED label replace the crosshair/dot. LMB, RMB and V must not start attacks, consume ammo, kick or play shots.
3. Begin a held automatic burst/aim before entering obstruction. It must stop. Back away, wait for the graphic to
   clear, then press fire afresh; normal combat returns. Reload remains available while obstructed.
4. Recheck reload and respawn (reported passing by owner). Run tools/CheckClientCombat.luau in the Client Command Bar
   from a fresh, alive, own-character camera view. New structural/collision/HUD assertions have not run in Studio here.

No new SPEC-QUESTIONs: the owner's latest direction is recorded in SPEC_CHANGES and overrides the old full-body plan.

---

The owner authorized continued client work across steps and incremental commits. Studio visual review is still
required; lint/build success does not establish visual correctness. Do not mark these tickets DONE on that basis.

## Committed work

| Commit | Change |
|---|---|
| d45f6f4 | 8.10 ammo reconciliation (owner says it passes); 8.11 pooled tracers and flashes. |
| a04a2e2 | Classic Motor6D compatibility in FacingController and StepAnimationController. |
| 732b3cb | HeldItemController owns fire/aim routing; item switches/focus loss cancel inputs. |
| 06357ec | Actual-FOV/aspect gun framing, five wall probes, high-ready tuck and full-tuck firing gate. |
| 1867a8f | Visible real first-person body, hidden head/head accessories; local two-bone arm poses on the shared 8 Hz clock. |
| c1663e9 | Client-only held-gun models on any rig matching the visible True Form palette. |
| 298c70c | ReticleCarbine definition/model and client PostMeleeFireDelay enforcement. |
| 48afb2a | Weapon connection/binding cleanup, death/respawn/camera recovery; Studio combat assertion script. |
| fe16524 | Delegated Feint balance; FeintPistol and GuisePistol data/models, hearing overrides. |
| 80346d9 | Client cadence, complete bursts, spin-up/restart, aimed RPM, one-request pellet groups, pooled scope glints. |
| 34a93a7 | Heavy SMG, marksman pistol, medic shotgun and dual machine pistols with shaped models and real-hand grips. |

06357ec also picked up Claude's concurrent Rig/Hitbox config hunks; c1663e9 picked up the Movement/Controls config
hunks. Those changes were preserved and are already committed. Associated server/controller implementations belong
to Claude. Going forward stage only owned hunks in shared files, not entire shared files.

## Contracts and integration

- No new remotes. Tracer/flash paths use existing prediction and ShotHeard. Quiet suppresses both unconditionally.
- ViewModel exposes getMuzzlePosition(), getHandTargets(), placeAtRightHand(), isFireBlocked(), setVisible(), destroy().
  Duplicate sleeve/hand parts and setColors() are removed: FirstPersonBodyController uses the real body.
- HeldItemController accepts an Item with fire(state), aim(state), setHeld(boolean). registerWeapon(item) installs
  the default. equip(item) cancels the old inputs and stows it; equipWeapon() restores it. No unbuilt gadget appears.
- FirstPersonBodyController owns the local arm Motor6D transforms in PreSimulation. StepAnimationController must
  continue skipping those joints and the local neck. Arms sample on floor(GetServerTimeNow() * Animation.StepHz).
- WeaponVisualController matches visible colors, never a Humanoid/player roster or identifying attributes. It
  displays Combat.DefaultWeapon because all current live loadouts use it. Different selected loadouts need an
  approved visible-data association; do not infer a hidden agent/team identity.
- ReticleCarbine is a complete standard semi-auto path: 22 body, 400 RPM, 20/40 ammo, 2 s reload, no falloff. Default
  remains GuiseSMG. Handling values are initial playtest tuning. SMG recovery is 0.2 s; carbine recovery is 0.35 s.
- Remaining 8.5 weapons need their missing mechanics and selection integration. The remaining nonstandard effects
  include garrote/hammer melee behavior, pump-shotgun stagger and per-shell reload, burst tracking, taser disable,
  flare lighting, smoke rounds and recoverable knives. Do not expose a weapon whose required effect is missing.
  The old Feint revolver numbers are superseded and were not reused.

Update: the owner delegated Feint's pistol balance. FeintPistol is now defined and modeled: 20 damage, 320 RPM,
12/24 ammo, 1.5 s reload, falloff 35–85 to 65%, post-melee recovery 0.25 s, Quiet, HearStuds=12,
SoundOffset=NumberRange.new(8,15). GuisePistol is also defined/modeled with the decided 22/300/12+24/1.4 s and
AmbushMult=1.5. ShotFxController honors HearStuds overrides. Neither needs a new server rule; existing 8.5-server
fields supply their effects. Both remain subject to the normal loadout/default-weapon test procedure below.

Eight complete registered firing paths now exist: GuiseSMG, GuisePistol, FeintPistol, ReticleCarbine,
ParapetHeavySMG, ReticlePistol, SutureShotgun and SutureDualPistols. No selection screen is added; Combat.DefaultWeapon
stays GuiseSMG. Dual pistols alternate muzzles while hip-firing; aiming hides the left gun, releases the left-hand
IK pose and uses AimedRPM. Third-person models place each pistol at its own hand, but there is no remote aim-state
display contract; actual varied live loadouts still need selection integration. Existing library sounds are reused.

WeaponCadence duplicates the pure server FireRate formulas because ServerScriptService modules are inaccessible to
clients. Keep them synchronized and use tools/CheckWeaponCadence.luau in Studio's SERVER Command Bar: it compares
the real modules over 1,800 state/gap assertions and checks burst pause, spin-up/restart and aimed rate independently.
This script is authored/linted, not engine-executed by Codex. Pellet directions use a reusable list; one request, one
ammo decrement, one sound/recoil/flash per trigger. Remote pellet ShotHeard events are coalesced by origin, weapon
and cadence window for audio/flash. Each pellet retains its own tracer/impact.

ScopeGlintController preallocates one billboard flare per maximum participant in a client-only folder. It consumes
the existing ScopeGlint event, expires by the provided Seconds and is normally occluded by walls. Test renderer alone
by firing the existing event from Studio's SERVER Command Bar to one local player with a visible Position and
Seconds=1. Actual DMR integration still needs the approved 300-stud maximum range enforced on the server and an exact
3x optical zoom contract; neither was silently approximated by a plain rifle definition.

Step 9 integration: WeaponController now consumes owner-only Downed/Revived/Eliminated messages. Downing cancels
fire/bursts/aim/reload prediction, hides the gun/crosshair and releases the real-arm grip poses. Revive and respawn
restore eligibility. It neither adds character state markers nor changes DownedController/server ownership.

## Studio review

1. Restart Play after sync. Look down and check real torso, legs, feet and hands. Swap disguises, die and respawn.
   Head/hair/hats should not obstruct the view; torso accessories should remain visible. Check grip reach at both
   ends of the new body scale range. Body IK has not been visually verified by Codex.
2. Aim, hip-fire, reload and move the view quickly. Check wide and narrow Studio viewports and FOV 70–100.
   Approach walls facing forward and obliquely: gun tucks, firing/ammo/recoil stop at full tuck, and recover on
   backing away. Camera-space depth compression preserves the projected gun size, but extreme camera embedding
   and near-plane clipping still require visual review.
3. Paste tools/CheckClientCombat.luau into the CLIENT Command Bar in a fresh playtest. It tests the actual modules
   across three FOVs, four aspect ratios, every pose, all eight models, muzzle existence and Quiet/non-Quiet pool behavior.
   The checks are authored and linted, not executed by Codex (no Studio connector; window capture unavailable).
4. Test > Clients 2 > Start: fire to expose a character, check its gun appears only on the other client's
   CombatHeldWeapons folder, then re-cover and verify it disappears immediately. Disguised NPCs/agents show none.
5. To exercise carbine prediction, disconnect Rojo in EDIT MODE, temporarily change Combat.DefaultWeapon to
   ReticleCarbine in Studio's GameConfig source only, then start Play. Both server and client must load that same
   temporary config. Single presses fire single shots; held fire does not run automatically. Verify 20/40 ammo,
   2 s reload, tracer/flash and post-melee recovery. Stop, undo the Studio-only edit and reconnect Rojo.
6. Hold fire through SMG reloads to recheck the owner's passing 8.10 result after later changes. Test input focus
   loss and respawn while aiming/reloading. Camera replacement should recreate a visible gun under the new camera.
7. Repeat the temporary Studio DefaultWeapon selection for the other registered IDs. Heavy SMG should ramp from
   500 to 750 RPM over one second and restart after releasing long enough. Medic shotgun spends one round per six
   pellets with one sound/flash. Dual pistols alternate, then aim switches to the right gun at half rate. Marksman
   pistol should hit a second lined-up person at 60% damage (server decides every hit).
8. Test > Clients 2 > Start: down the armed player while firing/aiming. The downed client must stop weapon prediction,
   sounds, crosshair and grip posing. Revive, then press fire afresh and verify normal combat. Elimination must keep
   combat disabled until the next character spawn. Watch Output for errors in both clients and the server.

## UI review and open questions

- docs/mockups/combat-hud-review.html proposes two future Step 19 HUD directions. This is a separate design preview,
  not new in-game UI or a claim that gadgets, teams or match phases are implemented. Choose a direction before
  translating it into the game. It uses Intel, Cover, two gadgets and current tier names; no Funds or premium currency.
- SPEC-QUESTION in ShotFxController: should tracers be visible beyond shot earshot? Current behavior accepts the
  existing event range, as the owner requested.
- Per-weapon recovery/handling numbers and the real-arm grips need playtest tuning.
- Guise ambush review for Claude: STEP8_QUESTIONS says Covered only, but the current server AmbushMult path uses
  not CoverService.isExposed(), which also grants the multiplier while Suspicious. Confirm/narrow that check before
  marking Guise's agent ticket DONE. Feint has no AmbushMult and is unaffected.
- Additional Talents and Instincts are still undesigned. Tutorial source videos are still absent. Neither was invented.

Validation: StyLua check on owned source files, Selene src plus the assertion script, Rojo build, git diff --check.
No changes from this development run were pushed by Codex.
