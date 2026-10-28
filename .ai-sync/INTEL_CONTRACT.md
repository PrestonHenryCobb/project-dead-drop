# Intel contract (Step 11, ticket 11a; Claude Code, 2026-10-27)

Server `src/server/Services/IntelService.luau`, client `src/client/Controllers/IntelController.luau`. **Untested in Studio.**

- Stations are the map's `IntelSpawn` parts. At boot the server sets attribute `IntelId` ("I1", "I2", ...) on each (a fixed
  order by height, then X, then Z). Every station is live; each can be taken once per team (SPEC_CHANGES: 36 stations;
  `Intel.ActiveSpawns` from spec 9.2 is unused).
- Hold E ( `RequestInteract("Intel", id)` through InteractService, label "Hack" ) for the station's `HackSeconds` (4/7/11/16 by
  type). A broken hold keeps its progress for `Intel.TerminalProgressKeepSeconds` (20 s) for that team. Needs: in a match
  (not Insertion), alive, within `Intel.InteractStuds` (5), line of sight, disguise clearance >= the room's tier. The hold is
  Suspicious if witnessed (`CoverService.noteHacking`, rate `Cover.SuspicionGain.Terminal`).
- Points: tablet 2, laptop 4, server rack 6, wall safe 10 to the team's balance. Balance is the currency and the unlock
  progress: the match-wide total is the sum of balances; `IntelService.spend(teamId, n)` lowers it (Step 18 doors, healing,
  ammo). When total >= `min(35, 5 + 5 * teams)` during Infiltration the server calls `MatchService.advance("VaultBreach")`.
- Remotes (both already in Remotes): `IntelUpdate(Types.IntelUpdateInfo {Balance, Used})` to the team only, on change and at
  each Insertion; `GlobalIntelUpdate(Types.GlobalIntelInfo {Current, Threshold})` to everyone.
- Client: faint gold `Highlight` glint on untaken stations within 25 studs and in sight (max 6), contextual E binding.
  `IntelController.balance()` and `.global()` are for the HUD.

## For Codex (ticket 11b)
HUD only: team Intel balance, the match-wide total with its threshold during Infiltration (a bar or count), and a checkmark
or grey state for stations the team took (the glint already stops). The "Hack" hold progress comes through the existing
`InteractState` remote like Revive and Execute. No server change is needed.

## Not built (named gaps)
- Briefcases, the Executive's phone and pickpocketing (spec 9.2) and the Funds rewards of spec 9.3 (Funds were removed). The
  team thresholds that still matter are read from the balance by later steps: 2 intel vault arrow (Step 12), 3 hack bonus
  (Step 12, `Vault.BonusMult`), 4 Package carrier reveal (Step 13).
- A team's Intel dropping as loot when it is eliminated (SPEC_CHANGES 14).
- Stations do not break a door's cost down yet (Step 18 spends through `IntelService.spend`).

## Studio test
1. Play, Deploy, wait for Infiltration. Walk up to a tablet or laptop in a public room: it glints gold at 25 studs.
2. Look at it within 5 studs, hold E: Output prints `[Intel] team 1 took I<n> (+2)`; the glint disappears; release early and
   hold again within 20 s to see the remaining time shorten.
3. Take enough stations (Duos alone: threshold 10): `[Match] VaultBreach` prints.
