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

## Not built (Step 18 to do)
- 18c: Supply Cache shop (6 caches): plate, ammo, heal, gadget charge, ability reset, Security Keycard, priced in intel.
- 18d: Agent Tag drop, pickup and Rescue (10 intel) at a Supply Cache.
- Elevator door hacks (`ElevatorDoor` HackCost) and the Package front door (10 intel) for human players; Tier 4 keycard printer.
- Asset safes (12) and Assets (per-match perks in four rarities): needs a design pass first.
- Intel prices for these are all open: `Economy.Shop.Prices` still holds the old Funds numbers.
