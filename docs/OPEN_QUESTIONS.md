# Open questions: Cover Story

Decisions the spec does not make, or makes ambiguously. Each one has what the code does today, the options, and the
step that needs it. **Write your answer on the `Answer:` line and tell me to apply it.** Blank means "keep the default".

How to read the tags:
- **Blocks** means I cannot build that step properly without an answer.
- **Default** means I have already built it a certain way and will change it if you answer differently.
- **Later** means it can wait; it is listed so it is not forgotten.

---

## A. Decisions I already made for you (confirm or change)

These came up in Steps 1 to 5. The code works either way; they are the answers I picked.

### A1. Security and Executive NPC walk speed
- **Spec says:** Guest 10, Staff 12. Executives "slow walks", Security speed not given.
- **Default:** both walk at 10.
- **Options:** (a) keep 10 (b) Executive 8, Security 11 (c) your numbers.
- **Answer:** keep

### A2. Supply cache discount for higher tiers
- **Spec says:** "Caches in higher tiers sell the same items but 20% cheaper."
- **Default:** discount applies to caches in tier 1 and above.
- **Options:** (a) tier 1+ (b) tier 2+ only (c) discount grows by tier.
- **Answer:** Make the discount based on your teir of disguise rather than the floor their on

### A3. How different rigs may be in size
- **Spec says:** "identical scale ranges" for players and NPCs, no numbers.
- **Default:** every outfit is scaled within 5% of normal.
- **Options:** (a) 5% (b) none, everyone the same size (c) wider, up to 10%.
- **Answer:** allow for different sized models and animation styles across all security levels. Maintain all guards color coordination buut allow for this same size and animation difference. 

### A4. Do characters collide with each other?
- **Spec says:** players and NPCs use "the same collision group against each other".
- **Default:** one group that does not collide with itself, so everyone walks through everyone. Walls still block.
- **Options:** (a) pass through (b) bump into each other, which needs NPCs to be physically pushable and costs performance.
- **Answer:** just allow passing on all character models

### A5. Do NPCs open keycard shortcut doors?
- **Spec says:** "NPCs open doors automatically", but keycard doors are described only for players.
- **Default:** yes. NPCs of a high enough tier open them and they close 3 s after the last body leaves. This lets a player tailgate through.
- **Options:** (a) yes, tailgating is a feature (b) no, keycard doors stay shut for NPCs and normal doors are a separate thing (c) only some doors.
- **Answer:** keep the default, but if a player enters a room higher than their current disguise level, suspision rises with the guards in that room. 

### A6. Who panics and who gasps (spec 5.4)
- **Spec says:** gunfire and explosions: "Guests and Staff". Bodies: "Guests".
- **Default:** exactly that. Security and Executives do not panic or gasp; Staff do not gasp.
- **Options:** (a) as spec (b) Executives panic like Guests (c) Staff also gasp.
- **Answer:** Maintain default, but when gunfire or an explosion happens within earshot of a guard on that floor only, Or if the guard is standing near a staircase or balcony that otherwise connects to the floor through vision or audible sound clues, they run toward the commosion to invetigate, later returning to there regular area after 15 seconds if all noise has subsided.

### A7. Where a killed NPC is replaced
- **Spec says:** replacement "at a random far-away node" after 45 s.
- **Default:** a random free node at least 100 studs from the body.
- **Options:** (a) 100 studs (b) farthest from all players (c) your distance: ____
- **Answer:** Instead of npcs dying, make them pass out on the floor and be revived by nearby npcs of the same, or higher security level, 5 seconds after they return from thier startled state. 

### A8. Seats for NPCs who sit
- **Spec says:** nodes have a Sit activity, and the Blend wheel's Sit works "only near a seat".
- **Default:** NPCs sit on nothing, because the graybox has no chairs.
- **Options:** (a) accept until the art pass (b) add placeholder benches now and a `Seat` tag (c) remove Sit from NPC nodes for now.
- **Answer:** a

### A9. One face
- **Default:** every character has the same default face, because there are no face assets yet.
- **Options:** (a) keep (b) several faces as a plain texture set (c) wait for real art.
- **Answer:** b, we will make assets later

---

## B. Match flow and lobby (Steps 10 to 13, 22)

