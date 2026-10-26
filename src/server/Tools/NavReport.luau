--!strict
-- A development check for the map (BUILD_ORDER Step 7B): loads the NPC graph exactly as NPCService does, then reports
-- what NPCs could never walk to. Run it in a playtest from a game Script (it needs ZoneService); see the build-map skill:
--
--     print(require(game.ServerScriptService.Server.Tools.NavReport).run())
--
-- For each role's limit (Tier 0 for Guests up to Tier 3) it lists the rooms holding nodes cut off from the largest
-- connected group, and it lists any stair whose two ends failed to link.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Enums"))
local NavGraph = require(script.Parent.Parent.NPC.NavGraph)
local ZoneService = require(script.Parent.Parent.Services.ZoneService)

local NavReport = {}

local BODY_HEIGHT = Vector3.new(0, 2, 0) -- zones are sampled at body height, as NPCs pass through them

-- The room a point is in: the name of the highest-tier zone volume holding it.
local function roomAt(zones: { Instance }, point: Vector3): string
	local best, bestTier = "?", -1
	for _, zone in zones do
		if zone:IsA("BasePart") then
			local localPoint = zone.CFrame:PointToObjectSpace(point)
			local half = zone.Size / 2
			if
				math.abs(localPoint.X) <= half.X
				and math.abs(localPoint.Y) <= half.Y
				and math.abs(localPoint.Z) <= half.Z
			then
				local tier = (zone:GetAttribute("Tier") :: number?) or 0
				if tier > bestTier then
					best, bestTier = (zone.Name:gsub("^Zone_", "")), tier
				end
			end
		end
	end
	return best
end

function NavReport.run(): string
	local nodes: { BasePart } = {}
	for _, node in CollectionService:GetTagged(Enums.Tag.NPCNode) do
		if node:IsA("BasePart") then
			table.insert(nodes, node)
		end
	end
	local graph = NavGraph.load(nodes, ZoneService.tierAt)
	local zones = CollectionService:GetTagged(Enums.Tag.ZoneVolume)
	local lines = { `nodes {#nodes}, links {graph.linkCount}` }

	-- Stairs whose two ends did not link.
	local ends: { [string]: { number } } = {}
	for index, node in nodes do
		local stairLink = node:GetAttribute("StairLink")
		if type(stairLink) == "string" then
			ends[stairLink] = ends[stairLink] or {}
			table.insert(ends[stairLink], index)
		end
	end
	local broken: { string } = {}
	for stairLink, pair in ends do
		local linked = false
		for _, edge in graph.edges[pair[1]] do
			if edge.to == pair[2] then
				linked = true
			end
		end
		if not linked then
			table.insert(broken, `{stairLink} in {roomAt(zones, graph.feet[pair[1]] + BODY_HEIGHT)}`)
		end
	end
	table.sort(broken)
	table.insert(lines, `stairs not linked: {if #broken == 0 then "none" else table.concat(broken, ", ")}`)

	-- For each tier limit: the connected groups of nodes a role with that limit may use.
	for maxTier = 0, 3 do
		local allowed: { [number]: boolean } = {}
		local total = 0
		for index = 1, #nodes do
			if graph.tiers[index] <= maxTier then
				allowed[index] = true
				total += 1
			end
		end
		local group: { [number]: number } = {}
		local sizes: { number } = {}
		for start in allowed do
			if not group[start] then
				table.insert(sizes, 0)
				local id = #sizes
				group[start] = id
				local stack = { start }
				while #stack > 0 do
					local at = table.remove(stack) :: number
					sizes[id] += 1
					for _, edge in graph.edges[at] do
						if allowed[edge.to] and edge.maxTier <= maxTier and not group[edge.to] then
							group[edge.to] = id
							table.insert(stack, edge.to)
						end
					end
				end
			end
		end
		local main, mainSize = 0, 0
		for id, size in sizes do
			if size > mainSize then
				main, mainSize = id, size
			end
		end
		local stranded: { [string]: number } = {}
		for index in allowed do
			if group[index] ~= main then
				local room = roomAt(zones, graph.feet[index] + BODY_HEIGHT)
				stranded[room] = (stranded[room] or 0) + 1
			end
		end
		local parts: { string } = {}
		for room, count in stranded do
			table.insert(parts, `{room} x{count}`)
		end
		table.sort(parts)
		table.insert(
			lines,
			`tier <= {maxTier}: {total} nodes, {mainSize} connected, {#sizes} groups; cut off: {if #parts == 0
				then "none"
				else table.concat(parts, "; ")}`
		)
	end
	return table.concat(lines, "\n")
end

return NavReport
