# Matchmaking (ticket matchmaking, Step 22, spec 25.7; Claude Code, 2026-11-20)

**Built, not run, and cannot be run without publishing.** Dormant until the owner publishes two places and sets `GameConfig.Matchmaking` (`Enabled = true`,
`LobbyPlaceId`, `MatchPlaceId`). With it off (and always in Studio) the game is one server that is lobby and match, exactly as before (`Util/PlaceRole`).

## Flow
- **Lobby place** (`PlaceRole` "Lobby"): `RequestFindMatch(mode) -> (ok, reason?)` ("Solos" or "Duos"; refused with `NotAvailable`, `UnknownMode`, `AlreadySearching`,
  `NoAgent`, `QueueUnavailable`) adds the player's UserId to the mode's MemoryStore queue. `RequestCancelFindMatch() -> (ok, reason?)` leaves. The server tells the owner
  `MatchmakingState { State = "Searching" | "Found" | "Failed" | "Idle", Mode?, Reason? }`. A search ends with `Failed "NoMatchFound"` after `QueueExpirySeconds` (180).
  Every lobby server, every 3 s, reads `Modes[mode].MinPlayers` entries all-or-nothing (atomic across servers), tops up to `MaxPlayers`, reserves a match server and publishes
  `{ Mode, Code, UserIds }` on MessagingService; each lobby server teleports the searching players it holds from that list with `TeleportAsync` and the reserved code,
  teleport data `{ Mode, Matched = true }`. Play (`RequestStartPreDeploy`) on a lobby place answers "Use Find Match to queue."
- **Match place** ("Match"): `TeamService` takes the mode from the first arrival's teleport data (before any team exists); an arrival with `Matched` starts agent select
  at once (`LobbyService.begin`, same as pressing Play) once their profile is loaded. Empty slots are filled by the bots (13B).

## For Codex (client)
When matchmaking is enabled (the lobby place), the Play screen's button should call `RequestFindMatch(mode)` instead of `RequestStartPreDeploy`, show "Searching..." with
a Cancel (`RequestCancelFindMatch`) from `MatchmakingState`, and show `Failed` honestly. Detect the lobby role from `GameConfig.Matchmaking.Enabled` and
`game.PlaceId == GameConfig.Matchmaking.LobbyPlaceId`. Nothing else changes.

## Owner steps
Publish the same project to two places, set the three config values, turn on API access and teleports in game settings, and test with two accounts.

## Gaps and SPEC-QUESTIONs
- No party grouping (friends are not kept together; Duos pair by join order on the match server). Squads cannot be queued.
- The lobby place is a copy of the same project (it also builds the map and crowd); it never starts a match because nobody can press Play there. A lighter lobby is later work.
- A player who cancels after their entry is read is simply not teleported; the match forms with fewer humans and the bots fill. Players dropped by a failed `ReserveServer`
  must search again. A reconnect after the match returns to the lobby place via the client (not built).
- `MemoryStore` and `MessagingService` limits and costs are not measured. Player-count rules (4 to 12) come from `GameConfig.Modes`.
