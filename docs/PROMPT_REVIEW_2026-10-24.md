# Owner brief review and design questions

Reviewed input: `C:\Users\Prest\Downloads\codex_deceive_inc_prompt.md`.
Review begun October 24, 2026; continued October 25. Recommendations below are not owner answers.

## Owner answers received October 25

1. Preserve existing repo decisions while reviewing conflicting attachment changes individually.
2. Own gun and arms smooth together. **Latest answer:** remove world-model choppiness entirely for combat;
   continuous movement/animation replaces both the original stepping and the interim 12/18 Hz tuning.
3. Compact icons/meters, translucent dark panels, shadows and numeric health/ammo are approved. Selected mockup:
   **Field notes**. Add a map-specific visual skin framework; current skin should match The Gala.
4. The final corrected takedown answer is **6.5 studs / 90 degrees**, superseding the earlier 3.5-stud answer.
   This is approved for Claude's server implementation; it is not already live.

These resolve the broad conflicts/timing/HUD direction and reach/angle questions below. Round 1 answers below resolve
gun composition, damage, camera, directional poses and ordinary-door exit. Do not repeat the answered choices.

### Round 1 answers received

- Q3: shoulder stock may extend offscreen; keep hands, sights and muzzle readable.
- Q8: keep 90-damage takedowns, not a guaranteed down.
- Q9: first-person action. Add short cosmetic takedown animations to the shop and Dossier rewards, played after
  confirmed execution/result. Charged melee is requested; only valid range/cone can initiate a takedown attempt.
- Q10: rear downing -> forward fall/prone forearm crawl; front downing -> backward stunned fall/supine backward
  crawl. Elimination -> short stable collapse. Player/NPC parity applies.
- Q11: ordinary clearance doors allow free exit from inside after clearance is lost; exterior entry stays authorized.

Selectable follow-ups answered: V press in the valid takedown window starts the hold without a preliminary melee;
outside it, tap/charge strikes on release. Cosmetic finishers require server-confirmed down/elimination. Directional
downing uses final hit direction relative to victim facing, with forward fall fallback for falls without an attacker.
Latest clarification: include equivalent left/right-side shot knockdowns as well as front/rear, superseding the
previous nearest-front/back-half side fallback. This does not authorize finishers on a surviving target.
Follow-up answers: side falls roll onto the stomach into prone crawl; default melee taps 35 and fully charges to
50 damage after 0.75 s (capped, no added range/stun); NPC clearance caps stay enforced during panic/fleeing, while
higher tiers can visit lower areas. Existing cooldown/recovery rules stay in place. Do not repeat answered choices.

HUD detail answers: Q5 essentials (health/armor, ammo, disguise, Cover, alarm) stay visible; prompts/warnings are
contextual. Q6 clearer numbers/body text with pixel headings. Q33 event-driven HUD motion plus reduced-motion option.
These are recorded design decisions; the typography/preference implementation is queued separately.

World-navigation answers: Q14 use actual generated-map named floor bands, with no new GH floor inferred from the
attachment. Q15 show elevation arrows for different floor bands rather than a raw 10-stud difference. Q16 preserve
existing marker visibility permissions/ranges/lifetimes; floor information adds no extra enemy detection.

Traversal answers: Q17 add a small original set of secret prop exits inside restricted rooms. Q18 prompt eligibility
requires inside-room position, proximity, facing and clear line of sight. Q19 add working glass elevators to the map
plan now. Follow-up answers: open exits allow anyone through in either direction, activation stays inside-only and
Discreet (breaks Cover only if witnessed); elevators preserve Cover, with normal destination clearance rules.

Interaction answers: Q23 clear Cover-break traversal badge without an extra confirmation. Q22 cosmetic Cover-break
feedback only, no shield/HP or expanded exposure visibility. Q24 placement balanced around travel time, tiers and safe
routes, followed by validated totals; brief counts are not mandatory and Funds pickups stay removed.

