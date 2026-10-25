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
- Interview is complete: optional light camera shake/no forced roll or blur, HUD 1280x720 minimum, bugs before
  combat/loadouts. Ticket 8.22 now implements the co-owned R5/R6 range/input path below; do not duplicate it.

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
sight checks and 1.2 s hold remain. Codex's coordinated 8.22 now implements this range/cone and updates the hint through
shared MeleeRules; the old 5.5/60 takedown window is no longer live after sync. Body animation work remains yours.

Before 8.22: nearest target within flat (Melee.Range 4 + ReachSlackStuds 1.5) = 5.5 studs; 90-degree front
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
Pre-8.22 cause reported by the owner: takedown hold
starts a melee. WeaponController.onMelee currently sends Press and plays MeleeSound immediately before the server
distinguishes strike/takedown; outside the server's present narrow window, CombatService immediately applies melee.
Keep takedown acquisition conditional on valid range/cone/LOS/state, and avoid a preliminary strike on a valid hold.
Coordinate charge start/release/cancel with Codex; never let a client-reported charge decide damage or duration.
Owner confirmed: V press inside the valid takedown window starts the hold directly with no preliminary melee;
outside that window, tap strikes on release and holding charges a strike for release. Use the approved default charge
values above; do not change ordinary melee range while increasing takedown reach. Server must validate elapsed charge and
cancel on incapacitation, wall tuck, removal/focus cancellation as applicable. No cosmetic may confirm a kill early.

**Implemented by Codex in co-owned ticket 8.22 (supersedes the old path described above):** shared MeleeRules now
drives the advisory hint and server 6.5-stud/90-degree rear acquisition; ordinary melee stays at 5.5 total. Press
selects a valid takedown without striking, otherwise starts a server-timed charge. Release strikes 35 or fully charged
50 after 0.75 s; Cancel never strikes. Owner-only MeleeState now distinguishes Takedown/Charge/Strike, with optional
StartedAt server time. Clients cancel on wall tuck, focus/text input, item switch, reload, disguise, incapacitation
and missing camera/character. Strike acknowledgement drives melee sound/recovery; no preliminary sound on press.
Server guards cooldown/LOS/range/cone, cancels invalid holds and rejects teammate damage under spec 13.6. No new
remote names. Strike is not a down/elimination confirmation and must not trigger cosmetic finishers.

Reproduce the automated regression checks with `node tools/check-melee.cjs <path-to-official-luau-cli>`: 29 assertions
exercise actual source bodies/config with engine/service fixtures. They do not execute Roblox physics or animation.
Studio acceptance remains in CLIENT_REVIEW_2026-10-25. Partial holds retain 35 until full charge (SPEC-QUESTION).
Do not overwrite these coordinated server changes when returning to body animation/cosmetic work.

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

**Owner approved now:** a small original set of prop-triggered secret exits inside restricted rooms, with activation
requiring inside-room position, proximity, facing and clear line of sight; also add working glass elevators to the map
plan now. See MAP_BRIEF_REPLAN's traversal expansion. Claude owns map/server travel and validation; Codex owns prompts,
floor selection/status graphics after real contracts exist. Floor stops follow actual map bands. Owner confirmed open
exits allow anyone through in either direction, with inside-only activation. Activation is Discreet using existing
witness rules. Elevator riding preserves Cover; destination rooms keep normal clearance rules. No pending owner
decision remains on those three points. Do not copy the reference map.

Further owner answers: existing Cover-breaking traversal prompts need a clear badge without a second confirmation.
The "Cover-Break Shield" is cosmetic only, with no shield/HP and no extra exposure visibility. Codex owns original
client feedback against existing authorized events; no character-attached identity effects or expanded enemy tracking.
Map pickup/station/safe/cache counts should follow placement balance (travel time, tier, safe routes), then validated
totals. The attachment's counts are not mandatory; Funds pickups stay removed. Update layout/config/checks together.

Step 18 owns Intel/economy interactions. **Rescue price is now approved:** initial 10 Intel through normal spending,
reducing vault-unlock progress. Codex updated Downed.Rescue.Cost from obsolete 150 Funds to 10; no rescue behavior
was added. Agent Tags/caches remain dependencies. Mastery 1–10 displays existing roughly ten-match kit unlocks.
**Final corrected selection rule:** full 30 seconds even if everyone readies, permitting loadout revisions until deploy;
retain team-agent restrictions and server final validation. No early all-ready start. Step 21 owns persistence, shop, Stocks
and Dossiers. Keep forthcoming menus as reviewable mockups until actual data exists. The live HUD refresh does not
pretend these systems are already implemented.

Further confirmed answers: Dossier progress goes directly to the selected non-expiring Dossier; no reward-token
currency. Menu tabs are Play/Agents/Assets/Dossiers/Black Market/Profile; Stocks balance opens Mint. Assets explains
perks found in matches, not permanent combat power. Keep limb damage equal to body damage. The lobby firing range
must show actual server-confirmed results, not imported sample numbers or an invented limb multiplier. Core roster,
gadget pool, controls and shop rotation remain preserved by the earlier owner instruction.

## Gala art direction source pass (owner requested, 2026-10-25)

