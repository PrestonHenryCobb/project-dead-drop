--!strict
-- How NPCs react to danger (spec 5.4).
--
--   Gunfire or an explosion within range: Guests and Staff cower for CowerSeconds, then flee to the farthest node
--   on their tier at FleeSpeed for FleeSeconds, then go back to normal. NPCs caught within ExplosionRagdollRadius of
--   a blast die (spec 5.5).
--   A dead body within range: Guests gasp, then step back from it.
--
-- The crowd calls update() each tick to move NPCs on to the next stage; combat (Step 8) will call gunfire() and
-- explosion() when shots and blasts happen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local AnimationSync = require(script.Parent.AnimationSync)
local Death = require(script.Parent.Death)
local NavGraph = require(script.Parent.NavGraph)
local NpcTypes = require(script.Parent.NpcTypes)

type Npc = NpcTypes.Npc
type Crowd = NpcTypes.Crowd

local Reactions = {}

local config = GameConfig.NPC
local WALL_CLEARANCE = 1 -- studs left between an NPC and a wall when it backs away
local EYE_LIFT = Vector3.new(0, 2, 0)

local function distance(npc: Npc, position: Vector3): number
	return (npc.ground - position).Magnitude
end

local function reacting(npc: Npc): boolean
	return npc.state == "Cower" or npc.state == "Gasp" or npc.state == "BackAway"
end

local function beginCower(npc: Npc, threat: Vector3, now: number)
	npc.state = "Cower"
	npc.stateUntil = now + config.Panic.CowerSeconds
	npc.path = nil
	npc.threat = threat
	AnimationSync.set(npc, Enums.NpcAnimation.Cower)
end

local function beginFlee(crowd: Crowd, npc: Npc, now: number)
	local destination, points = NavGraph.fleeRoute(crowd.graph, npc.node, npc.maxTier, npc.threat or npc.ground)
	AnimationSync.set(npc, "")
	if not destination or not points then
		npc.state = "Idle"
		npc.idleUntil = now
		return
	end
	crowd.release(npc.node)
	crowd.claim(destination)
	npc.node = destination
	npc.path = points
	npc.pathIndex = 1
	npc.speed = config.Panic.FleeSpeed
	npc.state = "Flee"
	npc.stateUntil = now + config.Panic.FleeSeconds
end

local function beginGasp(npc: Npc, bodyPosition: Vector3, now: number)
	npc.state = "Gasp"
	npc.stateUntil = now + config.Panic.GaspSeconds
	npc.path = nil
	npc.threat = bodyPosition
	AnimationSync.set(npc, Enums.NpcAnimation.Gasp)
end

-- A short step directly away from the body, shortened if a wall is in the way.
local function beginBackAway(npc: Npc)
	local from = npc.threat or npc.ground
	local away = Vector3.new(npc.ground.X - from.X, 0, npc.ground.Z - from.Z)
	AnimationSync.set(npc, "")
	if away.Magnitude < 1e-3 then
		npc.state = "Idle"
		return
	end
	local step = away.Unit * config.Panic.BackAwayStuds
	local hit = workspace:Raycast(npc.ground + EYE_LIFT, step)
	if hit then
		step = step.Unit * math.max(0, (hit.Position - (npc.ground + EYE_LIFT)).Magnitude - WALL_CLEARANCE)
	end
	npc.path = { npc.ground + step }
	npc.pathIndex = 1
	npc.speed = npc.baseSpeed
	npc.state = "BackAway"
end

local function panic(crowd: Crowd, position: Vector3, radius: number, now: number)
	for _, npc in crowd.npcs do
		if
			config.Panic.PanicRoles[npc.role]
			and npc.state ~= "Dead"
			and npc.state ~= "Cower"
			and distance(npc, position) <= radius
		then
			beginCower(npc, position, now)
		end
	end
end

function Reactions.gunfire(crowd: Crowd, position: Vector3, now: number)
	panic(crowd, position, config.Panic.GunfireRadius, now)
end

-- `replace` is handed to Death so killed NPCs get replaced.
function Reactions.explosion(crowd: Crowd, position: Vector3, now: number, replace: (string, Vector3) -> ())
	panic(crowd, position, config.Panic.ExplosionRadius, now)
	for _, npc in crowd.npcs do
		if npc.state ~= "Dead" and distance(npc, position) <= config.Panic.ExplosionRagdollRadius then
			Death.kill(crowd, npc, position, replace)
		end
	end
end

-- Guests who come within BodyRadius of a body they have not yet reacted to gasp at it.
function Reactions.watchBodies(crowd: Crowd, now: number)
	if #Death.bodies == 0 then
		return
	end
	for _, npc in crowd.npcs do
		if config.Panic.BodyRoles[npc.role] and npc.state ~= "Dead" and not reacting(npc) then
			for _, body in Death.bodies do
				if
					not npc.reactedTo[body.model]
					and body.model ~= npc.model
					and distance(npc, body.position) <= config.Panic.BodyRadius
				then
					npc.reactedTo[body.model] = true
					beginGasp(npc, body.position, now)
					break
				end
			end
		end
	end
end

-- Moves a reacting NPC on to its next stage once the current one has run its time.
function Reactions.update(crowd: Crowd, npc: Npc, now: number)
	if npc.state == "Cower" and now >= npc.stateUntil then
		beginFlee(crowd, npc, now)
	elseif npc.state == "Gasp" and now >= npc.stateUntil then
		beginBackAway(npc)
	elseif npc.state == "Flee" and now >= npc.stateUntil then
		-- Flee time is up: carry on to the node at normal pace, then stop there as usual.
		npc.speed = npc.baseSpeed
		npc.state = "Walk"
	end
end

return Reactions
