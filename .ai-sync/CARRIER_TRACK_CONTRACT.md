# Carrier tracking contract (GPS, CarrierTrackService)

Design: `docs/GPS_DESIGN.md`. Server: `src/server/Services/CarrierTrackService.luau`. Built 2026-10-28, tested solo in Studio.
Only the Package carrier can use it. Numbers are in `GameConfig.CarrierTrack`.

## Client -> server
`RequestCarrierTrack(down: boolean)` (rate limit 6 a second, burst 8): send `true` when the tracking key goes down and `false` when
it comes up. The server tells a tap from a hold (a press shorter than `TapSeconds`, 0.3 s, is a tap), so the client never decides.
Ignored unless the sender is the carrier, in a match and on their feet. Keys are still open (the exact key is chosen when the
controls are built).

## Server -> carrier: `CarrierTrackState` (`Types.CarrierTrackInfo`)
- `Mode "Ping"`: one mark, the nearest rival within `Radius` (60 studs, through walls), to show for `Seconds` (1 s). Costs `TapCost` (1) intel.
  Nothing is sent, and nothing charged, when nobody is in range (a Notification says "No rival in range").
- `Mode "Live"`: every rival in range, resent `SendHz` (5) times a second while the key is held. The first second is charged when
  the hold begins and each second after (1 intel a second). Replace the marks with each message.
- `Mode "End"`: clear all marks. Sent when the key goes up, the team cannot pay (a Notification says "Out of intel"), or the carrier
  stops being the carrier.
- `Marks` are positions only. They never say who, and never include a crowd NPC.
- `Intel` is the team's balance after paying. A hold that cannot pay its first second sends nothing and a Notification "Needs 1 intel".

## Server -> rival: `TrackedCue` (no payload)
Sent to each tracked player rival: on a ping, and on a hold when they come into range, then again only after `CueRepeatSeconds` (4)
of continuous tracking. The client draws a low-opacity vignette round the screen edge and plays a whispering sound. It says only
that they were seen, not by whom or from where.

## Rivals
Players of other teams and the bots, on their feet (a downed or eliminated agent is not shown). SPEC-QUESTION: bots count as rivals
because they stand in for agents; a bot is never sent a cue.

## Cover and cost
Tracking does not break the carrier's Cover (owner decision). Intel is the only price, and the cue the only warning.

## For Codex (client)
The tracking key and its tap/hold sending, drawing `Marks` on the minimap (a 1 s blip for Ping, a live set for Live, cleared on End),
and the `TrackedCue` vignette and whisper (respect Reduce Motion for the vignette). The key's hint should show only to the carrier.

## Tested
Solo in Studio, with the carrier check patched for the test player and the six bots as rivals: a tap returned one mark and charged 1
intel; a 2.6 s hold sent 10 live updates and charged 3 intel; a tap with nobody in range charged nothing; a hold with 2 intel ran
2 s, then sent "Out of intel" and End.
Not tested: the cue (needs a second human on another team), a carrier dropping the Package mid-hold, a real pickup.
