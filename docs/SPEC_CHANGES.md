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
