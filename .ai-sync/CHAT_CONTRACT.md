# Match chat (spec 21.4; Claude Code, 2026-11-19)

**Built, not run in Studio.** `Services/ChatService` sets `ShouldDeliverCallback` on Roblox's default channel (`TextChatService`
`RBXGeneral`), which the server asks for every message and every recipient.

- Not in a match (lobby, results): everyone hears everyone.
- In a match (`MatchService.isInMatch()`): a message reaches only the sender's own team (`TeamService.areTeammates`) and the sender.
  A **spectator's** message never reaches a player who is still playing (a spectating rejoiner must not relay what they see).
  Messages with no sender (system) always pass. In Solos a team is one player, so nobody hears anyone.
- Eliminated players still have their own filtered channel (`SpectateService`, `RequestSpectatorChat`).
- Voice chat is not scoped by code (Roblox cannot do it from a script); decide it in the place settings. Spec: team-only if
  possible, otherwise off in a match.
- If the place uses the legacy chat (`ChatVersion` is not `TextChatService`) the service logs a warning and does nothing.

## To check (owner, two clients)
Duos: both teammates read each other, a third client on the other team reads neither; Solos: nobody reads anyone; a spectating
rejoiner types and the living players see nothing. Check the place's chat setting is "TextChatService".

## Gaps
- No team-chat UI of our own: the default chat window is used. Codex may want a themed one later.
- The default chat window shows display names; inside a team that is expected (spec 21.1 allows usernames over teammates).
