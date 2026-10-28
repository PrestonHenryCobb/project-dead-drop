# Guard contract (Step 15, ticket 15)

Security NPCs fighting (spec 18.5) and the guards' side of the alarm (spec 18.4). All server side; clients see only what
they already see of an NPC (a walking rig) and a `ShotHeard` for each shot. Nothing is put on any character.

## Server
- `GuardService` (`src/server/Services`): runs at `Security.Guard.ThinkHz` while a match runs (`SecurityService` calls
  `setActive`). A guard engages an **Exposed** agent that is: in a Tier 1+ zone and seen (witness range 35, +20% from Alert,
  110 degree field of view, line of sight); or fired within `EngageFiringRadius` (30, or the weapon's hear radius if
  smaller) of the guard; or hit the guard (provoked for `ProvokeSeconds`). At Lockdown any Exposed agent the guard sees.
  Disguised agents are never engaged: only `CoverService.isExposed` players are candidates.
- It shoots every 0.8 s while the agent is in sight within 40 studs: 60% hit chance out to 15 studs falling in a line to
  20% at 40, 8 damage, no headshots (`CombatService.botFire`, weapon `ReticlePistol` for the look and sound).
- It walks after the agent (`Reactions.pursue`), stops 14 studs from them once in sight, never goes more than 40 studs from
  where it set out, and goes back to its post (`Reactions.recall`) when the agent is covered again, down, or out of sight
  for 4 s.
- `GuardService.alertNearest(position, count)`: `CameraService` calls it when a camera's lock-on raises the alarm; the
  `Camera.AlertGuards` (2) nearest free guards walk to the agent's position and wait 15 s.
- Alarm: from Alert (`AlarmService.onChange`) Security walks at `Alarm.AlertWalkSpeed` (14, `NPCService.setGuardSpeed`);
  on reaching Heightened `Alarm.HeightenedExtraGuards` (2) extra guards appear at Tier 1 nodes at least 40 studs from
  every player (`NPCService.spawnGuard`), up to `Guard.MaxExtras` (6), and are removed when the match ends.
- `CombatService.setProvokeHooks({ fired, hitNpc })` tells `GuardService` about shots and hits on NPCs.
- `Reactions` gained `pursue`, `holdPosition`, `recall`; `Death.forget`; `NPCService` gained `setGuardSpeed`, `spawnGuard`,
  `removeNpc`, `pursue`, `holdPosition`, `recall`. Guards use the existing Investigate/Return states, so a pursuing guard
  looks like any NPC walking.

## Client
No change. Shots are drawn by the existing `ShotHeard` handling.

## Not built (named gaps)
- Guards have no aiming pose or visible gun (NPC rigs hold nothing); the shot is a tracer and a sound.
- The vault's two extra guards (`Vault.ExtraSecurityOnOpen`, spec 9) are not placed yet; `NPCService.spawnGuard` is the call.
- The siren (Step 20).
- A bot (a crowd NPC standing in for a player) is never engaged by guards.

## SPEC-QUESTIONs
- Respawn: the spec says a guard respawns 60 s after death at its post. NPCs stand up where they fell 60 s later
  (`NPC.WakeUp`, SPEC_CHANGES relayout-2) and that holds for guards.
- The spec gives no engage reaction time, give-up time, stop distance or re-route values; `Guard.ProvokeSeconds`,
  `LoseSeconds`, `HoldStuds`, `RepathStuds`, `RepathSeconds` are implementation values.
- "Firing within 30 studs" uses the weapon's own hear radius when that is smaller (a suppressed weapon is heard less far).
- Heightened extras spawn each time the alarm rises into Heightened (up to a cap of 6 at once), not once per match.
