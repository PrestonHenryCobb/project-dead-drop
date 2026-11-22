# Floating HUD redesign — 2026-11-21

Status: client implementation ready for owner visual review. Source inspection and formatting only. No tests, lint,
builds, Studio sessions, or desktop control were run, following the owner's instructions.

## Owner decisions

- Top-center digital MM:SS watch with a circular countdown ring.
- Fully transparent gameplay widgets, fine ivory line icons, subtle outlines and shadows. Temporary dark backing for
  critical warnings. Full-screen results, briefing, supply, feed/elevator selectors and explicitly expanded GPS remain
  readable views with dark surfaces.
- Top-right minimap; preserve M small/full/off and Comma round/square, including existing device-specific hints.
- Vertical health at the left and segmented shield at the right of the bottom-left disguise/cover cluster.
- Gadgets next to those bars. Ability next to the bottom-right ammunition count.
- Essential numbers persist. Names and control hints appear briefly when relevant, rather than remaining on screen.
  Critical instructions and objective state remain readable for their duration.

## Implementation

- `src/shared/GameConfig.luau`: transparent gameplay palette, ivory ink, fine icon strokes and a FloatingHud section
  for geometry, contextual hint duration and warning contrast. Gameplay numbers are unchanged.
- `src/shared/Util/HudKit.luau`: transparent panel default, explicit opt-in surface, text/line shadows, shield and Intel
  symbols, custom line drawings and a reusable segmented ring that updates only when its appearance changes.
- `src/client/Combat/HudIcons.luau`: original code-drawn silhouettes for all twelve gadgets, eighteen selectable
  Talents and the six Assets. Ability display names resolve against AgentDefs locally because CooldownUpdate carries
  Name, Seconds and ReadyAt. No remote/type changes, uploaded art or actor attributes.
- `src/client/Combat/HudLayout.luau`: reserve top-right map footprint, put Package/extraction and transient warnings
  beneath it, and reserve the taller watch above the Vault display.
- `src/client/Controllers/CombatHudController.luau`: bottom-up health and shield brackets, plate segmentation,
  health/shield symbols and HP; damage feedback stays on the health fill. Low HP gets temporary number backing.
  Weapon name appears briefly on hardware changes. Reticle, reload, damage direction and takedown logic are preserved.
- `src/client/Controllers/DisguiseController.luau`: disguise and tier indicators sit inside the brackets; stored-slot
  symbols stay visible, while role/slot hints appear briefly on actual disguise changes or device change.
- `src/client/Controllers/CoverController.luau`: cover eye and suspicion meter share the bottom-left cluster; ordinary
  state labels disappear, with exposed/recovery instructions and contextual warnings retained.
- `src/client/Controllers/GadgetHudController.luau`: compact distinct icons beside shield, persistent charge counts,
  held-slot outline, depleted/tased dimming and brief device-specific names/hints on equip, use or device change.
- `src/client/Controllers/AbilityHudController.luau`: selected Talent icon beside ammo, cooldown ring and remaining
  seconds, brief name/input hint on new cooldown information or device change, explicit taser warning backing.
- `src/client/Controllers/RouteHudController.luau`: minimap anchored top-right, subtle square/round boundary, retained
  size/shape/route controls. Explicit full GPS receives a readable surface above ordinary gameplay HUDs.
- `src/client/Controllers/MatchController.luau`: transparent 88px watch with server-deadline ring and MM:SS. Overtime
  and the configured timer warning period use warning contrast. Briefing/results explicitly retain dark surfaces.
- `src/client/Controllers/PackageHudController.luau`: objective panels use the reserved regions below the minimap.
- `src/client/Controllers/VaultHudController.luau`: move the terminal display down to clear the watch.
- `src/client/Controllers/AssetHudController.luau`: compact icon/value strip at the left edge above the vitals; rarity
  color and dimming show found state. Names/rarities appear briefly when the authoritative slot state changes.
- `src/client/Controllers/IntelHudController.luau`: Intel symbol and balance, with a numeric team station count/check.
- `src/client/Controllers/DownedHudController.luau`: critical life-state warning keeps temporary dark contrast.
- `src/client/Controllers/SupplyHudController.luau`: opt the shop overlay into a readable surface.
- `src/client/Controllers/ElevatorController.luau`: opt the level selector into a readable surface.
- `src/client/Controllers/SecurityHudController.luau`: opt the manual feed selector into a readable surface.

## Owner visual acceptance (not executed)

1. In one normal match, look at the top-center watch, top-right mini map, bottom-left bracket cluster, adjacent gadget
   icons and bottom-right ammo/ability. Ordinary gameplay should have no rectangular white or dark panel backing.
2. Cycle M through small/full/off; toggle Comma. The small map stays top-right and the explicit GPS clears ordinary
   objective text. Check the watch/Vault and map/objective spacing at your usual resolution.
3. Change/consume gadgets, activate a Talent and swap disguise/hardware. Names/hints should last three seconds while
   charges, cooldown seconds, HP, armor segments and ammo remain visible. Changing device briefly restores its hints.
4. Look at low HP, exposed/recovery, taser lock, downed and Overtime states when they occur. Critical warnings should
   retain contrast and then disappear. Repeat a round and confirm old state does not linger.
5. Briefing, results, supply, elevator and manual feeds should still have readable dark surfaces.

Known limitations: no runtime or visual verification; native font metrics, thin-line contrast on bright world surfaces,
full GPS layering and small-window spacing need owner acceptance. Existing viewport scaling is preserved. Above/below
1280×720 is not a new supported-device promise. No new SPEC-QUESTIONs; ready for HUD visual acceptance.

## Prompt for Claude

Read AGENTS.md, .ai-sync/AI_SYNC_STATE.md and docs/HUD_FLOATING_REDESIGN_2026-11-21.md. Codex implemented the owner's
floating HUD choices. Review your server/data end of this change: owner-only HealthUpdate HP/Armor and plate limits,
GadgetState IDs/charges/held slot, CooldownUpdate Name/Seconds/ReadyAt, and PhaseChanged MainEndsAt/EndsAt/StartedAt
must remain consistent through insertion, use, death, rescue, late spectating and the next round. Check that selected
Talent display names match AgentDefs and that any server-created legacy ScreenGui/template cannot reintroduce opaque
gameplay panels. Source review only: the owner said no tests, lint, builds, Studio or desktop control. Lock every file
before editing and preserve other uncommitted work. Fix concrete server lifecycle/data defects in your own files;
report any client issue as a precise handoff before editing a Codex-locked file. Keep the confirmed layout: watch
top-center, mini map top-right, vertical HP/shield around bottom-left disguise/cover, gadgets beside the bars and Talent
icon beside ammo. Do not change balance, add remotes without a demonstrated need, add audio ids/Robux products or build
the tutorial. Record findings and any server changes in .ai-sync; do not claim runtime acceptance.
