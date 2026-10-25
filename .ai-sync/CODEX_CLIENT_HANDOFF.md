# Codex client handoff — 2026-10-24

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
- Remaining 8.5 weapons need server-owned unique effects and selection integration. Existing design specifies
  ambush pistol damage, garrote/hammer melee behavior, shotgun pellets/stagger, heavy-SMG spin-up, burst tracking,
  taser disable, DMR glint, piercing pistol, akimbo rate, flare lighting, smoke rounds and recoverable knives.
  Do not expose a weapon whose required effect is missing. Feint pistol stats need the owner's answer; the old
  revolver's numbers are superseded and were not reused.

## Studio review

1. Restart Play after sync. Look down and check real torso, legs, feet and hands. Swap disguises, die and respawn.
   Head/hair/hats should not obstruct the view; torso accessories should remain visible. Check grip reach at both
   ends of the new body scale range. Body IK has not been visually verified by Codex.
2. Aim, hip-fire, reload and move the view quickly. Check wide and narrow Studio viewports and FOV 70–100.
   Approach walls facing forward and obliquely: gun tucks, firing/ammo/recoil stop at full tuck, and recover on
   backing away. Camera-space depth compression preserves the projected gun size, but extreme camera embedding
   and near-plane clipping still require visual review.
3. Paste tools/CheckClientCombat.luau into the CLIENT Command Bar in a fresh playtest. It tests the actual modules
   across three FOVs, four aspect ratios, every pose, both models, muzzle existence and Quiet/non-Quiet pool behavior.
   The checks are authored and linted, not executed by Codex (no Studio connector; window capture unavailable).
4. Test > Clients 2 > Start: fire to expose a character, check its gun appears only on the other client's
   CombatHeldWeapons folder, then re-cover and verify it disappears immediately. Disguised NPCs/agents show none.
5. To exercise carbine prediction, disconnect Rojo in EDIT MODE, temporarily change Combat.DefaultWeapon to
   ReticleCarbine in Studio's GameConfig source only, then start Play. Both server and client must load that same
   temporary config. Single presses fire single shots; held fire does not run automatically. Verify 20/40 ammo,
   2 s reload, tracer/flash and post-melee recovery. Stop, undo the Studio-only edit and reconnect Rojo.
6. Hold fire through SMG reloads to recheck the owner's passing 8.10 result after later changes. Test input focus
   loss and respawn while aiming/reloading. Camera replacement should recreate a visible gun under the new camera.

## UI review and open questions

- docs/mockups/combat-hud-review.html proposes two future Step 19 HUD directions. This is a separate design preview,
  not new in-game UI or a claim that gadgets, teams or match phases are implemented. Choose a direction before
  translating it into the game. It uses Intel, Cover, two gadgets and current tier names; no Funds or premium currency.
- SPEC-QUESTION in ShotFxController: should tracers be visible beyond shot earshot? Current behavior accepts the
  existing event range, as the owner requested.
- Per-weapon recovery/handling numbers and the real-arm grips need playtest tuning.
- Additional Talents and Instincts are still undesigned. Tutorial source videos are still absent. Neither was invented.

Validation: StyLua check on owned source files, Selene src plus the assertion script, Rojo build, git diff --check.
No changes from this development run were pushed by Codex.
