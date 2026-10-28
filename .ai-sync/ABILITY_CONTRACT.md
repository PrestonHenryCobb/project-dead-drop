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

## Not built
- Plated's "plates on twice as fast": no plate-applying action exists yet (it comes with the economy/pickups), so there is
  nothing to speed up. When it is built, read `Agents.Parapet`.
- Guards' and bots' shots (`CombatService.botFire`) ignore the shield; so do melee and explosions.
- Ability cooldown HUD and the second disguise slot in the HUD (`DisguiseController` shows slot 1 only): ticket 16-hud for Codex.
- The other five agents (16b to 16f).

## SPEC-QUESTIONs
- Guise's "stored disguise" with two slots: Quick Change uses the first stored look that is not worn.
- G with two slots cycles slot 1, slot 2, insertion outfit (the spec's tap/hold is not used).
- Quick Change is also refused for an Exposed player with an Exposed minimum running (after killing a civilian).
