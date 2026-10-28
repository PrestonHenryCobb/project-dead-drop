# Client HUD readability continuation

The owner reported the playtest complete and requested continued work. Individual checks/results were not supplied;
this report does not mark earlier tickets DONE or claim a new Studio run.

## Source findings and changes

Two concrete collisions were reproduced from the existing positions: Alarm and TeamIntel both occupied the upper-left
margin, while ExposureNotice occupied the same upper-center space as MatchClock. Cover warnings and disguise toasts
also used the center area now occupied by phase/vault UI.

- `src/client/Combat/HudLayout.luau`: explicit left/right/center regions derived from the actual theme/config sizes.
  Left: Alarm, Intel, disguise toast. Right: Package, extraction, exposure notice, cover warning. Center remains for
  match clock and vault progress (vault bars already wait out phase banners).
- `src/client/Controllers/IntelHudController.luau`: Intel moves below Alarm with the shared padding gap.
- `src/client/Controllers/CoverController.luau`: exposure notice and cover warnings move to their right-side regions;
  standalone warning/prompt text scales with the viewport like the existing panels.
- `src/client/Controllers/DisguiseController.luau`: scaled, wrapped disguise toast in the left stack, on a readable
  themed backdrop. The backdrop hides with the text; an earlier expiry cannot hide a newer message, and removed UI
  is ignored by delayed callbacks.
- `tools/check-client-data.cjs`: cold-loads the full production GameConfig, AgentDefs and WeaponDefs with constructor
  fixtures, using the real DeepFreeze and lookup APIs. Checks all selectable weapons against the shaped-model registry,
  ownership, mastery, ammo/action contracts and immutability. Reintroduces the two formerly boot-breaking hardware IDs
  in isolated negative cases and verifies they fail. Also checks real HUD region/scale math and toast callback behavior.
- `tools/check-objective-client.cjs`: Intel controller fixtures now execute the actual shared layout helper.
- `.ai-sync/TASK_QUEUE.md`: owner playtest note and queued 19-hud-readability status. Existing unrelated edits preserved.

No server/shared-contract edits, weapon balance changes, new gameplay mechanic or new asset dependency.

## Verification

- Changed Luau files pass StyLua and Selene; Rojo build passes.
- Client-data suite: 673 assertions, 16 registered weapons and all six agent registries cold-loaded. The only two
  unavailable Hardware choices remain Lattice's burst rifle/taser; this work does not register incomplete weapons.
- Existing suites: 228 weapon, 40 match, 28 objective, 29 Package assertions. Total: 998 source assertions.
- Geometry checks cover Gala and neutral themes at 1280×720, 1600×900, 1920×1080, 2560×1440 and 3440×1440, using the
  production HudScale factor and region calculations. No pair of tested regions intersects or leaves the viewport.
- Fixtures verify data/logic and geometric regions, not native text measurement or engine rendering. This patch has
  not been visually checked in Studio; the owner's completed earlier playtest is a separate result.
- A full-source StyLua check encountered Claude's concurrent NPCService formatting; it was not modified. Only owned
  files are formatted/staged. Full-source Selene was clean at that check.

## Later visual check

In a fresh synced Play, show Alarm and Intel together, fire/expose near a vault terminal while the match clock is
visible, and trigger a disguise toast. The panels should remain separate. Repeat at 1280×720 and a larger viewport;
the toast backdrop must disappear when its message expires. These checks do not require a new gameplay decision.

## Gaps and next Claude prompt

No new SPEC-QUESTION. Layout values come from existing config; gameplay timers, recoil and permission rules are intact.
Cold-load tests are not proof of server boot, network behavior or native UI acceptance.

> Continue the alpha bot-fill work under locks. Read CLIENT_READABILITY_REVIEW_2026-10-28.md; leave Codex's HUD files
> untouched. Run the full agent/weapon cold-load check along with your server checks so Hardware ID drift cannot break
> boot again. Publish the stable bot/team-roster contract and any required client handoff before changing client-facing
> payloads. Record formatting/check results, commit only your own hunks and do not push.
