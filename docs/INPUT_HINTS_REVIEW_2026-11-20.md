# Input hint integration review — 2026-11-20

Reviewed the owner's InputHints integrations in AbilityHud, BugCam, CarrierTrack, Cover, DownedHud, Elevator,
Menu, PackageHud, RouteHud, SecurityHud, SupplyHud and SettingsPanel, plus PackageController's gamepad drop binding.
Preserved the device-specific keys/buttons and subscription cleanup. InputHints is the required helper for new
control hints going forward. The shared helper is already committed by the owner.

Fixed three device-switch gaps: elevator refresh signatures now include the active input family; the menu footer
computes the current legend when a notice ends; settings session/re-cover descriptions choose the current device
too. The gamepad controls summary now mentions B to drop the Package. Keyboard control paragraphs remain hidden
on gamepad and the gamepad paragraph remains hidden on keyboard/mouse.

Included the existing settings/audio/camera/status dependencies needed by these mixed files. Config corrections
place MiniPixels/MiniZoomPixels/ShapeKey inside RouteHud and DropPackagePad inside Controls, matching their callers.
The unrelated tracker config correction remains outside this commit. The owner's other uncommitted documentation
and remaining client/weapon work are excluded.

Revisited minimap-size: the original mixed controller was committed in 2fdc27b. Its small default, M/Select cycle,
Comma shape preference, inscribed round layout and centering behavior remain; this commit adds device-specific
footer/target/mode hints and includes the required config placement correction.

Validation: source/diff review and StyLua formatting only. No tests, lint, builds or Studio/desktop control, per
owner instruction. Native acceptance remains: switch input devices while each HUD/menu is visible, switch during
a menu notice or elevator selection, and press B with a carried Package both with and without a modal open.
No new SPEC-QUESTION. Ready for review; no push requested.
