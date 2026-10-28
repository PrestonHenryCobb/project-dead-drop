# Assets client — ticket 18e-hud, 2026-10-28

Built against `.ai-sync/ECONOMY_CONTRACT.md` and `docs/ASSETS_DESIGN.md`, including the owner's final four decisions.
Client only; no server, remote, shared type or gameplay-rule edits.

## What was built

- `src/client/Menu/Views/AssetsCodexView.luau`: Assets tab is now a four-slot draft in Field Agent, Infiltrator, Black Ops,
  Ghost order. Each slot can choose from AssetDefs.order; choices used in another slot are unavailable. Names,
  descriptions and signed percentage values come from AssetDefs/get/valueOf, replacing the obsolete static codex text.
- `src/client/Menu/AssetDraft.luau`: shared local draft for the tab and agent select. Seeds from a valid profile/default
  selection, normalizes invalid initial entries for display, and returns copies. Late profile data can seed an untouched
  draft; edits are preserved. This is a draft, not confirmed ownership or an activated Asset.
- `src/client/Menu/LobbyViews/PreDeployView.luau`: existing lock-in request includes four AssetIds in rarity order, along
  with agent/hardware/gadgets. The server remains the authority; no separate equip/unlock request is invented.
- `src/client/Controllers/AssetHudController.luau`: four-slot vertical strip in the right HUD stack, between warnings and
  ability/ammo. Only private AssetState supplies IDs/Found. Found slots light their rarity/name; unfound ones stay dim.
  Slot order follows the definitions; round reset clears stale state. Event-driven/static; no decorative motion.
- `src/client/Controllers/AssetSafeController.luau`: map BaseParts tagged AssetSafe follow Rarity and Opened attribute
  changes. Opened safes dim; removal/teardown restores original colour and disconnects. Parts inside a Humanoid model
  are rejected even if incorrectly tagged. No tags/attributes/names, highlights or effects are added to characters/NPCs.
- `src/client/Combat/AssetStyle.luau`: shared display names, signed value formatting and existing tier/rarity colours.
- `src/client/Controllers/SecurityHudController.luau`: Open safe contextual prompt and acknowledged hold label.
- `src/shared/GameConfig.luau`: separate client-only AssetHud geometry/dimming settings.
- `tools/check-assets-client.cjs`: actual definitions/draft/tab/lock-in/strip/safe tests; gadget/security fixtures updated
  for the new draft dependency and safe hold. `.ai-sync/TASK_QUEUE.md`: status and handoff.

## Validation

Changed-file StyLua formatting, full-source `stylua --check src`, `selene src` and Rojo build pass. 69 new Assets
assertions and two additional security assertions; 1,668 across fifteen checked client suites. Coverage includes all
24 value combinations, four distinct picks, request order/copy isolation, profile updates, no optimistic Found state,
safe tint/dim/reset/streaming/cleanup, actor protection and strip clearance from ability/ammo at three viewport sizes.
No new native Studio rendering/network/interaction result is claimed.

## How to test in Studio

1. Solo, fresh Play: open Assets. Select each rarity and browse all six definitions. Check -/+ values against the design
   (for example Ghost Light Feet -50%, Ghost Steady Nerves +150%). An Asset assigned elsewhere cannot be duplicated.
2. Assign four different Assets, choose Play and enter agent select. Lock in and Deploy.
   The match strip must show the server's four selections, initially NOT FOUND. Menu changes alone must not light slots.
3. Approach safes: grey/green/dark purple/gold correspond to their Rarity. Open one: the world safe dims and only the
   confirmed matching slot lights. Downing keeps Found; elimination/rescue clears it only through server AssetState.
4. End/start a match or stream a safe out/in: no stale slots, colours or connections. Check ordinary players/NPCs receive
   no new metadata or effects. Enable Reduce Motion: selections/Found/tints remain functional without decorative animation.
5. Check 1280x720/larger displays, scrolling and gamepad navigation. Two players should race a safe: only the server winner
   receives a Found slot; no optimistic local unlock or double award should appear.

## Known gaps, SPEC-QUESTIONs and next

Native menu focus/text layout and multiplayer safe races need Studio acceptance. Claude's 568dff6 adds four Tier 0
safes, making Field Agent available. The contract reports the Studio rebuild passed with zero problems and says the
owner must save the place. No fake safe or alternate reward is added by this client patch.
PreDeployState does not echo AssetIds, so the menu labels its choices as a draft and submits them; AssetState is the
confirmed in-match truth. Edit Assets in the Assets tab before entering agent select. No persistence or Stocks/Credits
purchase path is added.
No new gameplay SPEC-QUESTION. Existing Field Medic/quiet-vent questions remain owned by the server contract.
Ready for 18e-hud Studio acceptance; no next ticket or push.

Claude released the gaps-1 GameConfig lock after 568dff6; the complete client patch can now be committed together.
No Tier 4 keycard HUD is added: the printer contract exposes no KeycardState message, and Notifications are not inventory.
