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
- `src/client/Controllers/NPCController.luau` interpolates between replicated root samples with the shared 12 Hz render
  schedule. A client interpolation defect and a server support defect need different fixes.

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
by current design. Guests entering Staff/Security/Executive is not. Ask the owner to identify emergency exceptions if
desired, without making normal routes inconsistent.

Acceptance: role-by-role route audit with source/destination/edge maximum tier; stress stairs, shared boundaries,
panic/flee, crowd pushes and replacement spawn. Do not expose debug role/player identity attributes on rigs.

## P1: doors must open from outside

DoorService.holdNear currently uses symmetric horizontal distance to the blocker plus a vertical bound. There is no
one-sided inside/outside predicate in that function. Reproduce with the same correctly cleared disguise on each side.
Check door blocker center/size, actual exterior approach distance, elevation, overlapping blockers and zone sampling.
Keycard/lockpick/hack prompts in the new attachment do not mean those systems are complete.

Preserve clearance. "Outside openable" must not become client-forced opening or free unauthorized entry. Clarify whether
free exit after losing clearance is intended; that's separate from two-sided authorized access.

Acceptance: each door type tested from both sides, correct and incorrect tier, Exposed, NPC use, moving leaf collision,
and simultaneous entrants. Neither side traps authorized users; unauthorized players don't gain a bypass.

## P2: missing crawl, collapse and elimination animations

DownedController currently loads normal walk/idle tracks from character.Animate, if those descendants exist. It does
not load a bespoke crawl track. NPCController also selects ordinary idle/walk. This explains why the current design
has no actual authored crawl cycle; runtime loading of those particular tracks still needs verification.

Coordinate a shared player/NPC prone pose and crawl cycle, plus a brief collapse and final eliminated settle. Owner is
being asked prone vs knee crawl, ragdoll vs stable body and camera comfort. Use approved assets or original procedural
poses; no copied reference animations. Server owns transitions, movement, hit eligibility and interaction timing.
Animation must never announce player identity, team or agent while disguised. Restore joints/tracks cleanly on revive,
respawn and removal. Respect shared animation stepping for visible world rigs.

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
Owner is being asked first-person vs cinematic camera and 90 damage vs execution. Keep current damage/outcome until
answered; the 6.5-stud / 90-degree reach/angle change is approved.

Acceptance: NPC and player rear approach at range/angle boundaries, front/side rejected, nearest target selection,
wall rejection, interruption on damage/movement, and two clients seeing the same start/cancel/finish. Hint remains
absent behind walls, while wall-tucked/downed/eliminated, and during an active hold. No target identity info in the UI.

## Later dependencies from the attachment

### Approved client refinements, October 25

Smooth own gun/arms are confirmed. World rig cadence is initially 12 Hz poses / 18 Hz positions, both NPCs and players.
PositionStep and Ballistics already share Animation.PositionStepHz, so rewind follows the same 18 Hz schedule.
Do not add a separate interpolator/latency to one client path without updating the shared timing contract.

Gala HUD now resolves UI.HudThemeId through Util/HudTheme; only palette/corner/accent overrides are permitted.
Later map loading should provide its authorized map/skin ID at startup; no runtime map metadata contract is invented.
Core layout, action timing and tier/cover/health meanings stay common. Field notes is the selected design direction.

Secret prop exits and elevators need original map design and server contracts before interactive UI. Step 18 owns
Intel/economy interactions and Agent Tag rescue pricing still needs the owner. Step 21 owns persistence, shop, Stocks
and Dossiers. Keep forthcoming menus as reviewable mockups until actual data exists. The live HUD refresh does not
pretend these systems are already implemented.
