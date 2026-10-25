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
| 9 (intel amounts) | Stations give 1, 2, 3 or 4 intel by the room's tier; vault unlock min(14, 2 + 2 per team) | Scaled up to match Deceive Inc.'s pacing (about a third of collected intel goes on doors): stations give 2, 4, 6 or 10, and the vault unlock is min(35, 5 + 5 per team). 48 stations. A station's type is set per placement, not by the room's tier; the 10-intel safe is only in Security and Executive rooms; vault rooms hold some intel. |
| 4.3 / 7 (tier doors) | Only nested rooms, guard rooms, vault wings and the penthouse are hard-gated; other tier-to-tier doorways are open with trespass rules | Every doorway into a higher tier is a real clearance door. Clearance (an NPC of that tier, or a disguise of it) opens it free; anyone else hacks it with intel: Staff 4, Security 7, Executive 10 (Step 18). |
| 13 (weapons, combat feel) | 8 weapons; one signature primary per agent; 1.5x headshots; ammo by config | 18 weapons (3 per agent), the player picks 1 of their agent's 3 in agent select. Fights take about 1.2 s of sustained fire to down an agent with 1 plate. 3 magazines in total per weapon (loaded plus 2 spare). Left mouse draws and fires; right mouse aims. Reticle's weapons have no damage falloff. Each weapon has a unique effect (see STEP8_QUESTIONS.md). Others see your gun only while you are Exposed. |
| 15 (agent names) | Vesper, Halden, Juno, Sable, Ozzy, Mirage | Guise, Parapet, Lattice, Reticle, Suture, Feint: original names that don't echo other games' casts (user request 2026-10-23). The spec document keeps its old names. |
| 3 / 27 #5 (joining and rejoining) | Nobody re-enters a match they left; new players do not join mid-match | Bots fill empty slots; a new player who connects mid-match takes a bot's place until the vault unlock, after which they only spectate. A player who leaves still cannot return. |
| 14.4 (spectating) | Spectate a living teammate; if the team is out, whoever has the Package, then a free camera | Living teammates first; once the whole team is out, any living player plus a bounded drone camera inside the map volume. Eliminated teams chat in a spectator chat that the living never hear. |
| 16.1 (gadget use) | One key per gadget | Equip, deploy and alternate: holding a gadget never affects Cover, only a deploy does; the alternate button recalls a deployable, which then goes on cooldown. |
| 8.2 (character size) | All outfits scale 95% to 105% | Taller and slimmer for everyone: height 105% to 115%, width and depth 80% to 90%, the same range for players and NPCs. |
| 6.8 / 8.1 (movement feel) | Standard Roblox movement | Lower gravity and a longer jump, and smooth starts and stops on the ground for players **and NPCs** (so easing is never a tell). Character animation and other characters' positions step at 8 a second; your own movement does not. |
| 5.1 (crowd placement) | Spawn by tier weight | An even split between the two towers by floor area, with a minimum on every floor. |

## Added 2026-10-24 (the Deceive Inc. brief, answers in IDEAS_2026-10-24_BRIEF.md)

| Spec section | Current | Proposed |
|---|---|---|
| 5.5 (killing NPCs) | Exposed 10 s, team loses 50 Funds, +1 alarm (Funds since removed) | Exposed and +1 alarm stay. The Funds loss is replaced by **Notoriety**: a civilian downed adds a level, a Security NPC half a level, up to 3; each level raises damage taken (+15%, +30%, +50%) and guard hostility; it decays while you lie low; NPCs hit by one shot or blast count once. |
| 13 (headshots) | 1.5x for everyone (2x marksman) | A hit on a Covered or Suspicious agent always uses body damage, even on the head; multipliers apply once Exposed. |
| 11 (Package) | Carrier pinged every 10 s | A visible ping meter fills over 10 s while walking and pings when full; sprinting or jumping fills it faster. The carrier can hold a key to reveal rival agents within about 30 studs (1 intel to start, 1 a second). |
| 6.4 (applying a disguise) | A particle puff visible within 10 studs | No puff. Instead a disguise-swap marker visible to rival teams: Guest 5 s, Staff 10 s, Security 15 s, Executive 20 s. |
| 15 and 16 (agent kits, unlocks) | One ability and one passive; pick 1 of 3 weapons | Each agent has 3 **Hardware** (weapons), 3 **Talents** (abilities) and 3 **Instincts** (passives). Start with one of each; agent mastery (about 10 matches to max, the 2nd item after about 2) unlocks the rest in a fair order; pick one of each in agent select. |
| 20 (progression, shop) | Daily first-win bonus; seasonal Dossier | Adds daily and weekly contracts for Credits; Dossiers never expire (pick the active one); one game pass (cosmetic set plus XP boost); no Solo bonus. The premium currency is **Stocks**, bought in **the Mint** (banknote-press look). |
| 22 (lobby) | Lobby place | Adds a firing range with plated targets and a damage screen (head, body, legs, totals). |
| 13 (melee) | Fire right after a melee | A per-weapon delay before firing after a melee hit, scaled to the weapon's strength and set case by case. |
| 21 (agent select) | (unspecified) | Each weapon shows exact stats (damage, headshot multiplier, fire rate, magazine, reload, falloff) with themed graphics. |

## Delegated Feint pistol balance (2026-10-24)