### B1. How is the game mode chosen? (Blocks Step 10)
- **Spec says:** three modes (Squads, Duos, Solos) with team sizes, but not who picks the mode or when.
- **Options:** (a) players vote in the lobby (b) queue per mode, like separate playlists (c) one mode per server, set by the server (d) Squads only for now.
- **Answer:** solo and duo via seperate queues on the lobby screen

### B2. One place or two? (Blocks Step 22)
- **Spec says:** a lobby place that teleports parties to a match place, but also "for MVP, a single place with an in-world lobby is fine".
- **Options:** (a) single place for launch, matchmaking later (b) two places from the start (needs TeleportService and MemoryStore queues).
- **Answer:** b

### B3. Starting a match with too few players (Blocks Step 10)
- **Spec says:** below the minimum, wait up to 60 s, then start if at least 2 teams exist; with one team, do not start.
- **Question:** what do players in a server with one team see, and for how long? Do they wait forever, or return to the queue?
- **Answer:** below the minimum wait up to 30 s, start if two teams exists, if only 1 team of two exists, start a match of solo instead. Make this clear somewhere in the character select screen.

### B4. Spawn points vs team count (Blocks Step 10)
- **Spec says:** 12 insertion points, "each team spawns at one point, players within 8 studs". Solos has up to 8 teams of 1.
- **Question:** with fewer than 12 teams, do unused points stay empty? Is the point chosen at random or in a fixed order?
- **Answer:** points should be chosen at random, for unnused spawn points just leave them empty for that match

### B5. Joining a match in progress (Later)
- **Spec says:** a player who rejoins mid-match may only spectate. Not said: can a brand new player join an in-progress server at all?
- **Options:** (a) never, servers close to new players once a match starts (b) spectate only (c) join as a late spawn before Phase 3.
- **Answer:** b 

### B6. What happens when the winning team is partly dead? (Later)
- **Spec says:** eliminated players on the winning team count as winners.
- **Question:** do they still get the "survived to end" XP? The spec lists it as separate.
- **Answer:** No, they do not get survived to end XP, only the living teammate. 

---

## C. Cover, suspicion and disguises (Steps 6 and 7)

### C1. Who can see you being suspicious? (Blocks Step 7)
- **Spec says:** only Security NPCs and cameras count as witnesses. Other agents do not raise suspicion; they only notice tells.
- **Question:** is that final? It means two players can sprint past each other in the open and nothing happens, which is intended per the spec, but it changes how often cover breaks.
- **Answer:** all npcs on the map should count as witnesses, however non-security npcs should raise suspicion much slower than a guard, with cameras raising it with a level somewhere between the two.

### C2. Scanning another player (Blocks Step 6)
- **Spec says:** scanning a disguised enemy copies the NPC disguise they wear, silently.
- **Question:** can a player be scanned while exposed (in true form)? What does the scanner get then?
- **Options:** (a) cannot scan exposed agents (b) copies nothing (c) copies the agent's last disguise.
- **Answer:** c, but set a timer from the time the player was scanned to the time the disguise activates to about 3 seconds as a base

### C3. Several disguise slots (Blocks Step 6)
- **Spec says:** one slot by default, two for Vesper. Scanning again overwrites.
- **Question:** when you have two slots, which one does a new scan overwrite?
- **Options:** (a) the one not currently worn (b) the oldest (c) you choose.
- **Answer:** c, give a visual cue to let the player know they have a choice to make about which one to overwrite

### C4. Suspicion vs trespass at the same time (Blocks Step 7)
- **Question:** while the trespass countdown (3 s) is running, does the suspicion meter keep filling or decaying? Do both can expose you, whichever comes first?
- **Answer:** make the trespass rule part of the suspicion rule, just make the player aware that they are being suspected BECAUSE of trespassing. 

### C5. Walk speed caps (Blocks Step 6)
- **Spec says:** a disguised agent is capped to the NPC role's walk speed, but sprint is allowed at 18 and is only suspicious when witnessed.
- **Question:** is the cap a hard limit when not sprinting, so a player in a Staff disguise moves at exactly 12?
- **Answer:** make the player's walking speed always match the npcs walking speed, and make sure the direction of movement always matches the external look of the character, rather than the direction the agent is actually looking on their screen. The real direction an agent is looking should only be apperent to others when out of disguise. 

---

## D. Intel, vault, package, extraction (Steps 11 to 13)

