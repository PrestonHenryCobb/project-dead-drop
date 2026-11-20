# Dossier design: draft (2026-11-20, for the owner to edit or approve)

Nothing here is built. It follows the owner's decisions so far: Dossiers **never expire**, the player picks the **active** one, earned progress goes **straight into the
active Dossier** (no Catalog Token or other new currency), there is a free track and a premium track, **no gameplay power is sold**, and every reward obeys the identity rule
(cosmetics show only in True Form, the lobby and the win and kill screens). Sources: `docs/META_DRAFT.md`, `docs/SPEC_CHANGES.md` (2026-10-25), `docs/IDEAS_2026-10-24_BRIEF.md` Q9.
What the code already has: `Types.DossierProgress { XP, Premium, Claimed }`, `Profile.Dossiers`, `Profile.ActiveDossierId`, the remotes `RequestClaimDossierTier(dossierId, tierIndex)` and
`RequestSelectActiveDossier(dossierId)` (both answer `NoCatalogue` today), and the Dossiers tab (shows an honest empty state).

## 1. How progress works
- **Dossier XP = the account XP a match pays** (the lines in `REWARDS_CONTRACT.md`, about 250 to 600 a match). It goes to the active Dossier at match end, in the same step that settles
  account XP. No active Dossier, no Dossier XP (the menu nags once: pick one). Changing the active Dossier is free and any time outside a match.
- **A Dossier has 30 tiers, 1,000 XP each** (30,000 XP in all, roughly 60 matches). Tier N is reached when XP is at least N times 1,000. XP past tier 30 is kept and does nothing.
- **Free and premium rewards sit on the same tiers.** Rewards are claimed by the player (a button per tier, or Claim All) so nothing arrives unseen; claiming is idempotent and the server refuses a tier not yet
  reached or already claimed.
- **Premium** is a permanent per-Dossier unlock bought with **Stocks (800)**, never Robux directly, so the Mint stays the only Robux door. Buying it later back-fills every tier already reached.
  About half the Stocks come back across the premium track (tiers 10, 20 and 30 pay 100, 100 and 200), so a keen player nearly pays it off. SPEC-QUESTION: all numbers are guesses.

## 2. What the rewards are (all cosmetic or soft currency)
| Reward kind | Free track | Premium track | Notes |
|---|---|---|---|
| Credits | 150 on every fifth tier (900 in all) | none | Credits never buy power either: agents and Everyday Attire only |
| Stocks | none | 400 spread over tiers 10, 20, 30 (see above) | refund, not profit |
| Calling cards, titles, frames | 1 every 3 tiers | 1 every 3 tiers (the fancier ones) | shown on kill and MVP screens; text and 2D only |
| Sprays | 3 | 3 | placing one mid-match counts as a suspicious action (META_DRAFT flag) |
| Attire (agent skin) | 2 Everyday looks | 3 Premium looks, 1 Legendary at tier 30 | uses the same `OwnedCosmetics` ids as the Black Market (`ShopDefs`) |
| Finishes (gun skins) | none | 4 | art needed |
| Takedown animation | 1 at tier 30 | 1 at tier 15 | only plays after the server confirms a down or elimination |
| Extraction or win animation | none | 1 at tier 25 | art needed |
No reward changes damage, speed, cooldowns, detection or anything else the match depends on. Duplicates (an item the player already owns) pay 100 Credits instead.

## 3. The first three Dossiers (names are ideas, theme follows the Gala)
1. **The Gala Job** (the starter): high society looks, brass and ivory cards. Free Attire: two Guise or Reticle alternates. Premium Legendary: a gilded attire.
2. **Night Shift**: staff, kitchen and service looks (Janitor, Office Drone, Tourist colour-ways), jokey titles.
3. **Black Ledger**: tactical and cyber looks, neon cards, the takedown animation.
A new Dossier ships when its art is ready; old ones never go away. Each Dossier is one data entry (`Defs/DossierDefs`: id, name, tiers with a free and a premium reward each), so adding one needs no code.

## 4. Server work (Claude Code, about a day, once approved)
- `Defs/DossierDefs.luau` and `GameConfig.Dossier` (tiers, XP per tier, premium price in Stocks, duplicate payout). Reward kinds: Credits, Stocks, Cosmetic(id), Title(id), CallingCard(id), Spray(id).
- `DossierService`: adds match XP to the active Dossier from `RewardService` settlement; implements `RequestSelectActiveDossier`, `RequestClaimDossierTier` (reached, unclaimed, premium needed for premium rewards,
  grants through `MetaProgressionService.transact`), and a new `RequestBuyDossierPremium(dossierId)` (Stocks, back-fills nothing automatically; the player claims). Included in the saved profile; `reconcile`
  drops unknown Dossiers and clamps claimed lists. Unknown reward ids are refused at load.
- `MatchRewardsInfo` gains `DossierXp` and `DossierId` so the results screen can show the bar moving (additive).
- Extend `ShopDefs` or a sibling `CosmeticDefs` so Titles, Calling cards and Sprays exist as owned ids (names only, no art needed for titles and cards).

## 5. Client work (Codex, once approved)
The Dossiers tab: the selected Dossier's 30-tier track with free and premium rows, claim buttons, a premium-unlock button, a switcher to pick the active Dossier, and the XP bar on the Results
screen. Items without art show as "art coming".

## 6. Questions for the owner (my recommendation first)
1. **XP source:** all account XP goes into the active Dossier (recommended), or a separate smaller Dossier XP rate?
2. **Length and pace:** 30 tiers at 1,000 XP, about 60 matches per Dossier (recommended), or shorter (20 tiers) so a casual player finishes one?
3. **Premium price:** 800 Stocks per Dossier with a Stocks refund track (recommended), or premium included free with the one game pass?
4. **Free track generosity:** the table above (a free Legendary-adjacent reward only at tier 30), or keep all Attire premium?
5. **Launch count:** ship one Dossier (the Gala Job) first (recommended), or three?
6. **Sprays and calling cards:** build them in this step, or leave Titles and Attire only until art exists?
