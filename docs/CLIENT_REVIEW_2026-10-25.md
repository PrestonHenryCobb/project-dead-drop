# Client fixes and graphical HUD acceptance report

## What was built

| File | Change |
|---|---|
| `src/client/Combat/ViewModel.luau` | Keep pose smoothing in camera space; bring first-person geometry/offsets closer together, retaining framing and wall compression |
| `src/client/Controllers/FirstPersonBodyController.luau` | Draw the cosmetic hands on the rendered grips every frame, eliminating independent stepped grip snapshots |
| `src/shared/GameConfig.luau` | Ticket 8.16 close-depth tuning and a ticketed graphical HUD palette, layout and timing section |
| `src/shared/Util/HudKit.luau` | Shared shadowed panel and original code-drawn health, ammo, badge, eye and alarm graphics |
| `src/client/Controllers/CombatHudController.luau` | Health/armor and ammo panels, large numbers, easing meters, damage pulse and reload progress; Janitor cleanup |
| `src/client/Controllers/WeaponController.luau` | Expose the existing reload clock and standing/alive state to the HUD; no new firing behavior or remotes |
| `src/client/Controllers/CoverController.luau` | Compact eye/state/meter, alarm pips, short backed warnings; hide diagnostics by default and recovery instructions while downed/eliminated |
| `src/client/Controllers/DisguiseController.luau` | Compact tier-colored ID badge, clearance pips and stored disguise line; hide aiming dot while incapacitated; Janitor cleanup |
| `src/client/Controllers/DownedHudController.luau` | New 9b-hud countdown, server-confirmed revive/execute progress and eliminated state; no fake spectator controls |
| `src/client/Controllers/DownedController.luau` | Read-only generic body-target readiness for the HUD; reject targets behind collidable map geometry |
| `src/client/Controllers/TakedownHintController.luau` | Generic proximity hint matching current server reach/cones and map sight checks, for both visible NPC and player rigs |
| `tools/CheckClientCombat.luau` | Add a real-ViewModel regression assertion: camera translation must not drag the settled weapon through world space |
| `docs/PROMPT_REVIEW_2026-10-24.md` | Attachment audit, overlap table, recommended edits and 35 detailed owner questions |
| `.ai-sync/CLAUDE_RETURN_HANDOFF_2026-10-25.md` | Area ownership, source evidence and acceptance tests for NPC support/tiers, doors and synchronized animations |

The source root is `D:\Dead-Drop\Dead-Drop`. HUD controllers are discovered automatically; no boot or server edit
was necessary. Graphics are local GUI shapes with no paid generation or asset upload dependency.

## Verification completed

- StyLua formatting on changed source; read-only `stylua --check src` passes.
- `selene src tools/CheckClientCombat.luau`: 0 errors, 0 warnings, 0 parse errors.
- Rojo builds `default.project.json` successfully to a temporary check place.
- `git diff --check` passes.

These are static/lint/build checks. Studio rendering, assertions in CheckClientCombat, gamepad behavior, four-player
downed/revive checks and performance profiling have NOT been executed by Codex. No Studio result is claimed here.

## Exact Studio tests for the owner

### One player: gun, HUD and NPC hints

1. Stop any running test, connect Rojo and accept the script diff. Start a fresh **Play** session. A running test
   retains old ModuleScript results. Wait about 30 seconds for the NPC graph/crowd.
2. Look down and strafe/turn: your actual torso/legs/head must stay hidden locally. The cosmetic hands should
   remain on the gun. Make quick left/right turns, walk, crouch (C), aim (right mouse), fire (left mouse), reload (R),
   and swap disguise (G). Watch grip contact during each transition, not only when standing still.
3. Check whether the gun now feels close enough. The depth change preserves projected gun size/composition;
   if the stock still makes it look too far forward on screen, answer review question 3 about allowing the stock
   offscreen. Watch for near-plane clipping, giant hands, stretched elbows and recoil separating the hand/grip.
4. Walk toward a wall: gun tucks across the body, crossed-out OBSTRUCTED graphic replaces crosshair/dot.
   Try left mouse, right mouse and V. No shot sound, recoil, ammo spend or takedown should start. R still reloads.
   Back away while holding fire: no queued shot; release and press again when clear.
5. Check health/armor above the disguise badge at bottom left, cover centered below, ammo bottom right and alarm
   at top left. Panels need to stay readable against a bright window and a dark room. Worn role uses tier color/pips;
   the small G line describes the stored disguise. No always-on witness/debug paragraph should remain.
6. Fire several shots: exact ammo numbers update; R shows a moving reload bar. Cancel reload by changing disguise
   and verify the bar disappears. Take real damage using the existing fall/combat test: HP number updates promptly,
   health/armor bars settle smoothly and the vitals panel briefly pulses. Enter a higher-tier room: a short warning
   appears; when exposed, the recovery cue says why recovery is blocked. It must hide while downed/eliminated.
7. Approach an NPC from behind while clear of walls: a **V TAKEDOWN** prompt appears near the current allowed range.
   Turn toward the front, move out of range or put a wall between you: it disappears. Hold V: the existing hold bar
   appears and the readiness hint disappears. This does not add the missing two-body takedown animation.
8. At a downed NPC, aim at the body inside interaction range: **E INTERACT** appears without naming its identity
   or claiming a team. Hold E: after server acknowledgement, **EXECUTE** and progress appear. Release early to cancel;
   re-hold to finish. The hold UI disappears on server cancellation/completion. A wall must prevent the readiness cue.
