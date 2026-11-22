# Lobby transition obstruction — 2026-11-22

Owner reports a solid object crossing the lobby character only while opening the lobby or switching screens.

Source inspection found visible box-shaped light holders and an initial camera tween from the previous gameplay
camera to the distant menu origin, passing through intervening world geometry. The exact reported object has not
been visually observed.

Changed `src/client/Menu/MenuStage.luau`:

- Light-holder parts are invisible and cast no shadow; their PointLights still illuminate the display.
- The menu camera enters directly at the configured Play shot, then keeps the existing smooth transitions between
  menu shots. Opening no longer sweeps from the map through the world and balcony floor.
- The display HumanoidRootPart is explicitly invisible and shadowless before its opacity is captured for fades.
- A shared shot-frame helper keeps initial camera placement and subsequent framing consistent.

Validation: source inspection and StyLua formatting only. No tests, lint, builds, Studio or desktop control, per owner.
Owner acceptance: restart the play session, open the lobby, and switch Play/Agents/Hardware several times. Confirm
that the obstruction is gone, lighting remains, and in-lobby camera/pose transitions remain smooth. If it persists,
the object's appearance/location is needed to distinguish an outfit/weapon intersection from scene geometry.

No server/gameplay/config changes or new SPEC-QUESTIONs. Ready for owner lobby transition acceptance.
