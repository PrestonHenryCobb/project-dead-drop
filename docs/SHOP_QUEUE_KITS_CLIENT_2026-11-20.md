# Shop, queue and kit client integration — 2026-11-20

Read SHOP_CONTRACT.md, MATCHMAKING_CONTRACT.md, KITS_CONTRACT.md and AUDIO_CONTRACT.md before implementation.
Client only; no shared/server gameplay edits, audio IDs, Robux products, purchase prompts or tutorial work.

## Shop

- BlackMarketView fetches GetBlackMarketOffers, draws the actual daily cards and featured bundle, and counts down
  ResetsAt/FeaturedResetsAt on the server clock. Refresh/retry and automatic rotation refresh have in-flight guards
  and backoff. Requests cancel locally on unmount; stale callbacks cannot update a replacement view.
- Prices/currencies come from offers. OwnedCosmetics and actual profile balances/agent ownership drive the cards;
  bundles check every included agent and item. Purchases use RequestBlackMarketPurchase and await profile pushes,
  with no optimistic currency or ownership changes. Content says no art yet and not equippable.
- MintModalView reads GameConfig.Shop.Mint.Packages, shows Stocks/planned Robux prices and the server availability
  path. NotAvailable reads Coming soon. Studio previews use the existing server-only grant path; no Marketplace
  prompt, Developer Product ID or receipt code was added.
- Locked agents have the configured Credit Buy action. UseFreePick reads exactly Claim your free pick first.
  RequestFeedback also covers insufficient balances, ownership, expired offers and unavailable kit choices.

## Matchmaking

- MatchmakingController caches owner-only MatchmakingState across menu navigation. Local pending requests are
  shown as submitting/cancelling; Searching, Found, Failed and Idle remain server-driven.
- Play uses RequestFindMatch only when Enabled and the place ID equals LobbyPlaceId, with configured mode choices
  and a persistent fixed-area status/Cancel action. Cancel remains usable even if the local Asset draft becomes
  incomplete during a search. Closing/reopening Play does not silently cancel or forget a queued search.
- Before queueing, the existing RequestEquipLoadout saves the complete Asset draft and selected kit/gadgets so a
  fresh client after teleport retains them. A refused save does not start a search. Other places keep direct Deploy.

## Talents and Instincts

- Shared KitPicker renders all three of each, with configured mastery locks and the selected description.
  PreDeployView and AgentsView preserve separate draft selections per current agent, reset invalid/locked choices
  to the first item and send TalentId/InstinctId with the loadout. No client ability or passive effect is applied.
- HardwareInspectorView preserves the equipped kit for the same agent and selects first defaults for another.
  Agent/Hardware equip requests preserve the saved gadget/Asset fields instead of silently dropping them.
- The optional buff timer was omitted: the existing contract has no owner-only active-effect deadline packet.
  Ability cooldown feedback continues to use the server's selected Talent name and timing.

## Validation and remaining acceptance

Manual source/diff inspection and StyLua formatting only. No tests, lint, builds, Studio or desktop control.
Native review remains: rotation rollover and failed refresh; daily/bundle ownership, balances and missing-agent
refusals; free-pick agent refusal; Mint NotAvailable and Studio-only preview; search/cancel/failure/found states
across menu navigation and real published teleports; kit selections at mastery 1/3/6, agent changes, relocking
before cutoff, and saved kit/gadget/Asset retention. No server numbers were changed. Existing contract pricing,
kit balance and matchmaking infrastructure caveats remain. Ready for review; no push.
