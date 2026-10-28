# Supply Cache shop — ticket 18c-hud, 2026-10-28

Built against `.ai-sync/ECONOMY_CONTRACT.md` and Types.ShopStateInfo. Client only; no server/shared-contract changes.

## What was built

- `src/client/Controllers/SupplyHudController.luau`: HudTheme/HudKit modal opens only from private ShopState.Open.
  Its scrollable offers show server Name/Price and unavailable Reason, alongside the reported team Intel balance.
  Buy requests send only the selected Id through RequestShopBuy. The client does not deduct Intel, change inventory,
  predict availability or start a purchase before Buying arrives. BuySeconds drives receipt-relative progress; full
  progress stays visible until a server update ends Buying. Same-purchase snapshots do not restart the cosmetic bar.
  Close button, Escape, B/Backspace, lifecycle changes and server close release the screen and its input blocker.
  Static rendering adds no decorative motion or easing; functional progress remains under Reduce Motion.
- `src/client/Controllers/HeldItemController.luau`: UI-owned input blockers cancel existing fire/aim and prevent shop
  clicks from firing/deploying. Closing releases only that UI's blocker and preserves the confirmed held item.
- `src/client/Controllers/SecurityHudController.luau`: contextual cache-open prompt and acknowledged Supply Cache hold;
  economy station/tier-door labels and purchased Use keycard hold are included without inventing keycard inventory.
- `tools/check-supply-hud.cjs`: actual shop and held-item routing regression tests.
- `tools/check-security-client.cjs`: match the server's new conditional keycard/lockpick label and test cache/keycard HUD.
- `.ai-sync/TASK_QUEUE.md`: 18c-hud status and handoff.

## Validation

Changed-file StyLua, full-source `stylua --check src`, `selene src` and Rojo build pass. 41 Supply assertions and three
additional security assertions pass; 1,585 across fourteen checked client suites. Tests cover exact server prices,
reasons/balance, disabled/affordability states, one unacknowledged request, no optimistic spend/progress, duplicate
purchase snapshots, completion only from server state, Escape/button/pad/lifecycle close, input gating, held-item
preservation, bounded layout/scroll area and teardown. Native rendering/input/network behavior remains unverified.

## How to test in Studio

1. Solo, fresh Play, deploy and approach a Supply Cache. Hold E to open. Read the six item names/prices, team Intel
   and any unavailable reasons. Try a higher-tier cache: the UI must show its server-discounted prices unchanged.
2. With sufficient Intel and a need for an item, click Buy. The bar starts only on Buying; the balance and stock change
   only on server completion. Check plate, ammo, heal, gadget charge, ability reset and Security Keycard separately.
   Purchases break Cover. Try full resources or insufficient Intel: no fabricated successful purchase should appear.
3. While the modal is open, clicking an offer must not shoot/deploy. Close and verify the previously held weapon or
   gadget still works with a new press. Try Escape, B/Backspace and the close button. Walk out of range/down the shopper:
   the server close must dismiss the UI and release input.
4. Use a purchased keycard on an existing/test keycard door: the acknowledged hold displays USE KEYCARD. No keycard
   count is invented because ShopState does not report remaining uses.
5. Two players: spend shared Intel concurrently and test cache exclusivity. The server owns acceptance; check that
   refreshed shop state replaces stale prices/eligibility without local refunds or optimistic balance changes.
6. Verify mouse and gamepad focus, scrolling to all offers, 1280x720/larger layouts and Roblox Reduce Motion.

## Known gaps, SPEC-QUESTIONs and next

Native layout, focus and multiplayer timing need Studio acceptance. Buying has no absolute start timestamp; progress
is cosmetic from the first received Buying snapshot and never declares completion. A request dropped before a server
reply leaves REQUEST SENT; closing/reopening permits retry without an invented timeout or automatic purchase retry.
ShopState does not publish remaining Security Keycard uses, so no count is fabricated.
No contract/server mismatch or new SPEC-QUESTION found. Ready for 18c-hud Studio acceptance. Agent Tag/Rescue remains
a separate server/client contract and ticket; no 18d work was started in this patch. No push performed.
