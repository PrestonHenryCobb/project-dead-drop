# Gala art direction: source pass, 2026-10-25

Owner direction: Sculpted, Cinematic Stylization in an original Art Deco Gala, with clean low-poly geometry. The three
Gemini reference images supply mood, material hierarchy and silhouette targets, not layouts or assets to copy.
The owner's follow-up keeps the existing Public/Staff/Security/Executive tier colors and adds cyan accents.
The attachment's earlier three-way style comparison and full-scene outlines are not approved work.

## What is built

| File | Change |
|---|---|
| `src/shared/GameConfig.luau` | Ticket art section: surface targets, exact requested palette, lighting, geometry sizes and spark pool; Gala parchment/ink/font skin; brief impact and exposure fades. |
| `src/shared/Util/ArtSurface.luau` | Shared material application, installed-variant selection and native fallback; preserves physical properties before changing material. |
| `src/server/Tools/Gala/Materials.luau` | Edit-mode installer validates all supplied uploaded texture IDs before replacing six named MaterialVariants. No global material overrides. |
| `src/server/Tools/Gala/Art.luau` | Map finish pass: ivory pillars, walnut furniture, brass rails, quiet velvet finishes and two-sided geometric glass patterns; skips the distant city and one-way privacy panes. |
| `src/server/Tools/Gala/Build.luau` | Ivory Deco walls, walnut wainscot, brass lamp surrounds, cyan threshold SurfaceGuis and warm keys; requested ambient/bloom/grade; attempts current Realistic lighting in Edit mode. Existing layouts, collision solids, clearance rules and gameplay tags are retained. New wall panels and rims do not collide or participate in raycasts. |
| `src/shared/Util/OutfitApplier.luau` | Same material path, angled lapels and cyan badge for player disguises and NPC outfits; retains tier colors, body sizes, joints and hitboxes. |
| `src/shared/Util/HudTheme.luau` | Map skins can override text colors and font without changing behavior/layout. |
| `src/shared/Util/HudKit.luau` | Sans typography and unoutlined ink on cards; world overlays retain light text. |
| `src/client/Controllers/CombatHudController.luau` | Health/ammo/caption card text uses the active skin. |
| `src/client/Controllers/CoverController.luau` | Ink on cream cards; state colors stay on meters/pips; brief exposure fades. |
| `src/client/Controllers/DisguiseController.luau` | Ink role labels and tier-colored pips remain readable on parchment. |
| `src/client/Controllers/GraphicsController.luau` | Low quality uses a lighter warm/cool ambient fallback; existing F7 quality control/light cap remain. |
| `src/client/Combat/ViewModel.luau` | Steel main surfaces, walnut stocks, brass sights/trigger guards for both local and shared third-person weapon builders. No framing, timing or weapon stats changed. |
| `src/client/Combat/ShotFx.luau` | Janitor-owned pool of geometric map-impact sparks, 0.2 seconds, no Instance per shot or per-frame table creation. Sound retained; no FX on characters. |
| `tools/build-gala-materials.cjs` | Deterministic, original 1024px RGB PNG generator and binding manifest. |
| `assets/gala/materials/` | Twelve upload-ready maps, six-material manifest and fresh-clone Studio installation script. Neutral tintable albedo, four broad walnut paint bands, flat normal, grayscale metal/roughness maps. |

## Exact Studio steps

1. **Stop** the current playtest. Connect Rojo and allow source sync to finish. Save a separate copy of the current
   place before rebuilding: the existing Gala generator replaces `Workspace.Gala`, including manual map edits.
2. You can preview native fallback finishes immediately. In **Edit mode**, open **View > Command Bar** and run:

   ```lua
   local clone = game.ServerScriptService.Server.Tools.Gala:Clone()
   local shared = game.ReplicatedStorage.Shared:Clone()
   shared.Name = "SharedOverride"
   shared.Parent = clone
   clone.Parent = game.ServerStorage
   local ok, result = pcall(function() return require(clone.Build).run() end)
   clone:Destroy()
   assert(ok, tostring(result))
   print("Gala build result:", result)
   ```

   Read the final `[Gala]` checks in Output. Expect zero problems. Record the printed part count: this pass adds one
   wainscot per eligible wall face and at most one rim per existing lamp (110 lamps maximum). Compare with the roughly
   15,000-part finished-map target. Do not treat a successful Rojo build as a live map/nav/performance test.
