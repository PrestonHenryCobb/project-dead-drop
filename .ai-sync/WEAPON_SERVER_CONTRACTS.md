# Weapon server contracts (tickets 8.5a, 8.5b, 8.5e, 8.5f)

Written by Claude Code, 2026-10-27, for Codex. **Update 2026-11-03:** all six weapons are now registered in
`WeaponDefs` (Codex, commit 90df8d0) and `PendingWeaponDefs.luau` is empty. The server rules were run in Studio for the
first time on 2026-11-03 against NPC targets; see "Studio results 2026-11-03" below for what passed and what still needs
a second player. The sections after it are the original contracts.

To select one on the server alone (playtest, one player) use the real selector so the client agrees:
`CombatService.testCycle(player, "All")` repeatedly until `getTestWeaponId(player)` is the weapon wanted (a Script created
from `execute_luau` shares the live module cache; a Command Bar `require` does not). Then fire from the Client side with
`FireRequest:FireServer(origin, direction, serverTime, weaponId)` (a list of 8 directions for the pump) and
`RequestMelee:FireServer("Press"/"Release", look)`. `testEquip` still exists but leaves the client on the old weapon, which
makes the real `WeaponController` cancel scripted melee holds.

## Studio results 2026-11-03 (solo, NPC targets, Guests frozen with `NPCService.setHeld`)

| Weapon | Checked and passed |
|---|---|
| Pump | One pull = one `HitConfirm`; 8 x 11 x 1.5 head multiplier on an NPC (132). Per-shell reload: Mag 3 to 6 in steps of 0.5 s, Reserve 12 to 9, last `AmmoUpdate` has `ReloadSeconds = 0`. Firing mid-reload keeps the shells already loaded and stops the reload. Empty magazine reloads six shells (Reserve 8 to 2). |
| Hammer | Tap 70 (HP 50 to -20). Hold 1.0 s then release 100 (HP 50 to -50). A second press 0.4 s after a swing is refused; one 1.3 s later is accepted. A rear press starts the default 1.2 s takedown. |
| Garrote | Swing 40 (two swings, HP 50 to -30). Rear takedown: `MeleeState` Seconds 0.8, Strike `Result = Downed` after 0.8 s, 100 damage. |
| Guise pistol | First shot while Covered does 33 (22 x 1.5); a shot while Exposed does 22. |
| Flare | `ProjectileLaunched` to the shooter, `ProjectileImpact` 0.19 s later (`Reason` Npc or Wall), `LightUntil` = impact + 5.0 s. Direct hit 55 (HP 50 to -5), `TargetGlow` `ExpiresAt` = impact + 4.0 s to the shooter's team. Landing 3 studs from another NPC: that NPC takes 15 (50 to 35). One loaded round, reload 1.6 s. |
| Smoke SMG | 32 rounds at 750 RPM into the floor: exactly 5 `SmokeCloud` events (rounds 28 to 32), `Radius` 2, none before. |
| Knives | Chest 45 (50 to 5), NPC head 90 (50 to -40). Six throws; the seventh is refused with `AmmoUpdate Mag = 0`. Six `LandedKnife` parts in `workspace.LandedKnives`, no attributes, none named for the thrower. |

**Not run (needs a second human, or a real prompt):** the pump's 1 HP floor and Stagger on a player; the hammer shove of a
player; `TargetGlow` not reaching an opponent; knife pickup (a `ProximityPrompt` cannot be triggered under remote control,
`InputHoldBegin` did nothing; the handler `onPickup` was read: one step checks `landed[part]`, reach and room, then
destroys the part); the garrote's silence towards witnesses; Ambush while Suspicious (code reads `isCovered` only).

**Harness note, not a server bug:** scripted `Press` holds were cancelled about 0.35 s in by a `RequestMelee Cancel` sent
by the real `WeaponController` (it calls `cancelLocalMelee()` every frame while `attackBlocked(camera)` is true, the
wall tuck). A takedown completed in 4 of 8 tries; short swings were unaffected. Codex may want to confirm that a takedown
held from behind an NPC is not cancelled by the tuck when the target stands 3 to 6 studs away in open space.

## Shared fields (Types.WeaponDef, all optional)

| Field | Meaning |
|---|---|
| `Melee` | `{SwingDamage, SwingSeconds, SwingReach, ChargeSeconds?, ChargeDamage?, ShoveStuds?, TakedownSeconds?, TakedownDamage?}`. The weapon never fires (`FireRequest` is ignored); V uses these numbers. |
| `Projectile` | `{Kind "Flare"/"Knife", Speed, Gravity, MaxSeconds, SplashDamage?, SplashRadius?, LightSeconds?, GlowSeconds?, PickupStuds?}`. `FireRequest` throws it. `Damage`/`HeadshotMult` on the def are the direct-hit numbers. |
| `ReloadPerShell` | `ReloadSeconds` is per round. |
| `SurvivesFullHealth` | One pull cannot take an agent who began it at full HP below 1 HP. |
| `Stagger` | `{MinPellets, WithinStuds, SlowMult, Seconds, AimBumpDegrees}`. |
| `Smoke` | `{Rounds, Radius, Seconds}`. |
| `HearStuds = 0` | Silent: no gunshot for NPCs, no `ShotHeard`. |