### D1. Intel thresholds when a team loses players (Later)
- **Spec says:** team bonuses at 1, 2, 3, 4, 5+ intel, tracked per team. Intel is per team, not per player.
- **Question:** does a team keep its intel bonuses if every member is eliminated? The spec says they persist but are irrelevant. Confirm.
- **Answer:** once a team is eliminated they should lose it, and it should go to the team that elimiated them, maybe as a loot drop on the ground once the last member of a team is eliminated

### D2. Vault unlock threshold for large lobbies (Blocks Step 11)
- **Spec says:** `2 + teams * 2`, capped at 14. With 4 teams that is 10 and with 8 solos it would be 18, capped.
- **Question:** is 14 the right cap when only 10 intel spawns are active per match? A cap above 10 means the vault can never unlock by intel alone and needs the 6:00 forced unlock.
- **Options:** (a) cap at the number of active spawns (b) raise active spawns for big lobbies (c) accept forced unlock as normal.
- **Answer:** the intel available on the map should far exceed this, and the max carried by a team should only be 10 for solos and 15 for duos, so make that math make sense and up the terminals where intel is gained more ubiquitous. 

### D3. Extraction when another team calls it (Blocks Step 13)
- **Spec says:** "A new call by another team cancels the previous one only if the Package changed hands to that team."
- **Question:** what if the package changed hands but the new team has not called yet, and the first countdown is running? Does the countdown continue for the old team's site while the new carrier walks there?
- **Answer:** the extraction called should be available to all teams on the map, regardless of who holds the package. When the package attached to a player that team should win when it is extracted. Multiple extraction points should be available.

### D4. Overtime and the extraction call (Blocks Step 13)
- **Spec says:** in overtime the countdown is 20 s.
- **Question:** if the carrier has not called extraction when the main timer ends, do they have to call it, with a 20 s countdown, inside the 90 s cap?
- **Answer:** Yes once the overtime timer starts. an extraction still needs to be called within the time limit, if not then they still lose.

### D5. Package carrier is downed in the extraction zone (Later)
- **Spec says:** being downed interrupts the channel. The package drops.
- **Question:** can a teammate pick up the dropped package and continue the same channel, or does it restart at 3 s?
- **Answer:** The timer should gradually decrease the longer the package isnt in someones possession, rather than restarting

---

## E. Combat, agents, gadgets (Steps 8, 9, 16, 17)

### E1. Weapon art and sound (Blocks Step 8)
- **Spec says:** eight original weapons with models and sounds, and an IP note that nothing may come from other games.
- **Question:** where do the assets come from? You have no art pipeline yet.
- **Options:** (a) blocky placeholder models and silent weapons until the art pass (b) Creator Store free models, accepting the licence risk (c) you or a commission make them (d) Blender models I build and you import.
- **Answer:** Blender models you build for all assets and I want 3 weapon unique weapon choices for each class, each variying in things like visuals, fire mode/rate, ammo count, damage ,etc. as you see fit

### E2. Headshot detection on NPCs (Blocks Step 8)
- **Spec says:** headshots do 1.5x. NPCs have 50 HP.
- **Question:** do NPCs take headshot multipliers too? It would let players tell NPCs from players by damage numbers.
- **Options:** (a) same multipliers for everyone (b) NPCs never take multipliers.
- **Answer:** a

### E3. Friendly fire on NPCs (Later)
- **Question:** killing a civilian costs the team 50 Funds and exposes the killer. If a teammate's explosion kills an NPC, who pays?
- **Answer:** the team, count it in the same capacity as if a gunshot hit them, players should be careful

### E4. Agent balance (Later)
- **Question:** do you want all eight agents at launch, or the four free ones first (Vesper, Halden, Juno, Ozzy) and the rest after the first public test? Building them one at a time is Step 16.
- **Answer:** all eight at launch

### E5. Mobile combat (Blocks Step 19)
- **Spec says:** mobile controls exist for every action.
- **Question:** is aim assist wanted on mobile and console? Without it, mobile players will lose firefights.
- **Answer:** yes 

---

## F. Economy, progression and monetisation (Steps 18, 21)

### F1. What can be bought with Robux? (Later)
- **Spec says:** "Optional Robux purchases may only be cosmetic. Nothing purchasable affects gameplay."
- **Question:** do you want Robux purchases at launch at all? If yes: Credits packs, skins, or a battle-pass style track.
- **Answer:** yes, all of it, figure out the economy that makes sense

