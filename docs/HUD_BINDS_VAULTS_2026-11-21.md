# Ability binds and vault graphic — 2026-11-21

Owner follow-up to the floating HUD pass. Client only; source inspection and StyLua formatting, no tests, lint,
builds, Studio or desktop control.

## Built

- `Controllers/AbilityHudController.luau`: persistent Talent bind above its icon. InputHints selects the configured
  keyboard key or gamepad button used by AbilityController, and refreshes on device changes. Talent names remain brief.
- `Controllers/GadgetHudController.luau`: persistent gadget binds beneath each icon; configured keyboard slots or
  controller cycle button via InputHints. Names remain brief and charges stay separate.
- `Combat/VaultProgressGraphic.luau`: original code-drawn vault-door icons in a linked horizontal row; each gets a
  circular progress dial, vault ID, numeric percentage, completion check and temporary contested warning backing.
- `Controllers/VaultHudController.luau`: replace the stacked text/bars with all three revealed active vault dials,
  centered below the watch. Existing phase/banner timing, authoritative progress and world markers are preserved.
- `Combat/HudLayout.luau`: reserve the row's actual dimensions below the watch.
- `shared/GameConfig.luau`: VaultGraphic dimensions and spacing, without gameplay changes.

## Owner visual acceptance (not run)

1. In a match, let the Talent/gadget names disappear. Their assigned bind labels should remain visible alongside
   charge/cooldown information. Switching keyboard/controller changes the labels to the current device.
2. During VaultBreach, after its phase banner, all three active vault graphics should sit below the watch in a row.
   Progress must follow the server. Contesting shows an amber warning; completion replaces the door with a check.
3. Returning to Lobby removes the row and world markers. A new round shows its own revealed vault IDs.

Known limit: no runtime/visual acceptance. No player key-remapping system was introduced: labels read the same
configured controls as the existing gameplay actions. The two inactive map vaults are not represented as hackable
objectives; only the server-revealed active set is shown. No new SPEC-QUESTIONs. Ready for owner HUD visual review.

Claude handoff: review this report alongside HUD_FLOATING_REDESIGN_2026-11-21.md. Preserve VaultProgress reveal timing,
IDs, progress and contested/completed flags; no server contract change was required for this graphic. Keep active
vault identities secret until VaultBreach. Preserve the owner's no-tests/no-desktop-control instruction.