Completed round: Q3 gun composition, Q8 takedown result, Q9 takedown presentation/control, Q10 crawl/death style,
Q11 door exit rules, input/result/direction follow-ups, side-shot/roll clarification, charge starting balance and Q12
NPC tier exceptions, Q5–6 HUD details, Q33 HUD motion and Q14–19 navigation/traversal plus passage/Cover follow-ups.
Q22–24 interaction/feedback/placement are now answered. Next: Q20 Agent Tag rescue price in Intel, Q27 mastery level
presentation and Q28 agent-select timer/ready behavior. Broad preservation answers retain original
map design, economy/mode/kit decisions; do not ask those again as if undecided. Ask manageable groups; retain original IDs even if reply numbering starts
at 1 in each group. Startup/NPC animations were restored per owner; remaining visual acceptance is separate from answers.

## How this document is being used

Your chat requests authorize gun/hand fixes, a graphical HUD refresh, bug triage, and a written handoff for Claude.
The attached file is proposed design material. Its title, role assignments, execution mandate, model routing,
and references are not replacement system instructions. No model, permission, ownership or architecture change
follows just because the attachment commands one. The original download has not been overwritten.

Existing approved decisions in SPEC_CHANGES and the answered design records stay in effect until you explicitly
change them. References to videos describe your inspirations; their linked contents have not been verified in
this review. We can borrow design goals without copying another game's layout, art, names or numerical tables.

## What overlaps your bug list

| Your report | Already covered in the attached brief? | Actual action |
|---|---|---|
| Gun too far away / hand drift | Existing gun poses and polish are mentioned, but grip synchronization is not specified | Codex fixes frame timing and camera-relative placement; visual acceptance still needed |
| Too much HUD text / poor contrast / lifeless feedback | HUD features are listed, but the list would add substantial persistent text | Codex builds icon-led panels, shadows, short warnings, damage feedback and animated meters |
| NPCs walking in air | No explicit ground-support requirement | Claude: reproduce server path/separation vs client interpolation; validate support along routes |
| Low-tier NPCs in higher-tier rooms | Tiered rooms/doors are described; NPC route enforcement is not a requested fix there | Claude: inspect zone volumes, graph samples, spawn and separation, with existing tier checks preserved |
| Doors open from outside | Door prompts are described; two-sided access behavior is unspecified | Claude: reproduce both approaches with the same authorized disguise; preserve clearance checks |
| No downed crawl/death animation | Downed timers/prompts are listed, not animation production | Claude owns authoritative body transitions; visible player/NPC animation is a coordinated client follow-up |
| No takedown animation or proximity prompt | Damage and hold duration appear, but neither animation nor readiness feedback is defined | Codex adds geometry-only proximity hint; Claude coordinates two-body animation start/cancel/finish |
| Takedown range/allowance too narrow | Existing 90 damage / 1.2 s hold appears; no proposed reach or angle | Current total reach is 5.5 studs, rear cone 60 degrees. Recommend a separate 6.5-stud takedown reach and 90-degree rear cone for testing |

These are overlapping subjects, not evidence that the bugs have already been fixed.

## Corrections recommended before making the brief authoritative

