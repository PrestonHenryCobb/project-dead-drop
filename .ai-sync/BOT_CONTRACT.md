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

## Not built (named gaps, SPEC-QUESTIONs)
- Bots do not shoot, take the Package, extract or win; they cannot be revived or be a human's teammate. Bots that hack a terminal
  stay in their disguise (a human on a dais is Exposed). A human who disconnects is not replaced by a bot.
- A new player joining mid-match does not take a bot's place (BUILD_ORDER 13B).
- Bot teams are not on the Results scoreboard.
- Reactions (gunfire panic) interrupt a bot; it is sent again after `ResendSeconds`.

## Studio test
Play, claim an agent, Deploy, wait for Infiltration: Output shows `[Bots] 6 bot(s) in 3 team(s), Casual` and `[Intel] team 10x took ...`.
