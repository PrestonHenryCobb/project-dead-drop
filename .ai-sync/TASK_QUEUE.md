# Task queue

Built from `docs/BUILD_ORDER.md`, `docs/STEP8_HANDOFF.md` and `docs/IDEAS_2026-10-24.md`. One step at a time: tickets for
the next step stay `BLOCKED` until the owner starts that step. Owners are proposals; the owner confirms or swaps them.

Status: `TODO`, `IN_PROGRESS (CLAUDE_CODE)` or `IN_PROGRESS (CODEX)`, `READY_FOR_REVIEW`, `DONE`, `BLOCKED`.
Every ticket ends with the `CLAUDE.md` report, `stylua src` and `selene src` clean, and no commit unless the owner asks.

## Step 8: finish weapons (current)
Owner authorization (2026-10-24): Codex may continue client/weapon work across steps where the design and dependencies
allow, and commit each completed change without another confirmation. Keep server ownership/locks intact and document
server handoffs rather than presenting incomplete mechanics as finished. This supersedes the earlier one-ticket stop
and commit-confirmation rules for this development run.

| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| 8.1 | Test pass in Studio: melee (V), takedown from behind (hold V 1.2 s, breaks at 4 studs or when hurt), reload, empty click, fall damage; ziplines, gondola and vents must not cause fall damage. Fix what fails. **Fixed:** falls are now measured by height (the server's copy of a player's Humanoid state reported Landed mid-fall, so a 40-stud drop did nothing); the first shot after a reload is no longer dropped. Takedown breaking when the attacker is hurt is untested (needs 2 players, 8.4). | CLAUDE_CODE | Studio | READY_FOR_REVIEW |
| 8.2 | Reload cancels on a disguise swap (spec 27 #22). **Done:** starting a swap cancels the reload (rounds stay out, client told by AmmoUpdate) and no reload starts during one. Tested in Studio. | CLAUDE_CODE | | READY_FOR_REVIEW |
| 8.3 | Check the combat HUD in play (crosshair, hitmarkers, damage direction, HP and plates, ammo, takedown bar) and fix layout bugs. Do **not** tune view-model poses: Step 8B rebuilds them. Owner reported checks all clear on 2026-10-24. | CODEX | | READY_FOR_REVIEW |
| 8.4 | Two-player fire test: cover exposure on firing, red hitmarker, DamageTaken marker. | Owner with either agent | 2 players | TODO |
| studio-test-loadout | Owner requested the planned Studio-only F8 available-kit / F9 registered-weapon selector. Server validation, owner-only HUD/gun/ammo reset, respawn persistence, no live-server effect. | CODEX | STEP8_QUESTIONS A3; owner request | READY_FOR_REVIEW |
| 8.5 | Remaining 17 weapons, one agent per ticket (8.5a Guise, b Parapet, c Lattice, d Reticle, e Suture, f Feint): `WeaponDefs` entries and client feel by Codex; any new server rule (unique effects in `STEP8_QUESTIONS.md`) as a hand-off to Claude Code in `CombatService`. Includes Parapet's shorter heavy-SMG falloff and Feint's silent pistol replacing the heavy revolver. | CODEX + CLAUDE_CODE | 8.1 | TODO |
| 8.5f-client | Feint pistol audit: delegated 20 damage / 320 RPM / 12+24 ammo, Quiet, HearStuds=12, SoundOffset=8–15 and 0.25 s post-melee recovery preserved; existing shaped pistol model and explicit compact draw/aim response. No heavy revolver restored. Smoke SMG and knives remain unavailable pending server handoff below, with their client models/handling still pending. | CODEX | Owner Studio review; stylua src and selene src clean 2026-10-27 | READY_FOR_REVIEW |
| 8.5f-server-handoff | Claude Code: FeintSmokeSMG needs authoritative last-five-round impact smoke before registration (8 damage, 750 RPM, 32/64 ammo, 2 s reload, 25–60 stud falloff to 55%); use validated pre-shot magazine count and confirmed impact, not client claims. FeintKnives needs server-owned arcing throws, 45 body / 90 head, 0.6 s throw interval, 6 carried / no reserve, silent with no sound-based NPC panic or guard investigation, persistent landed knives and validated pickup with no duplication. Need projectile/impact/pickup contract before matching client prediction/models/handling can be integrated. Owner answers 2026-10-27: each final-five impact makes a 4-stud-wide, 2 s smoke cloud visible to everyone, obscuring sight without damage. Any knife user can recover opponents' landed knives up to 6 carried; knives persist until recovered or round end. Knives use fast/shallow arcs, flares slower/pronounced arcs; exact flight values and pickup reach are Studio tuning. Preserve NPC/player disguise parity and existing team damage rules. | CLAUDE_CODE | Server projectile/status/pickup contract | TODO |
| 8.5a-client | Guise SMG/pistol audit: approved revised stats, shaped native models, Quiet visuals and pistol `AmbushMult=1.5`; explicit SMG/pistol draw and aim response, 0.2/0.3 s post-melee recovery. `stylua src` and `selene src` clean 2026-10-27. Test F8 Guise / F9 SMG or pistol, hip/aim/reload, then V-release followed by held fire. Garrote remains unavailable pending server handoff below. | CODEX | Owner Studio feel review | READY_FOR_REVIEW |
| 8.5a-server-handoff | Claude Code: implement GuiseGarrote authoritative melee contract before registration: 40 swing damage, 0.8 s swing cooldown, 4-stud swing reach; rear takedown 100 damage in 0.8 s, silent with nearby NPC panic only when witnessed. Preserve latest shared takedown acquisition (6.5 studs / 90-degree rear cone) unless owner resolves a weapon-specific exception. Need shared weapon melee fields/action acknowledgement so client uses matching charge/hold/recovery and no firearm ammo/reload. Client garrote model/handling remains pending that contract; no fake firearm definition or selectable stub added. Review existing AmbushMult Covered-or-Suspicious check against Answers Covered-only wording. | CLAUDE_CODE | Server rule and shared contract | TODO |
| 8.5e-client | Suture client audit: approved dual-pistol/medic-shotgun data, existing shaped models, six-pellet request and 1100 hip / 550 aimed akimbo preserved; explicit pistol/shotgun draw and aim response, 0.15/0.65 s post-melee recovery. Full-source stylua src and selene src clean 2026-10-27; concurrent lint blocker resolved. Studio: F8 Suture / F9 pistols or shotgun; confirm alternating hip muzzles, one centred aimed pistol at half rate, one round per six-pellet pull, reload and V-to-fire recovery. Initial handling tuning is a SPEC-QUESTION. | CODEX | Owner Studio review | READY_FOR_REVIEW |
| 8.5e-server-handoff | Claude Code: SutureFlare needs authoritative arcing projectile and impact/status contract before registration/model integration: 55 direct damage, 15 splash within 6 studs, 1 loaded / 12 reserve, 1.6 s reload; burn/light landing area for 5 s and show direct-hit target glow for 4 s to Suture team only. Validate projectile travel/collision, damage/team guards and visibility recipients server-side; provide confirmed impact/expiry so client Janitor can own light/glow cleanup, never mark rigs with identity attributes. Owner answers 2026-10-27: direct target takes 55 total (no added splash), other targets take 15 splash; landing patch is light-only for 5 s. Team glow lasts full 4 s through disguise changes, requires line of sight. Flare uses slower/pronounced arc versus fast/shallow knives; exact flight values are Studio tuning. Flare remains unavailable; model/handling and PostMeleeFireDelay need the real projectile contract. | CLAUDE_CODE | Server projectile/status contract | TODO |
| 8.6 | SMG model in Blender for the owner to upload. | CLAUDE_CODE | Owner uploads | TODO |
| 8.8 | First hit on a Covered or Suspicious agent uses body damage even on the head (SPEC_CHANGES 2026-10-24). **Done** in CombatService (being shot does not expose, so every hit while disguised is body; the hitmarker shows body). Needs the 2-player test (8.4). | CLAUDE_CODE | 8.4 | READY_FOR_REVIEW |
| 8.9 | Per-weapon `PostMeleeFireDelay`: client audit 2026-10-27 confirms fireOnce blocks before ammo/audio/recoil while melee/takedown is pending and until the shared per-weapon delay after acknowledged Strike. All 10 registered firearms have explicit values; missing weapons get values in 8.5 when supported. Server check already exists. `stylua src` and `selene src` clean. Studio melee-to-fire acceptance pending. | CODEX + CLAUDE_CODE | Studio acceptance | READY_FOR_REVIEW |
| 8.10 | Ammo reconciliation in `WeaponController` (found in 8.1). Holding fire through a reload, the client completes the reload on its own clock and fires at once (mag 29), then the server's reload confirmation (`AmmoUpdate` Mag=30, ReloadSeconds=0) overwrites it, so the client counts one round too many. At the end of that magazine it fires one shot (sound, recoil) that the server rejects with Mag=0. Fix: keep the local count when an AmmoUpdate only confirms a reload the client already completed (same Reserve, Mag at or above the local one). | CODEX | | READY_FOR_REVIEW |
| 8.11 | Bullet tracers and muzzle flash for every weapon that is not `Quiet` (the suppressed SMG has neither, STEP8_QUESTIONS). Client only, from the existing data: your own shots from WeaponController's prediction, other players' from `ShotHeard` (Origin, Hit). Per-weapon look in `WeaponDefs`, shared numbers in `GameConfig.Combat.Feedback`. No server or remote changes. Runs alongside 8.5. | CODEX | | READY_FOR_REVIEW |
| 8.7 | Step 8 end report (CLAUDE.md format). | CLAUDE_CODE | 8.1 to 8.6 | TODO |
| 8.12 | Fix client facing and pose stepping to support the classic Motor6D rig now built by RigService, retaining compatibility with AnimationConstraint rigs. StyLua/Selene pass; Studio review pending. | CODEX | | READY_FOR_REVIEW |
| 8.13 | Clean up weapon bindings/connections/view model on teardown; recreate the model on respawn/camera replacement; reject dead-player aim/reload prediction and hide their crosshair. Added tools/CheckClientCombat.luau for real-module frustum/model/pooled-FX assertions in Studio's Client Command Bar. StyLua/Selene/Rojo pass; runtime assertions and playtest remain pending. | CODEX | | READY_FOR_REVIEW |
| 8.5d-client | Reticle folding carbine: complete data, shaped model, semi-auto prediction, no falloff, per-weapon shot look, 0.35 s post-melee recovery. Guise SMG starts at 0.2 s recovery. Remaining Reticle DMR glint and pistol pierce need server integration; no fake selection UI. Test carbine by selecting ReticleCarbine as Combat.DefaultWeapon in a temporary Studio copy before play. Handling/recovery values are initial playtest tuning. | CODEX | Studio review | READY_FOR_REVIEW |
| 8.5d-dmr | Approved Reticle DMR stats, original scoped model, exact 3x optics and cosmetic bolt cycle. Native 45,360 framing checks and two-client selection/respawn/glint regression passed. See docs/CLIENT_REVIEW_2026-10-25.md. | CODEX | STEP8 revised stats; existing server glint/cadence | READY_FOR_REVIEW |
| 8.5c-pdw | Lattice compact PDW with approved revised stats, original model and per-weapon fast draw/aim response. Added automatically to F8; native registry/model/cadence checks and both multiplayer clients passed. Preserves carbine's exceptional near-zero draw. | CODEX | Owner feel review; docs/CLIENT_REVIEW_2026-10-25.md | READY_FOR_REVIEW |
| 8.5-server | **Done (Claude Code):** the server half of the firing-path unique effects, as optional `WeaponDef` fields (see Types): `Pellets` (FireRequest carries a list of exactly that many unit directions), `Burst` {Count, DelaySeconds}, `SpinUp` {StartRPM, Seconds} (held fire; a pause longer than 1.5x the slowest gap restarts it), `AimedRPM` (while RequestDraw is on), `Pierce` {Count, DamageMult}, `AmbushMult` (shot fired while Covered or Suspicious), `ScopeGlint` (rivals with a clear line within 200 studs get `ScopeGlint` {Position, Seconds}), `HearStuds`, `SoundOffset` NumberRange (ShotHeard Origin and NPC panic use the displaced point). New server modules Combat/FireRate and Combat/Ballistics. Rate rules unit-tested; 10 of 10 hits on walking NPCs after the change. | CLAUDE_CODE | | READY_FOR_REVIEW |
| 8.5-client-rules | Client side of 8.5-server: (1) WeaponController follows FireRate exactly (bursts, spin-up and its restart, AimedRPM while aiming) so no shot is predicted that the server refuses; (2) Pellets weapons send a list of directions in one FireRequest (one magazine round per pull); (3) draw the `ScopeGlint` remote (a bright flare at Position for Seconds, refreshed while it keeps arriving); (4) fill each weapon's new fields in WeaponDefs as its agent ticket lands (Reticle: DMR `ScopeGlint = true`, marksman pistol `Pierce = { Count = 1, DamageMult = 0.6 }`; Guise pistol `AmbushMult = 1.5`; Parapet heavy SMG `SpinUp = { StartRPM = 500, Seconds = 1 }` with RPM 750; Lattice burst rifle `Burst = { Count = 3, DelaySeconds = 0.35 }`; Suture pistols `AimedRPM` = half; Feint silent pistol `Quiet`, `HearStuds = 12`, `SoundOffset = NumberRange.new(8, 15)`; shotguns `Pellets`). | CODEX | 8.5-server | READY_FOR_REVIEW |

| 8.5b-client | Parapet heavy SMG reinforced/vented model, slower draw/aim handling, existing spin-up/recovery verified; pump/hammer server handoff below. Full-source stylua src and selene src clean 2026-10-27; concurrent formatting blocker resolved. | CODEX | Studio review; missing server rules below | READY_FOR_REVIEW |

<!-- 8.5b server handoff (CODEX, 2026-10-27): heavy SMG remains fully registered: 10 damage,
500->750 RPM over 1 s, 40/80 ammo, 2.6 s reload, shortened 20-45 stud falloff to 55%,
PostMeleeFireDelay=0.25. Client reinforced/vented model and slower draw/aim response added.
Claude Code: pump shotgun needs authoritative per-shell reload (0.5 s each; 6 loaded/12 reserve),
8 pellets x 11 at 70 RPM, 10-30 stud falloff to 30%, close-majority-pellet stagger/aim flinch,
and the decided two-shot minimum even against unplated agents. Existing reload transfers a whole
magazine and Ballistics has no stagger or aggregate per-pull damage cap. Owner answers 2026-10-27: full-health unplated agents survive one blast including all exposed-head pellets. Within 12 studs, at least 5/8 pellets applies 25% slow for 0.35 s and a small aim bump, without interrupting firing. Aim bump magnitude is Studio tuning.
Hammer needs weapon-specific V rules: 70 swing, 100 after 1 s charge, 1.1 s cadence, 6-stud reach,
no ammo/reload, sideways displacement along the swing (never backwards); owner-approved shove is 3 studs, stopped by walls but allowed over open edges. Current server uses generic melee/charge/takedown rules.
Pump and hammer remain unavailable: WeaponDefs, shaped models and client reload/melee handling must
land together once the shared contract exists; no fake hitscan/whole-magazine substitutes registered.
Studio: fresh solo Play, choose Parapet heavy SMG with F8/F9, inspect Tucked/Ready/RMB, hold LMB
through spin-up, release >0.18 s and retry; test V then fire (no predicted shot until recovery).
Run tools/CheckClientCombat.luau in Client Command Bar and CheckWeaponCadence.luau on Server.
SPEC-QUESTION: heavy-SMG AimBlendRate/PoseSpeed=10 are initial feel tuning for owner playtest.

**Claude Code 2026-10-27: server side of pump and hammer built (READY_FOR_REVIEW, untested in Studio); see `.ai-sync/WEAPON_SERVER_CONTRACTS.md`.**
-->

## Step 8B: feel pass (after Step 8)
<!-- Ticket 8.11 (CODEX, 2026-10-24): ShotVisuals preallocates 64 tracers and 24 flashes under a client-only
workspace folder; Janitor owns the folder/connections. Quiet skips both. WeaponDefs contains default look and
WeaponDef optional overrides; GameConfig.Feedback contains timing, pool sizes and remote muzzle offset.
Own prediction uses ViewModel.Muzzle; ShotHeard uses an approximate held-gun origin. SPEC-QUESTION in
ShotFxController: should tracers be visible beyond shot earshot? No server/Remotes changes.
StyLua/Selene clean; Rojo build and git diff --check pass. Studio visuals unverified. To test Quiet=false without
disk changes, break in client WeaponController before WeaponDefs require, edit the running client copy of
ReplicatedStorage.Shared.Defs.WeaponDefs before it loads (the returned data is frozen), then resume.
Repeat on both clients for Test > Clients 2 > Start; stay within 25 studs since server SMG remains Quiet.
Stop discards runtime changes. Locks released; no commit/push. -->
<!-- Ticket 8.10 (CODEX, 2026-10-24): WeaponController now tracks a locally completed reload and consumes
its matching server confirmation once without restoring rounds already fired. Other corrections still apply;
respawn clears the pending prediction. StyLua and Selene pass (0 errors/warnings); git diff --check passes.
Owner reported 8.10 passes the Studio check on 2026-10-24.
Locks released. Studio check passed per owner; awaiting commit confirmation. No commit made for 8.10. -->
<!-- Ticket 8.3 progress (CODEX, 2026-10-24): static review found the combat vitals overlapping the disguise badge.
Moved vitals above it via GameConfig.Combat.Hud.VitalsBottomPixels; StyLua and Selene pass (0 errors/warnings).
Owner reported the requested Studio HUD checks "all clear" on 2026-10-24. Verification is owner-reported;
agent capture failed twice (FrameArrived timed out; window capture timed out). Locks released; no commit. -->

In this order; each depends on the one before. Decisions: `IDEAS_2026-10-24.md` and `BUILD_ORDER.md` Step 8B.
| Id | Ticket | Owner | Status |
|---|---|---|---|
| 8B.1 | Slimmer, taller bodies for everyone (height 105-115%, width and depth 80-90%); check hit boxes, doors, vents, camera height, NPC pathing height, clothes. **Done:** per-axis ranges in GameConfig.Rig, OutfitDefs, True Form at the middle; bodies measure 5.6 to 6.1 studs; a player walks a horizontal vent with 0.4 to 0.9 studs of headroom; player hit-box height now follows their current size. NPC graph AgentHeight left at 5 (NPCs are server-moved). | CLAUDE_CODE | READY_FOR_REVIEW |
| 8B.2 | Full-body first person: torso, legs and feet visible, head and accessories hidden; real arms hold the gun. Added FirstPersonBodyController with local two-bone Motor6D arm posing on the shared 8 Hz clock; removed duplicate sleeve/hand blocks. Survives outfit changes and respawn. StyLua/Selene/Rojo pass; Studio body/IK/scale review required. | CODEX | READY_FOR_REVIEW |
| 8B.3 | Gun always in frame (poses from real FOV and aspect) and the wall tuck (rays, blocks firing when fully tucked). Implemented against current view model: cached bounds, real-frustum fitting, five wall probes, high-ready tuck, camera-space depth compression, firing gate. StyLua/Selene/Rojo pass; Studio/FOV/wall review pending and recheck after 8B.2 arm rebuild. | CODEX | READY_FOR_REVIEW |
| 8B.4 | Held-item switch: one input layer decides whether fire and aim mean weapon or gadget. Implemented HeldItemController; switching/focus loss cancel inputs, stowed weapon hides while reload/FOV recovery continue. No gadget slots or fake items. Owner authorized independent client work across steps. StyLua/Selene/Rojo pass; Studio review pending. | CODEX | READY_FOR_REVIEW |
| 8B.5 | Movement feel: gravity about 150, longer jump, ground easing for players **and** NPCs. **Done:** GameConfig.Movement (gravity 150, jump height kept at 6.4 so it lasts 0.60 s instead of 0.51 s and reaches nothing new; ease 0.18 s up, 0.15 s down). New MovementController owns walking (Roblox keyboard controls set to Scriptable); NPCs ease with the same numbers in NPC/Movement. Measured in Studio. | CLAUDE_CODE | READY_FOR_REVIEW |
| 8B.6 | Frame stepping: animation 8 a second for everything, other characters' positions 12 a second on the server clock; server rewinds shots to snapped positions. **Done (positions):** shared Util/PositionStep; NPCController draws NPCs at the stepped moment on the server clock; new PositionStepController holds other players between steps; CombatService rewinds to the same moment. 12 of 12 shots at walking NPCs hit. Other players' stepping needs the 2-player test (8.4). Animation stepping is StepAnimationController (8 a second, already built). | CLAUDE_CODE | READY_FOR_REVIEW |
| 8B.7 | Hit-box radius about 1.0 stud. **Done** (GameConfig.Combat.Hitbox.BodyRadius = 1.0). | CLAUDE_CODE | READY_FOR_REVIEW |
| 8B.8 | Others see a gun on a character wearing a True Form look (client-side only, no new server message). WeaponVisualController matches the complete visible True Form body palette on any rig and reuses gun geometry in a client-only folder; disappears on disguise swap. No character markers. DefaultWeapon only until loadouts differ. StyLua/Selene/Rojo pass; 2-player Studio review pending. | CODEX | READY_FOR_REVIEW |

## Decided brief items (SPEC_CHANGES 2026-10-24), built ahead of their step
| Id | Ticket | Owner | Status |
|---|---|---|---|
| B.Q6 | Disguise-swap marker instead of the puff: rivals within Cover.SwapMarkerRange (60, SPEC-QUESTION: tune in play) see a diamond where someone changed disguise for 5/10/15/20 s by tier; the server tells each rival only when they come in range; walls hide it. SwapMarkerService + SwapMarkerController. Server placement and client drawing tested separately in Studio; seeing a rival's marker needs 2 players (8.4). | CLAUDE_CODE | READY_FOR_REVIEW |

## Step 9: downed, revive, elimination, spectate
| Id | Ticket | Owner | Status |
|---|---|---|---|
| 9a | TeamService: mode (Debug.TestMode until the lobby), teams filled in join order, TeamRoster sent only to each team; Solos start with 2 plates. | CLAUDE_CODE | READY_FOR_REVIEW |
| 9b | Downed (spec 14.1, 14.3): InteractService (hold-to-interact framework, kind "Body"), DownedService (down at 0 HP and Exposed; body lies and crawls like a downed NPC, server-moved; shots pass through downed bodies; 30 s bleed-out; hold E: revive a teammate 4 s / execute any other downed body, player or NPC, 2 s; team wipe; Solos eliminated at once; eliminated bodies lie intact then fade), DownedController (crawl input, crawl animation, body targeting, death sound muted). Also fixed: a spawn teleport was counted as a fall (Combat.TeleportStuds). Tested solo: fall down, team wipe, elimination, intact body; executing a downed NPC. **Needs 2 players:** crawling, bleed-out, revive, executing a player. | CLAUDE_CODE | READY_FOR_REVIEW |
| 9b-hud | DownedHudController: server-clock bleed-out countdown, generic body readiness without identity/team assumptions, server-confirmed Revive/Execute hold progress, eliminated state and Janitor cleanup. DownedController body targeting now checks map line of sight. No fake spectating controls. StyLua/Selene/Rojo pass; four-client Duos acceptance pending (two teams, partner alive). | CODEX | READY_FOR_REVIEW |
| 9c | Spectating (SPEC_CHANGES 14.4). **Built, untested in Studio:** SpectateService (server: living teammates first, then any living player or a drone clamped to the ZoneVolume parts, speed-limited, map streamed around the view; filtered spectator chat only eliminated players receive), SpectateController (orbit camera, drone, status line, chat). New remotes SpectateState, SpectatorChat, RequestSpectate, RequestDronePosition, RequestSpectatorChat (rate-limited); config GameConfig.Spectate. Needs 2+ players to see a teammate or rival (8.4). | CLAUDE_CODE | READY_FOR_REVIEW |
| 9d | Agent Tag drop and Rescue: owner approved initial 10-Intel cost through normal spending/vault-progress tradeoff; shared Rescue.Cost updated from obsolete 150 Funds. Functionality not started; still needs Supply Caches/Intel economy (Step 18). | CLAUDE_CODE | BLOCKED |

## Future client review
<!-- Step 9 weapon integration (Codex): WeaponController stops fire/burst/aim/reload prediction and real-arm grip
poses on owner-only Downed/Eliminated messages, restoring eligibility on Revived/spawn. Health > 0 alone is no
longer sufficient. Two-player down/revive testing required. Claude: Guise AmbushMult currently applies while
Suspicious as well as Covered, whereas STEP8_QUESTIONS specifies Covered only; please review that server check. -->
<!-- Additional completed firing paths (Codex): ParapetHeavySMG (500->750 spin-up, 20–45 falloff),
ReticlePistol (40 damage, 2x head, one-person pierce at 60%), SutureShotgun (six 10-damage pellets),
SutureDualPistols (1100 hip / 550 aimed, real two-hand grips, alternating muzzles; aim hides the left gun).
Each has a shaped native model and the decided ammo/reload stats. Default remains GuiseSMG; selection is Step 10.
Shared verified sound assets are reused pending audio tuning. CheckClientCombat covers all eight registered models.
Studio visual/gameplay checks remain required. Do not mark the entire agent ticket DONE: other weapons/effects remain. -->
<!-- 8.5a/8.5f client update: GuisePistol and FeintPistol definitions and shaped models are ready for review.
Owner delegated Feint stats: 20 damage, semi 320 RPM, 12/24 ammo, 1.5 s reload, 35–85 stud falloff to 65%,
0.25 s post-melee delay, Quiet/HearStuds=12/SoundOffset=8–15. Guise keeps 22 damage and AmbushMult=1.5.
ShotFxController honors per-weapon HearStuds. Existing 8.5-server handles both effects. Test either by temporarily
setting Combat.DefaultWeapon in Studio only before Play. No new selection UI or default weapon change. -->
| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| 8.15 | Owner test fixes: hide actual avatar locally; camera-relative cosmetic arm meshes; across-body wall tuck; shared attack gate blocks fire/aim/melee/takedown before feedback or requests and clears queued attacks. Crossed-out OBSTRUCTED reticle replaces weapon crosshair and disguise dot. Removed second tuck filter to keep rendering/gating aligned. Reload/respawn paths preserved. StyLua/Selene/Rojo pass; Studio regression checks and visual retest pending. | CODEX | Owner playtest report | READY_FOR_REVIEW |
| 8.16 | Fix gun/hand drift: cosmetic hands follow the gun's exact rendered grips every frame; persist pose smoothing in camera space; scale first-person geometry and camera offsets to 65% depth while preserving projection and third-person size. Shared wall-tuck gate retained. StyLua/Selene clean; Studio visual review pending. | CODEX | Owner gun placement report | READY_FOR_REVIEW |
| 8.18 | Historical interim tuning: 12 Hz poses / 18 Hz positions. **Superseded by owner request in 8.20:** fully smooth world animation/movement; do not restore stepping. | CODEX | Superseded by 8.20 | READY_FOR_REVIEW |
| 8.19 | Owner screenshot: default camera/player list, no HUD. Reproduced theme resolver's ambiguous assert/parenthesized-assignment as a boolean call; fixed with a named table alias. Same pattern corrected in heavy-SMG and marksman-pistol builders. Official Luau CLI: old resolver fails, fixed resolver passes 9 assertions with actual UI config and datatype fixtures. Studio startup/real-module check still pending. | CODEX | Stop/sync/fresh Play; tools/CheckHudTheme.luau | READY_FOR_REVIEW |
| 8.20 | Owner removes choppy movement for combat: delete pose/position stepping controllers and obsolete shared helper/config; continuously interpolate NPC roots, retain native smooth player replication/animation. Ballistics now rewinds continuous shot time minus target delay with existing clamps. StyLua/Selene/Rojo pass; actual Ballistics timing assertions pass in Luau with engine/history fixtures. | CODEX | Studio smooth-motion / moving-hit acceptance | READY_FOR_REVIEW |
| 8.21 | Owner allows shoulder stock offscreen. ViewModel frames actual visible part vertices plus grip centers, excluding Stock/Butt; full bounds remain for wall depth. Updated eight-weapon FOV/aspect assertions. StyLua/Selene/Rojo pass; Studio visuals/assertions pending. | CODEX | Owner framing review | READY_FOR_REVIEW |
| 8.22 | Co-owned R5/R6 bug fix: shared 6.5-stud/90-degree takedown acquisition, 1.2 s/90 damage; V press starts hold or server charge, release strikes 35/fully charged 50 after 0.75 s; Cancel never strikes. Acknowledged audio/recovery and blue/red progress; lifecycle cancellation; friendly-fire rejection. No new remotes. 29 real-source Luau assertions plus StyLua/Selene/Rojo pass; Studio acceptance pending. | CODEX (coordinated server/client) | Owner melee playtest; Claude review | READY_FOR_REVIEW |
| 8.17 | Generic takedown proximity hint: nearest visible upright rig within current server melee reach/front cone/rear cone; same NPC/player geometry, no identity labels/character decoration; hide while incapacitated, wall-tucked or holding an action. Advisory only; no server reach change. | CODEX | Studio acceptance; range/animation handoff below | READY_FOR_REVIEW |
| 19-client-hud | Owner authorized importing functional HUD now: original drawn icons, shadowed dark panels, health/armor easing and damage pulse, reload progress, compact role/tier/stored-disguise badge, cover/short warnings and alarm pips. Default diagnostics hidden. Uses existing events only; no unbuilt menus/objective/economy state. Report: docs/CLIENT_REVIEW_2026-10-25.md. | CODEX | Owner visual acceptance | READY_FOR_REVIEW |
| 19-map-skins | Shared HudTheme resolver over base layout/behavior, Gala charcoal/brass Field notes skin, startup skin ID and neutral fallback. Palette-only validated immutable overrides; all graphical controllers use the same resolved skin. No runtime map-switch contract invented. | CODEX | Studio owner review | READY_FOR_REVIEW |
| 19-hud-readability | Persistent essentials, contextual prompts/warnings, clear numbers/body text with pixel headings, event-driven feedback and reduced motion. Minimum 1280x720 with readable larger-display scaling. Preserve critical state/timers and gameplay recoil across skins. | CODEX | Typography and motion-setting implementation/review | READY_FOR_REVIEW |
| 19-hud-motion | Follow Roblox Reduce Motion for decorative HUD easing/flashes, preserve authoritative feedback and weapon recoil. | CODEX | Existing HUD and native accessibility preference | READY_FOR_REVIEW |
| 19-hud-scale | Scale panel text/icons/borders and edge spacing together from the approved 1280x720 baseline; preserve angular aiming/marker coordinates and map-skin behavior. | CODEX | 19-hud-readability; owner authorized parallel client work | READY_FOR_REVIEW |
| 19-camera-comfort | Light optional cosmetic camera shake during damage/takedowns, no forced roll/blur. Actual weapon recoil unchanged; respect comfort settings. | CODEX | Settings/feedback implementation and review | TODO |
| 19-menu-structure | Two original interactive layouts (Field desk / Agency rail) cover the approved six sections and Stocks -> Mint. Browser navigation/state/four-width checks passed; no fabricated account data or game integration. docs/mockups/main-menu-review.html and client review report. | CODEX | Owner navigation-layout choice; real gameplay/profile/commerce contracts | READY_FOR_REVIEW |
| 22-range-feedback | Lobby firing range uses actual server-confirmed damage, current body damage for limbs, no new limb multiplier/imported sample numbers. Keep existing plated-target/damage-screen plan. | CLAUDE_CODE server + CODEX UI | Lobby/range implementation in Step 22 | BLOCKED |
| 10-selection-window | Final owner correction: always allow full 30-second selection, no early all-ready deploy; permit loadout revisions before cutoff under team-agent rules and server validation. Mastery 1–10 displays existing roughly ten-match unlock pace, not extra grind. | CODEX UI + CLAUDE_CODE server | Agent-select/mastery contracts | TODO |
| 19-vertical-markers | Use actual generated-map named floor bands; arrows for different floors rather than 10-stud same-room height changes. Preserve existing marker visibility/range/lifetime permissions, with no extra enemy detection. | CODEX with CLAUDE_CODE floor-data support | Authored floor definitions and authorized marker data | READY_FOR_REVIEW |
| 19-traversal-warnings | Clear Cover-break badge for vents, ziplines and moving gondola, with no extra confirmation press; preserve actual Cover rules. | CODEX | Existing traversal prompt integration | READY_FOR_REVIEW |
| 19-coverbreak-feedback | Prebuilt 0.2-second peripheral exposure geometry and compact themed notice; preserves authorized pings and respects Reduce Motion. Source tests and native Studio GUI checks passed: 17 prebuilt descendants, 100 pulses, reduced motion and teardown. Gameplay visual acceptance remains; docs/CLIENT_REVIEW_2026-10-25.md. | CODEX | Studio acceptance; shared replacement of obsolete flash fields for review | READY_FOR_REVIEW |
| 19-client-preview | Two HUD design directions in docs/mockups/combat-hud-review.html: Field notes and Control strip. Preview only; no unbuilt gameplay UI added to src. See .ai-sync/CODEX_CLIENT_HANDOFF.md for commits, API integration, exact Studio checks and remaining server-effect handoffs. | CODEX | Owner design review; gameplay contracts for later features | READY_FOR_REVIEW |
| 19-agent-sense-lifecycle | Fixed client-only Highlight pool, no effects on character models; expiry/stream-out/respawn cleanup and downed-state cancellation. Native pool/parity tests and StyLua/Selene/Rojo pass. Existing server-authorized shimmer policy preserved. | CODEX | Opposing-team visual acceptance; docs/CLIENT_REVIEW_2026-10-25.md | READY_FOR_REVIEW |

## Owner-approved traversal additions (planned)

| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| 7B-secret-exits | Small original set in restricted rooms. Inside/proximity/facing/LOS activation, revalidated by server; matching prompt. Once open anyone passes in either direction. Activation is Discreet under existing witness rules. | CLAUDE_CODE map/server + CODEX UI | Original map design/contracts | TODO |
| 7B-glass-elevators | Working glass elevators using actual floor bands. Server travel/doors/passenger safety and client selector/status. Riding preserves Cover; destination clearance rules remain. | CLAUDE_CODE map/server + CODEX UI | Original map design/contracts | TODO |

## Owner-reported bug assignments

Owner requested this area split while Claude was unavailable. Full source evidence and acceptance tests are in
`.ai-sync/CLAUDE_RETURN_HANDOFF_2026-10-25.md`. These are queued assignments, not completed fixes.

| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| R1-ground | **Done (Claude Code):** measured with a server probe (feet vs floor under every NPC every 0.25 s): 4.9% of samples floated 0.6 to 1.0 studs, nearly all from the cached route on stair flights (sparse Pathfinding waypoints; straight lines over treads), not separation or the client. NavGraph now resamples each stored path every NPC.Graph.SupportSampleStuds (1) and sets each point on the floor found within SupportWindow (3 above, 2 below the line; never follows a hole down); groundBelow ignores non-map parts. Standing spreads, back-aways and downed crawls use NavGraph.standable (wall-free, floored). Result: 0.03% (7 of 22,600 samples, separation pushes on stairs). Graph build about 33 s (was 21.5 s); NPC tick unchanged within noise (12 to 17 ms). | CLAUDE_CODE | Studio | READY_FOR_REVIEW |
| R2-tiers | **Done (Claude Code):** probe found Guests idling in Staff rooms and Staff walking in Security. Causes: arrival spread (3 studs, unchecked) crossing doorways, back-away steps with no tier check, interrupted walks cutting straight to a new route, and node tiers trusted from the authored attribute only. Fixes: node tier = stricter of attribute and zone volume; spreads and back-aways go through NavGraph.standable (tier-checked); reactions keep the unfinished stored path (Movement.interrupt/withResume) and walk it before any new route (flee, investigate, return, next trip). Result: 0 samples above clearance in 30 s with 6 gunshot panics (22,600 samples). | CLAUDE_CODE | Studio | READY_FOR_REVIEW |
| R3-doors | **Done (Claude Code):** DoorService reads each clearance doorway's inside once at start from the zone volumes 3 studs either side (higher tier = inside; server map data, no client claim) and whether either side is a vault room (zone volume name). Players: clearance opens a door from either side (unchanged, symmetric); an ordinary clearance door also opens for anyone on its inside (free exit); vault-wing doors (12) are exempt; NPC and keycard behaviour unchanged. Studio, as a Guest at the Tier 1 door (170, -5): outside stays shut, inside opens, closes again after leaving. 40 doors have free exit. **Owner checks:** 2 Tier-gated doors have the same tier both sides, so no free exit: (-60, -17.5, 80) and (-50, 54.5, -70), map question. I could not reproduce "authorized player can't open from outside": the code was already symmetric; please retest with a scanned disguise of the door's tier and note the door's position if it stays shut. | CLAUDE_CODE | Owner retest of exterior entry | READY_FOR_REVIEW |
| R4-body-animation | **Done (Claude Code), owner visual review needed:** Util/Knockdown classifies the final hit relative to facing (server only): rear or no attacker -> KnockdownForward then prone; front -> KnockdownBackward then supine (head behind, crawls head first pushing with the legs); right/left -> KnockdownLeft/Right (falls away from the hit onto a side, rolls onto the front) then prone. Original procedural poses in Defs/PoseDefs (Knockdown*, Lie*, Crawl*, Dead* for Prone/Supine) name every joint, so walk/idle never shows through; elimination is a 0.5 s settle into a held still pose, not a ragdoll. NPCs: Death.down sets fall/posture/yaw, the crawl waits Downed.Knockdown.Seconds (0.75), AnimationSync sends the names. Players: DownedService does the same, DownedInfo/EliminatedInfo carry Fall/Posture, DownedController plays the same names on the own Animator (replicates); a team wipe or Solos death settles after the fall. Studio: all four NPC directions classified and lying correctly (prone face down, supine face up) with the named tracks playing; player fall -> Forward/Prone -> DeadProne. **Not verified:** how the poses look (no in-play screenshots). Numbers live in GameConfig.Downed.Knockdown and the pose tables. | CLAUDE_CODE | Owner visual review | READY_FOR_REVIEW |
| R5-takedown | **Done (Claude Code); 8.22 rules untouched (29 melee assertions still pass):** two-body hold: the attacker's own Animator plays TakedownGrab while MeleeState Kind=Takedown is active (TakedownBodyController, replicates to everyone); the target struggles (TakedownStruggle): an NPC is put in a new Held state (stands still, ignores panic and bodies, released back to its walk on cancel) and animated through NPCAnimation; a player target gets the new victim-only TakedownVictim remote and plays it on their own character, and can still break free by moving. Result contract: the completing MeleeState (Kind Strike) now carries optional Result = Downed / Eliminated / Hit, read from what the damage actually did (applyDamage returns it). Only Downed or Eliminated may trigger a cosmetic finisher; cancel and Hit never do. Studio: a hold on a talking NPC -> Held/TakedownStruggle -> Strike Result=Downed -> KnockdownForward -> CrawlProne. **Codex follow-up:** consume MeleeState.Result for any finisher and keep it absent from HUD logic that treats Strike as an acknowledgement. **Needs 2 players:** player-victim struggle and break-free. | CLAUDE_CODE with CODEX follow-up | Owner visual review | READY_FOR_REVIEW |
| R7-map-lights | **Done (Claude Code):** owner saw chandeliers floating in the middle of the building. Cause: Build.luau hung a ceiling light at nominal room height in every indoor room piece, including under the atrium void (4 at y=21 with the skylight 48 studs above) and 3 double-height spots. Lights now hang only where map geometry is within CEILING_PROBE_STUDS (1.5) above. Fresh-clone rebuild: 0 problems, 89 lights, 0 floating. **Owner:** save the place in Studio (the rebuild lives in the open place). | CLAUDE_CODE | Owner saves place | READY_FOR_REVIEW |
| crowd-readability | Map-independent gentle clearance/floor-validated ordinary walking variation and shared proximity/ambient head glances for NPC/player rigs. Lighting deferred to map overhaul. Initial two-client animation probe and actual-source route regressions passed; report docs/CLIENT_REVIEW_2026-10-25.md. | CODEX | Owner crowd/edge review | READY_FOR_REVIEW |
| R8-pistol-pose | Centred Suture dual-pistol ready pose, separate lowered two-wrist carry, wider spacing and closer default disguised carry. Native 12,312 framing assertions plus symmetry/hand/aim checks passed. Report docs/CLIENT_REVIEW_2026-10-25.md. | CODEX | Owner visual acceptance | READY_FOR_REVIEW |
| R6-charged-melee | Implemented by Codex in co-owned 8.22: valid press begins hold without initial strike; outside it tap/charge attacks on release, server-timed 35/50 at 0.75 s. Cancellation, cooldown and team guards; shared geometry/HUD. Partial holds use 35 until full (SPEC-QUESTION). | CODEX + CLAUDE_CODE review | Studio acceptance / code review | READY_FOR_REVIEW |
| 21-takedown-cosmetics | First-person shop/Dossier cosmetics play only after server-confirmed down/elimination, not nonlethal 90 damage. No stats/timing advantage. Front/rear/side knockdowns are separate baseline animations for NPCs and players. | CODEX + CLAUDE_CODE | Success contract; shop/progression; original animation assets | BLOCKED |

## Gala art direction (owner-authorized, 2026-10-25)

| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| gala-art-direction | Owner-authorized Direction 1 Gala art, parchment HUD, material import pack, weapons and shared disguise parity; preserve tier colors with cyan accents. | CODEX | Art refs + 2026-10-25 owner direction; docs/GALA_ART_REVIEW.md | READY_FOR_REVIEW (sculptures and verified PBR bindings installed; loading/visual review below) |
| gala-sculptures | Finish owner-approved original sculpted Gala geometry, shared disguises and asset integration; commit completed work. | CODEX | Original geometry baked; two-client probes passed; docs/GALA_ART_REVIEW.md | READY_FOR_REVIEW |
| gala-material-install | Bind owner-uploaded Gala Image IDs, preserve them through generation, install six variants and verify loading/replication in Studio. | CODEX | Owner manual upload complete; docs/GALA_ART_REVIEW.md | READY_FOR_REVIEW (installed; one image awaiting Roblox delivery) |

## Gala re-layout (owner-approved plan, 2026-10-25; docs/MAP_PLAN_RELAYOUT.md)

| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| relayout-1 | Phase 1, the new layout: `Relayout.luau` (generated from the plan by `tools/relayout-layout.cjs`) for the generator, `Build.luau` adapted (per-stair widths, glass elevator shafts, service ladders, Tier 4, terminals, printer spots, secret exits, Package doors, door costs, sky deck on posts), self-check extended, rebuilt in Studio edit mode to 0 problems, screenshots. The old `Layout.luau` stays working until the new one passes. **Done:** fresh-clone rebuild 0 problems (old layout also still 0). Screenshots not taken (Studio window not in front); owner review needed. Section 10 of the plan lists every deviation. | CLAUDE_CODE | Plan approved | READY_FOR_REVIEW |
| relayout-2 | Phase 2, NPC rework: authored lane routes from the layout, capacity-aware doors and stairs, crowd clusters, tiered updates, 60-second wake-up, Staff NPCs on the elevators, the Warden and Curator; measure at 200, 300, 400 NPCs. **Built, playtested and measured in Studio (Warden and Curator included); see `.ai-sync/RELAYOUT_PHASE2_HANDOFF.md`.** | CLAUDE_CODE | relayout-1 reviewed | READY_FOR_REVIEW |
| relayout-art | **For Codex, after the owner approves the new layout:** re-apply the art pass (sculptures, chandeliers, settees, materials, lights) to the rebuilt Gala. The layout moves every room, so the old placements no longer fit. Do not start before the owner says the layout is approved. | CODEX | relayout-1 approved by the owner | BLOCKED |

## Menu suite (owner-started 2026-10-26 from the menu handoffs; contract notes in .ai-sync/MENU_CONTRACT.md)
Pulls parts of Steps 10, 19, 21 and 22 forward at the owner's request. Repo decisions win over the handoff files where
they differ (see MENU_CONTRACT.md "Where the handoffs were corrected").

| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| menu-phase0 | Shared contract: Enums (MenuTab, AgentId, AgentClass, HardwareSlot, AssetRarity, DossierTrack, ItemState), Types (agents, Hardware, loadout, meta profile, agent select, MenuView), GameConfig (Mastery, Meta, Menu, rate limits), Remotes (3 events each way plus 7 RemoteFunctions, RemoteService.onInvoke, RemoteController.invoke), new Defs/AgentDefs, WeaponDefs.getForAgent/isValidForAgent, client/Menu/MenuTheme. Lint clean; checked in Studio from a scratch copy of Shared (all modules require, 18 Hardware items in slot order, 10 built, validity checks, MenuTheme builders). A full Play boot waits for the Rojo plugin to reconnect. | CLAUDE_CODE | | READY_FOR_REVIEW |
| menu-shell | MenuController (header, six tabs with LB/RB and Q/E, Stocks/Credits, footer, Backspace/B back, scaling to the window, HUD hidden while open, views loaded from Menu/LobbyViews and Menu/Views with bad ones skipped), MenuStage (client-only walnut/brass room, True Form rig holding the Hardware, camera framings), PlayLobbyView, PreDeployView, LobbyState. **Playtested solo in Studio 2026-10-26:** free picks, queue, loadout, Deploy, 30 s agent select with mastery/in-development locks, lock-in, spawn with the locked weapon, menu closes and HUD returns; Codex tabs mount; keyboard section switching; no new console errors. Integration pass 2026-10-26: header fits at 1280 (tab and bumper widths in GameConfig.Menu), operative hidden on screens that do not call focusAgent, Agents camera shows the whole body, full 30 s select with revisions at 12 s and 26 s verified, spawn with the last confirmed weapon verified. Found by reading the 2-player cases: two teammates who never locked in both kept the same agent at the cutoff; LobbyService.resolveLoadouts now gives each member a distinct agent (locked picks first, then join order, first free owned agent as the substitute), and the select screen moves a teammate off an agent that was just taken. Still needs a real 2-player run (my tools cannot see local-server clients). Known gap: a teammate who deploys after the other has already spawned is not checked against them (Step 10 match flow). | CLAUDE_CODE | menu-phase0 | READY_FOR_REVIEW |
| menu-services | MetaProgressionService (in-memory profile, one free pick per class, loadout validation: owned agent, own built Hardware, mastery; Dossier/Black Market/Mint answer NoCatalogue until designed) and LobbyService (full 30 s agent select per team, revisable picks, first lock keeps the agent, equip and spawn at the cutoff; RigService.spawn, CombatService.setLoadoutWeapon). Debug.MenuOnJoin false restores the old straight-in spawn. Playtested with menu-shell. Saving is Step 21. | CLAUDE_CODE | menu-phase0 | READY_FOR_REVIEW |
| menu-views | AgentsView, HardwareInspectorView, AssetsCodexView, DossiersView, BlackMarketView, ProfileView, MintModalView as MenuView modules in src/client/Menu/Views. Read MENU_CONTRACT.md first. | CODEX | menu-phase0 | READY_FOR_REVIEW |
| menu-views-fixes | **Done (2026-10-26):** token-sized armory action footer; content-measured Treasury; persistent Assets/Profile scroll cues with reachable last rows. Existing Dossier/right-edge and banner-contrast fixes verified. StyLua/Selene clean on the five changed Views/Components files. Studio Edit: CheckMenuViews **400 PASS**; additional in-memory bounds/scroll/contrast run **469 PASS** at 1280x720. Studio had stale source; synced only the five owned modules before the passing runs. No MenuController, MenuStage, MenuTheme, LobbyViews, server, shared contract or test-file changes; no invented content. No changes requested from Claude. | CODEX | menu-shell | DONE |
| menu-art-pass | Owner requests replacing placeholder lobby graphics with the supplied Gemini-inspired visual direction. Native Deco stage, original scalable illustrations, readable illustrated panels; preserve working systems. Implemented with 400 native checks and 21 session assertions; visual capture unavailable. Report: docs/MENU_ART_PASS_2026-10-26.md. | CODEX | Owner request; menu-views-fixes | READY_FOR_REVIEW |

## Step 10: match loop (owner: "no playtest, take the reins", 2026-10-27; contract in .ai-sync/MATCH_CONTRACT.md)

| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| 10a | MatchService phase machine (spec 2: Lobby, Insertion, Infiltration, VaultBreach, PackageHeist, Overtime, Results), fill rules (3.1), insertion freeze, forced vault unlock at 6:00, 14:00 main timer, Mission Failed, Results then back to the lobby; LobbyService hands ready teams to it; PhaseChanged payload in Types (PhaseData). **Built, untested in Studio.** | CLAUDE_CODE | | READY_FOR_REVIEW |
| 10b | MatchController: phase banner, black screen and briefing card on Insertion, main timer, results scoreboard, lobby wait text. Read MATCH_CONTRACT.md first; server complete, no server change needed. | CODEX | 10a | READY_FOR_REVIEW |
| 10c | Teammate markers: coloured diamond over living teammates through walls plus outline, from TeamRoster and Lobby.TeamColors, client only, nothing on characters. | CODEX | 10a | READY_FOR_REVIEW |
| 11a | IntelService + IntelController (Step 11): station ids, hold-to-hack through InteractService with per-team once-only use and 20 s saved progress, tier and sight checks, Suspicious-if-witnessed, team balance + spend(). Intel no longer unlocks the vault (re-layout; see 12a). Contract: .ai-sync/INTEL_CONTRACT.md. **Built, untested in Studio.** | CLAUDE_CODE | 10a | READY_FOR_REVIEW |
| 11b | Intel HUD: team balance, taken-station state, hold progress. Read INTEL_CONTRACT.md; no server change. | CODEX | 11a | READY_FOR_REVIEW |
| 12a | VaultService (Step 12, re-layout rules): 3 of 5 vaults active per match with a terminal on each dais, server-wide per-terminal hack by standing on the dais (1.25 %/s, x1.25 with 3 intel, paused when contested, Exposed on the dais), Vault Breach on the first hack or at 6:00, all 3 hacked unlocks the Sanctum elevator and starts the Package Heist. Contract: .ai-sync/VAULT_CONTRACT.md. **Built, untested in Studio.** | CLAUDE_CODE | 10a, 11a | READY_FOR_REVIEW |
| 12b | Vault HUD: terminal progress bars with CONTESTED, markers at the terminals during Vault Breach. Read VAULT_CONTRACT.md; no server change. | CODEX | 12a | READY_FOR_REVIEW |
| 13a | PackageService + ExtractionService + PackageController (Step 13): Package pickup/carrier rules/pass/drop/return/pings, extraction sites (call, 45 s or 20 s countdown, beacon, hover, green zone, 3 s channel), win via MatchService.finish, Overtime (90 s cap, 10 s drop grace) from the main timer when the Package is held. Contract: .ai-sync/PACKAGE_CONTRACT.md. **Built, untested in Studio.** | CLAUDE_CODE | 12a | READY_FOR_REVIEW |
| 13b | Package/extraction/overtime HUD: package and ping markers, extraction countdown, zone and channel, overtime timer. Read PACKAGE_CONTRACT.md; no server change. | CODEX | 13a | READY_FOR_REVIEW |
| 13c | Extraction presentation: helicopter at Hover, 5 s cinematic at Extracted, MISSION SUCCESS/FAILED. | CODEX | 13a | READY_FOR_REVIEW |
| 13B-a | Bots, first slice (owner chose crowd-NPC bots): BotService/BotRegistry fill the lobby with rival teams that take Intel stations and stand on vault terminals (contesting humans); no shooting, Package or win yet. Contract: .ai-sync/BOT_CONTRACT.md. **Tested solo in Studio.** | CLAUDE_CODE | 13a | READY_FOR_REVIEW |
| 13B-b | Bots fight and extract: bots carry the Package (paying the Package door in Intel), call and complete extraction (a bot team can win), and shoot Exposed humans in sight (CombatService.botFire). Contract: .ai-sync/BOT_CONTRACT.md. **A bots-only match ran to a bot win in Studio.** | CLAUDE_CODE | 13B-a | READY_FOR_REVIEW |
| 14 | Security (spec 18): AlarmService, CameraService (sweep, lock-on, hack, shoot, Camera Room terminal), LaserService (grids, fuse boxes), keycard door lockpicking and Lockdown seal, camera and interact controllers. Contract: .ai-sync/SECURITY_CONTRACT.md. Tested in Studio except shooting a camera. | CLAUDE_CODE | 13B-b | READY_FOR_REVIEW |
| 14b | Security HUD: alarm level pips and Lockdown banner, Camera Room 4-feed view, hold prompts for camera/fuse box/terminal/lockpick. Read SECURITY_CONTRACT.md; no server change. | CODEX | 14 | READY_FOR_REVIEW |
| 16a | Agents: AbilityService + AbilityController (Q, cooldown via CooldownUpdate) and Guise (Quick Change, Two Faces: 2 slots, 0.6 s scan). Contract: .ai-sync/ABILITY_CONTRACT.md. **Tested solo in Studio.** | CLAUDE_CODE | 15 | READY_FOR_REVIEW |
| 16b | Agents: Parapet (Riot Wall shield in Combat/Shields, stopped shots and projectiles; Plated: 2 starting plates) and ShieldController. Contract: .ai-sync/ABILITY_CONTRACT.md. **Tested solo in Studio.** | CLAUDE_CODE | 16a | READY_FOR_REVIEW |
| 16c | Agents: Lattice (Sparrow Drone: flight, hacks from the drone, tagging, 40 HP; Wired: 25% faster hacks) and DroneController. Contract: .ai-sync/ABILITY_CONTRACT.md. **Tested solo in Studio except tagging.** | CLAUDE_CODE | 16b | READY_FOR_REVIEW |
| 16d | Agents: Reticle (Tracer Glass cone highlight for her only; Still Water: quiet scope, half fall damage). Contract: .ai-sync/ABILITY_CONTRACT.md. **Tested solo in Studio except the glow and the suspicion effect.** | CLAUDE_CODE | 16c | READY_FOR_REVIEW |
| 16e | Agents: Suture (Mend Field first-aid kit heals 12 HP/s; Triage: teammate regen and 2 s revive). Contract: .ai-sync/ABILITY_CONTRACT.md. **Tested solo in Studio: Mend Field. Triage and revive need a teammate.** | CLAUDE_CODE | 16d | READY_FOR_REVIEW |
| 16f | Agents: Feint (Double decoy NPC, Smoke and Mirrors ping offset and 0.3 s disguise). Completes the six agents. Contract: .ai-sync/ABILITY_CONTRACT.md. **Tested solo in Studio except the ping offset.** | CLAUDE_CODE | 16e | READY_FOR_REVIEW |
| 17a | Gadgets: GadgetService + GadgetController (keys 1 to 3, equip/deploy/alternate through HeldItemController), GadgetDefs, loadout GadgetIds, Med Injector, Plate Pack (and Plated's faster plates). Contract: .ai-sync/GADGET_CONTRACT.md. **Tested solo in Studio.** | CLAUDE_CODE | 16f | READY_FOR_REVIEW |
| 17-hud | Gadget bar HUD (the two gadgets by `GadgetDefs` category shape and accent from docs/GADGETS_DRAFT.md, charges, which is held, from `GadgetController.state()`), and a gadget picker in agent select that sends `GadgetIds` in the lock-in `LoadoutRequest`. Client only; read GADGET_CONTRACT.md. | CODEX | 17a | TODO |
| 16-hud | Ability cooldown HUD (name, ready/countdown from `AbilityController.cooldown()`) and every disguise slot, including empty entries. Server-time deadline, static Reduce Motion-safe presentation and one/two-slot layout checks. Client only. | CODEX | 16a | READY_FOR_REVIEW |
| 15 | Security NPC combat (spec 18.5): GuardService (engage rules, pursuit, accuracy falloff, chase limit, recall), camera alert to the 2 nearest guards, Alert speed 14, Heightened extra guards, Lockdown engagement. Contract: .ai-sync/GUARD_CONTRACT.md. **Tested solo in Studio: engage, shots with falloff, give-up, Alert speed, Heightened extras.** | CLAUDE_CODE | 14 | READY_FOR_REVIEW |

## Waiting on the owner

All 35 prompt-review topics are answered or explicitly preserved. Owner priority: reported bugs first, then combat/
loadouts. Remaining owner work is Studio acceptance/tuning; do not repeat resolved interview questions.
<!-- Codex integration note: 06357ec includes Claude's concurrent GameConfig edits for 8B.1/8B.7
(Height/Width scale ranges and Hitbox.BodyRadius=1.0), as well as Codex's Combat.Presentation section.
The associated OutfitDefs/History changes were left for Claude to commit. Do not reapply those config changes. -->
<!-- c1663e9 also includes Claude's concurrent Movement and Controls config hunks for 8B.5. Associated movement
implementations remain Claude's work; do not reapply the config. Codex client post-melee gating now consumes
WeaponDef.PostMeleeFireDelay and blocks while a server-confirmed takedown is active. -->
- The brief's answers (`docs/IDEAS_2026-10-24_BRIEF.md`) are decided; each lands in the step its table names. Only 8.8 is
  ticketed now. Step 16 needs 12 new Talents and 12 new Instincts designed with the owner first.
- The Deceive Inc. tutorial videos for Step 13C (`IDEAS_2026-10-24.md` Q10).

## Six-weapon client integration (Codex, 2026-10-27)

Extends server commit 8750cdf using WEAPON_SERVER_CONTRACTS.md. These new rows supersede older client notes that say
these six weapons are unavailable. All six entries moved from PendingWeaponDefs to WeaponDefs, in the owner's order.

| Id | Client work | Owner | Needs | Status |
|---|---|---|---|---|
| 8.5a-garrote-client | Two-handle wire model, no ammo panel or firearm requests, weapon melee cooldown and server Seconds bar; 0.15 s recovery. | CODEX | Studio acceptance | READY_FOR_REVIEW |
| 8.5b-pump-client | Pump model/cycle, 8-direction request, per-shell prediction/reconciliation, due-shell fire interrupt and Stagger aim bump; 0.65 s recovery. | CODEX | Studio acceptance | READY_FOR_REVIEW |
| 8.5b-hammer-client | Two-hand hammer model, charge pose, weapon cooldown, server Seconds bar, no ammo or firearm requests; 0.8 s recovery. Existing MovementController owns shove. | CODEX | Studio acceptance | READY_FOR_REVIEW |
| 8.5e-flare-client | Signal pistol model, predicted flight adopted by Own launch, authoritative impact lights and LOS-only team glow through disguise changes; 0.6 s recovery. | CODEX | Studio acceptance | READY_FOR_REVIEW |
| 8.5f-smoke-client | Chambered SMG model, automatic handling, server SmokeCloud rendering and inside-cloud veil; 0.2 s recovery. | CODEX | Studio acceptance | READY_FOR_REVIEW |
| 8.5f-knives-client | Knife model/flight, silent prediction, six-round carry with no reload; existing server LandedKnife/pickup prompt retained unchanged; 0.35 s recovery. | CODEX | Studio acceptance | READY_FOR_REVIEW |

Validation: StyLua and Selene clean on every changed Luau file; 204 real-source Luau assertions exercise firing,
melee cooldowns, shell updates/interrupts, projectile adoption, light/smoke expiry, glow occlusion/rebinding, bounded
allocation/cleanup and model structure. Rojo build passes. Engine framing and multiplayer input remain untested.
Full Studio instructions, files and limitations: docs/WEAPON_CLIENT_REVIEW_2026-10-27.md.

Claude handoff (existing contract gaps, not silently fixed): NPC pump slow/hammer shove differ from players;
smoke remains visual-only for server sight/scans/Agent Sense; round end must clean landed knives; pickup prompt
still shows for non-knife users. No additional event/field mismatch found in the reviewed server paths.
Initial spread/recoil/pose/recovery and smoke appearance remain Studio tuning (SPEC-QUESTION).

## Client weapon hardening — owner continuation, 2026-10-27

Owner authorizes continuing without a playtest while Claude works concurrently. Codex owns local knife-prompt
eligibility and accurate melee/projectile armory descriptions; server contracts and gameplay remain Claude's.
| Id | Work | Owner | Status |
|---|---|---|---|
| 8.5-client-hardening | Local knife prompt eligibility/lifecycle; armory text derived from actual weapon definitions; changed-file StyLua/Selene clean, 221 actual-source assertions and Rojo build pass. No Studio playtest per owner. | CODEX | READY_FOR_REVIEW |

Codex continuation result: KnifePickupController watches the server LandedKnives folder and enables local prompts
only for a live knife user below the carrying cap. Stream-out/controller teardown restores original prompt state;
server-disabled prompts stay disabled. No pickup requests, knife reparenting or character decoration added.
WeaponSummary derives armory text from Melee/Projectile/Pellets/ReloadPerShell; knives no longer claim firearm
reloads and melee details now show charged/rear-hold damage. Smoke/server sight and NPC parity remain unchanged.

Concurrent work: Claude has locked the Step 10a match services and shared contract. Codex has not touched those files.
Next coordination: Claude should publish the stable 10a client event/state contract in .ai-sync before the client
adds match-phase/objective UI. Keep continuing without a Studio playtest as the owner requested; no fake round state.

## Match client handoff (Codex 10b/10c, 2026-10-27; no playtest)

MatchController and MatchPresentation render the server phase/clock, private insertion brief/fade, banner, lobby
wait and results roster. TeammateMarkerController draws only private-roster living teammate diamonds/outlines in
client-owned instances and follows respawns; no character decoration. WeaponController now suppresses insertion
prediction and clears held attacks without changing downed/eliminated state. MatchHud config is presentation-only.
Changed files pass StyLua/Selene; 39 match and 225 weapon actual-source assertions pass; Rojo build passes.
No Studio playtest per owner. Full files/acceptance/gaps: docs/MATCH_CLIENT_REVIEW_2026-10-27.md.
Next: queued Intel/Vault client HUD from Claude's published contracts; keep server work and locks with Claude.


## Intel/Vault HUD handoff (Codex 11b/12b, 2026-10-27; no playtest)

IntelHudController shows the private balance, taken count, LOS/range-limited taken-station checkmarks and acknowledged
Hack progress. VaultHudController shows only disclosed VaultBreach terminal snapshots, contested/hacked bars and
world markers until hacked; bars wait out the phase banner. ObjectivePresentation does not predict objective progress
or advance phases and clears prior-round secrets on Lobby. DownedHud filters unrelated interaction holds.
Changed-file StyLua/Selene clean; 28 objective actual-source assertions and Rojo build pass. No Studio playtest.
Known limits: native layout/replication acceptance remains unverified; server contracts own station availability,
terminal positions/rate and match transitions. No new gameplay decision or additional shared contract was introduced.
Next: Package/extraction HUD and presentation against .ai-sync/PACKAGE_CONTRACT.md.


## Package client continuation (Codex, 2026-10-27; PACKAGE_CONTRACT.md)

| Id | Client work | Owner | Status |
|---|---|---|---|
| 13b | Package/resting marker and strictly expiring rival pulses, carrier/drop hint, extraction/channel HUD and overtime timer. | CODEX | READY_FOR_REVIEW |
| 13c | Client-only native extraction aircraft at Hover/Open, five-second extraction presentation, server Results success/failure copy. | CODEX | READY_FOR_REVIEW |
## Package/extraction client handoff (Codex 13b/13c, 2026-10-28; no playtest)

PackageHudController consumes only per-player PackageState and ExtractionState; resting markers and rival pulses
expire without inferring any carrier identity/position. Real InteractState labels from server handlers drive objective
hold bars. Native client-only aircraft at Hover/Open rises during Extracted; server Results owns success/failure.
MatchPresentation now uses EndsAt for Overtime. WeaponController independently freezes prediction during extraction.
Changed-file StyLua/Selene and Rojo build pass. Actual-source suites: 228 weapon + 40 match + 28 objective + 29 Package
assertions = 325 total. No Studio playtest per owner. Detailed files, gaps, source checks and next Claude prompt:
docs/CLIENT_LOOP_REVIEW_2026-10-28.md. No gameplay questions added; presentation values remain tuning.
Contract detail for Claude: InteractState.Kind is the handler label (Take the Package / Pass the Package / Call
extraction / Extract), not the RequestInteract kind. Extracted has no new cinematic timestamp and retains the previous
Open EndsAt; cosmetic fade therefore starts at event receipt for configured CinematicSeconds and stops on Results.
Do not use that stale EndsAt as a cinematic deadline. Optional server timestamp handoff for tighter visual sync.


Owner continuation 2026-10-28: playtest reported complete; individual checks/outcomes were not specified. Codex is continuing queued HUD readability and full-registry bootstrap regression coverage. No tickets automatically marked DONE.


## Client readability continuation (Codex, 2026-10-28)

Owner reports playtest complete; individual outcomes not specified and no prior ticket automatically marked DONE.
Source-confirmed collisions fixed: Intel below Alarm; exposure/cover warnings in the right stack; wrapped/scaled
disguise toasts in the left stack. No gameplay/server changes. Full-module agent/weapon registry cold-load checks
now catch both historical Hardware ID boot failures and validate all 16 registered models/definitions.
Changed-file StyLua/Selene, 998 source assertions and Rojo build pass. Full-source StyLua initially saw Claude's
concurrent NPCService formatting; that WIP was not changed. New native visual acceptance remains pending.
Files, validation, later visual checks and next Claude prompt: docs/CLIENT_READABILITY_REVIEW_2026-10-28.md.


## Named-floor marker handoff (Codex, 2026-10-28)

19-vertical-markers: FloorBands/FloorMarkerController read existing generated Zone_<level>_T<tier>_<room> bounds;
private teammate and revealed vault/Package/extraction captions show arrows only across distinct authored floors.
Same-storey height changes, unknown/ambiguous data and expired pulses never invent a floor or new disclosure.
No server changes, character decoration or marker permission/range/lifetime changes. Source checks and Rojo pass;
1,077 assertions across floor/data/weapon/match/objective/Package suites pass. Native visuals remain unverified.
Full files/limits/acceptance: docs/FLOOR_MARKER_REVIEW_2026-10-28.md. Claude bot work is independent; no handoff needed.

## Package input continuation (Codex 13b, 2026-10-28)

READY_FOR_REVIEW: PackageController no longer captures E at unrelated extraction terminals, above/below the actual
pad or for rejected same-team repeat calls. Objective E/X and held requests respect phase, local life state, text
and window focus, extraction freeze and teardown. Server remains authoritative; no server/shared-contract edits.
82 new actual-source input assertions pass; 1,159 total across input/data/weapons/match/objectives/Package/floors.
StyLua, Selene and Rojo pass. Native input ordering/networking remains for Studio acceptance. No new SPEC-QUESTION.
Files, later Studio checks and limits: docs/PACKAGE_INPUT_REVIEW_2026-10-28.md. Claude bot work needs no handoff.


## Intel input continuation (Codex 11b, 2026-10-28)

READY_FOR_REVIEW: Intel contextual E/glints now respect phase, local life state, input focus, camera/character loss
and extraction freeze. Key press revalidates target; stream-out cancels held hacks; server-completed holds release
without spurious cancellation. Janitor owns subscriptions, visuals, input and caches. Server timing/rewards/clearance
and existing station LOS policy unchanged. 104 new actual-source assertions; 1,263 across all eight checked suites.
StyLua, Selene and Rojo pass; native rendering/input/network acceptance pending. No new SPEC-QUESTION or bot handoff.
Files and Studio checks: docs/INTEL_INPUT_REVIEW_2026-10-28.md.


## Body input continuation (Codex 9b, 2026-10-28)

READY_FOR_REVIEW: contextual revive/execute input revalidates bodies and respects phase/life/focus/cinematic state.
Held actions cancel once; server completion releases locally. All subscriptions/action bindings/tracks are cleaned up;
delayed death poses cannot survive respawn/round end/teardown. Existing generic NPC/player body discovery preserved.
93 new actual-source assertions; 1,356 across nine checked suites. StyLua, Selene and Rojo pass. Native animation,
network/input acceptance remains for Studio. No SPEC-QUESTION or security handoff. docs/BODY_INPUT_REVIEW_2026-10-28.md.


## Security client (owner-requested 14b, 2026-10-28)

14b READY_FOR_REVIEW: four cumulative alarm pips (0–3) and persistent Lockdown in the existing HudLayout slot;
contextual security target prompts and server-acknowledged hold progress; up to four working-camera ViewportFrames
near CameraTerminal, with automatic/manual pages and Reduce Motion. Live streamed visual copies are sanitized,
bounded, occlusion-checked and fully released when hidden. No server files/remotes or character metadata changed.
50 security source assertions and all 1,406 assertions across ten suites pass; StyLua, Selene and Rojo pass.
Native appearance, streaming completeness and performance need Studio acceptance. No new SPEC-QUESTION.
Full files, limitations and Studio checks: docs/SECURITY_CLIENT_REVIEW_2026-10-28.md.

## Ability/disguise HUD handoff (Codex 16-hud, 2026-10-28)

AbilityHudController reads AbilityController.cooldown(), shows the configured key/name and server-time READY/countdown,
and hides outside matches or before fresh confirmed data. DisguiseController renders every ordered Slots entry,
including false/empty slots, with reusable numbered rows and dynamic badge height. No server/shared-contract changes.
50 new actual-source assertions; 1,456 across eleven checked client suites. StyLua, Selene and Rojo pass.
Native Studio typography/timing acceptance remains. No new SPEC-QUESTION. docs/ABILITY_HUD_REVIEW_2026-10-28.md.
