--!strict
-- Types shared by the server's NPC modules.

local NavGraph = require(script.Parent.NavGraph)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

-- Idle: standing at a node doing its activity. Walk: on a trip. Cower, Gasp: frozen reacting. BackAway: stepping away
-- from a body. Flee: running from gunfire or an explosion. Investigate: a guard walking to, then waiting at, a noise.
-- Return: that guard walking back to its post. Downed: at 0 HP, crawling and bleeding out. Eliminated: bled out, lying
-- still until it fades.
export type NpcState =
	"Idle"
	| "Walk"
	| "Cower"
	| "Gasp"
	| "BackAway"
	| "Flee"
	| "Investigate"
	| "Return"
	| "Downed"
	| "Eliminated"

export type Npc = {
	id: string, -- the model's name; clients identify NPCs by it
	model: Model,
	root: BasePart,
	role: Types.Role,
	outfit: Types.OutfitDef, -- what a scan of this NPC copies (spec 6.3)
	maxTier: number,
	hp: number, -- health left; at 0 the NPC goes down (Death)
	baseSpeed: number,
	speed: number, -- the speed it is walking at when under way
	moveSpeed: number, -- the speed right now: eases up from a stop and down to one (GameConfig.Movement)
	rootHeight: number,
	node: number, -- the node the NPC is at, or the one it is walking to
	post: number, -- the node a guard goes back to after investigating
	ground: Vector3, -- where its feet are
	yaw: number,
	path: { Vector3 }?,
	pathIndex: number,
	resume: { Vector3 }?, -- the rest of a stored path a reaction interrupted; walked before the next route (R2-tiers)
	state: NpcState,
	stateUntil: number, -- when Cower, Gasp, Flee, Investigate or Downed ends
	idleUntil: number,
	offset: Vector3, -- separation push, added on top of the path
	placed: Vector3?, -- the root position last written, so unchanged NPCs are not rewritten every tick
	placedYaw: number,
	animation: string, -- what clients should play ("" means just walk or idle)
	threat: Vector3?, -- where the last gunshot or blast came from
	reactedTo: { [Model]: boolean }, -- bodies this NPC has already reacted to
}

-- What the reaction and death modules need from the crowd.
export type Crowd = {
	npcs: { Npc },
	graph: NavGraph.Graph,
	rng: Random,
	claim: (number) -> (),
	release: (number) -> (),
}

-- What the crowd lends to the reaction and death modules so they can finish an NPC's life.
export type Hooks = {
	replace: (role: string, bodyPosition: Vector3) -> (), -- a replacement of this role is due
	remove: (Npc) -> (), -- the NPC's body is gone; forget it
}

return {}