### F2. Free agents and unlocks (Later)
- **Spec says:** four free agents, four unlocked with 2,500 Credits each.
- **Question:** how fast should players earn Credits? At 250 Credits per level and a level costing roughly 600 to 3,000 XP, the first locked agent takes about 10 levels. Is that the pace you want?
- **Answer:** Yes 

### F3. Do wins carry across servers? (Blocks Step 21)
- **Question:** stats (matches, wins, extractions) are saved. Do you want a public leaderboard? It needs `OrderedDataStore` and moderation of names.
- **Answer:** Yes

### F4. Data safety (Blocks Step 21)
- **Question:** what should happen if saving fails for a player? Options: keep their progress in the server and retry until they leave, or tell them and block the match reward.
- **Answer:** The former option

---

## G. Map, art, audio, performance (Steps 4 to 25)

### G1. How many maps at launch? (Later)
- **Spec says:** one map, "The Gala". The spec mentions three vault rooms and three extraction sites inside it.
- **Question:** is one map enough for the first public test, and is a second map planned after launch?
- **Answer:** Id say three maps on launch give the maps inside and outside leveling with somewhat intricate walkways to different areas of the map to really allow stealth gameplayh styles

### G2. Who builds the real map? (Blocks the art pass)
- **Question:** the graybox is generated by a script. Do you build the final Gala by hand in Studio, use Blender and import, or use Creator Store kits for the first pass?
- **Answer:** Use your own blender skills and prefabs someone commonly found on roblox games as parts of the map

### G3. Lighting direction (Later)
- **Question:** the graybox has a temporary ambient lift. What mood do you want: bright gala, dim moody lighting, or dark with spotlights? It changes how hard blending in is, because shadows hide players.
- **Answer:** The base lighting should be somewhat dimly lit/gala lights but should ultimately match the vibe of the map

### G4. Audio sourcing (Blocks Step 20)
- **Question:** the spec lists music, ambience, footsteps, weapons and stingers. Sounds from the Creator Store are free but licences vary. Do you want licensed library music, original music, or Roblox library audio for now?
- **Answer:** roblox library audio

### G5. Minimum device (Blocks Step 25)
- **Spec says:** 74 NPCs at 30 Hz-equivalent smoothness on mid-range mobile.
- **Question:** which phone or tablet should I treat as the target? On PC the crowd costs about 1 ms per frame on the client; mobile is several times slower. Knowing the target tells me when to start cutting NPC detail.
- **Answer:** Target mobile device parameters from roughly 5 years ago for the medium graphical setting, but for higher end systems like pcs and consoles you may use more graphical detailing

### G6. Voice chat (Later)
- **Spec says:** team-only voice "if possible", otherwise disabled in matches.
- **Question:** Roblox voice cannot be limited to a team without extra work. Disable it in matches, or build team voice?
- **Answer:** take out VC and leave team communication to chat bubbles only the team can see

---

## H. Rules, fairness and moderation (Steps 23 and 24)

### H1. What happens to a cheater? (Later)
- **Spec says:** kick on repeated movement violations; flag impossible accuracy on disguised targets for review.
- **Question:** who reviews flags? Do you want an automatic ban threshold, or logs only?
- **Answer:** automatic ban threshold

### H2. Reporting and chat (Later)
- **Spec says:** global chat is off; team chat only.
- **Question:** is team chat text safe enough for a mixed-age audience without filtering beyond Roblox's own? Do you want a report button?
- **Answer:** add a report button, but roblox filtering is fine. Only enable global chat when in the lobby or end-game screens. Players who are still alive cannot see this, nor can their teammates that have already died

### H3. Accessibility (Later)
- **Spec says:** colourblind modes for zone colours.
- **Question:** any more? For example a reduced-motion option, larger HUD text, or subtitles for audio cues like the exposed sting.
- **Answer:** add a hud size slider and subtitle options in the settings menu aswell, these should be accessible only through the menu when not in-game.

---

## I. Project and process

### I1. When do we publish for outside testing? (Later)
- **Question:** the roadmap's checkpoints are "2-player session" (after Step 7) and "full matches with friends" (after Step 13). Do you want the first outside test at the second checkpoint or earlier?
- **Answer:** second is fine

