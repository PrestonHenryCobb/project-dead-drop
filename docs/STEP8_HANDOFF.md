# Step 8 handoff (paused 2026-10-23, mid-build)

Everything below is saved in local commit `5c883d1` on `main` (based on `aa65eef`, the map re-plan). The new commit has not been pushed to GitHub yet.
Read `CLAUDE.md` first (rules, and how a step must end), then `docs/STEP8_QUESTIONS.md` (the decided design, the
"Answers" section at the bottom is the source of truth), then this file.

## State in one paragraph
The weapon system for **Guise's suppressed SMG** is written, lint-clean (StyLua and Selene: 0 errors) and mostly working
in Studio. The server path (FireRequest, validation, lag-compensated hit registration, damage to NPCs, cover and
lockout hooks, hitmarkers, ammo, reload) was exercised through manual remote calls and worked. The **real client path**
(mouse -> WeaponController -> shots) had a camera recoil bug, now fixed and confirmed by the user in Studio. Melee,
takedowns, fall damage, the HUD and the view model have not been looked at or exercised yet.

## What exists (files)
Shared
- `src/shared/Defs/WeaponDefs.luau`: `GuiseSMG` only (the other 17 are deliberately not defined yet, no stubs).
- `src/shared/Types.luau`: `WeaponDef`, `HitConfirm`, `AmmoInfo`, `HealthInfo`, `DamageInfo`, `ShotInfo`, `MeleeState`.
- `src/shared/Remotes.luau`: added S->C `AmmoUpdate`, `HealthUpdate`, `ShotHeard`, `MeleeState`; C->S `RequestDraw`;
  removed `RequestDebugEvent`. Existing `FireRequest`, `ReloadRequest`, `RequestMelee`, `HitConfirm`, `DamageTaken` are used.
- `src/shared/GameConfig.luau`: `Combat` grew (DefaultWeapon, MaxShotStuds, PlayerRenderDelay, Hitbox, Melee/Takedown
  extras, Feedback, ViewModel); `Controls` gained Fire/Aim/Reload/Melee (+ pad); `Debug.TestEvents/TestKeys` removed,
  replaced by `Debug.PrintEvents` (the old log flag) and a new `Debug.PrintShots` (off by default).
Server
- `src/server/Services/CombatService.luau`: all combat state (HP, armour plates, ammo, reload, drawn), FireRequest,
  melee and held takedowns, fall damage (from landing speed), spawn reset, target registry sync.
- `src/server/Combat/Hitbox.luau`: ray vs cylinder + head sphere (unit-tested in Studio: correct).
- `src/server/Combat/History.luau`: 20 Hz ring-buffer pose history for lag compensation (rewind up to 250 ms).
- `src/server/Services/NPCService.luau`: added `getNpcs()`, `hitNpc(npc, amount, from)`, `gunshot(position, audibleStuds)`;
  NPCs now have `hp` (NpcTypes); the old J/K/L debug-event channel was removed (and `DebugEventController.luau` deleted).
- `src/server/NPC/Reactions.luau`: `gunfire(crowd, pos, now, audibleStuds)` so a suppressed weapon alarms fewer NPCs.
- `src/server/Services/CoverService.luau`: `setWeaponDrawn(player, drawn)` + WeaponDrawn suspicion rate (Tier 1+, guards/cameras).
Client
- `src/client/Controllers/WeaponController.luau`: input (ContextActionService: LMB fire, RMB aim, R reload, V melee, plus
  gamepad keys), prediction (sound, kick, recoil, ammo, reload), spread, FOV zoom, hides own arms, drives the ViewModel.
- `src/client/Controllers/CombatHudController.luau`: crosshair that opens with spread, hitmarkers (grey NPC / red agent /
  bigger + higher pitch for head), damage direction markers, HP and plates, ammo, takedown bar.
- `src/client/Controllers/ShotFxController.luau`: other players' shots (sound at the muzzle, dust where it landed).
- `src/client/Combat/{ViewModel,SoundPlayer,ShotFx}.luau`: first-person gun and arms built from parts, pooled sounds, pooled impacts.
- Sounds are Roblox library ids (all eight verified to load in Studio); listed in `WeaponDefs` and `GameConfig.Combat.Feedback`.

## Bugs found and fixed this step (so you don't redo them)
1. **Recoil piled up every frame.** Roblox's default camera builds each frame on the `camera.CFrame` it finds, so
   `camera.CFrame *= recoil` ratcheted the view. Fixed: only the *change* in recoil is applied (`appliedPitch/appliedYaw`).
   The user verified the fix in Studio.
