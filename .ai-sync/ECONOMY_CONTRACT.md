# Economy contract (Step 18, tickets 18a onward)

Intel is the only currency (SPEC_CHANGES: Funds are removed). A team's balance is `IntelService.balance(teamId)` and is spent
with `IntelService.spend(teamId, amount)`. Server-authoritative; the client only asks.

## Built so far
- **18a: tier doors hacked open with intel.** `DoorService` gives every clearance door a `SecurityId` ("D1", ...) next to its map
  `Tier` and `HackCost` (Staff 3, Security 6, Executive 8, more for the special doors; `GameConfig.Doors.HackCost` documents them).
  `SecurityService` registers the hold kind `DoorHack` (label "Hack door", `Doors.HackSeconds` 3, reach `Doors.HackStuds` 8): it
  starts only on a shut door within reach when the team can afford the price; while it runs the door must stay shut, in reach and
  affordable; when it ends the price is taken (`IntelService.spend`) and the door stays open `Doors.HackOpenSeconds` (4). Too
  little intel shows "Needs N intel". It is suspicious if witnessed (`noteHacking`), except from Lattice's drone.
  Lattice's Wired: `Agents.Lattice.TierDoorDiscount` takes 1 off (never below 1), and her hack takes 25% less time (`DoorHack` is
  in `HackKinds`). The Long Lens targets tier doors (kind `DoorHack`). The Keycard Clone opens a shut keycard or tier door free
  (`DoorService.shutDoor`); `DoorService.keycardDoor` is now keycard doors only, so Lockpick cannot open a tier door.
  `DoorService.openKeycardDoor` was renamed `openDoor`. Client: `SecurityInteractController` outlines a shut tier door in reach and
  Interact starts `DoorHack`.
  Tested solo in Studio: with no intel "Needs 3 intel"; with 6 intel the hold ran 3 s and the balance fell to 3; the Keycard Clone
  opened a tier door and cost nothing. Not tested: Wired's discount, the Long Lens or the drone on a door, another team's door.

- **18b: wall stations.** `StationService` gives each `HealthStation` ("H1"..), `AmmoCache` ("A1"..) and `FoodSpot` ("F1"..) a
  `StationId` attribute and a hold kind of the same name (label Heal / Refill ammo / Eat). Prices and times in
  `Economy.Stations` (owner prices 2026-10-28): Health Station 3 intel, 2 s, heals to full; Ammo Cache 2 intel, 1.5 s, full magazine
  and reserve; Food Spot free, 1.5 s, +15 HP, then empty for `PickupRespawnSeconds` (60; `Taken` attribute), refilled at match
  start. Needs the user near and in sight of the station (the line of sight stops 1.2 studs short of the nearest face, since the
  stations sit in their walls), refused with a message when there is no use ("Already at full health", "Ammo is full") or the
  team lacks the intel ("Needs N intel"); the price is taken when the hold ends. Discreet. Reach does not come from a drone or
  the Long Lens. `CombatService.canRefillAmmo/refillAmmo` are new. Client: `SecurityInteractController` outlines a station in reach.
  Tested solo in Studio: Health Station took the team from 8 to 5 intel and healed 5 to 100 HP, then refused at full health; a Food
  Spot healed 1 to 16 HP once and refused at full health. Not tested: the Ammo Cache, food emptying and refilling.

- **18c: Supply Cache shop.** `SupplyService`: each `SupplyCache` gets a `CacheId` ("S1"..). Hold kind `SupplyCache` (0.3 s, quiet)
  opens the shop for the user (one agent at a time per cache): `ShopState` (to them only, `Types.ShopStateInfo`: Open, CacheId,
  team Intel, Items {Id, Name, Price, Available, Reason}, Buying, BuySeconds). `RequestShopBuy(itemId)` (rate limit 2/s) starts
  a purchase: refused (the shop is just resent) unless the item has a use now and the team can pay; it breaks Cover at once,
  takes `Shop.PurchaseSeconds` (2) with the shopper near the cache, then takes the intel and applies the item. `RequestShopClose`
  or walking more than 8 studs off, being downed or the match ending closes it. Items and intel prices (`Economy.Shop.Items`,
  owner prices 2026-10-28): Armor Plate 3, Full ammo refill 2, Heal to full 3, Gadget charge 3 (`GadgetService.addCharge`),
  Ability cooldown reset 4 (`AbilityService.resetCooldown`, only while cooling down), Security Keycard 3. A cache in a zone of
  tier 1 or more is 20% cheaper (rounded, at least 1). A keycard has 3 uses: with one, the Lockpick hold on a keycard door takes
  1 s, is labelled "Use keycard", and does not break Cover (`SupplyService.keycardUses/useKeycard`). The obsolete Funds numbers
  were removed from `Economy`. Client: `SecurityInteractController` outlines a cache in reach and Interact opens it.
  Tested solo in Studio: a tier 2 cache opened and listed discounted prices (2, 2, 2, 2, 3, 2) with the reasons items had no use;
  Heal to full, Armor Plate and Security Keycard each bought (intel 12 to 6), an ability reset was refused while ready, close
  worked, and the keycard made a keycard door hold "Use keycard" for 1 s. Not tested: Ammo refill, Gadget charge, Ability reset
  when cooling down, two agents at one cache, walking off.

## Not built (Step 18 to do)
- The shop screen (a menu over `ShopState` with buy buttons calling `RequestShopBuy`): ticket 18c-hud for Codex. Until it
  exists nobody can pick an item with a button.
- 18d: Agent Tag drop, pickup and Rescue (10 intel) at a Supply Cache.
- Elevator door hacks (`ElevatorDoor` HackCost) and the Package front door (10 intel) for human players; Tier 4 keycard printer.
- Asset safes (12) and Assets (per-match perks in four rarities): needs a design pass first.
- Intel prices for these are all open: `Economy.Shop.Prices` still holds the old Funds numbers.
