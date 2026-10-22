--!strict
-- Builds "The Gala" graybox from Layout.luau into Workspace.Gala (BUILD_ORDER Step 7B).
--
-- How to run: in Studio (Edit mode, Rojo connected so ServerScriptService.Server.Tools.Gala and ReplicatedStorage.Shared exist),
-- run in the command bar or through the MCP tools:
--     require(game.ServerScriptService.Server.Tools.Gala.Build).run()
-- Running it again deletes and rebuilds Workspace.Gala. The result of every rule it can check is printed with [Gala].
--
-- What it makes, from rooms, voids, ramps and doors:
--   * floors and ceilings, walls with doorways, railings round drops and terraces, ramps with railed openings
--   * a ZoneVolume per room piece, clearance doors and keycard doors, and the tagged objects NPCs and spawns use
--   * cover and furniture blocks per room theme, and NPC nodes on a grid that keeps clear of all of it
-- Still to come in later passes: intel stations, supply caches, cameras, laser grids, vents, ziplines, pickups and the
-- vault interiors. Their counts are not checked here yet.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(script.Parent.Layout)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tag = Enums.Tag

type Rect = { x1: number, z1: number, x2: number, z2: number }
type Room = Layout.Room
type Piece = { room: Room, rect: Rect, index: number }
type Gap = { center: number, width: number, door: Layout.Door }
type Edge = {
	level: string,
	axis: string, -- "x": runs along x at z = line; "z": runs along z at x = line
	line: number,
	a: number,
	b: number,
	roomA: Room,
	roomB: Room?,
	kind: string, -- "shared", "free" or "void"
	gaps: { Gap },
}

-- Sizes in studs ------------------------------------------------------------------------------------------------------
local WALL_H = 22
local WALL_T = 2
local RAIL_H = 4
local GAP_H = 10 -- doorway height
local SLAB = 2
local RAMP_W, RAMP_RUN, RAMP_RISE = 6, 48, 24
-- A switchback climbs half the height in each of two legs, side by side with a gap, joined by a landing.
local LEG_RUN, LEG_RISE, LANDING, LANE_GAP = RAMP_RUN / 2, RAMP_RISE / 2, 6, 2
local ZONE_PAD = 2
local GREY = Color3.fromRGB(150, 150, 150)
local RAIL_GREY = Color3.fromRGB(175, 175, 178)
local EPS = 1e-4

local NODE_MARGIN = 8 -- studs a node keeps from a room's walls
local NODE_SPACING = { [0] = 70, [1] = 50, [2] = 55, [3] = 60 }
local NODE_CAP = 320 -- see GameConfig.Map.NPCNodeCount
local LIGHT_SPACING = 55 -- studs between ceiling lights in a room
local LIGHT_CAP = 110 -- the most lights in the map (each is a dynamic light on a phone)
local DOOR_CLEAR = 7 -- studs props keep clear in front of a doorway
local NODE_PROP_CLEAR = 3 -- studs a node keeps from a prop

local ACTIVITIES: { [number]: { string } } = {
	[0] = { "Walk", "Walk", "Idle", "Talk", "Sit", "Lean", "Drink" },
	[1] = { "Walk", "Work", "Work", "Idle", "Talk", "Drink" },
	[2] = { "Guard", "Guard", "Walk", "Idle" },
	[3] = { "Walk", "Idle", "Talk", "Drink", "Sit" },
}
local OUTDOOR_ACTIVITIES = { "Walk", "Walk", "Idle", "Talk", "Drink" }

local Build = {}

local function toRect(r: { number }): Rect
	return { x1 = r[1], z1 = r[2], x2 = r[3], z2 = r[4] }
end

local function overlaps(p: Rect, q: Rect): boolean
	return p.x1 < q.x2 - EPS and q.x1 < p.x2 - EPS and p.z1 < q.z2 - EPS and q.z1 < p.z2 - EPS
end

local function inflate(r: Rect, amount: number): Rect
	return { x1 = r.x1 - amount, z1 = r.z1 - amount, x2 = r.x2 + amount, z2 = r.z2 + amount }
end

-- The parts of every rect in `rects` that are not inside `hole`.
local function subtract(rects: { Rect }, hole: Rect): { Rect }
	local out: { Rect } = {}
	for _, r in rects do
		if not overlaps(r, hole) then
			table.insert(out, r)
		else
			if hole.x1 > r.x1 + EPS then
				table.insert(out, { x1 = r.x1, z1 = r.z1, x2 = hole.x1, z2 = r.z2 })
			end
			if hole.x2 < r.x2 - EPS then
				table.insert(out, { x1 = hole.x2, z1 = r.z1, x2 = r.x2, z2 = r.z2 })
			end
			local mx1, mx2 = math.max(r.x1, hole.x1), math.min(r.x2, hole.x2)
			if hole.z1 > r.z1 + EPS then
				table.insert(out, { x1 = mx1, z1 = r.z1, x2 = mx2, z2 = hole.z1 })
			end
			if hole.z2 < r.z2 - EPS then
				table.insert(out, { x1 = mx1, z1 = hole.z2, x2 = mx2, z2 = r.z2 })
			end
		end
	end
	return out
end

-- The parts of the interval [a, b] not covered by any interval in `covered`.
local function subtractIntervals(a: number, b: number, covered: { { number } }): { { number } }
	local free = { { a, b } }
	for _, c in covered do
		local next: { { number } } = {}
		for _, f in free do
			if c[2] <= f[1] + EPS or c[1] >= f[2] - EPS then
				table.insert(next, f)
			else
				if c[1] > f[1] + EPS then
					table.insert(next, { f[1], c[1] })
				end
				if c[2] < f[2] - EPS then
					table.insert(next, { c[2], f[2] })
				end
			end
		end
		free = next
	end
	return free
end

