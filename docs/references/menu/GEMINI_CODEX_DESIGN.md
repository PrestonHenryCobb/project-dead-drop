# CODEX HANDOFF — Dead Drop (`CoverStory`) Collection, Armory, & Store Views

**Role:** Roblox Luau UI Views, 3D Procedural Weapon Turntable, & Meta-Collection Engineer (`AGENTS.md`)
**Repository Sync:** Rojo (`default.project.json`), Selene (`selene.toml`), StyLua (`stylua.toml`)
**Coordination Protocol:** Read `docs/PROJECT_STATUS.md`, `CLAUDE.md`, `.ai-sync/AI_SYNC_STATE.md`, and `.ai-sync/TASK_QUEUE.md` first. Never edit a file locked by Claude Code. Add your lock row in `.ai-sync/AI_SYNC_STATE.md` before editing any file, stage only your own files/hunks (`git add -p` for shared files), and run `stylua` only on files you changed.

---

## 1. Executive Summary & Scope Split (Codex vs. Claude Code)

We are building the **Dead Drop** (`CoverStory`) **Sculpted Art Deco Espionage** UI Suite in the authentic **blocky Roblox R15 character art style** (`OutfitApplier.luau` / `OutfitDefs.luau` / procedural `ViewModel.luau` weapons).

To prevent merge and lock conflicts in `.ai-sync/AI_SYNC_STATE.md`:
- **Claude Code (Companion Handoff)** owns Phase 0 shared contracts (`Enums.luau`, `Types.luau`, `GameConfig.luau`, `Remotes.luau`, `WeaponDefs.luau`, `AgentDefs.luau`), the server services (`LobbyService.luau`, `MetaProgressionService.luau`), the shared theme helper (`src/client/Controllers/MenuTheme.luau`), the 3D stage camera (`MenuCameraController.luau`), the top-level shell (`MenuController.luau`), and the Play/Pre-Deploy views (`PlayLobbyView.luau`, `PreDeployView.luau`).
- **Codex (This Handoff)** owns the **7 connected Collection, Armory, Progression, Store, and Profile View Controllers** under `src/client/Controllers/` plus the shared **Universal Inspection & Confirmation Modal**:
  1. `src/client/Controllers/AgentsView.luau` (Screen 2: Agents Overview, Kit, Mastery & Cosmetic Modals)
  2. `src/client/Controllers/HardwareInspectorView.luau` (Screen 2B: Agent-Specific 18-Weapon Armory Bay & 3D Procedural `ViewportFrame` Turntable)
  3. `src/client/Controllers/AssetsCodexView.luau` (Screen 3: In-Match Tactical Perk Codex & Rarity Filters)
  4. `src/client/Controllers/DossiersView.luau` (Screen 4: Non-Expiring Operations Archive & 5-Card Illustrated Reward Track)
  5. `src/client/Controllers/BlackMarketView.luau` (Screen 5: Featured Bundle Banner, 6 Individual Offers, & 12h/24h Rotation Toggle)
  6. `src/client/Controllers/ProfileView.luau` (Screen 6: Operative Dossier, Extraction Telemetry, R15 Mastery Showcase, & Calling Cards)
  7. `src/client/Controllers/MintModalView.luau` (Screen 7 & Universal Modal: The Mint Intaglio Banknote Press & Bundle/Cosmetic Inspection Modal)

---

## 2. Non-Negotiable Rules (`AGENTS.md` & `CLAUDE.md`)

1. **Cover Story Original IP & Naming**:
   - Operatives: `Guise`, `Parapet`, `Lattice`, `Reticle`, `Suture`, `Feint`.
   - Classes: `Deceiver` (`Guise`, `Feint`), `Enforcer` (`Parapet`, `Reticle`), `Specialist` (`Lattice`, `Suture`).
   - Kit Architecture: **Hardware** (3 exclusive weapons per Agent: `W1`, `W2`, `W3`), **Talents** (active abilities), **Instincts** (passive traits).
   - Match Perks: **Assets** (`Field Agent`, `Infiltrator`, `Black Ops`, `Ghost` rarities) — activated in-match using **Intel**, never sold for currency.
   - Progression & Store: **Dossiers** (permanent, non-expiring reward tracks progressed via direct match XP — no event tokens), **Black Market** (Featured bundle + 6 individual offers), and **The Mint** (where **Stocks** are struck; all prices and balances must be explicitly labeled as `[MOCK EXAMPLE]`).
