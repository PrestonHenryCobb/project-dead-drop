# Gadget HUD and picker — ticket 17-hud, 2026-10-28

Built against `.ai-sync/GADGET_CONTRACT.md` and `docs/GADGETS_DRAFT.md`. Client only; server gadget/loadout validation
and all gameplay behavior remain unchanged.

## What was built

- `src/client/Controllers/GadgetHudController.luau`: HudTheme/HudKit cards above Cover display the actual slots from
  GadgetController.state(), configured 2/3 keys, GadgetDefs names/categories, confirmed charges and the held slot's
  category-colored border/HELD caption. Held 0 highlights neither gadget. Hidden outside matches/before fresh state.
  No equip/deploy prediction or requests; static geometry/text introduces no decorative motion.
- `src/client/Combat/GadgetCard.luau`: shared category emblems for cards and picker rows: Recon circle/cyan,
  Infiltration diamond/royal blue, Evasion chevron/pink, Support rounded square/coral. UI only, never world markings.
- `src/client/Menu/LobbyViews/PreDeployView.luau`: picker iterates built GadgetDefs.order entries, seeds the draft
  from the profile or default picks, allows 0..Gadgets.Slots distinct gadgets and shows their slot order. Selection
  survives agent/hardware changes and profile redraws; unmount resets the draft. Lock-in sends a detached GadgetIds
  array (including explicit empty picks). UPDATE LOADOUT stays available for revisions before the server's cutoff.
- `src/shared/GameConfig.luau`: category/card presentation settings; Camera Room page control moves from DPadRight
  to ButtonR1 to avoid the gadget-cycle binding. F6 remains the PC camera-page key.
- `tools/check-gadget-hud.cjs`: actual full card/HUD/PreDeploy source regression coverage with real GadgetDefs.
- `tools/check-security-client.cjs`, `docs/SECURITY_CLIENT_REVIEW_2026-10-28.md`: camera-page control compatibility.
- `tools/check-intel-input.cjs`: supply the existing DroneController dependency as an inactive-drone fixture for
  the on-foot regressions; no Intel gameplay source change.
- `.ai-sync/TASK_QUEUE.md`: ticket status and handoff.

## Validation

Changed-file StyLua, full-source `stylua --check src`, `selene src` and Rojo build pass. 55 new gadget assertions pass;
1,511 across twelve checked client suites. Coverage includes all four category drawings/accents, confirmed slot/key/
charge/held state, no optimistic inventory changes, absent slots, pooled geometry, phase/round reset/cleanup,
layout bounds, default/empty/distinct/capped picks, request-copy isolation, revisions after lock-in, agent changes,
snapshot refreshes, cutoff and mount/unmount. No new native Studio rendering/input/network result is claimed.

## How to test in Studio

1. Solo, fresh Play: enter agent select. Gadget rows show the currently built GadgetDefs entries and category shapes.
   Defaults start selected. Remove a pick, add another, and verify no duplicates or more than Gadgets.Slots selections.
   Select zero/one/two, lock in and Deploy: the match HUD must reflect the server's actual resulting list.
2. During the full selection window, revise gadgets after locking agent/hardware and press UPDATE LOADOUT. Change
   agents and hardware too: draft gadgets stay selected; the final accepted request must be the deployed loadout.
3. In a match press 2/3, then 1: only the confirmed held gadget is highlighted; weapon held clears both highlights.
   Use a gadget successfully: its charge count changes only with GadgetState. A refused use must not reduce it locally.
4. Gamepad: DPadRight cycles weapon/gadgets. Near a Camera Room terminal, R1 changes feed pages without cycling gadgets;
   on PC, F6 still pages feeds. Menu gadget buttons must work through normal menu selection.
5. Check 1280x720 and a larger display, and Roblox Reduce Motion: cards remain readable, avoid Cover/ammo/ability UI,
   and add no animation. Lobby/Results hide the bar; starting a new match must not briefly show prior inventory.

## Gaps, contract notes, SPEC-QUESTIONs and next

Native text sizing, gamepad focus, long scrolling lists and multiplayer request timing need Studio acceptance.
The existing PreDeployState confirms agent/hardware but does not echo GadgetIds. The picker therefore retains a local
draft and offers UPDATE LOADOUT without claiming gadget confirmation; the match HUD uses authoritative GadgetState.
Optional future contract improvement: echo the accepted GadgetIds privately for selection confirmation. This patch
does not change the contract or infer acceptance. Local picker constraints are convenience; server validation remains
the sole authority and rejects unavailable/duplicate/oversized lists.

No new gameplay SPEC-QUESTION. Ready for 17-hud Studio acceptance; no next ticket started and no push performed.
