# Step 7 questions: cover, suspicion, trespass, exposure

Everything Step 7 needs decided before I build it. It covers spec Sections 7, 8.3 and 8.4, plus your earlier answers
(OPEN_QUESTIONS C1, C4, C5, A5; STYLE_QUESTIONS C1, C2). **Write your answer on the `Answer:` line and tell me to
apply it.** Blank means "use the default".

How to read the tags:
- **Blocks** means I cannot build that part properly without an answer.
- **Default** means I will build it that way unless you say otherwise.
- **Later** means a later step builds it; the question is here so the Step 7 code leaves room for it.

What Step 7 builds, so you can see what each question touches:
- A **cover state** for every player (Covered, Suspicious, Exposed), owned by the server.
- A **suspicion meter** that fills when something suspicious is seen by a witness, and drains when it stops.
- **Trespass**: standing in a zone above your disguise's clearance.
- **Exposure**: the disguise is stripped, and nearby enemies get a ping.
- **Re-covering** after being exposed.
- **Agent Sense** (the shimmer) and the debug HUD that shows state and suspicion.

Combat, abilities, climbing, the Package and cameras do not exist yet. Their cover-breaking actions get a hook in
Step 7 and are wired in the step that builds them.

---

## A. Who counts as a witness (Blocks)

### A1. How much does each witness add, and do they stack?
- **You said (C1):** every NPC and camera is a witness. Security 1.0, camera 0.6, other NPC 0.2.
- **Spec says:** only Security and cameras count, and gains are per second (sprint 25%/s, and so on).
- **Question:** with up to 74 NPCs, if eight Guests see you sprint, is that 8 x 0.2 = 1.6 times the normal rate?
- **Options:**
  (a) Add them up, but cap the total at 1.0 (so a crowd never counts more than one guard).
  (b) Add them up with no cap. A crowded room makes sprinting fast to be caught in.
  (c) Take only the strongest witness. A crowd adds nothing extra.
- **Default:** (a).
- **Answer:** a

### A2. What can a witness see?
- **Spec says:** Security NPC range 35 studs and 110 degree field of view. It gives no numbers for other NPCs.
- **Question:** do Guests, Staff and Executives use the same range and field of view?
- **Options:** (a) same 35 studs and 110 degrees for every NPC (b) shorter for non-security, for example 20 studs
  and 90 degrees (c) your numbers: ____
- **Default:** (a), so there is one rule.
- **Answer:** a

### A3. Do other characters block a witness's view?
- **Question:** a crowd stands between you and a guard. Does it hide you?
- **Options:** (a) no, only walls block sight (b) yes, characters in the way also block it.
- **Why it matters:** (b) makes crowds real cover and costs more server time (more rays). Players could hide behind NPCs.
- **Default:** (a), which is how scanning already works.
- **Answer:** a (changed from b on 2026-10-22: only walls block sight)

### A4. Do suspicious actions count in Tier 0?
- **Spec says:** sprinting, jumping and crouching are suspicious only in Tier 1+ zones.
- **With your C1 answer:** every NPC is a witness, so the public area is full of them.
- **Question:** does a sprint in the crowded public area (Tier 0) raise suspicion?
- **Options:** (a) no, as in the spec (b) yes, at the witness rates (c) yes, but only for Security and cameras.
- **Default:** (a). It keeps the public area as a place to move quickly, with the tell being that other players see you.
- **Answer:** a (changed from b on 2026-10-22: sprint, jump and crouch are suspicious in Tier 1+ only, as in the spec)

### A5. Cameras
- **Question:** cameras are built in Step 14. Step 7 leaves a slot for them at the 0.6 rate. Any change before then?
- **Default:** no change.
- **Answer:** no change

---

## B. Suspicion meter (Blocks)

### B1. Gain and decay
- **Spec says:** gains per second or per jump (sprint 25, jump 20, crouch 15, terminal 20, weapon drawn 40, near a
  body 10, vault linger 15), decay 10 per second after 1.5 s of nothing suspicious.
- **Question:** keep every number as written? They are all in `GameConfig`.
- **Answer:** For the decay to apply, id add another 1.5 s of nothing suspicious before it applies. Everything else can stay as is for the time being.

### B2. What is "near a body"?
- **Spec says:** being within 6 studs of a dead body gives 10 percent per second while witnessed.
- **Now:** NPCs are downed, then lie still as bodies (OPEN_QUESTIONS A7), and a downed player is a body too.
- **Question:** does a downed or bled-out NPC count as a body?
- **Options:** (a) both downed and bled-out NPCs and players count (b) only bled-out ones (c) none.
- **Default:** (a). It matches what makes Guests gasp.
- **Answer:** a 

