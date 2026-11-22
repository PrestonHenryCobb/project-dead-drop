# Asset picker clarity — 2026-11-22

Owner request: make the Asset picking screen clearer.

The old screen placed four slots and six large descriptions in separate scrolling lists, used signed percentages
without saying what improved, and had no clear completion action. Pre-deploy cycled unseen candidates on each click.

## Built

- `src/client/Menu/Views/AssetsCodexView.luau`: numbered select-slot/choose-Asset steps, all four rarity slots fixed
  on screen, EDITING state and a persistent rarity/name/effect summary. Six illustrated choices appear in a two-column
  scrolling list with plain-language effects for the active rarity. Existing picks explain which two slots swap;
  moving into an empty slot explains that the source becomes empty. Selected state and post-choice feedback are
  explicit. One Clear Selected Slot action, a persistent 4/4 readiness count and Continue to Play replace repeated
  clear controls and the ambiguous exit flow. Continue is disabled for incomplete drafts.
- `src/client/Menu/Components/AssetEffect.luau`: effect copy derived from AssetDefs values, including less suspicion,
  faster hacking/recovery, lower Intel prices, food healing/treatment speed and vent speed. Duct Rat states whether
  vents preserve Cover using the configured QuietVentFrom rarity. No balance or activation rules changed.
- `src/client/Menu/LobbyViews/PreDeployView.luau`: a rarity button opens six explicit choices directly underneath it,
  rather than cycling. Each choice states its rarity-specific effect and current/swap/move outcome. Choosing closes
  the list. Expanded state resets when the view unmounts.

The screen explains that a matching-rarity safe activates each chosen Asset during a match. All picks remain the
existing local AssetDraft; no fake Saved/Active state or new remote was introduced. Draft uniqueness, swaps, empty-slot
handling, matchmaking persistence and server-validated Lock In remain unchanged. Continue to Play only navigates.

## Owner visual acceptance (not executed)

1. Open Assets. All four current slots should be visible on the left. Select Ghost and inspect the choices: effects
   should show Ghost values and say what they improve, with the active rarity in the heading.
2. Choose an unused Asset, then one already assigned elsewhere. The two changed slots should agree with the preview
   and action feedback. Clear a slot: readiness falls to 3/4 and Continue disables. Fill it to restore readiness.
3. Move a used Asset into an empty slot. The source should be marked empty and readiness must remain incomplete.
   Continue to Play should retain the current draft without claiming that in-match bonuses are already active.
4. During agent select, open any Asset slot and choose from the explicit list. The displayed result and Lock In draft
   should agree. Compare lower/higher Duct Rat rarities for the quiet-vent threshold.

Validation: source inspection and StyLua formatting only. No tests, lint, builds, Studio or desktop control, per owner
instructions. Visual acceptance remains pending, including card wrapping, lower-list scrolling and controller focus
at the owner's resolution. No new SPEC-QUESTIONs. Ready for owner Asset picker review.
