# Style and feel questions: Cover Story

Decisions about how the game looks, sounds and feels. The rules in `docs/OPEN_QUESTIONS.md` are about what the game
does; these are about what it is like to play. **Write your answer on the `Answer:` line and tell me to apply it.**
Blank means "use the default".

How to read the tags:
- **Blocks** means I cannot build that step properly without an answer.
- **Default** means I will build it that way unless you say otherwise.
- **Later** means it can wait until the art or polish pass.

---

## A. Camera and controls (Blocks Steps 6 to 8)

### A1. Camera view
- **Why it matters:** the disguise rule (your C5 answer) makes a disguised body face where it moves, not where the
  player looks. That rule feels very different in first person and third person, and so does aiming in Step 8.
- **Options:** (a) third person over the shoulder, always (b) first person, always (c) third person while disguised
  and first person when aiming or exposed (d) the player chooses in settings.
- **Default:** (a), because the player can see their own disguised body and the tell is easier to understand.
- **Answer:** b 

### A2. What does the player see of their own facing while disguised?
- **Question:** the camera can look anywhere but the body only turns the way you walk. How does the player know where
  their body is facing?
- **Options:** (a) nothing special, the player just sees the body (b) a faint arrow or cone on the ground (c) a small
  icon on the HUD showing "body facing" versus "camera facing".
- **Default:** (a) in third person, (c) if you pick first person.
- **Answer:** c

### A3. Moving the camera while standing still in a disguise
- **Question:** should looking around be free when the player is not moving? Real NPCs stand and glance now and then.
- **Options:** (a) free look, body does not turn (b) body turns slowly to follow the camera, like an NPC glancing
  (c) the body only turns when you hold a key.
- **Default:** (b).
- **Answer:** b

### A4. Default keys
- **Spec says:** Scan `F`, Disguise `G`, Blend wheel `B` (hold).
- **Question:** keep these, or does anything clash with how you want to play?
- **Answer:** all good

---

## B. Tone and atmosphere (Blocks Steps 6 and 7 for the HUD text; the rest is Later)

### B1. How serious is the game?
- **Options:** (a) tense spy thriller, quiet and low-key (b) glamorous and stylish, like a heist film (c) playful and
  a bit silly, big expressions and funny emotes (d) a mix: serious play, light cosmetics.
- **Why it matters:** the wording of every message ("EXPOSED", "Suspicious"), the emote wheel and the outfits.
- **Default:** (b).
- **Answer:** a mix of b and a but leaning more into b

### B2. Violence and presentation
- **Question:** Roblox's audience is mixed-age. How strong should hits and downed players look?
- **Options:** (a) no blood, characters fall face down and fade (b) small impact flashes only (c) your own limits: ____
- **Default:** (a), which also fits the downed-NPC body I just built.
- **Answer:** small impact flashes a but keep the caharcters falling face down and fading

### B3. The Gala setting
- **Question:** what kind of party is it? This sets outfits, props and music.
- **Options:** (a) black-tie art gallery (b) rooftop cocktail party in a skyscraper (c) masquerade ball (d) your idea: ____
- **Note:** the graybox already has a ballroom, galleries and a penthouse, which fits (a) best.
- **Default:** (a).
- **Answer:** How about a mix of all of these, heavily including a roofop piece to the map, dont just make the map layouts boring and linear 

---

## C. Cover and suspicion feel (Blocks Step 7)

### C1. How does the player learn they are being watched?
- **Spec says:** a suspicion meter fills left to right at the bottom of the screen.
- **Question:** is a meter alone enough, or should there be warning cues on top of it?
- **Options:** (a) meter only (b) meter plus the watcher gets a small marker on screen (c) meter plus a heartbeat sound
  that speeds up (d) all of it.
- **Why it matters:** the marker would show where the danger is but also tells the player who counts as a witness.
- **Default:** (c).
- **Answer:** d

### C2. How loud is being Exposed?
- **Spec says:** an "exposed sting" sound, pings for enemies.
- **Question:** how dramatic should the moment cover breaks be for the player and for everyone who sees it?
- **Options:** (a) loud and obvious, the whole screen reacts (b) a clear sound and a flash on the HUD only
  (c) subtle for the player, but loud pings for enemies.
- **Default:** (b).
- **Answer:** a, obvious for the player and enemies

### C3. Match pacing
- **Question:** what should a good five minutes feel like early in a match?
- **Options:** (a) quiet: players hide, scan and sneak, and nobody fights for a while (b) tense: small chances to be
  spotted and shot from the start (c) split: stealth first, fights only after the vault opens.
