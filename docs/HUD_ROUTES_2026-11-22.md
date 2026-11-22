# Solid progress loops and room routes — 2026-11-22

Owner requested continuous filling cooldown/vault loops, lettered vault emblems instead of word-based global pings, and a
subtle continuous route from the current room that favors nearby exits in the direction of movement.

## Built

- `src/shared/Util/HudKit.luau`: replaced separated radial ticks with a connected clockwise stroke over a dim circular track.
  The leading segment changes length with fractional progress. Ability cooldowns fill as they recover; vaults fill with
  authoritative hack progress. The match watch uses the same solid stroke and retains its remaining-time countdown.
- `src/client/Combat/VaultBadge.luau`: original outlined vault door with the server-revealed vault letter inset.
- `src/client/Combat/VaultProgressGraphic.luau`: lettered emblems inside the continuous progress dials, with percentage,
  completion check and contested warning retained.
- `src/client/Controllers/VaultHudController.luau`: compact lettered emblems replace the global marker's name/floor prose.
  Existing revealed-only and completed-vault visibility rules remain. Renamed the config alias to avoid the previously
  reported static-check alias collision; no checker was run.
- `src/client/Combat/RouteArrows.luau`: the existing module now pools connected, thin, muted ivory floor segments and corner
  joins. Removes neon chevrons, spacing gaps, moving radius cutouts and per-arrow floor probes. Uses the authored floor
  geometry with a 180-stud contiguous prefix and a bounded pool; only the tail is clipped.
- `src/server/Services/RouteService.luau`: selects a lane in the containing room, retains the previous room in padded doorway
  overlaps, and favors valid nearby exits ahead of actual horizontal movement. The preference is bounded by 48 equivalent
  studs and held for 1.5 seconds when stopping. The visible path starts at the room exit approach rather than the player's
  exact position. Required actions/warnings are never trimmed away.
- The server now chooses the nearest reachable revealed objective in automatic mode instead of the first listed vault.
  Clean routes take priority; Fast is the fallback. Objectives retain priority over teammates. Both existing all-node
  searches are reused for all candidate targets, preserving clearance, hacks, elevators and hidden-vent rules.
- `src/client/Combat/RoutePresentation.luau` and `Controllers/RouteHudController.luau`: distinguish automatic target choice
  from manual target cycling. Manual targets stay pinned until removed or the phase resets. A failed refresh retains the
  last accepted line for at most five seconds. Revision checks and lifecycle cleanup remain.
- `src/shared/GameConfig.luau` and `.ai-sync/ROUTE_CONTRACT.md`: presentation/steering tunables and the revised route contract.

No new remotes, input hints, character metadata, rewards, interaction rules or map geometry were added. The existing
RequestRoute rate limit and refresh interval remain. The server work is necessary because it chooses the path; changing
only the renderer would retain player-root routes and arbitrary target order.

## Owner visual check in Studio (not performed)

1. One-player match: activate a Talent. The dim loop should fill continuously as cooldown expires. The top watch should
   show a solid countdown stroke, with its existing urgency treatment near expiry.
2. Enter Vault Breach and hack a terminal: revealed A–E emblems should match between world markers and the top dials.
   Hack progress should fill the loop; contested color/backing and completion checks should remain legible.
3. Walk around a room with multiple exits. The line should stay on its authored route, begin at the exit approach rather
   than follow your feet, and favor a nearby viable doorway in your movement direction. Pause at a doorway to check it does
   not bounce between overlapping room volumes. Turn and move toward another exit to check replanning on the next refresh.
4. Move between rooms/floors; compare Clean and Fast; manually cycle targets. Confirm restrictions/actions are preserved.
   Floor transitions and Cover-breaking traversal entrances deliberately end the floor ribbon, which resumes from a fresh
   route on arrival. It should not draw a straight floor line through a vent wall or across a gondola gap.
5. Confirm the minimap remains top-right and M/Comma keep their existing behavior. No new opaque gameplay backing should appear.

## Limits and handoff

Source reviewed and changed Luau files formatted with StyLua only. No tests, lint, builds, Studio or desktop control were
run, per owner instruction. Native rendering, stair alignment, font readability, doorway preference and intensity need
owner acceptance. The line relies on the authored navigation graph: it does not invent shortcuts across missing graph
connections or promise a route where the player's clearance cannot reach the target. Direction weighting and line opacity
are initial tuning values in GameConfig.

SPEC-QUESTIONs: none. Ready for owner visual review of this HUD/navigation pass. Claude can review the server routing and
updated contract after the locks are released; unrelated shared-file edits were preserved and excluded from this commit.
