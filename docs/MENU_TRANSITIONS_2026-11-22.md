# Smooth menu transitions — 2026-11-22

Owner request: smooth transitions between menu screens instead of jump cuts.

Root cause: camera CFrame/FOV already tweened, but mounting a tab destroyed the display agent and the next pose was
applied immediately. Content was also cleared and rebuilt without a visual transition.

## Built

- `src/client/Menu/Components/StagePose.luau`: describe/blend complete pose states. Joint rotations, stance and support
  gesture weights interpolate together, while forward kinematics keeps limbs connected and the soles grounded.
- `src/client/Menu/MenuStage.luau`: retain the shared display body across agent-focused screens and selections. Pose
  transitions run for the existing CameraPanSeconds and keep the selected weapon attached to the moving hands.
  Interruption starts from the current blended state. Actor visibility fades for catalogue views and initial loading;
  reentering an agent view can reverse an unfinished fade. Existing camera/lens easing retargets from its current shot.
  Tween callbacks and temporary values are owned by Janitors, with no permanent render loop. Closing/spectating still
  destroys the stage and cancels its transitions and pending display intent.
- `src/client/Controllers/MenuController.luau`: preserve the actor when moving between Play, Agents, Hardware and
  pre-deploy. Crossfade an outgoing visual snapshot with newly mounted content using CanvasGroups and the existing
  ScreenFadeSeconds. Old subscriptions/requests are unmounted immediately; snapshot controls cannot receive input,
  scroll, edit text or run scripts. A new navigation cancels and cleans up old transition layers. Pre-deploy uses
  the same transition path. Reduced Motion skips content/actor/pose/camera animation.

No gameplay, ownership, loadout request, server or shared-config edits belong to this pass. Weapon selection remains
immediate and accurate; its holding pose blends to the appropriate weapon-family stance. All agents still use the
shared true-form outfit, so retaining the display body does not suppress distinct agent artwork that exists today.

## Owner visual acceptance (not executed)

1. Switch Play → Agents → Hardware → Play. The agent should stay present, turn smoothly into each pose, and keep
   the weapon in hand as camera position/lens and screen content transition.
2. Switch again halfway through an animation. It should continue from the current pose/shot without snapping back.
   Select several weapon families, including pistols, long guns and dual weapons, while switching.
3. Open a catalogue tab, then return quickly. The agent should fade out/in and the previous content snapshot should
   disappear. Old buttons and scroll areas must not remain interactive.
4. Enter pre-deploy or spectating/close the menu during a transition. No old rig, content layer, tween or camera
   movement should return later. Reduced Motion should make navigation immediate.

Validation: source inspection and StyLua formatting only. No tests, lint, builds, Studio or desktop control, following
the owner's instructions. Native visual acceptance is pending, especially intermediate hand/garment clearance and
CanvasGroup/ViewportFrame rendering cost at the owner's resolution. No new SPEC-QUESTIONs.
Ready for owner cinematic transition review.