- **Why it matters:** it decides how loud the early game is, how many guards patrol, and how soon players are
  pushed toward each other.
- **Default:** (c), which is how the phases in the spec already work.
- **Answer:** B, no protection needs to be added since the suspence is already there

### C4. Telling teammates apart in the crowd
- **Spec says:** teammate markers are built on the client from a roster sent only to that team.
- **Question:** how visible should the marker be?
- **Options:** (a) small outline only when looking directly at a teammate (b) a faint icon above the head at any
  distance (c) an icon that fades out the further away they are.
- **Default:** (c).
- **Answer:** C

---

## D. Look and sound (Later)

### D1. Overall art style
- **Options:** (a) clean, flat colours and simple shapes (b) realistic materials and lighting (c) stylised, with
  strong colour per zone (d) your reference: ____
- **Note:** the zones already use colours (spec Section 4), so (c) is the easiest to read at a glance.
- **Default:** (c).
- **Answer:** b, but keep colored zones obvious by things like rugs,suble color coded pieces in the room rather than the entire room being a flat color, keep it semi real, but keep the art style simple enough to run on all platforms. I want the game to run in a way that make character actions look deliberately choppy compared to the environment. Make suble objects wave around such as flag and npc interactions move choppily on purpose.

### D2. HUD style
- **Options:** (a) minimal, almost no HUD, with icons only when needed (b) a classic shooter HUD (c) a spy-gadget look,
  like an old briefing screen.
- **Default:** (a), because the less there is on screen, the harder it is to tell players apart by what they look at.
- **Answer:** make the hud minimal, but keep things like small icons floating on screen for the player to understand ammo count, abilities, etc. The font of words on screen should use a classic roblox that seems pixelized but bold and easy to read that blend with the screen. The HUD should move with actions on the screen, such as when jumping, the HUD should appear to float in the opposite direction.

### D3. Music mood
- **Question:** you chose Roblox library audio. What mood should I search for?
- **Options:** (a) jazz and lounge (b) tense orchestral (c) electronic, with a beat that rises as alarm increases
  (d) a different style: ____
- **Default:** (c).
- **Answer:** a mix of A and c

### D4. Footsteps and voices
- **Question:** NPCs and disguised players must sound the same. Should NPCs make small sounds (murmur, clinking glasses)?
- **Options:** (a) footsteps only (b) footsteps plus soft crowd murmur from the whole map (c) per-NPC sounds
  (more noticeable, but players must also make them).
- **Default:** (b).
- **Answer:** b

---

## E. Onboarding (Later, needed before Step 21)

### E1. How do new players learn the game?
- **Options:** (a) a short written tutorial screen before the first match (b) a solo practice room with NPCs and no
  enemies (c) tips that appear on screen during the first few matches (d) all of these.
- **Default:** (c), because it costs the least.
- **Answer:** c

### E2. What do players see between matches?
- **Question:** the lobby is its own place. What should it show?
- **Options:** (a) a menu only (b) a small walkable lobby where players can see each other's cosmetics
  (c) a menu, with the walkable lobby added after launch.
- **Default:** (c).
- **Answer:** c 

---

## How I will use your answers

1. Fill in any subset and tell me to apply it.
2. Camera and cover-feel answers (A, C) are used directly in Steps 6 and 7. I will say which file each one changes.
3. Tone, art and audio answers (B, D, E) are recorded in the "Decided" section of this file and shape later steps.
4. Answered items move to a "Decided" section at the bottom so the list keeps shrinking.

---

## Decided (2026-10-21)

| Ref | Decision |
|---|---|
| A1 | First person, always. When a disguised player fires, the body turns to the camera and cover breaks (spec rule). A small HUD portrait shows the disguise being worn. |
| A2 | A small HUD icon shows body facing versus camera facing. |
| A3 | Standing still: the body turns slowly to follow the camera, like an NPC glancing. |
| A4 | Keys stay as in the spec: Scan `F`, Disguise `G`, Blend wheel `B` (hold). |
| B1 | Glamorous heist-film tone, with some of the quiet spy-thriller feel. |
| B2 | Small impact flashes only. Characters fall face down and fade. No blood. |
| B3 | The Gala mixes gallery, cocktail party and masquerade, with a large rooftop section. Layouts must not be boring or linear. |
| C1 | All cues: suspicion meter, a marker on the watcher, and a heartbeat that speeds up. |
| C2 | Loud and obvious for the player. Enemies within about 60 studs get the loud version too; farther enemies get only the map ping. |
| C3 | Tense from the start. Weapons are locked for about 15 s after spawn. |
| C4 | Teammate marker is an icon that fades out with distance. |
| D1 | Semi-realistic art, simple enough for all platforms. Zones are marked by rugs and small colour-coded pieces, not flat-coloured rooms. Characters animate choppily on purpose (poses step at about 12 per second, on every character equally, players and NPCs). Positions stay smooth. Flags and small props wave gently. |
| D2 | Minimal HUD with small floating icons (ammo, abilities). A bold, pixel-style Roblox font. The HUD sways opposite to movement, for example when jumping. |
| D3 | Music mixes jazz/lounge with electronic that builds as alarm rises. Roblox library audio. |
| D4 | Footsteps plus soft crowd murmur across the map. |
| E1 | Tips on screen during the first few matches. |
| E2 | Menu lobby at launch. A walkable lobby comes later. |