### B3. Reaching 100 percent
- **Spec says:** you become Exposed and the witness raises Alarm Level by 1.
- **Question:** alarm levels are built in Step 14. In Step 7, should anything happen beyond Exposed?
- **Options:** (a) just Exposed (b) store an alarm level number now but show nothing (c) store it and show it on the debug HUD.
- **Default:** (c), so the connection is visible to test. It has no other effect until Step 14.
- **Answer:** c

### B4. Does the meter reset when you re-cover?
- **Options:** (a) back to 0 on re-covering (b) stays where it was.
- **Default:** (a).
- **Answer:** a

---

## C. Trespass (Blocks)

### C1. How does trespass raise suspicion?
- **You said (C4):** trespass is part of the suspicion system and only builds when witnessed. The HUD always shows
  when you are in a room above your clearance.
- **Spec says:** a 3 second grace countdown, then Exposed. A witness cuts the grace to 0 and exposes you instantly.
- **Question:** what is the trespass rate, and does anything keep the old countdown?
- **Options:**
  (a) A fixed rate while witnessed, for example 35 percent per second (about 3 s to Exposed), no separate countdown.
  (b) Keep the countdown: it only runs while witnessed; leaving or being unseen pauses it.
  (c) The old spec rule: always counts down, and a witness cuts it to 0.
- **Default:** (a), with the HUD explaining "SUSPECTED: RESTRICTED AREA".
- **Answer:** a

### C2. Does the tier matter?
- **Question:** is a Guest in the Staff area (one tier over) as suspicious as a Guest in the Executive area (three over)?
- **Options:** (a) same rate for all (b) rate grows with each tier above your clearance.
- **Default:** (b), at 1x, 1.5x and 2x per tier over.
- **Answer:** b 

### C3. Guards in the room (your A5)
- **You said:** entering a room above your disguise level raises suspicion with the guards in that room.
- **Question:** how is "in that room" decided, and is it the same as being witnessed?
- **Options:** (a) the guard is on the same floor and zone as you, and can see you (that is just a normal witness)
  (b) any Security NPC inside the same zone volume gets a bonus even without sight.
- **Default:** (a). A separate rule would mean guards sense you through walls.
- **Answer:** a

### C4. Leaving a restricted room
- **Question:** the meter drains at 10 percent per second when nothing suspicious is happening. Does being in a
  restricted room (even unseen) delay that decay?
- **Options:** (a) no, it only builds when witnessed (b) yes, the 1.5 s decay delay restarts while inside.
- **Default:** (a).
- **Answer:** Decay delay should stay, raising depending on trespass level, using the same tier system used for C2.

---

## D. Exposure (Blocks)

### D1. What does True Form look like in Step 7?
- **Spec says:** the disguise is stripped in 0.3 s with a puff and the agent's True Form appears with the weapon
  visible. Agents and weapons are built in Steps 16 and 8.
- **Question:** what do exposed players look like until then?
- **Options:** (a) a single placeholder agent look for everyone (dark tactical outfit, no weapon) (b) the insertion
  disguise stays but with a red outline (c) your idea: ____
- **Default:** (a). It reads clearly as "exposed" and is replaced in Step 16.
- **Answer:** a

### D2. Movement while Exposed
- **Spec says:** a disguised player is capped to the NPC speed. It gives only the sprint speed (18) for True Form.
- **Question:** what is an exposed player's normal walk speed?
- **Options:** (a) 16 (Roblox default), sprint 18 (b) same as disguised (10 or 12), sprint 18 (c) your numbers: ____
- **Default:** (a).
- **Answer:** a (changed from b on 2026-10-22: an Exposed player walks at 16, sprint 18)

### D3. The enemy ping
- **Spec says:** a red "!" on enemies' HUD at that location for 2 s if within 60 studs.
- **You said (C2):** loud and obvious for you, and loud for enemies within 60 studs.
- **Question:** no teams exist until Step 10. For testing, are all other players enemies?
- **Default:** yes. Teammates are excluded once teams exist.
- **Answer:** Default

### D4. What does an exposed player's own screen do?
- **Question:** you wanted "obvious for the player". Which effects, in order of how strong?
- **Options (pick any):** (a) red flash and "EXPOSED" text (b) a short sting sound (placeholder until audio in Step 20)
  (c) screen shake (d) a vignette that fades after a few seconds.
- **Default:** (a), (d), and the sound once Step 20 adds audio.
- **Answer:** Default, but for the flash and "EXPOSED" text on screen, the team color should effect it.

### D5. Scanning an exposed player (your C2)
- **You said:** it copies the agent's last disguise, after a timer of about 3 seconds from the scan to the disguise.
- **Question:** is that 3 seconds on top of the 1.2 s scan, or instead of it?
- **Options:** (a) on top: the scan takes 1.2 s, then the disguise is only usable after 3 more seconds (b) instead:
  scanning an exposed agent takes 3 s in total.
- **Default:** (b).
- **Answer:** b (changed on 2026-10-22: scanning an exposed agent takes 3 s in total, with no extra timer afterwards)