2. **Strict Luau & Clean Linting**: Every file must start with `--!strict`, return a Controller table with `Init()` and `Start()`, clean up connections/clones with `src/shared/Util/Janitor.luau`, and pass `selene src` and `stylua` on your modified files.
3. **Visual Hierarchy & Accessibility**:
   - Use `MenuTheme.luau` tokens (`BgObsidian #0E1014`, `BgCharcoal #161920`, `SurfaceIvory #F5F0E6`, `AccentEmerald #149A74`, `AccentBrass #D4A856`, `AccentBurgundy #7A1C30`, `AccentCyanFocus #38E8FC`).
   - Every interactive card or button must have unmistakable `Default`, `Hover`, `Selected`, `Controller Focus` (`2px` `#38E8FC` cyan ring), `Pressed`, and `Disabled/Locked` states, combining shape + badge text + color (`EQUIPPED`, `AVAILABLE`, `LOCKED`, `OWNED`).

---

## 3. Screen-by-Screen Implementation Specifications for Codex

### 3.1 Screen 2 — Agents Overview & Kit (`src/client/Controllers/AgentsView.luau`)
- **3-Column Layout (`330px` Left · `1fr` Center Stage · `410px` Right)**:
  - **Left Column**:
    1. **Operative Identity Panel**: Class kicker (`◆ DECEIVER CLASS`), status chip (`EQUIPPED`, `AVAILABLE`, or `LOCKED`), Operative title (`GUISE`), role subtitle (`CHAMELEON INFILTRATOR`), and lore bio from `AgentDefs`.
    2. **Agent Customization & Gadgets Grid (`2×2` secondary buttons)**:
       - `👔 R15 Attire (3)` -> opens `MintModalView:OpenCosmeticModal` showing 3 disguise-safe Gala outfits (`OutfitDefs.luau`).
       - `🔫 Agent Hardware (3)` -> navigates to `MenuController:NavigateTo("Hardware", { AgentId = selectedAgentId })`.
       - `⚡ Takedowns (Cosmetic)` -> opens cosmetic takedown preview modal.
       - `⚙ Gadgets & Mastery` -> opens gadget loadout & mastery milestone modal.
       - Include footnote: `*All players and NPCs share the blocky Roblox R15 rig (OutfitApplier.luau); cosmetics never expose cover.`
    3. **Agent Mastery Track Panel**: Shows `LEVEL 07 / 10` progress bar and explains that Mastery Level 3 unlocks `W2` and Mastery Level 6 unlocks `W3`.
  - **Center Stage**:
    - Requests `MenuCameraController:FocusAgent(selectedAgentId, selectedWeaponId)` to display the rigged blocky R15 Operative holding their active procedural weapon.
    - Bottom **6-Operative Roster Strip** (`Guise`, `Parapet`, `Lattice`, `Reticle`, `Suture`, `Feint`) with portrait cards, class subtitles, and lock indicators.
  - **Right Column (Agent Kit Breakdown)**:
    1. **Exclusive Hardware Card (`W1 / W2 / W3` Slot Pill Bar)**:
       - Displays the 3 exclusive weapons for the selected Operative via `WeaponDefs.getForAgent(selectedAgentId)`.
       - Clicking `W1 · Default`, `W2 · Lvl 3`, or `W3 · Lvl 6` updates the weapon preview and stat summary (`8 DMG · 800 RPM · 30/60 Mag · 1.9s Reload · Quiet (25-stud radius)` for `GuiseSMG`, or `[STAT PLACEHOLDER]` where flagged).
       - Includes `Open Armory Bay ▸` button linking to `HardwareInspectorView`.
    2. **Talents (Active Ability) Card**: Displays `TalentName`, `[COOLDOWN PLACEHOLDER]` chip, and `TalentDesc`.
    3. **Instincts (Passive Trait) Card**: Displays `InstinctName`, `PASSIVE` chip, and `InstinctDesc`.
    4. **Primary CTA (`52px` height)**: `✓ SET AS ACTIVE OPERATIVE & HARDWARE` (calls `Remotes.RequestEquipLoadout:InvokeServer(...)`, or shows `🔒 OPERATIVE / SLOT LOCKED` disabled state if unowned).

