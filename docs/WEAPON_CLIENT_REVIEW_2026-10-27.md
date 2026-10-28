# Six-weapon client review — 2026-10-27

Built against `.ai-sync/WEAPON_SERVER_CONTRACTS.md` and server commit `8750cdf`, in the owner's order:
garrote, pump, hammer, flare, smoke SMG, knives. Source checks pass; Studio acceptance is still pending.

## Files changed

- `src/shared/Defs/WeaponDefs.luau`: six complete definitions migrated from pending; handling, recovery and Visuals.
- `src/server/Tools/PendingWeaponDefs.luau`: empty migration index; all six entries removed.
- `src/client/Combat/ViewModel.luau`: six shaped models, pump cycle, acknowledged melee swing and hold poses.
- `src/client/Controllers/WeaponController.luau`: melee gates/cooldowns; per-shell reload/interruption/reconciliation;
  stagger camera bump; projectile prediction; silent knives. Also adopts authoritative AmmoUpdate.WeaponId in live
  games, where Studio-only TestLoadoutChanged is absent.
- `src/client/Controllers/CombatHudController.luau`: melee ammo panel/crosshair hidden; bar uses server Seconds.
- `src/client/Combat/WeaponEffects.luau` and `Controllers/WeaponEffectsController.luau`: bounded, client-only projectile
  flight, own-prediction adoption, impact lights, occluded team glow, smoke and inside-cloud veil, owned by Janitor.
- `src/shared/GameConfig.luau`: presentation sizes/colors, effect bounds and prediction timeout.
- `src/client/Menu/Views/AgentsView.luau` and `HardwareInspectorView.luau`: melee stats instead of firearm ammo/RPM.
- `tools/check-weapon-clients.cjs`: executable actual-source action/event/model-structure regression suite.
- `.ai-sync/TASK_QUEUE.md`: six review rows and server gap handoff. Existing uncommitted edits preserved.

No CombatService, ProjectileService, DisguiseService, CoverService, Ballistics, MovementController, Remotes, Types or
Enums edits. No instance, attribute or tag is added to a character/NPC. Highlights live in a client folder with an
Adornee; server LandedKnife instances, names, parents and prompts are unchanged.

## Studio tests

Stop any old playtest and sync Rojo first. Use two local clients for combat checks; use four in Duos for a separate
Suture teammate and opposing team. F8/F9 select the agent and registered weapon in Studio. Inspect Tucked/Ready/Aim
at 1280x720, a wider window and a narrow window; check hands, wall tuck, switching and respawning.

1. **GuiseGarrote:** LMB/R must spend no ammo or send FireRequest/ReloadRequest; ammo panel stays hidden. V tap
   swings for 40, with 0.8 s cooldown. From behind an NPC, hold V: server bar completes in 0.8 s for 100 damage.
   Garrote swing/takedown prediction plays no generic impact sound. Cancel by changing held item or disguise.
2. **ParapetPump:** fire two rounds, then R. Count one round every 0.5 s, not a whole magazine. Fire midway through
   loading; keep completed shells and stop loading. Repeat just before/after the shell boundary, and with an empty
   magazine. No refunded rounds or phantom seventh shot. One pull spends one shell and sends eight directions.
   At full health, an agent survives a complete close blast, even on the exposed head. At least five pellets within
   12 studs should slow the victim and bump their view away from the shooter without cancelling their firing.
3. **ParapetHammer:** no ammo panel, firearm or reload request. Tap V for 70; hold for 1 s then release for 100.
   Charge pose/bar follows the server, 1.1 s swing cooldown. A player victim moves 3 studs to the swinger's right,
   stops at walls and can fall over an open edge. Default rear takedown remains 1.2 s / 90 damage.
4. **SutureFlare:** fire across a room; see one predicted flare, then one adopted flight rather than a duplicate.
   No instant hitscan dust/tracer or damage prediction. A direct target takes 55, other nearby targets 15. Impact
   light lasts until the server's five-second expiry; no burn damage. Suture and their teammate see the four-second
   glow; an opponent does not. Hide target behind a wall: glow disappears; reappear before expiry: it returns.
   Change disguise during the glow: its expiry remains four seconds. One shot then 1.6 s reload.
5. **FeintSmokeSMG:** fire a full 32-round magazine into a nearby wall. Only final five impacts make smoke, each
   four studs across for two seconds. Both clients see it; entering the cloud also obscures the camera. No damage
   from smoke. Verify normal automatic fire, reload and 0.2 s melee-to-fire recovery.
6. **FeintKnives:** throw six at 0.6 s intervals; flight has a shallow arc, no gunshot/tracer/flash or reload.
   LandedKnife parts and prompts remain present. A second knife user, including an opponent, can recover one up to
   six carried. Non-knife users cannot take it. Two clients contesting one knife must gain only one total round.
   Check 45 body / 90 exposed-head damage and disguised-head body damage.

Also run `tools/CheckClientCombat.luau` in the Client Command Bar for real-engine framing/model checks and
`tools/CheckWeaponCadence.luau` in the Server Command Bar. These Studio checks have not been run in this session.

## Validation and known gaps

- Changed Luau files: StyLua and Selene clean. Rojo build passes.
- `node tools/check-weapon-clients.cjs <official-luau-cli>`: 204 assertions pass. Uses actual action/event bodies and
  model builders, with deterministic clocks/service/instance fixtures. Model fixtures check structure, not real
  CFrame projection, engine rendering, Roblox type checking or network behavior.
- No additional contract/server event-field mismatch found in the reviewed paths. Known server-contract gaps remain:
  NPCs are not slowed/shoved, smoke does not affect authoritative sight/scans/Agent Sense, no round-end landed-knife
  cleanup yet, and the pickup prompt remains visible to agents who cannot pick knives up.
- Without a request ID, Own projectile acknowledgement matches the oldest outstanding prediction of that kind.
  Rejected predictions expire after the configured timeout. Test packet delay/rejection behavior in Studio.
- Effect counts are bounded; at the cap the oldest cosmetic is discarded. Server gameplay is unaffected.

## SPEC-QUESTIONs and next Claude prompt

Initial spread, recoil, draw/aim response, post-melee recovery, smoke appearance and projectile prediction timeout
are Studio tuning. Owner-approved mechanics and the server's projectile numbers were preserved. Existing server
questions remain: NPC reaction parity, smoke sight policy, hammer-right interpretation, and pickup-prompt eligibility.

Suggested next prompt for Claude:

> Read the six-weapon client review and the new TASK_QUEUE rows. Run the Studio multiplayer checks against server
> commit 8750cdf and the client integration. Review NPC pump-slow/hammer-shove parity, visual-only smoke versus server
> sight, landed-knife cleanup at round end and pickup-prompt eligibility. Fix authorized server mismatches under locks;
> leave client combat files to Codex and document any necessary event/field changes. Commit only your own hunks; do
> not push. Report observed results separately from source checks.
