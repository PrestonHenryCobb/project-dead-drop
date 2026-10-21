# COVER STORY: Game Design & Rules Specification (v1.0)
*Working title. A Roblox social-stealth extraction shooter inspired by the Deceive Inc. genre.*

> **For Claude Code:** This document is the single source of truth for gameplay. Every number in it is a starting value and must live in `GameConfig` (Section 22), not in code. When a rule here conflicts with Roblox engine limits, keep the *player-facing behavior* identical and change the implementation. Build in the milestone order from Section 25. Do not invent mechanics that aren't listed here. If something is ambiguous, pick the option that keeps the game fair and server-authoritative, and leave a `-- SPEC-QUESTION:` comment.

> **IP note:** Use only original names, characters, maps, art, logos and UI. Do not use the names, agents, maps or branding of any existing game in code, assets or the Roblox listing.

---

## Table of contents
1. Core concept and win condition
2. Match structure and phase timeline
3. Lobby, teams and agent select
4. Map requirements
5. NPC system
6. Disguise system
7. Cover, suspicion and exposure
8. Spotting other agents (tells and counter-intel)
9. Intel
10. The vault
11. The package
12. Extraction
13. Combat
14. Downed, revive, elimination and rescue
15. Agents (8 original agents)
16. Gadgets
17. Pickups, funds and supply caches
18. Security systems (cameras, lasers, doors, alarms)
19. Endgame and overtime
20. Scoring, XP and progression
21. HUD and UI (every element)
22. Config tables
23. Audio
24. Controls (PC, mobile, console)
25. Technical architecture and Roblox implementation
26. Anti-exploit and identity secrecy
27. Edge cases (must all be handled)
28. Build milestones and test checklist

---

## 1. Core concept and win condition

