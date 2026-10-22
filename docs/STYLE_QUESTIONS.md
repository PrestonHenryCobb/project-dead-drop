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
- **Answer:**

### A2. What does the player see of their own facing while disguised?
- **Question:** the camera can look anywhere but the body only turns the way you walk. How does the player know where
  their body is facing?
- **Options:** (a) nothing special, the player just sees the body (b) a faint arrow or cone on the ground (c) a small
  icon on the HUD showing "body facing" versus "camera facing".
- **Default:** (a) in third person, (c) if you pick first person.
- **Answer:**

### A3. Moving the camera while standing still in a disguise
- **Question:** should looking around be free when the player is not moving? Real NPCs stand and glance now and then.
- **Options:** (a) free look, body does not turn (b) body turns slowly to follow the camera, like an NPC glancing
  (c) the body only turns when you hold a key.
- **Default:** (b).
- **Answer:**

### A4. Default keys
- **Spec says:** Scan `F`, Disguise `G`, Blend wheel `B` (hold).
- **Question:** keep these, or does anything clash with how you want to play?
- **Answer:**

---

## B. Tone and atmosphere (Blocks Steps 6 and 7 for the HUD text; the rest is Later)

### B1. How serious is the game?
- **Options:** (a) tense spy thriller, quiet and low-key (b) glamorous and stylish, like a heist film (c) playful and
  a bit silly, big expressions and funny emotes (d) a mix: serious play, light cosmetics.
- **Why it matters:** the wording of every message ("EXPOSED", "Suspicious"), the emote wheel and the outfits.
- **Default:** (b).
- **Answer:**

### B2. Violence and presentation
- **Question:** Roblox's audience is mixed-age. How strong should hits and downed players look?
- **Options:** (a) no blood, characters fall face down and fade (b) small impact flashes only (c) your own limits: ____
- **Default:** (a), which also fits the downed-NPC body I just built.
- **Answer:**

### B3. The Gala setting
- **Question:** what kind of party is it? This sets outfits, props and music.
- **Options:** (a) black-tie art gallery (b) rooftop cocktail party in a skyscraper (c) masquerade ball (d) your idea: ____
- **Note:** the graybox already has a ballroom, galleries and a penthouse, which fits (a) best.
- **Default:** (a).
- **Answer:**

---

## C. Cover and suspicion feel (Blocks Step 7)

### C1. How does the player learn they are being watched?
- **Spec says:** a suspicion meter fills left to right at the bottom of the screen.
- **Question:** is a meter alone enough, or should there be warning cues on top of it?
- **Options:** (a) meter only (b) meter plus the watcher gets a small marker on screen (c) meter plus a heartbeat sound
  that speeds up (d) all of it.
- **Why it matters:** the marker would show where the danger is but also tells the player who counts as a witness.
- **Default:** (c).
- **Answer:**

### C2. How loud is being Exposed?
- **Spec says:** an "exposed sting" sound, pings for enemies.
- **Question:** how dramatic should the moment cover breaks be for the player and for everyone who sees it?
- **Options:** (a) loud and obvious, the whole screen reacts (b) a clear sound and a flash on the HUD only
  (c) subtle for the player, but loud pings for enemies.
- **Default:** (b).
- **Answer:**

### C3. Match pacing
- **Question:** what should a good five minutes feel like early in a match?
- **Options:** (a) quiet: players hide, scan and sneak, and nobody fights for a while (b) tense: small chances to be
  spotted and shot from the start (c) split: stealth first, fights only after the vault opens.
- **Why it matters:** it decides how loud the early game is, how many guards patrol, and how soon players are
  pushed toward each other.
- **Default:** (c), which is how the phases in the spec already work.
- **Answer:**

### C4. Telling teammates apart in the crowd
- **Spec says:** teammate markers are built on the client from a roster sent only to that team.
- **Question:** how visible should the marker be?
- **Options:** (a) small outline only when looking directly at a teammate (b) a faint icon above the head at any
  distance (c) an icon that fades out the further away they are.
- **Default:** (c).
- **Answer:**

---

## D. Look and sound (Later)

### D1. Overall art style
- **Options:** (a) clean, flat colours and simple shapes (b) realistic materials and lighting (c) stylised, with
  strong colour per zone (d) your reference: ____
- **Note:** the zones already use colours (spec Section 4), so (c) is the easiest to read at a glance.
- **Default:** (c).
- **Answer:**

### D2. HUD style
- **Options:** (a) minimal, almost no HUD, with icons only when needed (b) a classic shooter HUD (c) a spy-gadget look,
  like an old briefing screen.
- **Default:** (a), because the less there is on screen, the harder it is to tell players apart by what they look at.
- **Answer:**

### D3. Music mood
- **Question:** you chose Roblox library audio. What mood should I search for?
- **Options:** (a) jazz and lounge (b) tense orchestral (c) electronic, with a beat that rises as alarm increases
  (d) a different style: ____
- **Default:** (c).
- **Answer:**

### D4. Footsteps and voices
- **Question:** NPCs and disguised players must sound the same. Should NPCs make small sounds (murmur, clinking glasses)?
- **Options:** (a) footsteps only (b) footsteps plus soft crowd murmur from the whole map (c) per-NPC sounds
  (more noticeable, but players must also make them).
- **Default:** (b).
- **Answer:**

---

## E. Onboarding (Later, needed before Step 21)

### E1. How do new players learn the game?
- **Options:** (a) a short written tutorial screen before the first match (b) a solo practice room with NPCs and no
  enemies (c) tips that appear on screen during the first few matches (d) all of these.
- **Default:** (c), because it costs the least.
- **Answer:**

### E2. What do players see between matches?
- **Question:** the lobby is its own place. What should it show?
- **Options:** (a) a menu only (b) a small walkable lobby where players can see each other's cosmetics
  (c) a menu, with the walkable lobby added after launch.
- **Default:** (c).
- **Answer:**

---

## How I will use your answers

1. Fill in any subset and tell me to apply it.
2. Camera and cover-feel answers (A, C) are used directly in Steps 6 and 7. I will say which file each one changes.
3. Tone, art and audio answers (B, D, E) are recorded in the "Decided" section of this file and shape later steps.
4. Answered items move to a "Decided" section at the bottom so the list keeps shrinking.
