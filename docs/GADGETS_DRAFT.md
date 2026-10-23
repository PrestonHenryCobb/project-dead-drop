# Sub-gadget pool (decided 2026-10-23)

Every agent keeps their own ability (`Q`) and carries **two different sub-gadgets** from this shared pool, picked in
agent select (SPEC_CHANGES, 16.1). Keys `2` and `3`, gamepad d-pad. Any two different gadgets can be picked: categories
don't limit the choice. Teammates may pick the same gadgets. The whole pool is free. Charges refill at Supply Caches for
intel (Funds were removed). All designs are our own. Built in Step 17.

**Design rules**
- **No gadget does an agent's job better than the agent.** Healing stays weaker than Suture's kit, the recon gadgets stay
  weaker than Glitch's drone, the Briefcase Shield is far weaker than Bastion's wall, and the Noise Maker stays weaker
  than Mirage's double.
- **No throwables that hurt or blind.** Smoke Canister, Flashbang and Frag Grenade are removed from the spec's pool.
  Grapple Line is also cut: it overlaps the ziplines, gondola and vents, so the Spring Pad is the only vertical gadget.
- **Identity secrecy (CLAUDE.md rule 3).** A deployed gadget never shows whose it is or which team owns it, and no gadget
  effect points back to its user.
- **Counterplay.** Every deployable (Spring Pad, Bug Cam, Tripwire, Noise Maker) can be shot or meleed, and the Jammer
  disables enemy deployables inside it. Anyone can use a Spring Pad, enemies included.

**Cover levels**
- **Quiet:** never affects your Cover.
- **Discreet:** fine unless a Security NPC, a camera or an enemy agent sees you use it. If one does, it counts as a
  cover-breaking action (spec 7.3).
- **Breaks Cover:** always breaks it.

## Four categories of three

In agent select and on the HUD, each category has its own **card shape and accent colour**. The colours are kept to
gadget UI and never used in the world, so they can't be confused with tier colours. The shape does most of the
work, and the colours get tuned at the Step 19 mock-up.

| Category | Job | Shape | Accent |
|---|---|---|---|
| Recon | See | Circle | Cyan |
| Infiltration | Get in | Diamond | Royal blue |
| Evasion | Get away | Chevron | Pink |
| Support | Stay alive | Rounded square | Coral |

Numbers are starting values. They will live in `GameConfig.Gadgets`.

### Recon: see
| Gadget | Charges | Effect | Cover |
|---|---|---|---|
| **Scanner Pulse** | 2 | A 20 stud pulse shows enemy agents as silhouettes for 2 s, including disguised ones. There is no visible wave or source. Agents caught in it get a subtle "you've been scanned" warning that doesn't say where it came from. | Discreet |
| **Bug Cam** | 2 | A sticky camera, viewable with a key, that lasts 60 s. Agents who break Cover in its view are tagged for your team for 4 s. 1 HP. | Discreet |
| **Tripwire** | 2 | A thin laser across a doorway for 90 s. An enemy agent who crosses it is pinged to your team for 3 s and slowed by 30% for 2 s. NPCs and teammates pass through. Only the victim is revealed, never the owner. | Discreet |

### Infiltration: get in
| Gadget | Charges | Effect | Cover |
|---|---|---|---|
| **Long Lens** | 3 uses | Hack something in line of sight up to 30 studs away (an intel station, camera, door or vault terminal) at 1.5× the normal hack time. | Discreet, plus the tier-door rule |
| **Keycard Clone** | 1 | Opens one keycard door, or one tier door with no intel cost. Opening a tier door above your disguise's tier still follows the tier-door rule. | Discreet |
| **Jammer** | 1 | For 20 s in a 15 stud radius, cameras, laser grids and enemy deployables are disabled. | Discreet |

### Evasion: get away
| Gadget | Charges | Effect | Cover |
|---|---|---|---|
| **Spring Pad** | 2 | A flat pad. Anyone who steps on it is launched about 25 studs up and forward. It lasts 30 s or 6 launches. | Placing: Discreet. Being launched: Breaks |
| **Noise Maker** | 2 | Sticky. After 3 s it plays a loud alarm-like sound for 6 s. Security NPCs within 30 studs walk over to investigate, and other NPCs turn to look. It doesn't point to whoever threw it. | Discreet |
| **Disguise Kit** | 1 | Instantly re-disguise as a **Guest** without scanning anyone. You can't use it while tracked by Security, while in combat lockout, or while carrying the Package. | Discreet |

### Support: stay alive
| Gadget | Charges | Effect | Cover |
|---|---|---|---|
| **Med Injector** | 1 | Heals 35 HP over 4 s, self only. Stops if you take damage. | Quiet in Tier 0, Discreet elsewhere |
| **Plate Pack** | 2 | Restore 1 armour plate (25) to yourself, or to a teammate you're touching. Takes 1.5 s, and you can't shoot meanwhile. No HP. | Quiet in Tier 0, Discreet elsewhere |
| **Briefcase Shield** | 1 | Snap open an armoured briefcase and hold it in front of you while you walk. 80 HP, covers head and chest, lasts up to 5 s. You move at 70% speed and can't shoot or sprint while holding it. It's for crossing an open gap or reaching a downed teammate. Bastion's Riot Wall is 400 HP, 8 × 6 studs, and lets him fire. | Breaks |

## Healing balance against Suture (approved)
| Source | Total heal | Notes |
|---|---|---|
| Suture's Mend Field | Up to 96 HP per ally, area, every 45 s | Plus Triage regen and 2 s revives |
| Med Injector | 35 HP, self, once per refill | Stops if you take damage |
| Plate Pack | 25 armour × 2, no HP | Doesn't compete with healing |
| Food | Small (Step 18) | Free, rare in guarded areas |
| Wall health station | Bought with intel (Step 18) | Fixed locations |

## Knock-on effects to handle in Step 17
- Mirage's "smoke-burst SMG" and the spec text that names smoke, flash or frag (7.3 and the alarm rules) need rewording
  once the grenades are gone.
- Glitch's drone must stay clearly better than Long Lens plus Bug Cam. Recheck this when numbers are tuned.
