# Account XP, levels and Credits (ticket 21-rewards; Claude Code, 2026-11-20)

**Built, not run in Studio.** Spec 20.1 to 20.3, with the numbers in `GameConfig.Rewards`. `Services/RewardService` collects XP events during a
match; `MatchService.finish` hands it who won and who was still up; `MetaProgressionService.settleAccount` applies it to the profile.
(Agent mastery is separate: `recordMatch`, one level a match; see DATA_CONTRACT.md.)

## XP events (spec 20.1)
| Event | XP | Where it comes from |
|---|---|---|
| MatchPlayed | 100 | every human in the match, at the end |
| IntelCollected | 25 | the player who finishes a station's hold (`IntelService`) |
| VaultParticipation | 50 | once a match, after 10 s on a terminal's dais (`VaultService`) |
| PackagePickedUp | 50 | once a match, the first time the player takes it (`PackageService.grant`) |
| PackageCarried | 10 | every 10 s holding it (`PackageService.check`) |
| EnemyDowned | 30 | the shooter whose hit downs an agent of another team (`CombatService.applyDamage`) |
| EnemyEliminated | 20 | the shooter whose hit eliminates one, or the player who executes a downed one (`DownedService`) |
| TeammateRevived | 30 | the reviver (`DownedService`) |
| TeammateRescued | 50 | the player who spends a carried Agent Tag on Rescue (`RescueService.rescue`) |
| ExtractionWin | 500 | every member of the winning team |
| SurvivedToEnd | 50 | a player still up at the end (OPEN_QUESTIONS: not a downed or eliminated one) |

## Levels and Credits (spec 20.2, 20.3)
XP to the next level is `500 + 100 x level`, at most 3000. Each level gained pays 250 Credits. A win pays 200 Credits, and the first win of each
UTC day 300 more. All saved in the profile (`Level`, `XP`, `LastWinDay`, `Credits`; DATA_CONTRACT.md).

## What the client gets
- `MatchRewards` (new server to client remote, one player only) after the match: `Types.MatchRewardsInfo { Lines { Event, Xp }, TotalXp,
  LevelBefore, LevelAfter, XpIntoLevel, XpForLevel, LevelCredits, WinCredits, DailyCredits }`.
- `ProfileStateUpdated` carries the new `Level`, `XP` and `Credits` as before (`XP` and `LastWinDay` are new fields on `MetaProfile`).

## For Codex (client)
Show the breakdown on the Results screen from `MatchRewards` (the XP lines in order, the total, the level bar from `XpIntoLevel / XpForLevel`,
a level-up note, and the Credits from levels, the win and the first win of the day), and show `Level` with an XP bar in the Profile header from
`MetaProfile.Level` and `.XP`. The event names are the keys of `GameConfig.Rewards.Xp`; give each a readable label. `MatchRewards` can
arrive before or after the results phase message, so keep the last one until the lobby opens.

## Gaps and SPEC-QUESTIONs
- Intel XP counts for the player who completes a hold (a team can take each station once). Package pickup and vault participation XP are paid
  once a match to stop farming. A Solos elimination is paid as EnemyEliminated only (there is no downed step).
- The +XP boost game pass (spec 18, META_DRAFT) is not built. Daily and weekly contracts (brief Q9) have no design.
- NPC kills pay nothing. Bots have no profile, so they earn nothing and are never paid.
- Credits are earned but there is nothing to spend them on yet (locked agents, Black Market and Dossiers have no catalogue).
