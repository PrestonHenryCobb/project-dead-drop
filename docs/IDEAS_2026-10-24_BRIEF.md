# The Deceive Inc. brief, sorted (2026-10-24)

You gave me a long brief (`claude_code_deceive_inc_prompt.md`) written as a master prompt for Claude Code and Codex. It
describes Deceive Inc.'s systems in detail. This file sorts it against what Cover Story already has, the same way as
`IDEAS_2026-10-24.md`. Nothing here changes an earlier decision, and nothing is built until you answer.
**All 13 answered on 2026-10-24** and recorded in `SPEC_CHANGES.md`.

Two ground rules apply to everything below:
- **Inspiration only** (your rule): no Deceive Inc. names, numbers, layouts or assets. Where a brief item is worth having,
  it gets our own name and our own numbers.
- **The brief's process is replaced.** Its `Contracts.luau`, ownership matrix and task board became `AGENTS.md`,
  `.ai-sync/AI_SYNC_STATE.md` and `.ai-sync/TASK_QUEUE.md`, using the existing `Remotes`, `Types`, `Enums` and `GameConfig`
  as the contract. Its "build five services now" plan is not followed: we stay on one step at a time, Step 8 first.

---

## 1. Already in Cover Story (nothing to do)
| Brief item | Where we have it |
|---|---|
| Intel per device usable once per team | Spec 9.2, intel tracked per team |
| Spawn disguised as a random civilian | Spec 6.5, insertion disguise |
| Clearance by disguise tier; wrong tier is punished | Spec 6.2, 7.4 and SPEC_CHANGES (tier doors, trespass suspicion) |
| A 10-intel door to the inner vault | Executive tier door, 10 intel to hack (SPEC_CHANGES) |
| Package carrier pinged every 10 s | Spec 11 (`Package.PingInterval = 10`), carrier can never disguise |
| Several extraction sites, win by extracting | Spec 11 and SPEC_CHANGES (capture zone, several sites) |
| A random vault each match | Four vaults, one chosen in Phase 3 |
| Per-match perks in rarities | Assets, four rarities (Field Agent, Infiltrator, Black Ops, Ghost) |
| Cosmetics only in True Form, never while disguised | META_DRAFT and CLAUDE.md rule 3 |
| Weapon skins, outfits, intro and win poses, Package skins, calling cards, gadget skins | META_DRAFT, the Black Market catalogue |
| Credits earned in play, a premium currency bought with Robux | META_DRAFT shop structure |
| Paid random items avoided | Cases are earned only, never bought, so `PolicyService` paid-random rules do not apply |
| Food and health stations | Map pass 2 and SPEC_CHANGES (no passive healing) |

## 2. Conflicts: the brief disagrees with a decision (recommend keeping ours)
| Brief | Ours | Recommendation |
|---|---|---|
| Five disguise tiers (Civilian, Staff, Guard, Technician, VIP) | Four tiers plus the vault: Public, Staff green, Security dark purple, Executive gold, Vault red | Keep ours |
| Disable 3 of 5 Vault Terminals to open the vault | Collect intel to a team-scaled unlock, min(35, 5 + 5 per team) | Keep ours |
| Cover is a shield that regenerates over 3 s | Cover is a stealth state (Covered, Suspicious, Exposed) with re-covering rules | Keep ours; regen timing does not apply |
| Field Upgrade decks: 8 saved loadouts of 5 chips, bought with intel at terminals | Assets found in supply caches and tiered safes | Keep ours |
| W1-W3, E1-E3, P1-P3 kits unlocked by agent level | 3 weapons per agent, pick 1 in agent select; one ability and one passive | **Changed by Q8:** 3 Hardware, 3 Talents, 3 Instincts per agent, unlocked by mastery |
| 10 gadgets including a shield umbrella, bounce mat, decoy props | 12 sub-gadgets in 4 categories (GADGETS_DRAFT) | Keep ours |
| "Social Battery" heals while emoting | No passive healing except Suture's kit | Keep ours |
| Sell agents for Robux or premium currency | Agents for Credits or earned cases; monetisation is cosmetics plus an XP boost | Keep ours (see Q11) |
| Premium currency named **Bonds** | We had also chosen Bonds | **Renamed ours to Stocks** (Q12) |

