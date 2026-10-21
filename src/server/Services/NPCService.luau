--!strict
-- The crowd (spec 5.1 to 5.5, 25.4).
--
-- NPCs are Humanoid-free rigs from RigService. The server owns where they are: at GameConfig.NPC.ServerTickHz it
-- moves each anchored root along a precomputed route; clients interpolate between those updates and animate the
-- rig themselves (NPCController). Nothing on an NPC model marks it as an NPC beyond what the rig itself is.
--
-- Each NPC walks from node to node of the NavGraph, only through zones its role is allowed in. At a node it does
-- the node's activity for GameConfig.NPC.ActivitySeconds, then picks another. Doors open as NPCs approach them
-- (DoorService), and NPCs react to gunfire, explosions and bodies (Reactions) and can die and be replaced (Death).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local OutfitDefs = require(Shared:WaitForChild("Defs"):WaitForChild("OutfitDefs"))
local Types = require(Shared:WaitForChild("Types"))
local NPC = script.Parent.Parent:WaitForChild("NPC")
local AnimationSync = require(NPC:WaitForChild("AnimationSync"))
local Death = require(NPC:WaitForChild("Death"))
local Movement = require(NPC:WaitForChild("Movement"))
local NavGraph = require(NPC:WaitForChild("NavGraph"))
local NpcTypes = require(NPC:WaitForChild("NpcTypes"))
local Reactions = require(NPC:WaitForChild("Reactions"))
local DoorService = require(script.Parent.DoorService)
local RigService = require(script.Parent.RigService)
local ZoneService = require(script.Parent.ZoneService)

type Npc = NpcTypes.Npc

local NPCService = {}

local config = GameConfig.NPC
local rng = Random.new()
local npcs: { Npc } = {}
local claims: { [number]: number } = {} -- node -> NPCs standing at or heading to it
local crowd: NpcTypes.Crowd? = nil

local function claim(node: number)
	claims[node] = (claims[node] or 0) + 1
end

local function release(node: number)
	claims[node] = math.max(0, (claims[node] or 0) - 1)
end

local function isFree(node: number): boolean
	return (claims[node] or 0) == 0
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

local function startTrip(npc: Npc, now: number, graph: NavGraph.Graph)
	local destination, points = NavGraph.route(graph, npc.node, npc.maxTier, config.MinTripStuds, isFree, rng)
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
	if state == "Dead" then
		return
	elseif state == "Cower" or state == "Gasp" then
		Reactions.update(crowd :: NpcTypes.Crowd, npc, now)
	elseif state == "Idle" then
		if now >= npc.idleUntil then
			startTrip(npc, now, graph)
		end
	else
		if state == "Flee" then
			Reactions.update(crowd :: NpcTypes.Crowd, npc, now)
		end
		if Movement.follow(npc, dt) then
			if state == "BackAway" then
				npc.state = "Idle"
				npc.idleUntil = now
			else
				beginActivity(npc, now, graph)
			end
		end
	end
end
