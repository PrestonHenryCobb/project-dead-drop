# Security HUD — ticket 14b, 2026-10-28

Built against `.ai-sync/SECURITY_CONTRACT.md`. Client only; no server service, remote, shared type or enum changes.

## What was built

- `src/client/Controllers/CoverController.luau`: reuse its AlarmLevel state and HudLayout.Alarm panel. Four cumulative
  pips represent levels 0–3 (one through four lit); level 3 replaces the alarm caption with a persistent LOCKDOWN banner.
  No flashing or decorative motion; the banner ends when the server reports a lower level.
- `src/client/Controllers/SecurityInteractController.luau`: read-only `currentTarget()` accessor for its existing target.
  The HUD does not select a separate object or send interaction requests.
- `src/client/Controllers/SecurityHudController.luau`: HudTheme/HudKit prompts for Hack camera, Cut power, Camera Room
  and Pick lock. Exact server InteractState labels drive hold progress, with unrelated holds suppressed. A nearby
  CameraTerminal shows up to four working camera views during gameplay. Disabled/destroyed/streamed-out cameras are
  removed. Pages cycle every 8 s, or manually via F6 / ButtonR1 / the Next Cameras button. Reduce Motion disables
  automatic page changes; functional live views remain. Life/phase/cinematic/menu visibility gates and cleanup included.
- `src/client/Combat/SecurityFeeds.luau`: bounded ViewportFrame scenes and cameras follow the existing camera props.
  Streamed map parts and nearby models use identical visual-copy rules, without identifying player/NPC/team roles.
  Copies have neutral names, no attributes/tags/scripts/rig controllers or labels; original sources are never modified.
  Per-part map occlusion checks suppress hidden surfaces/actors even if the viewport's scene budget omitted a wall.
- `src/shared/GameConfig.luau`: separate client-only SecurityHud presentation/input/performance tunables.
- `tools/check-security-client.cjs`: actual alarm, feed and HUD source regression coverage.
- `.ai-sync/TASK_QUEUE.md`: 14b status and handoff.

## Verification

Changed-file StyLua formatting, full-source `stylua --check src`, `selene src` and Rojo build pass.
50 security assertions pass; 1,406 across ten checked client suites. They cover alarm levels/Lockdown, exact server
hold labels, prompt arbitration/progress, camera filtering/order/pages, Reduce Motion/manual paging, near-terminal
gating, source immutability, clone sanitization/occlusion/pooling/budgets and visibility/life/phase/teardown cleanup.

## How to test in Studio

1. Fresh Play, solo with bots: deploy. Alarm starts at one lit pip for level 0. Trigger successive alarms: levels 1/2/3
   show two/three/four pips. LOCKDOWN remains visible throughout level 3 and disappears on the server's drop to level 2.
2. Aim at a hackable camera within the existing flat-distance reach: Hack camera prompt. Hold E / ButtonX; the bar
   must start on server acknowledgement, fill for the server duration and end when disabled. Repeat at a fuse box
   (Cut power), Camera Room terminal, and a closed tagged keycard door (Pick lock). Release early to cancel. Keycard
   doors need the existing temporary test prop because the current generated map has none; no test door was added.
3. Approach the Camera Room terminal within CameraRoom.InteractStuds during gameplay. Up to four views appear on the
   left, showing local streamed surroundings from working camera positions with live sweep and actor transforms.
   Wait 8 s or press F6 / ButtonR1 to change pages. Hack/destroy cameras: those signals must disappear. Disable all:
   NO WORKING SIGNAL must replace the views. Leave terminal reach: panel and scene copies disappear.
4. Turn on Roblox Reduce Motion: pages stay fixed until manually changed, with no fades/flashes. Verify F6 works with
   the first-person mouse locked, ButtonR1 works with a controller, and typing cannot change pages. Check at 1280x720
   and a larger viewport; feed panel must not cover essential state or the contextual action bar.
5. Two players: down/eliminate the viewer and finish a match. Prompts/feeds must close; respawn/revive restores only
   eligible live gameplay. Watch a disguised player and an NPC in feeds: neither gets an identifying label or highlight.

## Known gaps and risks

No new native Studio playtest/render/performance result is claimed. ViewportFrames render client-streamed parts, not a
server video stream: distant unstreamed cameras/rooms can have incomplete scenes. No streaming request is added. Geometry
discovery and copy count are bounded (350 surfaces/feed); dense rooms may be simplified. Actor occlusion is conservative
per-part center LOS, so partially visible parts may disappear rather than show through walls. Refresh is 10 Hz for
transforms/occlusion and 2 Hz for scene membership. Profile the four-view panel with the live crowd before tuning caps.
Viewport lighting is a fixed ambient/directional approximation; terrain, particles, postprocessing and skinned bone
deformations are not reproduced. The current classic-rig parts follow their live source transforms.

## SPEC-QUESTIONs and next

No new gameplay SPEC-QUESTION or contract/server mismatch found. Existing questions in SECURITY_CONTRACT.md remain.
Ready for ticket 14b Studio acceptance, including camera shooting and multiplayer security checks already listed by
Claude. No next ticket started and no push performed.
