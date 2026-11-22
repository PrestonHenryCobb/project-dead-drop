# UI reference direction — 2026-11-22

Owner requested inspiration from [isaiahagi/roblox-ai](https://github.com/isaiahagi/roblox-ai), while retaining Dead Drop's style and vibe. Reviewed repository revision `082517a9ed1eca47dbd2a80496b4b0039bdf000a` as a visual reference library, not a UI dependency.

## References inspected

- [Minimal dark UI](https://github.com/isaiahagi/roblox-ai/blob/082517a9ed1eca47dbd2a80496b4b0039bdf000a/ui-styles/43-dark-mode-pro/minimal-260-2.png): subdued panel depth and clear control contrast.
- [Modern dark UI](https://github.com/isaiahagi/roblox-ai/blob/082517a9ed1eca47dbd2a80496b4b0039bdf000a/ui-styles/43-dark-mode-pro/modern-dark-2.png): thin edge highlights and layered surfaces.
- [Brass frame](https://github.com/isaiahagi/roblox-ai/blob/082517a9ed1eca47dbd2a80496b4b0039bdf000a/ui-styles/73-steampunk-brass/steampunk-ui-3.png): restrained metallic framing and title hierarchy.
- [Inventory grid](https://github.com/isaiahagi/roblox-ai/blob/082517a9ed1eca47dbd2a80496b4b0039bdf000a/ui-styles/curated-2026-11/inventory-grid.png): distinct selected items and readable selection context.

Also inspected the glassmorphism sample and shooter crosshair preview. Their bright palette and atlas were not adopted. Reference images were viewed from a temporary directory; no third-party images, audio or code were imported into the project.

## Implemented translation

- `MenuTheme`: background-only dark panel gradients, fine fading top highlights on non-navigation buttons, and a brass diamond for selected controls. Existing navigation underline and keyboard/gamepad focus treatment remain.
- `DecoArt`: original collection plaques gain inset keylines and an ivory catchlight. Archive folios use outlines; market case lids use dark fill with metallic trim. Medallion fields are more transparent.
- `ViewKit`: collection headings separate the main title from quieter, right-aligned context when a title uses ` / `.
- `HudIcons`: six original Asset pictograms replace unrelated kit-icon aliases: footprints, hand, eye/downward arrow, wallet, medical bag and vent/passage. Both menu choices and the gameplay Asset strip consume these drawings.

Ivory, muted brass, dark gala surfaces, the cinematic character stage and existing smooth transitions remain the visual foundation. Gameplay retains its floating presentation. No new hints, server requests or selection behavior were added.

## Review and handoff

Source changes reviewed and the four modified Luau files formatted with StyLua. No tests, lint, builds, Studio or desktop control were run, per owner instruction. Native rendering and font metrics still need owner visual acceptance:

- Selected cards should remain distinguishable from hover and keyboard/gamepad focus.
- Collection titles/context should fit at supported viewport sizes.
- Archive/market illustrations should remain legible without bright solid blocks.
- Asset icons should read in both the picker and the small gameplay strip.

For future client styling, use these references for hierarchy, edge treatment and legibility while continuing original Dead Drop artwork. Coordinate through the lock table before touching shared files. No new design questions or server work are required by this pass.