## New remotes (all server to client)

| Remote | Payload | Who gets it |
|---|---|---|
| `ProjectileLaunched` | `{Id, Kind, Origin, Velocity, Gravity, StartedAt (server clock), Own}` | the shooter (`Own = true`) and players within `Combat.Projectile.ViewStuds` (160) of the launch |
| `ProjectileImpact` | `{Id, Reason "Wall"/"Agent"/"Npc"/"Expired", Position, Normal?, LightUntil?}` | the same viewers plus anyone within `ViewStuds` of the landing |
| `SmokeCloud` | `{Position, Radius, ExpiresAt}` | everyone |
| `TargetGlow` | `{TargetId, ExpiresAt}` | Suture's team only (the shooter alone in Solos) |
| `CombatStatus` | `{Kind "Stagger"/"Shove", Seconds, SlowMult?, AimBumpDegrees?, From?, Direction?, Studs?}` | the victim only |

No remote was added in the client-to-server direction. Rate limits are unchanged.

## 8.5a Guise garrote (`GuiseGarrote`)

- Tap-swing: `RequestMelee` Press then Release as today. Damage `Melee.SwingDamage` (40), reach `SwingReach` (4) plus the
  existing 1.5-stud slack, next swing or takedown no sooner than `SwingSeconds` (0.8) after the last.
- No charge: `ChargeSeconds` is nil, so every swing is 40 however long V is held.
- Rear takedown: acquisition is unchanged and shared (6.5 studs, 90-degree rear cone). The hold takes
  `TakedownSeconds` (0.8) and deals `TakedownDamage` (100). Silent: nothing makes noise; NPCs panic only through the
  existing witness logic when they see the body fall.
- `MeleeState.Seconds` now follows the held weapon: `TakedownSeconds` for a Takedown, `ChargeSeconds` (or the default
  0.75) for a Charge. Use it for the client bar.
- The weapon has no ammo and cannot be fired or reloaded. The client should send no `FireRequest` and show no ammo.
- **Ambush rule changed to match the answers:** `AmbushMult` (Guise pistol) now needs *Covered*, not Suspicious
  (`CoverService.isCovered`). Raised as SPEC-QUESTION below.

## 8.5b Parapet pump shotgun (`ParapetPump`) and hammer (`ParapetHammer`)

Pump:
- `FireRequest` carries 8 unit directions (as `Pellets` weapons do). 70 RPM, so 0.857 s between pulls.
- Reload is one round at a time. `AmmoUpdate.ReloadSeconds > 0` means "a round is loading, done in that many seconds"; it
  is sent again after each round while more are to come, and `ReloadSeconds = 0` when the reload ends (full, out of
  reserve, or interrupted). **Firing interrupts the reload** and keeps the rounds already loaded; a round that is due
  counts. Predict the same.
- The pull's damage is tallied per target and applied once (one hitmarker, `Head` if any pellet was an Exposed head). An
  agent who started the pull at full HP is left with at least 1 HP, plates or none.
- Stagger: 5 or more pellets on one player within 12 studs of the shooter: the server slows their `WalkSpeed` by 25 percent for 0.35 s
  (`DisguiseService.applySlow`) and sends them `CombatStatus {Kind="Stagger", Seconds, SlowMult, AimBumpDegrees=1.5, From}`.
  **Codex draws the aim bump** (the client moves the view `AimBumpDegrees` away from `From`; Studio tuning). It does not
  interrupt firing. An NPC hit the same way (5 pellets within 12 studs) walks slower for the same time (`NPCService.slow`,
  2026-11-19), so a stagger never tells an NPC from an agent; it gets no aim bump (it has no aim).

Hammer:
- V press near nothing starts a charge; releasing swings. Under `ChargeSeconds` (1.0): 70. At or over it: 100 and a shove.
  Reach 6, cadence 1.1 s. No ammo, never fires.
- Shove: `CombatStatus {Kind="Shove", Direction, Studs, Seconds}` to a player victim; `MovementController` (client, mine)
  runs the character along `Direction` for `Studs` over `Seconds` (0.25). `Direction` is the swinger's right. Walls cut
  `Studs`; open edges do not, so the victim can fall (normal fall damage applies). NPCs are not moved (see gaps).
- A takedown with the hammer uses the default 1.2 s / 90 damage (it sets no takedown fields).

