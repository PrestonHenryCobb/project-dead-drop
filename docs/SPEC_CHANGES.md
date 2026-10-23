# Proposed spec changes

Derived from the decisions in `docs/OPEN_QUESTIONS.md` (Decided section). `docs/cover-story-game-spec.md` has **not**
been edited. Review this list, then tell me to apply it.

| Spec section | Current | Proposed |
|---|---|---|
| 5 (NPC death, replacement) | NPC dies, replaced after 45 s at a far node | NPC goes down under the Section 14 rules (crawl, 30 s bleed-out, executable). No NPC-revives-NPC. |
| 5.4 (reactions) | Security and Executives ignore gunfire | They investigate within 60 studs same floor, or 40 studs of an open stair or balcony; return after 15 s of quiet |
| 7 (witnesses) | Only Security and cameras | All NPCs and cameras. Rates: Security 1.0, camera 0.6, other NPC 0.2 |
| 7.4 (trespass) | 3 s grace countdown, always ticks | Part of suspicion, builds only when witnessed. HUD always shows a higher-clearance room. |
| 6 (disguise) | Scan copies the NPC disguise | Scan copies outfit, scale, face and animation set. Scan of an exposed agent copies their last disguise after a ~3 s delay. |
| 5 / 7 (movement) | Walk speed cap, sprint allowed | Walk speed equals NPC role speed. Facing follows movement while disguised. |
| 9 (supply caches) | 20% cheaper in higher tiers | Discount by worn disguise tier, 10% per tier |
| 10.1 (vault) | `2 + teams * 2`, cap 14 | Combined across teams. Team carry cap 10 solo, 15 duo. More terminals. |
| 11 (extraction) | Interact for 3 s | Carrier calls, fixed delay with large visual cue, then a capture zone. Enemy in zone freezes progress. Drains while Package unheld. Several sites. |
| 3 / 22 (modes, places) | Squads, Duos, Solos; single place OK for MVP | Duos and Solos queues. Lobby plus match places from the start. |
| 14 (elimination) | Eliminated team's Intel persists | Drops as loot for the eliminating team |
| 15 (weapons) | 8 weapons | 18: 3 unique per agent, 6 agents |
| 16 (agents) | 4 free, 4 unlockable | 6 agents: 3 free, 3 unlockable |
| 18 (monetisation) | Cosmetic only | Cosmetics plus XP boost |
| 25 (map) | The Gala | One map at launch, two more later |

## Added 2026-10-23

| Spec section | Current | Proposed |
|---|---|---|
| 4.2 (zone colours) | Public white, Staff blue, Security orange, Executive purple | Public white, Staff muted navy, Security purple, Executive gold, matching the new outfits |
| 5.1 (NPC outfits) | Staff blue-trimmed uniforms, Security orange armbands, Executives purple accents | Staff light navy suits with black accessories and fedoras, Security black suits with purple trim and sunglasses, Executives cream suits with gold trim |
| 5.1 (NPC counts) | 74: Guest 40, Staff 18, Security 10, Executive 6 | 90: Guest 40, Staff 18, Security 16, Executive 16 |
| 4.3 (NPCNode count) | 150 to 250 | 150 to 320 |
| 5.1 (NPC counts) | 90 (see above) | 200: Guest 120, Staff 40, Security 25, Executive 15 |
| 25 (platforms, performance) | Built for low-end mobile | PC and console targets with a quality setting for weaker machines; touch kept as a fallback only |
| 7.3 (witnesses, suspicion) | Every NPC notices every suspicious action (0.2 share); sprint and jump count only in Tier 1+ | Civilians (non-Security NPCs) notice only sprinting and jumping, at a 0.5 share; Security and cameras notice everything. Sprint and jump count in every tier. All suspicion gains and the trespass rate doubled. Cover-breaking actions unchanged. |
| 9 and 17 (Intel and Funds) | Intel unlocks the vault; Funds buy things | Intel is the only currency: spent on tier doors, the vault unlock, healing and ammo. Spending removes it from unlock progress. Funds are removed. More intel on the map (32 stations). |
| 4.3 / 7 (doors) | Clearance by disguise; keycard doors; lock-picking | Tier doors always cost intel to hack open; the hack keeps your Cover if you wear that tier or higher, otherwise it breaks Cover. |
| 14 (healing) | (unspecified) | No passive healing except an agent's own kit. Wall health stations (bought with intel) in bathrooms; free food heals less. |
| 15.10 (loadout perks) | Pick one loadout perk | Replaced by Assets: per-match perks found in supply caches and tiered-room safes, in four rarities (Field Agent, Infiltrator, Black Ops, Ghost). |
| 15 (agents) | 8 agents with ability, passive and cover perk | 6 agents, one ability on a cooldown and one passive each (draft in AGENTS_DRAFT.md). |
| 4.3 (map objects) | 3 vaults, 18 intel spawns | 4 vaults; 32 intel stations in 4 types; a gondola; bathrooms with health stations; ammo caches; food; safes. |
| 15.9 and 20 (unlocks, progression) | 4 free agents, others for Credits | Three classes of two agents (Deceiver, Enforcer, Specialist); on first launch pick one free agent per class. The rest cost Credits, or come from earned-only cases at 1 in 200. No duplicate agents on a team. Cosmetics are sold in the Black Market shop. See META_DRAFT.md. |
| 16.1 (gadget slots) | Pick 1 gadget from the pool | Pick 2 different sub-gadgets from a shared pool, on top of the agent's own ability (keys 2 and 3; gamepad d-pad). Teammates may pick the same ones. The whole pool is free and chosen in agent select. Smoke Canister, Flashbang and Frag Grenade are removed. Grapple Line is cut too. The pool is 12 gadgets in 4 categories of 3: Recon, Infiltration, Evasion and Support (see GADGETS_DRAFT.md). The Pocket Barricade became a held Briefcase Shield, each Quiet, Discreet (only matters if seen) or Breaks Cover. Scanner Pulse no longer shows its source. Healing gadgets stay weaker than Suture's kit. Refills cost intel (Funds were removed). |
| 4.2 (zone colours) | Staff navy, Security purple, Executive gold | Staff green, Security dark purple, Executive gold, Vault red, each with tier pips; suit trims retuned to match. Tier doors are real doors (style by tier, handles glow in the tier colour), sized by importance. |
