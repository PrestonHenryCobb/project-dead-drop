--!strict
-- GPS routes (docs/GPS_DESIGN.md, owner answers 2026-10-28). The client asks RequestRoute(targetId?) about once a second while a
-- route shows; the server answers with the targets the match has revealed to that player and two routes to the selected one:
--
--   * Clean: the shortest path the current disguise's clearance may walk (no tier door it cannot open, no zone above it) and
--     nothing that breaks Cover. It changes when the disguise does.
--   * Fast: the shortest path overall. It may hack a tier door (its intel price counts as Route.HackStudsPerIntel studs of
--     walking and is reported), cross a zone above the clearance ("Restricted"), and use vents, ziplines, the gondola and the
--     service ladders, each flagged as a Cover-breaking step.
--
-- The searches run over the NPC lane graph (NPC/NavGraph, read again from the map here; PathfindingService is never used),
-- plus a few extra nodes where a vent, zipline, the gondola or a ladder starts and ends, each joined to the nearest lane node.
-- A vent is hidden: the route may enter a grate only after the player has come within Route.SeenStuds of it in sight, and it
-- leads only to that grate's partner. Secret exits are not built yet, so no route uses them. The Sanctum elevator is left
-- out while it is locked.
--
-- Targets (only what the match has revealed): the open vault terminals during the Vault Breach, the extraction site once it has
-- been called, and living or downed teammates. The Package and its carrier are never targets (owner decision).
--
-- The answer carries positions, never identities: a route to a teammate says only where they are, which the team's roster and
-- markers already show.
-- Owner follow-up 2026-11-22: room-exit anchors, movement-biased exit costs and automatic nearest revealed objectives.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))
local NavGraph = require(script.Parent.Parent.NPC.NavGraph)
local DisguiseService = require(script.Parent.DisguiseService)
local DownedService = require(script.Parent.DownedService)
local ElevatorService = require(script.Parent.ElevatorService)
local ExtractionService = require(script.Parent.ExtractionService)
local IntelService = require(script.Parent.IntelService)
local MatchService = require(script.Parent.MatchService)
local RemoteService = require(script.Parent.RemoteService)
local TeamService = require(script.Parent.TeamService)
local VaultService = require(script.Parent.VaultService)
local ZoneService = require(script.Parent.ZoneService)

-- One way to get from one node to another. mode: "Graph" (a lane link), "Join" (a traversal end to its lane node) or a
-- traversal: "Vent", "Zipline", "Gondola", "Ladder".
type Link = {
	to: number,
	length: number,
	points: { Vector3 },
	mode: string,
	kind: string, -- a lane link's kind: "Walk", "Door", "Stair" or "Elevator"
	maxTier: number,
	shaft: string?,
	grate: BasePart?, -- the grate a vent link is entered at
}

type Flag = { Kind: string, Detail: string?, Intel: number?, CoverBreak: boolean }

type Target = { Id: string, Name: string, Kind: string, Position: Vector3 }

local RouteService = {}

local config = GameConfig.Route
local feet: { Vector3 } = {}
local adjacent: { { Link } } = {}
local laneTiers: { number } = {}
local laneRooms: { string } = {}
local roomVolumes: { BasePart } = {}
type Guide = { Room: string?, Direction: Vector3, MovedAt: number }
local guides: { [Player]: Guide } = {}
local laneCount = 0
local grates: { BasePart } = {}
local seen: { [Player]: { [BasePart]: boolean } } = {}

local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

-- A binary min-heap on two parallel arrays.
local function heapPush(nodes: { number }, keys: { number }, node: number, key: number)
	table.insert(nodes, node)
	table.insert(keys, key)
	local index = #nodes
	while index > 1 do
		local parent = index // 2
		if keys[parent] <= keys[index] then
			break
		end
		nodes[parent], nodes[index] = nodes[index], nodes[parent]
		keys[parent], keys[index] = keys[index], keys[parent]
		index = parent
	end
end

