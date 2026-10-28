--!strict
-- Ticket 13B-a: the bots in the match in progress. A bot is a crowd NPC that a brain (BotService) walks to Intel stations
-- and vault terminals. Systems that count agents on the map (VaultService) read this list; nothing is put on the NPC's
-- model, so a bot looks exactly like any other NPC (CLAUDE.md rule 3).
--
--   BotRegistry.add(bot) / BotRegistry.clear()
--   BotRegistry.list() -> { Bot }
--   BotRegistry.alive(bot) -> boolean         on its feet (not downed, eliminated or rising)
--   BotRegistry.teamCount() -> number         bot teams in the match

local NpcTypes = require(script.Parent.Parent.NPC.NpcTypes)

export type Bot = {
	teamId: number,
	npc: NpcTypes.Npc,
	intelTaken: number,
	stationId: string?, -- the Intel station being walked to or worked
	workingUntil: number, -- os.clock(): working a station until then (0: not working)
	destination: Vector3?, -- where the brain last sent it
	sentAt: number, -- os.clock() of that
}

local BotRegistry = {}

local bots: { Bot } = {}

function BotRegistry.add(bot: Bot)
	table.insert(bots, bot)
end

function BotRegistry.clear()
	table.clear(bots)
end

function BotRegistry.list(): { Bot }
	return bots
end

function BotRegistry.alive(bot: Bot): boolean
	local state = bot.npc.state
	return state ~= "Downed" and state ~= "Eliminated" and state ~= "Rising"
end

function BotRegistry.teamCount(): number
	local seen: { [number]: boolean } = {}
	local count = 0
	for _, bot in bots do
		if not seen[bot.teamId] then
			seen[bot.teamId] = true
			count += 1
		end
	end
	return count
end

return BotRegistry
