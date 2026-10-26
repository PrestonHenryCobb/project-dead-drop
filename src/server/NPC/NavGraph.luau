--!strict
-- The NPC node graph (spec 5.2, 25.4), read from the map. The map generator (Tools/Gala/Build.luau) authors every link
-- from the layout: where nodes are, which pairs join, the polyline between them on the real floor, the highest clearance
-- tier it passes through, and how many NPCs fit on it at once. Nothing is discovered at runtime and PathfindingService is
-- never used: a route can only follow what the generator verified against the geometry.
--
-- Each NPCNode part carries NodeId, Tier, Activity and (for crowd clusters) Cluster, ClusterSize, FaceX, FaceZ, and a
-- Links attribute naming its links to higher-numbered nodes: "to:tier:capacity:kind:x,y,z;x,y,z", joined by "|". The kind
-- is Walk, Door, Stair, or Elevator@shaft@n (the first n points reach the cab, the rest leave it).
--
--   local graph = NavGraph.load(nodeParts, ZoneService.tierAt)
--   local destination, points = NavGraph.route(graph, fromNode, maxTier, minTripStuds, isFree, rng, weightOf?)
--   local destination, legs, links = NavGraph.tripRoute(graph, fromNode, maxTier, minTripStuds, isFree, rng, weightOf?)
--   local destination, points = NavGraph.fleeRoute(graph, fromNode, maxTier, threatPosition)
--   local points = NavGraph.routeTo(graph, fromNode, maxTier, destinationNode)
--   local destination, points = NavGraph.routeNear(graph, fromNode, maxTier, position)
--
-- Reaction routes (flee, investigate, return) never use an elevator; an ordinary trip (tripRoute) may.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Weighted = require(Shared:WaitForChild("Util"):WaitForChild("Weighted"))

-- How many NPCs are on a link now, shared by its two directions.
export type LinkState = { load: number, capacity: number }

-- What a trip does at an elevator: wait beside the door, walk in, ride, walk out.
export type Ride = {
	shaft: string,
	wait: Vector3, -- beside the door, where an NPC waits for the cab
	board: { Vector3 }, -- the doorway and the cab, from the waiting spot
	cab: Vector3, -- where the NPC stands in the cab at the first stop
	arrival: Vector3, -- ... and at the second
	exit: { Vector3 }, -- the doorway and the waiting spot beyond it
	fromY: number,
	toY: number,
}

export type Edge = {
	to: number,
	length: number,
	points: { Vector3 },
	maxTier: number,
	kind: string, -- "Walk", "Door", "Stair" or "Elevator"
	state: LinkState,
	ride: Ride?,
}

-- One stretch of a trip: points to walk, then (if it ends at an elevator) the ride to take.
export type Leg = { points: { Vector3 }, ride: Ride? }

-- Where a trip may go beyond the clearance: the Warden and the Curator stay in their own rooms and may ride only some
-- shafts.
export type Limits = { nodeOk: ((number) -> boolean)?, shaftOk: ((string) -> boolean)? }

export type Graph = {
	feet: { Vector3 }, -- ground position under each node
	tiers: { number }, -- the stricter of the node's authored Tier and the zone it stands in
	tierAt: (Vector3) -> number, -- ZoneService.tierAt, kept for checks made at runtime (NavGraph.standable)
	activities: { string },
	rooms: { string }, -- the room each node is in ("" if the map did not say)
	clusters: { [number]: { size: number, face: Vector3? } }, -- crowd clusters by node
	edges: { { Edge } },
	linkCount: number,
}

local NavGraph = {}

local TIER_PROBE_LIFT = Vector3.new(0, 2, 0) -- sample tiers at body height, not at the floor surface

-- Rays in the character group meet only the walkable map: not characters, invisible zone volumes or other triggers.
local floorParams = RaycastParams.new()
floorParams.CollisionGroup = GameConfig.Rig.CollisionGroup
floorParams.RespectCanCollide = true

local function parsePoints(text: string): { Vector3 }
	local points: { Vector3 } = {}
	for _, triple in string.split(text, ";") do
		local x, y, z = string.match(triple, "^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
		table.insert(points, Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number))
	end
	return points
end