local function heapPop(nodes: { number }, keys: { number }): (number, number)
	local topNode, topKey = nodes[1], keys[1]
	local lastNode, lastKey = table.remove(nodes) :: number, table.remove(keys) :: number
	local size = #nodes
	if size > 0 then
		nodes[1], keys[1] = lastNode, lastKey
		local index = 1
		while true do
			local left, right = index * 2, index * 2 + 1
			local smallest = index
			if left <= size and keys[left] < keys[smallest] then
				smallest = left
			end
			if right <= size and keys[right] < keys[smallest] then
				smallest = right
			end
			if smallest == index then
				break
			end
			nodes[smallest], nodes[index] = nodes[index], nodes[smallest]
			keys[smallest], keys[index] = keys[index], keys[smallest]
			index = smallest
		end
	end
	return topNode, topKey
end

local function addNode(position: Vector3): number
	table.insert(feet, position)
	table.insert(adjacent, {})
	return #feet
end

local function addLink(from: number, link: Link)
	table.insert(adjacent[from], link)
end

-- The lane node nearest a position, counting a storey of height FloorWeight times, within `limit`.
local function nearestLane(position: Vector3, limit: number): number?
	local best: number? = nil
	local bestDistance = limit
	for index = 1, laneCount do
		local offset = feet[index] - position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude + math.abs(offset.Y) * config.FloorWeight
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

local function contains(volume: BasePart, position: Vector3): boolean
	local point = volume.CFrame:PointToObjectSpace(position)
	local half = volume.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

-- Resolve the actual room volume before snapping to its graph, so a nearby lane behind a wall is not chosen.
-- Prefer the previous room in padded doorway overlaps; switch once the player leaves its volume.
local function roomAt(position: Vector3, previous: string?): string?
	local room: string? = nil
	local smallest = math.huge
	for _, volume in roomVolumes do
		if not volume:IsDescendantOf(workspace) or not contains(volume, position) then
			continue
		end
		local name = string.match(volume.Name, "^Zone_.-_T%d+_(.+)$")
		if name == previous and previous ~= nil then
			return previous
		end
		local area = volume.Size.X * volume.Size.Z
		if name and area < smallest then
			room, smallest = name, area
		end
	end
	return room
end

local function inRoom(node: number, room: string?, height: number): boolean
	return room ~= nil and laneRooms[node] == room and math.abs(feet[node].Y - height) <= config.ConnectFloorStuds
end

local function roomStart(position: Vector3, room: string?): number?
	local best: number? = nil
	local bestDistance = math.huge
	local closest: number? = nil
	local closestDistance = math.huge
	for index = 1, laneCount do
		if not inRoom(index, room, position.Y) then
			continue
		end
		local delta = feet[index] - position
		local distance = Vector3.new(delta.X, 0, delta.Z).Magnitude
		if distance < closestDistance then
			closest, closestDistance = index, distance
		end
		if distance < bestDistance then
			local chest = Vector3.yAxis * config.JoinChestStuds
			if workspace:Raycast(position + chest, feet[index] + chest - (position + chest), mapParams) == nil then
				best, bestDistance = index, distance
			end
		end
	end
	-- In an authored room, never snap through its wall to a different room as a fallback.
	return if room then best or closest else nearestLane(position, config.NodeSnapStuds)
end

-- A new node where a traversal starts or ends, walkable to the nearest lane node within ConnectStuds that has a clear line to it
-- at chest height (so a join never goes through a wall). Nil if none does.
local function joinNode(position: Vector3): number?
	local candidates: { { index: number, distance: number } } = {}
	for index = 1, laneCount do
		local offset = feet[index] - position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if flat <= config.ConnectStuds and math.abs(offset.Y) <= config.ConnectFloorStuds then
			table.insert(candidates, { index = index, distance = flat })
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	local best: number? = nil
	local chest = Vector3.new(0, config.JoinChestStuds, 0)
	for _, candidate in candidates do
		local from = position + chest
		local to = feet[candidate.index] + chest
		if workspace:Raycast(from, to - from, mapParams) == nil then
			best = candidate.index
			break
		end
	end
	if not best then
		return nil
	end
	local node = addNode(position)
	laneRooms[node] = laneRooms[best]
	local length = (feet[best] - position).Magnitude
	addLink(node, {
		to = best,
		length = length,
		points = { position, feet[best] },
		mode = "Join",
		kind = "Walk",
		maxTier = 0,
	})
	addLink(best, {
		to = node,
		length = length,
		points = { feet[best], position },
		mode = "Join",
		kind = "Walk",
		maxTier = 0,
	})
	return node
end

