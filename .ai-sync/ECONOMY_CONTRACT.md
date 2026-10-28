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

## Not built (Step 18 to do)
- 18b: wall stations: Health Station (6), Ammo Cache (8) bought with intel; Food Spots (20) free and heal less.
- 18c: Supply Cache shop (6 caches): plate, ammo, heal, gadget charge, ability reset, Security Keycard, priced in intel.
- 18d: Agent Tag drop, pickup and Rescue (10 intel) at a Supply Cache.
- Elevator door hacks (`ElevatorDoor` HackCost) and the Package front door (10 intel) for human players; Tier 4 keycard printer.
- Asset safes (12) and Assets (per-match perks in four rarities): needs a design pass first.
- Intel prices for these are all open: `Economy.Shop.Prices` still holds the old Funds numbers.
