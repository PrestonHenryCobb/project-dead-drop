# Team pings (ticket 19-pings, server; Claude Code, 2026-11-19)

**Built, not run in Studio.** Lint clean. Spec 21.3. Server: `Services/PingService`.

## Contract
- Client to server: `RequestPing(kind: string, position: Vector3, targetId: string?)`, rate limit 3 per second (burst 5).
  - `kind` is one of `GameConfig.Ping.Kinds`: `Look`, `Suspect`, `Intel`, `Danger`.
  - `position` is where the marker goes (a world point the player aimed at). It is refused if not finite, or further than
    `Ping.RangeStuds` (400) from the player.
  - `Suspect` needs `targetId`: the name of a model the client can see (an NPC's name, or a player's character name as the
    client knows it, which is the same id the combat code uses: `P<UserId>` is **not** a model name, so the client must send the
    model's `Name`). The server looks it up in `Combat/History` (living bodies only), refuses your own body, and uses the body's
    current position instead of `position`.
  - Refused outside a match, while downed or eliminated.
- Server to client, to the pinger and their team only (the pinger alone in Solos):
  - `PingPlaced` payload `Types.PingInfo { Id, Kind, Position, TargetId?, ExpiresAt (server clock), From (display name) }`.
  - `PingCleared` payload the marker id (number), sent when a marker ends early (the player placed a fourth, or left).
- At most `UI.MaxPingsPerPlayer` (3) per player: a new one replaces the oldest. `Suspect` lasts `UI.SuspectPingSeconds` (8 s),
  the other kinds `Ping.Seconds` (8 s, SPEC-QUESTION: the spec gives no time). All are cleared at Lobby and Insertion.

## For Codex (client)
Build the ping input (middle mouse or a button, gamepad), the aim point and context (a person under the crosshair means `Suspect`
with that model's `Name`), and the marker drawing from `PingPlaced`/`PingCleared`: a client-side marker only, nothing on any
character, hidden when `ExpiresAt` passes. A `Suspect` marker rides above the body named by `TargetId` and must not say what it is.
Show `From` only to teammates (the audience already is). Keep to Reduce Motion for any pulse.

## Gaps and SPEC-QUESTIONs
- No line-of-sight or "aimed at" check: a player may ping any point within 400 studs, even through a wall (the same as the game's
  other team markers). A rival never receives it.
- `Intel` and `Danger` have no gameplay effect beyond the marker.
- Kinds other than `Suspect` last 8 s by assumption.
