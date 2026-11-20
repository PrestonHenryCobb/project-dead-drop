--!strict
-- Ticket 8.5c-server: a short lockout of a player's ability and gadgets (Lattice's taser). CombatService sets it; AbilityService and
-- GadgetService refuse requests while it runs. Kept apart from all three so none needs to require another.
--
--   Lockout.set(player, seconds)   locked for that long from now (a longer lockout already running is kept)
--   Lockout.isLocked(player) -> boolean

local Players = game:GetService("Players")

local Lockout = {}

local until_: { [Player]: number } = {}

function Lockout.set(player: Player, seconds: number)
	until_[player] = math.max(until_[player] or 0, os.clock() + seconds)
end

function Lockout.isLocked(player: Player): boolean
	local ends = until_[player]
	return ends ~= nil and os.clock() < ends
end

Players.PlayerRemoving:Connect(function(player)
	until_[player] = nil
end)

return Lockout