- Up to **12 players** drop into a crowded building full of AI-controlled NPCs. Every player spawns **disguised as an NPC**.
- Teams race to **collect Intel**, **open the Vault**, **steal the Package**, and **extract** it.
- **Exactly one team can win a match**: the team that successfully extracts the Package. Everyone else loses.
- If the match timer and overtime both expire without an extraction, **no one wins** ("Mission Failed" for all teams).
- Killing other agents is allowed and often necessary, but kills alone never win the match.
- The core tension: anyone in the crowd might be a player. Acting like a player (running, jumping, shooting, entering places you shouldn't) gives you away.

---

## 2. Match structure and phase timeline

| Phase | Name | Duration | What happens |
|---|---|---|---|
| 0 | Lobby / Agent Select | 30 s (ends early when all locked in) | Pick agent, gadget, loadout perk |
| 1 | Insertion | 8 s | Black screen, mission briefing card, players spawned and frozen, disguised |
| 2 | Infiltration | Until Vault unlocks (max 6:00) | Collect Intel, gather Funds, scout |
| 3 | Vault Breach | Until hack hits 100% | Vault location revealed to everyone, hack it |
| 4 | Package Heist | Until extraction | Package is out; carrier must reach extraction |
| 5 | Overtime | Only if the Package is held when the main timer ends | See Section 19 |
| 6 | Results | 15 s | Winning team cinematic, scoreboard, XP |

- **Main match timer:** 14:00, counting down from the start of Phase 2.
- Phase 2 ends when **either** total uploaded Intel reaches the unlock threshold (Section 10.1) **or** the timer reaches 8:00 remaining (forced unlock at 6:00 elapsed).
- Phase transitions are driven only by `MatchService` on the server. Every transition fires `PhaseChanged(newPhase, data)` to all clients.
- Phase banners: large centered text for 3 s (e.g., "THE VAULT IS OPEN FOR BREACH").

---

## 3. Lobby, teams and agent select

### 3.1 Modes
| Mode | Team size | Max teams | Max players |
|---|---|---|---|
| Squads (default) | 3 | 4 | 12 |
| Duos | 2 | 6 | 12 |
| Solos | 1 | 8 | 8 |

- Minimum players to start a public match: 4 (Squads), 4 (Duos), 3 (Solos). Below that, fill countdown waits up to 60 s, then starts with whoever is present if at least 2 teams exist. If only 1 team exists, do not start.
- Party members (Roblox party / friends who queue together) are placed on the same team. Remaining slots fill randomly.
- If a team is short a player, it plays short. No bots replace players.

### 3.2 Agent select
- Each player picks one agent (Section 15). **Duplicate agents are not allowed on the same team** but are allowed across teams (this is fine because enemies can't see your agent while disguised).
- Each player also picks:
  - **1 Gadget** from the gadget pool (Section 16.1).
  - **1 Loadout Perk** (Section 15.10).
- Locked agents (not yet unlocked through progression) are shown greyed with lock icon.
- If a player hasn't locked in when the timer ends, auto-lock their last-used agent or a random available one.
- Teammates see each other's picks live. Enemies never see your pick.

### 3.3 Team identity
- Each team gets a color (Cyan, Magenta, Lime, Amber, then for Duos/Solos: Violet, Coral, Teal, White).
- Team color is **only visible to that team**: teammates see a small colored diamond above each other's heads (through walls) and a colored outline. Enemies see nothing.

---

## 4. Map requirements

### 4.1 First map: "The Gala" (original)
A three-floor luxury museum/estate hosting a charity gala. Footprint approx. 450 × 450 studs, plus rooftop and basement.

### 4.2 Clearance zones
Every walkable area belongs to exactly one zone, marked by a tagged invisible `ZoneVolume` part with attribute `Tier` (0–3).

| Tier | Name | Color on minimap and floor trim | Examples |
|---|---|---|---|
| 0 | Public | White/Gray | Lobby, galleries, ballroom, gardens, restrooms |
| 1 | Staff | Blue | Kitchens, offices, catering, coat check |
| 2 | Security | Orange | Security hub, camera room, armory hallways, basement corridors |
| 3 | Executive | Purple | Penthouse, private gallery, vault antechamber |

- The Vault room itself is Tier 3.
- Each zone transition has a visible doorway with colored trim and a floor decal so players can always see what tier they're stepping into.
- Zone detection: server checks each player's `HumanoidRootPart` position against zone volumes every 0.25 s using `workspace:GetPartBoundsInBox` or spatial lookup on precomputed bounds. Store `CurrentZoneTier` server-side.

### 4.3 Required map objects (all tagged with `CollectionService`)
| Tag | Count on The Gala | Notes |
|---|---|---|
| `InsertionPoint` | 12 | Spread across Tier 0 areas, min 60 studs apart. Each team spawns at one point, players within 8 studs of each other. |
| `NPCNode` | 150–250 | Waypoint graph for NPCs. Attributes: `Tier`, `Activity` (Walk, Idle, Talk, Sit, Lean, Drink, Work, Guard). |
| `IntelSpawn` | 18 | Server activates 10 per match at random, with at least 2 per tier. |
| `VaultSpawn` | 3 | One is chosen per match. Map must include 3 vault rooms; the 2 unused stay locked with decorative doors. |
| `ExtractionSite` | 3 | Rooftop helipad, loading dock, garden lawn. |
| `SupplyCache` | 6 | 2 in Tier 0, 2 in Tier 1, 1 in Tier 2, 1 in Tier 3. |
| `SecurityCamera` | 12 | See Section 18. |
| `LaserGrid` | 4 | Only in Tier 2/3. |
| `KeycardDoor` | 6 | Shortcut doors between tiers. |
| `Vent` | 6 pairs | Crawlspaces connecting rooms. Entering a vent is a Cover-breaking action. |
| `ZiplineAnchor` | 2 pairs | Exterior movement, Cover-breaking. |
| `PickupSpawn` | 30 | Random armor, ammo, Funds pickups. |
| `ClimbSurface` | many | Ledges players may mantle. |

### 4.4 Map design rules
- Every Tier 1+ zone must have at least 2 entrances.
- Every Intel spawn must be reachable without climbing.
- Each extraction site must be at least 120 studs path distance from each vault spawn.
- Sight lines longer than 150 studs should be rare (2–3 in the map, reserved for the marksman agent).
- No dead-end vault room: each vault spawn has at least 3 routes out.

---

## 5. NPC system

### 5.1 NPC roles
| Role | Tier allowed | Count per match | Behavior |
|---|---|---|---|
| Guest | 0 | 40 | Walk between galleries, idle at art, talk in groups, sit, drink |
| Staff | 0–1 | 18 | Walk briskly through Tier 0 and Tier 1, carry trays, work at desks |
| Security | 0–2 | 10 | Patrol fixed loops, stand posts, react to threats (Section 18.5) |
| Executive | 0–3 | 6 | Slow walks between penthouse, private gallery, ballroom; often escorted |

- Total NPCs: target 74, configurable. Must stay at 30 Hz-equivalent smoothness for 12 players on mid-range mobile.
- Every NPC has a randomized appearance from that role's appearance pool (outfit, skin tone, hair, accessories). Each role has **at least 20 outfit combos** so duplicates are uncommon.
- Each role has a **uniform signature** that makes the tier readable at a glance: Guests in varied formalwear, Staff in blue-trimmed waiter/office uniforms, Security in orange-armbanded dark suits, Executives in purple-accented suits with a lapel pin.

### 5.2 Movement
- NPCs walk at **walk speed 10** (studs/s), Staff at **12**, never sprint, never jump, never crouch, never climb.
- NPC pathing uses the `NPCNode` graph (precomputed adjacency). Each NPC picks a destination node from its allowed tiers, walks there, performs the node's `Activity` for 6–20 s (random), then picks another.
- NPCs turn smoothly (max 270°/s yaw). They avoid each other with simple separation (no overlap within 2.5 studs).
- NPC doors: NPCs open doors automatically; doors close 3 s after the last body passes.
- NPCs **never stop at intel terminals, vents, vault, or extraction sites** (so lingering there is a tell).

### 5.3 Idle animations
Each `Activity` maps to an animation set: Idle (shift weight), Look at Art, Talk (gesture), Phone, Drink, Sit, Lean, Typing, Guard Stance. Players can perform the same set via the Blend emote wheel (Section 6.7).

### 5.4 NPC reactions
- **Gunfire within 40 studs:** Guests and Staff crouch-cower for 3 s, then flee to the farthest node in the same tier at speed 16 for 8 s ("Panic"). Then resume.
- **Gunfire or an explosion heard by a guard:** Security NPCs on the same floor within 60 studs, or on another floor within 40 studs with a clear line to the source (a stair or balcony open to the floor), walk to the noise and wait. They return to their post after 15 s with no further noise in range.
- **Dead body / downed agent within 15 studs:** Guests gasp animation, back away.
- **Explosion within 25 studs:** same as gunfire, plus the NPC is downed if within 6 studs (see 5.5).
- Panic is a tell: players who don't panic stand out. Players can trigger a fake panic with the Blend wheel's "Cower" emote.

### 5.5 Killing NPCs
- NPCs have 50 HP. Civilians (Guest, Staff, Executive) killed by a player: the killer becomes **Exposed** for 10 s minimum, team loses 50 Funds, and the nearest camera/guard network raises Alarm Level by 1.
- NPCs are never killed outright. At 0 HP an NPC is **downed** under the Section 14.1 rules (crawls at speed 4, bleeds out after 30 s) so it cannot be told apart from a downed player. Nothing revives an NPC. A bled-out NPC lies still for 30 s, then fades. A replacement NPC of the same role spawns at a random far-away node 45 s after it bleeds out.
- Security NPCs can be killed without Funds penalty but always raise Alarm Level by 1.

---

## 6. Disguise system

### 6.1 Core rule
Every agent is always in one of two looks:
- **Disguised:** looks exactly like an NPC (role outfit, same animations, same movement limits).
- **True Form (Exposed):** looks like their agent model, with agent weapon visible.

### 6.2 Clearance
- Each disguise has a **Clearance Tier** equal to the NPC role it copies (Guest 0, Staff 1, Security 2, Executive 3).
- A disguised agent may stand in zones up to and including their Clearance Tier with no penalty.
- An agent in True Form has effectively **no clearance**: any Tier 1+ zone treats them as a trespasser (security will engage).

### 6.3 Scanning (acquiring a disguise)
- Aim at an NPC (or a disguised enemy agent) within **8 studs** and hold **Scan** (default `F`) for **1.2 s**.
- Requirements: not in True Form combat lockout (Section 7.6), target in line of sight, target not ragdolled.
- During scan, a thin progress ring appears on the scanner's HUD. **No visible effect on the target** (scanning is silent and quiet).
- Scanning is **not** cover-breaking, but it is a mild tell: the scanner must look at and stay near the target.
- On completion: the target's full appearance and clearance are stored in the agent's **Disguise Slot** (1 slot by default). Scanning again overwrites it.
- Scanning a disguised enemy agent copies the NPC disguise they are wearing (not their True Form).

### 6.4 Applying a disguise
- Press **Disguise** (default `G`) to put on the stored disguise. Takes **0.8 s** (short fabric-swish animation, small particle puff visible to people within 10 studs).
- Can also be used with no stored disguise to return to the **insertion disguise** (the one you spawned with).
- Blocked while: in combat lockout, being seen by a Security NPC or camera that is currently tracking you, carrying the Package, downed, or in a zone above the new disguise's clearance.
- When applied, the agent's character instantly matches: outfit, body proportions, walk speed cap, animation set, footsteps, nameplate (none).

### 6.5 Insertion disguise
- At spawn, each agent gets a random **Guest** (Tier 0) disguise. Teammates get different outfits.

### 6.6 Duplicate appearance
- If you copy an NPC, two identical people now exist. This is an **intended tell**. Do not prevent or hide it.

### 6.7 Blend wheel (social stealth tools)
Hold **Blend** (default `B`) to open a radial with: Idle, Look Around, Phone, Drink, Talk, Lean, Sit (only near a seat), Cower. Emotes are cancelled by movement. Emotes are not cover-breaking.

### 6.8 Movement while disguised
| Action | Allowed? | Effect |
|---|---|---|
| Walk | Yes | Speed capped to the disguise role's walk speed (10 or 12) |
| Sprint | Yes, speed 18 | **Suspicious** in Tier 1+ when witnessed (Section 7.3). Always a visual tell. |
| Jump | Yes | Suspicious when witnessed. NPCs never jump. |
| Crouch | Yes | Suspicious when witnessed. |
| Climb / mantle / vault | No while disguised: doing it **breaks Cover** |
| Vent / zipline | Breaks Cover |

---

## 7. Cover, suspicion and exposure

### 7.1 Cover states (server-owned, one per agent)
| State | Meaning | HUD color |
|---|---|---|
| `Covered` | Disguised, nothing suspicious | Green eye icon |
| `Suspicious` | Disguised, suspicion meter > 0 | Yellow eye, meter filling |
| `Exposed` | True Form, visible to all as an agent | Red eye, "EXPOSED" text |

### 7.2 Cover-breaking actions (instant Exposed, no meter)
1. Firing any weapon.
2. Using an offensive ability or throwing a damaging/blinding gadget.
3. Melee attack or takedown.
4. Climbing, mantling, vaulting, entering a vent, using a zipline.
5. Picking up or carrying the Package.
6. Reviving a teammate or executing an enemy.
7. Opening a Supply Cache upgrade (it's a loud action).
8. Hacking the Vault.
9. Staying in a zone above your clearance after the trespass grace runs out (7.4).
10. Suspicion meter reaches 100%.
11. Killing any NPC.
12. Picking a lock on a keycard door without a keycard.

When Exposed: the disguise is visually stripped in 0.3 s (puff effect), the agent's True Form appears, and a red **"!" ping** shows on all enemies' HUD at that location for 2 s if they are within 60 studs.

### 7.3 Suspicious actions (fill the suspicion meter only when witnessed)
A *witness* is any Security NPC or active, non-hacked Security Camera with line of sight to the agent within its detection range (Security NPC 35 studs, 110° FOV; camera see Section 18.1). Guests, Staff and Executives are **not** witnesses.

| Action (while witnessed) | Suspicion gain |
|---|---|
| Sprinting in Tier 1+ zone | 25% per second |
| Jumping in Tier 1+ zone | 20% per jump |
| Crouching in Tier 1+ zone | 15% per second |
| Interacting with an Intel terminal | 20% per second |
| Holding a weapon drawn (aiming) while disguised | 40% per second |
| Being within 6 studs of a dead body | 10% per second |
| Lingering within 5 studs of the open Vault for > 3 s | 15% per second |

- Suspicion decays at **10% per second** once nothing suspicious is happening for 1.5 s.
- At 100%: agent becomes Exposed, witness raises Alarm Level by 1.
- Suspicion is per-agent and server-owned. Client only displays it.

### 7.4 Trespassing
- Disguised agent enters a zone above their clearance → **Trespass grace: 3 s**. HUD shows a large orange "RESTRICTED AREA: 3…2…1" countdown.
- If they leave within grace: nothing happens.
- If grace expires while inside: Exposed.
- If a Security NPC or camera witnesses a trespasser during grace, grace is cut to 0 → instant Exposed.

### 7.5 Re-covering (getting back into disguise)
- An Exposed agent can apply a disguise (Section 6.4) once all of these are true:
  - **Combat lockout** has ended (7.6).
  - Not currently seen by a Security NPC or camera that is tracking them.
  - Not carrying the Package.
  - Standing in a zone at or below the disguise's clearance.
- HUD shows "COVER AVAILABLE" with the key prompt once conditions are met.

### 7.6 Combat lockout
- Starts or refreshes when the agent: fires, deals damage, takes damage from another agent, throws an offensive gadget, or uses an offensive ability.
- Duration: **5 s** since the last such event.

---

## 8. Spotting other agents (tells and counter-intel)

### 8.1 Natural tells (must exist in the game, do not "fix")
- Moving faster than NPCs, jumping, crouching, climbing.
- Not panicking during gunfire.
- Standing still at places NPCs never stop (intel terminals, vents, vault, extraction pads).
- Duplicate outfits.
- Walking into a tier the outfit shouldn't enter (a Guest in the kitchen briefly before grace runs out).
- Facing the camera direction a player is looking (NPC heads follow their walking direction; disguised player heads follow camera look). Implement: agent's neck rotation follows camera with a max 60° yaw offset. NPCs randomly look around too (every 4–10 s, 40° glance) so this is a soft tell, not a giveaway.

### 8.2 Things that must NOT be tells (implement carefully)
- No nametags, display names or health bars on anyone (set `Humanoid.DisplayDistanceType = None` on all characters and NPCs).
- Disable Roblox PlayerList, default Health bar and default chat bubbles over heads.
- Same rig type for players and NPCs (R15, identical scale ranges).
- Same footstep sounds for players and NPCs walking at the same speed.
- Same animation IDs for walk and idles.
- Players' local cosmetics (Roblox avatars) are never shown. Characters are built entirely from game assets.
- Collision behavior must match (players and NPCs both use the same collision group against each other).
- No hover highlight on players vs NPCs when aiming (the crosshair reacts the same way to any humanoid).

### 8.3 Agent Sense (built-in counter-intel)
Every agent has a passive, short-range sense:
- If an **enemy agent** is within **6 studs** and the local player looks directly at them for **1.5 s**, a faint white shimmer outlines that person for 1 s, only for the looker. Cooldown 8 s.
- Teammates are never shimmered (they already have team markers).

### 8.4 Hitmarkers reveal
- Shooting an NPC gives a grey hitmarker. Shooting a disguised agent gives a **red** hitmarker and reveals them (they are not Exposed by taking damage, but the attacker now knows). This is intentional: firing to "test" someone exposes yourself.

---

## 9. Intel

### 9.1 What Intel is
Intel is the currency that unlocks the Vault and gives your team an advantage. Intel is tracked **per team**.

### 9.2 Intel sources
| Source | How | Time | Cover |
|---|---|---|---|
| Intel Terminal (computer) | Hold Interact | 6 s (interruptible; progress saved per team for 20 s) | Suspicious if witnessed; required tier = terminal's zone tier |
| Intel Briefcase | Walk over and press Interact | 1 s | Quiet |
| Executive's Phone | Pickpocket an Executive NPC from behind within 3 studs | 2 s hold | Suspicious if witnessed |
| Server Rack (Tier 2/3 only) | Hold Interact | 10 s | Suspicious if witnessed; worth **2 Intel** |

- 10 Intel spawn points activate per match (Section 4.3). Each active point is usable **once per team** (so 4 teams can each take the same terminal). Briefcases are single pickup total.
- Intel locations are **not** shown on the map at start. Agents see Intel objects with a faint golden glint when within **25 studs** and in line of sight. A team's own HUD marks intel they've already taken from (grey checkmark).

### 9.3 Intel thresholds per team
| Team Intel | Reward |
|---|---|
| 1 | +100 Funds |
| 2 | Vault direction arrow on compass (only during Phase 2; exact location in Phase 3 is public anyway) |
| 3 | Team's **Vault hack speed +25%** |
| 4 | Team sees the **Package carrier through walls** once every 15 s for 1 s (Phase 4) |
| 5+ | +50 Funds per extra Intel |

### 9.4 Global unlock contribution
Every Intel any team collects adds 1 to `GlobalIntel`. When `GlobalIntel ≥ VaultUnlockThreshold`, Phase 3 begins.
- Threshold = `2 + (number of teams × 2)`. Example: 4 teams → 10. 8 solos → 18 (but capped at 14).

---

## 10. The Vault

### 10.1 Unlock
- At Phase 3 start: all players get a banner, the vault location is pinged on every HUD and minimap, and the Vault's exterior lights turn red.
- The Vault room's outer door opens. The inner vault door stays shut until hacked.

### 10.2 Hacking
- In front of the inner door is a **Hack Zone** (a 10 × 10 stud floor circle).
- Any agent standing in the zone (alive, not downed) contributes progress. Standing in the zone makes you **Exposed** immediately (Rule 7.2 #8).
- Base hack rate: **1% per second per team present** is NOT how it works. Rules:
  - Progress is **global** (one bar).
  - Progress rises at **1.25% per second** if one or more agents are in the zone, **regardless of how many** (prevents stacking).
  - If an agent from a team with 3+ Intel is in the zone, rate is **1.56% per second** (25% bonus).
  - Progress **pauses** (not decays) when nobody is in the zone.
  - Full hack from zero, no bonus: 80 s.
- Contesting: if agents from **2+ different teams** stand in the zone, progress pauses ("CONTESTED" on the bar).
- Hack progress bar shows at the top center for all players during Phase 3 with percent.

### 10.3 Vault opens
- At 100%: 4 s door-opening animation with alarm sound, then the Package spawns on a pedestal inside. Phase 4 begins.
- The vault room gets 2 extra Security NPCs that patrol for the rest of the match.

---

## 11. The Package

- A glowing briefcase. Only one exists per match.
- **Pickup:** press Interact within 4 studs, 1 s channel. Any agent can grab it. If two agents finish on the same server tick, the one whose request arrived first wins.
- **Carrier rules:**
  - Carrier is permanently Exposed while holding it and cannot disguise.
  - Carrier moves at **90%** of normal speed.
  - Carrier can use their primary weapon but **cannot** use their agent ability (they can use their gadget).
  - Carrier's location is pinged to **all enemies** on the minimap every **10 s** (pulse lasts 2 s).
  - Carrier can **pass** the Package to a teammate within 6 studs (hold Interact 0.5 s on the teammate). Can't throw it.
  - Carrier can **drop** it (key `X`).
- **When carrier is downed or eliminated:** Package drops at their position with physics (falls to floor).
- **Dropped package:** marked on all HUDs. If untouched for **30 s**, or if it falls out of the map / into a kill volume, it **teleports back to the Vault pedestal** and a banner announces it.
- The Package cannot enter vents or use ziplines (prompts for those are disabled for the carrier).

---

## 12. Extraction

### 12.1 Extraction sites
- 3 sites exist; all are **active** in Phase 4. Each has a terminal ("Call Extraction").
- Using the terminal requires the Package carrier **or** a teammate of the carrier within 10 studs of the carrier. Hold Interact 2 s.

### 12.2 Extraction call
- Calling extraction starts a **45 s** countdown at that site. The site's beacon flares (visible map-wide as a tall light pillar), and all enemies get a banner "EXTRACTION CALLED."
- Only one extraction can be active at a time per match. A new call by another team **cancels** the previous one only if the Package changed hands to that team.
- At 0 s, the helicopter/drone arrives and hovers 2 s, then the **Extraction Zone** (16 × 16 studs circle) lights up green.
- To win: the Package carrier must stand in the Extraction Zone and hold Interact for **3 s**, uninterrupted, while the zone is green. Taking damage does **not** interrupt; being downed does.
- If the Package leaves the zone or the carrier is downed: the extraction stays available at that site for **20 s** more, then expires. The carrier's team must call again (any site), with a fresh 45 s countdown.
- If the Package is held by a different team than the caller when the helicopter arrives, it doesn't matter: **whoever carries the Package into the green zone and completes the 3 s channel wins.**

### 12.3 Win
- On successful extraction: freeze all inputs, play 5 s extraction cinematic (helicopter lifts off with the team), "MISSION SUCCESS" for winners, "MISSION FAILED" for everyone else, go to Results.
- Winning team's eliminated members also count as winners.

---

## 13. Combat

### 13.1 Health and armor
- **Health: 100.** Regenerates **only** via pickups, Medic abilities or Supply Caches. No passive regen.
- **Armor: up to 3 plates, 25 HP each (75 max).** Agents spawn with 1 plate. Damage hits armor first. Plates are restored via pickups and Supply Caches.
- Headshots deal **1.5×** (marksman weapon 2×). Armor still absorbs headshots.
- Fall damage: falls over 30 studs deal `(fallDistance - 30) × 2` damage.

### 13.2 Weapons
Each agent has **one signature primary weapon** and **no secondary**. Weapons are hidden while disguised and drawn with **Draw** (right mouse / aim), which counts as "weapon drawn" for suspicion.

Generic weapon stats in config:
`Damage, FireRate (rpm), MagSize, ReserveAmmo, ReloadTime, Range (falloff start/end), Spread (hip/ADS), RecoilPattern, ProjectileType (hitscan/projectile)`.

### 13.3 Hit registration
- Client sends `FireRequest(origin, direction, timestamp, weaponId)` through a RemoteEvent.
- Server validates: player alive, not downed, weapon matches agent, fire-rate cooldown honored (±40 ms tolerance), ammo available, origin within 4 studs of server-known head position, direction is a unit vector.
- Server performs its own raycast with lag compensation (rewind targets up to 250 ms using a position history buffer sampled at 20 Hz).
- Server applies damage and fires hit feedback to shooter (hitmarker type) and damage feedback to victim (directional indicator).

### 13.4 Melee and takedowns
- Melee: **V**. 35 damage, 0.8 s cooldown, 4 stud range. Breaks cover.
- **Takedown:** from behind (target's back within 60° cone) on an agent, hold **V** for 1.2 s: deals 90 damage. Target can break out by moving more than 4 studs or if attacker takes damage.

### 13.5 Ammo
- Each weapon has reserve ammo (config). Ammo pickups refill 1 magazine. Supply Caches refill fully.

### 13.6 Friendly fire
Off. Explosions do not damage teammates. Explosions do damage yourself at 50%.

---

## 14. Downed, revive, elimination and rescue

### 14.1 Squads and Duos
- At 0 HP: agent becomes **Downed**. They are Exposed, can crawl at speed 4, can't shoot or use gadgets, and have a **bleed-out timer of 30 s**.
- **Revive:** teammate holds Interact on them for **4 s**. Revived with 30 HP, 0 armor. Reviving breaks the reviver's cover.
- **Execute:** enemy holds Interact on a downed agent for **2 s** → eliminated immediately.
- If all members of a team are downed or eliminated at the same time, all downed members die instantly (team wipe).
- **Eliminated** agents drop a **Agent Tag** (a small glowing badge) where they died. The tag stays for 90 s.

### 14.2 Rescue
- A living teammate can pick up the Agent Tag (Interact 1 s, quiet) and bring it to any **Supply Cache** to **Rescue** for **150 Funds** (Interact 3 s, breaks cover).
- Rescued agent re-enters at the nearest Insertion Point, disguised as a random Guest, with 100 HP, 1 armor plate, full ammo, ability on cooldown (half).
- Each player can be rescued **at most once per match**.
- Rescue is disabled during Overtime.

### 14.3 Solos
- No downed state. At 0 HP: eliminated. No rescue.
- Solos get **+1 armor plate at spawn** (2 total) to compensate.

### 14.4 Eliminated players
- Spectate a living teammate (cycle with left/right). If the whole team is eliminated, spectate whoever has the Package, then free-camera over the map; offer "Return to Lobby" button that does not penalize.

---

## 15. Agents (8 original agents)

Every agent has: **Primary weapon**, **Active Ability** (key `Q`), **Passive**, and a unique **Cover Perk** (how they interact with disguises).

### 15.1 VESPER, The Chameleon
- **Weapon:** Suppressed SMG. 14 dmg, 800 rpm, 30 mag, 120 reserve, 1.8 s reload, falloff 20→45 studs. *Suppressed: firing is still cover-breaking, but the Exposed "!" ping only shows to enemies within 25 studs instead of 60.*
- **Ability, Quick Change (CD 30 s):** instantly re-disguise into her stored disguise, **ignoring combat lockout**, but not while being tracked by security or carrying the Package.
- **Passive:** 2 Disguise Slots (switch between them with `G` tap/hold).
- **Cover Perk:** Scan time 0.6 s.

### 15.2 HALDEN, The Bulwark
- **Weapon:** Pump shotgun. 8 pellets × 11 dmg, 70 rpm, 6 shells, 30 reserve, reload 0.5 s per shell, falloff 6→18 studs.
- **Ability, Riot Wall (CD 35 s):** deploys a frontal energy shield (8 × 6 studs) carried in front of him, 400 HP, lasts 8 s or until broken. He can fire through it; enemies can't.
- **Passive:** Starts with 2 armor plates (3 in Solos).
- **Cover Perk:** none (trade-off for toughness).

### 15.3 JUNO, The Technician
- **Weapon:** Burst rifle. 3-round burst, 18 dmg per bullet, 0.35 s between bursts, 24 mag, 96 reserve, 2.0 s reload, falloff 30→70.
- **Ability, Sparrow Drone (CD 40 s):** pilots a small flying drone for up to 15 s (body stands idle and stays disguised; if the body takes damage, the drone ends). The drone can: hack Intel terminals remotely (same time), hack cameras (disables 30 s), and tag enemy agents it sees in True Form (revealed to Juno's team for 8 s). Drone has 40 HP and can be shot down.
- **Passive:** Hacks (terminals, server racks, cameras, doors) are 30% faster.
- **Cover Perk:** Using terminals while disguised generates 50% less suspicion.

### 15.4 SABLE, The Marksman
- **Weapon:** Bolt-action DMR. 75 dmg, headshot 2× (150), 45 rpm, 5 mag, 20 reserve, 2.6 s reload, no falloff, 4× scope.
- **Ability, Tracer Glass (CD 30 s):** for 6 s, Sable's scope highlights any **Exposed** agent and anyone with suspicion > 50% in a 45° cone, out to 150 studs.
- **Passive:** Fall damage halved; can mantle 25% faster.
- **Cover Perk:** Scoping while disguised does not raise suspicion until she fires.

### 15.5 OZZY, The Field Medic
- **Weapon:** Dual machine pistols. 11 dmg, 900 rpm, 40 mag (shared), 160 reserve, 2.2 s reload, falloff 15→35.
- **Ability, Mend Field (CD 45 s):** throws a canister creating a 10 stud healing zone for 8 s, +12 HP/s to allies (and himself). Heals in a Tier 0 zone do not expose him if he's disguised (it's a "first aid kit"); elsewhere, throwing it breaks cover.
- **Passive:** Revives take 2 s instead of 4.
- **Cover Perk:** When a teammate is Exposed nearby (within 20 studs), Ozzy can tap Disguise on them to push them into his stored disguise once per 60 s, ignoring combat lockout.

### 15.6 ROOK, The Trapper
- **Weapon:** Carbine. 20 dmg, 600 rpm, 25 mag, 100 reserve, 2.0 s reload, falloff 25→55.
- **Ability, Snitch Mine (CD 25 s, 2 charges):** places a nearly invisible mine on a surface. When an enemy agent (disguised or not) passes within 4 studs, it does not explode; it **reveals** them to Rook's team for 6 s and slows them 40% for 2 s. NPCs don't trigger it. Max 3 mines out.
- **Passive:** Sees enemy-placed devices (mines, drones, decoys) through walls within 30 studs.
- **Cover Perk:** Placing a mine while disguised doesn't break cover if not witnessed.

### 15.7 MIRAGE, The Illusionist
- **Weapon:** Heavy revolver. 45 dmg, 120 rpm, 6 mag, 30 reserve, 2.4 s reload, falloff 30→60.
- **Ability, Double (CD 30 s):** creates a hologram copy of herself (in her current look: disguised or True Form) that walks forward along her aim direction for 8 s, mimicking NPC behavior if disguised or sprinting if True Form. Has 1 HP, gives a red hitmarker when shot (a fake "this is an agent"), then pops.
- **Passive:** When Mirage is Exposed, the "!" ping to enemies appears at a location offset randomly 8–15 studs from her.
- **Cover Perk:** Re-disguising takes 0.3 s.

### 15.8 FERRO, The Breacher
- **Weapon:** Compact SMG. 16 dmg, 720 rpm, 28 mag, 112 reserve, 1.9 s reload, falloff 18→40.
- **Ability, Grapple Line (CD 18 s):** fires a grapple up to 40 studs; pulls Ferro to the point in 0.6 s. Breaks cover.
- **Passive:** Can open keycard doors without a keycard in 1.5 s (still breaks cover, as lockpicking).
- **Cover Perk:** Trespass grace is 6 s instead of 3.

### 15.9 Agent unlocks
- Starter (free): Vesper, Halden, Juno, Ozzy.
- Unlock with Credits (Section 20): Sable, Rook, Mirage, Ferro (2,500 Credits each).

### 15.10 Loadout Perks (pick 1)
| Perk | Effect |
|---|---|
| Light Feet | Sprint suspicion gain −40% |
| Deep Pockets | +1 extra ammo magazine and +50 starting Funds |
| Steady Hands | −20% recoil |
| Quick Study | Intel interactions −20% time |
| Iron Will | Bleed-out timer 45 s instead of 30 s (Squads/Duos only; no effect in Solos) |
| Cool Head | Combat lockout 3.5 s instead of 5 s |

---

## 16. Gadgets

### 16.1 Gadget pool (pick 1 before match; key `E`)
| Gadget | Charges | Effect | Cover |
|---|---|---|---|
| Smoke Canister | 2 | 8 stud radius smoke, 10 s, blocks line of sight for players, NPCs and cameras | Breaks cover |
| Flashbang | 2 | Blinds agents in LOS within 15 studs for up to 3 s (scaled by angle) | Breaks cover |
| Frag Grenade | 1 | 2.5 s fuse, 90 dmg center, falloff to 15 dmg at 8 studs | Breaks cover |
| Scanner Pulse | 2 | 20 stud radius pulse; shows each enemy agent as a silhouette for 2 s, including disguised ones. Pulse is visible to everyone in range. | Breaks cover |
| Jammer | 1 | 15 stud radius for 20 s: disables cameras, laser grids and enemy drones/mines inside it | Quiet if not witnessed |
| Keycard Clone | 1 | Instantly opens one keycard door silently | Quiet |
| Med Injector | 2 | Heals 40 HP over 3 s, can be used on self or touching teammate | Quiet in Tier 0, else breaks cover |

### 16.2 Gadget refills
Supply Caches restore 1 charge for 75 Funds.

---

## 17. Pickups, funds and supply caches

### 17.1 Funds (in-match money, resets every match)
- Start: 100 Funds per agent (personal, not shared).
- Sources: Funds pickup (+25 to +75), Intel thresholds (team-wide, each teammate gets it), downing an enemy (+50), eliminating (+25), hacking a camera (+10).

### 17.2 Pickups (`PickupSpawn`)
Each spawn picks one: Armor Plate (35%), Ammo Box (30%), Funds (25%), Med Kit 30 HP (10%). Respawn after 60 s if taken. Picking up is quiet. Pickups glint like intel when within 20 studs.

### 17.3 Supply Cache shop (opening the shop menu is quiet; buying breaks cover)
| Item | Cost |
|---|---|
| Armor Plate | 50 |
| Full ammo refill | 40 |
| Heal to full | 75 |
| Gadget charge | 75 |
| Ability cooldown reset | 100 |
| Rescue teammate (with Agent Tag) | 150 |
| Security Keycard (opens keycard doors, 3 uses) | 60 |

- One agent at a time per cache. 2 s purchase animation per item.
- Caches in higher tiers sell the same items but 20% cheaper (risk/reward).

---

## 18. Security systems

### 18.1 Cameras
- Each camera sweeps 90° back and forth over 6 s, with a 60° cone, 50 stud range. Visible cone on the floor as a faint light.
- Camera detects: Exposed agents in Tier 1+ zones, trespassers, and suspicious actions (counts as a witness).
- On detecting an Exposed agent or trespasser: camera locks on (stops sweeping), turns red, and after **1.5 s** of continuous view raises **Alarm Level +1** and alerts the 2 nearest Security NPCs to the agent's position.
- **Hacking a camera:** hold Interact on it within 6 studs for 2 s or use Juno's drone. Disabled for 30 s; can't be re-hacked for 30 s after it turns back on. Hacking a camera while disguised is suspicious if witnessed by another camera.
- **Shooting** a camera destroys it for 60 s (and it's a loud action).
- **Camera Room** (Tier 2): a terminal there shows a live feed (players can view 4 camera feeds) and lets the user disable all cameras for 20 s (CD 120 s, hold 5 s, breaks cover).

### 18.2 Laser grids
- Red horizontal beam arrays across certain doorways in Tier 2/3. Crossing them with a disguise of the matching tier or higher: nothing. Crossing them with lower clearance or in True Form: Alarm Level +1 and instant Exposed.
- Can be disabled by Jammer or by a nearby fuse box (hold Interact 3 s, quiet if not witnessed) for 30 s.

### 18.3 Keycard doors
- Shortcut doors between tiers. Opened by: Keycard (from cache), Keycard Clone gadget, Ferro's passive, or lockpick (any agent, hold 4 s, breaks cover).
- Door stays open 4 s, then closes.

### 18.4 Alarm levels (global, shared by all teams)
| Level | Name | Effect |
|---|---|---|
| 0 | Calm | Normal |
| 1 | Alert | Security NPCs move at walk speed 14, detection range +20% |
| 2 | Heightened | Plus: 2 extra Security NPCs spawn at random Tier 1 nodes |
| 3 | Lockdown | Plus: all keycard doors seal for 20 s, cameras sweep 50% faster, a siren plays, Security NPCs shoot Exposed agents in any tier |

- Alarm decays 1 level every 45 s with no new raise. Lockdown ends after 20 s → drops to Level 2.

### 18.5 Security NPC combat
- Security NPCs engage an agent who is: Exposed in Tier 1+ zone, or firing within 30 studs of them, or attacking them. (At Lockdown, any Exposed agent anywhere.)
- They shoot pistols: 8 dmg per shot, 1 shot per 0.8 s, 60% accuracy at 15 studs, dropping to 20% at 40 studs. They never headshot.
- They chase up to 40 studs from their post, then return.
- They **never** fire at disguised agents with suspicion < 100%.
- 50 HP each. Respawn 60 s after death at their post.

---

## 19. Endgame and overtime

- If the main timer reaches 0:00 and **nobody holds the Package**: match ends, Mission Failed for all.
- If someone holds the Package: **Overtime** begins.
  - Overtime lasts as long as the Package is being carried, up to a hard cap of **90 s**.
  - If the Package is dropped during Overtime, a **10 s** pickup grace runs; if no one grabs it, match ends with no winner.
  - Extraction countdown during Overtime is shortened to **20 s**.
  - Rescues disabled.
- Hard cap reached: match ends with no winner.

---

## 20. Scoring, XP and progression

### 20.1 Match XP
| Event | XP |
|---|---|
| Match played | 100 |
| Intel collected (personal) | 25 each |
| Vault hack participation (≥10 s in zone) | 50 |
| Package picked up | 50 |
| Package carried (per 10 s) | 10 |
| Enemy downed | 30 |
| Enemy eliminated | 20 |
| Teammate revived | 30 |
| Teammate rescued | 50 |
| Extraction win | 500 |
| Survived to end | 50 |

### 20.2 Account level
- XP to next level: `500 + 100 × level`, capped at 3,000 per level.
- Every level: 250 Credits. Every 5 levels: a cosmetic reward.

### 20.3 Credits (persistent currency, saved with DataStore)
- Earned: level-ups, win bonus (+200), daily first win (+300).
- Spent on: locked agents, agent skins (True Form only, never disguises), weapon skins, victory emotes, extraction cinematic flair.
- Optional Robux purchases may only be cosmetic. Nothing purchasable affects gameplay.

### 20.4 Saved data per player
`{ Level, XP, Credits, UnlockedAgents[], OwnedCosmetics[], EquippedCosmetics{agentId: {...}}, LastAgent, Stats{matches, wins, intel, downs, extractions}, Settings{...} }`. Save on leave, on match end, and every 120 s with `UpdateAsync` and retry/backoff. Use session locking to prevent duplication.

---

## 21. HUD and UI (every element)

### 21.1 In-match HUD
| Location | Element |
|---|---|
| Top center | Match timer (mm:ss), phase name below it. Turns red under 1:00. |
| Top center (Phase 3) | Vault hack bar with % and "CONTESTED" state |
| Top right | Team panel: each teammate's agent icon, health/armor bar, status (Covered/Exposed/Downed/Eliminated), Intel count for team |
| Top left | Global Intel progress ("Vault Lock: 7/10") during Phase 2 |
| Under timer | Alarm Level indicator (4 pips) |
| Center | Crosshair (only when weapon drawn), hitmarkers (grey NPC, red agent, skull for elimination) |
| Center-low | Interaction prompts with hold progress rings |
| Bottom center | Cover status: eye icon + state text + suspicion meter (fills left to right). Trespass countdown appears above it in orange. |
| Bottom left | Health number + bar, armor plates as 3 segments |
| Bottom right | Weapon icon, ammo `mag / reserve`, ability icon with cooldown sweep and key, gadget icon with charges, Funds amount |
| Left edge | Compass strip (N/E/S/W, vault arrow when unlocked, package arrow when pinged, extraction beacons) |
| Corner (toggle M) | Minimap: floor-by-floor, zone tint colors, teammates' positions, your position, pinged objectives |
| Right side | Event feed: anonymized ("An agent was eliminated", "Team Cyan extracted"); only your own team's actions use names. Enemy agents shown by agent name, never by Roblox username. |
| Above teammates | Team-color diamond + teammate's username (only visible to team) |

### 21.2 Screens
- Lobby queue screen, Agent Select (grid, loadout panel, team picks), Insertion briefing card, Death/spectate screen, Results screen (winner, your XP breakdown, team stats), Supply Cache shop, Camera Room feed, Settings (sensitivity, FOV 70–100, colorblind modes for zone colors, audio sliders, keybinds), Progression/Shop screen in main lobby.

### 21.3 Pings (team communication)
- Middle mouse / ping button: places a team-only marker. Types (context-based): "Look here," "Suspect" (on a person, shows a small marker above them for 8 s; the marker does NOT tell if they're actually an agent), "Intel," "Danger." Max 3 active per player.

### 21.4 Chat
- Disable global text chat during matches. Team chat only. Roblox voice chat: team-only if possible; otherwise disable in match.

---

## 22. Config tables

All tunables live in `ReplicatedStorage/Shared/GameConfig.lua` (read-only on clients). Example shape:

```lua
return {
  Match = {
    LobbySeconds = 30, InsertionSeconds = 8, MainTimerSeconds = 14*60,
    ForcedVaultUnlockElapsed = 6*60, OvertimeCap = 90, ResultsSeconds = 15,
  },
  Modes = {
    Squads = { TeamSize = 3, MaxTeams = 4, MinPlayers = 4 },
    Duos   = { TeamSize = 2, MaxTeams = 6, MinPlayers = 4 },
    Solos  = { TeamSize = 1, MaxTeams = 8, MinPlayers = 3 },
  },
  Cover = {
    ScanRange = 8, ScanTime = 1.2, DisguiseTime = 0.8,
    TrespassGrace = 3, CombatLockout = 5,
    SuspicionDecay = 10, SuspicionDecayDelay = 1.5,
    SuspicionGain = { Sprint = 25, Jump = 20, Crouch = 15, Terminal = 20,
                      WeaponDrawn = 40, NearBody = 10, VaultLinger = 15 },
    ExposedPingRadius = 60, AgentSenseRange = 6, AgentSenseTime = 1.5,
  },
  Speeds = { NPCWalk = 10, StaffWalk = 12, Sprint = 18, Crawl = 4, CarrierMult = 0.9 },
  Intel = { ActiveSpawns = 10, TerminalTime = 6, BriefcaseTime = 1,
            PickpocketTime = 2, ServerRackTime = 10, GlintRange = 25 },
  Vault = { BaseRate = 1.25, BonusMult = 1.25, OpenAnimTime = 4 },
  Package = { PickupTime = 1, ReturnTime = 30, PingInterval = 10, PassRange = 6 },
  Extraction = { CallTime = 2, Countdown = 45, OvertimeCountdown = 20,
                 ZoneSize = 16, ChannelTime = 3, LingerAfterFail = 20 },
  Combat = { MaxHP = 100, PlateHP = 25, MaxPlates = 3, StartPlates = 1,
             HeadshotMult = 1.5, BleedOut = 30, ReviveTime = 4, ExecuteTime = 2,
             LagCompMax = 0.25 },
  Alarm = { DecayInterval = 45, LockdownDuration = 20 },
  -- Agents, Weapons, Gadgets, Perks, Shop, XP tables follow the same pattern.
}
```

---

## 23. Audio

- **Ambient:** gala music (string quartet loops) in Tier 0, kitchen clatter in Tier 1, server hum in Tier 2, quiet ambience in Tier 3. Music crossfades by zone.
- **Crowd chatter** volume scales with nearby NPC count.
- **Footsteps:** identical sets for NPCs and agents at the same speed. Sprint has its own heavier set (a tell).
- **Disguise swap:** soft fabric swish, 10 stud audible radius.
- **Exposed:** a short sharp sting heard by the exposed player and everyone within 60 studs (positional).
- **Weapons:** each weapon has distinct fire, reload, empty click sounds; suppressed SMG is quieter (audible 25 studs vs default 120).
- **Phase stingers:** vault unlock, vault opened, package dropped/returned, extraction called, helicopter arrival, last 60 s ticking.
- **Alarm siren** at Lockdown.
- **Hitmarker sounds:** different for NPC vs agent vs headshot.

---

## 24. Controls

| Action | PC | Console (gamepad) | Mobile |
|---|---|---|---|
| Move | WASD | Left stick | Thumbstick |
| Sprint | Shift (hold) | L3 | Sprint button (toggle) |
| Jump | Space | A / Cross | Jump button |
| Crouch | C / Ctrl | B / Circle | Crouch button |
| Aim / Draw | Right mouse | LT | Aim button |
| Fire | Left mouse | RT | Fire button |
| Reload | R | X / Square | Reload button |
| Interact | E (hold) | X / Square (hold) | Context button |
| Scan | F (hold) | D-pad Up | Scan button |
| Disguise | G | D-pad Down | Disguise button |
| Ability | Q | LB | Ability button |
| Gadget | Z | RB | Gadget button |
| Melee / Takedown | V | R3 | Melee button |
| Blend wheel | B (hold) | D-pad Left (hold) | Emote button |
| Drop package | X | D-pad Right | Drop button (only when carrying) |
| Ping | Middle mouse | D-pad Right (when not carrying) | Ping button |
| Map | M | Select / Touchpad | Map icon |

Note: Gadget is Z (not E) on PC because E is Interact. Rebinding supported in Settings. Use `ContextActionService` with contextual mobile buttons that only appear when relevant.

---

## 25. Technical architecture and Roblox implementation

### 25.1 Folder layout
```
ServerScriptService/
  Server/ Main.server.lua
  Services/
    MatchService, TeamService, AgentService, LoadoutService,
    DisguiseService, CoverService (suspicion/trespass/exposure),
    ZoneService, NPCService, SecurityService (cameras/lasers/doors/alarm),
    IntelService, VaultService, PackageService, ExtractionService,
    CombatService, DownedService, GadgetService, AbilityService,
    PickupService, SupplyCacheService, ProgressionService, DataService
ReplicatedStorage/
  Shared/ GameConfig, Enums, Types, Util, AgentDefs, WeaponDefs, GadgetDefs
  Remotes/ (RemoteEvents/RemoteFunctions created by server at boot)
  Assets/ NPCOutfits/, AgentModels/, Weapons/, VFX/, Animations/
StarterPlayerScripts/
  Client/ Main.client.lua
  Controllers/
    InputController, CameraController, HUDController, InteractionController,
    WeaponController (client prediction, recoil, VFX), AbilityController,
    DisguiseController (local VFX only), NPCAnimationController,
    MinimapController, AudioController, SpectateController, SettingsController
ServerStorage/ MapTemplates/, NPCRigTemplates/
```
- Use a simple service/controller pattern (each a ModuleScript with `Init()` and `Start()`), started by the Main scripts. No third-party frameworks required.

### 25.2 Authority
- **Server owns:** cover state, suspicion, zone tier, disguise data, health, armor, ammo, Funds, cooldowns, Intel counts, vault progress, package holder, alarm level, NPC positions, all win logic.
- **Client owns:** input, camera, local VFX/SFX, prediction of own weapon fire (server corrects).
- Client sends **requests** only (`RequestScan(targetId)`, `RequestDisguise(slot)`, `RequestInteract(objectId)`, `FireRequest(...)`, `RequestAbility()`, `RequestGadget(aim)`, `RequestPurchase(itemId)`). Server validates every request (distance, line of sight, cooldown, state) and rejects silently or with a reason code.

### 25.3 Disguise implementation
- Players and NPCs use the **same custom R15 rig** built from game assets.
- An outfit is a data record: `{ OutfitId, Role, Tier, BodyColors, Shirt, Pants, Accessories[], Hair, Face, Scale }`. Applying a disguise = server applies the record to the player's character via a `HumanoidDescription` (or by swapping accessory/clothing instances directly if faster).
- Store each NPC's `OutfitId` server-side only. To clients, NPCs replicate visually but carry no attributes revealing role beyond what's visible.
- True Form: apply the agent's model outfit + cosmetic skin + weapon model.

### 25.4 NPC performance
- 70–90 NPCs with full Humanoids is too heavy. Use one of:
  - **Preferred:** NPC root parts anchored and moved by the server via `CFrame` along node paths at 10 Hz, with clients interpolating and playing animations locally with an `AnimationController` (no Humanoid). Player characters must still *look* identical: use the same rig mesh, clothing and animation IDs.
  - Or: Humanoids with `Humanoid:SetStateEnabled` stripped down and network ownership set to server.
- Paths are precomputed between `NPCNode`s at map load (A* over the node graph), not with `PathfindingService` per NPC per move.
- Stream NPC visuals with `StreamingEnabled` on.

### 25.5 Line of sight checks
- Use `workspace:Raycast` from witness eye position to agent head and torso (2 rays; either clear = seen). Run security witness checks at 5 Hz per witness, only for agents within range (use spatial culling).

### 25.6 Remotes list (minimum)
`PhaseChanged, TimerSync, CoverStateChanged, SuspicionUpdate, TrespassWarning, ExposedPing, IntelUpdate, GlobalIntelUpdate, VaultProgress, PackageState, ExtractionState, AlarmLevel, HitConfirm, DamageTaken, Downed, Revived, Eliminated, KillFeed, FundsUpdate, CooldownUpdate, Notification` (server→client) and `RequestScan, RequestDisguise, RequestInteract, RequestInteractCancel, FireRequest, ReloadRequest, RequestAbility, RequestGadget, RequestMelee, RequestPurchase, RequestPing, RequestDropPackage, RequestPassPackage, RequestEmote` (client→server). Rate-limit every client→server remote (e.g., 20/s, FireRequest bound to weapon rpm).

### 25.7 Server/match lifecycle
- One match per server. Lobby place → teleports party to match place with `TeleportService` and `MemoryStore`-based matchmaking queue. For MVP, a single place with an in-world lobby is fine.
- After Results, teleport everyone back to the lobby place (or reset the map and start a new match in the same server).

---

## 26. Anti-exploit and identity secrecy

- Never place attributes on characters like `IsAgent`, `TeamId`, `Disguise`. Keep them in server tables.
- Teammate markers are created **client-side** from a team roster sent only to that team.
- Do not replicate enemy cover/suspicion state to clients; send only the `ExposedPing` events to those in range.
- Known limitation: an exploiter can read `Players:GetPlayerFromCharacter()` to identify player characters. Mitigation: rename all character models and NPC models to random IDs, parent all humanoid models (players and NPCs) to the same folder, and accept that a perfect fix isn't possible on Roblox. Add server-side detection of impossible accuracy on disguised targets (e.g., shooting disguised agents through walls repeatedly) and flag for review.
- Validate movement speed server-side (allow 20% tolerance), check teleports, and kick on repeated violations.
- Never trust client timestamps for interaction timers; the server runs every hold-timer.

---

## 27. Edge cases (must all be handled)

1. Package carrier leaves the game → Package drops at their last server position.
2. Package falls into void / water / kill volume → returns to vault immediately.
3. Two players finish package pickup on the same tick → first-processed wins; the other gets "Too late."
4. Player disconnects while downed → counts as eliminated; drops Agent Tag.
5. Player rejoins mid-match → not allowed back into the same match (spectate only).
6. Agent disguised as an NPC that later dies → no effect on the agent.
7. Agent scans an NPC, NPC dies before disguise applied → stored disguise still valid.
8. Agent in Tier 2 disguise when Alarm hits Lockdown → still covered unless witnessed doing suspicious things.
9. Hack zone has a downed agent in it → downed agents don't count for progress or contesting.
10. Vault hack reaches 100% while contested → can't happen; contested pauses progress.
11. Extraction zone entered by the carrier from a different team than the caller → still wins (Rule 12.2).
12. Carrier passes Package to teammate who is in a vent → pass blocked (target must be eligible).
13. Ability used during Insertion phase → blocked; all input frozen except camera.
14. Agent Tag picked up by enemy → not possible; only teammates can interact with it (enemies see it as decor; hidden from enemy HUD).
15. All enemy teams eliminated, one team remains → match continues; they still have to extract (no automatic win).
16. Everyone eliminated → match ends, no winner.
17. Grenade kills NPCs and agents together → each NPC civilian death applies Rule 5.5 to the thrower.
18. Agent stands in a zone boundary → use the zone containing the root part center; if overlapping volumes, use the higher tier.
19. Mirage's hologram enters restricted zone → hologram is not a real agent; no security reaction, but it can trigger cameras' visual lock for show (no alarm raise).
20. Juno's body attacked while piloting → drone ends instantly, Juno gets control back.
21. Halden's Riot Wall blocks the Package carrier's path → walls have collision only with enemies; teammates pass through.
22. Reload during disguise swap → reload cancels.
23. Player tries to disguise inside a laser grid → blocked until outside.
24. Timer expires during extraction channel → channel can complete (overtime covers it since Package is held).
25. A team with 0 players left alive still holds Intel bonus → bonuses persist but are irrelevant.
26. Same-team scanning of a teammate → allowed (copies their disguise; useful for "matching").
27. Mobile players with low-end devices → reduce NPC render distance to 120 studs; NPCs beyond that still exist on server.

---

## 28. Build milestones and test checklist

### Milestone 1: Foundation
- Folder structure, GameConfig, Enums, service/controller loader.
- Graybox map with all 4 tiers, zone volumes, a few nodes, 1 insertion point per team.
- Custom R15 rig used for players and a test NPC. Hide default UI (player list, health, nametags).
- **Test:** player and NPC are visually indistinguishable when standing still.

### Milestone 2: NPCs
- Node graph, path precompute, NPC spawning by role, walk + activities + animations, panic reaction.
- **Test:** 74 NPCs run on a mid-range phone at stable framerate.

### Milestone 3: Disguise & cover
- Scan, disguise slots, clearance, ZoneService, trespass grace, suspicion meter with witnesses, Exposed state and pings, combat lockout, re-covering.
- **Test:** each item in tables 7.2 and 7.3 produces the correct result.

### Milestone 4: Combat
- One agent (Vesper) with weapon, hitreg with lag compensation, armor, downed/revive/execute, elimination, spectate.
- **Test:** red vs grey hitmarkers, firing breaks cover, downed crawl and bleed-out work.

### Milestone 5: Objective loop
- Intel sources and thresholds, global unlock, vault hack with contest, package rules, extraction call/countdown/channel, win/lose, overtime.
- **Test:** a full match can be won by one team from spawn to extraction.

### Milestone 6: Security
- Cameras, lasers, keycard doors, alarm levels, Security NPC combat, Camera Room.

### Milestone 7: Content
- All 8 agents, gadgets, perks, pickups, Supply Caches, Agent Tag rescue.

### Milestone 8: Polish & persistence
- Full HUD, minimap, audio, settings, DataService with session locking, XP, Credits, unlocks, cosmetics, matchmaking, mobile/console controls.

### Final acceptance checklist
- [ ] No way to tell a standing disguised player from an NPC using UI, sound or nametags.
- [ ] Every cover-breaking action in 7.2 instantly exposes.
- [ ] Suspicion only rises when a Security NPC or camera actually sees it.
- [ ] Vault progress pauses when contested and doesn't stack with more players.
- [ ] Package carrier always pings every 10 s and can never disguise.
- [ ] Only one team can ever win; no-winner endings work.
- [ ] All 27 edge cases handled.
- [ ] Every client request is validated on the server.
- [ ] All numbers come from GameConfig.
