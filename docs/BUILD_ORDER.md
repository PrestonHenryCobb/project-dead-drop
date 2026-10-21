# BUILD_ORDER.md: Cover Story

Do **one step per message**. Test each step in Studio before moving on. Each step lists the spec sections to read and a prompt you can paste into Claude Code.

> Tip: start each prompt with "Read CLAUDE.md and the listed spec sections first."

---

## Phase A: Foundation

### Step 1: Project scaffold
**Spec:** 25.1, 25.2, 22
**Prompt:** "Do Step 1. Set up the Rojo project, folder layout, Main server/client loaders, the Service/Controller Init/Start pattern, GameConfig (all values from the spec, Section 22 and every number elsewhere), Enums, Types, the Remotes list and auto-creation, a cleanup helper, and a remote rate-limiter. No gameplay yet."
**Done when:** Rojo syncs into Studio, play-test prints every service and controller starting with no errors.

### Step 2: Graybox map + zones
**Spec:** 4
**Prompt:** "Do Step 2. Build a graybox version of The Gala in code or as a Rojo model: 3 floors, all 4 tier zones with colored trim, ZoneVolume parts, and every tagged object from 4.3 as placeholder parts (correct counts). Write ZoneService that tracks each player's current tier at 4 Hz."
**Done when:** walking around prints your current tier correctly, including overlapping boundaries (higher tier wins).

### Step 3: Shared rig + hidden UI
**Spec:** 8.2, 25.3
**Prompt:** "Do Step 3. Make the custom R15 rig used by both players and NPCs, the OutfitDefs data format with 20+ outfits per role, and outfit application. Players spawn as a random Guest outfit. Disable player list, health bar, nametags, chat bubbles. Strip all Roblox avatar items."
**Done when:** a player and a test NPC wearing the same outfit look identical.

---

## Phase B: The crowd

### Step 4: NPC movement system
**Spec:** 5.1, 5.2, 25.4
**Prompt:** "Do Step 4. NPCService: precompute paths over the NPCNode graph, spawn NPCs by role with role tier limits, move them server-side cheaply, animate on clients. Walk speeds from config."
**Done when:** 74 NPCs walk around smoothly; check MicroProfiler and report server and client cost.

### Step 5: NPC activities + reactions
**Spec:** 5.3, 5.4, 5.5
**Prompt:** "Do Step 5. Node activities and idle animations, random head glances, door opening, panic reactions to gunfire/explosions/bodies (use a debug key to fire a test gunshot event), NPC death and replacement."
**Done when:** the crowd looks alive and panics correctly.

---

## Phase C: Social stealth (the core of the game)

### Step 6: Disguise system
**Spec:** 6
**Prompt:** "Do Step 6. Scan, disguise slots, apply disguise, insertion disguise, clearance, disguised movement limits, Blend emote wheel, neck follows camera."
**Done when:** you can scan any NPC and become them, and the Blend wheel works.

### Step 7: Cover, suspicion, trespass, exposure
**Spec:** 7, 8.3, 8.4
**Prompt:** "Do Step 7. CoverService with Covered/Suspicious/Exposed states, every action in 7.2 and 7.3, witness logic using Security NPCs (stationary is fine for now), trespass grace, combat lockout, re-covering, Exposed pings, Agent Sense. Add a temporary debug HUD showing state and suspicion."
**Done when:** every row of tables 7.2 and 7.3 behaves as written. Test with 2 players.

**Checkpoint:** play a 2-player session where you just try to find each other in the crowd. If this isn't fun yet, fix it before going further. Everything else builds on it.

---

## Phase D: Combat

### Step 8: Weapons + hitreg
**Spec:** 13
**Prompt:** "Do Step 8. WeaponDefs for all 8 weapons, client fire with prediction, server validation with lag compensation, damage, armor plates, headshots, falloff, reload, ammo, melee and takedowns, hitmarker types (grey NPC, red agent). Start with Vesper's SMG fully polished, then add the others."
**Done when:** 2 players can fight; firing breaks cover; hitmarkers are correct.

### Step 9: Downed, revive, elimination, spectate
**Spec:** 14
**Prompt:** "Do Step 9. Downed state, crawl, bleed-out, revive, execute, team wipe rule, Agent Tag drop, Solos rules, spectate."
**Done when:** tested with 3 players on 2 teams.

---

## Phase E: Match loop

### Step 10: Lobby, teams, match phases
**Spec:** 2, 3
**Prompt:** "Do Step 10. MatchService phase state machine, timers, modes, team assignment with parties, team colors and teammate markers (client-side only), agent select screen (placeholder art), insertion freeze and briefing, results screen."
**Done when:** a full empty match runs from lobby to results with the right timers.

### Step 11: Intel
**Spec:** 9
**Prompt:** "Do Step 11. IntelService: random active spawns, all 4 Intel sources, per-team usage, glint, team thresholds and rewards, global unlock counter."
**Done when:** collecting intel triggers Phase 3 at the right threshold.

### Step 12: Vault
**Spec:** 10
**Prompt:** "Do Step 12. Random vault from 3, reveal, hack zone with global progress, bonus rate, contest pause, open animation, extra guards."

### Step 13: Package + extraction + overtime
**Spec:** 11, 12, 19
**Prompt:** "Do Step 13. Package pickup, carrier rules, pass, drop, return timer, pings; extraction call, countdown, beacon, zone, channel, expiry; win/lose; overtime."
**Done when:** a full match can be won end to end.

**Checkpoint:** play full matches with friends. Tune numbers in GameConfig only.

---

## Phase F: Security

### Step 14: Cameras, lasers, doors, alarm
**Spec:** 18.1–18.4
**Prompt:** "Do Step 14. Cameras (sweep, cone, lock-on, hack, destroy), Camera Room, laser grids and fuse boxes, keycard doors and lockpicking, alarm levels with decay and Lockdown."

### Step 15: Security NPC combat
**Spec:** 18.5
**Prompt:** "Do Step 15. Make Security NPCs patrol, act as witnesses, engage by the rules, shoot with accuracy falloff, chase limit, respawn."

---

## Phase G: Content

### Step 16: Agents + abilities
**Spec:** 15
**Prompt:** "Do Step 16. All 8 agents: ability, passive, cover perk. Build them one at a time and give me a test plan for each."
(It's fine to split this into 16a to 16h.)

### Step 17: Gadgets + loadout perks
**Spec:** 16, 15.10

### Step 18: Funds, pickups, Supply Caches, Rescue
**Spec:** 17, 14.2

---

## Phase H: Polish and launch

### Step 19: Real HUD + minimap + pings + settings
**Spec:** 21, 24 (replace debug HUD; add mobile and console controls)

### Step 20: Audio
**Spec:** 23

### Step 21: Data + progression + shop
**Spec:** 20 (DataStore with session locking, XP, Credits, unlocks, cosmetics)

### Step 22: Matchmaking + lobby place
**Spec:** 25.7

### Step 23: Anti-exploit pass
**Spec:** 26 ("Audit every remote and system against Section 26 and CLAUDE.md rule 1. List and fix gaps.")

### Step 24: Edge case + acceptance pass
**Spec:** 27, 28 ("Go through all 27 edge cases and the final checklist. For each, point to the code that handles it or fix it.")

### Step 25: Performance pass
"Profile a full 12-player match with 74 NPCs on low graphics. Report costs, then optimize the top 5."
