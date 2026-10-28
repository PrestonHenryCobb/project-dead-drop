# Auto re-cover contract (ticket auto-recover)

Owner decision 2026-10-28 (asked in chat): re-covering after being Exposed starts by itself, and pressing Disguise still does it
at once. Server-authoritative; the client only toggles the option and shows the ring.

## Server (`DisguiseService`)
- Every `Cover.AutoRecoverCheckHz` (5): an Exposed player, option on, not mid-change, not blocked, for whom
  `CoverService.canRecover` holds (no combat lockout, Exposed minimum over, not seen by Security within 3 s, zone no higher than
  their look, not carrying the Package) starts a ring. `Cover.AutoRecoverSeconds` (1.5) later the disguise goes back on exactly
  as if they had pressed Disguise (random look of the last tier, `DisguiseSeconds` to put on, so Feint's 0.3 s applies).
  If `canRecover` stops holding, or the player turns it off, or presses Disguise, the ring ends.
- `Cover.AutoRecoverDefault = true`. The option is per player for the session (`autoRecover` table); the settings menu
  can persist it later.
- `RequestAutoRecover(boolean)` (rate limit 2/s) sets the option and shows "Auto re-cover on/off".
- `AutoRecoverState` (to the owner only): `Types.AutoRecoverInfo { Enabled, Active, Seconds }` when the option changes, a ring
  starts or ends, and at spawn.

## Client
- `AutoRecoverController`: `Controls.ToggleAutoRecover` (H) toggles it; `state()` returns the last message and `os.clock()` when
  it arrived, for a ring in the HUD (progress = (os.clock() - arrivedAt) / Seconds while Active).

## Tested in Studio (solo)
On: Exposed at t, ring message at t, ring ended at t+1.7, disguise back (new Guest look) at t+2.5. Off (H): stayed in True Form
for 4.5 s. Not tested: the ring cancelling on lockout or being seen, two players.

## Not built
- The ring in the HUD and a settings-menu toggle (client, Codex): ticket auto-recover-hud.
