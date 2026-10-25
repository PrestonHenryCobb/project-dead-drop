--!strict
-- The crowd (spec 5.1 to 5.5, 25.4).
--
-- NPCs are Humanoid-free rigs from RigService. The server owns where they are: at GameConfig.NPC.ServerTickHz it
-- moves each anchored root along a precomputed route; clients interpolate between those updates and animate the
-- rig themselves (NPCController). Nothing on an NPC model marks it as an NPC beyond what the rig itself is.
--
-- Each NPC walks from node to node of the NavGraph, only through zones its role is allowed in. At a node it does
-- the node's activity for GameConfig.NPC.ActivitySeconds, then picks another. Doors open as NPCs approach them
-- (DoorService), and NPCs react to gunfire, explosions and bodies (Reactions). At 0 HP an NPC goes down, bleeds out and
-- is replaced (Death).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local Weighted = require(Shared:WaitForChild("Util"):WaitForChild("Weighted"))
local NPC = script.Parent.Parent:WaitForChild("NPC")
local AnimationSync = require(NPC:WaitForChild("AnimationSync"))
local Death = require(NPC:WaitForChild("Death"))
local Movement = require(NPC:WaitForChild("Movement"))
local NavGraph = require(NPC:WaitForChild("NavGraph"))
local NpcTypes = require(NPC:WaitForChild("NpcTypes"))
local Reactions = require(NPC:WaitForChild("Reactions"))
local CoverService = require(script.Parent.CoverService)
local DisguiseService = require(script.Parent.DisguiseService)
local DoorService = require(script.Parent.DoorService)
local RigService = require(script.Parent.RigService)
local ZoneService = require(script.Parent.ZoneService)

type Npc = NpcTypes.Npc

local NPCService = {}

local config = GameConfig.NPC
local rng = Random.new()
local npcs: { Npc } = {}
local claims: { [number]: number } = {} -- node -> NPCs standing at or heading to it (up to NodeCapacity)
local crowd: NpcTypes.Crowd? = nil
local spawnReplacement: ((string, Vector3) -> ())? = nil -- set in Start, once the graph exists

-- What Death needs to finish an NPC's life: ask for its replacement, and forget it once its body is gone.
local hooks: NpcTypes.Hooks = {
	replace = function(role, bodyPosition)
		if spawnReplacement then
			spawnReplacement(role, bodyPosition)
		end
	end,
	remove = function(npc)
		local index = table.find(npcs, npc)
		if index then
			table.remove(npcs, index)
		end
	end,
}

local function claim(node: number)
	claims[node] = (claims[node] or 0) + 1
end

local function release(node: number)
	claims[node] = math.max(0, (claims[node] or 0) - 1)
end

local function isFree(node: number): boolean
	return (claims[node] or 0) < config.NodeCapacity
end

local function activitySeconds(): number
	return rng:NextNumber(config.ActivitySeconds.Min, config.ActivitySeconds.Max)
end

-- Somewhere near the node's ground point, so NPCs sharing an area don't stand on one spot. The spot must be reachable
-- in a straight line, on the floor and within the role's tier (R1-ground, R2-tiers); otherwise the node itself.
local function spreadAround(graph: NavGraph.Graph, point: Vector3, maxTier: number): Vector3
	for _ = 1, config.ArrivalSpreadTries do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local radius = rng:NextNumber(0, config.ArrivalSpread)
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

-- How much a role likes a node, by the node's tier (GameConfig.NPC.RoleTierWeights).
local function tierWeight(role: string, graph: NavGraph.Graph): (number) -> number
	local weights = (config.RoleTierWeights :: { [string]: { [number]: number } })[role]
	return function(node: number): number
		return weights[graph.tiers[node]] or 0
	end
end

local function startTrip(npc: Npc, now: number, graph: NavGraph.Graph)
	local destination, points =
		NavGraph.route(graph, npc.node, npc.maxTier, config.MinTripStuds, isFree, rng, tierWeight(npc.role, graph))
	if not destination or not points then
		npc.idleUntil = now + config.ActivitySeconds.Min
		return
	end
	release(npc.node)
	claim(destination)
	npc.node = destination
	table.insert(points, spreadAround(graph, points[#points], npc.maxTier))
	npc.path = Movement.withResume(npc, points)
	npc.pathIndex = 1
	npc.speed = npc.baseSpeed
	npc.state = "Walk"
	AnimationSync.set(npc, "")
end

-- Arrived at a node: do its activity (spec 5.3). A Walk node is only a waypoint, so the NPC walks straight on.
local function beginActivity(npc: Npc, now: number, graph: NavGraph.Graph)
	npc.state = "Idle"
	npc.speed = npc.baseSpeed
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

local function update(npc: Npc, dt: number, now: number, graph: NavGraph.Graph)
	local state = npc.state
	if state == "Downed" or state == "Eliminated" then
		Death.update(npc, dt, now, hooks)
	elseif state == "Cower" or state == "Gasp" then
		Reactions.update(crowd :: NpcTypes.Crowd, npc, now)
	elseif state == "Idle" then
		if now >= npc.idleUntil then
			startTrip(npc, now, graph)
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
			elseif npc.state ~= "Investigate" then
				beginActivity(npc, now, graph)
			end
		end
	end
end

-- Builds an NPC of a role standing at a node.
local function createNpc(role: Types.Role, node: number, graph: NavGraph.Graph, now: number): Npc
	local maxTier = config.RoleMaxTier[role]
	claim(node)
	local ground = spreadAround(graph, graph.feet[node], maxTier)
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
		placed = nil,
		placedYaw = yaw,
		animation = "",
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
	for node = 1, #graph.feet do
		if graph.tiers[node] <= maxTier and isFree(node) and #graph.edges[node] > 0 then
			table.insert(options, node)
		end
	end
	return options
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
			createNpc(role :: Types.Role, node, graph, now)
		end
	end
end

-- A replacement of the same role at a free node far from where the last one went down (spec 5.5).
local function replaceNpc(graph: NavGraph.Graph, role: string, bodyPosition: Vector3)
	local options = freeNodes(graph, config.RoleMaxTier[role])
	local far: { number } = {}
	for _, node in options do
		if (graph.feet[node] - bodyPosition).Magnitude >= config.Death.ReplacementMinStuds then
			table.insert(far, node)
		end
	end
	if #far == 0 then
		far = options
	end
	local node = Weighted.pick(far, tierWeight(role, graph), rng)
	if not node then
		warn(`[NPCService] No free node for a replacement {role}`)
		return
	end
	createNpc(role :: Types.Role, node, graph, os.clock())
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

local tickTotal, tickMax, tickCount, reportAt = 0, 0, 0, 0
local resyncAt = 0

local function tick(dt: number)
	local current = crowd :: NpcTypes.Crowd
	debug.profilebegin("NPCService.tick")
	local started = os.clock()
	for _, npc in npcs do
		update(npc, dt, started, current.graph)
	end
	refreshWitnesses()
	Reactions.watchBodies(current, started)
	Movement.separate(npcs, dt, rng)
	for _, npc in npcs do
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
	local graph = NavGraph.build(nodes, ZoneService.tierAt)
	print(
		string.format("[NPCService] Graph: %d nodes, %d links in %.1f s", #nodes, graph.linkCount, os.clock() - started)
	)

	crowd = { npcs = npcs, graph = graph, rng = rng, claim = claim, release = release }
	spawnReplacement = function(role, bodyPosition)
		replaceNpc(graph, role, bodyPosition)
	end
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