The owner delegated the replacement silent pistol's numbers to Codex. It replaces the heavy revolver: 20 damage,
1.5x headshots, semi-auto 320 RPM, 12 loaded / 24 reserve, 1.5 s reload, falloff from 35 to 85 studs to 65%, 0.25 s
post-melee recovery. Quiet: no tracer/flash, 12-stud hearing range around a sound origin displaced 8–15 studs.
It has no Guise ambush multiplier. The lower damage and shorter effective range pay for its misdirection advantage.
Tune these initial values through playtests.

## Owner FPS presentation correction (2026-10-24, ticket 8.15)

This replaces the earlier full-body first-person decision. Hide the actual avatar from its own first-person camera;
use slimmer cosmetic arm meshes in a camera-relative rig. The owner's view never inherits the real avatar's
movement-facing rotation. Other clients still see the normal avatar, facing and animation.

Wall obstruction blends the weapon across the body using its disguised tuck pose, rather than lifting the barrel.
The wall-driven tuck blocks shooting, aiming and melee/takedown attacks before requests, ammo, recoil or audio.
Keep the block while the visible tuck recovers. A crossed-out reticle with OBSTRUCTED replaces both normal weapon
crosshair and disguise dot. Clear the queued trigger/burst so backing away does not fire unexpectedly. Movement,
normal interactions and reload remain available; respawn behavior stays as implemented.

## Owner HUD import and gun-grip review (2026-10-24/25)

The owner brought the functional combat HUD refresh forward from Step 19: reduce persistent explanatory text,
use graphical assets/icons and meters, add readable shadows or translucent colored backdrops, and make feedback
more responsive. Keep actual health/ammo numbers and brief critical warnings. New UI must use existing authorized
game state, without pretending unbuilt shop, objective, elevator or rescue systems exist.

The own gun must stay close and attached to the cosmetic hands through turning, recoil, reload and wall tuck.
Codex's initial correction uses camera-relative smoothing and hands sampled from the rendered gun each frame;
the final choice between smooth first-person motion and a shared stepped gun/hand clock is still in owner review.
The attached design brief's conflicts are audited in PROMPT_REVIEW_2026-10-24.md; its new gameplay proposals have
not silently replaced any earlier answer.

## Owner review answers (2026-10-25)

- Own gun and cosmetic arms move smoothly together. World character models should also be slightly smoother;
  initial tuning is poses at 12 Hz (from 8) and world positions at 18 Hz (from 12), shared by NPCs and players.
  The same PositionStep config drives server rewind; do not add independent client-only positional lag.
- Preserve the existing recorded economy, modes, weapons and gadget decisions while reviewing the attachment.
  Intel-only, Stocks/Mint, Duos/Solos, Feint's pistol and the original 12 gadgets remain in effect.
- Compact graphical HUD with translucent panels/shadows is approved. The selected direction is Field notes.
  Gala gets its own visual skin over a shared HUD; future maps get matching skins with the same base layout,
  behavior and semantic warning colors. Theme selection is startup config until map-session metadata exists.
- Takedowns: the owner's final corrected answer is **6.5 studs total and a 90-degree rear cone**. This supersedes
  the earlier 3.5-stud reply. Keep ordinary melee unchanged, no lunge/teleport, sight checks and the 1.2 s hold.
  Claude owns the server change; do not advertise a live 6.5-stud hint before that server integration lands.

## Owner removes deliberate movement choppiness (2026-10-25, ticket 8.20)

Smooth world movement and animation replace the earlier stepped style, including the interim 12/18 Hz tuning.
Remove pose holds and position quantization for NPCs and players alike. Player movement uses normal Roblox
replication/animation; NPC movement retains continuous interpolation of server snapshots. The own gun/arms stay smooth.
Server shot rewind uses continuous shot time minus the existing per-target render delay, with existing safety clamps.
The obsolete stepping controllers, PositionStep helper and Animation stepping config are removed, not left disabled.

## Owner interview round 1 (2026-10-25)

- First-person gun framing may crop the shoulder stock offscreen, keeping hands/grips, sights and muzzle readable.
  Full-gun-in-frame is superseded. Full geometry still participates in wall-depth protection.
- Takedowns keep **90 damage** and stay **first person**. The approved acquisition change remains 6.5 studs total /
  90-degree rear cone, with ordinary melee unchanged and no teleport/lunge. Server integration remains Claude's work.
- Short cosmetic takedown animations become a shop category and non-expiring Dossier (battle-pass) reward category.
  They play only after server confirmation of the result; whether that means a down/elimination or any successful
  90-damage hold is being clarified. Cosmetics never alter damage, acquisition, hold time or other gameplay rules.
- Charged melee is approved as a mechanic. Takedown attempts start only inside the valid range/cone (and existing
  sight/state checks). The owner reports that initiating the hold currently initiates melee. Clarify tap/hold/release
  semantics before implementing the client and server together; charge duration/damage/recovery remain unspecified.
- Downed from behind: fall forward into prone forearm crawl. Downed from the front: fall backward as if stunned,
  then crawl backward on the back. Use the same behavior for players and NPCs. Side-hit/fall classification is being
  clarified; server owns the transition. Elimination uses a short, stable collapse rather than ragdoll.
- Ordinary clearance doors permit free exit from inside after losing clearance. Outside entry still requires the
  established authorization. Vault/objective locks retain their own rules; the server must determine the interior side.
