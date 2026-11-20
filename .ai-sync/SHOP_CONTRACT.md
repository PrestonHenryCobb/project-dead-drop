# Shop skeleton (ticket shop-skeleton; Claude Code, 2026-11-20)

**Built, not run in Studio.** Owner answers 2026-11-20: a locked agent costs 2,500 Credits; build agents, a rotating Black Market for Stocks and a Mint
screen that is not wired to Robux. Dossiers stay `NoCatalogue`. Numbers: `GameConfig.Shop`. Items: `Defs/ShopDefs` (names from META_DRAFT).

## Server
- `RequestBuyAgent(agentId) -> (ok, reason?)` (`MetaProgressionService`): refused with `UnknownAgent`, `AlreadyOwned`, `UseFreePick` (that class's free
  first-launch pick is still open), `NotEnoughCredits`. Success takes 2,500 Credits, owns the agent at mastery 1 and pushes `ProfileStateUpdated`.
- `GetBlackMarketOffers() -> Types.BlackMarketState`: `Daily` (4 items, the same for everyone on a UTC day), `Featured` (a weekly bundle, 80 percent of its
  Stocks prices), `ResetsAt` and `FeaturedResetsAt` on the server clock (`workspace:GetServerTimeNow()`).
- `RequestBlackMarketPurchase(offerId) -> (ok, reason?)`: a daily item or the featured bundle id. Reasons: `UnknownOffer`, `NotOnSale`, `AlreadyOwned`,
  `AgentNotOwned` (Attire is only sold to someone who owns the agent), `NotEnoughCredits`, `NotEnoughStocks`. Success marks `Profile.OwnedCosmetics[id]`.
- `RequestMintStrikeStocks(packageId) -> (ok, reason?)`: Studio-only grant of the package's Stocks; outside Studio `NotAvailable` (the packages'
  `ProductId` is 0 until the owner creates Developer Products). No `ProcessReceipt` is built before then, on purpose.
- Unknown cosmetic ids in a saved profile are dropped on load.

## For Codex (client)
Build the Black Market tab from `GetBlackMarketOffers` (daily cards with a countdown to `ResetsAt`, one featured bundle card), the Mint from
`GameConfig.Shop.Mint.Packages` (show "coming soon" on `NotAvailable`), and a Buy button on a locked agent in the Agents tab (`RequestBuyAgent`; show
`UseFreePick` as "Claim your free pick first"). Prices and currency come with each offer. Show `OwnedCosmetics` as Owned. Nothing is equippable yet
(no art): say "no art yet" honestly. Use `InputHints` for any hint.

## SPEC-QUESTIONs
- Every price, the Stocks package sizes and Robux prices, which agent wears which look, tiers, the 4-a-day and weekly cadence and the 80 percent bundle
  price are first guesses. An agent's Attire needs the agent owned (invented rule, easy to drop).
- Credits cannot buy a cosmetic from the daily list unless it is an `Everyday` item.
