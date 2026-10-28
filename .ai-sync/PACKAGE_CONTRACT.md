# Package, extraction and overtime contract (Step 13, ticket 13a; Claude Code, 2026-10-27)

Server `PackageService`, `ExtractionService`, small hooks in `MatchService`, `CoverService`, `DisguiseService`,
`ZiplineService`; client `PackageController`. **Untested in Studio.** With Steps 10 to 12 this is a full match loop.

## Package (spec 11)
- Appears on the Sanctum pedestal when the Package Heist begins. Part `Package` (tag `PackageItem`) in workspace.
- Hold E within 4 studs for 1 s (`InteractService` kind `"Package"`). First hold to finish wins.
- Carrier: Exposed while holding and cannot re-cover (`CoverService.setPackageCarrier`; recover blocker text `"Package"`);
  90 % speed and no scan/disguise (`DisguiseService.setCarrier`); cannot ride a zipline. Vents are not blocked (SPEC-QUESTION).
- Pass: hold E 0.5 s with a teammate within 6 studs (kind `"PackagePass"`, the server picks the nearest living teammate).
  Drop: X (`RequestDropPackage`, rate limited). Downed, eliminated or leaving drops it where they stood.
- Dropped: falls with physics; after 30 s untouched, or below `Package.MinY`, it returns to the pedestal with a Notification.
- Not built: the ping meter that fills faster when sprinting or jumping, and the carrier's rival-reveal key (SPEC_CHANGES 11);
  the fixed `Package.PingInterval` pulse is built instead.

## Remote `PackageState(Types.PackageStateInfo)`, sent per player
`State` Hidden | Pedestal | Carried | Dropped. `Position`: where a resting Package lies (everyone), or the carrier during a
pulse (rivals only, `Package.PingPulseSeconds` every `PingInterval`). `YouCarry`, `TeamCarries`, `PulseUntil`, `ReturnsAt`.

## Extraction (spec 12)
- A `ExtractionTerminal` part (attribute `SiteId`) at each of the 3 sites. Carrier or a teammate within 10 studs of them holds
  E 2 s (kind `"ExtractionCall"`): countdown 45 s (20 s in Overtime), beacon `ExtractionBeacon` map-wide, Notification
  "EXTRACTION CALLED". One at a time; another team replaces it only if the Package changed hands to it.
- Then Hover 2 s, then the zone (`ExtractionZone`, 16 studs, green) opens. The carrier in the zone holds E 3 s (kind
  `"ExtractionChannel"`). Damage does not break it; going down, leaving, dropping, or an enemy in the zone does (restarts).
- A failed channel leaves it open 20 s, then it expires. Success: `State = "Extracted"`, everyone frozen 5 s, then
  `MatchService.finish(team)`: Results with that team Won (its eliminated members count as winners).
- Remote `ExtractionState(Types.ExtractionStateInfo)`: `State` Idle | Countdown | Hover | Open | Extracted, `SiteId`,
  `Position`, `EndsAt`, `ByYourTeam`.

## Overtime (spec 19)
When the 14:00 timer ends while someone carries the Package (`MatchService.setPackageCheck`), the phase becomes Overtime for
at most `Overtime.CapSeconds` (90); `PhaseData.EndsAt` is its end. A drop in Overtime ends the match with no winner after
`DroppedGraceSeconds` (10). Otherwise the main timer ending is Mission Failed. Rescues are disabled (not built yet).

## For Codex (tickets 13b and 13c)
- 13b HUD: package marker and carrier ping pulses (`PackageState`), the carrier's "you have the Package" banner and drop hint,
  extraction countdown/zone/channel, overtime timer. Pickup, pass and channel holds show through the existing `InteractState`.
- 13c Presentation: helicopter hover at `Hover`, the 5 s extraction cinematic at `Extracted`, "MISSION SUCCESS/FAILED".

## Studio test (solo)
1. Set `Vault.BaseRate` high in Studio's copy of `GameConfig`, or hack the three terminals (contract in VAULT_CONTRACT.md).
2. At `[Match] PackageHeist` a glowing `Package` sits in the Sanctum: hold E next to it. You are Exposed and slower.
3. Walk to an extraction site terminal (gold block on a pad), hold E 2 s: beacon appears, countdown 45 s, hover 2 s, green
   disc. Stand on it and hold E 3 s: the screen freezes 5 s, then Results with your team winning.
4. Drop test: press X; wait 30 s: the Package returns. To test overtime set `Match.MainTimerSeconds` small while carrying.
