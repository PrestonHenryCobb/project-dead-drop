# Loading screens (2026-11-25)

Owner ask: custom, dynamic, themed loading screens for changing places and pre-loading assets, a different one for each kind of load.

| Scene | When | Where it runs |
|---|---|---|
| Boot | game starts in any place that is not the lobby or match place (Studio, single place) | `src/first/BootLoading.client.luau` |
| Lobby ("The Safehouse") | game starts in `Matchmaking.LobbyPlaceId` | same script |
| Match ("The Gala") | game starts in `Matchmaking.MatchPlaceId` | same script |
| ToMatch ("Going In") | `MatchmakingState` Found, until the teleport takes over | `LoadingController` |
| ToLobby ("Heading Home") | the match's Lobby phase after Results, until the teleport takes over | `LoadingController` |

- Words, tips and colours: `src/shared/Defs/LoadingDefs.luau`. Drawing: `src/shared/Util/LoadingScreen.luau`. Numbers: `GameConfig.Loading`.
- The boot screen pre-loads Sound, Decal, Texture, SurfaceAppearance, MeshPart, Image and Animation assets under ReplicatedStorage, Lighting, StarterGui and Workspace
  in batches, so the bar is real. It waits at most `MaxPreloadSeconds`, at least `MinShowSeconds`.
- Transition screens have no measurable progress, so they show a sliding bar and rotating status lines. They also hand themselves to
  `TeleportService:SetTeleportGui` so Roblox shows ours during the hop (a static copy). A failed teleport, `ReturnFailed`, `Failed`/`Idle`, or
  `TransitionTimeoutSeconds` closes them.
- Review a layout: set `GameConfig.Loading.PreviewScene` to a scene id; the boot screen then stays up. Leave it empty in the game.
- Tips only restate rules that exist (cover, intel stations, hold-to-hack vault, watch, ping wheel, loadout lock-in).

Not verified in Studio when written (Studio was not connected): layout, the teleport screens (need two published places and matchmaking config).

- Studio intro (Never Seen Swag): `StudioIntro` + `StudioLogo` (code-drawn logo, no background), plays over the boot screen, any key/click skips; set `GameConfig.StudioIntro.Enabled = false` to turn it off.
- Logo files: `assets/branding/nss-logo.svg` (light ink, for dark backgrounds) and `nss-logo-dark.svg` (dark ink, for light ones), both transparent; regenerate with `node tools/build-nss-logo.cjs`.