### Decided in the second round

| Ref | Decision |
|---|---|
| Masks | Characters wear masks only in the masquerade area, and only on the Gala. A mask-off animation exists. |
| C1 marker | A marker appears only on a watcher that is currently adding to your suspicion, and disappears when they stop. Off-screen watchers get an edge arrow. |
| D2 motion | A "reduce HUD motion" option in the lobby settings, with the sway on by default. This replaces the earlier rule (OPEN_QUESTIONS H3) that settings are changed only outside matches: an in-game settings system is added. |
| B3 rooftop | The rooftop is a Tier 0 public cocktail party. It is crowded and open, and Exposed players there are visible from far away. |

### Decided in the third round

| Ref | Decision |
|---|---|
| Mask area | Masks are worn in the masquerade area and on the rooftop, on the Gala only. |
| Mask-off | Scripted unmasking for everyone: at set moments, every character in a masked area takes the mask off at once. Players cannot take it off on their own, so there is no tell. |
| Mask scan | A scan copies the mask with the outfit. |
| In-game menu | Settings can be opened any time as an overlay. The match keeps running (NPCs, suspicion, timers). Input to the character is paused while the menu is open. |
| Rooftop | Open but balanced: no sniper nests, no extra sight-line limits. |

### Decided in the fourth round (replaces the open mask items below)

| Ref | Decision |
|---|---|
| Mask rule | A mask belongs to the area, not the character. Everyone inside a masked area wears one whatever they scanned; entering adds it, leaving removes it. A scan copies only the outfit underneath. |
| Mask timing | Masks are on from the start. One scripted unmasking at a fixed time (5:00 into the match), after which masks stay off. SPEC-QUESTION: 5:00 is taken as time elapsed, not time remaining. |
| Unmasking and cover | Nobody gains suspicion for about 3 s while the animation plays. |
| Menu and cover | Opening the in-game menu is like standing still. Suspicion keeps building if a witness is watching. |

### Superseded (kept for the record)
- SPEC-QUESTION: scripted unmasking and "mask copied with the outfit" do not fully fit together. If a player scans a masked NPC and walks into an unmasked area, are they masked there? Proposed rule: a mask is a state of the area, not the character. Everyone inside a masked area wears one whatever they scanned, and the scan copies only the outfit underneath. Say if you want it otherwise.
- How often and for how long are the masks on? For example, masks on at the start, one scripted unmasking at a fixed time, then masks stay off for the rest of the match.

---

## Decided (2026-10-23): movement and animation feel ("Dingus" reference)

Taken from your notes on the movement of Dingus. You asked for the general feel, not to override our movement, and for it
to apply to all human-controlled characters and NPCs.

| Idea in your notes | What was built |
|---|---|
| Low frame rate, about 8 FPS, with limbs snapping between poses | Every character (players and NPCs) shows its pose about 8 times a second (`GameConfig.Animation.StepHz`). Only the pose is held; position, speed and facing stay smooth. Characters further than 120 studs from the camera animate normally, since the steps cannot be seen there. |
| Zero-inertia stopping | NPCs already stop exactly where their route ends. Players are unchanged. |
| Linear trajectories | NPC routes are straight segments between nodes already. |
| 4 to 5 s freeze at a destination | Not applied. NPCs pause 6 to 20 s at a node (spec 5.2). Say if you want 4 to 5 s. |
| Instant 180 degree turns | Not applied. NPCs and disguised players both turn at up to 270 degrees a second (spec 5.2). Faster turning is a one-number change if you want it. |
| Players slide, jitter and sprint (the "giveaway") | Sprint exists (speed 18). The slide and jitter are not applied, because they would let players be told apart from NPCs, which this game must not allow. |

Also settled: 90 NPCs, split Guest 40, Staff 18, Security 16, Executive 16, with each role favouring its own tier when it
spawns and when it picks where to walk (`GameConfig.NPC.RoleTierWeights`).
