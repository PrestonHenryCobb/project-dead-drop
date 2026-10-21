--!strict
-- Tells clients which animation each NPC is playing. Walking and standing are worked out on the client from how the
-- NPC moves; this covers what the server decides: the activity at a node, cowering, gasping.
--
-- Changes go out together once per tick. The server also repeats every NPC's animation now and then, so a player
-- who joins late, or whose client missed a message, catches up.

local NpcTypes = require(script.Parent.NpcTypes)
local RemoteService = require(script.Parent.Parent.Services.RemoteService)

type Npc = NpcTypes.Npc
type Change = { id: string, animation: string }

local AnimationSync = {}

local pending: { Change } = {}

-- "" means no special animation: the NPC just walks or idles.
function AnimationSync.set(npc: Npc, animation: string)
	if npc.animation == animation then
		return
	end
	npc.animation = animation
	table.insert(pending, { id = npc.id, animation = animation })
end

function AnimationSync.flush()
	if #pending == 0 then
		return
	end
	RemoteService.fireAllClients("NPCAnimation", pending)
	pending = {}
end

function AnimationSync.resync(npcs: { Npc })
	local all: { Change } = {}
	for _, npc in npcs do
		table.insert(all, { id = npc.id, animation = npc.animation })
	end
	RemoteService.fireAllClients("NPCAnimation", all)
end

return AnimationSync
