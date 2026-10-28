# Vault contract (Step 12, ticket 12a; Claude Code, 2026-10-27)

Server `src/server/Services/VaultService.luau`. **Untested in Studio.** Follows the owner-approved re-layout
(`docs/MAP_BRIEF_RELAYOUT.md`, SPEC_CHANGES 2026-10-25): the Intel threshold no longer unlocks anything. I removed that
trigger and the match-wide Intel counter from ticket 11a (`GlobalIntelUpdate` is no longer sent; `Intel.Unlock` is gone).

## Rules built
- At Insertion, 3 of the 5 vaults (`Vault.ActiveVaults`) are chosen at random; each gets a `VaultTerminal` prop on its dais
  (the `VaultTerminalSpot` part) in `workspace.VaultTerminals`. The other two daises stay empty. Cleared when the lobby returns.
- Standing on the dais (its radius, within `Vault.TerminalHeightStuds` vertically) hacks it: `Vault.BaseRate` % a second when
  one team is there regardless of head count, x`Vault.BonusMult` if that team's Intel balance is >= `Intel.Thresholds.HackBonusAt`
  (3), paused (`Contested`) while two or more teams are on it, never decays. Anyone on the dais is Exposed at once (spec 7.2 #8).
- Phase 3 (`VaultBreach`) begins at the earlier of the 6:00 forced unlock and the first progress on any terminal. When all
  active terminals are hacked, `ElevatorService.setLocked("E5", false)` and `MatchService.advance("PackageHeist")`.

## Remote: `VaultProgress(Types.VaultProgressInfo)` (server -> all clients, already in Remotes)
`{ Terminals = { {VaultId, Position, Progress 0..1, Contested, Hacked} } }`. Sent only from the Vault Breach on (the active
vaults are secret before that): once at the phase change, then at most every `Vault.BroadcastSeconds` while it changes.

## For Codex (ticket 12b)
HUD: top-centre bars for the active terminals during VaultBreach (percent, "CONTESTED"), a world/compass marker at each
terminal `Position` until hacked, and the Vault Breach banner (already in `PhaseChanged`). No server change needed.

## SPEC-QUESTIONs
1. Phase 2 to 3 rule after Intel stopped being the unlock (first hack or 6:00, whichever first).
2. 1.25 %/s per terminal (80 s each) is the old single-bar rate.
3. The gold Asset a terminal awards its hackers waits for the Assets system (Steps 18 and 21).

## Not built
Package spawn, the Sanctum's doors and the Package itself (Step 13); extra Security NPCs on opening (`Vault.ExtraSecurityOnOpen`,
Step 15); other teams' Intel-gated Package door (DoorService, Step 18).

## Studio test (solo)
1. Play, Deploy; Output shows `[Vault] active vaults: ...` at Insertion.
2. Walk to an active vault's dais (the glowing terminal): you are Exposed at once; Output shows `[Match] VaultBreach` and
   progress rises 1.25 %/s; leave and it pauses.
3. Hack all three (about 80 s each): `[Vault] terminal ... hacked` x3, then `[Match] PackageHeist`.
