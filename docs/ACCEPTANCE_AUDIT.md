# Acceptance audit (spec 28, first pass), 2026-11-20

Where the project stands against the milestones and the final checklist of spec section 28. Written by Claude Code from the repository
and the earlier Studio notes. **Nothing in the 2026-11-19 and 2026-11-20 autonomous runs was run in Studio**; "tested earlier" means a
past session ran it solo in Studio (see the contracts in `.ai-sync/`). Status: DONE, BUILT (code exists, never run), PARTIAL, OPEN.

## Final acceptance checklist
| Item | Status | Evidence and what remains |
|---|---|---|
| No way to tell a standing disguised player from an NPC by UI, sound or nametag | PARTIAL | No server or client code puts attributes or tags on a rig; models share random 12-character names; the player list, health bars, nametags and chat bubbles are hidden (CoreGuiController). Leaks found and fixed in the 2026-11-19 audit (`TargetGlow` and ping ids, NPC slow and shove parity). Footstep and ability sounds were not compared. An exploiter can still call `GetPlayerFromCharacter` (accepted by spec 26). Needs a two-player look. |
| Every cover-breaking action in 7.2 exposes at once | DONE (tested earlier) | Steps 6 and 7 (cover tests); newer actions (Disguise Kit, secret exit, tier-door hack) use the same `CoverService` calls (`expose`, `noteHacking`). |
| Suspicion rises only when a Security NPC or camera sees it | DONE (tested earlier) | Witness checks in `CoverService`; smoke now also blocks witness sight. |
| Vault progress pauses when contested and does not stack | DONE (tested with bots) | `VaultService` (VAULT_CONTRACT, BOT_CONTRACT: a bot team contested the bars). |
| Package carrier pings every 10 s and can never disguise | BUILT | `Package.PingInterval` 10; `DisguiseService.blocked` is true for carriers (`setCarrier`). Not run with a human carrier. |
| Only one team can win; no-winner endings work | BUILT | `MatchService.finish` once per match; all-out ends with no winner (`checkAllOut`, which only works since `Debug.AutoRespawn` was turned off on 2026-11-19). Bots won a whole match alone (tested). Human no-winner path not run. |
| All 27 edge cases handled | PARTIAL | `docs/EDGE_CASE_AUDIT.md`: 4 gaps found and fixed, one accepted change (Riot Wall), several not re-checked. |
| Every client request is validated on the server | PARTIAL | `docs/ANTI_EXPLOIT_AUDIT.md`: every handler read; one real bug and three leaks fixed; the movement guard only logs. |
| All numbers come from GameConfig | DONE (scan) | A scan of `src/server` (not the Studio-only generators) found 30 tunable-looking literals: epsilons, hash constants, particle settings and named local constants, and two real tunables (a target-id length cap in `RouteService`, a poll interval in `MetaProgressionService`) that are listed for GameConfig. |

## Milestones
| Milestone | Status | Notes |
|---|---|---|
| 1 Foundation | DONE | Folder layout, Enums, Types, GameConfig, service loader, two-tower map. The "indistinguishable at rest" test needs an owner look. |
| 2 NPCs | DONE (tested earlier) | 200 NPCs, authored routes, panic. The 74-NPC phone target is replaced: mobile is not a target. |
| 3 Disguise and cover | DONE (tested earlier) | Tables 7.2 and 7.3 were run in Steps 6 and 7. |
| 4 Combat | PARTIAL | All 18 Hardware weapons are registered; the server rules of six were run solo on NPCs (WEAPON_SERVER_CONTRACTS). Player-victim effects, downed crawl, bleed-out and revive between two players are untested. |
| 5 Objective loop | DONE (tested with bots) | Bots played a full match to extraction. A human run is the owner's checklist (docs/TWO_PLAYER_TEST.md). |
| 6 Security | DONE (tested solo) | Cameras, lasers, keycard doors, alarm, Camera Room, guard combat (SECURITY and GUARD contracts). Shooting a camera untested. |
| 7 Content | PARTIAL | **Six** agents (not eight; SPEC_CHANGES), 12 gadgets, Assets, Supply Caches, Agent Tag and Rescue are built. The 12 new Talents and 12 Instincts (brief Q8) are not designed, so only the first of each exists. |
| 8 Polish and persistence | PARTIAL | HUD, minimap, settings, pings, spectating, chat rules: BUILT (client in review). Saved profiles and XP, levels and Credits: BUILT, never run. **Open:** audio (Step 20), matchmaking and the lobby place (Step 22), cosmetics and the shop catalogue (Step 21), the tutorial (13C, waits for reference videos), the Robux pass and Mint. |

## What would move this furthest, in order
1. The owner's solo and two-player runs (docs/TWO_PLAYER_TEST.md): everything marked BUILT is untested.
2. Audio (Step 20): needs the owner's asset choices.
3. A shop and unlock catalogue so Credits can be spent (agents, cosmetics): needs design.
4. Matchmaking (Step 22): needs the place structure and publishing.
