# Step 8 questions: weapons and hit registration

Everything Step 8 needs decided before I build it. It covers spec Section 13, 7.2/7.6 (firing breaks Cover, combat
lockout), 8.4 (hitmarkers) and your earlier answers (OPEN_QUESTIONS E1, E2, E5; AGENTS_DRAFT; SPEC_CHANGES).
**Write your answer on the `Answer:` line and tell me to apply it.** Blank means "use the default".

- **Blocks** means I cannot build that part properly without an answer.
- **Default** means I will build it that way unless you say otherwise.

What Step 8 builds:
- **Health and armour** for agents (100 HP, plates of 25, 1 at spawn), damage to NPCs (they go down, as already built).
- **Weapons**: `WeaponDefs` for all 18, a first-person view model, firing with client prediction, reload, ammo, spread
  and recoil, aim-down-sights.
- **Hit registration on the server**: every shot validated (rate, ammo, origin, alive), its own raycast with lag
  compensation (targets rewound up to 250 ms), headshots, falloff.
- **Melee (V) and takedowns** from behind.
- **Feedback**: hitmarkers (grey for an NPC, red for an agent, a headshot variant), a directional damage indicator, and
  sounds from the Roblox library.
- **Cover**: firing, melee and takedowns break Cover; dealing or taking agent damage starts the combat lockout.

The BUILD_ORDER prompt still names "Vesper's SMG" and 8 weapons. Vesper is now **Guise**, and there are 18 weapons
(3 per agent), so I would start with **Guise's suppressed SMG** fully polished, then add the others.

---

## A. Loadout (Blocks)

### A1. Do you pick one of your agent's 3 weapons, or carry all 3?
- **Spec says:** one signature primary, no secondary.
- **Your answer (E1):** 3 unique weapon choices per agent.
- **Options:** (a) pick **one** of the 3 in agent select; it is your only weapon for the match (b) carry all 3 and switch
  with 1/2/3 (c) pick two of the 3 (primary and secondary).
- **Default:** (a). It keeps the spec's "one weapon" pace, and each agent has three playstyles.
- **Answer:**

### A2. The melee and odd weapons in the roster
Five of the 18 aren't ordinary guns: Guise's **garrote**, Parapet's **breaching hammer**, Lattice's **taser**, Suture's
**flare pistol** and Feint's **throwing knives**. With A1 (a), picking one means it is your only weapon.
- **Options:** (a) keep them as full weapon choices (stats in section C), each strong at its job (b) swap them for
  guns (c) make them extras everyone carries next to their pick.
- **Default:** (a), with the garrote as a stealth choice: a silent takedown that is faster than the normal one.
- **Answer:**

### A3. Choosing an agent and weapon before Step 10
Agent select is built in Step 10. To test Step 8 you need a way to pick.
- **Default:** in Studio only, F8 cycles your agent and F9 cycles their weapon. It does nothing in a live server, and
  Step 10's agent select replaces it.
- **Answer:**

---

## B. How firing feels (Default)

### B1. Drawing and hip fire
- **Spec says:** weapons are hidden while disguised; right mouse draws (aims), which is suspicious.
- **Options:** (a) right mouse draws and aims; left mouse only fires while drawn (b) left mouse also draws and fires at
  once (hip fire), which breaks Cover anyway.
- **Default:** (b). Hip fire is wider, aiming is tighter and zooms a little.
- **Answer:**

### B2. Who sees the gun
- **Default:** you see a first-person view model (arms and gun). Everyone else sees the gun in your character's hand
  only while it is drawn. A holstered weapon is invisible, so it never gives you away.
- **Answer:**

### B3. Aim assist (your answer E5: yes, on gamepad and touch)
- **Rule I must keep:** aim assist must treat every person the same. If it pulled only toward players, it would point
  them out.
- **Default:** on gamepad and touch only, aim slows down slightly over **any** person (NPC or player) and gently
  follows them while aiming. Off for mouse.
- **Answer:**

### B4. Headshots on NPCs (your answer E2: same multipliers for everyone)
Already decided. Hitmarkers still say what you hit: grey for an NPC, red for an agent (spec 8.4), each with a
headshot variant.

---

## C. The 18 weapons (Default: these numbers, all tunable in `WeaponDefs`)

