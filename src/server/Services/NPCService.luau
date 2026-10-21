--!strict
-- The crowd (spec 5.1, 5.2, 25.4).
--
-- NPCs are Humanoid-free rigs from RigService. The server owns where they are: at GameConfig.NPC.ServerTickHz it
-- moves each anchored root along a precomputed route; clients interpolate between those updates and animate the
-- rig themselves (NPCController). Nothing on an NPC model marks it as an NPC beyond what the rig itself is.
--
-- Each NPC walks from node to node of the NavGraph, only through zones its role is allowed in, waits at the node
-- for GameConfig.NPC.ActivitySeconds, then picks another. Node activities and reactions come in Step 5.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local NavGraph = require(script.Parent.Parent:WaitForChild("NPC"):WaitForChild("NavGraph"))
local RigService = require(script.Parent.RigService)
local ZoneService = require(script.Parent.ZoneService)

type Npc = {
	model: Model,
	root: BasePart,
	maxTier: number,
	speed: number,
	rootHeight: number,
	node: number, -- the node the NPC is at, or the one it is walking to
	ground: Vector3, -- where its feet are
	yaw: number,
	path: { Vector3 }?,
	pathIndex: number,
	idleUntil: number,
	offset: Vector3, -- separation push, added on top of the path
	placed: Vector3?, -- the root position last written, so unchanged NPCs aren't rewritten every tick
	placedYaw: number,
}

local NPCService = {}

local config = GameConfig.NPC
local rng = Random.new()
local npcs: { Npc } = {}
local graph: NavGraph.Graph? = nil
local claims: { [number]: number } = {} -- node -> NPCs standing at or heading to it

local function isFree(node: number): boolean
	return (claims[node] or 0) == 0
end

local function claim(node: number)
	claims[node] = (claims[node] or 0) + 1
end

local function release(node: number)
	claims[node] = math.max(0, (claims[node] or 0) - 1)
end

local function activitySeconds(): number
	return rng:NextNumber(config.ActivitySeconds.Min, config.ActivitySeconds.Max)
end

-- Somewhere near the node's ground point, so NPCs sharing an area don't stand on one spot.
local function spreadAround(point: Vector3): Vector3
	local angle = rng:NextNumber(0, 2 * math.pi)
	local radius = rng:NextNumber(0, config.ArrivalSpread)
	return point + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- Yaw such that CFrame.Angles(0, yaw, 0) looks along the direction.
