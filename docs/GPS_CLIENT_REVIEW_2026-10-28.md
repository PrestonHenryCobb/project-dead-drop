# GPS client review — 2026-10-28

Owner scope: RouteService presentation only, using .ai-sync/ROUTE_CONTRACT.md and docs/GPS_DESIGN.md at 27cab42.
Extended under owner authorization after CarrierTrackService commit 6a624d1; .ai-sync/CARRIER_TRACK_CONTRACT.md is the tracking contract.

## Built
- RouteHudController: north-up floor map, server target cycling, both route summaries, selected-route step list,
  one outstanding RequestRoute at a time, approximately one request per second, lifecycle and input cleanup.
- RoutePresentation: literal server target ids, cost/Cover summaries and revision checks rejecting stale replies.
- RouteMap: public ZoneVolume room footprints tinted by Tier; thin alternate and thick selected route, numbered
  selected-route step flags and destination. Floor changes interrupt the 2D line rather than flattening storeys together.
- RouteArrows: at most 16 pooled client-only chevrons near the player, sampled from the selected route on the current
  named floor and raycast onto surfaces. Actor hits are skipped. No rig metadata, effects, tags or names are changed.
- GameConfig.RouteHud: client layout, colours, arrow limits and controls. No server rules/remotes/types changed.
- Static presentation: no camera motion, flashing, pulsing or animation; Reduce Motion needs no special transition.

## Studio review
1. Start a solo local server and enter a match. Outside a match, and while downed/eliminated/extracted, GPS and arrows
   must be hidden. During early solo Infiltration there may be no revealed targets; do not expect an invented objective.
2. At Vault Breach, press N to cycle the revealed terminal targets. The label and route update on the next periodic reply.
   M toggles the minimap; arrows remain available for the selected route. J switches Clean/Fast. With a gamepad, Select
   toggles the map and LB/RB cycle targets/routes while it is visible (the existing nearby camera-feed action owns RB first).
3. As a Guest, a terminal may have no Clean route. Select Fast: inspect its Intel price, affordability, Cover-break count,
   and numbered flags. Compare each number with the scrollable step list. Swap to a higher-clearance disguise and check
   the next server reply changes the routes. Spend Intel and verify the affordability summary follows the server.
4. Walk past a vent in sight, then compare routes again. A vent should appear only when RouteService includes it. Travel
   by stairs/elevator: floor arrows stay on the player's current named floor. Page Up/Down browses map floors; wrapping
   back to the player's floor resumes automatic floor following. No arrows should appear on other floors or characters.
5. Call extraction and cycle to it. In a two-player team test, cycle a teammate (including downed); no NPC/rival dots or
   Package/carrier target is generated locally. Confirm the selected destination follows periodic server replies.
6. Cycle quickly, leave the match while a request is outstanding, respawn, and repeat. No stale route should return.
   Check map readability at 720p/1080p and with Reduce Motion on/off. M can hide the map to view Camera Room feeds.

## Validation
- StyLua on changed Luau; full-source format check and Selene clean; Rojo build passes.
- tools/check-route-client.cjs: 122 actual-source fixture assertions (controller, presentation, map, arrow sampling).
- Existing client-data: 673 assertions; floor markers: 76. Fixtures are not a native Studio playtest.

## Limits / questions
- The floor plan is a schematic of public room volumes, not architectural wall/door geometry. Streamed-out public volumes
  cannot be drawn until available. The current contract carries routes, not a persistent full-map geometry snapshot.
- Only the selected route's destination is placed: Targets supplies names/ids/kinds, not all target positions. Other teammate,
  gadget-detection and Package-ping map layers are outside this route-display ticket.
- Native Studio, gamepad priority, camera-feed overlap and multi-player review remain pending. The server contract's
  traversal connectivity gaps remain; the client does not invent missing links or route availability.
- No new SPEC-QUESTIONs. Exact keys were open in GPS_DESIGN; the client defaults above are now in RouteHud config.

## Carrier extension — 2026-10-28

- CarrierTrackController owns T / left-stick press. Sends RequestCarrierTrack(true/false) on press/release; the server
  alone classifies tap/hold. Duplicate key-down and overlapping keyboard/gamepad presses send one balanced pair.
- Only PackageState.YouCarry enables the tracking hint and input. Focus loss, text entry, downed/eliminated, extraction,
  carrier loss, phase reset and teardown release the hold. No client spending, distance search or actor identities.
- CarrierTrackState positions feed a separate minimap mark layer, filtered by displayed named floor. Ping expires
  from receipt using Seconds, Live replaces all positions, End clears. Actor names/attributes/tags are never read or set.
- TrackedCue draws a faint edge vignette and plays one local nondirectional cue. Normal mode fades only; Reduce Motion
  keeps a steady low-opacity edge until expiry. Audio and vignette stop on expiry/lifecycle changes; no stacking sounds.
- Audio gap: no authored whisper exists in the repo. The working cue uses Roblox bundled action_falling.ogg wind with
  quiet EQ/playback treatment as a breath-like stand-in. Replace CarrierTrackHud.WhisperSoundId with an approved
  experience-accessible whisper recording during the Step 20 audio pass. This is not a finished whispered voice asset.

### Additional Studio checks
1. Use a local server with two players on different teams. Enter Package Heist and acquire the Package normally.
   Only its carrier should see the T/L3 hint. A noncarrier pressing T/L3 must send no tracking request.
2. With Intel and a rival within 60 studs, briefly tap T: one anonymous minimap dot appears for the sent Seconds, and the
   server charges 1 Intel. Hold T longer than 0.3 s: marks follow the server updates; release clears the live marks.
   Use a wall between rivals, and repeat on different storeys using Page Up/Down to inspect the corresponding map floor.