3. Select **Lighting** in Explorer. Confirm **LightingStyle = Realistic** and **PrioritizeLightingQuality = true**.
   If the generator warns that those properties cannot be assigned, set them in Properties. Older Studio uses
   **Technology = Future**. Current Roblox documents Realistic as its advanced lighting mode; Technology is deprecated.
4. For exact material roughness/metalness, use **Asset Manager > Images > Bulk Import** (or Material Manager's texture
   import controls) for the **12 PNGs** in `assets/gala/materials`. Import under the account/group that owns the
   experience and ensure the experience may use them. Wait for successful uploads/moderation. Do not import the JSON
   or Luau files as images.
5. Open `assets/gala/materials/install.luau` locally. Fill its `ids` table with each uploaded filename and content ID:
   `ids["neutral-albedo.png"] = "rbxassetid://..."` using the **real ID**, and likewise for every PNG. Paste the complete
   script into the Studio **Edit-mode** command bar. Missing IDs fail before material installation starts. Expect
   `GalaIvory`, `GalaWalnut`, `GalaBrass`, `GalaSteel`, `GalaVelvet`, `GalaSuit` under **MaterialService**.
6. Re-run step 2 so scenery binds the installed variants. Save the place. Source sync alone does not upload image
   assets, persist MaterialService instances or rebuild the map. Newly spawned guns/outfits bind variants on creation.
7. **One player:** Test > Play. Expect parchment cards, dark readable health/ammo, retained tier pips, warm ivory/walnut
   rooms, brass rails and cyan threshold accents. Walk through a threshold: collision and clearance rules should be
   unchanged. Check the courtyard, atrium, casino, security rooms, stairs and privacy glass. Inspect chevrons from both
   sides; they must not draw through walls. Fire at a wall: short geometric sparks, no lingering dust cloud. Guise's
   Quiet SMG must still show no muzzle flash/tracer. Check reload, aiming, wall tuck and respawn still work.
8. **Two players:** Test > **Clients 2 > Start**. Compare an NPC and the other player wearing the same disguise in the
   same light: same rig, angled lapels, badge and material response; no player-only glow or extra identity markings.
   Fire at each other and confirm the brief directional damage indicator; break Cover and confirm the brief exposure
   flash does not hide the crosshair. No new through-wall enemy visibility is granted.
9. On each client cycle **F7** through Low/Medium/High, and also test Roblox graphics levels **1–3**. Ivory silhouettes,
   clearance tiers/cyan accents, health/ammo and dark gun silhouettes must remain readable with bloom/shadows reduced.
   Check at **1280×720**. Profile the 200-NPC crowd and new SurfaceGuis before accepting performance.

## Validation performed here

- StyLua full-source check, Selene (zero errors/warnings/parse errors), Rojo build and git whitespace check.
- Official Luau CLI: compilation of changed/new modules and generated installer; 12 assertions execute the actual
  frozen GameConfig and HudTheme with engine value fixtures (default/cache/fallback, palette/font/layout and targets).
- All 24 map references decoded: 1024×1024 RGB data and exact quantized grayscale roughness/metalness checked.
- Existing melee regression: 29 assertions still pass against actual server action/helper bodies.
- Initial source-pass checks did not include Studio. The subsequent live validation below supersedes that limitation
  for the rebuild and one-player runtime checks only.

## Live Studio validation, 2026-10-25

Owner authorized direct computer operation. Open place: `D:\Dead-Drop\CoverStory.rbxl`.

- Saved the pre-rebuild scene and copied it to `D:\Dead-Drop\CoverStory.before-gala-art-20261025-0416.rbxl`.
- The first rebuild exposed an existing generator error at the synthetic stair/gondola gaps: they have no layout
  door/second room, but the doorway renderer dereferenced `roomB.tier`. `Build.luau` now skips doorway decoration for
  these full-height openings after rendering their adjacent wall segments. Real doors still use the existing logic.
