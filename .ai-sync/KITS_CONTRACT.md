# Talents and Instincts: the 24 new kit items (ticket kits-24; Claude Code, 2026-11-20)

**Built, not run in Studio.** Owner answer 2026-11-20: "you come up with all the new abilities". Every agent now has **3 Talents (abilities, key Q) and 3 Instincts
(passives)** in `Defs/AgentDefs` (each item has an `Id`). A player selects one of each in agent select; mastery unlocks them (`GameConfig.Mastery.TalentUnlockLevels` and
`InstinctUnlockLevels`, {1, 3, 6} like Hardware: the second after about two matches, all three after about nine). **All numbers are first guesses (SPEC-QUESTION).**

## Selecting
`PlayerLoadout` and `LoadoutRequest` gained `TalentId?` and `InstinctId?`. `MetaProgressionService.validateLoadout` refuses an id that is not the agent's own
(`TalentUnavailable`, `InstinctUnavailable`) or not yet unlocked (`MasteryTooLow`); a missing id takes the agent's first (always unlocked). Saved loadouts without them
load as the first of each. **Codex:** add a Talent and an Instinct picker beside the Hardware picker in agent select (`PreDeployView` shows only the first of each now),
greying out locked ones like Hardware, and send the ids in `RequestLockInPreDeploy` / `RequestEquipLoadout`. The ability HUD already follows `CooldownUpdate.Name`.

## The items
| Agent | Talents (Q) | Instincts |
|---|---|---|
| Guise | Quick Change (30 s, first) / **Face Value** (40 s): 8 s of witnesses filling suspicion at 40 percent / **Cold Read** (30 s): 8 s of scans taking 40 percent of the time and reaching 60 percent further | Two Faces (first) / **Deep Cover**: combat lockout 40 percent shorter / **Social Climber**: sprint and jump suspicion 35 percent lower |
| Parapet | Riot Wall (35 s, first) / **Brace** (30 s): 5 s of half damage taken / **Plate Slam** (40 s): one armour plate at once | Plated (first) / **Thick Skin**: hits hurt 10 percent less / **Anchor**: stagger, shove and slows last half as long |
| Lattice | Sparrow Drone (40 s, first) / **Overclock** (35 s): 10 s of hack holds taking 60 percent of the time / **Signal Jam** (40 s): cameras within 45 studs dark for 8 s | Wired (first) / **Data Miner**: each Intel station she finishes pays 1 more intel / **Low Profile**: hacking raises suspicion half as fast |
| Reticle | Tracer Glass (30 s, first) / **Focus** (30 s): 8 s of 20 percent more damage dealt / **Marked Man** (35 s): the nearest Exposed enemy in sight within 100 studs glows to her, through walls, 6 s | Still Water (first) / **Patient Hunter**: 10 percent more damage to an Exposed agent / **Cold Blood**: suspicion drains 50 percent faster |
| Suture | Mend Field (45 s, first) / **Adrenaline** (35 s): heal 40 HP now and clear any slow / **Screen** (40 s): a smoke cloud (radius 5, 6 s) ahead of him | Triage (first) / **Second Wind**: bleeds out 30 percent slower when downed / **Self-Care**: regains 1.5 HP/s after 6 s out of combat |
| Feint | Double (30 s, first) / **Lure** (30 s): a noise 25 studs ahead, guards investigate, the crowd looks / **Twin Double** (45 s): two Doubles at 25 degrees either side | Smoke and Mirrors (first) / **Cheap Tricks**: every Talent cools 20 percent faster / **Ghost Trail**: the Exposed ping lasts half as long |

## How it works (server)
- `AbilityService`: `abilities` is keyed by Talent id; `talentOf` follows the loadout's `TalentId`; `rulesOf(player)` is now `GameConfig.Instincts[selected Instinct]` (the old
  per-agent rule keys moved there; `GameConfig.Agents` keeps the Talents' own numbers; the 12 new Talents' numbers are `GameConfig.Talents`). `AbilityService.instinctOf`.
  Cooldowns use `CooldownMult` (Cheap Tricks). `Ability.start` now gets `(agentOf, instinctOf)`: Triage's loop runs only for a Suture who selected Triage. Self-Care is a loop in `AbilityService`.
- `Combat/Effects` (timed buffs: DamageDealt, DamageTaken, SuspicionGain, ScanTime, ScanRange, HackTime) and `Combat/KitRules` (the selected Instinct's rules for services that cannot require
  AbilityService). Hooks: `CombatService` (DamageTakenMult, DamageDealt, ExposedDamageBonus), `CoverService` (SuspicionMult, SuspicionGain, SuspicionDecayMult, CombatLockoutMult,
  ExposedPingMult), `DisguiseService` (ScanTime, ScanRange, StatusMult), `IntelService` (IntelBonus), `DownedService` (BleedOutMult). Effects clear when a match starts or the player leaves.
- Identity: nothing is put on a character. `Marked Man` names the body by its model name and only marks an Exposed agent; Screen and Lure use the existing smoke and noise paths.

## Not built / SPEC-QUESTIONs
- The picker UI (above). The Cold Read, Face Value, Brace, Focus and Overclock buffs have no HUD timer yet (the Q cooldown shows). `Anchor` shortens slows applied through
  `DisguiseService.applySlow` (pump stagger, taser) but not a shove's distance.
- The Twin Doubles and Screen smoke are not marked to show who made them, by design.
- Every number is a guess; Brace plus Thick Skin stack (about 0.45 damage). Cheap Tricks also shortens Marked Man and Signal Jam. Plate Slam refuses when plates are full.
