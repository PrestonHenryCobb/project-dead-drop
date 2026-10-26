# Menu contract (ticket menu-phase0, 2026-10-26)

The shared contract for the menu suite. Codex: read this **before** `dead_drop_codex_handoff.md`. Where the two differ,
this file wins, because the handoffs were written without the repo's decision records.

## What exists now
| Piece | Where | Use |
|---|---|---|
| Agents | `src/shared/Defs/AgentDefs.luau` | `AgentDefs.order`, `AgentDefs.get(id)`: name, epithet, class, role, Talents, Instincts (text from AGENTS_DRAFT) |
| Hardware | `WeaponDefs.getForAgent(agentId)` | Three `Types.AgentHardware` in slot order: Id, Slot, UnlockMasteryLevel, Name, Category, `Def` |
| Weapon check | `WeaponDefs.isValidForAgent(agentId, weaponId)` | The agent's own weapon **and** built. Mastery is checked separately |
| Unlock levels | `GameConfig.Mastery` | `MaxLevel` 10, `HardwareUnlockLevels` {1, 3, 6} |
| Menu look | `src/client/Menu/MenuTheme.luau` | `primaryButton`, `secondaryButton`, `infoPanel`, `stateChip`; tokens in `GameConfig.Menu` |
| View interface | `Types.MenuView`, `Types.MenuNavigator` | `{ Tab, Mount(stage, navigator, context?), Unmount() }` |
| Profile data | `RemoteController.invoke("GetPlayerMetaProfile")` | Returns `Types.MetaSnapshot`; updates arrive on `ProfileStateUpdated` |
| Requests | `RemoteController.invoke(name, ...)` | `RequestEquipLoadout`, `RequestClaimStarterAgent`, `RequestClaimDossierTier`, `RequestSelectActiveDossier`, `RequestBlackMarketPurchase`, `RequestMintStrikeStocks`; each returns `(ok, reason?)` |

The server handlers (`menu-services`) and the shell that mounts views (`menu-shell`) are Claude Code's next tickets. Until
they land, `invoke` calls yield with no answer, so build views against the types and show a loading state.

## Where views go
Views are **plain modules in `src/client/Menu/Views/`** returning a `Types.MenuView`, not Controllers in
`src/client/Controllers/`. The client boot requires every module in Controllers and asserts it has `Init`/`Start`;
views are mounted by `MenuController` instead. `Unmount` must destroy everything `Mount` made (use `Util/Janitor`).
Navigate with the `navigator` passed to `Mount` (`navigator.navigateTo("Hardware", { AgentId = "Guise" })`).

## Where the handoffs were corrected
- **Weapons are the decided 18** (`docs/STEP8_QUESTIONS.md` "Answers", with Feint's silent pistol replacing the heavy
  revolver), not the handoff's table ("Concierge Breach Shotgun", "Imperial Marksman Rifle" and so on are not ours).
  Ten are built and have a `Def`; eight (garrote, pump shotgun, hammer, burst rifle, taser, flare pistol, smoke SMG,
  knives) have `Def = nil`. Show those as "in development", never as equippable, and invent no stats or
  `[STAT PLACEHOLDER]` numbers for them.
- **`Types.WeaponDef` is unchanged** (`RPM`, `Automatic`, `Falloff`, `AimZoom` and so on). There is no `FireMode`,
  `IsPlaceholderStats` or `RoundsPerMinute`; combat depends on the current shape.
- **Mode strings are `"Solos"` and `"Duos"`** (the existing `Enums.Mode`), not `"SOLOS"`/`"DUOS"`.
- **Asset rarity ids** are `FieldAgent`, `Infiltrator`, `BlackOps`, `Ghost`; the UI shows "Field Agent", "Black Ops".
- **Starter agents:** first launch picks one free agent per class (SPEC_CHANGES 15.9/20), through
  `RequestClaimStarterAgent`. No agent is hard-coded as owned.
- **Agent select** uses the full 30 seconds (`GameConfig.Lobby.AgentSelectSeconds`) and never ends early when everyone
  locks in; picks can be revised until the cutoff (SPEC_CHANGES 2026-10-25). Its state goes only to the team.
- **Loadout is `{ AgentId, HardwareId }` for now.** Gadgets (two picked from the pool, GADGETS_DRAFT) join it in Step 17
  and cosmetics in Step 21, when their definitions exist. There is no gadget, outfit-cosmetic, finish, takedown or
  calling-card catalogue yet; do not invent item names for them.
- **Content the handoff made up is not decided:** the eight named Assets and their effects, Dossier names
  ("Gilded Mirage" and others), Black Market bundles, Mint package sizes and prices, profile examples. Asset effects
  by rarity are in `BUILD_ORDER.md` (Step 7B); anything else needs the owner first. Show real data, or an honest
  empty state.
- **The Mint grant is Studio-only.** Real Stocks come from Robux purchases (Step 21); the server will refuse
  `RequestMintStrikeStocks` outside Studio.
- **Reduced motion** follows Roblox's own setting (`Util/UiAccessibility`, ticket 19-hud-motion); MenuTheme already
  does.
