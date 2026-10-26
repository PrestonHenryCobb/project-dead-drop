--!strict
-- How NPCs react to danger (spec 5.4, with the guard change from OPEN_QUESTIONS A6).
--
--   Gunfire or an explosion within range: Guests and Staff cower for CowerSeconds, then flee to the farthest node
--   on their tier at FleeSpeed for FleeSeconds, then go back to normal. NPCs caught within ExplosionDownRadius of
--   a blast are downed (spec 5.5).
--   Security guards walk to the noise to look (see Investigate in GameConfig) and go back to their post once it has
--   been quiet for ReturnAfterQuietSeconds.
--   A body or downed NPC within range: Guests gasp, then step back from it.
--
-- The crowd calls update() each tick to move NPCs on to the next stage; combat calls gunfire() when a shot is fired and
-- will call explosion() when blasts exist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local AnimationSync = require(script.Parent.AnimationSync)
local Death = require(script.Parent.Death)
local NavGraph = require(script.Parent.NavGraph)
local Movement = require(script.Parent.Movement)
local NpcTypes = require(script.Parent.NpcTypes)

type Npc = NpcTypes.Npc
type Crowd = NpcTypes.Crowd

local Reactions = {}

local config = GameConfig.NPC
local WALL_CLEARANCE = 1 -- studs left between an NPC and a wall when it backs away
local EYE_LIFT = Vector3.new(0, 2, 0)

-- Characters do not collide with each other, so rays cast in their group skip NPCs and players and only meet the map.
local rayParams = RaycastParams.new()
rayParams.CollisionGroup = GameConfig.Rig.CollisionGroup

local function distance(npc: Npc, position: Vector3): number
	return (npc.ground - position).Magnitude
end

local function reacting(npc: Npc): boolean
	return npc.state == "Cower"
		or npc.state == "Gasp"
		or npc.state == "BackAway"
		or npc.state == "Held"
		or npc.state == "Board"
		or npc.state == "Ride" -- inside an elevator: nothing out here reaches it
end

local function beginCower(npc: Npc, threat: Vector3, now: number)
	Movement.cancelRide(npc)
	npc.state = "Cower"
	npc.stateUntil = now + config.Panic.CowerSeconds
	Movement.interrupt(npc)
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
	npc.path = Movement.withResume(npc, points)
	npc.pathIndex = 1
	npc.speed = config.Panic.FleeSpeed
	npc.state = "Flee"
	npc.stateUntil = now + config.Panic.FleeSeconds
end

local function beginGasp(npc: Npc, bodyPosition: Vector3, now: number)
	Movement.cancelRide(npc)
	npc.state = "Gasp"
	npc.stateUntil = now + config.Panic.GaspSeconds
	Movement.interrupt(npc)
	npc.threat = bodyPosition
	AnimationSync.set(npc, Enums.NpcAnimation.Gasp)
end

-- A short step directly away from the body, shortened if a wall is in the way.
local function beginBackAway(crowd: Crowd, npc: Npc)
	local from = npc.threat or npc.ground
	local away = Vector3.new(npc.ground.X - from.X, 0, npc.ground.Z - from.Z)
	AnimationSync.set(npc, "")
	if away.Magnitude < 1e-3 then
		npc.state = "Idle"
		return
	end
	local step = away.Unit * config.Panic.BackAwayStuds
	local hit = workspace:Raycast(npc.ground + EYE_LIFT, step, rayParams)
	if hit then
		step = step.Unit * math.max(0, (hit.Position - (npc.ground + EYE_LIFT)).Magnitude - WALL_CLEARANCE)
	end
	-- Only onto floor and within the role's tier (R1-ground, R2-tiers); otherwise it stays put.
	local spot = NavGraph.standable(crowd.graph, npc.ground, npc.ground + step, npc.maxTier)
	if not spot then
		npc.state = "Idle"
		return
	end
	npc.path = { spot }
	npc.pathIndex = 1
	npc.speed = npc.baseSpeed
	npc.state = "BackAway"
end

local function panic(crowd: Crowd, position: Vector3, radius: number, now: number)
	for _, npc in crowd.npcs do
		if
			config.Panic.PanicRoles[npc.role]
			and not Death.isDown(npc)
			and npc.state ~= "Cower"
			and npc.state ~= "Held"
			and distance(npc, position) <= radius
		then
			beginCower(npc, position, now)
		end
	end
end

