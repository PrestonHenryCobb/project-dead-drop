# Lobby black rectangle — image follow-up

Owner's Capture.PNG shows a broad black rectangular piece across the forehead extending beyond the head. The
true-form outfit has no sunglasses; OutfitApplier builds its Crop hair as a flat rectangular black Part. The earlier
light-helper fix did not resolve the owner's reported obstruction.

## Changes

- `src/client/Menu/MenuStage.luau`: the local lobby copy of the fallback hair becomes a rounded crown, centered at
  the head's HairAttachment instead of offset down across the face. Shared outfits/gameplay appearance are unchanged.
- `src/client/Menu/Components/StagePose.luau`: resolve accessory Handle positions directly from matching body/handle
  attachments. A newly created preview no longer depends on the timing of Humanoid:AddAccessory's generated weld.
  Skip only the superseded body-to-handle constraint; preserve internal accessory welds. Grounding lifts only parts
  resolved into the posed assembly, so an unbound part cannot accumulate vertical offsets on every blend update.

Validation: source inspection and StyLua formatting only. No tests, lint, builds, Studio or desktop control, per owner.
The image identifies the flat face-level geometry; the corrected live silhouette/transition still needs owner
acceptance. Restart Play, look at the hairline and switch Play/Agents/Hardware. Hair should stay attached to the head,
with no rectangular visor or accessory floating upward. The held weapon and smooth pose/camera transitions remain.

No server/shared-outfit/config changes or new SPEC-QUESTIONs. Ready for owner lobby hair/attachment review.