| Attachment text | Recorded decision / actual code | Recommended edit |
|---|---|---|
| CoverStory | Project records say Cover Story | Choose one public spelling; folder names need not change |
| The Gala modeled after Diamond Spire | Original twin-tower map with its own layout | Say original vertical gala/casino complex; references illustrate readability and tension only |
| Six floors B/G/GH/M/T/R, but badges/selectors B/G/M/T/R | Internally inconsistent | Define each floor's name, height band and access tier; include GH everywhere if real |
| Funds pickup, starting $100, 150 Funds rescue | Funds removed; Intel is the match currency | Remove Funds from UI; separately decide rescue's Intel cost rather than blindly converting 150 |
| Bonds | Stocks, purchased in the Mint | Replace Bonds with Stocks |
| Flat 20% shop discount in Tier 1+ rooms | 10% per worn disguise tier | Keep disguise discount unless explicitly changing it |
| Squads, Duos and Solos | Duos and Solos queues | Remove Squads unless deliberately restoring that mode |
| Cover-Break Shield | Cover is a stealth state, not damage protection | Call it cover-break feedback; keep health and armor independent |
| Heavy revolver | Feint's silent pistol explicitly replaced it | Keep Feint pistol; ask before adding a revolver elsewhere |
| Crossbow / hand shotgun | Not in the approved 18-weapon roster | Treat as additions/replacements requiring kit and server design |
| Ten imported gadgets | Approved original 12-gadget pool, two different selections | Keep ours; identify exact substitutions if you intend a redesign |
| Ability E | Ability Q; interaction E | Keep Q/E separation and show current bindings, not hardcoded letters |
| MeleeRequest / TakedownRequest | Existing remote is RequestMelee with Press/Release | Correct the contract names; don't add duplicate remotes |
| SecretExitTrigger and working glass elevators | No such secret-exit contract or complete elevator system exists | Mark proposed; require map/server behavior before wiring working controls |
| Live damage screen using 23/17/16 | Actual damage comes from WeaponDefs and server hit rules; no distinct limb multiplier now | Show real results, not those sample numbers; range currently planned for Step 22 |
| Seasons / Catalog Tokens | Non-expiring Dossiers approved; token economy not defined here | Keep Dossier naming; decide whether a separate token currency is worth its UI cost |
| Exact map object counts as if present | Must be checked against generated layout and validation | Treat numbers as desired counts until measured |
| Every proposed HUD field immediately visible | Some systems lack a server/data contract | Show only functional information; preview future screens separately |

The four Intel station rewards/times (2/4/6/10, 4/7/11/16 s) and 25-stud glint match current config.
Zipline, moving gondola and vent traversal already break Cover on the server; a warning is appropriate.
Mastery kit choices, exact weapon stats with themed graphics, and non-expiring Dossiers overlap approved plans.

## Questions: start with 1–12

Reply by number; a short answer is enough. For any question, "keep the recommendation" is a valid answer.
Unanswered recommendations remain proposals and do not silently replace approved gameplay.

1. **Which differences in this attachment are intentional changes?** Do you want a newer authoritative redesign,
   or a reference brief reconciled with previous answers? Recommend preserve previous answers and explicitly
   list only the changes you now want. In particular: Funds, Bonds, Squads, the revolver and the ten gadgets.
2. **Own gun/arm timing:** smooth together, or both stepped together at 8 Hz? The bug fix makes the hands follow
   the gun every render frame. Recommend smooth own gun/arms for precise aiming, retaining other-character
   animation stepping. If you want a stepped first-person style, the gun must share that clock too.
3. **How much weapon should be visible?** Recommend a close grip in the lower right, support hand visible,
   stock allowed to run offscreen near the shoulder, muzzle and sights readable. Is "entire gun always in frame"
   still mandatory, including the stock? That requirement is a major reason the framing solver pushes it away.
   Current fix brings camera depth closer without changing projected composition; changing the composition is
   a separate art choice.
4. **HUD visual direction:** compact smoked glass with restrained gold/teal accents, or a more ornate agency
   dossier look? Recommend compact combat UI; reserve engraving, animated dossiers and richer illustrations
   for menus where people have time to read.
5. **HUD amount:** always show health/armor, ammo, cover/disguise and alarm; show objectives, action prompts and
   warnings when relevant? Recommend that hierarchy. Which existing item would you remove entirely?
6. **Text rules:** keep exact HP/ammo numbers and short action words, with icons/meters replacing explanations?
   Recommend yes. Do you still want the pixel font everywhere, or a clearer numeric/body font with pixel headings?
7. **Takedown allowance:** current reach is 4 + 1.5 = 5.5 studs, front swing cone 90 degrees, rear eligibility cone
   60 degrees total. Recommend separate 6.5-stud takedown reach and 90-degree rear cone (45 degrees each side).
   Should ordinary 35-damage melee stay at its current reach? Recommend yes; avoid buffing both accidentally.
8. **Takedown result:** keep 90 damage over a 1.2 s hold, or make it an execution? Recommend preserve 90 until
   explicitly changed: "takedown" currently does not guarantee defeating a full-health armored agent.
   Do plates absorb that damage as normal? Should an exposed target be easier to finish?
