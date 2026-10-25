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
| 8.5 | Remaining 17 weapons, one agent per ticket (8.5a Guise, b Parapet, c Lattice, d Reticle, e Suture, f Feint): `WeaponDefs` entries and client feel by Codex; any new server rule (unique effects in `STEP8_QUESTIONS.md`) as a hand-off to Claude Code in `CombatService`. Includes Parapet's shorter heavy-SMG falloff and Feint's silent pistol replacing the heavy revolver. | CODEX + CLAUDE_CODE | 8.1 | TODO |
| 8.6 | SMG model in Blender for the owner to upload. | CLAUDE_CODE | Owner uploads | TODO |
| 8.8 | First hit on a Covered or Suspicious agent uses body damage even on the head (SPEC_CHANGES 2026-10-24). **Done** in CombatService (being shot does not expose, so every hit while disguised is body; the hitmarker shows body). Needs the 2-player test (8.4). | CLAUDE_CODE | 8.4 | READY_FOR_REVIEW |
| 8.9 | Per-weapon `PostMeleeFireDelay` scaled to weapon strength (brief Q14): field in `WeaponDefs` (Codex), enforced on the server in `CombatService` (Claude Code). Values set case by case with each agent's weapons in 8.5. **Server side done:** `Types.WeaponDef.PostMeleeFireDelay` (optional) and the check in `onFire` (a refused shot gets an AmmoUpdate correction). **Left for Codex:** the client must wait the same delay before predicting a shot, and the values in `WeaponDefs` with 8.5. | CODEX + CLAUDE_CODE | 8.1 | IN_PROGRESS (CODEX) |
| 8.10 | Ammo reconciliation in `WeaponController` (found in 8.1). Holding fire through a reload, the client completes the reload on its own clock and fires at once (mag 29), then the server's reload confirmation (`AmmoUpdate` Mag=30, ReloadSeconds=0) overwrites it, so the client counts one round too many. At the end of that magazine it fires one shot (sound, recoil) that the server rejects with Mag=0. Fix: keep the local count when an AmmoUpdate only confirms a reload the client already completed (same Reserve, Mag at or above the local one). | CODEX | | READY_FOR_REVIEW |
| 8.11 | Bullet tracers and muzzle flash for every weapon that is not `Quiet` (the suppressed SMG has neither, STEP8_QUESTIONS). Client only, from the existing data: your own shots from WeaponController's prediction, other players' from `ShotHeard` (Origin, Hit). Per-weapon look in `WeaponDefs`, shared numbers in `GameConfig.Combat.Feedback`. No server or remote changes. Runs alongside 8.5. | CODEX | | READY_FOR_REVIEW |
| 8.7 | Step 8 end report (CLAUDE.md format). | CLAUDE_CODE | 8.1 to 8.6 | TODO |
| 8.12 | Fix client facing and pose stepping to support the classic Motor6D rig now built by RigService, retaining compatibility with AnimationConstraint rigs. StyLua/Selene pass; Studio review pending. | CODEX | | READY_FOR_REVIEW |
| 8.13 | Clean up weapon bindings/connections/view model on teardown; recreate the model on respawn/camera replacement; reject dead-player aim/reload prediction and hide their crosshair. Added tools/CheckClientCombat.luau for real-module frustum/model/pooled-FX assertions in Studio's Client Command Bar. StyLua/Selene/Rojo pass; runtime assertions and playtest remain pending. | CODEX | | READY_FOR_REVIEW |
| 8.5d-client | Reticle folding carbine: complete data, shaped model, semi-auto prediction, no falloff, per-weapon shot look, 0.35 s post-melee recovery. Guise SMG starts at 0.2 s recovery. Remaining Reticle DMR glint and pistol pierce need server integration; no fake selection UI. Test carbine by selecting ReticleCarbine as Combat.DefaultWeapon in a temporary Studio copy before play. Handling/recovery values are initial playtest tuning. | CODEX | Studio review | READY_FOR_REVIEW |
| 8.5-server | **Done (Claude Code):** the server half of the firing-path unique effects, as optional `WeaponDef` fields (see Types): `Pellets` (FireRequest carries a list of exactly that many unit directions), `Burst` {Count, DelaySeconds}, `SpinUp` {StartRPM, Seconds} (held fire; a pause longer than 1.5x the slowest gap restarts it), `AimedRPM` (while RequestDraw is on), `Pierce` {Count, DamageMult}, `AmbushMult` (shot fired while Covered or Suspicious), `ScopeGlint` (rivals with a clear line within 200 studs get `ScopeGlint` {Position, Seconds}), `HearStuds`, `SoundOffset` NumberRange (ShotHeard Origin and NPC panic use the displaced point). New server modules Combat/FireRate and Combat/Ballistics. Rate rules unit-tested; 10 of 10 hits on walking NPCs after the change. | CLAUDE_CODE | | READY_FOR_REVIEW |
| 8.5-client-rules | Client side of 8.5-server: (1) WeaponController follows FireRate exactly (bursts, spin-up and its restart, AimedRPM while aiming) so no shot is predicted that the server refuses; (2) Pellets weapons send a list of directions in one FireRequest (one magazine round per pull); (3) draw the `ScopeGlint` remote (a bright flare at Position for Seconds, refreshed while it keeps arriving); (4) fill each weapon's new fields in WeaponDefs as its agent ticket lands (Reticle: DMR `ScopeGlint = true`, marksman pistol `Pierce = { Count = 1, DamageMult = 0.6 }`; Guise pistol `AmbushMult = 1.5`; Parapet heavy SMG `SpinUp = { StartRPM = 500, Seconds = 1 }` with RPM 750; Lattice burst rifle `Burst = { Count = 3, DelaySeconds = 0.35 }`; Suture pistols `AimedRPM` = half; Feint silent pistol `Quiet`, `HearStuds = 12`, `SoundOffset = NumberRange.new(8, 15)`; shotguns `Pellets`). | CODEX | 8.5-server | TODO |

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
| 9.x | Split into tickets when the owner starts Step 9 (spectator rules are in `SPEC_CHANGES.md`). | | BLOCKED |

