# Claude return handoff — owner reports and prompt review

Prepared by Codex while Claude was unavailable. This is a repository handoff, not a sent message or a scheduled task.
Read AGENTS/CLAUDE, current locks and queue before work. Owner authorized development across steps and focused commits;
stage only your work. No push was requested for this round. Codex has not changed server gameplay for these reports.

## Read first

- `docs/PROMPT_REVIEW_2026-10-24.md`: full conflict audit, overlap list and 35 owner questions.
- Owner's input is `C:\Users\Prest\Downloads\codex_deceive_inc_prompt.md`; it is a proposal, not an overriding system prompt.
- SPEC_CHANGES wins over the attachment until explicit new answers are recorded. Funds/Bonds/Squads/revolver and the
  imported ten-gadget roster conflict with answered decisions. Do not resurrect them from leftover GameConfig entries.
- Latest Codex queue rows and commit log contain the completed client work. Studio visual acceptance remains pending.

## Area split

| Area | Lead | Boundary |
|---|---|---|
| Own gun/hand placement, HUD graphics, existing-event prompts | Codex | Cosmetic client presentation; no new gameplay authority |
| NPC support/path/zone correctness and map defects | Claude | NPC/Movement/NavGraph, ZoneService and generator; client interpolation checked alongside server state |
| Two-sided door access | Claude | Clearance/auth, actual door geometry, authorized entry and exit rules |
| Downed/death authoritative body state and animation contract | Claude | Coordinate with Codex on visible poses; player/NPC parity throughout |
| Takedown reach, server hold/cancel and synchronized two-body action | Claude | Codex owns local readiness hint and first-person presentation |
| Design conflicts | Owner, recorded by either engineer | Recommendations in review document are not answers |

## P1: NPCs appear to walk in thin air

Confirmed code facts, not a confirmed runtime reproduction:

- `src/server/NPC/NavGraph.luau`: groundBelow uses an unfiltered downward ray and falls back to the node position when
  no hit is found. Intermediate PathfindingService waypoint positions are copied directly into cached routes.
- `src/server/NPC/Movement.luau`: follow linearly interpolates in 3D between cached points. separate adds a lateral offset;
  place uses ground + offset + rootHeight without testing support under the displaced footprint.
- `src/client/Controllers/NPCController.luau` now continuously interpolates between replicated root samples. The owner
  removed deliberate stepping in 8.20. A client interpolation defect and a server support defect need different fixes.

Reproduce at stairs, ramps, balcony edges and clustered doorways. Compare server root/ground/path points and client
rendered roots at the same location. Check whether navmesh vertical clearance, thin floor seams, separation over an
edge, or interpolation between floors causes the observation. A fallback to an unsupported node must not create a
valid walkable route. Don't fix it with a global Y offset; preserve legitimate slopes and stairs.

Acceptance: NPC feet remain supported at the rig's proper height across all floors and stairs, in both a sparse
NavReport test and a full crowd. No per-frame PathfindingService. Re-run map checks and measure added runtime cost.
Use the existing documented NavReport workflow: zero role counts in Studio's temporary GameConfig copy, never disk.

## P1: low-tier NPCs enter areas they don't match

The graph ALREADY samples maxTierAlong each edge and search rejects edges/destinations above maxTier. Start with actual
zone volumes, node Tier, TierSampleStuds spacing, RoleMaxTier, spawn/flee routes and lateral separation outside the
cached route. Don't add a duplicate destination-only check and claim the report fixed.

DoorService's PathfindingModifier.PassThrough allows routes through closed doors; verify the route's zone tier really
matches the door and that NPC role clearance is passed correctly. Higher-tier NPCs visiting lower-tier rooms is allowed
by current design. Guests entering Staff/Security/Executive is not allowed.

**Owner confirmed:** no panic/fleeing exception. Role clearance remains a hard cap; higher tiers may visit lower tiers.
Validate fleeRoute/routeNear and separation against it; no further owner decision is needed on panic exceptions.

Acceptance: role-by-role route audit with source/destination/edge maximum tier; stress stairs, shared boundaries,
panic/flee, crowd pushes and replacement spawn. Do not expose debug role/player identity attributes on rigs.

## P1: doors must open from outside