Agents have 100 HP and start with 1 plate (125 to break; Parapet 150), up to 175 with 3 plates. Headshots are 1.5x
(marksman weapons 2x). Falloff is linear from the first range down to the minimum at the second. "Quiet" weapons can
be heard 25 studs away instead of 120.

| Agent | Weapon | Fire | Damage | Rate | Mag / reserve | Reload | Falloff | Notes |
|---|---|---|---|---|---|---|---|---|
| Guise | Suppressed SMG | auto | 15 | 800 rpm | 30 / 90 | 1.9 s | 30 to 70 studs, 60% | quiet |
| Guise | Silenced pistol | semi | 30 | 300 rpm | 12 / 48 | 1.4 s | 50 to 110, 70% | quiet |
| Guise | Garrote | melee | 40 swing | 0.8 s | none | | 4 studs | takedown from behind in 0.8 s (normal 1.2 s), 100 damage, silent |
| Parapet | Pump shotgun | pump | 8 pellets x 11 | 70 rpm | 6 / 24 | 0.5 s per shell | 10 to 30, 30% | |
| Parapet | Heavy SMG | auto | 19 | 650 rpm | 40 / 120 | 2.6 s | 25 to 60, 55% | heavier recoil |
| Parapet | Breaching hammer | melee | 70 swing | 1.1 s | none | | 6 studs | hold 1 s for a 100 damage swing |
| Lattice | Burst rifle | 3-round burst | 22 | 0.35 s between bursts | 24 / 96 | 2.2 s | 60 to 140, 70% | |
| Lattice | Compact PDW | auto | 13 | 950 rpm | 45 / 135 | 2.0 s | 25 to 55, 55% | fast handling |
| Lattice | Taser | single dart | 30 | 1 shot | 1 / 10 | 2.0 s | 25 studs max | hit slows the target 60% for 1.5 s |
| Reticle | Bolt-action DMR | bolt | 75 | 45 rpm | 5 / 20 | 2.8 s | none to 300 | 2x headshots, 3x scope |
| Reticle | Marksman pistol | semi | 45 | 150 rpm | 7 / 28 | 1.8 s | 80 to 160, 75% | 2x headshots |
| Reticle | Folding carbine | semi | 32 | 400 rpm | 20 / 80 | 2.0 s | 70 to 150, 70% | |
| Suture | Dual machine pistols | auto | 11 | 1100 rpm | 40 / 120 | 2.4 s | 20 to 45, 50% | wide hip spread |
| Suture | Medic shotgun | semi | 6 pellets x 10 | 90 rpm | 8 / 32 | 2.6 s | 8 to 25, 30% | |
| Suture | Flare pistol | arcing flare | 55 direct, 15 splash (6 studs) | 1 shot | 1 / 12 | 1.6 s | | the flare burns and lights the spot for 5 s |
| Feint | Heavy revolver | semi | 55 | 100 rpm | 6 / 30 | 2.4 s | 60 to 140, 70% | |
| Feint | Smoke-burst SMG | auto | 14 | 750 rpm | 32 / 96 | 2.0 s | 25 to 60, 55% | the last 5 rounds of a magazine leave a small smoke puff where they hit |
| Feint | Throwing knives | thrown | 45 | 0.6 s | 6 / none | | arcing | knives can be picked back up |

- **Answer:** (change any number, or say "fine")

---

## D. Art and pace (Blocks)

### D1. Weapon models
- **Your answer (E1):** I build the models in Blender; you upload them to Roblox.
- **Question:** 18 models is a lot of Blender work. How should Step 8 pace it?
- **Options:** (a) Guise's SMG gets its real Blender model in Step 8; the other 17 use simple shaped models made of
  parts (recognisable, not boxes) until an art pass (b) all 18 in Blender during Step 8 (slow) (c) parts-only models
  for all 18 now, and every Blender model in one art pass later.
- **Default:** (a).
- **Answer:**

### D2. Sounds
- **Your answer (G4):** Roblox library audio.
- **Default:** I pick library sounds for each weapon's fire, reload and empty click, and the hitmarkers, and list
  their IDs in `WeaponDefs` so you can swap them.
- **Answer:**

---

## E. Melee and takedowns (Default)

### E1. Melee and takedowns on NPCs
- **Spec says:** melee (V) does 35 in a 4 stud reach; a takedown from behind on an agent does 90.
- **Default:** both work on NPCs too (same numbers, so an NPC and a disguised agent react the same), and both break
  Cover.
