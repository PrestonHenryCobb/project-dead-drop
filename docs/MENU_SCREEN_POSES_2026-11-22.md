# Cinematic agent poses by screen — 2026-11-22

Owner request: a different cinematic pose/angle on each agent screen, including "ready for trouble" on the loadout
screen, with the weapon in hand changing as the player chooses Hardware.

## Built

| Screen | Pose | Shot |
|---|---|---|
| Play | Quiet confidence: weight shifted, Hardware low, head toward camera | Lower three-quarter hero angle, 40° lens |
| Agents | Undercover arrival: cuff-adjustment gesture, Hardware lowered; dual gear uses both hands | Opposite-side three-quarter angle, 42° lens |
| Hardware / loadout | Ready for trouble: Hardware across the chest, support hand fitted to two-handed grips | Closer three-quarter chest framing, 38° lens |
| Pre-deploy agent select | Over-the-shoulder turn toward camera, Hardware low | Separate opposite-side shot, 40° lens |

- `src/client/Menu/Components/StagePose.luau`: static local R15 pose solver, including forward/reverse accessory welds,
  sole grounding and bounded two-bone support-arm reach. Anchored display parts and disabled display joints prevent
  physics/Animator overrides; neck requirements are disabled only on the local display Humanoid. No animation upload,
  per-frame work, player-character changes or replicated pose state.
- `src/client/Menu/MenuStage.luau`: each framing applies its pose, independently of the camera angle. Each shot now
  owns its field of view. Same-agent Hardware changes replace the held weapon while retaining the body/template.
  One-handed, two-handed and dual equipment get distinct support-hand treatment. Existing late-template generation,
  hidden-screen intent, cleanup and camera restoration remain in place.
- `src/client/Controllers/MenuController.luau`: select the correct pose/shot before mounting a view; Hardware now has
  its own framing rather than sharing Agents. Pre-deploy uses its own pose even if the selected weapon is unchanged.
- `src/client/Menu/Views/HardwareInspectorView.luau`: armory selection now calls focusAgent with the selected agent
  and weapon. Previously it never updated the stage. Narrow scrolling filters/cards at left and details/actions at
  right leave the middle open for the posed agent. Start from the equipped Hardware when available, preserve user
  selection against profile pushes and preserve filter/list scroll while inspecting. Agent filters update the preview.
- `src/shared/GameConfig.luau`: per-screen joint angles, stance, support flags, camera position/target/FOV and visual
  weapon-family overrides. No gameplay weapon, ownership, mastery, loadout request or server values changed.

The Agents and pre-deploy screens already call focusAgent on Hardware changes; those paths use the same updated
display machinery. Selecting a locked weapon can preview it in the armory; the existing Equip gates still enforce
ownership/mastery. Catalogue screens that do not display an operative retain their existing content-focused layout.

## Owner visual acceptance (not executed)

1. Start a fresh play session. Look at Play, Agents, the Armory and pre-deploy: each agent view should have a distinct
   stance and angle, without a generic straight standing pose or a view from behind the face.
2. Change W1/W2/W3 in agent select and armory. The actual chosen Hardware should appear in the posed hands. Check a
   long gun, pistol, dual pistols, garrote and hammer for hand/muzzle clearance. The armory center should remain clear.
3. Select late entries while scrolling the armory. The list should retain its position, and choosing another agent
   filter should change the preview without granting ownership or equipping it.
4. Switch screens quickly during initial rig loading, then close the menu or enter spectating. No old pose/weapon
   should reappear. Reduced Motion snaps camera position and lens; other settings keep the existing camera pan.

Validation: source inspection and StyLua formatting only. No tests, lint, builds, Studio or desktop control, following
the owner's instructions. Native visual acceptance is pending: pose silhouette, cuffs, support-hand reach, garment
fit and all eighteen weapon clearances still need owner review. Poses are authored static portraits with camera
transitions, not uploaded idle animations. Agents continue to share the existing true-form outfit.

No new SPEC-QUESTIONs. Ready for owner cinematic menu pose review.

Claude handoff: preserve the configured screen poses and local-only menu rig. No server/data change is needed. Check
any client review feedback against these files/locks before editing. Keep the owner's no-tests/no-desktop instruction.
