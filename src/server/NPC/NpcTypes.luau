--!strict
-- Types shared by the server's NPC modules.

local NavGraph = require(script.Parent.NavGraph)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

-- Idle: standing at a node doing its activity. Walk: on a trip. Cower, Gasp: frozen reacting. BackAway: stepping away
-- from a body. Flee: running from gunfire or an explosion. Dead: ragdolled, no longer in the crowd.
export type NpcState = "Idle" | "Walk" | "Cower" | "Gasp" | "BackAway" | "Flee" | "Dead"

export type Npc = {
	id: string, -- the model's name; clients identify NPCs by it
	model: Model,
	root: BasePart,
	role: Types.Role,
	maxTier: number,
	baseSpeed: number,
	speed: number,
	rootHeight: number,
	node: number, -- the node the NPC is at, or the one it is walking to
	ground: Vector3, -- where its feet are
	yaw: number,
	path: { Vector3 }?,
	pathIndex: number,
	state: NpcState,
	stateUntil: number, -- when Cower, Gasp or Flee ends
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

return {}