DoorService.holdNear currently uses symmetric horizontal distance to the blocker plus a vertical bound. There is no
one-sided inside/outside predicate in that function. Reproduce with the same correctly cleared disguise on each side.
Check door blocker center/size, actual exterior approach distance, elevation, overlapping blockers and zone sampling.
Keycard/lockpick/hack prompts in the new attachment do not mean those systems are complete.

Preserve exterior clearance. "Outside openable" must not become client-forced opening or free unauthorized entry.
Apply the confirmed free-exit rule below separately from two-sided authorized access.

**Owner now confirmed:** ordinary clearance doors must allow free exit from inside after losing clearance; outside
entry stays authorized and vault/objective locks are exempt. Determine the interior side from authored room/door
geometry on the server, never a client claim. Test turning around at the threshold and approaches from both sides.

Acceptance: each door type tested from both sides, correct and incorrect tier, Exposed, NPC use, moving leaf collision,
and simultaneous entrants. Neither side traps authorized users; unauthorized players don't gain a bypass.

## P2: missing crawl, collapse and elimination animations

DownedController currently loads normal walk/idle tracks from character.Animate, if those descendants exist. It does
not load a bespoke crawl track. NPCController also selects ordinary idle/walk. This explains why the current design
has no actual authored crawl cycle; runtime loading of those particular tracks still needs verification.

Coordinate shared player/NPC directional transitions: a rear downing falls forward into prone forearm crawl; a front
downing falls backward as if stunned into supine backward crawl. Final elimination is a brief stable collapse, not
ragdoll. Owner confirmed final damaging-hit direction relative to victim facing. **Latest clarification:** include
distinct left/right-side shot knockdown animations, not nearest-front/back reuse. Owner confirmed side fall then roll
onto the stomach into prone crawl; front/rear crawl choices stay approved. Falls without an attacker
use standard forward collapse. Keep classification server-side and use the same directional set for NPCs/players.
These baseline downing animations are separate from shop/Dossier finisher cosmetics. Use approved assets or original procedural
poses; no copied reference animations. Server owns transitions, movement, hit eligibility and interaction timing.
Animation must never announce player identity, team or agent while disguised. Restore joints/tracks cleanly on revive,
respawn and removal. Visible world rigs now animate smoothly; do not restore pose stepping.

Codex adds 9b-hud using Downed.BleedOutAt, InteractState and Eliminated only. A countdown is not the missing animation.
Test Duos: 2 players on the same team, one remains alive to avoid team wipe; separately test enemy execution and NPC
collapse/crawl behavior. Solos eliminate directly, so cannot demonstrate a downed countdown there.

## P2: takedown needs a broader allowance and two-body action

**Owner answer, October 25:** final corrected choice is **6.5 studs / 90-degree rear cone**, superseding the initial
3.5-stud reply. Implement this as separate takedown acquisition reach; ordinary melee stays unchanged. No lunge,
sight checks and 1.2 s hold remain. Codex has deliberately left the live hint on existing shared server values until
your implementation lands. Update those shared values/hint together; the numbers are no longer an unanswered question.

Current CombatService facts: nearest target within flat (Melee.Range 4 + ReachSlackStuds 1.5) = 5.5 studs; 90-degree front
swing cone, HeightStuds 3, root-to-root map line of sight. Rear eligibility is Takedown.ConeDegrees 60 total. Hold 1.2 s,
damage 90, target displacement break 4 studs, attacker damage cancels. Hold distance check is 3D, initiation flat.

Owner says it feels too narrow. Approved testing baseline: a SEPARATE takedown reach of 6.5 studs and rear cone 90 total,
ordinary melee unchanged. The final corrected answer above authorizes these values.
Avoid accidentally increasing normal melee by changing ReachSlackStuds for both. Review initiation/ongoing reach,
turning, line of sight, death/downed/removal and cancellation together. No automatic teleport/lunge without agreement.

MeleeState currently tells only the attacker Kind/Seconds/Active, without a target reference. Don't make Codex guess a
victim and animate the wrong body. Design the smallest authorized action-start/cancel/finish contract for observers;
no persistent identifying attributes, attachments or team reveal. Reuse current remotes if sufficient; otherwise lock
and append shared contracts properly. Current event is RequestMelee, not the attachment's invented remote names.

