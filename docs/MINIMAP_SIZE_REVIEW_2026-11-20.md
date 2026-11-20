# Minimap size integration review — 2026-11-20

Reviewed the owner's mixed, uncommitted RouteHudController changes against the committed RouteMap follow API and
RouteHud config. Kept the 176-pixel corner minimap default, 960-pixel plan with continuous player centering,
M/Select small/full/off cycle and Comma square/round preference. The round layout contains an inscribed square
map window as requested. Full view restores the original GPS controls, map size and canvas position. View/shape
changes invalidate the map drawing; existing route authority, floor data and carrier-marker permissions remain.

Preserved Codex's input guard and added it to clickable target/mode controls too, so settings or other interface
blockers cannot activate the background GPS. Included the existing HeldItemController guard implementation in the
same commit because RouteHudController now calls its isInputBlocked API. That implementation also cancels held
weapon input on lost focus/native menu/life and phase transitions and orders dialog blockers by display/open order.
It has no dependencies on the other uncommitted new controller modules.

Validation: manual source/diff review and StyLua formatting only, per the owner's no-tests/no-desktop instruction.
No tests, lint, build or Studio session was run. Native acceptance remains: player centering at map edges, both
shapes, repeated small/full/off cycles, changing floors, gamepad Select and background controls under settings.
No new SPEC-QUESTION. Ready for review; unrelated work is excluded from this commit and no push is requested.