## 3. New ideas worth a decision
Ordered by how much they would change the game.

### Q1. A penalty for downing innocent NPCs (the brief's "Heat")
- **Today:** spec 5.5 punished killing a civilian with Exposed for 10 s, a 50 Funds loss and +1 alarm. **Funds were removed**
  (SPEC_CHANGES), so the money part of that penalty is gone and nothing has replaced it. This is a real gap.
- **Options:** (a) *an intel fine instead of Funds (for example 2 intel for a civilian, nothing extra for Security), keeping
  the Exposed and alarm parts* (b) a "Notoriety" meter of our own: each civilian downed adds a level (Security half a
  level), each level adds incoming damage (for example +15%, +30%, +50%) and guard hostility, and it decays when you lie low;
  hits on several NPCs in one shot count once (c) both (d) keep only Exposed and alarm.
- **Answer:** **Notoriety meter** (our own name and numbers). Each civilian (Guest, Staff, Executive) downed adds one level and a Security NPC half a level, up to 3. Each level raises the damage you take (defaults +15%, +30%, +50%, tuned in play) and how readily guards engage you; it decays while you lie low. Several NPCs hit by one shot or blast count once. Exposed and +1 alarm stay as in spec 5.5. No intel fine.

### Q2. The first shot on a disguised agent can't be a headshot
- **Brief:** while disguised, the hit that breaks cover always counts as a body shot.
- **Why it matters here:** Reticle's DMR headshot downs an agent with 0 or 1 plate (STEP8 answers), so a disguised agent can
  be one-shot from range with no chance to react. This rule gives everyone one hit's warning.
- **Identity check:** it leaks nothing new, since the red agent hitmarker already reveals an agent on any hit.
- **Options:** (a) *yes: a hit on a Covered or Suspicious agent uses body damage even on the head* (b) no, keep 1.5x and 2x
  headshots for everyone.
- **Answer:** (a) Yes: a hit on a Covered or Suspicious agent uses body damage even on the head. Headshot multipliers apply once they are Exposed.

### Q3. A light over the vault's inner door showing whether a rival team is inside
- **Options:** (a) *no: walking in blind is part of the tension, and Agent Sense already hints* (b) yes, red when another team
  is inside the strongroom.
- **Answer:** (a) No light. Walking in blind stays part of the tension.

### Q4. The Package carrier can see through disguises, at an intel cost
- **Brief:** the carrier holds a key to see rival agents nearby, draining intel each second.
- **Today:** the carrier is pinged every 10 s and cannot disguise, so they are hunted with no tool of their own except their
  agent's kit.
- **Options:** (a) *no: keep the carrier a target* (b) yes: hold to reveal agents within about 30 studs, costing 1 intel to
  start and 1 a second (our own numbers, tuned in play).
- **Answer:** (b) Yes: the carrier holds a key to reveal rival agents within about 30 studs, 1 intel to start and 1 a second (tuned in play).

### Q5. Carrier ping faster when sprinting or jumping
- **Options:** (a) *no: a steady 10 s* (b) yes: every 5 s while sprinting or jumping.
- **Answer:** A **visible ping timer**: a meter fills over 10 s while the carrier walks and pings when full; sprinting or jumping fills it faster for as long as they do it (default about twice as fast, tuned in play), instead of a fixed rate.

### Q6. A disguise-swap marker (the brief's "Holo-Crumbs")
- **Brief:** where you take a disguise, a marker shows (friendly to your team, hostile to rivals).
- **Today:** applying a disguise shows a puff to anyone within 10 studs, and copying an NPC creates a visible twin, which is
  already the intended tell (spec 6.6).
- **Options:** (a) *no: the twin and the puff are enough* (b) a short-lived marker (for example 20 s) visible to rivals only
  within some range.
- **Answer:** Yes, short-lived and visible to rival teams: it lasts longer for higher tiers, **Guest 5 s, Staff 10 s, Security 15 s, Executive 20 s** (the cap). **The disguise puff is removed** (spec 6.4), so taking a high-tier disguise is not an outsized advantage. Range to tune in play.

