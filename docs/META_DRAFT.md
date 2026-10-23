# Meta and progression: draft (2026-10-23)

Decisions from the grilling before Step 7B pass 2. They change spec Sections 15 and 20 and are listed in SPEC_CHANGES.
The systems are built in their own steps (agents in Step 16, assets in Step 18, data and the shop in Step 21); this file
is the record until then.

## Assets (per-match perks)
- Found in supply caches and in safes in tiered rooms. Four rarities, coloured like the tiers: Field Agent (grey),
  Infiltrator (blue), Black Ops (dark purple), Ghost (gold). Effects by rarity are in BUILD_ORDER.md (Step 7B).
- **Odds:** the higher the rarity, the rarer. Base odds: Field Agent 60%, Infiltrator 28%, Black Ops 10%, Ghost 2%. A
  safe in a higher-tier room shifts the odds up a little, but Ghost never goes above about 8%, even in an Executive safe.

## Agents
- Three classes of two agents. **Deceiver:** Guise, Mirage (deception). **Enforcer:** Bastion, Vantage (fighting).
  **Specialist:** Glitch, Suture (tech and support).
- **First launch:** each player picks one free agent from each class (three in all). The other three are earned.
- **Earning:** Credits from matches (spec Section 20); an agent costs about 10 to 15 matches' worth.
- **No duplicates on a team:** in agent select, the first teammate to lock an agent gets it and it greys out for the rest
  of their team. Other teams can still pick it.

## Cases
- **Earned only** (levelling up and match rewards), never bought with Robux, so agents are never sold by chance and Roblox's
  paid-random-item rules do not apply.
- **Contents:** XP boosts, Credit bundles, some cosmetics, and a very small chance of an agent: **1 in 200 (0.5%)**. If the
  agent rolled is already owned, it pays out Credits instead.

## The Black Market (shop)
- Most cosmetics are sold directly in the shop, the Black Market (a rotating storefront, like Overwatch's and Fortnite's).
- **Attire:** agent skins, each with alternate versions.
- **Finishes:** gun skins.
- **Extraction animations and match-win animations,** and more to come.

## Black Market catalogue (ideas, 2026-10-23)

Every cosmetic follows the identity rule (CLAUDE.md rule 3): while disguised, an agent looks exactly like the NPC they copied,
so Attire, Finishes and effects show only in True Form, in the lobby, on podiums and in kill and win screens.

**Attire (agent skins), with alternates**
- High society, the best sellers: the Gala tuxedo and evening gown, Monochrome Noir (black-and-white detective, optional
  fedora), the VIP Escort (white blazer, gold aviators, earpiece).
- Tactical and cyber: the Infiltration Suit (matte black jumpsuit, glowing night-vision goggles), Cyber-Guerrilla (hooded
  techwear, neon straps, digital mask), the Rogue Netrunner (open trench coat, data-stream texture, holographic visor).
- Deep-cover jokes, mid tier: the Tourist (floral shirt, socks and sandals, camera), the Office Drone (grey suit, giant
  "HUMAN RESOURCE MANAGER" badge), the Janitor Elite (boiler suit over a tactical harness).
- Over the top, legendary: the Cardboard Infiltrator (box suit with a crayon tuxedo), the "Invisible" Man (coat, hat and
  glowing glasses), the Golden Asset (a solid gold statue).

**Other cosmetics**
- Finishes (gun skins), designed to pair with Attire bundles.
- Extraction animations and match-win animations (a stealth chopper, a vanish in smoke, a luxury car).
- Intro poses for agent select (checking a wrist gadget, straightening a tie, spinning a silencer).
- Cover-bust effects: what plays when a disguise breaks (glitch pixels, confetti, cartoon smoke).
- Gadget skins and Package skins (a data cylinder, a gold briefcase, a leather satchel).
- Calling cards, titles and frames shown on eliminations and the MVP screen.
- Lobby auras (lobby and podium only), emotes and taunts, and holographic sprays.

**Flags**
- The "Invisible" Man must keep a readable silhouette in True Form (transparent limbs would be pay-to-win); suggest smoked
  glass rather than clear.
- Placing a spray mid-match is an action NPCs never do, so it should count as suspicious (or be True Form only).
- No cosmetic sound or effect may play while disguised.

## Shop structure (2026-10-23)
- **Currencies:** Robux buy **Bonds**, the premium currency, which buys Black Market items. **Credits** are earned in play and
  buy agents and some cosmetics.
- **Format:** a daily rotation of items plus a weekly featured bundle, and a seasonal battle pass (the Dossier) with a free
  and a premium track.
- **Earnable without paying:** Credits buy some cosmetics (basic Attire alternates, calling cards, sprays); the Dossier free
  track; titles and frames from achievements.

## Open
1. The two flags above: the "Invisible" Man silhouette, and whether sprays are allowed mid-match.
