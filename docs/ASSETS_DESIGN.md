# Assets: design (2026-10-28)

Owner answers of 2026-10-28 (asked in chat) replace the random-odds version in `META_DRAFT.md` and `BUILD_ORDER.md` Step 7B.
The six Assets and their numbers per rarity are unchanged. Everything marked **PROPOSED** is mine and waits for an answer.

## What an Asset is
A per-match perk an agent finds in the match and keeps until eliminated. It is never bought with Stocks or Credits, so the
menu's "equal footing" line still holds: everyone can bring the same four.

## The four-slot Asset loadout (owner)
- Before the match each player fills **four Asset slots, one for each rarity**: Field Agent (grey), Infiltrator (green),
  Black Ops (dark purple), Ghost (gold). Each slot holds one of the six Assets.
- What a player finds in the match is a *rarity*, not a fixed Asset: the safe's colour. When an agent takes a safe of a rarity
  they get **their own loadout's Asset for that rarity**, at that rarity's strength.
  Example: Ghost slot = Quick Hands: a gold safe gives them Quick Hands at +40%.
- **PROPOSED:** the four slots hold four different Assets (no repeats), so the choice is real and nothing double-counts.
- The loadout is part of the lock-in (`PlayerLoadout.AssetIds`, four ids by rarity), validated like Hardware and Gadgets.
  The menu's Assets tab changes from a reference codex to a loadout screen (a Codex ticket).

## Safes (owner)
- A safe holds only the rarity of the **room it stands in**: a Public (Tier 0) room's safe is Field Agent, Staff (Tier 1)
  Infiltrator, Security (Tier 2) Black Ops, Executive (Tier 3) Ghost. No odds, no rolls, no shifting. (There are 12 safes,
  `AssetSafe`, each with a `Tier`; a safe in a higher tier than 3 counts as Ghost.)
- **Safes cost intel to open** (owner). **PROPOSED:** 1 / 3 / 5 / 8 intel for Field Agent / Infiltrator / Black Ops / Ghost, a
  3 s hold near the safe, like a tier door; the team pays when the hold ends.
- **PROPOSED:** a safe can be opened once per match by whoever gets there first; the next agent finds it empty. The Asset
  goes to the opener only.
- Supply Caches do not sell Assets for now (the owner did not ask for it). They can later.

## Holding and losing them (owner)
- An agent holds at most one Asset per rarity slot, so at most four. Opening a safe of a rarity they already hold gives
  nothing more (the server refuses the hold, so no intel is wasted).
- **Downed:** keeps them. **Eliminated:** loses them. **Rescued:** returns with none (a rescue costs more than the intel).
- Assets are for the match only; nothing is saved.

## The six Assets by rarity (unchanged, from BUILD_ORDER Step 7B)
| Asset | Field Agent | Infiltrator | Black Ops | Ghost | Where it plugs in |
|---|---|---|---|---|---|
| Light Feet: sprinting and jumping raise suspicion slower | -15% | -25% | -35% | -50% | `CoverService` suspicion gain for sprint and jump |
| Quick Hands: intel stations, doors and the vault hack faster | +10% | +20% | +30% | +40% | `InteractService.setSecondsMult` for Intel, DoorHack, Camera, Lockpick and the vault |
| Steady Nerves: suspicion drains faster once unwatched | +25% | +50% | +100% | +150% | `CoverService` decay rate |
| Deep Pockets: intel purchases cost less | -10% | -15% | -25% | -35% | prices in `SupplyService`, `StationService`, tier doors and safes |
| Field Medic: health stations and food heal more | +15% | +30% | +50% | +75% | `StationService` (Health Station and Food Spot) |
| Duct Rat: crawl through vents faster (quietly from Black Ops) | +20% | +35% | +50% | +75% | `VentService` speed, and no Cover break from Black Ops |

**PROPOSED:** two or more of these that touch one number multiply (for example Quick Hands with Lattice's Wired), and Deep
Pockets never takes a price below 1.

## What gets built (Step 18e, after the answers)
- `Defs/AssetDefs`: the six Assets and their four values (shared with the menu).
- `PlayerLoadout.AssetIds` and its validation in `MetaProgressionService`.
- `AssetService`: the safes (an id each, a rarity from the room's tier, hold kind `AssetSafe`, intel price), what each agent
  holds, loss on elimination and rescue, `AssetState` to the owner (for the HUD). Each Asset reads from its system through a
  small lookup like the agent rules: `AssetService.value(player, assetId)` returns the percent for the rarity held, or 0.
- The six hooks above. Each is a few lines in a system that already exists.
- Codex: the Assets loadout screen (four rarity slots), an in-match held-Assets strip, and a coloured look for the safes
  (their rarity colour, readable at a glance).

## Decided (owner, 2026-10-28, all four proposals confirmed)
1. The four slots hold four different Assets (no repeats).
2. Safe prices: 1 / 3 / 5 / 8 intel for Field Agent / Infiltrator / Black Ops / Ghost, a 3 s hold.
3. A safe opens once per match, for the first agent to finish the hold; after that it is empty.
4. Supply Caches sell no Assets. A safe in a Tier 4 room is Ghost.

Nothing is open: Step 18e can be built from this file.
