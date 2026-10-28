# Ability contract (Step 16, tickets 16a onward)

Agent abilities (spec 15, key Q). Server-authoritative; the client only asks.

## Server
- `AbilityService`: `RequestAbility` (rate limit 2/s, burst 3). Refused unless the player is alive, in a match, not out, and the
  cooldown (AgentDefs `Talents[1].CooldownSeconds`) has run out. The agent comes from `MetaProgressionService.getLoadout`. An
  agent's ability lives in `src/server/Abilities/<Agent>.luau` (`activate(player) -> (used, reason?)`) and is listed in
  `AbilityService`'s `abilities` table. A used ability starts its cooldown; a refused one shows `reason` as a `Notification`.
- `CooldownUpdate` (to the owner only), `Types.AbilityCooldownInfo { Name, Seconds, ReadyAt }`. `ReadyAt` is server time
  (`workspace:GetServerTimeNow()`). Sent at Insertion (ready, `ReadyAt` = now) and on each use.
- Per-agent numbers that change common rules: `GameConfig.Agents[agentId]`.

## Client
- `AbilityController`: Q (`Controls.Ability`, pad `AbilityPad`) sends `RequestAbility`; `AbilityController.cooldown()` returns the
  last `CooldownUpdate` for the HUD.

## Built so far
- **16a Guise.** Quick Change (30 s): `DisguiseService.quickChange` switches to the first stored look that differs from the one
  worn, instantly, ignoring the combat lockout. Refused while Security tracks the player (3 s after last seen), carrying the
  Package, an Exposed minimum running, or the look's tier below the zone. Two Faces: `Agents.Guise.DisguiseSlots = 2`
  (`DisguiseUpdate.Slots` has two entries) and `ScanSeconds = 0.6` (scanning an Exposed agent still takes 3 s). G now cycles
  stored looks then the insertion outfit.
- Tested in Studio solo: both slots fill, a scan takes 0.6 s, G cycles, Q re-covers in lockout, second Q refused on cooldown.

- **16b Parapet.** Riot Wall (35 s): `Abilities/Parapet` puts up `Combat/Shields`, a see-through part welded 4.5 studs in front
  of his root (8 x 6 x 0.4, 400 HP, 8 s, in `workspace.Shields`, nothing on the character). `Ballistics.trace` stops other
  shooters' rays at it (4th return value `shield`); his own pass; `CombatService` wears it down by the shot's damage (falloff
  included); `ProjectileService` stops flares and knives at it. Ends on expiry, 0 HP, his death, downing, or the match
  ending. Putting it up breaks Cover. `ShieldController` (client) only makes your own shield clearer to you.
  Plated: `Agents.Parapet.ExtraStartPlates = 1` (2 plates, 3 in Solos) via `CombatService.setExtraPlates`.
  Tested solo in Studio: armour 50 at spawn, an outside shot is stopped at the shield, his own shot passes, 400 HP breaks it.
  Not tested: two players (a real second shooter), the owner's clearer view.

- **16c Lattice.** Wired: `Agents.Lattice.HackMult = 0.75` on the hold kinds in `HackKinds` (Intel, Camera, FuseBox,
  CameraTerminal, Lockpick) through `InteractService.setSecondsMult`. Sparrow Drone (40 s): `Services/DroneService`. The server
  makes a `Drone` part (workspace.Shields, no owner marking) 3 studs above her head and tells her (`SparrowState`
  `{Active, EndsAt}`); `DroneController` finds the part beside her body, views from it (Scriptable camera, mouse look, WASD,
  Jump up, Crouch down) and sends `RequestSparrowMove` (direction, 15 Hz); the server flies it at 24 studs/s, stops it at
  walls, within 120 studs of her body, hovers if the client goes quiet. She cannot walk or fire meanwhile. Ends after 15 s, when
  the drone is shot down (40 HP, via `Combat/Shields.adopt`), when her body takes damage (`CombatService.setDamageListener`),
  when she is downed, or at match end. Hacks: `IntelService` and `CameraService` measure reach from the drone while it is up
  (and skip the clearance check and the witness suspicion for Intel); `IntelController`/`SecurityInteractController` target
  from it (`DroneController.part()`). Tagging: every 0.5 s each enemy in True Form within 80 studs and in sight of the drone gets
  a `TargetGlow` for her team for 8 s.
  Tested solo in Studio: take-off, camera, flight (13.6 studs in 1 s), an Intel hold from the drone 55 studs from her body (8.25 s,
  i.e. 0.75 of the station time), the drone shot down ends the flight and returns the camera.
  Not tested: tagging (needs a second player in True Form), the body-damage ending, two players, the cover/identity side.

