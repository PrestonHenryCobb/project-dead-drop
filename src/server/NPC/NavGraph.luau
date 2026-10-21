--!strict
-- The NPC node graph (spec 5.2, 25.4). Built once at map load; never touched by PathfindingService afterwards.
--
-- Each NPCNode is linked to its nearest neighbours. For every link the walking path is computed once with
-- PathfindingService and stored as a list of points, together with the highest clearance tier the path passes
-- through, so an NPC never cuts through a zone its role may not enter. At runtime routes are found by a shortest-path
-- search over this graph and simply follow the stored points.
--
--   local graph = NavGraph.build(nodeParts, ZoneService.tierAt)   -- yields while paths are computed
--   local destination, points = NavGraph.route(graph, fromNode, maxTier, minTripStuds, isFree, rng)
--   local destination, points = NavGraph.fleeRoute(graph, fromNode, maxTier, threatPosition)
--   local points = NavGraph.routeTo(graph, fromNode, maxTier, destinationNode)
--   local destination, points = NavGraph.routeNear(graph, fromNode, maxTier, position)

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

export type Edge = {
	to: number,
	length: number,
	points: { Vector3 },
	maxTier: number,
}

export type Graph = {
	feet: { Vector3 }, -- ground position under each node
	tiers: { number },
	activities: { string },
	edges: { { Edge } },
	linkCount: number,
}

local NavGraph = {}

local GROUND_PROBE = Vector3.new(0, -8, 0)
local TIER_PROBE_LIFT = Vector3.new(0, 2, 0) -- sample tiers at body height, not at the floor surface

local function groundBelow(position: Vector3): Vector3
	local result = workspace:Raycast(position, GROUND_PROBE)
	return if result then result.Position else position
end

local function pathLength(points: { Vector3 }): number
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	return total
end

local function maxTierAlong(points: { Vector3 }, tierAt: (Vector3) -> number): number
	local step = GameConfig.NPC.Graph.TierSampleStuds
	local highest = tierAt(points[1] + TIER_PROBE_LIFT)
	for index = 2, #points do
		local a, b = points[index - 1], points[index]
		local samples = math.max(1, math.ceil((b - a).Magnitude / step))
		for sample = 1, samples do
			highest = math.max(highest, tierAt(a:Lerp(b, sample / samples) + TIER_PROBE_LIFT))
		end
	end
	return highest
end

