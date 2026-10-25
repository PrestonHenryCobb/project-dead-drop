# Original Gala sculpture assets

These are original low-poly assets authored for Cover Story, not models copied or downloaded from the reference games.

- `geometry.json`: canonical Roblox-space recipe for seven assemblies (15 material-separated components).
- `GalaSculptures.fbx`: canonical components at their authored origins, exported from Blender for further mesh work.
- `GalaSculptures.blend`: editable source plus a staged review scene.
- `asset-preview.png`: Blender asset preview. **Not a Roblox screenshot.** The reference rigs' hair/limbs are not
  included in this detached head/torso presentation; the game retains its existing shared hair/limbs and joints.

Regenerate with `node tools/build-gala-sculptures.cjs`, then format `src/shared/Defs/SculptureDefs.luau` with StyLua
(0.20.0 may need a second pass for its nested-table formatting fixed point). To export/render, run Blender in background
with `--factory-startup --python tools/render-gala-sculptures.py`. Render material colors are converted from sRGB to
linear; the Studio code uses the exact configured Color3 palette.

The playable place uses baked Studio CSG from the **same recipes**, so these original shapes do not require uploaded
mesh IDs. `Tools.Gala.Sculptures.bake()` only runs in Edit mode, before the existing Gala rebuild. It replaces the
`ReplicatedStorage.GalaArtAssets` template folder only after the entire new bake succeeds. Runtime outfits clone the
cache; no player/NPC runs CSG. Rebuild via fresh clones as documented in `docs/GALA_ART_REVIEW.md`.

Both players and NPCs use the same SculptedOutfit helper, material path and canonical pieces. Head/UpperTorso remain as
the original joint/hitbox parts, with their visuals hidden only after fitting succeeds. Sculpted faces/jackets cannot
collide, receive queries or add mass. These are welded cosmetic **Models**, avoiding Humanoid auto-scaling of Accessories
(which would double-scale players but not NPCs). NPC fitting happens after Humanoid/description cleanup, before the rig
enters the replicated world. Disguise stripping removes those models and restores native transparency before refitting.
Janitor-owned size-change connections keep the visual pieces fitted if the Humanoid settles its scale after a swap;
there is no per-frame fitting loop, and removing an outfit disconnects its connections.

Pillars retain their original collision shapes. Chandeliers reuse the existing indexed lights; no additional lights
are created. Settees are placed through the generator's existing free-space reservation path and use separate seat,
back and arm pieces for collision instead of a full-height invisible bounding box. Recipes remain adjustable source
art, not immutable production art approval.

Texture uploads are a separate task: baked geometry uses native material fallback until the six MaterialVariants from
`assets/gala/materials` are installed. No fabricated mesh/image IDs or temporary texture URLs are embedded here.