### I2. GitHub (Blocks nothing yet)
- **Question:** the new repo has no remote. Do you want it pushed to the old repository (replacing the previous project, with the old history kept as a branch), a new repository, or kept local for now?
- **Answer:**

### I3. Place file backups
- **Question:** the map lives only in `D:\Dead-Drop\CoverStory.rbxl`, which git ignores. Do you want a copy committed as a release asset at each milestone, or published to Roblox cloud as the backup?
- **Answer:** copy asset and roblox cloud for redundant backup should work

---

## How I will use your answers

1. You fill in answers (any subset) and tell me to apply them.
2. I list what each answer changes, in code or in `docs/cover-story-game-spec.md`, and tell you before touching `src/shared/`.
3. Changes go in as their own commit so they can be reverted.
4. Answered questions move to a "Decided" section at the bottom of this file so the list keeps shrinking.

---

## Decided (grill session, 2026-10-21)

Settled in follow-up questions. These override the `Answer:` lines above where they differ. Spec edits are proposed in
`docs/SPEC_CHANGES.md`; nothing in `src/shared/` has been changed for them yet.

| Ref | Decision |
|---|---|
| A2 | Cache discount follows the worn disguise tier, 10% per tier: Guest 0%, Staff 10%, Security 20%, Executive 30%. True Form gets none. |
| A3 / C2 | Sizes and animation sets may differ by tier. A scan copies everything (outfit, scale, face, animation set), so a disguised player is a structural twin of the scanned NPC. Guard colour coordination is kept. |
| A7 | NPCs are not killed. At 0 HP they go down under the same rules as a downed player (crawl, bleed-out, executable), so NPC and player bodies are indistinguishable. NPC-revives-NPC is dropped because players could never be NPC-revived. Replacement-after-45 s is replaced by this. |
| A6 | Guards investigate gunfire and explosions within 60 studs on the same floor, or within 40 studs of a stair or balcony open to it. They return to their area after 15 s of quiet. Values go in `GameConfig`. |
| B1 / B3 | Solo and Duo queues only (Squads dropped). Wait 30 s for a second team. A lone duo is asked whether to split into solos or keep waiting. |
| B2 | Two places (lobby plus match) using TeleportService and MemoryStore queues. |
| C1 | Every NPC and camera is a witness. Suspicion rate: Security 1.0, camera 0.6, other NPC 0.2. |
| C4 | Trespass is part of suspicion and only builds when witnessed. The HUD always shows when you are in a room above your clearance. A5: entering a room above your tier raises suspicion with the guards in it. |
| C5 | Walk speed equals the NPC role speed. Sprint (18) stays and is suspicious when witnessed. While disguised, facing follows movement, not the camera. |
| D1 | Eliminated team's Intel drops as loot for the eliminating team. |
| D2 | Vault threshold counts all teams combined. Carry cap 10 (solo) and 15 (duo). Intel terminals are made far more common than the threshold. |
| D3 / D5 | Extraction is a capture zone. The carrier calls it, there is a fixed delay before capture can start with a very large visual cue, then progress fills while the carrier is in the zone. An enemy in the zone freezes progress. Progress drains while the Package is not held. Several extraction points. Overtime: it must still be called within the 90 s. |
| E1 | Blender-built weapons, 3 unique per agent. Upload to Roblox is done by you. |
| E4 | Launch with 6 agents, 3 free and 3 unlockable, 3 weapons each (18 weapons). |
| F1 | Robux buys cosmetics plus an XP boost. No Credit packs. |
| F3 / F4 | Public leaderboard. On save failure keep progress in the server and retry. |
| G1 | One map at launch (The Gala), two more after. |
| H1 | Auto-kick on movement violations. Auto-ban only on hard signals (fire rate beyond cooldown, impossible hit position). Accuracy flags are logged only. |
| H2 | Team chat for living teams only. Fully eliminated teams get a spectator chat. Global chat only in the lobby and end screens. Report button added. |
| I2 | New private GitHub repo named `cover-story`. |

### Still open
- Weapon art: 18 weapons is a large Blender workload; pace to be set when Step 8 starts.
- Which 6 of the spec's 8 agents ship. Not chosen yet.
- Capture delay length, fill time and drain rate: placeholders go in `GameConfig` and will be flagged SPEC-QUESTION.