9. **Takedown presentation/control:** stay first person with hands entering view, or briefly switch to third person?
   Recommend first person, a short readable two-body motion, no camera teleport and no automatic lunge.
   Can either person still move during the hold? How should damage, lost sight, turning and displacement cancel it?
10. **Downed/death style:** prone forearm crawl, knee crawl, or stylized dragging? Recommend prone crawl and a short
    collapse into a stable body pose, with the same treatment for players and NPCs. Should elimination add a
    ragdoll, a final settle, or a dissolve after a delay? How graphic should it be?
11. **Outside doors:** should a correctly cleared disguise open automatically from both sides, while an
    unauthorized entrant still needs the approved hack/keycard/lockpick? Recommend yes. Should anyone already
    inside get free exit even after losing clearance? That is a distinct rule from outside entry.
12. **NPC tier behavior:** do you mean low roles entering higher-clearance areas, or any role visiting a floor
    that doesn't match its uniform? Recommend Guest <= Public, Staff <= Staff, Security <= Security,
    Executive <= Executive; higher-clearance roles can still visit lower tiers. Should panic ever permit escape
    through a higher tier? Recommend no for routine crowd paths; decide emergency exceptions explicitly.

## World, economy and information questions

13. **Originality and map shape:** keep our current Gala arrangement and use videos only for examples of vertical
    navigation? Recommend yes. Which specific feel is missing: seeing floors across the atrium, escape options,
    landmark readability, or longer sightlines? Those goals can be met with our own layout.
14. **Floor dictionary:** what do B, G, GH, M, T and R mean in this map? Is GH a full navigable storey, an atrium,
    or a named room? Should the hotel wing use the same letters or tower-specific labels?
15. **Vertical markers:** always show floor plus up/down, or show the arrow only for meaningful floor differences?
    Recommend floor bands, not a hard 10-stud difference alone: ramps and tall rooms otherwise mislabel targets.
    Should a teammate on the same floor but on a raised balcony get an elevation arrow?
16. **Marker information limits:** which markers can appear through walls and at what ranges? Recommend only
    existing team/objective permissions; exposed-enemy pings keep their authorized lifetime/range. No generic
    HUD feature should reveal disguised players or add wall tracking.
17. **Secret exits:** approve these as new mechanics, or just improve current vents/escape routes? If approved,
    should exits open only from inside, be physically usable from outside while open, close automatically, and
    be usable by NPCs? Are they one-way drops or bidirectional doors? Recommend a small original set of clear,
    testable escape routes rather than hidden props copied from the reference map.
18. **Secret detection:** should the prompt reveal every secret as you walk near it, require facing/inspection,
    or become visible after a clue? Recommend close range plus line of sight and facing, with no wall prompt.
    Can a player keep Cover while using one, or does the animation expose them?
19. **Elevators:** do you want genuine glass capsule elevators now, later, or no elevators? Recommend finishing
    current routes first, then designing server-owned platforms, obstruction handling, passenger safety and
    floor access. Should riding preserve Cover unlike vents/ziplines/gondola?
20. **Match currency:** keep Intel-only? Recommend yes. If rescue uses Intel, what should the team sacrifice
    versus vault progress, healing and ammo? A flat conversion of 150 Funds to 150 Intel would be arbitrary.
21. **Supply Cache discount:** keep 10% per worn disguise tier, change to room tier, or remove discounts?
    Recommend keep disguise-based discount because it rewards acquiring and keeping better Cover.
22. **Cover-break visuals:** is hex shatter just cosmetic feedback, or did you intend an actual shield mechanic?
    Recommend cosmetic only. Should rivals see it only in line of sight, or should it accompany existing
    authorized exposure pings? A cosmetic effect must not become permanent tracking.
23. **Traversal warnings:** brief warning under a context icon before using the route, or another confirmation
    press? Recommend a clear short Cover-break badge without an extra confirmation step during a chase.
24. **Pickups:** are 30/6/8/20/12/6 hard targets for pickups, health stations, ammo, food, safes and caches,
    or illustrative counts? Recommend balancing distribution by travel time, safe routes and room tier,
    then checking the total in map validation. What replaces the removed Funds pickups?

## Kits, progression, menus and polish