local function addTraversal(from: number, to: number, mode: string, start: Vector3, finish: Vector3, grate: BasePart?)
	addLink(from, {
		to = to,
		length = (finish - start).Magnitude,
		points = { start, finish },
		mode = mode,
		kind = "Walk",
		maxTier = 0,
		grate = grate,
	})
end

local function build()
	for _, instance in CollectionService:GetTagged(Enums.Tag.ZoneVolume) do
		if instance:IsA("BasePart") then
			table.insert(roomVolumes, instance)
		end
	end
	local nodes: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.NPCNode) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			table.insert(nodes, instance)
		end
	end
	if #nodes == 0 then
		warn("[RouteService] No NPCNode parts in the map; no routes")
		return
	end
	local graph = NavGraph.load(nodes, ZoneService.tierAt)
	laneCount = #graph.feet
	for index = 1, laneCount do
		table.insert(feet, graph.feet[index])
		table.insert(adjacent, {})
		table.insert(laneTiers, graph.tiers[index])
		laneRooms[index] = graph.rooms[index]
	end
	for index = 1, laneCount do
		for _, edge in graph.edges[index] do
			addLink(index, {
				to = edge.to,
				length = edge.length,
				points = edge.points,
				mode = "Graph",
				kind = edge.kind,
				maxTier = edge.maxTier,
				shaft = if edge.ride then edge.ride.shaft else nil,
			})
		end
	end

	local added = { Vent = 0, Zipline = 0, Gondola = 0, Ladder = 0 }
	local skipped = { Vent = 0, Zipline = 0, Gondola = 0, Ladder = 0 }
	local function pair(mode: string, a: Vector3, b: Vector3, oneWay: boolean, grateA: BasePart?, grateB: BasePart?)
		local nodeA, nodeB = joinNode(a), joinNode(b)
		if not (nodeA and nodeB) then
			skipped[mode] += 1
			return
		end
		added[mode] += 1
		addTraversal(nodeA, nodeB, mode, a, b, grateA)
		if not oneWay then
			addTraversal(nodeB, nodeA, mode, b, a, grateB)
		end
	end

	-- Vents: two grates share a VentId.
	local byVent: { [string]: { BasePart } } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.Vent) do
		if instance:IsA("BasePart") then
			local id = tostring(instance:GetAttribute("VentId"))
			byVent[id] = byVent[id] or {}
			table.insert(byVent[id], instance)
			table.insert(grates, instance)
		end
	end
	for _, list in byVent do
		if #list == 2 then
			pair("Vent", list[1].Position, list[2].Position, false, list[1], list[2])
		end
	end

	-- Ziplines: down from the Top anchor to the Bottom one. A rider mounts at the mast's foot.
	local byLine: { [string]: { Top: BasePart?, Bottom: BasePart? } } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.ZiplineAnchor) do
		if instance:IsA("BasePart") then
			local id = tostring(instance:GetAttribute("ZiplineId"))
			byLine[id] = byLine[id] or {}
			local ends = byLine[id]
			if instance:GetAttribute("End") == "Top" then
				ends.Top = instance
			else
				ends.Bottom = instance
			end
		end
	end
	for _, ends in byLine do
		if ends.Top and ends.Bottom then
			local function foot(anchor: BasePart): Vector3
				return anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0)
			end
			pair("Zipline", foot(ends.Top), foot(ends.Bottom), true, nil, nil)
		end
	end

	-- The gondola: between its two call buttons.
	local buttons: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Enums.Tag.GondolaCall) do
		if instance:IsA("BasePart") then
			table.insert(buttons, instance)
		end
	end
	if #buttons == 2 then
		pair("Gondola", buttons[1].Position, buttons[2].Position, false, nil, nil)
	end

	-- Service ladders: the foot to the top, both ways.
	for _, instance in CollectionService:GetTagged(Enums.Tag.ServiceLadder) do
		if instance:IsA("BasePart") then
			local bottom = instance.Position - Vector3.new(0, instance.Size.Y / 2, 0)
			local top = instance.Position + Vector3.new(0, instance.Size.Y / 2 - 3, 0)
			pair("Ladder", bottom, top, false, nil, nil)
		end
	end
	print(
		string.format(
			"[RouteService] %d lane nodes, %d extra; vents %d (skipped %d), ziplines %d (%d), gondola %d (%d), ladders %d (%d)",
			laneCount,
			#feet - laneCount,
			added.Vent,
			skipped.Vent,
			added.Zipline,
			skipped.Zipline,
			added.Gondola,
			skipped.Gondola,
			added.Ladder,
			skipped.Ladder
		)
	)
