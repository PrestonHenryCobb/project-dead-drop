# Secret exits (ticket 7B-secret-exits, server; Claude Code, 2026-11-20)

**Built, not run in Studio.** `Services/SecretExitService`. The map already builds eight exits (`Tools/Gala`, `sx_a` to `sx_records`): a wall
panel (tag `SecretExit`, attributes `ExitId`, `Room`, `To`) and a lever inside the restricted room (tag `SecretExitTrigger`, same `ExitId`).

## Rules (SPEC_CHANGES 2026-10-25, "Owner traversal additions")
- Hold Interact: `RequestInteract("SecretExit", ExitId)`, `GameConfig.SecretExit.HoldSeconds` (1.5 s). The label is "Pull the lever".
- The server allows it only if the player is in the match and up, **inside the restricted room** (the lever's side of the wall), within
  `InteractStuds` (4) of the lever, **facing it** within `FacingDegrees` (50), with a **clear line** to it, and the exit is shut. It keeps
  checking while the hold runs. There is no activation from outside or through a wall.
- **Discreet**: `CoverService.noteHacking`, so it breaks Cover only if a witness sees it (the same rule as a hack).
- Done: the panel opens (`CanCollide` false, `Transparency` 1, so clients just see the opening) for `OpenSeconds` (12 s). **Anyone** can pass
  either way. It does not close while a body is still in the doorway (checked every `ClearCheckSeconds`). It is shut again at Lobby and Insertion.
- Nothing is put on any character.

## For Codex (client)
- Offer the hold the same way as the other contextual holds (SecurityInteract / SecurityHud labels): find the lever by the tag
  `SecretExitTrigger`; when the player is inside the restricted room (on the lever's side of the panel with the same `ExitId`), within about
  4 studs, facing it and with a clear line, show "[ key ] Pull the lever" (use `InputHints`) and start the hold with `RequestInteract`. Add the
  kind `SecretExit` to the HUD's valid hold labels so the progress bar shows. Outline the lever like the other interactables.
- A client check may be looser than the server's; the server decides.

## Gaps and SPEC-QUESTIONs
- The hold time (1.5 s), open time (12 s), reach (4 studs) and angle (50 degrees) are not specified; they are first guesses in `GameConfig.SecretExit`.
- NPCs and the NPC graph do not know the exits: NPCs never use one, and `RouteService` (GPS) does not route through them.
- No sound or sliding animation: the panel just disappears and comes back. The doorway is not drawn as open on the minimap.
