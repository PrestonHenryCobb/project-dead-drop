--!strict
-- The crowd (spec 5.1 to 5.5, 25.4).
--
-- NPCs are Humanoid-free rigs from RigService. The server owns where they are: at GameConfig.NPC.ServerTickHz it
-- moves each anchored root along a stored route; clients interpolate between those updates and animate the rig
-- themselves (NPCController). Nothing on an NPC model marks it as an NPC beyond what the rig itself is.
--
-- Each NPC walks from node to node of the NavGraph, whose links the map generator authored from the layout (so a route
-- cannot leave its floor, cross a wall or enter a zone above the role's clearance). A trip steers round busy doors and
-- stairs and waits if one is overloaded; Staff and above may ride the glass elevators (ElevatorService). At a node it does
-- the node's activity for GameConfig.NPC.ActivitySeconds, then picks another; at a crowd cluster a dozen stand round one
-- spot facing it. Doors open as NPCs approach them (DoorService), and NPCs react to gunfire, explosions and bodies
-- (Reactions). At 0 HP an NPC goes down, bleeds out and, WakeUp.Seconds after it went down, stands up (Death).
--
-- The server moves an NPC less often the farther it is from every player, and not at all while it only stands or strolls
-- farther than Update.FarStuds from all of them (it sleeps; a player coming within range, or anything happening to it,
-- wakes it).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local Weighted = require(Shared:WaitForChild("Util"):WaitForChild("Weighted"))
local NPC = script.Parent.Parent:WaitForChild("NPC")
local CrowdPath = require(NPC.CrowdPath)
local AnimationSync = require(NPC:WaitForChild("AnimationSync"))
local Death = require(NPC:WaitForChild("Death"))
local Movement = require(NPC:WaitForChild("Movement"))
local NavGraph = require(NPC:WaitForChild("NavGraph"))
local NpcTypes = require(NPC:WaitForChild("NpcTypes"))
local Reactions = require(NPC:WaitForChild("Reactions"))
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DoorService = require(script.Parent.DoorService)
local ElevatorService = require(script.Parent.ElevatorService)
local RigService = require(script.Parent.RigService)
local ZoneService = require(script.Parent.ZoneService)

type Npc = NpcTypes.Npc

local NPCService = {}

local config = GameConfig.NPC
local rng = Random.new()
local npcs: { Npc } = {}
local claims: { [number]: number } = {} -- node -> NPCs standing at or heading to it (up to its capacity)
local crowd: NpcTypes.Crowd? = nil
local currentGraph: NavGraph.Graph? = nil

local function claim(node: number)
	claims[node] = (claims[node] or 0) + 1
end

local function release(node: number)
	claims[node] = math.max(0, (claims[node] or 0) - 1)
end

-- How many NPCs a node takes: an ordinary node a pair, a crowd cluster as many as it was made for.
local function capacityOf(graph: NavGraph.Graph, node: number): number
	local cluster = graph.clusters[node]
	return if cluster then cluster.size else config.NodeCapacity
end

local function isFree(graph: NavGraph.Graph): (number) -> boolean
	return function(node: number): boolean
		return (claims[node] or 0) < capacityOf(graph, node)
	end
end

local function activitySeconds(): number
	return rng:NextNumber(config.ActivitySeconds.Min, config.ActivitySeconds.Max)
end

-- Somewhere near the node's ground point, so NPCs sharing an area don't stand on one spot (a crowd cluster is wider). The
-- spot must be reachable in a straight line, on the floor and within the role's tier (R1-ground, R2-tiers); otherwise the
-- node itself.
local function spreadAround(graph: NavGraph.Graph, node: number, maxTier: number): Vector3
	local point = graph.feet[node]
	local reach = if graph.clusters[node] then config.Crowd.ClusterRadiusStuds else config.ArrivalSpread
	for _ = 1, config.ArrivalSpreadTries do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local radius = reach * math.sqrt(rng:NextNumber())
		local spot = NavGraph.standable(
			graph,
			point,
			point + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius),
			maxTier
		)
		if spot then
			return spot
		end
	end
	return point
end

-- How much a role likes a node, by the node's tier (GameConfig.NPC.RoleTierWeights); a crowd cluster is liked more.
local function tierWeight(role: string, graph: NavGraph.Graph): (number) -> number
	local weights = (config.RoleTierWeights :: { [string]: { [number]: number } })[role]
	return function(node: number): number
		return (weights[graph.tiers[node]] or 0) * (if graph.clusters[node] then config.Crowd.ClusterWeight else 1)
	end