- Retried with fresh cloned modules and an explicit source-sync guard: **0 problems**, **102 rooms**, **143 zone
  volumes**, **54 clearance doors**, **6 keycard doors**, **786 NPC nodes**. Generator reported 9,766 parts; a complete
  descendant audit counted **9,797 BaseParts**, including descendants outside that counter.
- Audit found **184 noncolliding/nonqueryable/non-touchable walnut panels**, **96 lamp rims**, **120 cyan threshold
  SurfaceGuis** and **192 glass-chevron SurfaceGuis**. These counts are not a GPU/UI performance acceptance.
- Saved rebuilt place. F5 one-player test started all **25 client controllers** and the **200-NPC** crowd.
- Checks ran in the actual local client: HUD backdrop `f4efe6`, transparency approximately `.08`, health text `1a1918`,
  font `GothamMedium`; camera `LockFirstPerson`; owner Head and UpperTorso local transparency both `1`.
- Actual `ShotFx` impact calls built **64 spark parts**. Another 24 impact calls retained exactly 64 parts, and all
  64 had transparency `1` after `.3` seconds. No new geometry per impact; test effects disappeared when Play stopped.
- Actual lighting readback: `Realistic`, prioritization true, ambient `181c24`, outdoor `1d283a`, bloom approximately
  `.35`, threshold `1.8`. Studio logged its advanced/Future shadow renderer being enabled.
- The existing NPC script profiler reported around 1.94 ms average client work/frame and 9.76 ms average server
  tick in one sample. These are script measurements, **not** whole-game frame times or a validated FPS claim.
- F7 while command-bar focus was active did not reach the gameplay input handler; Low/Medium/High visual tests remain
  pending with the viewport focused. The test was stopped with Shift+F5; Studio was returned to Edit mode.

Computer controls could read/set the command bar and run keyboard shortcuts. Screen capture repeatedly timed out,
and coordinate-based controls reported `coordinate input geometry is unavailable`. Commands were verified through
Studio's local CreatorOutput log. **No viewport screenshot, two-client test, full navigation report, GPU profile or
visual art acceptance is claimed.** Existing engine warnings included wrap-deformer mesh-fetch failures and an
asset-type mismatch for texture ID `203785492`; that ID is not in the repository source and was not replaced blindly.

Attempted the supported AssetService upload workflow for the original neutral image. This Studio build returned
`CreateAssetAsync and CreateAssetVersionAsync are not available yet`; the image was cleaned up and no successful
uploaded asset ID was returned. The place is local (`PlaceId = 0`, `GameId = 0`). The 12-map pack remains ready for
normal Studio image import, and the six PBR variants have **not** been installed. The rebuilt scene uses native
fallback finishes. The game was not published to create an experience ID.

## Remaining art and integration work

This is the source/material foundation, **not the finished sculpted reference scene**. The existing native R15 faces
and body meshes are retained. Sculpted facial planes, beveled collars, tailored torso meshes, fluted architectural
meshes, proper chandelier meshes and modeled velvet seating still need original authored/imported mesh assets and
crowd/rig acceptance. Angled rectangular lapels are not presented as sculpted or beveled meshes. Existing stepped
motion stays removed. No mesh asset IDs were invented and no random Creator Store models were substituted.

Exact PBR response remains pending the owner-side image upload/install. Without installed variants, source uses clean
native materials; the numerical Roughness/Metalness entries are targets, not unsupported Roblox scalar properties.
Flat normals preserve existing native normals; they do not manufacture facial bevels. Brass highlights, dark panels,
chevron aliasing, low-quality ambient tuning and extra part/UI counts need Studio review. Native glass retains its
engine-specific appearance rather than claiming an exact IOR/frost shader. Impact sparks use pooled geometry instead
of ParticleEmitters to avoid needing a further uploaded sprite and to keep the shape crisp.

**SPEC-QUESTION:** unspecified steel/suit/velvet PBR values and the low-quality fallback are initial visual tuning,
not gameplay changes. Review them under the installed materials. No further clearance question is open.

**Ready for:** Gala source-pass Studio review and material import, then the original sculpted mesh/rig art pass.
This does not advance an unrelated BUILD_ORDER gameplay ticket.
