# Agent Tag and Rescue client — 18d-hud, 2026-10-28

Built against the 18d section of `.ai-sync/ECONOMY_CONTRACT.md` and the existing shared shop/interaction payloads.
Client only; no server, shared-contract or character metadata changes.

## What was built

- `src/client/Controllers/SecurityHudController.luau`: generic Take Agent Tag prompt from the existing
  SecurityInteractController target. Exact `InteractState.Kind = "Take Agent Tag"` drives the acknowledged pickup bar.
  Server Seconds and existing lifecycle/phase guards apply. No owner/team/agent identity is inferred from a tag.
- `src/client/Controllers/SupplyHudController.luau`: purchase status names the item currently reported in Buying,
  using its server-provided Name. Rescue flows through the existing authoritative offer/price/reason/purchase path,
  including its distinct BuySeconds. No local rescue completion, tag inventory or recipient is invented.
- `tools/check-security-client.cjs`: actual prompt, pickup progress and cancellation tests; server label guard.
- `tools/check-supply-hud.cjs`: real Rescue reason/id guards and UI tests for all four refusal reasons, a reported
  discounted price, existing buy request, reported three-second duration, and server-only balance/availability updates.
- `.ai-sync/TASK_QUEUE.md`: 18d-hud status and validation.

## Validation

Changed-file StyLua, full-source `stylua --check src`, `selene src` and Rojo build pass. Security suite: 56 assertions;
Supply suite: 50 assertions. Total: 1,597 across fourteen checked client suites. These execute actual client source with
service/clock/UI fixtures; they do not verify native networking, respawn placement, animation or multiplayer rules.
Static labels and functional progress add no decorative motion, preserving Reduce Motion behavior.

## How to test in Studio

1. Two-player Duos: eliminate one teammate while the other stays alive. Near the dropped tag, aim and hold E:
   TAKE AGENT TAG and the acknowledged pickup bar appear. Release early to cancel, then finish the pickup. The prompt
   should disappear when the server removes the tag. No owner label or fabricated carried-tag count should appear.
2. Carry the tag to a Supply Cache. Rescue teammate should show the server's price (10 Intel before any tier discount)
   and eligibility. Buy it: the status names RESCUE TEAMMATE, and the bar uses the reported duration (currently 3 s).
   Completion must come from server state; verify the teammate returns at the server-selected insertion point.
3. Check server-sent refusal reasons: no tag, Solos, Overtime and nobody eligible after the one-rescue limit. The UI
   must show each exact reason and prevent the unavailable button from sending a buy request.
4. After Rescue, verify the returned agent's normal HUD/spectating state and half cooldown from the existing server
   updates. Check that interrupted/failed purchases do not produce a local success message or optimistic Intel change.
5. Repeat with Roblox Reduce Motion and gamepad interaction; inspect the pickup bar and scrollable Rescue offer.

## Known gaps, questions and next

Native two-player pickup/carry/Rescue and the server's one-rescue/Overtime/respawn behavior remain untested here.
The current contract exposes no carried-tag list/count, tag expiry timestamp or Rescue recipient name. None is inferred
from an inactive hold, disappearing part, corpse, roster or guessed 90-second timer. A private state message would be
needed for those additional HUD features; no server change is requested as a prerequisite for this ticket.

The economy contract's old bottom Not built list still mentions 18c/18d; its detailed Built sections and current
server paths supply the payloads used here. That status wording needs a documentation refresh by its owner.
No new gameplay SPEC-QUESTION. Ready for 18d multiplayer Studio acceptance; no next ticket or push.
