--!strict
-- Ticket kits-24: the numbers of a player's selected Instinct (GameConfig.Instincts[id]), for the services that cannot require
-- AbilityService without a cycle. AbilityService installs the lookup at boot.
--
--   KitRules.of(player) -> { [string]: any }     empty for a player with no Instinct

local KitRules = {}

local NONE: { [string]: any } = table.freeze({})
local lookup: ((Player) -> { [string]: any })? = nil

function KitRules.set(fn: (Player) -> { [string]: any })
	lookup = fn
end

function KitRules.of(player: Player): { [string]: any }
	local find = lookup
	return if find then find(player) else NONE
end

return KitRules