### 3.2 Screen 2B — Agent-Specific Hardware Collection & 3D Turntable (`src/client/Controllers/HardwareInspectorView.luau`)
- **Layout (`1fr` Left Armory Grid · `400px` Right Inspector Panel)**:
  - **Top Filter Bar**:
    - Operative filter pills: `Guise (3 Guns)`, `Parapet (3 Guns)`, `Lattice (3 Guns)`, `Reticle (3 Guns)`, `Suture (3 Guns)`, `Feint (3 Guns)`, and `All 18 Agent Weapons`, plus `◂ Back to Agent Overview` button.
  - **Weapon Silhouette Card Grid (`3 columns`)**:
    - Renders high-contrast weapon cards for the filtered Operative(s) showing slot kicker (`GUISE · W1`), unlock chip (`EQUIPPED`, `AVAILABLE`, or `LOCKED · LVL 6`), weapon silhouette/preview, weapon name, and fire-mode/category subtitle.
    - **No prices or buy buttons** appear in the Hardware Collection (weapons are earned strictly through Agent Mastery).
  - **Right Inspector Panel**:
    - **3D Procedural Weapon `ViewportFrame` Turntable**:
      - Clone the procedural `Part`-built weapon model from `ViewModel` / `WeaponDefs` into a `ViewportFrame` with a local `Camera` and 3-point `PointLight`/`SpotLight` setup.
      - Support `⟲ Rotate Left`, `⊕ Toggle Zoom`, `⟳ Rotate Right` buttons and mouse/right-stick drag rotation (disabled auto-spin when `ReducedMotion == true`).
    - **Stat Readout & Bars**:
      - Displays exact `WeaponDefs.luau` stats for `GuiseSMG` (`8 DMG (1.5x Headshot · 30–70 Studs)`, `SUPPRESSED (25-Stud Hear Radius)`, `800 RPM Auto · 1.9s Reload · 0.88x Zoom`) and explicit `[STAT PLACEHOLDER]` tags for unfinalized weapons.
    - **Available Weapon Finishes (Cosmetic Only)**:
      - 3 finish pills (`Blued & Brass (Equipped)`, `Gilded Ivory (Available)`, `Emerald Engraving (Locked)`).
    - **Primary CTA**: `✓ EQUIP TO [AGENT] LOADOUT` (invokes `RequestEquipLoadout`).