end

local function dropHolds(npc: Npc)
	for _, hold in npc.holds do
		hold.state.load = math.max(0, hold.state.load - 1)
	end
	npc.holds = {}
end

-- Reserves room on the links of a trip, to be given back when the NPC should have passed them.
local function reserve(npc: Npc, chain: { NavGraph.Edge }, now: number)
	dropHolds(npc)
	local walked = 0
	for _, edge in chain do
		walked += edge.length
		edge.state.load += 1
		local seconds = walked / math.max(npc.baseSpeed, 1) + config.Capacity.HoldMarginSeconds
		if edge.kind == "Elevator" then
			seconds += config.Elevator.WaitGiveUpSeconds
		end
		table.insert(npc.holds, { state = edge.state, releaseAt = now + seconds })
	end
end

local function settleHolds(npc: Npc, now: number)
	local holds = npc.holds
	local index = 1
	while index <= #holds do
		if now >= holds[index].releaseAt then
			holds[index].state.load = math.max(0, holds[index].state.load - 1)
			table.remove(holds, index)
		else
			index += 1
		end
	end
end

local function overloaded(chain: { NavGraph.Edge }): boolean
	for _, edge in chain do
		if edge.kind ~= "Walk" and edge.state.load >= edge.state.capacity * config.Capacity.OverloadFactor then
			return true
		end
	end
	return false
end

local putOffs = 0 -- trips put off because a door or stair on the way was full (reported with the tick cost)

