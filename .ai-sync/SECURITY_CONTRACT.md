# Security contract (Step 14, ticket 14)

Server-authoritative cameras, laser grids, keycard doors and the alarm (spec 18). Clients only draw.

## Server
- `AlarmService`: level 0 to 3, `raise(amount, reason)`, decay 1 level per 45 s with no raise, Lockdown 20 s then Level 2.
  Armed only during a match (`SecurityService`), reset Calm at Lobby and Insertion. Remote `AlarmLevel(level)` to everyone
  (new joiners get the current level). Raises come from: suspicion meter full, camera lock-on, laser crossing, NPC kills
  (civilian 1, Security 1, Warden/Curator 2, `CoverService.onNpcKilled(player, role)`).
- `CameraService`: tag `SecurityCamera`. Sweep 90 deg / 6 s, cone 60 deg, range 50. Camera is a Cover witness (`kind Camera`,
  own range and fov). Locks on to an Exposed agent in Tier 1+ or a trespasser; 1.5 s of view raises the alarm once;
  sweeps on after 1.5 s without the target. Interact kind `Camera` (hack 2 s within 6 studs on the floor plan): disabled 30 s,
  not hackable for 30 s after. A shot that ends within 2.5 studs destroys it for 60 s (`CombatService.setWorldHitListener`).
  Lockdown sweeps 1.5x. Camera Room terminal (tag `CameraTerminal`, made at match start on a clear spot of room `b_camera`):
  Interact kind `CameraTerminal`, hold 5 s, disables every working camera 20 s, 120 s cooldown, breaks Cover.
- `LaserService`: tag `LaserGrid` (2 on the map). Crossing Exposed or below the doorway's tier: alarm +1 and Exposed.
  A fuse box (tag `FuseBox`, made beside each grid) with Interact kind `FuseBox` (3 s) cuts that grid 30 s, quiet.
- `DoorService` + `SecurityService`: tag `KeycardDoor` gets `SecurityId` "K1..". Interact kind `Lockpick` (4 s) breaks
  Cover, opens it for 4 s. Lockdown seals keycard doors 20 s (`DoorService.seal`).
- Replication (no new remotes): attributes on map props only. Camera: `SecurityId`, `CameraState`, `SweepPhase`, `SweepSince`,
  `SweepRate`, `HackableAt`. Terminal: `SecurityId`, `ReadyAt`. Grid: `LaserOn`. Door: `SecurityId`, `Open`.

## Client
- `CameraController`: swings each camera from its attributes, SpotLight cone (white sweeping, red locked, off when down).
- `SecurityInteractController`: hold Interact on a camera, fuse box, Camera Room terminal or keycard door; outline on target.
  Uses the existing `InteractState` for the hold bar.

## Tested in Studio (solo, 6 bots running)
Camera locked an Exposed agent and raised the alarm to 1 after 1.5 s; hack disabled it (30 s + 30 s immune); terminal disabled
all 12 and started a 120 s cooldown; laser crossing raised the alarm and exposed; fuse box cut the grid; lockpick opened a
test keycard door for 4 s; Lockdown sealed it for 20 s and dropped to Level 2; client sweep and cone light run.
**Not tested:** shooting a camera, camera spotting a Suspicious agent doing a suspicious action (witness path), two players.

## Not built (named gaps)
- Guards' side of the alarm: 2 nearest Security NPCs alerted by a camera, Heightened extra guards, Alert walk speed 14,
  Lockdown shooting (Step 15). Siren sound (Step 20).
- Camera Room live feeds (4 feeds) and an alarm pip HUD beyond the existing Alarm indicator (Step 19, Codex).
- Keycards (cache, Keycard Clone, Ferro, printer), Jammer, Sparrow drone camera hack (Steps 16 to 18). The map has no keycard
  doors now (re-layout); the Lockpick path was tested on a temporary tagged part.
- Mirage hologram camera lock (spec 27 #19), smoke blocking camera sight (smoke is client-visual only).

## SPEC-QUESTIONs
- Camera unlocks after 1.5 s without its target and raises the alarm once per lock (spec silent).
- Camera hack reach is measured on the floor plan (cameras are high on walls).
- Fuse boxes and the terminal are made at runtime on clear floor (the generator does not place them).
