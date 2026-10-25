# Gala art direction: source pass, 2026-10-25

**Latest:** the owner manually uploaded all twelve maps. Verified Image IDs now populate the reproducible installer;
all six Gala MaterialVariants are installed and the local scene rebuilt with zero problems. See the material-install
section at the end for actual loading and multiplayer results. Earlier upload-blocker notes below are historical.

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
4. The owner has completed the twelve-image upload on 2026-10-25. For replacement assets, use **Asset Manager > Images > Bulk Import** (or Material Manager's texture
   import controls) for the **12 PNGs** in `assets/gala/materials`. Import under the account/group that owns the
   experience and ensure the experience may use them. Wait for successful uploads/moderation. Do not import the JSON
   or Luau files as images.
5. Open `assets/gala/materials/install.luau` locally. Its `ids` table is filled from the verified **Image IDs** in
   `asset-ids.json`; Decal wrapper IDs are recorded separately and must not be used as material maps. Paste the complete
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

## Remaining at the first source pass (superseded by the sculpture pass below)

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

## Original sculpture pass and two-client review

The owner approved continuing all unfinished art and committing the changes. Seven original assemblies now exist:
faceted head/face, tapered jacket/collar, planar lapels, bow tie, fluted column, stepped brass chandelier and upholstered
settee. They use 15 material-separated components. The place uses baked native CSG from the authored recipes, so the
geometry does not depend on fabricated/uploaded mesh IDs. Blender source, FBX and an asset preview are committed
alongside those recipes. **The preview is a Blender render, not a Studio screenshot or final visual acceptance.**

| File | Built |
|---|---|
| `tools/build-gala-sculptures.cjs` | Original canonical geometry recipes; writes JSON and frozen Luau definitions. |
| `src/shared/Defs/SculptureDefs.luau` | Generated asset-space geometry for seven assemblies. |
| `tools/render-gala-sculptures.py` | Blender authoring/export/render using the same geometry, sRGB-to-linear material colors. |
| `assets/gala/sculptures/` | Editable `.blend`, canonical FBX, JSON, PNG asset preview and usage/provenance README. |
| `src/server/Tools/Gala/Sculptures.luau` | Edit-only CSG bake, atomic template replacement and scenery placement. No runtime/per-NPC CSG. |
| `src/server/Tools/Gala/Art.luau` | Fits fluted columns and chandeliers around existing collision solids/lights. |
| `src/server/Tools/Gala/Build.luau` | Bakes the asset cache; adds four settees through existing free-space reservations/navigation exclusions. |
| `src/shared/Util/SculptedOutfit.luau` | Same massless/nonqueryable cosmetic models on players and NPCs, with Janitor-owned body-size refitting and cleanup. |
| `src/shared/Util/OutfitApplier.luau` | Removes/refits the new models on disguise changes and restores native visuals if the cache is absent. |
| `src/server/Services/RigService.luau` | Finalizes NPC cosmetics after Humanoid/description cleanup, before the rig replicates. No combat/hitbox changes. |
| `src/shared/GameConfig.luau` | Ticket sculpture cache name, facial proportion/color and scenery placement tuning. |
| `src/client/Controllers/GraphicsController.luau` | Validated `setMode` shared by F7 and the settings/test caller. |
| `src/server/Tools/Gala/ReviewHarness.luau` | Explicit Studio-only two-client/server probes, removed when the test ends; no remotes. |

The first live check caught NPC accessory finalization removing the initial parts. The first two-client test then
caught player Humanoids double-scaling directly welded Accessories. The final implementation uses identical welded
cosmetic Models, fitted by the same helper; NPCs finalize after cleanup, and size changes refit through events. Original
Head/UpperTorso parts, joints and hitboxes remain. Swaps strip the cosmetic models and disconnect their callbacks.

Verification:

- Live crowd check passed: **201 rigs / 201 sculpted heads / 201 sculpted suits** in one-player Play.
- Guest → Security → Guest application and strip/restore assertions passed in an actual engine fixture.
- Final recipe rebuild returned **0 problems**, 102 rooms, 786 nodes; four settees were placed. Fresh-clone source
  guards and native CSG bake completed in Studio. The map remains below the 15,000-part target.
- Roblox `StudioTestService:ExecuteMultiplayerTestAsync(2, ...)` launched a server and two actual simulated clients.
  Server comparison matched both player outfits against the same NPC fixture: component classes, sizes, colors,
  materials, noncollision/nonquery and masslessness. **ServerPassed** was returned.
- **Both client logs independently reported PASS** for parchment HUD, Low/Medium/High shadow/bloom/ambient settings,
  pooled spark count/fade and replicated crowd sculptures. Server success alone was not used as client proof.
- StyLua, Selene, Rojo build and the existing 29-assertion melee regression passed.

To repeat the automated two-client review, in **Edit mode** after source sync run:

```lua
local module = game.ServerScriptService.Server.Tools.Gala.ReviewHarness:Clone()
module.Parent = game.ServerStorage
local ok, result = pcall(function() return require(module).run() end)
module:Destroy()
assert(ok, tostring(result))
print(result)
```

