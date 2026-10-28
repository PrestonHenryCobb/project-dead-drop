# Gadget contract (Step 17, tickets 17a onward)

Sub-gadgets (docs/GADGETS_DRAFT.md, SPEC_CHANGES 16.1). Server-authoritative; the client only asks.

## Server
- `GadgetService`: `RequestGadget(action, slot?)` (rate limit 6/s, burst 8). Actions: `"Equip"` with slot 0 (weapon), 1 or 2;
  `"Deploy"` (the fire button) and `"Alternate"` (the aim button) act on the held gadget. Refused unless the player is alive,
  in a match after Insertion, and not downed. A used gadget spends a charge only if its `deploy` returns true; a refusal
  reason is shown as a `Notification`. Charges are full at Insertion; a new life starts with the weapon held.
- `GadgetState` (to the owner only): `Types.GadgetStateInfo { Slots = { {Id, Charges} }, Held }` on each change.
- Loadout: `PlayerLoadout.GadgetIds` (up to `Gadgets.Slots` = 2 built gadget ids, none twice), validated in
  `MetaProgressionService.validateLoadout` (`LoadoutRequest.GadgetIds`); without it the player carries `Gadgets.DefaultPicks`.
- Each gadget is a module in `src/server/Gadgets` (`Gadget.deploy(player, rules) -> (used, reason?)`, optional `alternate`)
  listed in `GadgetService.gadgets`, and an entry in `Defs/GadgetDefs`. `rules` are the user's `GameConfig.Agents` numbers.
- Cover levels: Quiet does nothing; Discreet calls `CoverService.useDiscreetly` (breaks Cover if a Security NPC or camera sees
  it; a civilian or enemy agent seeing it does not count yet); Breaks calls `CoverService.expose`. Holding never affects Cover.

## Client
- `GadgetController`: keys 1, 2, 3 (`Controls.Weapon`, `Gadget1`, `Gadget2`; pad: d-pad right cycles) send Equip; the held
  item changes only when `GadgetState` comes back, through `HeldItemController` (fire = Deploy, aim = Alternate).
  `GadgetController.state()` gives the last `GadgetState` for the HUD.

## Built so far
- **17a: framework, Med Injector, Plate Pack.** Med Injector (1 charge): 35 HP over 4 s at 4 Hz, self only, ends on damage;
  refused at full health. Plate Pack (2 charges): one plate (`CombatService.addPlate`, up to `MaxPlates`) on the nearest
  teammate within 4 studs who has room, else on the user, after 1.5 s (Parapet's `PlateMult` 0.5 halves it: Plated's
  "twice as fast"); the user cannot shoot meanwhile (`CombatService.setFrozen`).
  Tested solo in Studio: equip 1 and 2 and back to the weapon, Med Injector healed 88.6 to 100 and spent its charge, a second
  deploy with no charge did nothing, Plate Pack added 25 armour after 1.5 s and not before. Not tested: Plate Pack on a teammate,
  Med Injector stopping on damage, the Cover rules in a Tier 1+ zone, the pad cycling.

## Not built
- The other ten gadgets (17b to 17e): Evasion (Spring Pad, Noise Maker, Disguise Kit), Infiltration (Long Lens, Keycard
  Clone, Jammer), Recon (Scanner Pulse, Bug Cam, Tripwire), Briefcase Shield.
- The gadget bar HUD and picking gadgets in agent select (client, Codex): ticket 17-hud.
- Charges refill at Supply Caches (Step 18). The loadout perks of spec 15.10 are replaced by Assets (SPEC_CHANGES), Step 18/21.

## SPEC-QUESTIONs
- A Discreet use is "seen" only by Security NPCs and cameras (the witnesses CoverService already has); enemy agents are not.
- Default picks (Med Injector, Plate Pack) until agent select can choose.