## 8.5e Suture flare (`SutureFlare`)

- `FireRequest` with one direction. The server spends the round, then `ProjectileService` flies the flare under gravity
  (speed 70, gravity 45, 4 s). Rate and reload are the normal `RPM` and `ReloadSeconds` (1.6 s, 1 loaded, 12 reserve).
- Sends `ProjectileLaunched` to the shooter and nearby players. The shooter may have predicted the flare: match by
  `Own = true`, then adopt the server's `Id`.
- Direct hit: 55 damage, no extra splash. Then every other target within 6 studs with a clear line to the landing point
  takes 15 (teammates and the shooter are spared). The struck character glows for Suture's team 4 s (`TargetGlow`,
  `TargetId` = the body's model name (an NPC and a player alike; History's `"P" .. UserId` is never sent); **the glow follows the character, so a disguise change never ends
  it**; the client draws it with line of sight, and must never mark the rig with an attribute).
- Landing: `ProjectileImpact` with `LightUntil = now + 5`. Clients light the area until then, no damage. A flare that
  hits a person lights at that person; a flare that times out lights where it is. Cleanup belongs to the client Janitor
  at `LightUntil`.
- Firing is loud (normal gunshot to NPCs) and breaks Cover like any shot.

## 8.5f Feint smoke SMG (`FeintSmokeSMG`) and throwing knives (`FeintKnives`)

Smoke SMG:
- An ordinary automatic firearm. The server's own magazine count decides: a round fired with 5 or fewer in the magazine
  (before it leaves) that hits a person or a wall sends `SmokeCloud {Position (the impact), Radius 2, ExpiresAt}` to
  everyone. The cloud does no damage.
- Each cloud is also recorded on the server (`Combat/Smoke`, 2026-11-19) and blocks line of sight for Agent Sense, scans,
  witnesses (Cover: NPCs, guards and cameras seeing an act), guards and camera cones. A viewer inside a cloud is blocked too. It
  does not stop shots or sound, and NPC panic and hearing are unchanged.

Knives:
- `FireRequest` with one direction, 100 RPM (0.6 s), `MagSize` 6, no reserve, no reload. The throw is silent: no
  gunshot for NPCs, no `ShotHeard`. It still breaks Cover (using a weapon).
