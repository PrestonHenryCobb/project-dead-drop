# Playtest plan (set 2026-10-27)

Targets, not promises. They hold only while scope stays frozen. The riskiest piece is the match loop (Steps 10 to 13):
if it takes much longer than about 7 weeks, playtest 1 slips with it.

## Playtest 1: closed alpha, target mid-January 2027
**Who:** the owner plus 4 to 8 friends, with NPCs and bots filling the rest. **Question it answers:** is one full match fun?

**Must have**
- Weapons and combat, after the two-player test (8.4) and the client side of the six new weapons (garrote, pump shotgun,
  hammer, flare, smoke SMG, throwing knives; see `.ai-sync/WEAPON_SERVER_CONTRACTS.md`).
- Steps 10 to 13: lobby and teams, match phases, intel, vault, package, extraction and overtime.
- Bots that fill empty slots (13B).
- One map (the Gala). The hotel wing can stay as extra space.
- A minimal HUD and basic sounds.

**Can skip:** progression and the shop, cameras, lasers and security NPC combat, most agent abilities and gadgets, the
tutorial (the owner explains the game), matchmaking.

**What to learn:** does stealth feel tense, does the crowd hide players well, is combat fair, is a round a sensible length.

## Playtest 2: open beta, target April 2027
**Who:** 20 to 50 public testers (private link or small group). **Question it answers:** does the game hold up with
strangers, load and cheaters, and do they come back for a second match?

**Adds**
- Steps 14 to 16: cameras, lasers and alarms, security NPC combat, agent abilities.
- Agent select with Talents and Instincts (the owner designs them first; brief Q8).
- The real HUD and minimap, real audio.
- Saved progress and a minimal shop.
- Anti-exploit basics, and the first-run tutorial (13C).
- A performance pass on mid-range PCs.

## Launch: no earlier than about Q3 2027
After playtest 2, once the findings from both playtests are fixed.

## Rules to keep these dates
1. **Freeze scope.** No new weapons, agents or map rebuilds before playtest 1.
2. **Studio tests every week.** Most unverified work (Steps 8, 9, 9c and the six new weapons' server rules) waits on the
   owner running them.
3. **Playtest 1 is a vertical slice.** Anything that does not serve one complete match waits.
