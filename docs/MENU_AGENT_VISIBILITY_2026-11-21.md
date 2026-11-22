# Missing main-menu agent

Owner report: the cinematic main screen has no visible agent.

Source causes: PlayLobbyView only called focusAgent when a saved Loadout existed, leaving first-launch/loading
profiles without any model. MenuStage also relied on an immediately available, fully replicated StarterCharacter;
an unavailable template silently dropped the request, with no independent local preview source.

## Built

- `src/client/Menu/LobbyViews/PlayLobbyView.luau`: always request an agent display. Prefer the equipped loadout,
  otherwise the first owned agent, otherwise the first roster agent. Unequipped displays are labelled PREVIEW.
  Previewing does not claim, equip, buy or enable deployment.
- `src/client/Menu/MenuStage.luau`: retain the current requested agent/hardware and retry when template descendants
  arrive. If necessary, asynchronously generate a local blank R15 with the same construction API used by RigService,
  then apply the shared true-form outfit. Convert fresh physics joints to the server's classic Motor6D convention,
  remove scripts, reset local visibility and disable preview collisions. Cache the successful local template for this
  menu lifetime. Bounded creation retries warn on failure. Closing/hiding cancels display intent; late model results
  are destroyed after menu closure and cannot recreate a stage or take over the camera.
- `src/shared/GameConfig.luau`: stage-local creation attempts/retry delay only. Unrelated working edits preserved.

API reference: [Players.CreateHumanoidModelFromDescriptionAsync](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync).
This uses an empty description, not the player's personal Roblox avatar or a newly uploaded asset.

Source inspection and StyLua formatting only. No tests, lint, builds, Studio or desktop control, per owner request.

## Owner acceptance (not executed)

1. Start a fresh session. The main screen should show a preview while the profile loads, even with no owned agent
   or saved loadout. Play remains gated by actual loadout requirements.
2. Claim/select an agent or switch Hardware, then return to Play. Its model/weapon should replace the preview.
3. Close the menu or enter spectating during loading; no late rig should reappear or alter the spectator camera.

Known limit: runtime and asset-loading acceptance remain pending. All agents still share the existing true-form
outfit; this does not introduce unique agent artwork. No server/remotes changes or new SPEC-QUESTIONs.
Ready for owner main-menu agent visibility review.