local function startTrip(npc: Npc, now: number, graph: NavGraph.Graph)
	local destination, legs, chain = NavGraph.tripRoute(
		graph,
		npc.node,
		npc.maxTier,
		config.MinTripStuds,
		isFree(graph),
		rng,
		if npc.limits then nil else tierWeight(npc.role, graph),
		npc.limits
	)
	if not destination or not legs or not chain then
		npc.idleUntil = now + config.ActivitySeconds.Min
		return
	end
	if overloaded(chain) then
		putOffs += 1
		-- A door or stair on the way is full: wait a moment, then choose again.
		npc.idleUntil = now + rng:NextNumber(config.Capacity.RetrySeconds.Min, config.Capacity.RetrySeconds.Max)
		return
	end
	reserve(npc, chain, now)
	npc.tripFrom = npc.node
	release(npc.node)
	claim(destination)
	npc.node = destination
	local first = legs[1]
	local points = first.points
	if #legs == 1 then
		table.insert(points, spreadAround(graph, destination, npc.maxTier))
		-- Only ordinary trips meander; reactions retain their purposeful, clearance-checked routes.
		points = CrowdPath.vary(points, rng, function(from, to)
			return NavGraph.standable(graph, from, to, npc.maxTier)
		end)
	else
		table.insert(legs[#legs].points, spreadAround(graph, destination, npc.maxTier))
	end
	npc.path = Movement.withResume(npc, points)
	npc.pathIndex = 1
	npc.legs = table.move(legs, 2, #legs, 1, {})
	npc.ride = first.ride
	npc.speed = npc.baseSpeed * rng:NextNumber(config.WalkVariation.SpeedMin, config.WalkVariation.SpeedMax)
	npc.state = "Walk"
	AnimationSync.set(npc, "")
end

-- Arrived at a node: do its activity (spec 5.3). A Walk node is only a waypoint, so the NPC walks straight on. At a crowd
-- cluster the NPC faces the middle of the group.
local function beginActivity(npc: Npc, now: number, graph: NavGraph.Graph)
	npc.state = "Idle"
	npc.speed = npc.baseSpeed
	local cluster = graph.clusters[npc.node]
	if cluster and cluster.face then
		local toward = cluster.face - npc.ground
		if Vector3.new(toward.X, 0, toward.Z).Magnitude > 1e-3 then
			npc.yaw = math.atan2(-toward.X, -toward.Z)
		end
	end
	local options = (config.ActivityAnimations :: { [string]: { string } })[graph.activities[npc.node]]
	if not options or #options == 0 then
		npc.idleUntil = now
		AnimationSync.set(npc, "")
		return
	end
	local choice = options[rng:NextInteger(1, #options)]
	-- "Idle" is the base idle animation, which clients already play when nothing else is asked for.
	AnimationSync.set(npc, if choice == "Idle" then "" else choice)
	npc.idleUntil = now + activitySeconds()
end

-- The walk to an elevator is over: wait beside the door for the cab.
local function beginWait(npc: Npc, now: number)
	local ride = npc.ride :: NavGraph.Ride
	npc.state = "Wait"
	npc.waitUntil = now + config.Elevator.WaitGiveUpSeconds
	npc.moveSpeed = 0
	AnimationSync.set(npc, "")
	ElevatorService.call(ride.shaft, ride.fromY)
	if GameConfig.Debug.PrintEvents then
		print(`[NPCService] {npc.role} {npc.id} waits for {ride.shaft} at {ride.fromY}, going to {ride.toY}`)
	end
end

-- No cab came: go back to the node the trip began at and choose again.
local function giveUpWaiting(npc: Npc, now: number)
	dropHolds(npc)
	release(npc.node)
	npc.node = npc.tripFrom
	claim(npc.node)
	npc.ride = nil
	npc.legs = {}
	npc.state = "Idle"
	npc.idleUntil = now
end

-- A downed NPC is on its feet again: it takes the nearest node on its floor within its clearance, and carries on.
local function revive(npc: Npc)
	local graph = currentGraph :: NavGraph.Graph
	local best, bestDistance = npc.post, math.huge
	for node = 1, #graph.feet do
		local offset = graph.feet[node] - npc.ground
		if
			graph.tiers[node] <= npc.maxTier
			and (not npc.limits or not npc.limits.nodeOk or npc.limits.nodeOk(node))
			and math.abs(offset.Y) < config.Graph.SupportWindow.Above
			and #graph.edges[node] > 0
		then
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance < bestDistance then
				best, bestDistance = node, distance
			end
		end
	end
	npc.node = best
	npc.post = best
	claim(best)
end

local hooks: NpcTypes.Hooks = { revive = revive }

local function update(npc: Npc, dt: number, now: number, graph: NavGraph.Graph)
	local state = npc.state
	if state == "Downed" or state == "Eliminated" or state == "Rising" then
		Death.update(npc, dt, now, hooks)
	elseif state == "Held" then
		return -- grabbed in a takedown: it stands still until released or downed
	elseif state == "Cower" or state == "Gasp" then
		Reactions.update(crowd :: NpcTypes.Crowd, npc, now)
	elseif state == "Idle" then
		if now >= npc.idleUntil then
			startTrip(npc, now, graph)
		end
	elseif state == "Wait" then
		local ride = npc.ride :: NavGraph.Ride
		if ElevatorService.ready(ride.shaft, ride.fromY) then
			npc.state = "Board"
			npc.path = table.clone(ride.board)
			npc.pathIndex = 1
			npc.speed = npc.baseSpeed
		elseif now >= npc.waitUntil then
			giveUpWaiting(npc, now)
		end
	elseif state == "Board" then
		local ride = npc.ride :: NavGraph.Ride
		if Movement.follow(npc, dt) then
			if ElevatorService.board(ride.shaft, npc, ride.toY) then
				npc.state = "Ride"
				npc.riding = ride.shaft
			else
				-- The cab left before the NPC was in: back out and wait again.
				npc.path = { ride.board[1], ride.wait }
				npc.pathIndex = 1
				npc.state = "Walk"
			end
		end
	elseif state == "Ride" then
		local ride = npc.ride :: NavGraph.Ride
		local seat = ElevatorService.position(ride.shaft, npc)
		if seat then
			npc.ground = seat
			if ElevatorService.arrived(ride.shaft, npc) then
				npc.riding = nil
				npc.ground = ride.arrival
				if GameConfig.Debug.PrintEvents then
					print(`[NPCService] {npc.role} {npc.id} got out of {ride.shaft} at {ride.toY}`)
				end
				local points = table.clone(ride.exit)
				local nextLeg = table.remove(npc.legs, 1) :: NavGraph.Leg
				for index = 2, #nextLeg.points do
					table.insert(points, nextLeg.points[index])
				end
				npc.ride = nextLeg.ride
				npc.path = points
				npc.pathIndex = 1
				npc.state = "Walk"
			end
		else
			npc.state = "Idle" -- the cab was taken from under it
			npc.riding = nil
			npc.idleUntil = now
		end
	else
		if state == "Flee" or state == "Investigate" then
			Reactions.update(crowd :: NpcTypes.Crowd, npc, now)
		end
		if npc.state == "Investigate" and not npc.path then
			return -- a guard waiting where the noise was
		end
		if Movement.follow(npc, dt) then
			if npc.state == "BackAway" then
				npc.state = "Idle"
				npc.idleUntil = now
			elseif npc.ride and npc.state == "Walk" then
				beginWait(npc, now)
			elseif npc.state ~= "Investigate" then
				beginActivity(npc, now, graph)
			end
		end
	end
	settleHolds(npc, now)
end

-- Builds an NPC of a role standing at a node.
local function createNpc(
	role: Types.Role,
	node: number,
	graph: NavGraph.Graph,
	now: number,
	limits: NavGraph.Limits?
): Npc
	local maxTier = config.RoleMaxTier[role]
	claim(node)
	local ground = spreadAround(graph, node, maxTier)
	local yaw = rng:NextNumber(-math.pi, math.pi)
	local outfit = OutfitDefs.random(role, rng)
	local model, rootHeight = RigService.createNpcRig(outfit, CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
	local speed = config.WalkSpeed[role]
	local npc: Npc = {
		id = model.Name,
		model = model,
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart,
		role = role,
		outfit = outfit,
		maxTier = maxTier,
		limits = limits,
		hp = config.MaxHP,
		baseSpeed = speed,
		speed = speed,
		moveSpeed = 0,
		rootHeight = rootHeight,
		node = node,
		post = node,
		ground = ground,
		yaw = yaw,
		path = nil,
		pathIndex = 1,
		state = "Idle",
		stateUntil = 0,
		idleUntil = now + rng:NextNumber(0, config.ActivitySeconds.Max),
		offset = Vector3.zero,
		downedAt = 0,
		legs = {},
		ride = nil,
		riding = nil,
		waitUntil = 0,
		tripFrom = node,
		holds = {},
		tier = 1,
		phase = rng:NextInteger(0, config.Update.FarEvery - 1),
		owed = 0,
		placed = nil,
		placedYaw = yaw,
		animation = "",
		fall = "Forward",
		posture = "Prone",
		knockUntil = 0,
		threat = nil,
		reactedTo = {},
	}
	Movement.place(npc)
	table.insert(npcs, npc)
	return npc
end

-- Free nodes an NPC of this role may stand at.
local function freeNodes(graph: NavGraph.Graph, maxTier: number): { number }
	local options: { number } = {}
	local free = isFree(graph)
	for node = 1, #graph.feet do
		if graph.tiers[node] <= maxTier and free(node) and #graph.edges[node] > 0 then
			table.insert(options, node)
		end
	end
	return options
end

-- The Warden and the Curator (SPEC_CHANGES 2026-10-25): one each, in their own rooms only. A trip may go only through
-- nodes of those rooms (and rooms inside them), and by the elevators the role may ride that are not locked.
local function limitsFor(graph: NavGraph.Graph, role: "Warden" | "Curator"): NavGraph.Limits
	local settings = config.Tier4[role]
	local inRooms: { [string]: boolean } = {}
	for _, room in settings.Rooms do
		inRooms[room] = true
	end
	return {
		nodeOk = function(node: number): boolean
			return inRooms[graph.rooms[node]] == true
		end,
		shaftOk = function(shaft: string): boolean
			return settings.Elevators and not ElevatorService.isLocked(shaft)
		end,
	}
end

local function spawnTier4(graph: NavGraph.Graph, now: number)
	for _, role in { "Warden", "Curator" } :: { "Warden" | "Curator" } do
		local limits = limitsFor(graph, role)
		local options: { number } = {}
		for node = 1, #graph.feet do
			if (limits.nodeOk :: (number) -> boolean)(node) and #graph.edges[node] > 0 then
				table.insert(options, node)
			end
		end
		if #options == 0 then
			warn(`[NPCService] No node in the rooms of the {role}; it is not spawned`)
			continue
		end
		createNpc(role, options[rng:NextInteger(1, #options)], graph, now, limits)
	end
end

local function spawnAll(graph: NavGraph.Graph)
	local now = os.clock()
	for role, count in config.RoleCounts do
		for _ = 1, count do
			local node = Weighted.pick(freeNodes(graph, config.RoleMaxTier[role]), tierWeight(role, graph), rng)
			if not node then
				warn(`[NPCService] No free node left for a {role} NPC`)
				break
			end
			createNpc(role :: Types.Role, node, graph, now, nil)
		end
	end
	spawnTier4(graph, now)
end

local witnessList: { CoverService.Witness } = {}
local EYE_LIFT = Vector3.new(0, GameConfig.Cover.WitnessEyeHeight, 0)

-- Brings the shared witness list in step with where every NPC is and which way it faces, reusing its tables.
local function refreshWitnesses()
	local count = 0
	for _, npc in npcs do
		if not Death.isDown(npc) then
			count += 1
			local entry = witnessList[count]
			if not entry then
				entry = { position = Vector3.zero, look = Vector3.zero, kind = "Npc" }
				witnessList[count] = entry
			end
			entry.position = npc.ground + EYE_LIFT
			entry.look = Vector3.new(-math.sin(npc.yaw), 0, -math.cos(npc.yaw))
			entry.kind = if npc.role == Enums.Role.Security then "Security" else "Npc"
		end
	end
	for index = #witnessList, count + 1, -1 do
		witnessList[index] = nil
	end
end

-- Which NPCs are near a player (UpdateTier: 1 every tick, 2 and 3 every few, 0 asleep). Looked at a couple of times a
-- second; an NPC is as far as the nearest player.
local refreshTiersAt = 0
local function refreshTiers(now: number)
	if now < refreshTiersAt then
		return
	end
	refreshTiersAt = now + config.Update.PlayerCheckSeconds
	local positions: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(positions, root.Position)
		end
	end
	local settings = config.Update
	for _, npc in npcs do
		local nearest = math.huge
		for _, position in positions do
			nearest = math.min(nearest, (npc.ground - position).Magnitude)
		end
		npc.tier = if nearest <= settings.NearStuds
			then 1
			elseif nearest <= settings.MidStuds then 2
			elseif nearest <= settings.FarStuds then 3
			else 0
	end
end

local tickTotal, tickMax, tickCount, reportAt = 0, 0, 0, 0
local tickIndex = 0
local resyncAt = 0
local active: { Npc } = {}

-- An NPC that only stands or strolls, with no player within Update.FarStuds, is asleep: nothing moves it. Everything else
-- (reactions, bodies, elevators) is always kept up.
local function asleep(npc: Npc): boolean
	return npc.tier == 0 and (npc.state == "Idle" or npc.state == "Walk")
end

local function due(npc: Npc): boolean
	if npc.tier == 1 then
		return true
	end
	local every = if npc.tier == 2 then config.Update.MidEvery else config.Update.FarEvery
	return tickIndex % every == npc.phase % every
end

local function tick(dt: number)
	local current = crowd :: NpcTypes.Crowd
	debug.profilebegin("NPCService.tick")
	local started = os.clock()
	tickIndex += 1
	refreshTiers(started)
	table.clear(active)
	for _, npc in npcs do
		npc.owed += dt
		if not asleep(npc) and (npc.tier <= 1 or npc.state ~= "Idle" and npc.state ~= "Walk" or due(npc)) then
			update(npc, npc.owed, started, current.graph)
			npc.owed = 0
			table.insert(active, npc)
		elseif asleep(npc) then
			npc.owed = 0
		end
	end
	refreshWitnesses()
	Reactions.watchBodies(current, started)
	Movement.separate(active, dt, rng)
	for _, npc in active do
		Movement.place(npc)
		if npc.path and not Death.isDown(npc) then
			DoorService.holdNear(npc.ground, npc.maxTier, true)
		end
	end
	AnimationSync.flush()
	if started >= resyncAt then
		resyncAt = started + config.ActivityResyncSeconds
		AnimationSync.resync(npcs)
	end
	debug.profileend()

	if GameConfig.Debug.PrintNpcCost then
		local cost = (os.clock() - started) * 1000
		tickTotal += cost
		tickMax = math.max(tickMax, cost)
		tickCount += 1
		if started >= reportAt then
			if tickCount > 0 and reportAt > 0 then
				local awake = 0
				for _, npc in npcs do
					if not asleep(npc) then
						awake += 1
					end
				end
				for _, npc in npcs do
					if npc.limits then
						print(
							string.format(
								"[NPCService] %s %s: %s in %s at %.0f, %.0f, %.0f",
								npc.role,
								npc.id,
								npc.state,
								current.graph.rooms[npc.node],
								npc.ground.X,
								npc.ground.Y,
								npc.ground.Z
							)
						)
					end
				end
				print(
					string.format(
						"[NPCService] %d NPCs (%d awake): tick avg %.3f ms, max %.3f ms (%d ticks), %d trips put off",
						#npcs,
						awake,
						tickTotal / tickCount,
						tickMax,
						tickCount,
						putOffs
					)
				)
			end
			tickTotal, tickMax, tickCount = 0, 0, 0
			reportAt = started + GameConfig.Debug.CostReportSeconds
		end
	end
end

-- Who can see players, for suspicion (spec 7.3): every NPC that is not down. Security counts fully, the rest less.
-- The list is kept up to date by the NPC tick and reused, so asking for it costs nothing.
local function describeWitnesses(): { CoverService.Witness }
	return witnessList
end

-- Where bodies lie (spec 7.3: near a body).
local function describeBodies(): { Vector3 }
	local list: { Vector3 } = {}
	for _, body in Death.bodies do
		table.insert(list, body.ground())
	end
	return list
end

-- How a scan finds an NPC by the name of its model (spec 6.3).
local function describeNpc(id: string): DisguiseService.NpcInfo?
	for _, npc in npcs do
		if npc.id == id then
			return { outfit = npc.outfit, position = npc.root.Position, scannable = not Death.isDown(npc) }
		end
	end
	return nil
end

-- Combat (CombatService) reads the live crowd, hits NPCs and makes noise through these.
function NPCService.getNpcs(): { Npc }
	return npcs
end

-- An NPC takes damage; at 0 HP it goes down (spec 5.5, OPEN_QUESTIONS A7). Returns true if this hit downed it.
function NPCService.hitNpc(npc: Npc, amount: number, from: Vector3): boolean
	if Death.isDown(npc) then
		return false
	end
	npc.hp -= amount
	if npc.hp > 0 then
		return false
	end
	if npc.riding then
		ElevatorService.leave(npc.riding, npc)
		npc.riding = nil
	end
	dropHolds(npc)
	Movement.cancelRide(npc)
	Death.down(crowd :: NpcTypes.Crowd, npc, from, os.clock())
	return true
end

-- Finishes off a downed NPC (spec 14.1 execute): it bleeds out at once. Returns false if it was not downed.
function NPCService.executeNpc(npc: Npc): boolean
	if npc.state ~= "Downed" then
		return false
	end
	Death.execute(npc, os.clock())
	return true
end

-- A takedown grabs an NPC (R5-takedown): it stops where it is and struggles until the hold ends. Releasing it lets it
-- carry on: it finishes the walk it was on, then picks its next trip. Returns false if it could not be held.
function NPCService.setHeld(npc: Npc, held: boolean): boolean
	if held then
		if Death.isDown(npc) or npc.state == "Ride" or npc.state == "Board" then
			return false
		end
		Movement.interrupt(npc)
		npc.state = "Held"
		npc.moveSpeed = 0
		AnimationSync.set(npc, Enums.NpcAnimation.TakedownStruggle)
		return true
	end
	if npc.state == "Held" then
		npc.state = "Idle"
		npc.idleUntil = os.clock()
		AnimationSync.set(npc, "")
	end
	return true
end

-- The NPC whose rig this is, if any.
function NPCService.npcOf(model: Model): Npc?
	if not crowd then
		return nil
	end
	for _, npc in (crowd :: NpcTypes.Crowd).npcs do
		if npc.model == model then
			return npc
		end
	end
	return nil
end

-- A shot was fired at `position` and can be heard `audibleStuds` away: NPCs panic or investigate (spec 5.4).
function NPCService.gunshot(position: Vector3, audibleStuds: number)
	if crowd then
		Reactions.gunfire(crowd, position, os.clock(), audibleStuds)
	end
end

function NPCService.Init() end

function NPCService.Start()
	DisguiseService.setNpcLookup(describeNpc)
	CoverService.setSources({ witnesses = describeWitnesses, bodies = describeBodies })
	local nodes: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.NPCNode) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			table.insert(nodes, instance)
		end
	end
	if #nodes == 0 then
		warn("[NPCService] No NPCNode parts in the map; no NPCs will spawn")
		return
	end

	local started = os.clock()
	local graph = NavGraph.load(nodes, ZoneService.tierAt)
	currentGraph = graph
	print(
		string.format("[NPCService] Graph: %d nodes, %d links in %.2f s", #nodes, graph.linkCount, os.clock() - started)
	)

	crowd = { npcs = npcs, graph = graph, rng = rng, claim = claim, release = release }
	spawnAll(graph)
	print(`[NPCService] Spawned {#npcs} NPCs`)

	local interval = 1 / config.ServerTickHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < interval then
			return
		end
		tick(elapsed)
		elapsed = 0
	end)
end

return NPCService