-- Can this guard make out a noise at `position`? A guard on the same floor hears it within SameFloorStuds. On another
-- floor it counts only if the guard is close and has a clear line to the source, as it would from a stair or balcony
-- that is open to the floor.
local function hears(npc: Npc, position: Vector3, audibleStuds: number): boolean
	local settings = config.Investigate
	local offset = npc.ground - position
	if math.abs(offset.Y) <= settings.FloorHeightStuds then
		return offset.Magnitude <= math.min(settings.SameFloorStuds, audibleStuds)
	end
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > math.min(settings.OpenFloorStuds, audibleStuds) then
		return false
	end
	local from = npc.ground + EYE_LIFT
	return workspace:Raycast(from, position + EYE_LIFT - from, rayParams) == nil
end

local function beginInvestigate(crowd: Crowd, npc: Npc, position: Vector3, now: number)
	local quiet = config.Investigate.ReturnAfterQuietSeconds
	if npc.state == "Investigate" then
		-- Still noisy: keep waiting there.
		npc.stateUntil = now + quiet
		return
	end
	local destination, points = NavGraph.routeNear(crowd.graph, npc.node, npc.maxTier, position)
	if not destination or not points then
		return
	end
	if npc.state ~= "Return" then
		npc.post = npc.node
	end
	Movement.cancelRide(npc)
	crowd.release(npc.node)
	crowd.claim(destination)
	npc.node = destination
	Movement.interrupt(npc)
	points = Movement.withResume(npc, points)
	npc.path = if #points > 0 then points else nil
	npc.pathIndex = 1
	npc.speed = npc.baseSpeed
	npc.state = "Investigate"
	npc.stateUntil = now + quiet
	AnimationSync.set(npc, "")
	if GameConfig.Debug.PrintEvents then
		print(`[Reactions] {npc.role} {npc.id} goes to look at the noise (node {destination}, post {npc.post})`)
	end
end

local function investigate(crowd: Crowd, position: Vector3, now: number, audibleStuds: number)
	for _, npc in crowd.npcs do
		if
			config.Investigate.Roles[npc.role]
			and not Death.isDown(npc)
			and not reacting(npc)
			and hears(npc, position, audibleStuds)
		then
			beginInvestigate(crowd, npc, position, now)
		end
	end
end

local function beginReturn(crowd: Crowd, npc: Npc, now: number)
	local points = if npc.node ~= npc.post then NavGraph.routeTo(crowd.graph, npc.node, npc.maxTier, npc.post) else nil
	if not points then
		npc.state = "Idle"
		npc.idleUntil = now
		return
	end
	crowd.release(npc.node)
	crowd.claim(npc.post)
	npc.node = npc.post
	npc.path = Movement.withResume(npc, points)
	npc.pathIndex = 1
	npc.speed = npc.baseSpeed
	npc.state = "Return"
	if GameConfig.Debug.PrintEvents then
		print(`[Reactions] {npc.role} {npc.id} is going back to its post (node {npc.post})`)
	end
end

-- A shot: panic and investigation reach no further than the weapon can be heard (spec 23), which is shorter for a
-- suppressed weapon than the usual radii.
function Reactions.gunfire(crowd: Crowd, position: Vector3, now: number, audibleStuds: number)
	panic(crowd, position, math.min(config.Panic.GunfireRadius, audibleStuds), now)
	investigate(crowd, position, now, audibleStuds)
end

function Reactions.explosion(crowd: Crowd, position: Vector3, now: number)
	panic(crowd, position, config.Panic.ExplosionRadius, now)
	investigate(crowd, position, now, math.huge)
	for _, npc in crowd.npcs do
		if not Death.isDown(npc) and distance(npc, position) <= config.Panic.ExplosionDownRadius then
			Death.down(crowd, npc, position, now)
		end
	end
end

-- Guests who come within BodyRadius of a body they have not yet reacted to gasp at it.
function Reactions.watchBodies(crowd: Crowd, now: number)
	if #Death.bodies == 0 then
		return
	end
	for _, npc in crowd.npcs do
		if config.Panic.BodyRoles[npc.role] and not Death.isDown(npc) and not reacting(npc) then
			for _, body in Death.bodies do
				if
					not npc.reactedTo[body.model]
					and body.npc ~= npc
					and distance(npc, body.ground()) <= config.Panic.BodyRadius
				then
					npc.reactedTo[body.model] = true
					beginGasp(npc, body.ground(), now)
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
		beginBackAway(crowd, npc)
	elseif npc.state == "Flee" and now >= npc.stateUntil then
		-- Flee time is up: carry on to the node at normal pace, then stop there as usual.
		npc.speed = npc.baseSpeed
		npc.state = "Walk"
	elseif npc.state == "Investigate" and not npc.path and now >= npc.stateUntil then
		beginReturn(crowd, npc, now)
	end
end

return Reactions