- **16d Reticle.** Still Water: `Agents.Reticle.QuietScope` (CoverService skips the WeaponDrawn suspicion for her; firing still
  exposes) and `FallDamageMult = 0.5` (CombatService). Both read the agent's numbers through `setAgentRules` (CombatService,
  CoverService), fed by `AbilityService.rulesOf`; this replaced 16b's `setExtraPlates`. Tracer Glass (30 s): `Abilities/Reticle`
  runs for 6 s; every 0.25 s, while she is scoped (`CombatService.isAiming`), each enemy agent who is Exposed or over half the
  suspicion meter (`CoverService.suspicionOf`) inside a 45 degree cone of her body's facing, within 150 studs, gets a
  `TargetGlow` sent to her only (0.6 s, refreshed), seen through walls.
  Tested solo in Studio: she gets the ability and rules, a 60-stud drop cost 28.5 (full damage would be about 57), Q starts the
  30 s cooldown with no error while scoped. Not tested: the glow itself and the suspicion effect (both need a second player).

- **16e Suture.** Mend Field (45 s): `Abilities/Suture` sets a `FirstAidKit` model (white box, red cross, no owner marking,
  workspace.FieldKits) 4 studs ahead on the floor; for 8 s each 0.25 s it heals his team and himself within 10 studs by 12 HP/s
  (`CombatService.heal`, health only, never a downed player); a Tier 1+ zone breaks his Cover (`CoverService.expose`).
  Triage: `Ability.start` (new optional field, called by `AbilityService` at boot with the agent lookup) runs a 4 Hz loop; teammates
  other than him within 12 studs regain 2 HP/s once `CombatService.secondsSinceDamaged` is 6 s or more. Revives take half the time:
  `InteractService.setSecondsMult` now also gets the interaction's label and `Agents.Suture.ReviveMult = 0.5` applies to "Revive".
  Tested solo in Studio: the kit appears and goes after 8 s; healing from 4.6 to 55.6 HP in 4.5 s (12 HP/s); the ability and
  rules load. Not tested: Triage, the 2 s revive and the Cover break (need a teammate or a Tier 1+ position).

## Not built
- Mend Field is set down, not thrown (no canister arc), and shows no heal ring or sound.
- The Tracer Glass highlight is the shared flare colour (WeaponEffects, Codex's file): a own colour needs a client change there.
- Wired's "tier doors cost 1 less intel": tier doors cost intel in Step 18, so it lands there (read `Agents.Lattice`).
- Drone hacking of doors (keycard Lockpick and Step 18's tier doors) and of vault terminals; gamepad flight.
- Plated's "plates on twice as fast": no plate-applying action exists yet (it comes with the economy/pickups), so there is
  nothing to speed up. When it is built, read `Agents.Parapet`.
- Guards' and bots' shots (`CombatService.botFire`) ignore the shield; so do melee and explosions.
- Ability cooldown HUD and the second disguise slot in the HUD (`DisguiseController` shows slot 1 only): ticket 16-hud for Codex.
- The other five agents (16b to 16f).

## SPEC-QUESTIONs
- Guise's "stored disguise" with two slots: Quick Change uses the first stored look that is not worn.
- G with two slots cycles slot 1, slot 2, insertion outfit (the spec's tap/hold is not used).
- Quick Change is also refused for an Exposed player with an Exposed minimum running (after killing a civilian).
