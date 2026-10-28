# Route contract (GPS, RouteService)

Design: `docs/GPS_DESIGN.md`. Server: `src/server/Services/RouteService.luau`. Built 2026-10-28, tested solo in Studio.

## The request
`RemoteController.invoke("RequestRoute", targetId?)` (a client -> server RemoteFunction, rate limit 2 a second, burst 4). Ask about
once a second while a route shows. Returns a `Types.RouteResult`, or `(false, reason)`: "BadTarget" (not a string, or over 40
characters), "NotPlaying" (not in a match, downed or eliminated), "RateLimited".

```
RouteResult = {
  Targets: { {Id, Name, Kind} },   -- what the match has revealed to this player; cycle by sending the next Id
  Selected: string?,               -- the target the routes lead to (the one asked for, else the first)
  Clean: RouteInfo?, Fast: RouteInfo?,   -- nil when there is no such route
  Intel: number,                   -- the team's intel now
}
RouteInfo = { Points: {Vector3}, Length, HackIntel, CoverBreaks, Affordable, Steps: { {Index, Kind, Detail?, Intel?, CoverBreak} } }
```
`Points` runs from the player to the target; `Steps[i].Index` is the point where that step starts. Step kinds: `Stair`,
`Elevator` (floor changes), `Hack` (Detail "Door" or "Elevator", Intel = its price), `Restricted` (a zone above your
clearance), and the Cover-breaking `Vent`, `Zipline`, `Gondola`, `Ladder` (CoverBreak true). `Affordable` is false when the
team's intel cannot pay every Hack on it (the real price may be lower with Wired or Deep Pockets).

## Targets
- `Terminal@x,z` ("Vault terminal", Kind "Terminal"): each open terminal, only during the Vault Breach.
- `Extraction` (Kind "Extraction"): once extraction is called (Countdown, Hover or Open), at the site's pad.
- `Mate:<UserId>` (Kind "Teammate"): a living or downed teammate.
- Never the Package pedestal or carrier (owner decision).

## The routes
- **Clean**: only what the current disguise's clearance may walk (re-asked each time, so it follows a disguise swap), and nothing that
  breaks Cover. An Exposed player has clearance 0.
- **Fast**: shortest overall. Hacks cost `Route.HackStudsPerIntel` studs per intel, a restricted zone `Route.RestrictedStuds`;
  vents, ziplines, the gondola and the service ladders are allowed. Elevators are used by both unless the shaft is locked.
- **Vents are hidden**: a grate is usable only after the player has come within `Route.SeenStuds` of it in sight (checked 2 times a
  second, cleared at Insertion, per player). Entering one leads only to its partner grate. Secret exits are not built, so no route
  uses them.
- Searches run over the NPC lane graph (read from the NPCNode parts again) plus extra nodes where a traversal starts and ends,
  each joined to the nearest lane node within `Route.ConnectStuds` with a clear line at chest height. At the first test 5 of 6
  vents, 1 of 2 ziplines, the gondola and 1 of 2 ladders joined; the others have no lane node within 40 studs in sight. The
  build prints the counts at startup.

## Cost
About 4 ms of server time per request in Studio with 202 NPCs. At 12 players asking once a second that is about 5% of a core.

## For Codex (client)
The minimap, the route line (clean and fast, flagged steps), target cycling (next Id from `Targets`), switching clean and fast,
and the floor arrows. Floor arrows are client-only and use `Points` for the current floor. Keys are still open (M toggles the
minimap, per the spec).

## Tested
Guest (clearance 0): three terminals, no clean route, fast route 782 studs and 23 intel; clearance 3: clean routes with no intel
and no flags; after walking past the grates, the fast route to one terminal used a Vent (782 studs and 23 intel became 423
and 3, one Cover break). Bad input refused; the rate limit held (27 of 30 limited).
Not tested: teammate and extraction targets, zipline, gondola and ladder routes, an elevator route, two players.
