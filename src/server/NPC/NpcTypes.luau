--!strict
-- Types shared by the server's NPC modules.

local NavGraph = require(script.Parent.NavGraph)
local Knockdown =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Knockdown"))
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

-- Idle: standing at a node doing its activity. Walk: on a trip. Cower, Gasp: frozen reacting. BackAway: stepping away
-- from a body. Flee: running from gunfire or an explosion. Investigate: a guard walking to, then waiting at, a noise.
-- Return: that guard walking back to its post. Downed: at 0 HP, crawling and bleeding out. Eliminated: bled out, lying
-- still. Rising: getting up, WakeUp.Seconds after it went down. Wait, Board, Ride: an elevator trip (waiting beside the
-- door for the cab, walking in, riding).
export type NpcState =
	"Idle"
	| "Walk"
	| "Cower"
	| "Gasp"
	| "BackAway"
	| "Flee"
	| "Investigate"
	| "Return"
	| "Held" -- grabbed in a takedown: stands still until it ends (R5-takedown)
	| "Wait"
	| "Board"
	| "Ride"
	| "Downed"
	| "Eliminated"
	| "Rising"

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
	fall: Knockdown.Fall, -- how it went down, once downed (R4-body-animation)
	posture: Knockdown.Posture, -- lying on its front or back, once downed
	knockUntil: number, -- the fall plays until then; the crawl starts after it
	downedAt: number, -- when it last went down (it stands up WakeUp.Seconds later)
	legs: { NavGraph.Leg }, -- the rest of a trip that rides an elevator: the legs after the one being walked
	ride: NavGraph.Ride?, -- the elevator ride this walk ends at
	riding: string?, -- the shaft whose cab the NPC is in
	waitUntil: number, -- an NPC waiting for a cab gives up at this time
	tripFrom: number, -- the node an elevator trip began at (it returns there if the cab never comes)
	holds: { { state: NavGraph.LinkState, releaseAt: number } }, -- room reserved on the links a trip uses
	tier: number, -- how often the server moves it: 1 near a player, 2 mid, 3 far, 0 asleep (Update)
	phase: number, -- which ticks a mid or far NPC is moved on (0 to FarEvery - 1)
	owed: number, -- seconds of movement it has not been given yet while it was skipped
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

-- What the crowd lends to the death module so a downed NPC can get up again (relayout-2: nothing replaces it).
export type Hooks = {
	revive: (Npc) -> (), -- the NPC is on its feet: give it a node to stand at and a routine to return to
}

return {}
