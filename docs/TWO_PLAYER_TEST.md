# Two-player test session

Everything the solo Studio runs could not check. Tick each line and write down what you saw. Server rules are in the
contracts named in brackets. Controls: F8 cycles the agent, `]` cycles the weapon (Studio only), V melee/takedown,
Q ability, E interact, 1 to 3 gadgets.

## Setup

1. Stop any playtest. In the Rojo plugin press Disconnect, then Connect (accept the script-only diff).
2. **Session A, teammates (Duos):** leave `Debug.TestMode = "Duos"`. Test > Clients and Servers > Clients 2 > Start.
   Clients 1 and 2 are on one team (teams fill in join order).
3. **Session B, opponents (Solos):** stop, then in Studio's copy of `GameConfig` (not on disk) set `TestMode = "Solos"`,
   and start Clients 2 again. Each client is its own team and starts with 2 plates.
4. On each client: open the menu, take the free agent pick, Deploy, lock in an agent and wait out the 30 s select.
   Both clients spawn at Insertion. Say which client is "A" and which is "B".
5. Keep the Output window open on the server and watch for red errors during every step.

## Session A: teammates (Duos)

| # | Do | Expect |
|---|---|---|
| A1 | Down A: let A fall from a high ledge until downed (fall damage is by height). | A is downed and crawls. B sees a generic body prompt, not a team label. Bleed-out is 30 s. |
| A2 | B holds E on A's body for 4 s. | A is revived at 30 HP, both HUDs update, no errors. |
| A3 | Down A again, wait 30 s without reviving. | A is eliminated and the body lies intact then fades. B gets the elimination state. |
| A4 | Both on Suture (F8 until Suture): A uses Q (Mend Field) near B. | B heals about 12 HP/s inside the field. Triage: teammate regen and a 2 s revive (ABILITY_CONTRACT). |
| A5 | Lattice flies the Sparrow drone over a rival or NPC and tags. | Check the tag against ABILITY_CONTRACT (section Lattice): who sees it and for how long. Note anything that differs. |
| A6 | Select Suture's flare (`]`). A fires at an NPC. | **Both** clients see the 4 s glow on the target, only with line of sight. It survives a disguise change. |
| A7 | A is eliminated. B opens a Supply Cache and buys Rescue (10 intel), after picking up A's Agent Tag. | Tag drop, pickup bar, Rescue price and reasons show. A respawns (ECONOMY_CONTRACT 18d). |
| A8 | A and B both stand at a glass elevator stop; A hacks it, B walks in behind. | Tailgating works: B can enter and ride without a hack. Cover is not broken by riding. |
| A9 | A stands in a cab while an NPC calls it. | The cab carries both A and the NPC with no teleporting or falling through the floor. |
| A10 | One teammate scans a Staff NPC, then calls an elevator at a Staff stop. | Doors open without a hack for the Staff-disguised player. |

## Session B: opponents (Solos)

| # | Do | Expect |
|---|---|---|
| B1 | A fires at B with the SMG from 15 studs. | A becomes Exposed on firing. A sees a hitmarker. B gets a damage-direction marker. Being shot does not expose B (ticket 8.4). |
| B2 | B is disguised and Covered. A hits B in the head. | Body damage only, hitmarker shows body (SPEC_CHANGES 2026-10-24). |
| B3 | Parapet pump at 8 studs, all pellets on B at full health, 2 plates or none. | B ends at 1 HP or more, not downed. B is slowed 25 percent for 0.35 s and the view bumps away from A. A second pull within range kills. |
| B4 | Same pump from 20 studs. | No stagger (needs 5 pellets within 12 studs). |
| B5 | Parapet hammer: A taps V on B, then holds V 1 s and releases. | 70 damage, then 100 and B slides about 3 studs to A's right. Beside a wall B does not move into it. Near an open edge B can fall. |
| B6 | A holds V from behind B (B walking, then standing). | B sees the struggle and can break free by moving. Takedown completes in 1.2 s for 90 damage. Garrote: 0.8 s and 100. |
| B7 | Suture flare from A at B, B on an enemy team. | B takes 55. A and A's team see the glow. **B must not see any glow.** B sees the landing light for 5 s. |
| B8 | Feint knives: A throws six, one hits B. B (also Feint) walks over a landed knife and holds E. | B gains one knife at a time up to 6. A non-knife user sees no use for it. A and B both holding E on one knife: exactly one round is gained. |
| B9 | Reticle DMR: A aims at B from 40 studs. | B sees a scope glint at A's head. No glint when A is not aiming. |
| B10 | Parapet Riot Wall between A and B. | A's shots and flares stop at it. |
| B11 | Package carrier B uses the carrier tracking key. | A sees a cue only when tracked, and B pays the intel. |
| B12 | A changes disguise within 60 studs of B. | B sees the swap marker diamond for 5 to 20 s, not through walls. |
| B13 | A eliminates B (Solos). | B is eliminated at once, spectates (ticket 9c), and loses the Tier 4 card if B had one. |

## Always check

- Does anything on a character, name or tag reveal player vs NPC, team or agent? Compare both views.
- Any red errors in the server or client Output, any remote spam, or any rejected shot at normal play?
- Does the Studio window stay focused? A scripted-style cancel (a takedown dropping after 0.35 s) in real play means a wall-tuck bug; note where you stood.

## Report back

For each failed line give: the id, what you did, what you saw and the Output text. Then tag Claude Code with the list.