9. Resize the viewport and repeat at 1280x720 and your normal resolution. Report overlap, unreadable captions and
   background blending. Very narrow windows still need visual review; mobile is not the target.
10. Optional regression assertions: during an alive playtest, select **Client** in the Command Bar context and paste
    `tools/CheckClientCombat.luau`. It makes temporary camera/model/wall fixtures, checks real modules and cleans
    them up. Expect the success count and no assertion error; report the first assertion verbatim if it fails.

### Two players: observer sanity check

1. Stop; use **Test > Clients 2 > Start**. Keep both clients near each other.
2. Move/turn/aim in client 1 while watching from client 2. Client 1's own view should keep the close cosmetic arms;
   client 2 should see normal world movement/facing, not the cosmetic arm rig.
3. Repeat the takedown readiness approach around a visible character and around an NPC. It is the same generic
   geometry hint, with no names, outlines or special player-only label. Server team rules remain authoritative.

### Downed/revive/execute: four clients for a normal combat setup

1. Stop; current `GameConfig.Debug.TestMode` is **Duos**. Use **Test > Clients 4 > Start** so there are two teams.
   TeamService's Studio output reports membership. Do not switch to Solos: Solos eliminate directly.
2. Have a rival shoot one member of a Duo to zero while its partner stays alive. The victim gets **DOWNED** and
   a countdown from the server's 30-second deadline. Fire/aim/reload/melee stay disabled. Movement asks to crawl;
   the missing authored crawl/death animation is separately handed to Claude.
3. The teammate approaches the body, aims at it, holds E: the server labels the hold **REVIVE**, with roughly 4 s
   progress. Release halfway: progress vanishes and does not finish. Repeat and finish: victim stands, downed HUD
   clears, weapon controls recover. Observe all clients for stale UI.
4. Down the victim again with its teammate alive. Have an enemy hold E: **EXECUTE** progresses for roughly 2 s;
   completion shows **ELIMINATED** on the victim. In a separate attempt, let the victim bleed out: countdown reaches
   zero and clears into eliminated state. A team wipe may eliminate early, which is intended existing behavior.
5. Respawn/start a fresh test: no stale eliminated/countdown/hold state, duplicated panels or duplicate callbacks.

## Gaps and SPEC-QUESTIONs

- Gun contact and HUD appearance require Studio acceptance. The owner confirmed smooth own gun/arms on October 25;
  world models should be slightly smoother too. Initial shared tuning is 12 Hz poses / 18 Hz positions.
- Full-gun-in-frame versus a closer shoulder-stock crop remains a composition choice. Initial depth scale is tuning.
- Takedown hint is advisory against client-rendered geometry, not a server guarantee. Reach and rear cone remain
  5.5 studs / 60 degrees total until Claude integrates the owner's approved 6.5 / 90. Ordinary melee stays unchanged.
- NPC airwalking/tier incidents, exterior door reproduction, crawl/death and two-body takedown animation remain
  assigned to Claude in the return handoff. Codex has not declared those gameplay bugs resolved.
- HUD includes only live existing contracts. Timer/objective/Intel progression, Assets, gadgets, menus, elevators,
  secret exits and rescue do not appear as fabricated working systems. Keyboard labels outside the takedown hint
  still need the broader controller-glyph/rebinding pass.
- Source review and test expectations are evidence, not a runtime reproduction of the NPC/door reports.

**Ready for:** owner Studio acceptance and design answers, then Step 9c (spectating) / remaining Step 8 integration
under the existing ownership split. All new gameplay proposals in the attached brief remain pending explicit answers.

## Map HUD skins and cadence follow-up (October 25)

Added `src/shared/Util/HudTheme.luau`, consumed by HudKit and all five graphical HUD controllers. It overlays only
allowed visual fields onto the common GraphicHud config, validates override names/types, freezes and caches results,
and falls back to neutral base styling for an unregistered ID. No per-frame theme lookup or extra connections.

`GameConfig.UI.HudThemeId = "Gala"` selects charcoal panels, brass borders, a restrained gold accent rule and tighter
corners matching the selected Field notes direction. Future maps add an entry to `UI.HudThemes` and select that ID
with their startup config. Optional `HudTheme.get(id)` supports a future map bootstrap. Runtime map switching is not
claimed: no map-session metadata event exists yet. Tier/cover/health colors and HUD layout/timing cannot be overridden
by a skin, so familiar gameplay information stays consistent between maps.

Additional tests:

1. Restart **Play** after Rojo sync. Compare bright/dark rooms: every panel should share the Gala charcoal/brass look
   and short gold top rule. Health, armor, tier and warning colors must retain their usual meanings.
2. **Test > Clients 2 > Start**: strafe/circle and watch NPCs alongside the other client. World models should feel
   less choppy; your own gun/arms stay smooth. Fire at moving NPCs and rivals in a separate multi-team test, checking
   that hit feedback follows the visible target. Initial 12/18 Hz tuning still needs owner feel/performance review.
3. Optional **Client** Command Bar theme check:
   `local s=game.ReplicatedStorage.Shared; local t=require(s.Util.HudTheme); assert(t.get().AccentColor==require(s.GameConfig).UI.HudThemes.Gala.AccentColor); assert(t.get("UnknownPreview").PanelColor==require(s.GameConfig).UI.GraphicHud.PanelColor); print("HUD theme checks passed")`
   This checks the real resolver without mutating the live theme or config. It does not repaint the GUI.

StyLua/Selene/Rojo checks are required for this follow-up as well. Studio tests above remain owner-run.
