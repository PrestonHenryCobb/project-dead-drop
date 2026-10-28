# Bots (Step 13B-a; Claude Code, 2026-10-28)

Owner chose "crowd-NPC bots". `BotService`, `Bots/BotRegistry`, hooks in `NPCService`, `IntelService`, `VaultService`, `MatchService`.
**Tested in Studio (solo, 2026-10-28):** 6 bots in 3 teams appear at Insertion; they take Intel stations (`[Intel] team 102 took ...`); after
a Vault Breach they reach terminals and contest them (`C` on the bars).

- A bot is a random crowd NPC (never the Warden/Curator). Nothing marks it; clients see an ordinary NPC. `Bots.TargetTeams` (4)
  minus the human teams is how many bot teams fill the match (max players 12 never exceeded). Bot team ids start at 101.
- Infiltration: walks to the nearest untaken station, works it (hack seconds x `HackMult`), `IntelGoal` stations each.
  Vault Breach: after `TerminalDelaySeconds` walks to the nearest unhacked terminal and stands on it (a vault core has no
  graph nodes, so the last <= 60 studs is a placement; `NPCService.warpBot`). `VaultService` counts a bot on a dais for its team
  (contests humans, x1.25 with 3 Intel). Package Heist onward: released back to the crowd at its node.
- Profiles `Casual` (default) and `Competitive` in `GameConfig.Bots`.
- The briefing's team and player counts include bots (`MatchService.setBotSpawner`).

## Step 13B-b: bots fight and extract (2026-10-28)
**Tested in Studio:** with the human parked, three bot teams ran a whole match alone: Intel, hacked all three terminals, took the
Package, called extraction, stood in the zone and won (`[Match] ended, winner team: 101`). A Competitive bot killed an Exposed
player in sight within seconds.
- Package: `PackageService` can be carried by a bot (`botPickup`, `carrierTeam`, `carrierBot`); it drops where the bot goes down and
  pings rivals like a human carrier. The Package room's front door costs 10 Intel: a stopped bot team pays
  `Doors.HackCost.PackageDoor` (IntelService.spend) and the bot is placed inside; a team that cannot pay goes back to taking Intel.
- Extraction: `ExtractionService.botCall`, `botExtract`, `sites`, `state`; the carrier walks to the nearest pad (placed on it if the graph
  stops short), calls, waits for the green zone, stands the channel time with no rival in it, wins. A bot win ends the match for humans.
- Combat: `CombatService.botFire`. A bot shoots an **Exposed** human in sight within its profile's range (Shot: damage, interval, hit
  chance); Covered humans are left alone. The shot is heard (ShotHeard, NPC panic). Competitive bots also hunt a rival carrier.
- Bots stay active through Package Heist and Overtime and return to the crowd at Results.
- Fixes found while testing: a bot sent again mid-walk starts from the node nearest to it (not the node it was heading for); a bot that
  finished its Intel goal scouts the terminals during Infiltration, so a match of bots alone does not stall until the 6:00 unlock.

## Not built (named gaps, SPEC-QUESTIONs)
- Bots cannot be revived, be a human's teammate or use gadgets; they do not pass the Package or defend a carrier (Competitive ones hunt).
- A human who disconnects is not replaced by a bot; a new player joining mid-match does not take a bot's place (BUILD_ORDER 13B).
- Bot teams are not on the Results scoreboard. Bots stay in their NPC look (never Exposed) even while shooting.
- Placement (warp) onto vault daises, the Package room and extraction pads is a visible jump for anyone watching; rooms with no graph
  nodes would need proper routing.
- Casual (default) and Competitive numbers are first guesses from short runs.