Require `ServerPassed`, **two** `GALA_REVIEW_CLIENT_PASS` entries and no `GALA_REVIEW_*_FAIL` entries. The test temporarily
uses a common Guest outfit on both players and a separate NPC fixture, then ends and removes its probe scripts. Do not
save the place mid-test. For appearance/game-feel review, use the earlier Play/Clients 2 steps; check hair/hat fit,
facial planes, tuxedo fit, animation, firing/reloading, wall tuck and respawn at normal gameplay distance.

The local place is `D:\Dead-Drop\CoverStory.rbxl`; the pre-sculpture backup is
`D:\Dead-Drop\CoverStory.before-sculptures-20261025.rbxl`. Rebuild is reproducible from source; source-only Rojo builds
use the existing native rig until the Edit-mode bake has created `ReplicatedStorage.GalaArtAssets`.

**Historical upload blocker:** browser file transfer remained declined, and Studio's CreateAssetAsync was unavailable.
The owner subsequently uploaded the twelve maps manually; the material-install section below supersedes this blocker.
No upload-gate workaround was used, no IDs were fabricated, and the game was not published.

**Remaining review:** viewport capture/coordinate control still fail, so no in-game screenshot, full visual acceptance,
actual mouse-driven fire/reload run or whole-game GPU/FPS acceptance is claimed. The automated two-client and quality
checks above are complete. **SPEC-QUESTION:** no new gameplay question; initial art proportions remain visual tuning.
**Ready for:** owner art review and authorized texture integration; continuing unblocked Codex client tickets is approved.

## Owner-uploaded material installation (2026-10-25)

The owner completed the upload manually after the browser transfer gate stayed blocked. All twelve matching PNG
names were verified under squareprep007's Creator Hub Decals AND Images listings. No permission settings or asset
privacy were changed by Codex. The inspected neutral-albedo Image is already Open Use.

What I built:
- `assets/gala/materials/asset-ids.json`: verified filename-to-Image-ID bindings and separate Decal-ID provenance.
- `tools/build-gala-materials.cjs`: preserves those verified Image IDs when regenerating the material pack.
- `assets/gala/materials/install.luau`: now contains the real twelve Image ContentIds; creates the six variants using the existing Edit-only installer.
- `src/server/Tools/Gala/ReviewHarness.luau`: compares player/NPC MaterialVariant names and requires the installed six variants to replicate when present in Edit. Texture properties are Plugin-protected, so their IDs are audited in Edit rather than read by ordinary client scripts.

Studio installation completed, then the fresh-clone scene rebuild returned **0 problems**. Existing scene bindings:
GalaBrass 902, GalaWalnut 524, GalaIvory 689 and GalaVelvet 318 parts. Steel and Suit are additionally consumed when
weapons/characters are constructed. The place backup is `D:\Dead-Drop\CoverStory.before-materials-20261025.rbxl`.

Loading check: the first bare-string preload reported twelve failures. The subsequent instance-based Decal probe
loaded **11/12** images; `roughness-184.png` (Image 82169046589228, steel roughness) still reported Failure at 16:58 UTC.
Engine logs distinguish unapproved assets (403) from material-pack representations still being generated (406).
Neither means a new browser-upload permission is needed. PreloadAsync cannot establish that MaterialVariant's
processed PBR texture pack has rendered correctly; visual inspection remains necessary. Later check results are
recorded in the final handoff. The final Edit audit at 17:04 UTC matched all 24 material map properties against the
verified bindings and again loaded **11/12** images; only the same steel roughness Image remained unavailable.

How to test in Studio:
1. Open the saved local place and start **Play** with one player. Walk between a chandelier-lit room and a dim room.
   Brass should have tighter highlights than ivory walls; walnut should stay satin with broad subtle bands; velvet
   and suits should remain matte. Weapon steel should retain its broad dark silhouette rather than appear glossy.
2. Press **F7** through quality modes. Low quality should remain readable; higher quality should reveal the material
   response. Check Output for new asset approval/processing errors before judging a missing texture as a palette bug.
3. Use **Test > Clients 2 > Start**. Compare the same outfit on a player and NPC, including the tailored torso and
   facial pieces. Material shading must not identify a disguised player. Fire/reload and respawn to inspect new guns/rigs.
4. For a clean source-only place, run the populated `install.luau` in **Edit**, rebuild with the command above, then
   save. To replace an image, update its verified Image ID in `asset-ids.json` and regenerate; do not substitute its Decal wrapper ID.

Validation: material generator regeneration preserves all texture hashes and bindings; StyLua, Selene and Rojo
build pass. The initial multiplayer probe exposed Plugin-only map-property reads in the test itself; those checks
were moved to Edit and the multiplayer review rerun. See the handoff for final server and both-client outcomes.
The final two-client run returned ServerPassed and BOTH clients independently logged PASS at 17:02 UTC, including
the six replicated variants, shared disguise finishes, existing HUD/quality/sparks/crowd and traversal fixtures.
Known gaps: pending asset approval/processed-pack availability and full visual/GPU acceptance. No game was published.
SPEC-QUESTIONs: no new gameplay questions; material proportions/response remain art tuning. Ready for: owner Gala
material review and the existing next gameplay step, Step 9c spectating.