local function pathLength(points: { Vector3 }): number
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

local function reversed(points: { Vector3 }): { Vector3 }
	local out = table.create(#points)
	for index = #points, 1, -1 do
		table.insert(out, points[index])
	end
	return out
end

-- The ride at an elevator link: its points are the walk to the cab (the first `before`), then the walk away from it.
local function rideOf(shaft: string, before: number, points: { Vector3 }): Ride
	local count = #points
	return {
		shaft = shaft,
		wait = points[before - 2],
		board = { points[before - 1], points[before] },
		cab = points[before],
		arrival = points[before + 1],
		exit = { points[before + 2], points[count] },
		fromY = points[before].Y,
		toY = points[before + 1].Y,
	}
end

function NavGraph.load(nodes: { BasePart }, tierAt: (Vector3) -> number): Graph
	local graph: Graph = {
		feet = {},
		tiers = {},
		tierAt = tierAt,
		activities = {},
		rooms = {},
		clusters = {},
		edges = {},
		linkCount = 0,
	}
	-- Nodes are numbered by the generator (NodeId, with gaps where a node was dropped); the graph numbers them densely.
	local ordered = table.clone(nodes)
	table.sort(ordered, function(a, b)
		return (a:GetAttribute("NodeId") :: number) < (b:GetAttribute("NodeId") :: number)
	end)
	local indexOfId: { [number]: number } = {}
	for index, node in ordered do
		indexOfId[node:GetAttribute("NodeId") :: number] = index
		graph.feet[index] = node.Position - Vector3.new(0, 1, 0)
		local authored = (node:GetAttribute("Tier") :: number?) or 0
		graph.tiers[index] = math.max(authored, tierAt(graph.feet[index] + TIER_PROBE_LIFT))
		graph.activities[index] = (node:GetAttribute("Activity") :: string?) or "Idle"
		graph.rooms[index] = (node:GetAttribute("Room") :: string?) or ""
		graph.edges[index] = {}
		local clusterSize = node:GetAttribute("ClusterSize")
		if type(clusterSize) == "number" then
			local faceX, faceZ = node:GetAttribute("FaceX"), node:GetAttribute("FaceZ")
			graph.clusters[index] = {
				size = clusterSize,
				face = if type(faceX) == "number" and type(faceZ) == "number"
					then Vector3.new(faceX, graph.feet[index].Y, faceZ)
					else nil,
			}
		end
	end

	for index, node in ordered do
		local links = node:GetAttribute("Links")
		if type(links) ~= "string" or links == "" then
			continue
		end
		for _, entry in string.split(links, "|") do
			local to, tier, capacity, kind, text = string.match(entry, "^(%d+):(%d+):(%d+):([^:]+):(.*)$")
			local other = indexOfId[tonumber(to) :: number]
			if not other then
				continue
			end
			local points = parsePoints(text :: string)
			local length = pathLength(points)
			local shaft, before = string.match(kind :: string, "^Elevator@(%w+)@(%d+)$")
			local state: LinkState = { load = 0, capacity = tonumber(capacity) :: number }
			local forward: Edge = {
				to = other,
				length = length,
				points = points,
				maxTier = tonumber(tier) :: number,
				kind = if shaft then "Elevator" else kind :: string,
				state = state,
				ride = if shaft then rideOf(shaft, tonumber(before) :: number, points) else nil,
			}
			local backPoints = reversed(points)
			local back: Edge = {
				to = index,
				length = length,
				points = backPoints,
				maxTier = forward.maxTier,
				kind = forward.kind,
				state = state,
				ride = if shaft then rideOf(shaft, tonumber(before) :: number, backPoints) else nil,
			}
			table.insert(graph.edges[index], forward)
			table.insert(graph.edges[other], back)
			graph.linkCount += 1
		end
	end
	return graph
end

-- Can a body step from `from` to `to` in a straight line (R1-ground, R2-tiers)? Clear of walls at chest height, with
-- floor under `to` near `from`'s height, and no higher tier than maxTier there. Returns the supported point, or nil.
-- Used for the few moves that leave the stored paths: standing spread round a node, backing away, a downed crawl.
function NavGraph.standable(graph: Graph, from: Vector3, to: Vector3, maxTier: number): Vector3?
	local window = GameConfig.NPC.Graph.SupportWindow
	local chest = TIER_PROBE_LIFT
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude > 1e-3 and workspace:Raycast(from + chest, flat, floorParams) then
		return nil
	end
	local hit = workspace:Raycast(
		Vector3.new(to.X, from.Y + window.Above, to.Z),
		Vector3.new(0, -(window.Above + window.Below), 0),
		floorParams
	)
	if not hit then
		return nil
	end
	local supported = Vector3.new(to.X, hit.Position.Y, to.Z)
	if graph.tierAt(supported + chest) > maxTier then
		return nil
	end
	return supported
end

type Search = {
	distance: { number },
	via: { Edge | false },
	cameFrom: { number },
}

-- What walking a link costs: its length, and more as it fills (an NPC avoids a doorway or stair that is already busy),
-- and a fixed wait for an elevator.
local function cost(edge: Edge, crowded: boolean): number
	local total = edge.length
	if crowded then
		total *= 1 + GameConfig.NPC.Capacity.CongestionWeight * math.min(edge.state.load / edge.state.capacity, 2)
	end
	if edge.kind == "Elevator" then
		total += GameConfig.NPC.Elevator.WaitCostStuds
	end
	return total
end

-- Shortest walking distance from one node to every node it can reach, using only nodes and links whose tier is at
-- most maxTier. A linear-scan Dijkstra: the graph has a few hundred nodes and searches are rare.
local function search(
	graph: Graph,
	from: number,
	maxTier: number,
	rides: boolean,
	crowded: boolean,
	limits: Limits?
): Search
	local count = #graph.feet
	local nodeOk = if limits then limits.nodeOk else nil
	local shaftOk = if limits then limits.shaftOk else nil
	local found: Search = {
		distance = table.create(count, math.huge),
		via = table.create(count, false),
		cameFrom = table.create(count, 0),
	}
	local done: { boolean } = table.create(count, false)
	found.distance[from] = 0

	for _ = 1, count do
		local current, best = 0, math.huge
		for index = 1, count do
			if not done[index] and found.distance[index] < best then
				current, best = index, found.distance[index]
			end
		end
		if current == 0 then
			break
		end
		done[current] = true
		for _, edge in graph.edges[current] do
			local ride = edge.ride
			if
				edge.maxTier <= maxTier
				and graph.tiers[edge.to] <= maxTier
				and (rides or ride == nil)
				and (not nodeOk or nodeOk(edge.to))
				and (not ride or not shaftOk or shaftOk(ride.shaft))
			then
				local candidate = best + cost(edge, crowded)
				if candidate < found.distance[edge.to] then
					found.distance[edge.to] = candidate
					found.via[edge.to] = edge
					found.cameFrom[edge.to] = current
				end
			end
		end
	end
	return found
end

local function chainTo(found: Search, from: number, destination: number): { Edge }
	local chain: { Edge } = {}
	local node = destination
	while node ~= from do
		table.insert(chain, 1, found.via[node] :: Edge)
		node = found.cameFrom[node]
	end
	return chain
end

-- The points to walk along a chain of links (no rides: reaction routes never use an elevator).
local function pointsOf(chain: { Edge }): { Vector3 }
	local points: { Vector3 } = {}
	for edgeIndex, edge in chain do
		for pointIndex, point in edge.points do
			if edgeIndex == 1 or pointIndex > 1 then
				table.insert(points, point)
			end
		end
	end
	return points
end

-- The legs of a trip: walk to an elevator's waiting spot, ride, walk on. A trip with no elevator is one leg.
local function legsOf(chain: { Edge }): { Leg }
	local legs: { Leg } = {}
	local current: { Vector3 } = {}
	for _, edge in chain do
		local ride = edge.ride
		if ride then
			-- the walk to the waiting spot is the link's first point
			if #current == 0 then
				table.insert(current, edge.points[1])
			end
			table.insert(legs, { points = current, ride = ride })
			current = { ride.exit[2] }
		else
			for pointIndex, point in edge.points do
				if #current > 0 and pointIndex == 1 then
					continue
				end
				table.insert(current, point)
			end
		end
	end
	table.insert(legs, { points = current, ride = nil })
	return legs
end

local function pick(
	graph: Graph,
	found: Search,
	from: number,
	minTrip: number,
	isFree: (number) -> boolean,
	rng: Random,
	weightOf: ((number) -> number)?
): number?
	local options: { number } = {}
	for index = 1, #graph.feet do
		if
			index ~= from
			and found.distance[index] >= minTrip
			and found.distance[index] < math.huge
			and isFree(index)
		then
			table.insert(options, index)
		end
	end
	local prefer = GameConfig.NPC.TripPreferStuds
	return Weighted.pick(options, function(index: number): number
		local nearness = 1 / (1 + (found.distance[index] / prefer) ^ 2)
		return nearness * (if weightOf then weightOf(index) else 1)
	end, rng)
end

-- Picks a random reachable, free node at least minTrip studs of walking away, favouring nearer ones (a node twice
-- GameConfig.NPC.TripPreferStuds away is a fifth as likely as a near one), so the crowd mills about where it is and only
-- sometimes crosses the map. Returns the node and the points to walk, or nil if nothing qualifies. No elevators.
function NavGraph.route(
	graph: Graph,
	from: number,
	maxTier: number,
	minTrip: number,
	isFree: (number) -> boolean,
	rng: Random,
	weightOf: ((number) -> number)?
): (number?, { Vector3 }?)
	local found = search(graph, from, maxTier, false, false)
	local destination = pick(graph, found, from, minTrip, isFree, rng, weightOf)
	if not destination then
		return nil, nil
	end
	return destination, pointsOf(chainTo(found, from, destination))
end

-- An ordinary trip: like route, but it may ride an elevator and it steers clear of busy links. Returns the node, the
-- legs of the trip and the links it uses (for reserving their room).
function NavGraph.tripRoute(
	graph: Graph,
	from: number,
	maxTier: number,
	minTrip: number,
	isFree: (number) -> boolean,
	rng: Random,
	weightOf: ((number) -> number)?,
	limits: Limits?
): (number?, { Leg }?, { Edge }?)
	local found = search(graph, from, maxTier, true, true, limits)
	local destination = pick(graph, found, from, minTrip, isFree, rng, weightOf)
	if not destination then
		return nil, nil, nil
	end
	local chain = chainTo(found, from, destination)
	return destination, legsOf(chain), chain
end

-- The route to a given node. Returns nil if it cannot be reached within maxTier.
function NavGraph.routeTo(graph: Graph, from: number, maxTier: number, destination: number): { Vector3 }?
	local found = search(graph, from, maxTier, false, false)
	if destination == from or found.distance[destination] == math.huge then
		return nil
	end
	return pointsOf(chainTo(found, from, destination))
end

-- The route to the reachable node nearest a position (3D distance), for an NPC going to look at something.
function NavGraph.routeNear(graph: Graph, from: number, maxTier: number, position: Vector3): (number?, { Vector3 }?)
	local found = search(graph, from, maxTier, false, false)
	local best, bestDistance = nil, math.huge
	for index = 1, #graph.feet do
		if found.distance[index] < math.huge then
			local distance = (graph.feet[index] - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	if not best then
		return nil, nil
	end
	if best == from then
		return best, {}
	end
	return best, pointsOf(chainTo(found, from, best))
end

-- The route for an NPC running from a threat (spec 5.4): the farthest node from `awayFrom` that is on the same tier
-- as the node it starts at and reachable within maxTier. Returns nil if there is none.
function NavGraph.fleeRoute(graph: Graph, from: number, maxTier: number, awayFrom: Vector3): (number?, { Vector3 }?)
	local found = search(graph, from, maxTier, false, false)
	local best, bestDistance = nil, -1
	for index = 1, #graph.feet do
		if index ~= from and found.distance[index] < math.huge and graph.tiers[index] == graph.tiers[from] then
			local distance = (graph.feet[index] - awayFrom).Magnitude
			if distance > bestDistance then
				best, bestDistance = index, distance
			end
		end
	end
	if not best then
		return nil, nil
	end
	return best, pointsOf(chainTo(found, from, best))
end

return NavGraph
