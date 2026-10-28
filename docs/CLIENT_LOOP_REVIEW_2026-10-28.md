# Client round-loop continuation

Source work continued without a Studio playtest, as the owner requested. Claude's server code and client interaction
controllers were left alone; their published Match, Intel, Vault and Package contracts drive this UI.

## Completed client work

- `972a088`: local knife pickup prompt eligibility/cleanup; data-derived melee, pellet and throwable armory text.
- `767a52a`: insertion briefing/fade, server-clock timer, phase banners, lobby wait and results; private teammate
  diamonds/outlines; insertion prediction gate. Detailed files/checks: `MATCH_CLIENT_REVIEW_2026-10-27.md`.
- `c33ad3f`: Intel balance/taken count, nearby LOS-limited taken-station checks and acknowledged hack bar; revealed
  VaultBreach terminal bars/world markers; separate objective/body progress ownership. No objective progress prediction.
- Package client integration: `Combat/PackagePresentation`, `Combat/ExtractionAircraft`, `Controllers/PackageHudController`;
  overtime/result updates in MatchPresentation/MatchController; extraction freeze in WeaponController; presentation
  config in GameConfig; new/extended source regression scripts. All six weapon definitions remain registered.

## Package/extraction behavior

- Resting Package markers use only the position sent by the server. A rival carrier pulse vanishes at PulseUntil even
  if no later packet arrives. No carrier identity, rig or position is inferred from other characters.
- Carrier/team banners and the configured X drop hint follow YouCarry/TeamCarries. Extraction countdown, team label,
  zone marker and acknowledged pickup/pass/call/channel progress use the contract's payloads.
- Actual InteractState.Kind values verified from the handlers are `Take the Package`, `Pass the Package`,
  `Call extraction`, and `Extract`. Those are labels, distinct from RequestInteract kind strings.
- A native client-only aircraft appears at Hover/Open, spins its rotors and rises during Extracted. No asset IDs,
  character children, collisions, queries, camera takeover or gameplay effects are introduced.
- Server-confirmed Extracted draws a letterbox/fade and own-team MISSION SUCCESS (neutral extraction text for rivals).
  Results shows MISSION SUCCESS only for the server's winning team, including eliminated members; others see FAILED.
- Overtime uses PhaseData.EndsAt instead of the expired main-match deadline.
- Weapon prediction clears queued inputs/reloads and remains frozen through Extracted, independently of insertion
  and downed state. A later phase message cannot revive the player or undo the extraction freeze before Results.

## Verification

- Changed Luau files: StyLua and Selene clean. Rojo build passes.
- Actual-source regression suites: weapons **228**, match **40**, Intel/Vault **28**, Package **29**; **325 assertions total**.
- Tests execute actual controller/event/projection code with deterministic service/clock/UI fixtures. Aircraft and
  weapon geometry fixtures check structure and lifecycle; symbolic transforms do not verify real engine projection.
- No Studio playtest, viewport rendering acceptance, network trial, performance measurement or multiplayer claim.
- Own locks released and only own hunks committed. Earlier spec/answer edits and Claude's concurrent work excluded.

## Known limitations and contract details

The cosmetic cinematic begins on receipt of Extracted and uses Extraction.CinematicSeconds. Extracted does not carry
a new cinematic deadline: current server code retains the prior Open deadline (or nil). The client deliberately does
not use that value as the cinematic deadline, and Results always ends the presentation. For tighter synchronisation,
Claude can publish a cinematic StartedAt/EndsAt in a future contract update; none was invented here.

Existing server gaps remain: fixed carrier ping rather than the designed movement-driven meter/reveal key; world
reset and matchmaking; NPC shove/slow parity; server smoke sight; round-end knife cleanup; absent progression/bot
systems. This source integration does not close those tickets or claim the alpha has passed acceptance.

No new gameplay choice is required from the owner. Aircraft appearance, layout, smoke/recoil and other cosmetic
numbers remain initial tuning. Source work can continue without a playtest; do not treat source checks as runtime proof.

## Next Claude prompt

> Read CLIENT_LOOP_REVIEW_2026-10-28.md and the Match/Intel/Vault/Package contracts. Continue without a Studio playtest.
> Audit the complete round loop with actual-source tests, especially round reset, extraction/Overtime races, server
> freeze cleanup and state sent to late joiners. Keep Codex's client files untouched. Document contract changes and
> server fixes under locks; stage only your own hunks and do not push. Then hand off the next alpha-critical client
> requirement; avoid progression/shop scope.