function Build.run()
	local started = os.clock()
	local rng = Random.new(7)
	local levels = Layout.levels :: { [string]: number }
	local levelOrder = Layout.levelOrder :: { string }
	local nextLevel: { [string]: string } = {}
	for index, name in levelOrder do
		nextLevel[name] = levelOrder[index + 1]
	end

	local problems = 0
	local function check(ok: boolean, message: string)
		if not ok then
			problems += 1
		end
		print(`[Gala] {if ok then "ok  " else "FAIL"} {message}`)
	end

	-- Setup ------------------------------------------------------------------------------------------------------------
	for _, name in { "Gala", "Greybox", "Baseplate" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local root = Instance.new("Folder")
	root.Name = "Gala"
	root.Parent = workspace
	local function folder(name: string): Folder
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		return f
	end
	local geometry, trim, zonesFolder, objects, nodesFolder, propsFolder =
		folder("Geometry"), folder("Trim"), folder("Zones"), folder("Objects"), folder("NPCNodes"), folder("Props")

	local made = 0
	local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Anchored = true
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		made += 1
		if made % 400 == 0 then
			task.wait() -- keep Studio responsive while a large map is made
		end
		return p
	end
	local function ghost(p: Part)
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	local function tag(instance: Instance, tagName: string, attributes: { [string]: any }?)
		CollectionService:AddTag(instance, tagName)
		for key, value in attributes or {} do
			instance:SetAttribute(key, value)
		end
	end
	local function tierColor(tier: number): Color3
		return GameConfig.Zones.TierColors[tier]
	end

	-- Rooms and pieces ---------------------------------------------------------------------------------------------------
	local rooms = Layout.rooms :: { Room }
	local roomById: { [string]: Room } = {}
	for _, room in rooms do
		assert(not roomById[room.id], `Duplicate room id {room.id}`)
		assert(levels[room.level], `Room {room.id} is on unknown level {room.level}`)
		roomById[room.id] = room
	end

	local voidRects: { [string]: { Rect } } = {}
	for _, void in Layout.voids do
		voidRects[void.level] = voidRects[void.level] or {}
		table.insert(voidRects[void.level], toRect(void.rect))
	end

	local piecesByLevel: { [string]: { Piece } } = {}
	local piecesOfRoom: { [string]: { Piece } } = {}
	for _, name in levelOrder do
		piecesByLevel[name] = {}
	end
	for _, room in rooms do
		local rects = { toRect(room.rect) }
		for _, child in rooms do
			if child.parent == room.id then
				rects = subtract(rects, toRect(child.rect))
			end
		end
		for _, hole in room.holes or {} do
			rects = subtract(rects, toRect(hole))
		end
		for _, void in voidRects[room.level] or {} do
			rects = subtract(rects, void)
		end
		piecesOfRoom[room.id] = {}
		for _, rect in rects do
			local list = piecesByLevel[room.level]
			local piece: Piece = { room = room, rect = rect, index = #list + 1 }
			table.insert(list, piece)
			table.insert(piecesOfRoom[room.id], piece)
		end
	end

	-- No two pieces on a level may overlap.
	local overlapsFound = 0
	for name, list in piecesByLevel do
		for i = 1, #list do
			for j = i + 1, #list do
				if overlaps(list[i].rect, list[j].rect) then
					overlapsFound += 1
					print(`[Gala]      overlap on {name}: {list[i].room.id} and {list[j].room.id}`)
				end
			end
		end
	end
	check(overlapsFound == 0, "No overlapping rooms")

	-- Edges: every wall line between pieces, or between a piece and nothing --------------------------------------------------
	local edges: { Edge } = {}
	local function sideInfo(rect: Rect, side: number): (string, number, number, number)
		-- side 1: z1, 2: z2, 3: x1, 4: x2 -> axis, line, a, b
		if side == 1 then
			return "x", rect.z1, rect.x1, rect.x2
		elseif side == 2 then
			return "x", rect.z2, rect.x1, rect.x2
		elseif side == 3 then
			return "z", rect.x1, rect.z1, rect.z2
		end
		return "z", rect.x2, rect.z1, rect.z2
	end
	local function oppositeLine(rect: Rect, side: number): number
		-- the line of `rect` that touches a piece sitting on `side` of another piece
		if side == 1 then
			return rect.z2
		elseif side == 2 then
			return rect.z1
		elseif side == 3 then
			return rect.x2
		end
		return rect.x1
	end
	local function alongInterval(rect: Rect, axis: string): (number, number)
		return if axis == "x" then rect.x1 else rect.z1, if axis == "x" then rect.x2 else rect.z2
	end

	for levelName, list in piecesByLevel do
		for _, p in list do
			for side = 1, 4 do
				local axis, line, a, b = sideInfo(p.rect, side)
				local covered: { { number } } = {}
				for _, q in list do
					if q ~= p and math.abs(oppositeLine(q.rect, side) - line) < EPS then
						local qa, qb = alongInterval(q.rect, axis)
						local lo, hi = math.max(a, qa), math.min(b, qb)
						if hi - lo > EPS then
							table.insert(covered, { lo, hi })
							if p.index < q.index and p.room ~= q.room then
								table.insert(edges, {
									level = levelName,
									axis = axis,
									line = line,
									a = lo,
									b = hi,
									roomA = p.room,
									roomB = q.room,
									kind = "shared",
									gaps = {},
								})
							end
						end
					end
				end
				-- What is left of this side faces a void or nothing.
				local voidCovered: { { number } } = {}
				for _, void in voidRects[levelName] or {} do
					if math.abs(oppositeLine(void, side) - line) < EPS then
						local va, vb = alongInterval(void, axis)
						local lo, hi = math.max(a, va), math.min(b, vb)
						if hi - lo > EPS then
							table.insert(voidCovered, { lo, hi })
						end
					end
				end
				for _, free in subtractIntervals(a, b, covered) do
					local rest = { free }
					for _, v in voidCovered do
						-- the part of this free stretch that faces a void
						local lo, hi = math.max(free[1], v[1]), math.min(free[2], v[2])
						if hi - lo > EPS then
							table.insert(edges, {
								level = levelName,
								axis = axis,
								line = line,
								a = lo,
								b = hi,
								roomA = p.room,
								roomB = nil,
								kind = "void",
								gaps = {},
							})
						end
					end
					for _, v in voidCovered do
						rest = subtractIntervals(rest[1][1], rest[#rest][2], { v })
						if #rest == 0 then
							break
						end
					end
					for _, f in rest do
						table.insert(edges, {
							level = levelName,
							axis = axis,
							line = line,
							a = f[1],
							b = f[2],
							roomA = p.room,
							roomB = nil,
							kind = "free",
							gaps = {},
						})
					end
				end
			end
		end
	end

	-- Doors --------------------------------------------------------------------------------------------------------------------
	local doorPoints: { { level: string, x: number, z: number, nx: number, nz: number, a: Room, b: Room } } = {}
	local reserved: { [string]: { Rect } } = {}
	for _, name in levelOrder do
		reserved[name] = {}
	end
	local doorsUnplaced = 0
	local doorsPerRoom: { [string]: number } = {}
	for _, door in Layout.doors do
		local ra, rb = roomById[door.a], roomById[door.b]
		if not (ra and rb) then
			doorsUnplaced += 1
			print(`[Gala]      door names an unknown room: {door.a} / {door.b}`)
			continue
		end
		local best: Edge? = nil
		local bestLength = 0
		for _, edge in edges do
			if
				edge.kind == "shared"
				and ((edge.roomA == ra and edge.roomB == rb) or (edge.roomA == rb and edge.roomB == ra))
			then
				local length = edge.b - edge.a
				local containsAt = door.at ~= nil and door.at >= edge.a and door.at <= edge.b
				if containsAt then
					best, bestLength = edge, math.huge
				elseif length > bestLength then
					best, bestLength = edge, length
				end
			end
		end
		if not best then
			doorsUnplaced += 1
			print(`[Gala]      doors: {door.a} and {door.b} do not share a wall`)
			continue
		end
		local width = math.min(door.width or 10, best.b - best.a - 2)
		local center = door.at or (best.a + best.b) / 2
		center = math.clamp(center, best.a + width / 2 + 1, best.b - width / 2 - 1)
		table.insert(best.gaps, { center = center, width = width, door = door })
		doorsPerRoom[ra.id] = (doorsPerRoom[ra.id] or 0) + 1
		doorsPerRoom[rb.id] = (doorsPerRoom[rb.id] or 0) + 1
		local x, z = if best.axis == "x" then center else best.line, if best.axis == "x" then best.line else center
		local nx, nz = if best.axis == "x" then 0 else 1, if best.axis == "x" then 1 else 0
		table.insert(doorPoints, { level = best.level, x = x, z = z, nx = nx, nz = nz, a = ra, b = rb })
		table.insert(reserved[best.level], {
			x1 = x - (if best.axis == "x" then width / 2 + 2 else DOOR_CLEAR),
			z1 = z - (if best.axis == "x" then DOOR_CLEAR else width / 2 + 2),
			x2 = x + (if best.axis == "x" then width / 2 + 2 else DOOR_CLEAR),
			z2 = z + (if best.axis == "x" then DOOR_CLEAR else width / 2 + 2),
		})
	end
	check(doorsUnplaced == 0, `Every door placed ({#Layout.doors - doorsUnplaced}/{#Layout.doors})`)

	-- Ramps --------------------------------------------------------------------------------------------------------------------
	local rampFootprints: { [string]: { Rect } } = {} -- by the level the ramp starts on
	local rampHoles: { [string]: { Rect } } = {} -- by the level it arrives on
	local function dirVector(dir: string): (number, number)
		if dir == "+z" then
			return 0, 1
		elseif dir == "-z" then
			return 0, -1
		elseif dir == "+x" then
			return 1, 0
		end
		return -1, 0
	end
	for _, name in levelOrder do
		rampFootprints[name] = {}
		rampHoles[name] = {}
	end
	-- How wide and long a stair's footprint is: one lane for a plain run, two lanes and a landing for a switchback.
	local function rampSize(ramp: Layout.Ramp): (number, number)
		if ramp.turn then
			return RAMP_W * 2 + LANE_GAP, LEG_RUN + LANDING
		end
		return RAMP_W, RAMP_RUN
	end
	for _, ramp in Layout.ramps do
		local dx, dz = dirVector(ramp.dir)
		local width, length = rampSize(ramp)
		local x1, x2, z1, z2
		if dx == 0 then
			x1, x2 = ramp.x - width / 2, ramp.x + width / 2
			z1, z2 = math.min(ramp.z, ramp.z + dz * length), math.max(ramp.z, ramp.z + dz * length)
		else
			z1, z2 = ramp.z - width / 2, ramp.z + width / 2
			x1, x2 = math.min(ramp.x, ramp.x + dx * length), math.max(ramp.x, ramp.x + dx * length)
		end
		local footprint: Rect = { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }
		table.insert(rampFootprints[ramp.from], footprint)
		local upper = nextLevel[ramp.from]
		table.insert(rampHoles[upper], footprint)
		-- Props and nodes keep off the ramp on both levels.
		table.insert(reserved[ramp.from], inflate(footprint, 3))
		table.insert(reserved[upper], inflate(footprint, 3))
	end

	-- Features: water, islands, bridges, skylights and set pieces that are not rooms (Layout.features) -----------------------------
	local WATER = Color3.fromRGB(70, 135, 190)
	local GRASS = Color3.fromRGB(90, 135, 80)
	local BRONZE = Color3.fromRGB(190, 125, 60)
	local DARK_WOOD = Color3.fromRGB(100, 72, 52)
	local STONE_GREY = Color3.fromRGB(170, 170, 175)
	local GLASS = Color3.fromRGB(190, 220, 240)

	local function featureTree(level: string, x: number, z: number, lift: number)
		local y = levels[level] + lift
		part(propsFolder, "Tree", Vector3.new(1.6, 6, 1.6), CFrame.new(x, y + 3, z), Color3.fromRGB(90, 65, 45))
		local canopy = part(propsFolder, "Canopy", Vector3.new(10, 8, 10), CFrame.new(x, y + 9.5, z), GRASS)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
	end

	for _, feature in Layout.features do
		local level = feature.level
		local y = levels[level]
		local r: Rect? = if feature.rect then toRect(feature.rect) else nil
		if r and feature.kind ~= "skylight" then
			table.insert(reserved[level], inflate(r, 1)) -- props and doorways keep clear of it
		end
		if feature.kind == "pool" and r then
			local water = part(
				propsFolder,
				"Water",
				Vector3.new(r.x2 - r.x1, 0.5, r.z2 - r.z1),
				CFrame.new((r.x1 + r.x2) / 2, y + 0.25, (r.z1 + r.z2) / 2),
				WATER
			)
			water.Material = Enum.Material.Glass
			water.Transparency = 0.35
			water.CanCollide = false
		elseif feature.kind == "island" and r then
			part(
				propsFolder,
				"Island",
				Vector3.new(r.x2 - r.x1, 1, r.z2 - r.z1),
				CFrame.new((r.x1 + r.x2) / 2, y + 0.5, (r.z1 + r.z2) / 2),
				GRASS
			)
			local cx, cz = (r.x1 + r.x2) / 2, (r.z1 + r.z2) / 2
			local long = (r.x2 - r.x1) > (r.z2 - r.z1)
			for _, side in { -1, 1 } do
				local ox = if long then side * (r.x2 - r.x1) * 0.28 else 0
				local oz = if long then 0 else side * (r.z2 - r.z1) * 0.28
				featureTree(level, cx + ox, cz + oz, 1)
			end
		elseif feature.kind == "bridge" and r then
			local top = feature.top or 1
			local color = feature.color or DARK_WOOD
			part(
				propsFolder,
				"Bridge",
				Vector3.new(r.x2 - r.x1, 0.4, r.z2 - r.z1),
				CFrame.new((r.x1 + r.x2) / 2, y + top - 0.2, (r.z1 + r.z2) / 2),
				color
			)
			local lengthAlongX = (r.x2 - r.x1) > (r.z2 - r.z1)
			for _, side in { -1, 1 } do
				if lengthAlongX then
					part(
						propsFolder,
						"BridgeRail",
						Vector3.new(r.x2 - r.x1, 2.2, 0.3),
						CFrame.new((r.x1 + r.x2) / 2, y + top + 1.1, if side < 0 then r.z1 + 0.15 else r.z2 - 0.15),
						color
					)
				else
					part(
						propsFolder,
						"BridgeRail",
						Vector3.new(0.3, 2.2, r.z2 - r.z1),
						CFrame.new(if side < 0 then r.x1 + 0.15 else r.x2 - 0.15, y + top + 1.1, (r.z1 + r.z2) / 2),
						color
					)
				end
			end
		elseif feature.kind == "skylight" and r then
			local pane = part(
				geometry,
				"Skylight",
				Vector3.new(r.x2 - r.x1, SLAB, r.z2 - r.z1),
				CFrame.new((r.x1 + r.x2) / 2, y - SLAB / 2, (r.z1 + r.z2) / 2),
				GLASS
			)
			pane.Material = Enum.Material.Glass
			pane.Transparency = 0.55
		elseif feature.kind == "statue" then
			part(
				propsFolder,
				"Pedestal",
				Vector3.new(4, 2, 4),
				CFrame.new(feature.x :: number, y + 1, feature.z :: number),
				STONE_GREY
			)
			part(
				propsFolder,
				"Statue legs",
				Vector3.new(2, 3.5, 1.2),
				CFrame.new(feature.x :: number, y + 3.75, feature.z :: number),
				BRONZE
			)
			part(
				propsFolder,
				"Statue torso",
				Vector3.new(2.4, 3, 1.4),
				CFrame.new(feature.x :: number, y + 7, feature.z :: number),
				BRONZE
			)
			local head = part(
				propsFolder,
				"Statue head",
				Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(feature.x :: number, y + 9.3, feature.z :: number),
				BRONZE
			)
			head.Shape = Enum.PartType.Ball
		elseif feature.kind == "lanterns" then
			for _, position in feature.points do
				part(
					propsFolder,
					"Lantern post",
					Vector3.new(0.7, 4, 0.7),
					CFrame.new(position[1], y + 2, position[2]),
					STONE_GREY
				)
				local lamp = part(
					propsFolder,
					"Lantern",
					Vector3.new(1.3, 1.3, 1.3),
					CFrame.new(position[1], y + 4.6, position[2]),
					Color3.fromRGB(255, 200, 120)
				)
				lamp.Material = Enum.Material.Neon
				lamp.CanCollide = false
			end
		elseif feature.kind == "pavilion" and r then
			-- A boardwalk deck and a row of A-frame glass-and-timber arches along it.
			part(
				propsFolder,
				"Boardwalk",
				Vector3.new(r.x2 - r.x1, 0.4, r.z2 - r.z1),
				CFrame.new((r.x1 + r.x2) / 2, y + 0.2, (r.z1 + r.z2) / 2),
				DARK_WOOD
			)
			local count = feature.count or 4
			local spacing = (r.z2 - r.z1) / count
			for index = 1, count do
				local z = r.z1 + spacing * (index - 0.5)
				for _, side in { -1, 1 } do
					local panel = part(
						propsFolder,
						"Arch",
						Vector3.new(0.8, 14, spacing * 0.7),
						CFrame.new((r.x1 + r.x2) / 2 + side * 3.6, y + 7.2, z)
							* CFrame.Angles(0, 0, side * math.rad(-32)),
						Color3.fromRGB(235, 150, 60)
					)
					panel.Material = Enum.Material.Glass
					panel.Transparency = 0.35
				end
			end
		end
	end

	-- Walls ----------------------------------------------------------------------------------------------------------------------
	local function alongSize(axis: string, length: number, height: number, depth: number): Vector3
		return if axis == "x" then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
	end
	local function alongPoint(axis: string, line: number, pos: number, y: number): Vector3
		return if axis == "x" then Vector3.new(pos, y, line) else Vector3.new(line, y, pos)
	end
	local currentGlass = false -- the wall being built is glass above a low sill (an indoor room facing a garden)
	local function wallPiece(edge: Edge, a: number, b: number, height: number, color: Color3)
		if b - a < 0.5 then
			return
		end
		if currentGlass and height == WALL_H then
			local sill = 3
			local base = levels[edge.level]
			part(
				geometry,
				"Sill",
				alongSize(edge.axis, b - a, sill, WALL_T),
				CFrame.new(alongPoint(edge.axis, edge.line, (a + b) / 2, base + sill / 2)),
				color
			)
			local pane = part(
				geometry,
				"Glass",
				alongSize(edge.axis, b - a, height - sill, WALL_T - 0.6),
				CFrame.new(alongPoint(edge.axis, edge.line, (a + b) / 2, base + sill + (height - sill) / 2)),
				Color3.fromRGB(170, 210, 235)
			)
			pane.Material = Enum.Material.Glass
			pane.Transparency = 0.55
			return
		end
		local y = levels[edge.level] + height / 2
		part(
			geometry,
			"Wall",
			alongSize(edge.axis, b - a, height, WALL_T),
			CFrame.new(alongPoint(edge.axis, edge.line, (a + b) / 2, y)),
			color
		)
	end

	local wallCount, gateCount, keycardCount = 0, 0, 0
	for _, edge in edges do
		local height = 0
		local color = GREY
		if edge.kind == "shared" then
			local roomB = edge.roomB :: Room
			if edge.roomA.kind == "indoor" or roomB.kind == "indoor" then
				height = WALL_H
			end
		elseif edge.kind == "void" then
			height, color = RAIL_H, RAIL_GREY
		else
			if edge.roomA.kind == "indoor" then
				height = WALL_H
			else
				height, color = RAIL_H, RAIL_GREY
			end
		end
		if height == 0 then
			continue
		end
		wallCount += 1
		currentGlass = false
		if edge.kind == "shared" then
			local other = edge.roomB :: Room
			currentGlass = (edge.roomA.glass == true or other.glass == true)
				and (edge.roomA.kind == "outdoor" or other.kind == "outdoor")
		elseif edge.kind == "free" then
			-- Windows onto the city where a room asks for glass; vault and guard rooms keep solid walls.
			currentGlass = edge.roomA.glass == true and edge.roomA.kind == "indoor"
		end

		table.sort(edge.gaps, function(p, q)
			return p.center < q.center
		end)
		local cursor = edge.a
		for _, gap in edge.gaps do
			wallPiece(edge, cursor, gap.center - gap.width / 2, height, color)
			cursor = gap.center + gap.width / 2
			-- Lintel above the doorway.
			local baseY = levels[edge.level]
			part(
				geometry,
				"Lintel",
				alongSize(edge.axis, gap.width, height - GAP_H, WALL_T),
				CFrame.new(alongPoint(edge.axis, edge.line, gap.center, baseY + GAP_H + (height - GAP_H) / 2)),
				color
			)
			local roomB = edge.roomB :: Room
			local high = math.max(edge.roomA.tier, roomB.tier)
			local door = gap.door
			-- A clearance door or keycard door fills the doorway until it is opened (DoorService).
			if door.gate or door.keycard then
				local doorPart = part(
					objects,
					if door.gate then "ClearanceDoor" else "KeycardDoor",
					alongSize(edge.axis, gap.width, GAP_H, WALL_T - 0.4),
					CFrame.new(alongPoint(edge.axis, edge.line, gap.center, baseY + GAP_H / 2)),
					tierColor(if door.gate then door.gate else high)
				)
				doorPart.Transparency = 0.35
				if door.gate then
					gateCount += 1
					tag(doorPart, Tag.ClearanceDoor, { Tier = door.gate })
				else
					keycardCount += 1
					tag(doorPart, Tag.KeycardDoor, { Tier = high })
				end
			end
			-- Coloured posts and floor decals show which tiers a doorway joins.
			if edge.roomA.tier ~= roomB.tier or door.gate then
				local postColor = tierColor(if door.gate then door.gate else high)
				for _, offset in { -gap.width / 2 + 0.6, gap.width / 2 - 0.6 } do
					part(
						trim,
						"DoorPost",
						alongSize(edge.axis, 1.2, GAP_H, WALL_T + 0.6),
						CFrame.new(alongPoint(edge.axis, edge.line, gap.center + offset, baseY + GAP_H / 2)),
						postColor
					)
				end
				for sign, room in { [-1] = edge.roomA, [1] = roomB } do
					local decal = part(
						trim,
						"FloorDecal",
						alongSize(edge.axis, gap.width, 0.2, 4),
						CFrame.new(alongPoint(edge.axis, edge.line + sign * (WALL_T / 2 + 2), gap.center, baseY + 0.1)),
						tierColor(room.tier)
					)
					decal.CanCollide = false
				end
			end
		end
		wallPiece(edge, cursor, edge.b, height, color)
	end

	-- Floors and ceilings --------------------------------------------------------------------------------------------------------
	local function slab(parent: Instance, name: string, rect: Rect, topY: number, color: Color3)
		part(
			parent,
			name,
			Vector3.new(rect.x2 - rect.x1, SLAB, rect.z2 - rect.z1),
			CFrame.new((rect.x1 + rect.x2) / 2, topY - SLAB / 2, (rect.z1 + rect.z2) / 2),
			color
		)
	end
	for levelName, list in piecesByLevel do
		for _, piece in list do
			local pieces = { piece.rect }
			for _, hole in rampHoles[levelName] do
				pieces = subtract(pieces, hole)
			end
			local color
			if piece.room.kind == "indoor" then
				color = tierColor(piece.room.tier):Lerp(GREY, 0.6)
			elseif levelName == "G" then
				color = Color3.fromRGB(95, 130, 85)
			else
				color = Color3.fromRGB(140, 140, 150)
			end
			for _, rect in pieces do
				slab(geometry, `Floor_{levelName}_{piece.room.id}`, rect, levels[levelName], color)
			end
			-- An indoor room is roofed wherever no room sits above it; a shaft stays open where the void is.
			if piece.room.kind == "indoor" then
				local above = nextLevel[levelName]
				local uncovered = { piece.rect }
				if above then
					for _, other in piecesByLevel[above] do
						uncovered = subtract(uncovered, other.rect)
					end
					for _, void in voidRects[above] or {} do
						uncovered = subtract(uncovered, void)
					end
				end
				for _, rect in uncovered do
					slab(geometry, `Roof_{levelName}_{piece.room.id}`, rect, levels[levelName] + WALL_H + SLAB, GREY)
				end
			end
		end
	end

	-- Stairs (the bodies and the railings round their openings) --------------------------------------------------------------------
	local STAIR_GREY = Color3.fromRGB(120, 120, 130)
	local function slope(
		name: string,
		sx: number,
		sz: number,
		dx: number,
		dz: number,
		baseY: number,
		run: number,
		rise: number
	)
		-- the part's thickness lifts its top surface, so shift it back toward the climb
		local angle = math.atan2(rise, run)
		local shift = run / 2 + math.sin(angle)
		local center = Vector3.new(sx + dx * shift, baseY + rise / 2 - math.cos(angle), sz + dz * shift)
		local target = center + Vector3.new(dx * run, rise, dz * run)
		part(
			geometry,
			name,
			Vector3.new(RAMP_W, 2, math.sqrt(rise ^ 2 + run ^ 2)),
			CFrame.lookAt(center, target),
			STAIR_GREY
		)
	end
	for _, ramp in Layout.ramps do
		local dx, dz = dirVector(ramp.dir)
		local px, pz = dz, -dx -- sideways across the stair
		local baseY = levels[ramp.from]
		local upperY = baseY + RAMP_RISE
		local width, length = rampSize(ramp)
		local lane = RAMP_W / 2 + LANE_GAP / 2
		-- A rail on the upper floor, `along` studs up the stair and `across` studs sideways from its centre line.
		local function rail(along: number, across: number, alongLen: number, acrossLen: number)
			part(
				geometry,
				"StairRail",
				Vector3.new(if dx == 0 then acrossLen else alongLen, RAIL_H, if dx == 0 then alongLen else acrossLen),
				CFrame.new(ramp.x + dx * along + px * across, upperY + RAIL_H / 2, ramp.z + dz * along + pz * across),
				RAIL_GREY
			)
		end
		for _, side in { -1, 1 } do
			rail(length / 2, side * (width / 2 + 0.5), length, 1)
		end
		if ramp.turn then
			-- Leg one climbs away from the start; leg two climbs back, from the landing to the upper floor.
			slope("StairLeg", ramp.x - px * lane, ramp.z - pz * lane, dx, dz, baseY, LEG_RUN, LEG_RISE)
			slope(
				"StairLeg",
				ramp.x + px * lane + dx * LEG_RUN,
				ramp.z + pz * lane + dz * LEG_RUN,
				-dx,
				-dz,
				baseY + LEG_RISE,
				LEG_RUN,
				LEG_RISE
			)
			part(
				geometry,
				"StairLanding",
				Vector3.new(if dx == 0 then width else LANDING, SLAB, if dx == 0 then LANDING else width),
				CFrame.new(
					ramp.x + dx * (LEG_RUN + LANDING / 2),
					baseY + LEG_RISE - SLAB / 2,
					ramp.z + dz * (LEG_RUN + LANDING / 2)
				),
				STAIR_GREY
			)
			rail(length + 0.5, 0, 1, width + 2) -- across the landing end
			rail(length / 2, 0, length, 1) -- between the two legs
			rail(-0.5, -lane, 1, RAMP_W + 1) -- across the lower leg's start; the upper leg arrives open here
		else
			slope("Stair", ramp.x, ramp.z, dx, dz, baseY, RAMP_RUN, RAMP_RISE)
			rail(-0.5, 0, 1, width + 2) -- across the low end; the top end is open to walk off
		end
	end

	-- Zone volumes (spec 4.2) ------------------------------------------------------------------------------------------------------
	local zoneCount = 0
	for levelName, list in piecesByLevel do
		for _, piece in list do
			local r = piece.rect
			local volume = part(
				zonesFolder,
				`Zone_{levelName}_T{piece.room.tier}_{piece.room.id}`,
				Vector3.new(r.x2 - r.x1 + ZONE_PAD * 2, 24, r.z2 - r.z1 + ZONE_PAD * 2),
				CFrame.new((r.x1 + r.x2) / 2, levels[levelName] + 11, (r.z1 + r.z2) / 2),
				tierColor(piece.room.tier)
			)
			ghost(volume)
			tag(volume, Tag.ZoneVolume, { Tier = piece.room.tier })
			zoneCount += 1
		end
	end

	-- Props --------------------------------------------------------------------------------------------------------------------------
	local propRects: { [string]: { Rect } } = {}
	for _, name in levelOrder do
		propRects[name] = {}
	end
	-- Is this area on the room's floor, away from doorways, ramps and other props?
	local function freeFor(room: Room, rect: Rect): boolean
		local fits = false
		for _, piece in piecesOfRoom[room.id] do
			local p = piece.rect
			if rect.x1 >= p.x1 + 2 and rect.x2 <= p.x2 - 2 and rect.z1 >= p.z1 + 2 and rect.z2 <= p.z2 - 2 then
				fits = true
				break
			end
		end
		if not fits then
			return false
		end
		for _, blocked in reserved[room.level] do
			if overlaps(rect, blocked) then
				return false
			end
		end
		for _, other in propRects[room.level] do
			if overlaps(rect, inflate(other, 1)) then
				return false
			end
		end
		return true
	end
	local function addProp(
		room: Room,
		name: string,
		cx: number,
		cz: number,
		sx: number,
		sy: number,
		sz: number,
		color: Color3,
		solid: boolean?,
		round: boolean?
	): boolean
		local rect: Rect = { x1 = cx - sx / 2, z1 = cz - sz / 2, x2 = cx + sx / 2, z2 = cz + sz / 2 }
		if not freeFor(room, rect) then
			return false
		end
		local p =
			part(propsFolder, name, Vector3.new(sx, sy, sz), CFrame.new(cx, levels[room.level] + sy / 2, cz), color)
		if round then
			-- A cylinder's axis is X, so it is sized with its height along X and turned upright.
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(sy, sx, sz)
			p.CFrame = CFrame.new(cx, levels[room.level] + sy / 2, cz) * CFrame.Angles(0, 0, math.rad(90))
		end
		if solid == false then
			p.CanCollide = false
		end
		table.insert(propRects[room.level], rect)
		return true
	end

	local WOOD = Color3.fromRGB(120, 100, 80)
	local STONE = Color3.fromRGB(170, 170, 175)
	local GREEN = Color3.fromRGB(60, 110, 60)
	local METAL = Color3.fromRGB(110, 115, 125)

	local function bounds(room: Room): Rect
		return toRect(room.rect)
	end

	local propBuilders: { [string]: (Room) -> () } = {
		pillars = function(room)
			local b = bounds(room)
			local x = b.x1 + 20
			while x < b.x2 - 10 do
				local z = b.z1 + 20
				while z < b.z2 - 10 do
					addProp(room, "Pillar", x, z, 3, WALL_H, 3, STONE, true, true)
					z += 24
				end
				x += 24
			end
		end,
		planters = function(room)
			local b = bounds(room)
			local x = b.x1 + 12
			while x < b.x2 - 6 do
				addProp(room, "Planter", x, b.z1 + 5, 5, 3, 3, GREEN)
				addProp(room, "Planter", x, b.z2 - 5, 5, 3, 3, GREEN)
				x += 15
			end
			local z = b.z1 + 22
			while z < b.z2 - 16 do
				addProp(room, "Planter", b.x1 + 5, z, 3, 3, 5, GREEN)
				addProp(room, "Planter", b.x2 - 5, z, 3, 3, 5, GREEN)
				z += 15
			end
		end,
		tables = function(room)
			local b = bounds(room)
			local x = b.x1 + 18
			while x < b.x2 - 12 do
				local z = b.z1 + 18
				while z < b.z2 - 12 do
					if rng:NextNumber() < 0.85 then
						addProp(
							room,
							"Table",
							x + rng:NextNumber(-4, 4),
							z + rng:NextNumber(-4, 4),
							6,
							3.5,
							6,
							WOOD,
							true,
							true
						)
					end
					z += 17
				end
				x += 17
			end
		end,
		crates = function(room)
			local b = bounds(room)
			for _ = 1, 28 do
				addProp(
					room,
					"Crate",
					rng:NextNumber(b.x1 + 8, b.x2 - 8),
					rng:NextNumber(b.z1 + 8, b.z2 - 8),
					rng:NextNumber(5, 8),
					rng:NextNumber(5, 8),
					rng:NextNumber(5, 8),
					WOOD
				)
			end
		end,
		trucks = function(room)
			local b = bounds(room)
			addProp(room, "Truck", b.x1 + 18, (b.z1 + b.z2) / 2 - 20, 12, 9, 28, METAL)
			addProp(room, "Truck", b.x1 + 18, (b.z1 + b.z2) / 2 + 24, 12, 9, 28, METAL)
		end,
		desks = function(room)
			local b = bounds(room)
			local x = b.x1 + 14
			while x < b.x2 - 8 do
				local z = b.z1 + 12
				while z < b.z2 - 8 do
					addProp(room, "Desk", x, z, 8, 3, 4, WOOD)
					z += 16
				end
				x += 18
			end
		end,
		reception = function(room)
			local b = bounds(room)
			addProp(room, "Reception desk", (b.x1 + b.x2) / 2, b.z1 + 14, 26, 4, 6, WOOD)
		end,
		bar = function(room)
			local b = bounds(room)
			addProp(room, "Bar counter", (b.x1 + b.x2) / 2, b.z1 + 12, 34, 4, 4, WOOD)
			addProp(room, "Bar shelves", (b.x1 + b.x2) / 2, b.z1 + 5, 34, 8, 2, METAL)
		end,
		partitions = function(room)
			local b = bounds(room)
			local index = 0
			local x = b.x1 + 18
			while x < b.x2 - 10 do
				local z = b.z1 + 20
				while z < b.z2 - 14 do
					index += 1
					if index % 2 == 0 then
						addProp(room, "Partition", x, z, 1.5, 14, 16, STONE)
					else
						addProp(room, "Partition", x + 6, z + 12, 16, 14, 1.5, STONE)
					end
					z += 24
				end
				x += 20
			end
		end,
		islands = function(room)
			local b = bounds(room)
			local z = b.z1 + 16
			while z < b.z2 - 10 do
				local x = b.x1 + 16
				while x < b.x2 - 12 do
					addProp(room, "Island", x, z, 12, 3.5, 5, METAL)
					x += 26
				end
				z += 22
			end
		end,
		stage = function(room)
			local b = bounds(room)
			addProp(room, "Stage", (b.x1 + b.x2) / 2, b.z2 - 12, 30, 1.5, 16, WOOD)
		end,
		trees = function(room)
			local b = bounds(room)
			for _ = 1, 20 do
				local x, z = rng:NextNumber(b.x1 + 10, b.x2 - 10), rng:NextNumber(b.z1 + 10, b.z2 - 10)
				if addProp(room, "Tree", x, z, 2, 7, 2, Color3.fromRGB(90, 65, 45)) then
					local canopy = part(
						propsFolder,
						"Canopy",
						Vector3.new(11, 9, 11),
						CFrame.new(x, levels[room.level] + 11.5, z),
						GREEN
					)
					canopy.Shape = Enum.PartType.Ball
					canopy.CanCollide = false
				end
			end
		end,
	}
	local propCount = 0
	for _, room in rooms do
		for _, kind in room.props or {} do
			local build = propBuilders[kind]
			assert(build, `Unknown prop kind {kind} on {room.id}`)
			local before = #propRects[room.level]
			build(room)
			propCount += #propRects[room.level] - before
		end
	end

	-- Interior lights: warm amber in the public rooms, cooler as the tier rises, a handful per room (dusk-like inside).
	local LIGHT_COLORS: { [number]: Color3 } = {
		[0] = Color3.fromRGB(255, 205, 150),
		[1] = Color3.fromRGB(225, 232, 255),
		[2] = Color3.fromRGB(205, 190, 255),
		[3] = Color3.fromRGB(255, 220, 160),
	}
	local lightCount = 0
	for _, room in rooms do
		if room.kind == "indoor" then
			for _, piece in piecesOfRoom[room.id] do
				local p = piece.rect
				local x = p.x1 + LIGHT_SPACING / 2
				while x < p.x2 do
					local z = p.z1 + LIGHT_SPACING / 2
					while z < p.z2 do
						if lightCount < LIGHT_CAP then
							local lamp = part(
								propsFolder,
								"CeilingLight",
								Vector3.new(3, 0.3, 3),
								CFrame.new(x, levels[room.level] + WALL_H - 0.4, z),
								LIGHT_COLORS[room.tier]
							)
							lamp.Material = Enum.Material.Neon
							lamp.CanCollide = false
							lamp.CanQuery = false
							local light = Instance.new("PointLight")
							light.Color = LIGHT_COLORS[room.tier]
							light.Range = 30
							light.Brightness = 0.7
							light.Shadows = false
							light.Parent = lamp
							lightCount += 1
						end
						z += LIGHT_SPACING
					end
					x += LIGHT_SPACING
				end
			end
		end
	end

	-- Tagged objects ---------------------------------------------------------------------------------------------------------------------
	local function tierAtPoint(level: string, x: number, z: number): number
		local best = 0
		for _, piece in piecesByLevel[level] do
			local r = piece.rect
			if x > r.x1 and x < r.x2 and z > r.z1 and z < r.z2 then
				best = math.max(best, piece.room.tier)
			end
		end
		return best
	end
	local function marker(
		name: string,
		level: string,
		x: number,
		z: number,
		size: Vector3,
		color: Color3,
		tagName: string,
		extra: { [string]: any }?
	): Part
		local p = part(objects, name, size, CFrame.new(x, levels[level] + size.Y / 2, z), color)
		local attributes: { [string]: any } = { Tier = tierAtPoint(level, x, z), Floor = level }
		for key, value in extra or {} do
			attributes[key] = value
		end
		tag(p, tagName, attributes)
		return p
	end

	for _, m in Layout.insertion do
		local p =
			marker(m.id, m.level, m.x, m.z, Vector3.new(4, 0.4, 4), Color3.fromRGB(0, 200, 120), Tag.InsertionPoint)
		p.Transparency = 0.4
		p.CanCollide = false
	end
	for _, m in Layout.extraction do
		local p = marker(
			m.id,
			m.level,
			m.x,
			m.z,
			Vector3.new(16, 0.5, 16),
			Color3.fromRGB(255, 215, 0),
			Tag.ExtractionSite,
			{ Site = m.id }
		)
		p.Transparency = 0.2
	end
	for index, m in Layout.vaults do
		marker(
			m.id,
			m.level,
			m.x,
			m.z,
			Vector3.new(6, 1, 6),
			Color3.fromRGB(200, 40, 40),
			Tag.VaultSpawn,
			{ VaultId = index }
		)
	end
	-- The pad on the roof under the Helipad extraction marker.
	for _, m in Layout.extraction do
		if m.id == "Helipad" then
			part(
				propsFolder,
				"Helipad",
				Vector3.new(36, 0.6, 36),
				CFrame.new(m.x, levels[m.level] + 0.3, m.z),
				Color3.fromRGB(90, 90, 95)
			)
		end
	end

	-- NPC nodes ------------------------------------------------------------------------------------------------------------------------------
	type NodeSpec = { level: string, x: number, z: number, tier: number, activity: string }
	local function blockedForNode(level: string, x: number, z: number): boolean
		for _, r in rampFootprints[level] do
			if x > r.x1 - 6 and x < r.x2 + 6 and z > r.z1 - 6 and z < r.z2 + 6 then
				return true
			end
		end
		for _, r in rampHoles[level] do
			if x > r.x1 - 6 and x < r.x2 + 6 and z > r.z1 - 6 and z < r.z2 + 6 then
				return true
			end
		end
		for _, r in propRects[level] do
			if
				x > r.x1 - NODE_PROP_CLEAR
				and x < r.x2 + NODE_PROP_CLEAR
				and z > r.z1 - NODE_PROP_CLEAR
				and z < r.z2 + NODE_PROP_CLEAR
			then
				return true
			end
		end
		return false
	end
	local function buildNodes(spacingScale: number): { NodeSpec }
		local list: { NodeSpec } = {}
		local nodeRng = Random.new(11)
		for _, room in rooms do
			local pool = room.activities
				or (if room.kind == "outdoor" then OUTDOOR_ACTIVITIES else ACTIVITIES[room.tier])
			local step = (NODE_SPACING[room.tier] / math.sqrt(room.density or 1)) * spacingScale
			for _, piece in piecesOfRoom[room.id] do
				local r = piece.rect
				-- A strip narrower than twice the margin (a terrace, a bridge) still gets nodes, down its middle.
				local marginX = math.min(NODE_MARGIN, math.max((r.x2 - r.x1) / 2 - 0.1, 0))
				local marginZ = math.min(NODE_MARGIN, math.max((r.z2 - r.z1) / 2 - 0.1, 0))
				local x = r.x1 + marginX
				while x <= r.x2 - marginX do
					local z = r.z1 + marginZ
					while z <= r.z2 - marginZ do
						if not blockedForNode(room.level, x, z) then
							table.insert(list, {
								level = room.level,
								x = x,
								z = z,
								tier = room.tier,
								activity = pool[nodeRng:NextInteger(1, #pool)],
							})
						end
						z += step
					end
					x += step
				end
			end
		end
		for _, node in Layout.nodes do
			table.insert(list, {
				level = node.level,
				x = node.x,
				z = node.z,
				tier = tierAtPoint(node.level, node.x, node.z),
				activity = node.activity,
			})
		end
		-- Every doorway gets a walking node on each side so routes connect through it.
		for _, d in doorPoints do
			for sign, room in { [-1] = d.a, [1] = d.b } do
				local x, z = d.x + d.nx * sign * 5, d.z + d.nz * sign * 5
				local dup = false
				for _, n in list do
					if n.level == d.level and math.abs(n.x - x) < 4 and math.abs(n.z - z) < 4 then
						dup = true
						break
					end
				end
				if not dup then
					table.insert(list, { level = d.level, x = x, z = z, tier = room.tier, activity = "Walk" })
				end
			end
		end
		-- Both ends of every ramp.
		-- A plain stair arrives past its far end; a switchback arrives beside where it began.
		for _, ramp in Layout.ramps do
			local dx, dz = dirVector(ramp.dir)
			local px, pz = dz, -dx
			local lane = RAMP_W / 2 + LANE_GAP / 2
			local upper = nextLevel[ramp.from]
			local lowerLane = if ramp.turn then -lane else 0
			local lowerX, lowerZ = ramp.x - dx * 4 + px * lowerLane, ramp.z - dz * 4 + pz * lowerLane
			table.insert(list, {
				level = ramp.from,
				x = lowerX,
				z = lowerZ,
				tier = tierAtPoint(ramp.from, lowerX, lowerZ),
				activity = "Walk",
			})
			local topX, topZ
			if ramp.turn then
				topX, topZ = ramp.x - dx * 4 + px * lane, ramp.z - dz * 4 + pz * lane
			else
				topX, topZ = ramp.x + dx * (RAMP_RUN + 4), ramp.z + dz * (RAMP_RUN + 4)
			end
			table.insert(
				list,
				{ level = upper, x = topX, z = topZ, tier = tierAtPoint(upper, topX, topZ), activity = "Walk" }
			)
		end
		return list
	end
	local scale = 1
	local specs = buildNodes(scale)
	for _ = 1, 12 do
		if #specs <= NODE_CAP then
			break
		end
		scale *= 1.08
		specs = buildNodes(scale)
	end
	for index, spec in specs do
		local node = part(
			nodesFolder,
			`NPCNode{index}`,
			Vector3.one,
			CFrame.new(spec.x, levels[spec.level] + 1, spec.z),
			Color3.fromRGB(255, 255, 0)
		)
		ghost(node)
		tag(node, Tag.NPCNode, { Tier = spec.tier, Activity = spec.activity })
	end

	-- The cityscape. The Gala sits on the roof of a skyscraper: a sheer shaft drops away under the tower, the street is far
	-- below under a deck of cloud, and the rest of the city is lower towers poking through the haze with a few taller ones
	-- in the distance. None of it can be reached; every ground floor wall is closed and the only outdoor spaces are the
	-- terraces and decks above. It is one persistent model so streaming never drops the skyline.
	local cityModel = Instance.new("Model")
	cityModel.Name = "Cityscape"
	cityModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	cityModel.Parent = root
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, piece in piecesByLevel.G do
		minX, minZ = math.min(minX, piece.rect.x1), math.min(minZ, piece.rect.z1)
		maxX, maxZ = math.max(maxX, piece.rect.x2), math.max(maxZ, piece.rect.z2)
	end
	local centerX, centerZ = (minX + maxX) / 2, (minZ + maxZ) / 2
	local cityRng = Random.new(23)
	local function cityPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
		local p = part(cityModel, name, size, cframe, color)
		p.CanQuery = false
		return p
	end
	local function lit(name: string, size: Vector3, cframe: CFrame)
		local p = cityPart(name, size, cframe, Color3.fromRGB(255, 214, 150))
		p.Material = Enum.Material.Neon
		p.CanCollide = false
	end
	local APRON_W, APRON_DEPTH, SHAFT_DEPTH, CITY_BOTTOM = 14, 25, 800, -820
	local roofTop, shaftTop = -1, levels.B - SLAB -- the basement floor's underside
	-- The skyscraper's roof round the tower (the tower's own floors cover the middle), and the shaft under all of it.
	for _, strip in
		{
			{ minX - APRON_W, minZ - APRON_W, minX, maxZ + APRON_W },
			{ maxX, minZ - APRON_W, maxX + APRON_W, maxZ + APRON_W },
			{ minX, minZ - APRON_W, maxX, minZ },
			{ minX, maxZ, maxX, maxZ + APRON_W },
		}
	do
		cityPart(
			"Roof apron",
			Vector3.new(strip[3] - strip[1], APRON_DEPTH, strip[4] - strip[2]),
			CFrame.new((strip[1] + strip[3]) / 2, roofTop - APRON_DEPTH / 2, (strip[2] + strip[4]) / 2),
			Color3.fromRGB(95, 97, 108)
		)
	end
	local roofW, roofD = maxX - minX + APRON_W * 2, maxZ - minZ + APRON_W * 2
	cityPart(
		"Skyscraper shaft",
		Vector3.new(roofW, SHAFT_DEPTH, roofD),
		CFrame.new(centerX, shaftTop - SHAFT_DEPTH / 2, centerZ),
		Color3.fromRGB(62, 64, 76)
	)
	-- Rows of lit windows down the shaft's four faces, so the drop reads as the face of a building.
	for face = 1, 4 do
		local sign = if face % 2 == 0 then 1 else -1
		for _ = 1, 9 do
			local y = shaftTop - cityRng:NextNumber(15, 320)
			local length = cityRng:NextNumber(30, 90)
			if face <= 2 then
				local z = centerZ + cityRng:NextNumber(-roofD / 2 + length / 2, roofD / 2 - length / 2)
				lit("Shaft windows", Vector3.new(0.4, 4, length), CFrame.new(centerX + sign * (roofW / 2 + 0.2), y, z))
			else
				local x = centerX + cityRng:NextNumber(-roofW / 2 + length / 2, roofW / 2 - length / 2)
				lit("Shaft windows", Vector3.new(length, 4, 0.4), CFrame.new(x, y, centerZ + sign * (roofD / 2 + 0.2)))
			end
		end
	end
	-- Cloud decks and the street far below.
	for _, layer in { { -250, 0.5 }, { -430, 0.2 } } do
		local mist = cityPart(
			"Cloud deck",
			Vector3.new(4000, 2, 4000),
			CFrame.new(centerX, layer[1], centerZ),
			Color3.fromRGB(225, 218, 235)
		)
		mist.Transparency = layer[2]
		mist.CanCollide = false
	end
	cityPart(
		"Street",
		Vector3.new(4000, 2, 4000),
		CFrame.new(centerX, CITY_BOTTOM, centerZ),
		Color3.fromRGB(30, 31, 38)
	)

	-- The other towers: low and near, so you look down on them; a few tall ones at a distance.
	local CELL = 110
	for gx = -5, 5 do
		for gz = -5, 5 do
			local dx, dz = gx * CELL + cityRng:NextNumber(-15, 15), gz * CELL + cityRng:NextNumber(-15, 15)
			if math.abs(dx) < 200 and math.abs(dz) < 230 then
				continue
			end
			local reach = math.max(math.abs(dx), math.abs(dz))
			local top = if reach < 300
				then cityRng:NextNumber(-300, -70)
				elseif reach < 420 then cityRng:NextNumber(-220, 20)
				else cityRng:NextNumber(-120, 170)
			local width, depth = cityRng:NextNumber(40, 70), cityRng:NextNumber(40, 70)
			local cx, cz = centerX + dx, centerZ + dz
			local shade = cityRng:NextNumber(0.75, 1.15)
			cityPart(
				"Tower",
				Vector3.new(width, top - CITY_BOTTOM, depth),
				CFrame.new(cx, (top + CITY_BOTTOM) / 2, cz),
				Color3.fromRGB(58 * shade, 66 * shade, 92 * shade)
			)
			-- Lit bands on the face toward the Gala.
			local alongX = math.abs(dx) > math.abs(dz)
			for _ = 1, 3 do
				local y = cityRng:NextNumber(math.max(CITY_BOTTOM + 20, top - 110), top - 8)
				if alongX then
					lit(
						"Windows",
						Vector3.new(0.4, 3, depth * 0.8),
						CFrame.new(cx - math.sign(dx) * (width / 2 + 0.2), y, cz)
					)
				else
					lit(
						"Windows",
						Vector3.new(width * 0.8, 3, 0.4),
						CFrame.new(cx, y, cz - math.sign(dz) * (depth / 2 + 0.2))
					)
				end
			end
		end
	end

	-- A test spawn so a playtest starts in the grand lobby.
	for _, other in workspace:GetDescendants() do
		if other:IsA("SpawnLocation") then
			other.Enabled = false
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TestSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(15, 0.5, 100)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = objects

	-- Night outside, with a warm dusk-like glow inside (STYLE_QUESTIONS: night with nice ambient light). The art pass refines it.
	Lighting.ClockTime = 20.5
	Lighting.Ambient = Color3.fromRGB(135, 105, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(78, 86, 125)
	Lighting.Brightness = 1.2
	Lighting.ExposureCompensation = 0.35
	-- Thin air and haze: the Gala is high above the city.
	local oldAtmosphere = Lighting:FindFirstChild("GalaAtmosphere")
	if oldAtmosphere then
		oldAtmosphere:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "GalaAtmosphere"
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(205, 175, 190)
	atmosphere.Decay = Color3.fromRGB(95, 80, 120)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	-- Checks -----------------------------------------------------------------------------------------------------------------------------------
	local function count(tagName: string): number
		local total = 0
		for _, instance in CollectionService:GetTagged(tagName) do
			if instance:IsDescendantOf(root) then
				total += 1
			end
		end
		return total
	end
	local counts = GameConfig.Map.Counts
	check(
		count(Tag.InsertionPoint) == counts.InsertionPoint,
		`InsertionPoint {count(Tag.InsertionPoint)}/{counts.InsertionPoint}`
	)
	check(count(Tag.VaultSpawn) == counts.VaultSpawn, `VaultSpawn {count(Tag.VaultSpawn)}/{counts.VaultSpawn}`)
	check(
		count(Tag.ExtractionSite) == counts.ExtractionSite,
		`ExtractionSite {count(Tag.ExtractionSite)}/{counts.ExtractionSite}`
	)
	check(count(Tag.KeycardDoor) == counts.KeycardDoor, `KeycardDoor {count(Tag.KeycardDoor)}/{counts.KeycardDoor}`)
	check(count(Tag.ZoneVolume) == zoneCount, `ZoneVolume {count(Tag.ZoneVolume)}/{zoneCount}`)
	local nodeRange = GameConfig.Map.NPCNodeCount
	check(
		#specs >= nodeRange.Min and #specs <= nodeRange.Max,
		`NPCNode {#specs} (want {nodeRange.Min} to {nodeRange.Max})`
	)

	local spacingOk = true
	for i = 1, #Layout.insertion do
		for j = i + 1, #Layout.insertion do
			local a, b = Layout.insertion[i], Layout.insertion[j]
			if Vector2.new(a.x - b.x, a.z - b.z).Magnitude < GameConfig.Map.InsertionMinSpacing then
				spacingOk = false
				print(`[Gala]      {a.id} and {b.id} are too close`)
			end
		end
	end
	check(spacingOk, `InsertionPoints are at least {GameConfig.Map.InsertionMinSpacing} studs apart`)

	local extractionOk = true
	for _, site in Layout.extraction do
		for _, vault in Layout.vaults do
			local a = Vector3.new(site.x, levels[site.level], site.z)
			local b = Vector3.new(vault.x, levels[vault.level], vault.z)
			if (a - b).Magnitude < GameConfig.Map.MinExtractionPathDistanceFromVault then
				extractionOk = false
				print(`[Gala]      {site.id} is only {math.floor((a - b).Magnitude)} studs from {vault.id}`)
			end
		end
	end
	check(
		extractionOk,
		`Every extraction site is at least {GameConfig.Map.MinExtractionPathDistanceFromVault} studs from every vault`
	)

	-- Spec 4.4: every Tier 1+ zone has at least two entrances. A room nested inside another, or a vault wing, is reached
	-- through a single guarded door on purpose (SPEC-QUESTION), so they are listed apart.
	local entrancesOk = true
	local nestedSingles: { string } = {}
	for _, room in rooms do
		if room.tier >= 1 and (doorsPerRoom[room.id] or 0) < GameConfig.Map.MinEntrancesPerRestrictedZone then
			if room.parent or string.find(room.id, "vault") then
				table.insert(nestedSingles, room.id)
			else
				entrancesOk = false
				print(`[Gala]      {room.name} has {doorsPerRoom[room.id] or 0} doorway(s)`)
			end
		end
	end
	check(
		entrancesOk,
		`Every Tier 1+ room has {GameConfig.Map.MinEntrancesPerRestrictedZone}+ doorways (nested and vault rooms aside)`
	)
	print(`[Gala]      single-door guarded rooms: {table.concat(nestedSingles, ", ")}`)

	print(
		`[Gala] {#rooms} rooms, {zoneCount} zone volumes, {wallCount} wall lines, {gateCount} clearance doors, {keycardCount} keycard doors`
	)
	print(
		`[Gala] {propCount} props, {#specs} NPC nodes, {made} parts, {string.format("%.1f", os.clock() - started)} s, {problems} problem(s)`
	)

	ChangeHistoryService:SetWaypoint("Build Gala")
	return problems
end

return Build