- **Answer:**

### E2. Melee with a melee weapon picked
- **Default:** if your weapon is the garrote or the hammer, V uses its numbers instead of the default melee.
- **Answer:**

---

# Answers (2026-10-23, "grill me" session) and the decided design

These replace the defaults above wherever they differ.

## Decided
| Topic | Decision |
|---|---|
| Loadout (A1) | Pick **1 of the agent's 3** in agent select; it is your only weapon all match. |
| Odd weapons (A2) | The garrote, hammer, taser, flare pistol and throwing knives are **full weapon choices**. |
| Test pick (A3) | **F8 cycles agent, F9 cycles weapon**, Studio only; Step 10's agent select replaces it. |
| Drawing (B1) | **Left mouse draws and fires** (hip fire, breaks Cover); right mouse aims (tighter spread, small zoom). |
| Aim assist (B3) | Gamepad and touch only: slowdown over **any** person plus a gentle follow while aiming. Off for mouse. NPCs and players are treated identically. |
| Art (D1) | Guise's SMG gets its **real Blender model** in Step 8; the other 17 use shaped part models until an art pass. |
| Sounds (D2) | Roblox library sounds, IDs listed per weapon in `WeaponDefs`. |
| Melee (E1, E2) | Melee and takedowns work on NPCs with the same numbers; the garrote or hammer replaces V's default numbers. |
| Fight speed | **About 1.2 s** of sustained fire to down an agent with 1 plate (125 HP). Automatic weapons' damage is halved from the first table to match. |
| Ammo | **3 magazines in total** per weapon: the loaded one plus 2 spare (so reserve = 2 x magazine). Ammo caches refill one magazine. |
| Shotgun | The pump shotgun always takes **two shots**, even on an agent with no plates. |
| DMR headshot | One headshot (2x) downs an agent with **0 or 1 plate**; with 2 or more plates it survives. |
| Reticle | **No damage falloff on any of her weapons** (nobody else has that), and her numbers are trimmed about 10%. |

## What each player sees of a gun (client-side visuals only)
- **Disguised:** a first-person view where the gun is tucked across the chest with the barrel angled down.
- **Exposed:** the gun is up in a combat-ready pose, in the **right third of the screen**.
- **Other players** see a gun in your character's hands **only while you are Exposed**. A disguised player never shows
  one (so a gun never gives you away).
- Hip fire and drawing while disguised are cover-breaking (spec 7.2) and suspicious (7.3) as the spec says.

## Unique effects (built in Step 8)
| Weapon | Effect |
|---|---|
| Guise: Suppressed SMG | No muzzle flash or tracer; quiet (heard 25 studs). |
| Guise: Silenced pistol | The first shot fired while Covered deals +50% (ambush shot). |
| Guise: Garrote | A takedown from behind takes 0.8 s (normal 1.2 s), is silent, and nearby NPCs only panic if they see it. |
| Parapet: Pump shotgun | Stagger: a close hit with most pellets briefly slows the target and flinches their aim. |
| Parapet: Heavy SMG | Spin-up: fire rate climbs from 500 to 750 rpm over the first second of held fire. |
| Parapet: Breaching hammer | A charged swing moves the target **sideways, in the direction of the swing** (not backwards), a few studs. |
| Lattice: Burst rifle | Tracker round: landing a full burst on an agent marks them for Lattice only for 3 s. |
| Lattice: Compact PDW | Fastest draw and aim-in; no movement penalty while aiming. |
| Lattice: Taser | The slow (60%, 1.5 s) also stops the target's ability and gadgets for 3 s. |
| Reticle: Bolt-action DMR | Scope glint: enemies she is scoping see a glint at her position. |
| Reticle: Marksman pistol | Pierce: a shot passes through one person and hits the next at 60%. |
| Reticle: Folding carbine | Near-zero draw time. |
| Suture: Dual machine pistols | Akimbo aim: hip fire uses both pistols; aiming switches to one at half the rate but accurate. |
| Suture: Medic shotgun | No special effect. |
| Suture: Flare pistol | The flare burns where it lands and lights the area for 5 s; a direct hit leaves the target glowing for 4 s, visible to Suture's team. |
| Feint: Heavy revolver | Fan the hammer: held hip fire empties the cylinder fast with wide spread; aimed shots stay precise. |
| Feint: Smoke-burst SMG | The last 5 rounds of a magazine leave a small smoke puff where they hit. |
| Feint: Throwing knives | Silent (no gunshot noise, so no sound-based NPC panic or guard investigation); a headshot deals 2x; knives stay where they land and can be picked up. |