---

## E. Re-covering (Blocks)

### E1. Conditions
- **Spec says:** the combat lockout has ended, no Security NPC or camera is tracking you, you are not carrying the
  Package, and you are in a zone at or below the disguise's clearance. The HUD says "COVER AVAILABLE".
- **Question:** what does "tracking" mean for a Security NPC without combat?
- **Options:** (a) a Security NPC currently counts you as a witness (b) a Security NPC has seen you within the last 3 s.
- **Default:** (b), so ducking out of sight for a moment is not enough.
- **Answer:** b

### E2. Which disguise do you get back?
- **Question:** when you re-cover, you put on the stored disguise or the insertion one, as in Step 6. Is there anything
  different when you were Exposed?
- **Default:** no. The same `G` key and the same rules.
- **Answer:** Same rules, however, for every re-cover the agent gains a new disguise. This disguise should never defer from the tier of the players last disguise.

---

## F. Combat lockout and cover-breakers (Later)

### F1. Lockout without combat
- **Spec says:** the lockout starts when you fire, deal or take damage from another agent, or throw an offensive gadget.
- **Question:** none of those exist yet. Step 7 can build the timer and the "locked out" rule with nothing starting it.
  Is that acceptable, or should a test key start it?
- **Default:** build the timer, and add a Studio-only test key to start it, removed in Step 8.
- **Answer:** default 

### F2. The other cover-breaking actions
- **Spec says:** firing, abilities, melee, climbing, vents and ziplines, the Package, reviving and executing, supply cache
  upgrades, hacking the vault, killing any NPC, and lock picking all expose you instantly.
- **Question:** each is wired in the step that builds the action. Step 7 provides one function they all call. OK?
- **Default:** yes. The ones I can test now: trespass, the meter, and "killing an NPC" through the Studio test keys.
- **Answer:** default

---

## G. Agent Sense and hitmarkers (Blocks for Agent Sense)

### G1. Agent Sense
- **Spec says:** an enemy agent within 6 studs that you look straight at for 1.5 s gets a faint white outline for 1 s,
  for you only. Cooldown 8 s. Teammates never shimmer.
- **Why it needs the server:** the client must not know who is a player. The server checks the look and sends the
  shimmer to that one player.
- **Question:** what does "looks directly at" mean in first person?
- **Options:** (a) the target is within a narrow cone (about 10 degrees) of the centre of the screen (b) the crosshair
  ray hits them.
- **Default:** (b), which matches how scanning aims.
- **Answer:** b

### G2. Does Agent Sense work on exposed enemies?
- **Question:** an exposed enemy is already visible as an agent. Does the shimmer still trigger?
- **Default:** no, only disguised enemies.
- **Answer:** yes but as a red vingette effect if the player isnt already looking back at them. This effect should be much more feint than the normal agent sense.

### G3. Hitmarkers (spec 8.4)
- **Question:** red or grey hitmarkers belong to weapons (Step 8). Anything to decide now?
- **Default:** no. Step 8 handles it.
- **Answer:** default

---

## H. HUD and feedback (Blocks the debug HUD)

### H1. Debug HUD
- **Build order says:** a temporary debug HUD with state and suspicion.
- **Question:** what should it show?
- **Default:** state name, suspicion percent, the clearance tier of your zone and of your disguise, who is currently
  witnessing you (count by type), and the alarm level.
- **Answer:** default

### H2. Watcher markers (your C1)
- **You said:** a marker on any witness currently adding to your suspicion. Edge arrows for off-screen ones.
- **Question:** is that part of the debug HUD for now or the real HUD?
- **Options:** (a) build it now as the real feedback (b) show a count in the debug HUD now, and build markers in the
  HUD step (19).
- **Default:** (b). The marker design depends on the final HUD style (STYLE_QUESTIONS D2).
- **Answer:** default

### H3. Heartbeat sound
- **You said:** a heartbeat that speeds up as the meter rises.
- **Question:** audio is Step 20. Skip the sound for now?
- **Default:** yes. The meter and the visual cues first.
- **Answer:** default

---

## I. Engineering notes (no decision needed, FYI)

- **Cost:** a witness check is a distance and angle test for each player against each NPC, then one ray only for those
  that pass. At 5 Hz with 12 players and 74 NPCs, that is under 1000 cheap checks and a few rays per tick. I will
  measure it in Studio.
- **Identity:** the cover state and suspicion are sent only to the owner. Other players learn only what they can see:
  the true-form model and the ping.
- **Respawn:** a player returns to Covered with the insertion disguise and an empty meter.
- **No new tags or attributes** go on any character or NPC.

---

## How I will use your answers

1. Fill in any subset and tell me to apply it.
2. I will list what each answer changes in `GameConfig`, the spec and the code before building.
3. Answered items move to a "Decided" section at the bottom of this file.
