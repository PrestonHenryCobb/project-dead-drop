# Step 8 end report: weapons and hit registration (2026-11-20)

Written to the `CLAUDE.md` format (ticket 8.7). Step 8 grew past its first prompt: all 18 Hardware weapons, their unique effects, the
Feel pass (8B) and the status effects exist now. Almost all of it has run in Studio solo against NPCs; **nothing involving a second human has
been run** (ticket 8.4). Detail lives in `.ai-sync/WEAPON_SERVER_CONTRACTS.md` (server rules and the 2026-11-03 Studio results),
`docs/STEP8_QUESTIONS.md` (decisions and numbers) and `docs/STEP8_HANDOFF.md` (the first pause).

## 1. What I built

Server (Claude Code)
- `Services/CombatService`: all combat state (HP, plates, ammo, reload, drawn weapon), `FireRequest` validation (origin, rate, magazine, state),
  lag-compensated hits, damage with headshots and falloff, melee, held takedowns, fall damage by height, downed/elimination hooks,
  per-weapon effects (pellets, bursts, spin-up, aimed rate, pierce, ambush shot, scope glint, displaced sound, stagger, shove, taser, tracker).
- `Combat/Hitbox`, `Combat/History` (20 Hz pose ring buffer, rewind up to 250 ms, matches the 12 Hz stepped poses of Step 8B), `Combat/FireRate`,
  `Combat/Ballistics`, `Combat/Lockout`, `Combat/Shields`.
- `Services/ProjectileService`: Suture's flare and Feint's knives (arcing flights, landed knives, validated pickup, cleared at Lobby/Insertion).
- Smoke SMG's last-five-round clouds block sight checks (`Combat/Smoke`); the NPC crowd is slowed by a pump stagger or taser and shoved by the hammer.
- Lattice burst rifle tracker (a full burst on one agent sends `TargetGlow` with `ThroughWalls` to the shooter alone) and taser (30 damage,
  25 studs, 60 percent slow for 1.5 s, 3 s ability and gadget lockout, `CombatStatus` "Taser").

Shared: `WeaponDefs` (18 Hardware definitions, owner numbers from `STEP8_QUESTIONS`), `Types.WeaponDef` and friends, the combat remotes, `GameConfig.Combat`.

Client (Codex, for reference): `WeaponController` with prediction that follows `FireRate`, `ViewModel` with full-body first person, `CombatHudController`,
`ShotFxController`, tracers and muzzle flash, `WeaponEffectsController` (flare, smoke, tracker glow), `TaserStatusController`, per-weapon handling and recovery.

## 2. How to test it in Studio

Solo, one player (`Debug.TestMode = "Duos"` or `"Solos"`, fresh Play):
1. Deploy, take any agent, press F8 to cycle agents and `]` to cycle weapons (Studio only). Fire at an NPC: grey hitmarker, red on an agent, bigger on a head.
   Expect 1.2 s to down an agent with one plate; reload with R; an empty click when the magazine is dry.
2. V taps a melee swing; hold V from behind an NPC within 6 studs for a takedown (garrote 0.8 s, others 1.2 s); moving 4 studs away or being hurt breaks it.
3. Jump from a 40-stud roof: fall damage by height. A zipline, the gondola and a vent must not hurt.
4. Weapon by weapon, use the steps at the end of `.ai-sync/WEAPON_SERVER_CONTRACTS.md` (garrote, pump, hammer, flare, smoke SMG, knives) and the Lattice burst rifle
   (three hits on one agent, see a 3 s outline through a wall) and taser (25-stud range, slow, abilities refused for 3 s).
5. `docs/TWO_PLAYER_TEST.md` lists everything that needs a second human (rows for stagger, shove, glow reaching only a team, knife pickup, takedown breaking when hurt).

## 3. Known gaps and risks
- Not run with a second human: the pump's 1 HP floor and stagger on a player, the hammer shove of a player, the taser and its slow/lockout on a player, tracker and flare
  glow recipients, knife pickup, takedown breaking when the attacker is hurt, cover exposure on firing, stepped poses of other players, `HitConfirm`/`DamageTaken` markers.
- Hit registration at real latency has not been measured; rewind windows are 0.15 s (NPCs) and 0.1 s (players) plus the step moment.
- The SMG Blender model (ticket 8.6) is not made; weapon models are part-built or Codex's shaped models.
- Aim assist for gamepads is deferred (Step 19). Weapon sounds are Roblox library ids, not authored audio (Step 20).

## 4. SPEC-QUESTIONs raised
- Burst rifle rate inside a burst (`RPM = 900`) is not specified.
- Taser has no head bonus (`HeadshotMult = 1`); the owner made the dart quiet.
- The hammer's "sideways in the direction of the swing" is the swinger's right.
- The ambush shot needs Covered (the answers' wording); it also worked while Suspicious before.
- The knife prompt shows to every agent near a landed knife, including ones who cannot use it.
- Flight values (knife, flare), pickup reach and most handling numbers are Studio tuning.

## 5. Ready for
Step 9 is built (`9a` teams, `9b` downed/revive/execute, `9c` spectating) and the match loop (Steps 10 to 13) follows it. The next real work is the **two-player test session**
(ticket 8.4 and `docs/TWO_PLAYER_TEST.md`), then Step 19 polish, Step 20 audio, Step 21 the shop and Step 22 matchmaking.