## Revised stats (starting point for playtests; everything lives in `WeaponDefs`)
Agents are 100 HP with 1 plate (125 HP) at spawn. Mag / reserve follows "3 magazines in total". Falloff is linear
between the two ranges down to the percentage shown; Reticle's weapons have none.

| Agent | Weapon | Fire | Damage | Rate | Mag / reserve | Reload | Falloff |
|---|---|---|---|---|---|---|---|
| Guise | Suppressed SMG | auto | 8 | 800 rpm | 30 / 60 | 1.9 s | 30 to 70 studs, 60% |
| Guise | Silenced pistol | semi | 22 | 300 rpm | 12 / 24 | 1.4 s | 50 to 110, 70% |
| Guise | Garrote | melee | 40 swing, takedown 100 | 0.8 s | none | | 4 studs |
| Parapet | Pump shotgun | pump | 8 pellets x 11 | 70 rpm | 6 / 12 | 0.5 s per shell | 10 to 30, 30% |
| Parapet | Heavy SMG | auto | 10 | 500 to 750 rpm | 40 / 80 | 2.6 s | 25 to 60, 55% |
| Parapet | Breaching hammer | melee | 70 swing, charged 100 | 1.1 s | none | | 6 studs |
| Lattice | Burst rifle | 3-round burst | 12 per round | 0.35 s between bursts | 24 / 48 | 2.2 s | 60 to 140, 70% |
| Lattice | Compact PDW | auto | 7 | 950 rpm | 45 / 90 | 2.0 s | 25 to 55, 55% |
| Lattice | Taser | single dart | 30 | 1 shot | 1 / 10 | 2.0 s | 25 studs max |
| Reticle | Bolt-action DMR | bolt | 68 | 45 rpm | 5 / 10 | 2.8 s | none, 300 studs |
| Reticle | Marksman pistol | semi | 40 | 150 rpm | 7 / 14 | 1.8 s | none |
| Reticle | Folding carbine | semi | 22 | 400 rpm | 20 / 40 | 2.0 s | none |
| Suture | Dual machine pistols | auto | 6 | 1100 rpm | 40 / 80 | 2.4 s | 20 to 45, 50% |
| Suture | Medic shotgun | semi | 6 pellets x 10 | 90 rpm | 8 / 16 | 2.6 s | 8 to 25, 30% |
| Suture | Flare pistol | arcing flare | 55 direct, 15 splash (6 studs) | 1 shot | 1 / 12 | 1.6 s | |
| Feint | Heavy revolver | semi | 55 | 100 rpm | 6 / 12 | 2.4 s | 60 to 140, 70% |
| Feint | Smoke-burst SMG | auto | 8 | 750 rpm | 32 / 64 | 2.0 s | 25 to 60, 55% |
| Feint | Throwing knives | thrown | 45 (90 headshot) | 0.6 s | 6 / none | | arcing |

## Left to decide while building


- **SPEC-QUESTION candidates:** the takedown speed-up (garrote), the "no falloff" rule for Reticle, and "3 magazines in
  total" (taken as the loaded magazine plus 2 spare) are all changes to spec 13; they go in SPEC_CHANGES.md at the end
  of the step.

## Feint silent pistol — delegated balance decision, 2026-10-24

The owner asked Codex to choose stats based on the kits. These replace the obsolete heavy-revolver rows above:

| Damage | Head | Rate | Mag / reserve | Reload | Falloff | Recovery after melee |
|---|---|---|---|---|---|---|
| 20 | 1.5x | 320 RPM, semi-auto | 12 / 24 | 1.5 s | 35–85 studs, down to 65% | 0.25 s |

Quiet, no tracer or flash, heard within 12 studs of a displaced sound origin 8–15 studs from the shooter. No ambush
damage bonus. Seven close body hits against 125 HP take 1.125 s from first to last shot at maximum cadence. Guise's
pistol retains 22 damage, longer effective range and its 1.5x ambush shot; Feint trades those for misdirection and
lower detectability. These are starting balance values for playtests, not measured match outcomes.