### Q7. A firing range with a damage screen
- Targets with toggleable armour plates and a big screen showing the last hit (head, body, legs) and total damage, so
  players can learn each weapon. Lives in the lobby place (Step 22) or the tutorial (Step 13C).
- **Options:** (a) *yes, in the lobby, built with Step 22* (b) yes, earlier, as a test map for Step 8 tuning (c) no.
- **Answer:** (a) Yes, in the lobby, built with Step 22.

### Q8. Agent mastery levels
- **Today:** all three weapons are pickable from the start; nothing levels per agent.
- **Options:** (a) *per-agent levels that unlock cosmetics only (finishes, a mastery weapon skin, titles), never weapons or
  abilities* (b) levels that also unlock the 2nd and 3rd weapons (slower start, more grind) (c) none.
- **Answer:** **Mastery unlocks kit, in a fair order, and is easy to earn.** Each agent has **3 Hardware** (weapons), **3 Talents** (abilities) and **3 Instincts** (passives). Every agent starts with one of each; mastery unlocks the other two of each, and in agent select you pick one Hardware, one Talent and one Instinct. About **10 matches with an agent** to unlock everything (the 2nd item after about 2); wins and objectives speed it up. Needs 12 new Talents and 12 new Instincts designed (Step 16, AGENTS_DRAFT).

### Q9. Daily and weekly contracts
- Small goals for Credits, for example "Hack 15 stations as a Guest", "Extract without downing an NPC".
- **Options:** (a) *yes, with the shop in Step 21* (b) no, keep the daily first-win bonus only (spec 20).
- **Answer:** (a) Yes, daily and weekly contracts with the shop in Step 21.

### Q10. Battle-pass seasons that never expire
- **Today:** META_DRAFT has the Dossier, a seasonal pass with a free and a premium track; it does not say what happens when a
  season ends.
- **Brief's idea:** past passes stay buyable and you choose which one your earned progress goes into.
- **Options:** (a) *yes: every Dossier stays available; you pick the active one* (b) seasons end, as most games do.
- **Answer:** (a) Every Dossier stays available; you pick the active one.

### Q11. A game pass
- **Brief:** a VIP pass with formal cosmetics, a +20% XP boost and starter premium currency.
- **Today:** spec allows cosmetics plus an XP boost; no game pass is planned.
- **Options:** (a) *one game pass of our own design: a cosmetic set and an XP boost, nothing that affects play* (b) none,
  only the shop.
- **Answer:** (a) One game pass of our own design: a cosmetic set and an XP boost, nothing that affects play.

### Q12. Rename the premium currency
- The brief says "Bonds" is Deceive Inc.'s premium currency. If so, ours needs its own name. Ideas in our spy-gala theme: **Chips** (casino), **Marks**, **Dossier Points**.
- **Answer:** The premium currency is **Stocks**. The screen where you buy them is **the Mint**, with a background to match (a banknote and coin press: engraved plates, presses, vault metal, ledger green).

### Q13. Extra Credits for playing Solo
- **Options:** (a) *yes, a modest bonus (for example +20%) because Solo is harder* (b) no.
- **Answer:** (b) No: the same Credits in every mode.

### Not taken up
- **A personal hideout or trophy room:** a large new space with little play value; can be proposed after launch.
- **Model routing for the agents** (which model runs which phase): a tooling choice for you, not part of the game.
- **The brief's Field Upgrade numbers, season names and patch details:** Deceive Inc.'s own data; not used.

---

## Where answers would land
| If yes | Step |
|---|---|
| Q1 penalty | Step 9 (downed NPCs) or Step 14 (alarm) |
| Q2 first-hit rule | Rest of Step 8 (combat) |
| Q3, Q4, Q5 vault and carrier | Steps 12 and 13 |
| Q6 marker | Step 6 follow-up, any time after Step 8B |
| Q7 firing range | Step 22 (or now, if b) |
| Q8 to Q13 meta and shop | Step 21 |