2. FOV compare used exact float equality (the camera stores FOV at lower precision, so zoom would have compounded). Fixed
   with `FOV_TOLERANCE`.
3. A stuck trigger when the mouse-up never arrives (window loses focus). Fixed with `WindowFocusReleased`.

## What is NOT done (in order I would do it)
1. Screenshot the HUD and the view model in play (Tucked / Ready / Aim poses) and tune `GameConfig.Combat.ViewModel.Poses`.
   The arms are plain sleeve blocks (placeholder for the art pass).
2. Exercise melee (V), takedown from behind (hold V 1.2 s: server timer, breaks if the target moves 4 studs or the
   attacker is hurt), reload, empty click, fall damage (check ziplines, gondola and vents do **not** cause fall damage:
   it is computed from landing speed, never tested), and two-player fire (cover exposure, red hitmarker, DamageTaken marker).
3. Third-person gun on other players' characters while **Exposed only** (decided in STEP8 answers). Not built. It must be
   client-side only (nothing on the character, rule 3); the plan was a `WeaponVisual`-style event sent only to nearby
   players, or reuse of ExposedPing. Needs a design decision on what the server may tell nearby clients.
4. **Real Blender model for the SMG** (decided: only the SMG gets one in Step 8; the rest stay part-built until an art pass).
   The user uploads to Roblox. Not started. There is a Blender MCP available.
5. Gamepad/touch **aim assist** was deferred to Step 19 (it was tagged "blocks Step 19"); gamepad keys are bound but untested.
6. The other 17 weapons and their unique effects (see STEP8_QUESTIONS.md, "Unique effects" and "Revised stats" tables).
   Per CLAUDE.md the user said: start with the SMG fully polished, then add the others.
7. Edge cases from the spec: reload cancels on disguise swap (27 #22); friendly fire needs teams (Step 10).
8. End-of-step report in the CLAUDE.md format (what I built / how to test in Studio / gaps / SPEC-QUESTIONs / next step).
   SPEC changes to log in `docs/SPEC_CHANGES.md` are already there (13: weapons; 15: new agent names).

## Decisions made this session worth knowing
- Agent names changed (user request): Guise and Suture kept; Bastion -> **Parapet**, Glitch -> **Lattice**,
  Vantage -> **Reticle**, Mirage -> **Feint**. Done in `docs/` (not in the original spec file) and the memory file.
- Fight speed about 1.2 s to down an agent with 1 plate; 3 magazines total (loaded + 2 spare); Vantage/Reticle has no
  damage falloff and ~10% trimmed damage; the SMG's numbers are in `WeaponDefs`.
- One shot per FireRequest; the server trusts the direction (spread is client side). Origin must be within 4 studs of the
  shooter's head at the fire time. Rewind per target: NPCs 0.15 s (client interpolation delay), players 0.1 s.
- At 0 HP a player's character dies and the debug auto-respawn brings them back (Step 9 replaces this with downed).
- Firing breaks Cover, refreshes the combat lockout, makes NPCs react (suppressed: heard 25 studs, otherwise 120).
- Hitmarkers: grey = NPC, red = agent; the server also sends `ShotHeard` to players within earshot.

## Studio and tooling gotchas
- Rojo must be serving (two rojo.exe were running) and connected; Studio file is `CoverStory.rbxl` (studio id from
  `list_roblox_studios`). Edit the files on disk; Rojo syncs scripts within seconds. **A running playtest keeps old code,
  restart it after every change.** The NPC graph takes about 25-30 s to build after Play starts.
- `execute_luau` requires a *fresh* module copy: to inspect live server state, create a Script from `execute_luau`
  that `require`s the module (shares the cache) and writes into a StringValue; then read it.
- A server-side `CFrame` set on the client-owned character snaps back; teleport the player from the **Client** datamodel.
- The `user_mouse_input` tool works for clicks (give it a `moveTo` first, and always release the button).
- Roblox's camera integrates `camera.CFrame` frame to frame: never assign absolute rotations from the weapon code.
- Studio screenshots (edit mode) work when the Studio window is in front; do not launch Studio via computer-use.
- NPC server poses are standing T-pose-ish (animation is client side); hit boxes are deliberately generous (body radius 1.25).

## Before committing
- `Debug.PrintShots` is set to false in `GameConfig.luau`.
- Run `stylua src` and `selene src` (both were clean at pause).
- Commit message idea: "Step 8 (part 1): combat core and Guise's SMG". The user confirms commits and pushes.