25. **Weapon additions:** which approved agent/slot would a crossbow, hand shotgun or revolver replace?
    Recommend keep the approved 18 and Feint's replacement silent pistol. Adding weapons needs damage,
    cadence, ammo, falloff, Cover behavior and a unique effect, not just a model and a menu card.
26. **Gadget mapping:** keep our 12? They are Scanner Pulse, Bug Cam, Tripwire, Long Lens, Keycard Clone,
    Jammer, Spring Pad, Noise Maker, Disguise Kit, Med Injector, Plate Pack and Briefcase Shield.
    The brief's Bounce Mat/Spyglass/Signal Scrambler overlap Spring Pad/Long Lens/Jammer. Holo-Mimic,
    Turret, Goo Pod, Hack Trap and Recon Drone are actual new or overlapping designs, not alternate names.
    Which exact replacements do you want, and how will they avoid outperforming an agent's Talent?
27. **Agent mastery:** keep Hardware/Talent/Instinct choices, about ten matches for the full kit, one of each
    available initially? Recommend yes. Are levels 1–10 just presentation, or a new progression curve?
    Twelve additional Talents and twelve Instincts still need designs; this attachment doesn't define them.
28. **Match modes:** keep Duos/Solos, or restore Squads? Recommend keep the two approved queues until
    population supports more. Do you still want a 30-second selection timer, and can everyone ready early?
29. **Shop terminology:** keep Stocks/Mint, Credits and non-expiring Dossiers? Recommend yes. Do you want
    a new Dossier-only token, or earned progress on the selected Dossier? Avoid a fourth currency without a
    clear purpose. Does "zero FOMO" apply only to Dossiers or also the rotating Black Market?
30. **Six menu tabs:** should Assets be a reference/loadout screen for perks found in a match, rather than
    selling permanent power? Recommend yes. Should the labels be Play, Agents, Assets, Dossiers,
    Black Market and Profile, with the Mint reached from the currency balance?
31. **Controls:** keep Q ability, E interaction, 2/3 gadgets, F scan, G disguise, V melee/takedown?
    Recommend yes; the brief currently assigns E to two jobs. Should HUD keycaps switch with active input
    and eventually reflect rebinding? Recommend yes, including controller glyphs.
32. **Firing range:** keep it in the lobby at Step 22, or bring a minimal tuning range forward?
    Recommend real server-confirmed damage, adjustable plates, head/body labeling, distance and resettable
    totals. Do you actually want distinct limb damage? That is a combat rule change, not just a screen label.
33. **Motion/contrast:** restrained event-driven pulses and easing, or continuous scanning/animated ornament?
    Recommend event-driven motion, shadows/dark backdrops, shape plus color, and a reduced-motion option.
    What minimum Studio window size and screen resolution should the HUD support?
34. **Death and takedown camera comfort:** should there be camera shake, blur or screen tilt? Recommend light
    optional shake and no forced roll. Should spectators see the same action without extra identity effects?
35. **Next priority:** after this acceptance pass, prioritize NPC/door correctness, completing weapon/kit
    functionality, or building menus? Recommend correctness first, then finish the usable combat/loadout loop,
    with menu mockups progressing independently of unbuilt server systems.

## Proposed replacement opening for the attachment

> This is a design brief for the original game Cover Story. Reconcile it with SPEC_CHANGES and the owner's
> answered decision records before implementation. References illustrate pacing, readability and interaction
> goals only; do not copy names, layouts, numerical tables or assets. Build functional client UI against existing
> shared types and events. Mark proposed systems and missing contracts explicitly. Preserve Intel-only match
> currency, Stocks/Mint, Duos/Solos, the approved agent kits and original gadget pool unless the owner records
> an explicit replacement. Keep combat text brief, use graphical hierarchy and readable backdrops, and show
> only information the player is authorized to receive. Coordinate server/map work through the shared queue
> and file locks; never assume a named feature already exists.

Recommended structural edits: split the rest into **approved behavior**, **new proposals awaiting answers**,
**implementation dependencies**, and **acceptance tests**. Delete tooling/model routing and stale as-if-built
architecture claims. Keep one glossary and one floor dictionary instead of repeating inconsistent names.
