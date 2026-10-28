# Match loop contract (Step 10, ticket 10a; server by Claude Code, 2026-10-27)

Built from spec 2 and 3.1. **Untested in Studio** (no place was open). The server is `src/server/Services/MatchService.luau`;
`LobbyService` hands teams to it.

## Phases
`Lobby -> Insertion -> Infiltration -> VaultBreach -> PackageHeist -> (Overtime) -> Results -> Lobby`

Only `MatchService` changes the phase. Steps 11 to 13 call `MatchService.advance("VaultBreach" | "PackageHeist" | "Overtime")`
and `MatchService.finish(winnerTeamId?)` (nil = Mission Failed).

| Phase | Ends by | Notes |
|---|---|---|
| Lobby | `startInsertion` when nobody is still in agent select and (MinPlayers ready, or the fill countdown ran out with `Match.MinTeamsToStart` teams) | `Debug.FastMatchStart = true` starts at once with one ready team (Studio) |
| Insertion | `Match.InsertionSeconds` (8) | players are spawned, **frozen** (walk speed 0, no jump, no shots or melee) |
| Infiltration | `Match.ForcedVaultUnlockElapsed` (6:00) or Step 11 | main timer `Match.MainTimerSeconds` (14:00) starts at the beginning of this phase |
| VaultBreach, PackageHeist, Overtime | Steps 12 and 13 | |
| Results | `Match.ResultsSeconds` (15) | then characters are destroyed and the phase returns to Lobby |

The main timer ending is Mission Failed until Step 13 adds the "Package held, so Overtime" check (SPEC-QUESTION in the code).
Everyone out (eliminated or gone) also ends the match as Mission Failed, unless `Debug.AutoRespawn` is on (Studio respawn).

## Remote: `PhaseChanged(phase: Types.Phase, data: Types.PhaseData)`  (server -> client, already in Remotes)
- Fired to **all** clients on every transition; to a team's members only when they finish agent select and the wait changes
  (`phase = "Lobby"`, `data.ReadyPlayers`, `data.EndsAt` = fill countdown end).
- All times are `workspace:GetServerTimeNow()`. `data.Banner` is the 3 s centred phase banner (`Match.BannerSeconds`).
- `Insertion` carries `data.Brief` (`Mode`, `TeamId`, `Teams`, `Players`): each player gets their own team id. Team colour is
  `GameConfig.Lobby.TeamColors[TeamId]`, shown only to that team.
- `Results` carries `data.Results` (`WinnerTeamId?`, `Reason`, `Teams` with `Members { UserId, DisplayName, AgentId?, Out }`).
  Teams are revealed only here.
- `TimerSync` is unused: clients count down to the server-clock fields.

## Client already done (Claude Code)
- `MovementController`: no walking or jumping while the phase is `Insertion`.
- `MenuController`: reopens the lobby menu on `PhaseChanged "Lobby"` when the player has no character.
- A request to queue while a match runs is refused with a `Notification` ("A match is in progress.").

## Client handoff for Codex (tickets 10b and 10c in TASK_QUEUE.md)
1. **MatchController** (`src/client/Controllers/`): consume `PhaseChanged`.
   - Phase banner: large centred text for `Match.BannerSeconds`.
   - Insertion: black screen fading out over the phase, mission briefing card from `data.Brief` (mode, own team colour, teams and
     players, the objective in one line: Intel, Vault, Package, extract).
   - Main timer HUD during Infiltration to Overtime (counts down to `MainEndsAt`).
   - Results screen: winner or "MISSION FAILED", scoreboard from `data.Results`, countdown to `EndsAt`.
   - Lobby wait: in the menu after agent select, "waiting for players" with `ReadyPlayers` and the fill countdown.
2. **Teammate markers** (client only): from `TeamRoster` (`TeamId`, `Members`), a coloured diamond above each living teammate
   through walls plus a coloured outline, using `Lobby.TeamColors[TeamId]`. Nothing on any character; enemies see nothing.

## Known gaps
- The world is not reset between matches (NPCs, doors, vault state carry over); a fresh server per match is Step 22.
- A player who joins mid-match waits for the next lobby (bots and takeover are Step 13B).
- Party placement on one team (spec 3.1) needs matchmaking (Step 22); teams still fill in join order (`TeamService`).
- Scoreboard has teams and who was eliminated only; kills and objective stats have no counters yet.

## Studio test (solo, then 2 players)
1. Play, press Deploy: the 30 s agent select runs, then (FastMatchStart) Insertion starts: you spawn and cannot move or shoot for 8 s.
2. Output shows `[Match] Insertion`, `Infiltration`. After 8 s you can move. `[Match] VaultBreach` appears at 6:00.
3. To see Results quickly lower `Match.MainTimerSeconds` in Studio's copy of `GameConfig`: at expiry `[Match] Results`, 15 s later
   your character is removed, `[Match] Lobby`, and the menu opens again; Deploy works for a second match.
4. Set `Debug.AutoRespawn = false` and die: with everyone out the match ends at once (Results).
