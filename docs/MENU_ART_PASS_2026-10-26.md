# Menu art pass — 2026-10-26

The owner identified the previous menu as a functional foundation with placeholder-quality presentation. This pass implements original native Deco artwork and fixes the concrete issues Claude found at 1280x720. It does not declare final visual acceptance or invent missing gameplay/shop content.

## What changed

- `Components/GalaSet.luau`, `MenuStage.luau`: three monumental fan-window bays, fluted ivory columns and stepped capitals, engraved balcony chevrons, marble parquet/inlays, velvet settees and a faceted three-tier chandelier. All authored native geometry in the menu's existing client-only stage folder; no map generator change. No extra lights, shadow-casting fixtures, NPCs, interactive parts or uploaded assets. Existing stage lifecycle and camera framings remain.
- `Components/DecoArt.luau`: original scalable credential insignia, intaglio treasury seal, sealed folio and presentation-case illustrations, with engraved rays, brass keys and separate ivory title bands. These are actual native UI drawings rather than blank labels for unpublished rewards. Game content is not implied by the art.
- `Components/ViewKit.luau`, `MenuTheme.luau`, `GameConfig.luau`: larger menu body type, explicit brass scrollbars, clipped scrolling areas, illustrated panels and filled emerald selected buttons. Decorative corner frames are confined to fixed-layout panels, so they cannot become extra rows in automatic list layouts.
- `PlayLobbyView.luau`: ivory operation briefing with dark typography, original operation insignia and the richer stage behind the existing working queue/loadout/deploy flow. The parchment explicitly disables the dark panel gradient; changing its base color alone was insufficient.
- `AgentsView.luau`, `Components/WeaponPreview.luau`: credential artwork beside agent identity and brass framing around the real weapon previews. Shared True Form agent appearances remain shared; this pass does not invent final agent costumes.
- Hardware: compact three-line stat readout and LEFT/ZOOM/RIGHT controls fit above pinned Equip at 720p. Independent scroll clipping prevents details from drawing over pinned actions.
- Dossiers: the right-hand copy is confined to its column; the empty-state paragraph no longer competes with its list layout. Dark-on-dark placeholder banners are replaced by the illustrated plates.
- Black Market / Mint: illustrated case/treasury graphics with high-contrast titles; scrollable information rails contain their actions and balances. No invented offers, prices or currency grants.
- Assets / Profile: compact illustrated Asset cards, larger text, explicit scroll cues and wider persistent scrollbars for content below the fold. Asset inspection scrolls independently.

The presentation files normally maintained by Claude (MenuStage, MenuTheme, PlayLobbyView) were unlocked, then locked for this owner-authorized art pass. Server rules, Remote contracts, progression, mastery requirements, team selection and match flow were not edited.

## Verification completed

- Actual Roblox Edit fixture `tools/CheckMenuViews.luau`: **MENU_VIEWS_NATIVE_PASS: 400 checks**, confirmed in the Studio application log on 2026-10-26. It uses fresh isolated Client/Shared copies, fake transport and an exact 1280x720 reference content area. Checks cover seven collection views, Play, assembly/destruction of the actual MenuStage, all eighteen Hardware entries, six real W1 models, profile push/refusal/lifecycle behavior, title fit, Mint controls inside Treasury, clipped inspector details, rotate controls and the entire weapon stat readout above Equip, authored stage geometry, no new lights and noninteractive art parts. Camera state and all temporary GUI/models/modules are restored/removed.
- `node tools/check-menu-session.cjs <official-luau-cli>`: **21 actual-source lifecycle/transport assertions pass**.
- StyLua on named modified files, read-only full source formatting check, Selene, official Luau compilation and Rojo build pass.
- The updated native fixture succeeds through Studio's command bar using keyboard execution. Computer-use screenshot capture still fails with `window capture timed out`; coordinate input reports `coordinate input geometry is unavailable`. No screenshot review or performance measurement is claimed. Native construction, layout bounds and TextFits checks do not replace visual composition/lighting review.

## How to review in Studio

1. Stop an old test, sync Rojo and start fresh Play. On Play and Agents, compare the fan windows, chandelier, brass/ivory architecture, velvet seating and floor inlays with the saved Gemini references. Check the operative remains legible and comfortably framed. The menu set changes only the local lobby, not the Gala map.
2. At 1280x720, select each agent, open Armory and inspect built weapons. LEFT/ZOOM/RIGHT, the full stat summary and Equip must be separately readable. Scroll the weapon catalogue, Asset codex, profile and Treasury using the visible brass bars. Verify text and actions do not escape their panels.
3. Open Dossiers, Black Market and Mint. The illustrated title bands must have dark text on ivory. Open/close Mint inspection. No fictional rewards, balances or offers should appear.
4. Recheck free class claims, equipment selection, Deploy and the full 30-second selection window. Those existing systems were preserved. A real two-player selection regression remains a separate acceptance requirement.
5. Optional Edit regression: paste `tools/CheckMenuViews.luau` into Studio's Command Bar and run with Ctrl+Enter. Expect MENU_VIEWS_NATIVE_PASS and complete temporary fixture cleanup. The fixture temporarily exercises the menu camera and restores it; it never rebuilds the map or changes real profiles.

## Gaps, questions and next

Visual fidelity, menu lighting and final framing still need screenshot/owner acceptance because capture is unavailable here. Distinct final agent appearances, custom portrait art, final weapon finishes, shop/reward catalogues and purchase products remain separate unfinished content; the previous functional-foundation report was too broad and these are not presented as complete. This pass adds genuine authored native art, but is not a claim that the entire Gemini suite is finished.

SPEC-QUESTIONs added: none. Ready for: visual review of this native lobby/collection art pass and remaining two-player menu acceptance. No new main gameplay step was started.