## Future client review
<!-- 8.5a/8.5f client update: GuisePistol and FeintPistol definitions and shaped models are ready for review.
Owner delegated Feint stats: 20 damage, semi 320 RPM, 12/24 ammo, 1.5 s reload, 35–85 stud falloff to 65%,
0.25 s post-melee delay, Quiet/HearStuds=12/SoundOffset=8–15. Guise keeps 22 damage and AmbushMult=1.5.
ShotFxController honors per-weapon HearStuds. Existing 8.5-server handles both effects. Test either by temporarily
setting Combat.DefaultWeapon in Studio only before Play. No new selection UI or default weapon change. -->
| Id | Ticket | Owner | Needs | Status |
|---|---|---|---|---|
| 19-client-preview | Two HUD design directions in docs/mockups/combat-hud-review.html: Field notes and Control strip. Preview only; no unbuilt gameplay UI added to src. See .ai-sync/CODEX_CLIENT_HANDOFF.md for commits, API integration, exact Studio checks and remaining server-effect handoffs. | CODEX | Owner design review; gameplay contracts for later features | READY_FOR_REVIEW |

## Waiting on the owner
<!-- Codex integration note: 06357ec includes Claude's concurrent GameConfig edits for 8B.1/8B.7
(Height/Width scale ranges and Hitbox.BodyRadius=1.0), as well as Codex's Combat.Presentation section.
The associated OutfitDefs/History changes were left for Claude to commit. Do not reapply those config changes. -->
<!-- c1663e9 also includes Claude's concurrent Movement and Controls config hunks for 8B.5. Associated movement
implementations remain Claude's work; do not reapply the config. Codex client post-melee gating now consumes
WeaponDef.PostMeleeFireDelay and blocks while a server-confirmed takedown is active. -->
- The brief's answers (`docs/IDEAS_2026-10-24_BRIEF.md`) are decided; each lands in the step its table names. Only 8.8 is
  ticketed now. Step 16 needs 12 new Talents and 12 new Instincts designed with the owner first.
- The Deceive Inc. tutorial videos for Step 13C (`IDEAS_2026-10-24.md` Q10).
