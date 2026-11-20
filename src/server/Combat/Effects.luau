--!strict
-- Ticket kits-24: short timed effects on a player (a Talent's buff), read by the systems they change. A key holds one number that
-- lasts until its expiry; setting it again replaces it. Nothing here is sent to any client and nothing is put on a character.
--
--   Effects.set(player, key, value, seconds)
--   Effects.get(player, key, default) -> number     the value while it lasts, else default
--   Effects.clear(player)                           all of a player's effects (they left, or a new match)
--   Effects.clearAll()
--
-- Keys: DamageDealt and DamageTaken (CombatService, multipliers), SuspicionGain (CoverService, a multiplier), ScanTime and ScanRange
-- (DisguiseService, multipliers), HackTime (AbilityService's hold-time multiplier).

type Entry = { value: number, untilAt: number }

local Effects = {}

local active: { [Player]: { [string]: Entry } } = {}

function Effects.set(player: Player, key: string, value: number, seconds: number)
	local entries: { [string]: Entry } = active[player] or {}
	active[player] = entries
	entries[key] = { value = value, untilAt = os.clock() + seconds }
end

function Effects.get(player: Player, key: string, default: number): number
	local entries = active[player]
	local entry = if entries then entries[key] else nil
	if entry and os.clock() < entry.untilAt then
		return entry.value
	end
	return default
end

function Effects.clear(player: Player)
	active[player] = nil
end

function Effects.clearAll()
	table.clear(active)
end

return Effects