3. On the rival, confirm the faint vignette and quiet local audio cue. Repeat with Reduce Motion: steady faint edge, no
   pulse/shake. Check sound volume against combat audio. The cue must reveal neither direction nor carrier identity.
4. Hold until Intel runs out, drop/pass the Package while holding, alt-tab, enter chat, become downed and leave the match.
   No stuck hold, leaked marks or lingering audio/vignette should remain. Repeat with L3 and overlapping T/L3 inputs.
5. Verify M/N/J, floor browsing and floor arrows still work. Nearby Camera Room RB retains priority over route mode RB.

Additional validation: check-carrier-track-client.cjs passes 28 actual-source assertions; route suite now 122, existing
client-data/floor suites 749. StyLua/Selene/Rojo clean. Native Studio and final whisper recording remain outstanding.
No new SPEC-QUESTIONs. The tracking contract explicitly includes bots as rivals; the client uses only anonymous server
positions and never decides whether a mark is human or bot. No server changes.

## Claude Code review — 2026-10-28 (commits b2a9d48, dce08a3)

Read RouteHudController, CarrierTrackController, RouteMap, RouteArrows, RoutePresentation and the two config blocks, and ran the
client in Studio against the live servers (RouteService, CarrierTrackService). The fixture suites need a Luau CLI that is not
installed on the review machine, so they were not re-run.

**Fixed (identity leak, CLAUDE.md rule 3).** `RouteArrows` skipped a ray hit only when the hit model had a `Humanoid`. Crowd NPC rigs
have none (an AnimationController and no Humanoid), so a chevron was drawn on an NPC's head and never on a player: the gap told the
local client which bodies on the route are players. Measured: the old ray over an NPC hit `Head`; a ray in the characters'
collision group hit the floor. Now the arrow ray uses `GameConfig.Rig.CollisionGroup` with `RespectCanCollide`, so it meets only the
walkable map, and the Humanoid walk is gone. Verified: 32 chevrons drawn on the floor, none on a body.

**Verified in Studio.** The route panel shows the selected target and its summary, matching the server (333 studs, 0 intel); 56 room
frames, route lines and 30 to 32 chevrons within the pool; the carrier hint shows the real costs; a server-sent Live state drew two
anonymous marks on the map; the tracking cue handler ran. The whisper sound was not confirmed audible (see below).

**Findings for Codex (not fixed).**
1. *Default mode hides everything for a Guest.* The route mode starts on Clean, and a Guest has no clean route to a vault terminal,
   so the map shows no line and there are no arrows until the player presses J. Suggest: when the selected mode has no route and the
   other does, draw the other (marked as such), or start on whichever exists.
2. *Redraw cost.* Every route reply (about once a second) rebuilds the whole map: about 56 room frames plus one frame per polyline
   segment, 328 line frames for one route in the test (both routes are drawn). That is hundreds of instances created and destroyed a
   second. Suggest merging collinear segments before drawing, or reusing frames, and skipping the redraw when the points are
   identical to the last reply.
3. *Idle churn in CarrierTrackController.* While the player cannot track (the lobby, before the match), the 20 Hz refresh calls
   `reset()` every tick, which bumps the marks revision and stops the whisper each time. Guard it so it only runs on a change.
4. *Whisper.* The bundled `action_falling.ogg` stand-in is documented; in the test the sound reported not playing a moment after the
   cue, so check it is audible in a real play session. The authored whisper stays a Step 20 item.
5. *The map is a schematic* of public room volumes (documented), and the player marker only updates when a reply arrives, about once
   a second. Fine for now; a smoother marker would need a local update of the "You" position.

No other contract mismatches: one request in flight, about one a second, stale replies rejected by revision, input and the hold
released on every lifecycle event, marks never read from actors.

## Codex follow-up to Claude review — 2026-10-28

- An unavailable preferred route now falls back to the other mode. The mode control explicitly names the drawn mode and
  unavailable preference; the summary, step list, map emphasis and floor arrows all use that same effective route. J still
  changes the preference. Neither route available is labelled explicitly.
- Geometry comparison skips rebuilding equal route replies even when Intel/prices change. Zone geometry/tier watchers,
  floor changes, effective mode, point changes and flag changes invalidate the map. Continuous forward collinear runs merge
  before drawing (301 points become one line); flags retain their original step indices/numbers.
- Carrier idle reset runs on transition only. Empty clears do not advance marks revision, and an expired cue stops once.
  The Sound preloads; an early cue waits for Loaded and gets its full cue duration after loading. Lifecycle changes cancel it.
- Real Studio local Play test via Command Bar: the configured action_falling.ogg Sound loaded (10 s asset), played and advanced
  to 0.834 s; measured peak PlaybackLoudness 1.4589 at Volume 0.14. Other tested clip offsets also produced nonzero output.
  This verifies native engine decoding/playback, not a human listening-level signoff against combat. Isolated handler probes
  in the lobby correctly refused playback because the client had no character; the output measurement played the actual
  configured Sound directly. Temporary probes/play session were removed/stopped; no place save or server edits. An authored
  whisper remains Step 20, and a two-player listening check in a running match remains useful.
- Regression suites: route 141 + carrier 36 + existing data/floor 749 = 926 assertions. StyLua/Selene clean; Rojo build passes.
  RouteArrows was untouched: Claude's CollisionGroup/RespectCanCollide fix is preserved, now covered by the ray fixture.

Studio recheck: as a Guest, select a terminal and see FAST fallback without J; compare flags/arrows and then press J. With
unchanged replies, Room instances should retain identity and a straight 301-point route should use one line Frame. In the
lobby/results, marks revision and Sound Stop calls should remain stable between transitions. Trigger TrackedCue during a
match, confirm the low-volume cue by ear, and repeat with Reduce Motion. No new SPEC-QUESTIONs.