end

-- The intel a hack of a door of this tier costs (Doors.HackCost: tiers 1 to 3; the Tier 4 doors cost their stair-head price).
local function hackIntel(tier: number): number
	local costs = GameConfig.Doors.HackCost
	return costs[tier] or costs.Tier4StairHead
end

-- What walking this link costs for this player, and the step it makes, or nil if the route may not use it.
local function evaluate(link: Link, clearance: number, fast: boolean, known: { [BasePart]: boolean }): (number?, Flag?)
	local mode = link.mode
	if mode == "Join" then
		return link.length, nil
	elseif mode == "Graph" then
		local cost = link.length
		local flag: Flag? = nil
		if link.shaft then
			if ElevatorService.isLocked(link.shaft) then
				return nil, nil
			end
			cost += GameConfig.NPC.Elevator.WaitCostStuds
			flag = { Kind = "Elevator", CoverBreak = false }
		elseif link.kind == "Stair" then
			flag = { Kind = "Stair", CoverBreak = false }
		end
		local tier = math.max(link.maxTier, laneTiers[link.to] or 0)
		if tier > clearance then
			if not fast then
				return nil, nil
			end
			if link.kind == "Door" or link.shaft then
				local intel = hackIntel(tier)
				cost += intel * config.HackStudsPerIntel
				flag = {
					Kind = "Hack",
					Detail = if link.shaft then "Elevator" else "Door",
					Intel = intel,
					CoverBreak = false,
				}
			else
				cost += config.RestrictedStuds
				flag = { Kind = "Restricted", CoverBreak = false }
			end
		end
		return cost, flag
	end
	-- Every traversal breaks Cover, so only the fast route may use one.
	if not fast then
		return nil, nil
	end
	if mode == "Vent" then
		if not (link.grate and known[link.grate]) then
			return nil, nil
		end
		return link.length * config.VentCostMult, { Kind = "Vent", CoverBreak = true }
	elseif mode == "Zipline" then
		return link.length * config.ZiplineCostMult, { Kind = "Zipline", CoverBreak = true }
	elseif mode == "Gondola" then
		return link.length + config.GondolaWaitStuds, { Kind = "Gondola", CoverBreak = true }
	end
	return link.length * config.LadderCostMult, { Kind = "Ladder", CoverBreak = true }
end

