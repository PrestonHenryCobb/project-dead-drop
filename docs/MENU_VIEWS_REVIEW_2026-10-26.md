# Native menu views — 2026-10-26 (menu-views)

## What was built

Seven plain MenuView modules in `src/client/Menu/Views`, automatically discovered by Claude's MenuController:

- AgentsView: six approved operatives, first-launch free class claims, actual mastery/ownership/equipment state, W1/W2/W3 selection and validated equip requests. Calls navigator.focusAgent for the large native operative stage; its centre remains transparent. Designed Talents/Instincts are explicitly marked in development.
- HardwareInspectorView: all 18 designed Hardware entries, agent filters, ten real procedural weapon previews, exact WeaponDefs stats, drag / focus-scoped right-stick rotation, rotate/zoom buttons and always-visible equip/back actions. Eight unbuilt items cannot equip and have no fabricated geometry/stats. Hardware is never sold.
- AssetsCodexView: six approved BUILD_ORDER Step 7B Assets and four rarity values, selected states, descriptions and an equal-footing panel. Explicit reference codex; no pre-match activation or invented eight-item catalogue.
- DossiersView: real server track/XP/claimed counts and active-track requests when present. Honest archive empty state until a reward catalogue exists; permanent direct-XP rule preserved.
- BlackMarketView: verified balances, Mint route and clear no-offers state. No fake countdown, rotation, bundle or purchase.
- ProfileView: actual identity, career counters and all six mastery records, with real W1 weapon artwork. No fabricated ranked ladder, history or calling-card ownership.
- MintModalView: verified Stocks balance, purchase-unavailable state, Mint-policy inspection and reusable read-only/confirmation overlay. No price examples, currency grant or cash purchase substitute.

`Menu/Components/ViewKit` centralizes shared-theme controls, profile lifecycle, pending-request guard, readable server refusals and focus restoration. It reuses navigator.snapshot/onSnapshot and falls back to the existing RemoteController only without that shell interface. Unmount destroys GUI, listeners, background tasks and preview models through Janitor. `WeaponPreview` uses ViewModel's actual builders, native ViewportFrame directional lighting and bounds-based camera fitting. There is no automatic spin, so reduced-motion users get no unsolicited motion. Game mechanics, Remotes and server validation are unchanged.

References and latest explicit preferences were saved first in UI_REFERENCE_HANDOFF_2026-10-26.md. The supplied Gemini handoff is preserved with only trailing Markdown whitespace normalized beside three candidate Gemini reference images found in Downloads. The original generation prompt and any finer image ranking were not supplied; these remain explicitly unknown rather than reconstructed.

## Validation

- `node tools/check-menu-session.cjs <official-luau-cli>`: 21 actual-source assertions passed for initial/pushed profiles, shell snapshot/subscription reuse, duplicate-request rejection, readable success/refusal, pending-invoke cancellation, no callbacks after teardown and GUI/subscription cleanup. Narrow GUI/transport fixtures do not emulate Roblox rendering.
- StyLua on our named files; read-only source formatting check, Selene source/native fixture, official Luau compilation and Rojo build checked before commit. See final command output for any concurrent unrelated failures.
- `tools/CheckMenuViews.luau` is an isolated Studio EDIT fixture for seven real-module mounts, nil first-launch loadout, repeated teardown, all 18 armory entries, six real W1 models, transport refusal and profile-push rendering. It clones Client and replaces only its transport/LocalPlayer access; no live profile, map or purchase is touched. **Not executed here.**
- Native visual capture failed (`FrameArrived timed out`, then `window capture timed out`). Accessibility inspection worked; no Play session, map rebuild or shared-place mutation was performed by Codex. Rendering/gamepad acceptance is pending, not claimed as passed.

## Studio acceptance

1. After Claude completes shell/services, stop the old test, sync Rojo and start a fresh one-player Play. Open every tab, Stocks -> Mint and Agents -> Armory. At 1280x720 check readable text, model lighting, scroll areas and the pinned Armory equip/back controls.
2. First launch: no agent is assumed owned and nil Loadout must not crash any view. Claim one free operative from each class. Inspect another unowned agent in that class: no second free claim. Confirm equipment only changes after the server's profile update.
3. Agents: select all six and all three slots. The stage follows the selected kit. Open All 18 Hardware: ten real models, eight in-development entries, never prices. Unowned or mastery-locked items cannot equip. In Studio, mastery may intentionally follow Claude's configured StudioMasteryLevel override.
4. Inspect a built weapon, drag it, use LEFT/ZOOM/RIGHT, then navigate with a gamepad and right stick. Switch tabs while dragging or awaiting a server answer; no retained input, model, listener or stale update should survive Unmount. Enable Roblox Reduce Motion: no automatic model motion exists; shared button motion follows MenuTheme.
5. Assets: all six entries and four rarity selectors update the correct description/value and selected state. Dossiers/Black Market/Mint show honest unavailable states with zero invented offers or grants. Profile reflects actual server counters. Open/close Mint policy inspection.
6. Optional isolated Edit check: paste tools/CheckMenuViews.luau into the Command Bar after syncing source. Expect MENU_VIEWS_NATIVE_PASS and no retained fixture GUI/modules. The fixture never starts Play or rebuilds the map.

## Gaps, decisions and next

Reward tiers/catalogue, cosmetic definitions/offers/schedules, Mint packages/Robux products and match history have no contract/content yet. They need approved content and server systems before the illustrated five-reward track, six live offers, purchase confirmation and claims can become functional. We deliberately do not manufacture those decisions from Gemini examples. Assets remain a reference codex until their gameplay step is connected. Profiles are currently session-only per Claude's service, not saved progression. All agents share the game's current True Form look until original agent appearances exist.

SPEC-QUESTIONs added: none. Existing mastery/kit decisions remain in shared definitions. Original Gemini prompt and more specific image preference text still need their source from the owner.

Ready for: integrated native Studio menu acceptance with Claude's menu-shell/menu-services. The main gameplay-plan next step remains Step 9c spectating; this ticket does not start it.

## Integration follow-up — shared margins

Claude's committed solo-playtest handoff (3945bab) identified collection views drawing flush to the edges/header. ViewKit now insets every collection screen by twice GameConfig.Menu.GapPixels on each edge, matching MenuTheme.rail's outer spacing. Transparent agent staging, scrolling, pinned armory actions and the shell's existing scale remain intact. Actual-source session regressions, formatting, lint and Rojo build pass; visual acceptance and the two-player selection test remain pending. Claude should next run tools/CheckMenuViews.luau and the two-player menu-shell/menu-services integration checks, fixing only its owned shell/service files and reporting any view issues for Codex.
