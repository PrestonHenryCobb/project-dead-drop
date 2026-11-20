# Dossiers (ticket dossier; Claude Code, 2026-11-20)

**Built, not run in Studio.** Design: `docs/DOSSIER_DRAFT.md`, with the owner's answers of 2026-11-20: all account XP of a match goes into the active Dossier; 30 tiers of 1,000 XP;
premium costs 800 Stocks per Dossier; the free track as drafted; **one Dossier ships (The Gala Job)**; Titles, Calling cards and Sprays are included as owned ids (name only, no art).
Numbers: `GameConfig.Dossier`. Data: `Defs/DossierDefs` (rewards per tier), `Defs/CosmeticDefs` (every ownable cosmetic: Attire from the Black Market plus the Dossier kinds).

## Server
- Every profile starts with the first Dossier active (`ActiveDossierId`); `MetaProgressionService.settleAccount` adds the match's account XP to it and reports `DossierId` and `DossierXp` in
  `MatchRewardsInfo` (new optional fields). Progress is created on first XP.
- `RequestSelectActiveDossier(id) -> (ok, reason?)` (`UnknownDossier`). `RequestClaimDossierTier(id, tier) -> (ok, reason?)`: refused `UnknownTier`, `NotReached` (XP below tier x 1,000),
  `PremiumRequired`, `NothingToClaim`; otherwise it takes the tier's free rewards and, once premium is unlocked, its premium rewards. `RequestBuyDossierPremium(id) -> (ok, reason?)`
  (`AlreadyOwned`, `NotEnoughStocks`). All through `MetaProgressionService.transact`, saved at the next autosave.
- `DossierProgress.Claimed`: tier n = free track claimed, n plus 100 = premium track claimed. Buying premium late lets the player claim the premium rewards of tiers already passed.
- Rewards: Credits, Stocks, or a Cosmetic id (a duplicate pays 100 Credits). Unknown cosmetic and Dossier ids are dropped when a profile loads.
- The Gala Job: free track pays 900 Credits (150 every fifth tier), titles, cards, three sprays, two Everyday Attire looks and the Waltz Dip takedown at tier 30; premium pays 400 Stocks back (100, 100, 200),
  three Premium Attire looks, a Legendary at tier 30, four finishes, a takedown, an extraction animation and more.

## For Codex (client)
The Dossiers tab: the active Dossier's 30-tier track from `DossierDefs.get(id).Tiers` (Free and Premium rewards per tier, names from `CosmeticDefs`), progress from `Profile.Dossiers[id]` (XP, Premium, Claimed),
a claim button per reached tier, a "Premium (800 Stocks)" button, a switcher from `DossierDefs.order`, and the Dossier XP bar on the Results screen from `MatchRewardsInfo.DossierXp`. Show items without art as "art coming".

## Not built / SPEC-QUESTIONs
- Equipping a title or calling card, and placing a spray (which must count as a suspicious action, META_DRAFT), have no request yet: owning is all there is. Finishes, takedown and extraction animations have no art.
- XP only comes from finished matches (not the lobby). The 30-tier rewards, names and prices are guesses. Night Shift and Black Ledger are not defined.

## Equip (ticket equip-cosmetics, added later the same day)
`RequestEquipCosmetic(kind, cosmeticId?) -> (ok, reason?)`: kind is "Title" or "Card"; the id must be an owned cosmetic of that kind (`UnknownKind`, `UnknownCosmetic`, `NotOwned`), nil takes it off.
Saved as `Profile.EquippedTitle` and `EquippedCard`. Not built: showing them to other players (the kill feed and results rosters do not carry them) and spray placement.