Read docs/GALA_ART_REVIEW.md before changing art/rigs. Direction 1 cinematic sculpted Art Deco wins; keep existing tier
colors with CYAN accents (owner clarification). Parchment/ink HUD supersedes Gala dark glass. ArtSurface is shared by
NPC/player outfit application; preserve identical structures, shading and physical properties. Source map finishes,
lighting, gun materials and pooled sparks are implemented; no server mechanics/remotes changed. Material import pack
has real generated PNGs but NO uploaded IDs. Native fallback is intentional and must not be called exact PBR.

Remaining asset work: original sculpted facial planes, beveled collars, tapered torso meshes, low-poly fluted architecture,
chandeliers and velvet seating, shared by NPCs and players, with unchanged joints/hitboxes and 200-NPC profiling.
Current native R15 faces/torso are retained; angled block lapels are not a completed sculpted rig. Coordinate the mesh
import/rig pass after owner Studio source review; do not independently change disguise proportions or revive stepped
motion. Existing NPC ground/tier, ordinary doors and animation tickets remain separate. Use fresh-clone map/material
commands in the review doc so cached GameConfig cannot silently supply old art values.

### Live Studio follow-up (2026-10-25)

Codex operated D:\Dead-Drop\CoverStory.rbxl with owner permission, saved a pre-art backup at
D:\Dead-Drop\CoverStory.before-gala-art-20261025-0416.rbxl, and rebuilt/saved Gala. Fixed an existing Build.luau crash:
synthetic stair/gondola gaps have no door/roomB and must skip doorway lintel/clearance decoration. Fresh-clone rebuild:
0 problems, 102 rooms, 786 nodes, 9,797 actual scene BaseParts. One-player test: all 25 client controllers and 200 NPCs
started; actual parchment/ink/font, first-person body hiding, Realistic lighting and 64-part spark reuse/fade verified.
See docs/GALA_ART_REVIEW.md live section for exact evidence and limitations. Stopped Play; left Edit mode saved.

PBR uploads are still pending: Studio's CreateAssetAsync returned "CreateAssetAsync and CreateAssetVersionAsync are
not available yet". No uploaded IDs were returned and no six-variant install is claimed. Normal Studio image-import
UI is still required. Computer-use screenshots time out and coordinate controls fail, although keyboard command-bar
operations work. No visual acceptance, two-client run or low-quality visual test is claimed. Do not mark the full
sculpted art pass complete based on this validation.

### Original sculptures completed; two-client probes passed

Read the latest section in docs/GALA_ART_REVIEW.md and assets/gala/sculptures/README.md. Original head/face, tailored
jacket/collar, lapels/bow tie, fluted columns, chandeliers and settees now have recipe/Blender/FBX sources and baked CSG
in the saved local place. Bake is EDIT-only and the cache is ReplicatedStorage.GalaArtAssets. No uploaded mesh IDs are
needed; no per-NPC/runtime CSG. Keep player and NPC cosmetics as the SAME welded Models (not Accessories: Humanoids
would double-scale players). NPCs fit after Humanoid/description cleanup. Original joints, native head/torso query
parts and combat hitboxes remain; cosmetic parts are massless/nonqueryable/noncolliding. Size-change connections are
Janitor-owned and stripped with the outfit. No new remotes or public identity metadata.

One-player live parity asserted 201/201/201 rigs/heads/suits. Real StudioTestService two-client/server review returned
ServerPassed; BOTH client logs independently passed HUD, Low/Medium/High settings, spark pool/fade and crowd. Earlier
failures were corrected (NPC cleanup, then player Accessory double-scaling). The repeatable ReviewHarness is explicit
Studio-only and removes its temporary scripts. Scene rebuild is 0 problems; four settees use existing free-space and
NPC reservations. Native decorative pillars retain their collision proxy and chandeliers reuse existing lights.

Texture maps remain unuploaded. Owner expressly approved all 12 PNG uploads in chat, but the separate browser upload
authority gate again returned declined. Do not route around the rejection. Resolve that gate or let the owner upload
normally, then install real Image IDs. Source material pack/installer are ready; no fake/PBR-complete claim is valid.
Viewport screenshots, full mouse-driven combat acceptance and whole-game GPU performance remain owner review items.
## Codex: native Reduce Motion HUD support (19-hud-motion)

CombatHud/CoverController now follow `UiAccessibility.reducedMotion()`, a live read of Roblox's native preference.
Reduced mode uses immediate meter updates, static feedback for the original durations, and EXPOSED text without
fullscreen flash/glow. Recoil, gameplay numbers, cover state and action durations are unchanged. No new remotes.
StyLua, Selene and Rojo build passed. Studio run at 15:30 UTC independently logged both client PASS results and the
server parity PASS. The previous run ended before cold clients loaded; ReviewHarness now allows 45 seconds after
the server check. Require both client results rather than treating ServerPassed as sufficient.
Enabled-mode visual review remains owner-run. Exact one-/two-player steps are in CLIENT_REVIEW_2026-10-25.md.
No new SPEC-QUESTIONs. Ready for Step 19 traversal warnings (main gameplay sequence: Step 9c spectating).

