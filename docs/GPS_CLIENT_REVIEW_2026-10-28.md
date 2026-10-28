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
