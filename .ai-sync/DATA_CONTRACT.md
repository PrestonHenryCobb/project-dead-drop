# Saved data (ticket 21-data; Claude Code, 2026-11-19)

**Built, not run in Studio** (owner asked for no tests in this run). Lint clean.

## What is saved
One DataStore key per player (`P<UserId>` in `GameConfig.Data.StoreName`), value
`{ Version, Data = { Profile = MetaProfile, Loadout = PlayerLoadout? }, Lock = { JobId, At }?, SavedAt }`.
`Profile` is the whole `Types.MetaProfile` (Level, Credits, Stocks, OwnedAgents, StarterPicksLeft, Mastery, OwnedCosmetics,
Dossiers, ActiveDossierId, Career). Nothing else is saved yet: settings, XP and match results have no code that produces them.

## How
- `Data/ProfileStore.load(userId)` and `.save(userId, data, release)`: `UpdateAsync` with a session lock inside the value. A join
  waits `LockWaitSeconds` (25 s) for another live server to let go, then is kicked with a message ("Locked"). A lock older than
  `LockStaleSeconds` (600 s) is a crashed server's and is taken. A save from a server that lost the lock is refused.
  Every call retries `Retries` times with a doubling backoff.
- `MetaProgressionService.loadProfile` runs on join; the client already retries `GetPlayerMetaProfile` and listens for
  `ProfileStateUpdated`, so the menu fills in when the load finishes. `reconcile` drops unknown agents, classes and
  malformed entries and bounds every number; the saved table is never used as is.
- Saves: every `AutosaveSeconds` (120) for profiles marked dirty (equip, claiming a starter agent), on leave (with release)
  and in `BindToClose`.
- Studio without API access, or an unpublished place: the first call fails with a known error, the store switches itself off and
  the profile lives for the session only (a warning says so once). In Studio a profile that is Locked (a force-stopped test left its
  lock) or Unavailable also plays unsaved instead of being kicked. Outside Studio a Locked or transiently Unavailable profile kicks
  with a retry message, so a player never plays on a blank profile that would look like a wipe.
- Every autosave writes every profile (not just changed ones) because the write also renews the lock; `LockStaleSeconds` is 360.
  A quick rejoin on the same server waits for the leaving player's release save (`releasing[userId]`) before it loads.

## Mastery XP and career (ticket 21-mastery)
`MatchService.finish` calls `MetaProgressionService.recordMatch(player, won)` for every human who was in the match. The agent they
deployed with gains `Mastery.MatchXP` (100) plus `WinBonusXP` (50) on a win, and levels up every `XPPerLevel` (100) to `MaxLevel` 10:
one match is one level, so Hardware slot 2 (level 3) opens after two matches, slot 3 (level 6) after five, level 10 after nine
(SPEC_CHANGES: about ten matches, the second item after about two). `Career.Matches` always rises, `Career.Extractions` only for a winning-team member who was still in at the end.
SPEC-QUESTIONs: objectives (intel, vault, Package) add nothing yet; account Level, Credits and the spec 20.1 XP table are not
awarded (the owner replaced account XP with mastery); a player who left early still counts if they were on the roster.

## Not built
- Account Level, XP and Credits are never awarded (no design says how they combine with mastery).
- Dossiers, Black Market, Mint and Stocks have no catalogue, so there is nothing to save for them.
- Saved settings (graphics quality, auto re-cover): Codex's client keeps them locally; no remote carries them.
- A kicked "Locked" join has no retry screen.

## To test (owner)
1. Publish the place with API access on. Play, claim a starter agent, equip a loadout, leave. Rejoin: the agent and loadout are back.
2. Two servers (or a Studio test plus a live server) with the same account: the second waits about 25 s and is kicked.
3. Close the server with a player in it: `BindToClose` saves and releases (no "held by another server" warning on the next join).
