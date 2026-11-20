# Edge case audit (Step 24, first pass), 2026-11-19

Spec section 27, case by case. A static read by Claude Code; nothing was run in Studio. Status: **OK** (the code handles it,
with where), **FIXED** (a gap found and closed in this pass), **GAP** (open), **N/A**, **NOT RE-CHECKED** (believed handled by
design, not read this pass).

| # | Case | Status | Where |
|---|---|---|---|
| 1 | Package carrier leaves | OK | `PackageService` PlayerRemoving drops it at `lastCarrierPosition` |
| 2 | Package falls out of the map | OK | `PackageService` returns it when below `Package.MinY` or untouched for `ReturnSeconds` |
| 3 | Two finish pickup together | OK | first completed hold wins, the second finds it taken (`PackageService`) |
| 4 | Disconnect while downed | **FIXED** | `DownedService` PlayerRemoving already re-checked the team wipe; it now also fires `onLeftDowned` so `RescueService` drops the Agent Tag |
| 5 | Rejoin mid-match | **FIXED** (server; client ticket open) | `MatchService` sends anyone who joins while `isInMatch()` to `SpectateService.watchMatch`: they spectate like an eliminated player (teammates first, then anyone, then the drone) and go back to the lobby at the end. They cannot deploy (`canQueue` is Lobby only). The client menu must step aside while spectating: ticket `menu-spectate-latejoin` |
| 6, 7 | Disguised-as NPC dies, or dies before the swap | NOT RE-CHECKED | a scan copies the `OutfitDef`, not the NPC |
| 8 | Lockdown while in a Tier 2 disguise | NOT RE-CHECKED | |
| 9 | Downed agent in a hack zone | OK | `VaultService` skips `DownedService.isOut` |
| 10 | Vault at 100 percent while contested | OK | contested pauses (VAULT_CONTRACT) |
| 11 | Extraction by a carrier of another team | NOT RE-CHECKED | PACKAGE_CONTRACT says the win goes to the carrier's team |
| 12 | Pass to a teammate in a vent | NOT RE-CHECKED | `PackageService.beginPass` picks the nearest living teammate in `PassRange`; vent eligibility was not read |
| 13 | Ability during Insertion | **FIXED** | `AbilityService.onRequestAbility` now refuses in Insertion (gadgets already did) |
| 14 | Enemy takes an Agent Tag | OK | `RescueService.beginPickup` requires `areTeammates` |
| 15, 16 | Last team standing / everyone eliminated | OK | `MatchService.checkAllOut` ends the match only when nobody is left, with no winner |
| 17 | Grenade kills | N/A | no grenades |
| 18 | Zone boundary | OK | `ZoneService.tierAt` takes the highest tier among overlapping volumes |
| 19 | Feint's decoy | NOT RE-CHECKED | `GuardService` ignores decoys; cameras and the alarm were not read |
| 20 | Drone owner's body attacked | OK | `DroneService` ends the flight on damage to her body |
| 21 | Riot Wall and teammates | **ACCEPTED** (owner, 2026-11-19: keep as is) | the wall part has `CanCollide = false`; shots and projectiles stop at it (raycast, `Shields`), but no body is physically blocked, enemies included. The spec wants collision with enemies only |
| 22 | Reload during a swap | OK | ticket 8.2 |
| 23 | Disguise inside a laser grid | **FIXED** | `LaserService.inBeam` feeds `DisguiseService.setSwapBlocker`; the request, Disguise Kit, Quick Change and auto re-cover all refuse inside a live beam. Scanning, sprint and crouch are unaffected |
| 24 | Timer expires during the extraction channel | OK | Overtime covers it (PACKAGE_CONTRACT) |
| 25 | Team with 0 alive keeps Intel | N/A | |
| 26 | Same-team scan | NOT RE-CHECKED | `startScan` resolves a target id; teammate rules were not read |
| 27 | Low-end mobile | N/A | mobile is not a target |

**Debug default changed:** `Debug.AutoRespawn` was `true`, which reloaded an eliminated player after 3 s and stopped `MatchService`
ending the match when everyone was out, so elimination, spectating (case 15, 16) and Mission Failed could not happen in a real match.
It is now `false`. In Studio a player who dies is now eliminated, spectates, and the match ends and returns to the lobby as designed.

**Found by the reviewer afterwards:** nothing watched `Humanoid.Died` on the server, so a death that did not come through combat damage (falling out of the world) never marked the player out. `DownedService` now eliminates on any death of the current character (a death it caused itself is ignored the second time). Smoke clouds are also cleared at Lobby and Insertion.

Also added in the same pass: `RequestDropPackage` duplicate fix and finite-vector validation (docs/ANTI_EXPLOIT_AUDIT.md).

## What the owner should check in Studio
- Cases 4, 13 and 23 once each (leave while downed with a teammate watching; press Q during the briefing; stand in a live beam and
  try to change disguise).
- Owner decisions 2026-11-19: a rejoiner spectates (built); the Riot Wall keeps stopping shots and projectiles only, bodies walk
  through it (case 21 accepted, a change from spec 27 #21).