Codex readiness hint is generic geometry for both NPC/player rigs, with the current range and cone, no names/outlines.
It is advisory because client pose/latency can differ. A server range change must update the same shared data/hint.
**Round 1 answer:** keep first person and 90 damage. Add short cosmetic takedown animations as shop/Dossier rewards
after a server-confirmed down/elimination, with no effect on combat stats/timing. A nonlethal 90-damage completion
does not trigger the cosmetic finisher. The later clarification requires directional knockdowns for front/rear/side
shots, and has not reversed the finisher trigger. MeleeState.Active=false means cancel or completion;
that alone is insufficient proof of success and must not trigger a cosmetic execution.

Charged melee input and initial default balance are now confirmed: normal tap 35 damage; full charge 50 damage after
0.75 s, capped there, with no added range or stun. Keep existing cooldown/recovery rules unless playtesting changes
them; do not block implementation on the previously unanswered balance question.
The owner reports takedown hold
starts a melee. WeaponController.onMelee currently sends Press and plays MeleeSound immediately before the server
distinguishes strike/takedown; outside the server's present narrow window, CombatService immediately applies melee.
Keep takedown acquisition conditional on valid range/cone/LOS/state, and avoid a preliminary strike on a valid hold.
Coordinate charge start/release/cancel with Codex; never let a client-reported charge decide damage or duration.
Owner confirmed: V press inside the valid takedown window starts the hold directly with no preliminary melee;
outside that window, tap strikes on release and holding charges a strike for release. Use the approved default charge
values above; do not change ordinary melee range while increasing takedown reach. Server must validate elapsed charge and
cancel on incapacitation, wall tuck, removal/focus cancellation as applicable. No cosmetic may confirm a kill early.

Acceptance: NPC and player rear approach at range/angle boundaries, front/side rejected, nearest target selection,
wall rejection, interruption on damage/movement, and two clients seeing the same start/cancel/finish. Hint remains
absent behind walls, while wall-tucked/downed/eliminated, and during an active hold. No target identity info in the UI.

## Later dependencies from the attachment

### Approved client refinements, October 25

Smooth own gun/arms are confirmed. **Latest owner answer (8.20): remove movement/animation stepping entirely.**
Codex removed StepAnimationController, PositionStepController, Util/PositionStep and the obsolete Animation config.
NPCController uses continuous server time minus NPC.InterpolationDelay; players use native replication/animation.
Necessary server edit: Ballistics now passes continuous timestamp minus target.delay to History.poseAt, with the same
lag-compensation/future clamps. No other ballistic behavior, target delay, remote, hitbox or weapon rule changed.
Eight timing assertions plus shooter exclusion/empty-trace checks passed against the actual Ballistics body/config
in Luau with engine/history fixtures. Live moving-target hit registration still needs the owner's Studio test.
Do not restore the earlier 12/18 Hz interim tuning or old stepping imports.

Gala HUD now resolves UI.HudThemeId through Util/HudTheme; only palette/corner/accent overrides are permitted.
Later map loading should provide its authorized map/skin ID at startup; no runtime map metadata contract is invented.
Core layout, action timing and tier/cover/health meanings stay common. Field notes is the selected design direction.

Owner's HUD detail answers: health/armor, ammo, disguise, Cover and alarm stay visible during normal play; contextual
prompts/warnings appear only when relevant. Use clearer numbers/body text with pixel headings. HUD motion is driven
by events, with a real player-facing reduced-motion preference. Preserve critical information/timers under that
preference; do not change actual recoil/gameplay. Codex's typography and preference work is queued, not already built.

Floor/marker answers are confirmed: use the generated map's actual named floor bands (no invented GH floor), and
up/down arrows for different floors, not an arbitrary 10-stud difference within one room. Map work should provide
consistent authored floor definitions for Codex's HUD. Preserve current marker visibility/ranges/lifetimes; do not
expose extra enemy positions or keep a floor badge after its underlying marker expires. Vertical HUD work is queued.

Secret prop exits and elevators need original map design and server contracts before interactive UI. Step 18 owns
Intel/economy interactions and Agent Tag rescue pricing still needs the owner. Step 21 owns persistence, shop, Stocks
and Dossiers. Keep forthcoming menus as reviewable mockups until actual data exists. The live HUD refresh does not
pretend these systems are already implemented.