local function yawToward(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function turnToward(current: number, target: number, maxStep: number): number
	local delta = (target - current + math.pi) % (2 * math.pi) - math.pi
	return current + math.clamp(delta, -maxStep, maxStep)
end

local function startTrip(npc: Npc, now: number)
	local destination, points =
		NavGraph.route(graph :: NavGraph.Graph, npc.node, npc.maxTier, config.MinTripStuds, isFree, rng)
	if not destination or not points then
		npc.idleUntil = now + config.ActivitySeconds.Min
		return
	end
	release(npc.node)
	claim(destination)
	npc.node = destination
	table.insert(points, spreadAround(points[#points]))
	npc.path = points
	npc.pathIndex = 1
end

local function advance(npc: Npc, dt: number, now: number)
	local path = npc.path
	if not path then
		if now >= npc.idleUntil then
			startTrip(npc, now)
		end
		return
	end

	local remaining = npc.speed * dt
	local heading = Vector3.zero
	while remaining > 0 and npc.pathIndex <= #path do
		local target = path[npc.pathIndex]
		local delta = target - npc.ground
		local distance = delta.Magnitude
		if distance > 1e-3 then
			heading = Vector3.new(delta.X, 0, delta.Z)
		end
		if distance <= remaining then
			npc.ground = target
			remaining -= distance
			npc.pathIndex += 1
		else
			npc.ground += delta.Unit * remaining
			remaining = 0
		end
	end

	if heading.Magnitude > 1e-3 then
		npc.yaw = turnToward(npc.yaw, yawToward(heading), math.rad(config.MaxYawRate) * dt)
	end
	if npc.pathIndex > #path then
		npc.path = nil
		npc.idleUntil = now + activitySeconds()
	end
end

-- Pushes NPCs that are closer than SeparationStuds apart away from each other (spec 5.2).
local function separate(dt: number)
	local cellSize = config.SeparationStuds
	local cells: { [number]: { Npc } } = {}
	-- One number per cell (the map is a few hundred studs across, far inside these ranges).
	local function cellKey(x: number, y: number, z: number): number
		return ((x + 4096) * 1024 + (y + 512)) * 8192 + (z + 4096)
	end
	local function cellOf(npc: Npc): (number, number, number)
		local p = npc.ground + npc.offset
		return math.floor(p.X / cellSize), math.floor(p.Y / 12), math.floor(p.Z / cellSize)
	end
	for _, npc in npcs do
		local key = cellKey(cellOf(npc))
		local list = cells[key]
		if not list then
			list = {}
			cells[key] = list
		end
		table.insert(list, npc)
	end

	local decay = math.exp(-config.SeparationDecayPerSecond * dt)
	for _, npc in npcs do
		local cx, cy, cz = cellOf(npc)
		local here = npc.ground + npc.offset
		local push = Vector3.zero
		for dx = -1, 1 do
			for dz = -1, 1 do
				for _, other in cells[cellKey(cx + dx, cy, cz + dz)] or {} do
					if other ~= npc then
						local diff = here - (other.ground + other.offset)
						diff = Vector3.new(diff.X, 0, diff.Z)
						local distance = diff.Magnitude
						if distance < cellSize then
							local away = if distance > 1e-3
								then diff.Unit
								else Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
							push += away * (cellSize - distance)
						end
					end
				end
			end
		end
		local offset = npc.offset * decay + push * config.SeparationStrength * dt
		if offset.Magnitude > config.SeparationMaxOffset then
			offset = offset.Unit * config.SeparationMaxOffset
		end
		npc.offset = offset
	end
end

local PLACE_TOLERANCE = 0.01 -- studs and radians; smaller changes are not worth replicating

local function place(npc: Npc)
	local position = npc.ground + npc.offset + Vector3.new(0, npc.rootHeight, 0)
	local placed = npc.placed
	if
		placed
		and (placed - position).Magnitude < PLACE_TOLERANCE
		and math.abs(npc.placedYaw - npc.yaw) < PLACE_TOLERANCE
	then
		return
	end
	npc.placed = position
	npc.placedYaw = npc.yaw
	npc.root.CFrame = CFrame.new(position) * CFrame.Angles(0, npc.yaw, 0)
end

local tickTotal, tickMax, tickCount, reportAt = 0, 0, 0, 0

local function tick(dt: number)
	debug.profilebegin("NPCService.tick")
	local started = os.clock()
	for _, npc in npcs do
		advance(npc, dt, started)
	end
	separate(dt)
	for _, npc in npcs do
		place(npc)
	end
	debug.profileend()

	if GameConfig.Debug.PrintNpcCost then
		local cost = (os.clock() - started) * 1000
		tickTotal += cost
		tickMax = math.max(tickMax, cost)
		tickCount += 1
		if started >= reportAt then
			if tickCount > 0 and reportAt > 0 then
				print(
					string.format(
						"[NPCService] %d NPCs: tick avg %.3f ms, max %.3f ms (%d ticks)",
						#npcs,
						tickTotal / tickCount,
						tickMax,
						tickCount
					)
				)
			end
			tickTotal, tickMax, tickCount = 0, 0, 0
			reportAt = started + GameConfig.Debug.CostReportSeconds
		end
	end
end

local function spawnAll(nodeCount: number)
	local now = os.clock()
	local g = graph :: NavGraph.Graph
	for role, count in config.RoleCounts do
		local maxTier = config.RoleMaxTier[role]
		for _ = 1, count do
			local options: { number } = {}
			for node = 1, nodeCount do
				if g.tiers[node] <= maxTier and isFree(node) and #g.edges[node] > 0 then
					table.insert(options, node)
				end
			end
			if #options == 0 then
				warn(`[NPCService] No free node left for a {role} NPC`)
				break
			end
			local node = options[rng:NextInteger(1, #options)]
			claim(node)
			local ground = spreadAround(g.feet[node])
			local yaw = rng:NextNumber(-math.pi, math.pi)
			local outfit = OutfitDefs.random(role :: Types.Role, rng)
			local model, rootHeight = RigService.createNpcRig(outfit, CFrame.new(ground) * CFrame.Angles(0, yaw, 0))
			local npc: Npc = {
				model = model,
				root = model:FindFirstChild("HumanoidRootPart") :: BasePart,
				maxTier = maxTier,
				speed = config.WalkSpeed[role],
				rootHeight = rootHeight,
				node = node,
				ground = ground,
				yaw = yaw,
				path = nil,
				pathIndex = 1,
				idleUntil = now + rng:NextNumber(0, config.ActivitySeconds.Max),
				offset = Vector3.zero,
				placed = nil,
				placedYaw = yaw,
			}
			place(npc)
			table.insert(npcs, npc)
		end
	end
end

function NPCService.Init() end

function NPCService.Start()
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
	graph = NavGraph.build(nodes, ZoneService.tierAt)
	print(
		string.format(
			"[NPCService] Graph: %d nodes, %d links in %.1f s",
			#nodes,
			(graph :: NavGraph.Graph).linkCount,
			os.clock() - started
		)
	)

	spawnAll(#nodes)
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