local function reversed(points: { Vector3 }): { Vector3 }
	local out = table.create(#points)
	for index = #points, 1, -1 do
		table.insert(out, points[index])
	end
	return out
end

function NavGraph.build(nodes: { BasePart }, tierAt: (Vector3) -> number): Graph
	local config = GameConfig.NPC.Graph
	local graph: Graph = { feet = {}, tiers = {}, activities = {}, edges = {}, linkCount = 0 }
	for index, node in nodes do
		graph.feet[index] = groundBelow(node.Position)
		graph.tiers[index] = (node:GetAttribute("Tier") :: number?) or 0
		graph.activities[index] = (node:GetAttribute("Activity") :: string?) or "Idle"
		graph.edges[index] = {}
	end

	-- Candidate links, each pair once: a node's nearest neighbours on its own level, plus a few on other levels.
	-- The closest node in 3D is often straight above or below, which is a long walk via a ramp; those links only
	-- survive the detour check when a ramp really is nearby, which is exactly how floors get connected.
	local pairs: { { number } } = {}
	local seen: { [string]: boolean } = {}
	local function addNearest(a: number, near: { { index: number, distance: number } }, count: number)
		table.sort(near, function(p, q)
			return p.distance < q.distance
		end)
		for rank = 1, math.min(count, #near) do
			local b = near[rank].index
			local key = if a < b then `{a}:{b}` else `{b}:{a}`
			if not seen[key] then
				seen[key] = true
				table.insert(pairs, { a, b })
			end
		end
	end
	for a = 1, #nodes do
		local sameLevel: { { index: number, distance: number } } = {}
		local otherLevel: { { index: number, distance: number } } = {}
		for b = 1, #nodes do
			if a ~= b then
				local distance = (graph.feet[a] - graph.feet[b]).Magnitude
				if distance <= config.MaxEdgeStuds then
					local rise = math.abs(graph.feet[a].Y - graph.feet[b].Y)
					table.insert(
						if rise < config.SameLevelStuds then sameLevel else otherLevel,
						{ index = b, distance = distance }
					)
				end
			end
		end
		addNearest(a, sameLevel, config.NeighborsPerNode)
		addNearest(a, otherLevel, config.CrossLevelNeighbors)
	end

	local function link(a: number, b: number)
		local path = PathfindingService:CreatePath({
			AgentRadius = config.AgentRadius,
			AgentHeight = config.AgentHeight,
			AgentCanJump = false,
			AgentCanClimb = false,
		})
		local ok = pcall(function()
			path:ComputeAsync(graph.feet[a], graph.feet[b])
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			return
		end
		local points: { Vector3 } = {}
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
		if #points < 2 then
			return
		end
		local length = pathLength(points)
		if length > (graph.feet[a] - graph.feet[b]).Magnitude * config.MaxDetourRatio then
			return
		end
		local maxTier = maxTierAlong(points, tierAt)
		table.insert(graph.edges[a], { to = b, length = length, points = points, maxTier = maxTier })
		table.insert(graph.edges[b], { to = a, length = length, points = reversed(points), maxTier = maxTier })
		graph.linkCount += 1
	end

	-- Paths are computed a few at a time; ComputeAsync yields, so this spreads the work over several frames.
	local running = 0
	local finished = Instance.new("BindableEvent")
	for _, pair in pairs do
		if running >= config.ConcurrentPaths then
			finished.Event:Wait()
		end
		running += 1
		task.spawn(function()
			link(pair[1], pair[2])
			running -= 1
			finished:Fire()
		end)
	end
	while running > 0 do
		finished.Event:Wait()
	end
	finished:Destroy()
	return graph
end

type Search = {
	distance: { number },
	via: { Edge | false },
	cameFrom: { number },
}

-- Shortest walking distance from one node to every node it can reach, using only nodes and links whose tier is at
-- most maxTier. A linear-scan Dijkstra: the graph has a few hundred nodes and searches are rare.
local function search(graph: Graph, from: number, maxTier: number): Search
	local count = #graph.feet
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
			if edge.maxTier <= maxTier and graph.tiers[edge.to] <= maxTier then
				local candidate = best + edge.length
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

-- The points to walk from one node to a node the search reached.
local function pointsTo(found: Search, from: number, destination: number): { Vector3 }
	local chain: { Edge } = {}
	local node = destination
	while node ~= from do
		table.insert(chain, 1, found.via[node] :: Edge)
		node = found.cameFrom[node]
	end
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

-- Picks a random reachable, free node at least minTrip studs of walking away. Returns the node and the points to
-- walk, or nil if nothing qualifies.
function NavGraph.route(
	graph: Graph,
	from: number,
	maxTier: number,
	minTrip: number,
	isFree: (number) -> boolean,
	rng: Random
): (number?, { Vector3 }?)
	local found = search(graph, from, maxTier)
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
	if #options == 0 then
		return nil, nil
	end
	local destination = options[rng:NextInteger(1, #options)]
	return destination, pointsTo(found, from, destination)
end

-- The route to a given node. Returns nil if it cannot be reached within maxTier.
function NavGraph.routeTo(graph: Graph, from: number, maxTier: number, destination: number): { Vector3 }?
	local found = search(graph, from, maxTier)
	if destination == from or found.distance[destination] == math.huge then
		return nil
	end
	return pointsTo(found, from, destination)
end

-- The route to the reachable node nearest a position (3D distance), for an NPC going to look at something.
function NavGraph.routeNear(graph: Graph, from: number, maxTier: number, position: Vector3): (number?, { Vector3 }?)
	local found = search(graph, from, maxTier)
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
	return best, pointsTo(found, from, best)
end

-- The route for an NPC running from a threat (spec 5.4): the farthest node from `awayFrom` that is on the same tier
-- as the node it starts at and reachable within maxTier. Returns nil if there is none.
function NavGraph.fleeRoute(graph: Graph, from: number, maxTier: number, awayFrom: Vector3): (number?, { Vector3 }?)
	local found = search(graph, from, maxTier)
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
	return best, pointsTo(found, from, best)
end

return NavGraph
