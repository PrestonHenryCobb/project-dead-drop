# Audio cues (ticket audio-defs, Step 20; Claude Code, 2026-11-20)

**Built, not run in Studio, and silent until you add sound ids.** Spec 23. `Defs/AudioDefs` lists every non-weapon cue with `Id = ""`; the cue system
(`Controllers/AudioCueController`) skips an empty id, so adding an `rbxassetid://` id to a line is all it takes. I could not audition or verify any
Roblox library id from here, so none is guessed (weapon, hitmarker and impact sounds already have ids elsewhere). Timings and ranges: `GameConfig.AudioCues`.

| Cue | Plays when |
|---|---|
| ExposedSting | you become Exposed (flat), and at the spot of an `ExposedPing` within 60 studs (positional) |
| DisguiseSwap | your worn outfit changes (`DisguiseUpdate`). Only the wearer hears it: no remote tells others (spec 23's 10-stud audibility is not built) |
| VaultUnlock / VaultOpened | the Vault Breach phase starts / a terminal becomes Hacked (`VaultProgress`) |
| PackageDropped / PackageReturned | `PackageState` goes Carried to Dropped / Dropped to Pedestal |
| ExtractionCalled / HelicopterArrival | `ExtractionState` becomes Countdown / Hover |
| LastMinuteTick | once a second while the match clock (`MainEndsAt`) has `Audio.LastSecondsTicking` (60) s or less |
| Siren (loop) | alarm level is Lockdown |
| Ambient[tier] (loops) | the tier of the ZoneVolume you stand in, faded between tiers over 2 s |
| Crowd (loop) | volume rises with bodies within 40 studs, full at 25 |
| FootstepWalk / FootstepSprint | every body near the camera, one rule for an NPC and an agent (rule 3): a step per 4.5 studs walked, sprint set above 15 studs a second |

## Gaps and SPEC-QUESTIONs
- No sound plays until ids are set. Music is a loop per tier, not a playlist; a quartet crossfade is the Ambient[0] loop.
- Footsteps come from drawn positions of models in `workspace` (players' characters and NPC rigs alike). Other players' stepped positions (12 Hz)
  may make the stride slightly uneven. Own footsteps play too.
- Sprint is told apart by speed only (an alerted guard at 14 is below the 15 threshold, a sprinting agent at 18 is above).
- Per-agent ability and gadget sounds are not part of this table (no cues exist for them yet).