### 3.3 Screen 3 — Assets: In-Match Tactical Perk Codex (`src/client/Controllers/AssetsCodexView.luau`)
- **Layout (`1fr` Left 4-Column Grid · `390px` Right Inspector)**:
  - **Rarity Filter Pills**: `All Rarities (8)`, `Field Agent`, `Infiltrator`, `Black Ops`, `Ghost`.
  - **8 Scannable Asset Perk Cards**:
    1. `Phantom Credential` (`Ghost`) — Suppresses clearance laser alerts for `[DURATION PLACEHOLDER]` & highlights nearest Intel terminal.
    2. `Velvet Silencer Baffle` (`Black Ops`) — Reduces weapon acoustic radius by `[STAT PLACEHOLDER]` for 60s after vault breach.
    3. `Syndicate Tailor Kit` (`Infiltrator`) — Instant R15 disguise swap upon interacting with any staff wardrobe rack.
    4. `Ballroom Courier Stride` (`Field Agent`) — Carrying *The Package* no longer applies movement speed penalty (`[STAT PLACEHOLDER]`).
    5. `Double-Agent Ledger` (`Infiltrator`) — Decoding an Intel station awards `+[STAT PLACEHOLDER]%` bonus Intel.
    6. `Chandelier Overwatch` (`Black Ops`) — Pinging a rival operative reveals their current R15 disguise class to your Duos partner.
    7. `Cold-Blooded Alibi` (`Ghost`) — Immunity to rival recon pulse scans while blending in crowd nodes.
    8. `Reinforced Cummerbund` (`Field Agent`) — Grants `+[STAT PLACEHOLDER]` armor plating upon entering Executive or Vault tiers.
  - **Right Inspector Panel**:
    - Displays selected Asset icon, rarity kicker, full tactical description, `[INTEL COST PLACEHOLDER] · Gathered during match` callout box, and the **Competitive Integrity Rule** panel (*"Assets cannot be bought with Stocks or Credits. Every operative begins the Gala match on equal footing and unlocks Assets strictly by gathering Intel on-site."*).

### 3.4 Screen 4 — Dossiers: Non-Expiring Reward Tracks (`src/client/Controllers/DossiersView.luau`)
- **Layout (`310px` Left Dossier Selector · `1fr` Right 5-Card Illustrated Track)**:
  - **Left Column**:
    - Permanent Dossier switcher cards:
      1. `OP: GILDED MIRAGE` (`ACTIVE · Tier 4 / 10 · Permanent Track`)
      2. `OP: VELVET CIPHER` (`AVAILABLE · Tier 2 / 10 · Permanent Track`)
      3. `OP: IRON PARAPET` (`LOCKED · Tier 0 / 10 · Unlock Premium Track`)
    - Selected Reward Inspection box with `✓ CLAIM AVAILABLE REWARD` button (invokes `RequestClaimDossierTier`).
  - **Right Column**:
    - Header bar showing `NON-EXPIRING PROGRESSION · DIRECT XP (NO EVENT TOKENS)`, `DIRECT XP: [XP PLACEHOLDER: 3,400 / 5,000]`, and `Unlock Premium Dossier ([STOCKS PLACEHOLDER])` button.
    - **5-Card Horizontal Illustrated Reward Track**:
      - Clearly distinguishes **FREE TIER** cards (ivory top header badge) from **PREMIUM TIER** cards (gilded brass top header badge) and **CLAIMED** (`✓ CLAIMED`), **AVAILABLE** (`◆ AVAILABLE`), and **LOCKED** (`🔒 LOCKED`) states.

### 3.5 Screen 5 — Black Market (`src/client/Controllers/BlackMarketView.luau`)
- **Top Half — Featured Bundle Banner**:
  - Displays `FEATURED COLLECTION`, distinct countdown timer (`FEATURED SCHEDULE: 06D : 14H : 22M`), `THE GILDED MASQUERADE BUNDLE` title, itemized contents list (`Vanguard Engraved Carbine Finish (Lattice W1)`, `Ivory & Brass GuiseSMG Finish (Guise W1)`, `Gilded Domino R15 Attire`, `Velvet Bow Calling Card`), `INSPECT BUNDLE · [EXAMPLE: 1,800 STOCKS]` primary CTA (opens `MintModalView:OpenBundleModal`), and `Get Stocks at The Mint ▸` secondary button.
- **Bottom Half — 6 Individual Cosmetic Offer Cards**:
  - Header bar with distinct individual timer (`INDIVIDUAL ROTATION (24H MODE): 14H : 28M : 19S`) and interactive **12-Hour Cycle / 24-Hour Cycle** config toggle pills.
  - 6 individual offer cards showing item preview, category kicker, cosmetic name, currency pill (`[MOCK: 600 STOCKS]` or `[1,200 CREDITS]`), and ownership state (`AVAILABLE` vs. `OWNED`). Clicking any card opens the inspection & purchase confirmation modal.

