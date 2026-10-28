# Named-floor marker cues (19-vertical-markers)

Uses the existing generated map protocol; no server edit or new remote is required. `Gala/Build.luau` names public
ZoneVolume parts `Zone_<level>_T<tier>_<room>` and sizes their vertical span to the next authored storey. The client
reads those names and bounds, including legacy GH, rather than inventing a floor every ten studs.

## Files and behavior

- `Combat/FloorBands.luau`: deduplicated named intervals, updated only when streamed volume membership changes.
  Queries scan named bands, not every room. Missing/ambiguous floor data returns no hint; no nearest-floor guess.
- `Controllers/FloorMarkerController.luau`: tracks tagged map volumes and supplies a cue relative to the current
  camera, including camera replacement/spectating. Owns all connections/cache through Janitor.
- `TeammateMarkerController`: adds an up/down floor label below the existing private-roster diamond. No self/enemy
  marker, character decoration, team rule or life-state rule changed.
- `VaultHudController`: revealed terminal world captions show the named floor when different.
- `PackageHudController`: resting Package, authorized carrier pulses and extraction captions show the floor cue.
  No carrier identity/position is inferred. An expired pulse is neither shown nor queried for a floor.
- `tools/check-floor-markers.cjs`: actual resolver/controller source against volume fixtures derived from both
  authored Layout and Relayout level tables, with the generator's real vertical geometry/name convention checked.
- Existing match/objective/Package tests now cover floor-caption integration. Queue status updated under locks.

Examples: `↑ M`, `↓ B`. A ten-stud difference inside the same authored storey gives no arrow. Unknown maps or missing
streamed volumes keep the original marker without a floor suffix. No attributes, tags, values or names are written
to any character/NPC. Visibility, range, line-of-sight, lifetime and server disclosure policies are unchanged.

## Validation

Changed source passes StyLua/Selene; full-source read-only formatting and lint checks pass; Rojo build passes.
Actual-source suites: 76 floor + 673 client data + 228 weapon + 41 match + 29 objective + 30 Package = 1,077 assertions.
Cases cover both authored layouts, room duplicates, repeated discovery, streaming removal/re-addition, exact band
boundaries, same-room height differences, ambiguous intervals, unknown heights, camera replacement and teardown.

This is not a new Studio playtest or native rendering claim. Later visual checks: compare a teammate/objective on
the same storey at different heights, then one on the next storey; verify the arrow only in the latter case. Watch
a carrier pulse expire and confirm its marker/floor cue disappear together. All characters must remain undecorated.

## Limits and coordination

Generated volumes are static. A different map generator must preserve the public naming/bounds convention or supply
an explicit floor contract; the helper safely stays silent otherwise. During partial streaming a hint may temporarily
disappear. No new gameplay SPEC-QUESTION. Claude's bot work is separate: rival crowd-NPC bots do not gain special
markers or labels. No Claude change is needed for this ticket.
