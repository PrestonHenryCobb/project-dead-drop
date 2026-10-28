# GPS and carrier tracking (Step 19, owner answers 2026-10-28)

Decided in a "grill me" session. Nothing here is built. It sits under Step 19 (minimap, pings) and replaces nothing in the
spec; the spec's minimap (toggle M, floor by floor, zone tints, teammates, pinged objectives) is the base the GPS draws on.

## What it is
A **route guide** for match-revealed objectives, always on for everyone (not a gadget or an Asset). The map is fully visible
from the start. The GPS shows a route from you to the objective you choose.

## Targets (cycle with one key)
- Active vault terminals (once the Phase 3 vault ping has revealed them)
- The extraction site (once extraction is called)
- Living teammates (and a downed teammate, to revive)
- **Not** the Package pedestal or the Package carrier: everyone already gets the spec's Package pings (confirmed).

Nothing is marked before the match reveals it. The player cycles targets with a key; the GPS follows the current one.

## Routes
- **Two routes** are shown, and the player picks one:
  - **Clean route**: the shortest legal path for the current disguise (avoids doors and zones its clearance cannot enter; it
    changes when the disguise changes).
  - **Fast route**: the shortest path overall. It may use tier-door hacks (shown with the intel they cost) and **Cover-breaking
    ways** (vents, ziplines, the gondola, secret exits). Each such step is **flagged** on the line and in the route summary.
- **Hidden traversal stays hidden until used**: vents and secret exits never appear on the map or in a route until the player
  has used or seen them.
- Drawn as a **line on the minimap plus floor arrows** in the world, shown only to the player. A floor change (stairs, elevator,
  ladder) is a step in the line.

## Carrier tracking (new mechanic, only for the Package carrier)
The carrier can see other players on the GPS, paid in intel from the team balance:
- **Tap** (1 intel per tap): pings the **nearest rival** only.
- **Hold** (1 intel per second): shows **all rivals within the radius**, live.
- **Limited radius**, through walls. SPEC-QUESTION: the radius is a tunable; 60 studs proposed.
- It **stops when the team cannot pay** the next second.
- **Only players are shown**, never NPCs, and only to the carrier. SPEC-QUESTION: this tells the carrier which dots are players
  (only the ones inside the radius), which is the point of the mechanic; nothing on any character changes.
- **The tracked or pinged rival gets a cue**: a low-opacity vignette round the screen edge and a whispering sound. It tells
  them they were seen, not by whom or where from.
- Not decided: whether using it breaks the carrier's Cover (the answers ticked no Cover penalty; intel and the cue are the price).

## Build split (proposed)
| Part | Owner |
|---|---|
| `RouteService` (server): computes clean and fast routes from the authored lane graph (no `PathfindingService`), clearance from the player's disguise, hack costs, Cover-breaking flags, "used or seen" traversal; a rate-limited request; sends only a polyline and a summary to that player | Claude Code |
| `CarrierTrackService` (server): tap and hold, intel payment each second, radius and nearest-rival checks, sends positions only to the carrier, sends the cue only to the tracked rival | Claude Code |
| Minimap (floor by floor, zone tints, teammates, gadget detections, pings), the route line, target cycling, the carrier tracking controls | Codex |
| Floor arrows (client-only, per-frame cost kept low), the vignette and whisper cue | Codex |

## Minimap contents (from the answers)
Full floor plan from the start; zone tints; **teammates** plus what the team's **gadgets** detect (Scanner Pulse, Bug Cam, the
drone), for the right team only; the spec's pings (vault at Phase 3, the Package carrier every 10 s to enemies). No NPC dots and no
rival dots, except the carrier's tracking above.

## Open points (defaults chosen if not answered)
1. Tap versus hold threshold: 0.3 s (a press shorter than that is a tap).
2. Radius: 60 studs.
3. Keys: M toggles the minimap (spec); one key cycles the GPS target; one key switches clean and fast; carrier tracking on its own key.
4. How long the nearest-rival ping marker stays: 2 s.