### 3.6 Screen 6 — Profile (`src/client/Controllers/ProfileView.luau`)
- **Layout (`270px` Left Identity & Sub-Tabs · `1fr` Right Telemetry & Showcase)**:
  - **Left Column**: R15 Operative portrait avatar, `AGENT_VALENTINE`, `Title: Master of Disguise · Level 24`, equipped Calling Card badge (`The Velvet Phantom`), and 3 sub-tab buttons (`◆ Career & Extraction Overview`, `▸ Recent Gala Match History`, `▸ Calling Cards & Milestones`).
  - **Right Column**:
    - **4 Telemetry Stat Cards** (grounded in Dead Drop mechanics — **no invented ranked ladder**): `PACKAGE EXTRACTIONS (42 · 64% Rate)`, `INTEL GATHERED (18,450 · Avg 280/Match)`, `UNCOMPROMISED DISGUISE (78% Undetected)`, `RIVAL ELIMINATIONS (119 · 34 Silent Takedowns)`.
    - **Roblox R15 Operative Mastery Showcase**: Top 3 Operatives (`GUISE · Lvl 7`, `LATTICE · Lvl 5`, `PARAPET · Lvl 4`).
    - **Recent Gala Operations Log**: `EXTRACTED THE PACKAGE · Duos (GuiseSMG)`, `SAFE EVACUATION · Solos (Vanguard Carbine)`, `COVER COMPROMISED · Duos (Concierge Shotgun)`.

### 3.7 Screen 7 & Modal — The Mint (`src/client/Controllers/MintModalView.luau`)
- Accessible from the persistent header's **Stocks Balance Pill (`+`)** or Black Market / Dossier upgrade buttons.
- **Left Column**: Intaglio Treasury briefing + explicit mock notice (`⚠ NOTICE: ALL BALANCES & PRICES SHOWN ARE LABELED MOCK EXAMPLES FOR UI LAYOUT ONLY`) + selected certificate summary + `STRIKE CERTIFICATES (CONFIRM)` CTA.
- **Right Column (4 Banknote-Press Stock Packages)**:
  1. `FIELD STIPEND · 500 STOCKS` (`[MOCK EXAMPLE: $4.99]`)
  2. `OPERATIVE PORTFOLIO · 1,100 STOCKS` (`10% Bonus · [MOCK EXAMPLE: $9.99]`)
  3. `SYNDICATE FOLIO · 2,400 STOCKS` (`MOST POPULAR · 20% Bonus · [MOCK EXAMPLE: $19.99]`)
  4. `GRAND GALA RESERVE · 6,500 STOCKS` (`30% Bonus · [MOCK EXAMPLE: $49.99]`)
- **Universal Inspection & Confirmation Modal**:
  - Reusable modal overlay (`#1C2029` card with `2px` `#F3C978` brass border) for confirming Mint certificate strikes, Black Market bundle/item purchases, and R15 Attire/Takedown previews.

---

## 4. Studio Verification & Handoff Checklist (`AGENTS.md` / `CLAUDE.md` Format)

Before handing back your ticket:
1. Run `stylua` only on the files you created/modified and run `selene src` to confirm zero warnings.
2. Remove your lock rows in `.ai-sync/AI_SYNC_STATE.md` and move your ticket in `.ai-sync/TASK_QUEUE.md` to `READY_FOR_REVIEW`.
3. Provide the 5-part completion report:
   - **What I built** (each view controller file created, one line each)
   - **How to test it in Studio** (testing the 6 Operatives & `W1`/`W2`/`W3` weapon slots in `AgentsView`, rotating procedural weapon models in `HardwareInspectorView`, filtering `Assets`, claiming a `Dossier` reward, toggling `12h/24h` rotation in `BlackMarketView`, inspecting `ProfileView`, and striking mock `Stocks` in `MintModalView`)
   - **Known gaps or risks**
   - **SPEC-QUESTIONs** raised
   - **Ready for:** Full end-to-end integration test with Claude Code's `MenuController` and `LobbyService`.