-- Dijkstra from one node over every node (lane and extra). Returns the distance to each node, the link it was reached by and
-- the node before it.
local function search(
	start: number,
	clearance: number,
	fast: boolean,
	known: { [BasePart]: boolean },
	room: string?,
	origin: Vector3,
	direction: Vector3
): ({ number }, { Link? }, { number })
	local count = #feet
	local distance: { number } = table.create(count, math.huge)
	local via: { Link? } = table.create(count, false) :: any
	local from: { number } = table.create(count, 0)
	local done: { boolean } = table.create(count, false)
	local heapNodes: { number } = {}
	local heapKeys: { number } = {}
	distance[start] = 0
	heapPush(heapNodes, heapKeys, start, 0)
	while #heapNodes > 0 do
		local node, key = heapPop(heapNodes, heapKeys)
		if not done[node] and key <= distance[node] then
			done[node] = true
			for _, link in adjacent[node] do
				if not done[link.to] then
					local cost = evaluate(link, clearance, fast, known)
					-- Compare valid exits by walking cost plus a bounded heading preference. Looking at a door
					-- does not steer GPS: only actual horizontal movement does. No new links are invented.
					if
						cost
						and direction.Magnitude > 0
						and inRoom(node, room, origin.Y)
						and not inRoom(link.to, room, origin.Y)
					then
						local middle = (#link.points + 1) / 2
						local a = link.points[math.floor(middle)] or feet[node]
						local b = link.points[math.ceil(middle)] or feet[link.to]
						local exit = a:Lerp(b, middle % 1)
						local delta = Vector3.new(exit.X - origin.X, 0, exit.Z - origin.Z)
						if delta.Magnitude > GameConfig.UI.GraphicHud.DirectionEpsilonStuds then
							cost += (1 - math.clamp(direction:Dot(delta.Unit), -1, 1)) * config.ExitDirectionCostStuds / 2
						end
					end
					if cost and key + cost < distance[link.to] then
						distance[link.to] = key + cost
						via[link.to] = link
						from[link.to] = node
						heapPush(heapNodes, heapKeys, link.to, key + cost)
					end
				end
			end
		end
	end
	return distance, via, from
end

local function buildRoute(
	via: { Link? },
	from: { number },
	start: number,
	finish: number,
	room: string?,
	destination: Vector3,
	clearance: number,
	fast: boolean,
	known: { [BasePart]: boolean },
	balance: number
): Types.RouteInfo
	local chain: { Link } = {}
	local sources: { number } = {}
	local node = finish
	while node ~= start do
		table.insert(chain, 1, via[node] :: Link)
		table.insert(sources, 1, from[node])
		node = from[node]
	end
	-- Omit the approach across the current room; the visible guide begins at its exit approach.
	-- Targets within this room still use the room's authored lane anchor, never a player-root tether.
	local first = 1
	for index, link in chain do
		local _, flag = evaluate(link, clearance, fast, known)
		-- Never trim away a required action or warning even if both endpoints share a room name.
		if flag or (inRoom(sources[index], room, feet[start].Y) and not inRoom(link.to, room, feet[start].Y)) then
			first = index
			break
		end
	end
	local points: { Vector3 } = { feet[sources[first] or start] }
	local steps: { Types.RouteStepInfo } = {}
	local intel, breaks = 0, 0
	for linkIndex, link in chain do
		local _, flag = evaluate(link, clearance, fast, known)
		if flag then
			table.insert(steps, {
				Index = #points,
				Kind = flag.Kind,
				Detail = flag.Detail,
				Intel = flag.Intel,
				CoverBreak = flag.CoverBreak,
			})
			intel += flag.Intel or 0
			breaks += if flag.CoverBreak then 1 else 0
		end
		if linkIndex >= first then
			for _, point in link.points do
				if point ~= points[#points] then
					table.insert(points, point)
				end
			end
		end
	end
	-- Markers can sit above the floor. Keep the ribbon on the destination lane's floor instead of ramping into the marker.
	table.insert(points, Vector3.new(destination.X, feet[finish].Y, destination.Z))
	local length = 0
	for index = 2, #points do
		length += (points[index] - points[index - 1]).Magnitude
	end
	return {
		Points = points,
		Length = length,
		HackIntel = intel,
		CoverBreaks = breaks,
		Affordable = balance >= intel,
		Steps = steps,
	}
end

local function rootOf(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- What the match has revealed to this player as somewhere to go.
local function targetsFor(player: Player): { Target }
	local list: { Target } = {}
	if MatchService.phase() == "VaultBreach" then
		for _, position in VaultService.openTerminals() do
			table.insert(list, {
				Id = string.format("Terminal@%d,%d", position.X, position.Z),
				Name = "Vault terminal",
				Kind = "Terminal",
				Position = position,
			})
		end
	end
	local state, siteId = ExtractionService.state()
	if siteId and (state == "Countdown" or state == "Hover" or state == "Open") then
		for _, site in ExtractionService.sites() do
			if site.id == siteId then
				table.insert(list, { Id = "Extraction", Name = "Extraction", Kind = "Extraction", Position = site.pad })
			end
		end
	end
	local teamId = TeamService.teamOf(player)
	if teamId then
		for _, mate in TeamService.members(teamId) do
			local root = rootOf(mate)
			if mate ~= player and root and (DownedService.isDowned(mate) or not DownedService.isOut(mate)) then
				table.insert(list, {
					Id = `Mate:{mate.UserId}`,
					Name = mate.DisplayName,
					Kind = "Teammate",
					Position = root.Position,
				})
			end
		end
	end
	return list
end

local function targetNode(target: Target): number?
	return roomStart(target.Position, roomAt(target.Position, nil))
end

local function answer(player: Player, requested: unknown): any
	if
		(requested ~= nil and type(requested) ~= "string")
		or (type(requested) == "string" and #requested > GameConfig.Network.MaxIdLength)
	then
		return false, "BadTarget"
	end
	local root = rootOf(player)
	local teamId = TeamService.teamOf(player)
	if not root or not teamId or not MatchService.isInMatch() or DownedService.isOut(player) then
		return false, "NotPlaying"
	end
	local balance = IntelService.balance(teamId)
	local targets = targetsFor(player)
	local result: Types.RouteResult = { Targets = {}, Selected = nil, Clean = nil, Fast = nil, Intel = balance }
	local chosen: Target? = nil
	for _, target in targets do
		table.insert(result.Targets, { Id = target.Id, Name = target.Name, Kind = target.Kind })
		if target.Id == requested then
			chosen = target
		end
	end
	if #targets == 0 or #feet == 0 then
		return result
	end
	local origin = root.Position - Vector3.new(0, config.FootStuds, 0)
	local guide: Guide = guides[player] or { Room = nil, Direction = Vector3.zero, MovedAt = 0 }
	guide.Room = roomAt(root.Position, guide.Room)
	local velocity = root.AssemblyLinearVelocity
	local movement = Vector3.new(velocity.X, 0, velocity.Z)
	if movement.Magnitude >= config.DirectionMinSpeed then
		guide.Direction, guide.MovedAt = movement.Unit, os.clock()
	elseif os.clock() - guide.MovedAt > config.DirectionHoldSeconds then
		guide.Direction = Vector3.zero
	end
	guides[player] = guide
	local start = roomStart(origin, guide.Room)
	if not start then
		return result
	end
	local clearance = DisguiseService.getClearance(player)
	local known = seen[player] or {}
	-- Both all-node searches are shared by automatic target selection and route reconstruction.
	-- Keep objective priority over teammates; choose the closest reachable objective rather than list order.
	local cleanDistance, cleanVia, cleanFrom =
		search(start, clearance, false, known, guide.Room, origin, guide.Direction)
	local fastDistance, fastVia, fastFrom = search(start, clearance, true, known, guide.Room, origin, guide.Direction)
	if not chosen then
		local kind = targets[1].Kind
		local bestCost = math.huge
		local bestClean = false
		for _, target in targets do
			if target.Kind ~= kind then
				continue
			end
			local node = targetNode(target)
			if not node then
				continue
			end
			local clean = cleanDistance[node] < math.huge
			local cost = (if clean then cleanDistance[node] else fastDistance[node])
				+ (feet[node] - target.Position).Magnitude
			if (clean and not bestClean) or (clean == bestClean and cost < bestCost) then
				chosen, bestCost, bestClean = target, cost, clean
			end
		end
	end
	chosen = chosen or targets[1]
	result.Selected = chosen.Id
	local finish = targetNode(chosen)
	if not finish then
		return result
	end
	for _, fast in { false, true } do
		local distance = if fast then fastDistance else cleanDistance
		local via = if fast then fastVia else cleanVia
		local from = if fast then fastFrom else cleanFrom
		if distance[finish] < math.huge then
			local route =
				buildRoute(via, from, start, finish, guide.Room, chosen.Position, clearance, fast, known, balance)
			if fast then
				result.Fast = route
			else
				result.Clean = route
			end
		end
	end
	return result
end

-- A vent grate is seen once the player has come within SeenStuds of it with a clear line.
local function look()
	if #grates == 0 or not MatchService.isInMatch() then
		return
	end
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root then
			local known = seen[player] or {}
			seen[player] = known
			local eye = root.Position + Vector3.new(0, 1.5, 0)
			for _, grate in grates do
				if not known[grate] and (grate.Position - eye).Magnitude <= config.SeenStuds then
					local hit = workspace:Raycast(eye, grate.Position - eye, mapParams)
					if hit == nil or hit.Instance == grate or hit.Instance.Parent == grate.Parent then
						known[grate] = true
					end
				end
			end
		end
	end
end

function RouteService.Init() end

function RouteService.Start()
	build()
	RemoteService.onInvoke("RequestRoute", answer)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 / config.SeenHz then
			elapsed = 0
			look()
		end
	end)
	MatchService.onPhaseChanged(function(phase)
		if phase == "Insertion" then
			table.clear(seen)
		end
		if phase == "Lobby" or phase == "Insertion" then
			table.clear(guides)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		seen[player] = nil
		guides[player] = nil
	end)
end

return RouteService
