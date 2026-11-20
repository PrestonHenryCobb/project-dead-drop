--!strict
-- Ticket matchmaking (Step 22): which job this server does. "Single" is the one-place game (lobby and match in one server, as today);
-- "Lobby" queues players and teleports them; "Match" runs one match for the players a lobby sent. Matchmaking is off in Studio (a teleport
-- cannot work there) and until both place ids are set in GameConfig.Matchmaking.
--
--   PlaceRole.get() -> "Single" | "Lobby" | "Match"

local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.Parent.GameConfig)

local PlaceRole = {}

local role: string? = nil

function PlaceRole.get(): string
	if role then
		return role
	end
	local config = GameConfig.Matchmaking
	local found = "Single"
	if config.Enabled and not RunService:IsStudio() and config.LobbyPlaceId ~= 0 and config.MatchPlaceId ~= 0 then
		if game.PlaceId == config.LobbyPlaceId then
			found = "Lobby"
		elseif game.PlaceId == config.MatchPlaceId then
			found = "Match"
		end
	end
	role = found
	return found
end

return PlaceRole
