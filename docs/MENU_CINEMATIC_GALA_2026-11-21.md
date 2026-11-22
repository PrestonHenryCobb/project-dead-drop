# Cinematic gala menu — owner choices, 2026-11-21

Client implementation ready for visual review. Source inspection and StyLua formatting only. No tests, lint, builds,
Studio sessions, browser or desktop control were used.

## Confirmed direction

The owner chose a cinematic spy gala with the agent taking center stage, slim navigation across the top, compact
mission essentials on the left and a prominent Play action at bottom-right. The setting is an open gala balcony at
night: city skyline, warm interior light and restrained ivory/brass presentation. The landing screen shows mode,
equipped agent/hardware, squad and Play; secondary mission details and first-launch claims open on demand.

## Built

- `src/client/Menu/LobbyViews/PlayLobbyView.luau`: remove the opaque ivory briefing card, decorative right-hand plate
  and persistent field-briefing block. A 304px left rail carries the operation title, mode and loadout. The compact
  squad stays upper-right; Play and its required setup/search feedback stay bottom-right. First-launch free picks and
  mission details expand when requested. The center operative name floats over the scene.
- `src/client/Controllers/MenuController.luau`: floating top navigation with selection underlines, compact wordmark
  and stacked balances; transparent header/footer and soft edge veils provide contrast without enclosing the stage.
  Existing Mint access, profile retry, settings, device hints, late-spectate and reopen guards are retained.
- `src/client/Menu/MenuTheme.luau`: shared ivory primary actions, translucent secondary controls, restrained dark
  panels, muted brass accents, text shadows and a dedicated navigation style. Hover, selected, disabled and controller
  focus feedback remain separate. All views using these helpers inherit the new presentation.
- `src/client/Menu/Components/ViewKit.luau`: common collection text gains the same shadow contrast.
- `src/client/Menu/Components/DecoArt.luau`: illustrated collection plates use dark engraved title bands with ivory
  text and subtle borders rather than opaque ivory banners.
- `src/client/Menu/Components/GalaSet.luau`: replace the enclosed column/window/chandelier set with an open balcony,
  balustrade, dark stone and velvet runner, warm side doorways, planters, eighteen skyline towers and distant stars.
  Static original geometry, no uploaded assets, NPCs, animation loops or additional world lights.
- `src/client/Menu/MenuStage.luau`: balcony floor and four local non-shadowed key/edge lights; remove enclosing walls
  and extra sconces. Preserve the local rig, weapon display, camera restoration and reduced-motion camera behavior.
  A missing rig template no longer caches a failed display request.
- `src/shared/GameConfig.luau`: cinematic layout/palette and balcony art settings; Play camera now centers the agent.
  No gameplay values, remotes, server files, Robux products, audio ids or tutorial changes belong to this pass.

The existing Find/Cancel requests, complete loadout persistence before matchmaking, direct pre-deploy path, Asset
requirements, free-agent claims and server-confirmed ownership remain in use. The Play label names the main action;
the server still decides deployment and queue state.

## Owner visual acceptance (not executed)

1. Reopen the menu in a fresh play session. Expect a centered operative, skyline behind an open balcony rail, warm
   doorway accents, ivory operation title on the left and Play at bottom-right. Center stage should remain clear.
2. Open each top tab, Mint and settings. Check the shared typography/control styling and visible controller focus.
   Confirm text remains readable over the scene at your normal window size.
3. Expand free picks on an account that has picks left, choose an agent, then inspect/customize the loadout. Open and
   close mission details. The left rail should scroll as needed while Play stays anchored on the right.
4. Confirm missing Assets still offer Choose Assets and prevent deployment. A complete loadout should enter the same
   agent-select flow as before. When configured for matchmaking, Searching/Cancel and failure feedback remain visible.
5. On joining a live match as a spectator, the menu must stay closed and the spectator camera must retain control.
   Returning to Lobby should restore the menu. Reduced Motion should keep camera changes immediate.

## Limits and handoff

No runtime or visual acceptance is claimed. Lighting/bloom, text metrics, skyline contrast, camera framing and
controller focus need owner review. The existing stage uses the shared true-form rig; this pass does not supply unique
agent outfits or new character art. The scene is static and silent. Existing map Lighting remains unchanged on the
client and server; night scenery is authored locally in the menu set.

No new SPEC-QUESTIONs. Ready for owner menu visual acceptance.

Claude prompt: read this report and the current .ai-sync locks. Preserve the new menu layout and its server-authority
contracts. Review your data/lifecycle end for first-launch free picks, saved loadouts, Find/Cancel and spectate-to-Lobby
transitions. Report precise client issues rather than editing a Codex-locked file. The owner requested no tests, lint,
builds, Studio or desktop control. No server or map-art changes are required by this menu pass; do not add audio ids,
Robux products or tutorial content. Keep your unrelated working changes separate.