- 45 damage, 90 on a head that counts (an Exposed head; a disguised agent's head counts as body).
- A knife lands where it hit or where it timed out (3 s) and rests as a `Part` named `LandedKnife` in
  `workspace.LandedKnives`, replicated to everyone, with a server `ProximityPrompt` ("Pick up knife", hold 0.2 s,
  4 studs). The part carries no attributes and nothing about who threw it.
- Pick-up: any agent *currently holding knives*, an opponent too. The server checks they are alive, not downed, within
  reach, and below 6 knives, then removes the part and adds one round, in one step, so a knife can never be picked up
  twice or copied. Knives left over stay on the floor. They never expire during a round.
- **Client work:** draw the knife in flight from `ProjectileLaunched`, replace the default `LandedKnife` part's look if
  wanted (keep its name and parent), and a "pick up" hint. Pickup works today through the prompt with no client code.

## 8.5c Lattice burst rifle (`LatticeBurstRifle`) and taser (`LatticeTaser`) (2026-11-19, built, not run in Studio)

Entries with the approved numbers are in `src/server/Tools/PendingWeaponDefs.luau`; Codex moves each into `WeaponDefs` when its
model, handling and prediction are ready (the Hardware slots already exist in `AgentDefs`).

Burst rifle:
- 12 damage a round, `Burst { Count = 3, DelaySeconds = 0.35 }` (the client sends each round; the server follows `FireRate`), 24 loaded
  and 48 spare, 2.2 s reload, falloff 60 to 140 studs down to 70 percent. SPEC-QUESTION: the rate inside a burst is not specified
  (`RPM = 900`).
- `Tracker { Seconds = 3 }`: when every round of one burst (`Burst.Count` consecutive hits, each within
  `Combat.TrackerBurstGapFraction` of the burst pause of the last) lands on the same **agent**, the server sends `TargetGlow` to the
  shooter alone (`TargetId` = the body's model name, `ExpiresAt` = now + 3 s). A miss, a different body or a pause starts over.
  NPCs are never marked. **Owner answer 2026-11-19: the mark shows through walls.** The event is `TargetGlow` with the new field
  `ThroughWalls = true` (Types.TargetGlowInfo): the client draws that glow even when the body is behind a wall (the flare glow, which
  has no flag, still needs line of sight).

Taser:
- One dart, 30 damage, `MaxRange = 25` (a new optional `WeaponDef` field: the ray stops there), 1 loaded and 10 spare, 2 s reload.
- A hit that leaves a **player** standing: `DisguiseService.applySlow(victim, 0.4, 1.5)` (60 percent slower for 1.5 s),
  `Combat/Lockout` for 3 s (`AbilityService` and `GadgetService` refuse requests while it runs) and
  `CombatStatus { Kind = "Taser", Seconds = 1.5, SlowMult = 0.4, From }` to the victim only. NPCs take the damage and nothing else.
  A downed or eliminated target takes no status; teammates are not hit (the existing team rule).
- Owner answer 2026-11-19: the dart is **quiet** (`Quiet = true` in WeaponDefs: heard only `Audio.SuppressedWeaponRadius` (25 studs) away, no
  muzzle flash or tracer). SPEC-QUESTION still open: no head bonus (`HeadshotMult = 1`).

**For Codex:** register both when ready. Burst rifle: the client must send each round of a burst on the `FireRate` timing (it already
does for bursts), and draw the `TargetGlow` it receives (shooter only). Taser: a single-round weapon with a 25-stud range; show a
`CombatStatus` "Taser" to the victim (slowed, abilities locked for 3 s, the server does the slow and the lock; show the lock on the
ability and gadget HUD from this event, which carries only the slow time).

## Studio test steps (server rules; after the client side lands, repeat with real input)

All with one player, `Debug.TestMode` Duos or Solos, after a fresh Play. Equip with `testEquip` (above). Fire from the
Client command bar by firing the remote with a script, or wait for Codex's client.

1. Garrote: equip, stand behind an NPC within 6 studs, `RequestMelee Press` with the look direction, wait 0.8 s: the NPC is
   downed and NPCs that did not see it do not panic. Tap from the front: 40 damage, not before 0.8 s.
2. Pump: equip, `ReloadRequest` with 2 spare shells missing: `AmmoUpdate` arrives each 0.5 s; fire mid-reload and the
   remaining rounds stay. Shoot a full-health second client with all 8 pellets on the head: left on 1 HP. Within 12 studs
   they walk 25 percent slower for 0.35 s and receive `CombatStatus Stagger`.
3. Hammer: tap = 70; hold V 1 s then release = 100 and the victim slides about 3 studs to the right; beside a wall they do
   not move into it.
4. Flare: fire at an NPC across the room: `ProjectileLaunched`, then `ProjectileImpact` with `LightUntil`; the NPC takes
   55; another NPC within 6 studs takes 15; a Suture teammate receives `TargetGlow`, an opponent does not.
5. Smoke SMG: with a full 32 magazine the first 27 rounds send no `SmokeCloud`; the last 5 do, at their impact.
6. Knives: throw all six; `AmmoUpdate` Mag 0 and the 7th is refused. Landed parts appear. A second client equipped with
   knives picks one up (Mag 1); a client without knives cannot. Two clients triggering the same knife get one round.

## Gaps and SPEC-QUESTIONs

- Run in Studio against NPCs on 2026-11-03 (see the results table above); player-victim effects still untested.
- NPCs are now **slowed** by the pump stagger and the taser (`Movement.slow`: the same multiplier and seconds as a player), but
  still **not shoved** by the hammer (their position comes from the crowd's route). An observer comparing a shoved player with an
  unshoved NPC could still see the difference; a shove for NPCs is not built.
- Smoke blocks sight checks on the server (see the smoke SMG section) but not shots, sound, Bug Cams or the Long Lens.
- Landed knives and flights in the air are cleared when the match goes to Lobby or Insertion (ProjectileService, 2026-11-19).
- SPEC-QUESTION: the hammer's "sideways in the direction of the swing" is implemented as the swinger's right.
- SPEC-QUESTION: the ambush shot now needs Covered (the answers' wording); before it also worked while Suspicious.
- SPEC-QUESTION: the knife prompt is visible to every agent near a landed knife, including ones who cannot use it.
- Flight values (speed, gravity, 4 and 3 s limits) and pickup reach are Studio tuning, set in `PendingWeaponDefs`.
- The pump's `PostMeleeFireDelay`, hammer/garrote `PostMeleeFireDelay` and the flare's are for Codex to set with the
  client handling. `PostMeleeFireDelay` still applies to any weapon that has it.

## Next client handoff for Codex

1. Register the four weapons in order of your choice (each needs model, handling, prediction): pump (8-direction
   request, per-shell reload and its `AmmoUpdate` pattern, aim bump from `CombatStatus`), flare (`ProjectileLaunched`
   draw and adopt, `ProjectileImpact` light, `TargetGlow`), smoke SMG (`SmokeCloud` draw), knives (flight draw, optional
   pickup hint), garrote and hammer (melee view model, no ammo UI, `MeleeState.Seconds`).
2. Never add attributes or tags to a character for any of this.
3. Move each registered weapon out of `PendingWeaponDefs`; the `AgentDefs` hardware slot then makes it selectable.
