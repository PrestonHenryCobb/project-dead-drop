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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local City = require(script.Parent.City)
local Layout = require(script.Parent.Layout)
-- Studio caches required modules, so a rebuild after a config change can put a fresh copy of Shared next to this
-- script, named SharedOverride (see the build-map skill).
local Shared = script.Parent:FindFirstChild("SharedOverride") or ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tag = Enums.Tag

type Rect = { x1: number, z1: number, x2: number, z2: number }
type Room = Layout.Room
type Piece = { room: Room, rect: Rect, index: number }
-- A gap in a wall: a doorway (door), a window (window), or, with neither, an opening in a railing (a stair's arrival
-- on a gallery, a gondola dock, a rounded void corner).
type Gap = { center: number, width: number, door: Layout.Door?, window: Layout.Window? }
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
local BARRIER_H = 9 -- glass at the open edge of a terrace or deck: higher than a jump (about 7.2 studs), over a long drop
local GAP_H = 10 -- doorway height (an arched doorway rises a further half its width at the middle)
local DOOR_H = 13 -- a clearance or keycard door's opening: taller than an ordinary doorway, so it reads as important
local LEAF_T = 0.6 -- a door leaf's thickness
local DOOR_POST_W = 1.2 -- the posts either side of a doorway between tiers; door leaves hang between them
local SIGN_W, SIGN_H = 3.6, 1.1 -- a doorway sign over a doorway
local STAIR_SIGN_W, STAIR_SIGN_H, STAIR_SIGN_Y = 6, 1.4, 9 -- a sign hanging over each end of a stair, and its height
local SIGN_PIXELS = 50 -- SurfaceGui resolution on signs
local EXIT_SIGN_REACH = 30 -- studs: a doorway gets an EXIT sign when a stair end is this close beyond it
local HANDLE_LOW, HANDLE_HIGH = 2.5, 8 -- a door handle bar's bottom and top, above the floor
local ARCH_SLICE = 1 -- studs: the infill over an arch is built in vertical slices this wide
local GLASS_SILL, GLASS_HEAD = 3, 15 -- a glass window's sill and head heights above the floor
-- A serving hatch's opening: low and short, so a body (about 5 studs tall) can see through it but never climb through.
local HATCH_SILL, HATCH_HEAD = 4, 8
local WINDOW_CLEAR = 3 -- studs props keep clear of a window, on each side of the wall
local CURVE_SEGMENT = 2.5 -- studs: curved walls and railings are built from straight pieces about this long
local FOUNTAIN_STATUE_H = 11 -- studs: the porcelain statue on top of the atrium fountain
local SLAB = 2
local RAMP_W = 6 -- a stair's width; it climbs one stud in two
-- A switchback climbs half the height in each of two legs, side by side with a gap, joined by a landing.
local LANDING, LANE_GAP = 6, 2
local HEADROOM = 7 -- studs of clear height a body needs above a step; the floor above is cut where it is less
local STAIR_LANDING_CLEAR = 6 -- studs of open floor kept at the foot and head of every stair
local STAIR_GAP = 2 -- studs kept between one stair (or its opening) and another
local STAIR_RAIL_H = 3 -- the handrails along the sides of a flight
local TRUSS_DEPTH, TRUSS_BAY = 8, 6 -- the steel truss under a bridge: how deep, and how long each bay
local VENT_OPENING_H = 6 -- a vent grate's opening; players fit through its 3-stud width, NPCs (radius 2) never path it
local GONDOLA_RAIL_H = 13 -- the gondola's overhead rail, above its floor
local GONDOLA_DOCK_CLEAR = 8 -- studs of floor kept clear in front of each gondola dock
local ZONE_PAD = 2
local ZONE_H = 24 -- a zone's height where there is no storey above it
local GALLERY_POST_SPACING = 16 -- studs between the posts under a gallery's edge
local STEEL_POST = Color3.fromRGB(70, 74, 86)
-- The Gala's palette follows the city round it: a slate-blue shell, warm stone inside, steel and city-blue glass.
local SHELL = Color3.fromRGB(78, 82, 98) -- outside walls and roofs
local INTERIOR_WALL = Color3.fromRGB(138, 124, 112)
local FLOOR_WARM = Color3.fromRGB(96, 84, 78) -- indoor floors take their tier's colour, mixed toward this
local DECK = Color3.fromRGB(92, 94, 106) -- terraces, decks and the roof
local RAIL_GREY = Color3.fromRGB(96, 100, 114)
local CITY_GLASS = Color3.fromRGB(110, 140, 180)
local MIRROR = Color3.fromRGB(150, 156, 168) -- one-way glass seen from outside (OneWayGlassController clears it inside)
local COUNTER = Color3.fromRGB(70, 66, 64) -- the counter top under a serving hatch
local DOOR_FRAME = Color3.fromRGB(46, 42, 44) -- door frames and the frames of glass door leaves
-- Signs: dark LED panels. EXIT and stair signs are white, extraction cyan, so none of them reads as a tier colour.
local SIGN_PANEL = Color3.fromRGB(20, 22, 26)
local SIGN_EXIT = Color3.fromRGB(235, 240, 245)
local SIGN_EXTRACTION = Color3.fromRGB(80, 220, 235)
local SIGN_PLAIN = Color3.fromRGB(215, 215, 215)
local DOOR_WOOD = Color3.fromRGB(78, 56, 44) -- a Security door's solid leaves
local DOOR_STEEL = Color3.fromRGB(104, 108, 118) -- an Executive or vault-wing door's heavy leaves
local EPS = 1e-4

local NODE_MARGIN = 8 -- studs a node keeps from a room's walls
-- Dense enough that, at GameConfig.NPC.NodeCapacity NPCs a node, 200 NPCs always have free places to walk to.
local NODE_SPACING = { [0] = 30, [1] = 32, [2] = 36, [3] = 36 }
local LIGHT_SPACING = 55 -- studs between ceiling lights in a room
local LIGHT_CAP = 110 -- the most lights in the map (each is a dynamic light on a phone)
local DOOR_CLEAR = 7 -- studs props keep clear in front of a doorway
local CRATES_PER_ROOM = 14 -- crates tried in a storage room; more choke the routes NPCs need
local PLACE_STEP = 3 -- studs between the spots tried along a wall for a placed object
local PLACE_SPREAD = 60 -- placed objects in one room are spread up to this far apart
local NODE_PROP_CLEAR = 3 -- studs a node keeps from a prop
-- Where a node tries next when its grid spot is taken by a prop, nearest first (studs along x and z).
local NODE_NUDGES = {
	{ 0, 0 },
	{ 0, 4 },
	{ 0, -4 },
	{ 4, 0 },
	{ -4, 0 },
	{ 0, 8 },
	{ 0, -8 },
	{ 8, 0 },
	{ -8, 0 },
	{ 4, 4 },
	{ -4, -4 },
	{ 4, -4 },
	{ -4, 4 },
}

local ACTIVITIES: { [number]: { string } } = {
	[0] = { "Walk", "Walk", "Idle", "Talk", "Sit", "Lean", "Drink" },
	[1] = { "Walk", "Work", "Work", "Idle", "Talk", "Drink" },
	[2] = { "Guard", "Guard", "Walk", "Idle" },
	[3] = { "Walk", "Idle", "Talk", "Drink", "Sit" },
}
local OUTDOOR_ACTIVITIES = { "Walk", "Walk", "Idle", "Talk", "Drink" }

local Build = {}

-- An indoor room's wall height: a full storey unless the layout gives it a lower one (a bridge).
local function roomHeight(room: Layout.Room): number
	return room.height or WALL_H
end

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
	-- Levels that are not in levelOrder are gallery levels: open floors between the storeys (Layout.levels).
	local allLevels = table.clone(levelOrder)
	local isGalleryLevel: { [string]: boolean } = {}
	for name in levels do
		if not table.find(levelOrder, name) then
			table.insert(allLevels, name)
			isGalleryLevel[name] = true
		end
	end
	-- The full level a gallery stands on (the highest one below it) and the one over its head.
	local function storeyBelow(y: number): string
		local best = levelOrder[1]
		for _, name in levelOrder do
			if levels[name] < y and levels[name] > levels[best] then
				best = name
			end
		end
		return best
	end
	local function storeyAbove(y: number): number?
		local best: number? = nil
		for _, name in levelOrder do
			if levels[name] > y and (best == nil or levels[name] < best) then
				best = levels[name]
			end
		end
		return best
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
		assert(
			(room.kind == "gallery") == (isGalleryLevel[room.level] == true),
			`Room {room.id}: galleries, and only galleries, go on gallery levels`
		)
		roomById[room.id] = room
	end

	local voidRects: { [string]: { Rect } } = {}
	for _, void in Layout.voids do
		voidRects[void.level] = voidRects[void.level] or {}
		table.insert(voidRects[void.level], toRect(void.rect))
	end

	local piecesByLevel: { [string]: { Piece } } = {}
	local piecesOfRoom: { [string]: { Piece } } = {}
	for _, name in allLevels do
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
	local doorClear: { [string]: { Rect } } = {} -- the floor in front of each doorway, which stairs must keep off
	for _, name in allLevels do
		reserved[name] = {}
		doorClear[name] = {}
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
				and (door.line == nil or math.abs(edge.line - door.line) < EPS)
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
		if not (ra.duct or rb.duct) then
			table.insert(doorPoints, { level = best.level, x = x, z = z, nx = nx, nz = nz, a = ra, b = rb })
		end
		local clear: Rect = {
			x1 = x - (if best.axis == "x" then width / 2 + 2 else DOOR_CLEAR),
			z1 = z - (if best.axis == "x" then DOOR_CLEAR else width / 2 + 2),
			x2 = x + (if best.axis == "x" then width / 2 + 2 else DOOR_CLEAR),
			z2 = z + (if best.axis == "x" then DOOR_CLEAR else width / 2 + 2),
		}
		table.insert(reserved[best.level], clear)
		table.insert(doorClear[best.level], clear)
	end
	check(doorsUnplaced == 0, `Every door placed ({#Layout.doors - doorsUnplaced}/{#Layout.doors})`)

	-- Windows (MAP_BRIEF_REPLAN stage 2): a gap in a shared wall like a doorway, but filled with a sill, a pane or a
	-- hatch, and never a route. A window may not overlap a doorway on the same wall.
	local windowsUnplaced = 0
	for _, window in Layout.windows do
		local ra, rb = roomById[window.a], roomById[window.b]
		local best: Edge? = nil
		for _, edge in edges do
			if
				edge.kind == "shared"
				and ((edge.roomA == ra and edge.roomB == rb) or (edge.roomA == rb and edge.roomB == ra))
				and (window.line == nil or math.abs(edge.line - window.line) < EPS)
				and window.at >= edge.a
				and window.at <= edge.b
			then
				best = edge
			end
		end
		if not best then
			windowsUnplaced += 1
			print(`[Gala]      window {window.a} / {window.b} at {window.at}: no shared wall there`)
			continue
		end
		local width = math.min(window.width, best.b - best.a - 2)
		local center = math.clamp(window.at, best.a + width / 2 + 1, best.b - width / 2 - 1)
		local clash = false
		for _, gap in best.gaps do
			if math.abs(gap.center - center) < (gap.width + width) / 2 + 1 then
				clash = true
			end
		end
		if clash then
			windowsUnplaced += 1
			print(`[Gala]      window {window.a} / {window.b} at {window.at} overlaps a doorway`)
			continue
		end
		table.insert(best.gaps, { center = center, width = width, window = window })
		-- Props keep off the wall in front of it, on both sides.
		local x, z = if best.axis == "x" then center else best.line, if best.axis == "x" then best.line else center
		local halfAlong, halfAcross = width / 2, WINDOW_CLEAR
		table.insert(reserved[best.level], {
			x1 = x - (if best.axis == "x" then halfAlong else halfAcross),
			z1 = z - (if best.axis == "x" then halfAcross else halfAlong),
			x2 = x + (if best.axis == "x" then halfAlong else halfAcross),
			z2 = z + (if best.axis == "x" then halfAcross else halfAlong),
		})
	end
	check(windowsUnplaced == 0, `Every window placed ({#Layout.windows - windowsUnplaced}/{#Layout.windows})`)

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
	for _, name in allLevels do
		rampFootprints[name] = {}
		rampHoles[name] = {}
	end
	-- A stair climbs from its level to `to` (the next full level if not given): a full storey or half of one, onto a
	-- gallery. It always climbs one stud in two, so a plain run is twice its rise and a switchback's legs half that.
	type Dims = { rise: number, run: number, legRise: number, legRun: number }
	local function stairDims(ramp: Layout.Ramp): Dims
		local rise = levels[ramp.to or nextLevel[ramp.from]] - levels[ramp.from]
		return { rise = rise, run = rise * 2, legRise = rise / 2, legRun = rise }
	end
	-- How wide and long a stair's footprint is: one lane for a plain run, two lanes and a landing for a switchback.
	local function rampSize(ramp: Layout.Ramp): (number, number)
		local dims = stairDims(ramp)
		if ramp.turn then
			return RAMP_W * 2 + LANE_GAP, dims.legRun + LANDING
		end
		return RAMP_W, dims.run
	end
	-- A rect given in the stair's own terms: `along` studs up the climb from its start, `across` studs sideways from its
	-- centre line (positive is the side a switchback's upper leg is on).
	local function stairRect(ramp: Layout.Ramp, along1: number, along2: number, across1: number, across2: number): Rect
		local dx, dz = dirVector(ramp.dir)
		local px, pz = dz, -dx
		local ax1, az1 = ramp.x + dx * along1 + px * across1, ramp.z + dz * along1 + pz * across1
		local ax2, az2 = ramp.x + dx * along2 + px * across2, ramp.z + dz * along2 + pz * across2
		return { x1 = math.min(ax1, ax2), z1 = math.min(az1, az2), x2 = math.max(ax1, ax2), z2 = math.max(az1, az2) }
	end
	-- The floor above is cut only where someone on the stair would hit their head: where the step is higher than the
	-- slab's underside less HEADROOM. A plain stair needs it at its top end; a switchback over the end of its upper leg,
	-- where it arrives. Returns the opening as along and across ranges. A stair onto a gallery climbs up beside it and
	-- needs no opening.
	local lane = RAMP_W / 2 + LANE_GAP / 2
	local function holeSpan(ramp: Layout.Ramp): (number, number, number, number)
		local dims = stairDims(ramp)
		local cutFrom = dims.rise - SLAB - HEADROOM
		if ramp.turn then
			-- leg two's step is legRise * (2 - along / legRun) high
			return 0, dims.legRun * (2 - cutFrom / dims.legRise), lane - RAMP_W / 2, lane + RAMP_W / 2
		end
		return dims.run * cutFrom / dims.rise, dims.run, -RAMP_W / 2, RAMP_W / 2
	end

	type Stair = {
		ramp: Layout.Ramp,
		upper: string,
		dims: Dims,
		ontoGallery: boolean,
		footprint: Rect,
		entry: Rect,
		hole: Rect?,
		arrival: Rect,
	}
	local stairs: { Stair } = {}
	for _, ramp in Layout.ramps do
		local width, length = rampSize(ramp)
		local dims = stairDims(ramp)
		local upper = ramp.to or nextLevel[ramp.from]
		local ontoGallery = isGalleryLevel[upper] == true
		local h1, h2, c1, c2 = holeSpan(ramp)
		local entryAcross = if ramp.turn then -lane else 0
		local stair: Stair = {
			ramp = ramp,
			upper = upper,
			dims = dims,
			ontoGallery = ontoGallery,
			footprint = stairRect(ramp, 0, length, -width / 2, width / 2),
			-- the floor someone steps off before climbing, and the floor they arrive on at the top
			entry = stairRect(ramp, -STAIR_LANDING_CLEAR, 0, entryAcross - RAMP_W / 2, entryAcross + RAMP_W / 2),
			hole = if ontoGallery then nil else stairRect(ramp, h1, h2, c1, c2),
			arrival = if ramp.turn
				then stairRect(ramp, -STAIR_LANDING_CLEAR, 0, c1, c2)
				else stairRect(ramp, dims.run, dims.run + STAIR_LANDING_CLEAR, c1, c2),
		}
		table.insert(stairs, stair)
		table.insert(rampFootprints[ramp.from], stair.footprint)
		if stair.hole then
			table.insert(rampHoles[upper], stair.hole)
		end
		-- Props and nodes keep off the stair, its opening and both ends.
		for _, r in { stair.footprint, stair.entry } do
			table.insert(reserved[ramp.from], inflate(r, 3))
		end
		table.insert(reserved[upper], inflate(stair.arrival, 3))
		if stair.hole then
			table.insert(reserved[upper], inflate(stair.hole, 3))
		end
	end

	-- Stair self-check. On every level, a stair's body and the floor at its foot, and its opening and the floor at its
	-- head, must sit wholly inside one room, keep off every doorway, and never touch another stair's body, opening or
	-- ends. This is what catches stairs passing through each other and openings cut across walls.
	-- Is `r` wholly covered by the floor of one room (a room can be several pieces round a nested room or a void)?
	local function insideOneRoom(level: string, r: Rect): boolean
		for _, room in rooms do
			if room.level == level then
				local left = { r }
				for _, piece in piecesOfRoom[room.id] do
					left = subtract(left, piece.rect)
				end
				if #left == 0 then
					return true
				end
			end
		end
		return false
	end
	local function stairName(s: Stair): string
		return `{s.ramp.from}->{s.upper} stair at ({s.ramp.x}, {s.ramp.z})`
	end
	local stairsOk = true
	local function stairProblem(message: string)
		stairsOk = false
		print(`[Gala]      {message}`)
	end
	type StairArea = { stair: Stair, what: string, rect: Rect }
	local areasByLevel: { [string]: { StairArea } } = {}
	for _, name in allLevels do
		areasByLevel[name] = {}
	end
	for _, s in stairs do
		for _, area in
			{
				{ level = s.ramp.from, what = "body", rect = s.footprint },
				{ level = s.ramp.from, what = "foot", rect = s.entry },
				{ level = s.upper, what = "opening", rect = s.hole :: Rect },
				{ level = s.upper, what = "head", rect = s.arrival },
			}
		do
			if area.what == "opening" and not s.hole then
				continue
			end
			if not insideOneRoom(area.level, area.rect) then
				stairProblem(`{stairName(s)}: its {area.what} crosses a wall or leaves the floor`)
			end
			for _, clear in doorClear[area.level] do
				if overlaps(area.rect, clear) then
					stairProblem(`{stairName(s)}: its {area.what} blocks a doorway`)
					break
				end
			end
			table.insert(areasByLevel[area.level], { stair = s, what = area.what, rect = area.rect })
		end
	end
	for levelName, list in areasByLevel do
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				if a.stair ~= b.stair and overlaps(inflate(a.rect, STAIR_GAP / 2), inflate(b.rect, STAIR_GAP / 2)) then
					stairProblem(
						`on {levelName}, the {a.what} of the {stairName(a.stair)} meets the {b.what} of the {stairName(
							b.stair
						)}`
					)
				end
			end
		end
	end
	-- A stair's body must not pass through a gallery floor on its way up (one it climbs onto ends at its edge).
	for _, s in stairs do
		local low, high = levels[s.ramp.from], levels[s.upper]
		for name in isGalleryLevel do
			if levels[name] > low and levels[name] <= high then
				for _, piece in piecesByLevel[name] do
					if overlaps(s.footprint, piece.rect) then
						stairProblem(`{stairName(s)}: it passes through the floor of {piece.room.name}`)
						break
					end
				end
			end
		end
	end
	check(stairsOk, `Every stair is clear of walls, doorways and other stairs ({#stairs} stairs)`)

	-- Features: water, islands, bridges, skylights and set pieces that are not rooms (Layout.features) -----------------------------
	local WATER = Color3.fromRGB(70, 135, 190)
	local GRASS = Color3.fromRGB(90, 135, 80)
	local BRONZE = Color3.fromRGB(190, 125, 60)
	local DARK_WOOD = Color3.fromRGB(100, 72, 52)
	local STONE_GREY = Color3.fromRGB(170, 170, 175)
	local GLASS = Color3.fromRGB(190, 220, 240)
	local STEEL = Color3.fromRGB(70, 74, 86)

	local function featureTree(level: string, x: number, z: number, lift: number)
		local y = levels[level] + lift
		part(propsFolder, "Tree", Vector3.new(1.6, 6, 1.6), CFrame.new(x, y + 3, z), Color3.fromRGB(90, 65, 45))
		local canopy = part(propsFolder, "Canopy", Vector3.new(10, 8, 10), CFrame.new(x, y + 9.5, z), GRASS)
		canopy.Shape = Enum.PartType.Ball
		canopy.CanCollide = false
	end

	-- Set pieces NPC nodes keep off (the fountain).
	local solidFeatures: { [string]: { Rect } } = {}
	for _, name in allLevels do
		solidFeatures[name] = {}
	end

	-- The atrium fountain: a tiered porcelain fountain in blue and white with gold trim, water falling from its bowls,
	-- a plaque, and on top a porcelain statue cast from a Roblox avatar (its shape only: clothes, colours, textures and
	-- face are stripped, and it is no character: no Humanoid, no collision, nothing to scan).
	local PORCELAIN = Color3.fromRGB(240, 238, 232)
	local COBALT = Color3.fromRGB(32, 66, 150)
	local GOLD = Color3.fromRGB(212, 172, 74)
	local FOUNTAIN_WATER = Color3.fromRGB(110, 180, 225)
	local function glaze(p: BasePart)
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.12
	end
	-- A flat disc (a cylinder standing upright) from y1 to y2 above the floor.
	local function disc(name: string, x: number, z: number, radius: number, y1: number, y2: number, color: Color3): Part
		local p = part(
			propsFolder,
			name,
			Vector3.new(y2 - y1, radius * 2, radius * 2),
			CFrame.new(x, y1 + (y2 - y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			color
		)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- A ring of short pieces round (x, z): a bowl's rim.
	local function ring(
		name: string,
		x: number,
		z: number,
		radius: number,
		y1: number,
		y2: number,
		depth: number,
		color: Color3
	)
		local count = math.max(12, math.ceil(2 * math.pi * radius / CURVE_SEGMENT))
		for i = 1, count do
			local t0, t1 = 2 * math.pi * (i - 1) / count, 2 * math.pi * i / count
			local p0 = Vector3.new(x + radius * math.cos(t0), 0, z + radius * math.sin(t0))
			local p1 = Vector3.new(x + radius * math.cos(t1), 0, z + radius * math.sin(t1))
			local piece = part(
				propsFolder,
				name,
				Vector3.new((p1 - p0).Magnitude + 0.3, y2 - y1, depth),
				CFrame.fromMatrix(
					Vector3.new((p0.X + p1.X) / 2, y1 + (y2 - y1) / 2, (p0.Z + p1.Z) / 2),
					(p1 - p0).Unit,
					Vector3.yAxis
				),
				color
			)
			glaze(piece)
		end
	end
	-- Water spilling over a bowl's edge, as particles falling from a ring.
	local function spill(x: number, z: number, radius: number, y: number, rate: number)
		local emitterPart = part(
			propsFolder,
			"FountainSpill",
			Vector3.new(0.2, radius * 2, radius * 2),
			CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
			FOUNTAIN_WATER
		)
		emitterPart.Shape = Enum.PartType.Cylinder
		ghost(emitterPart)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Shape = Enum.ParticleEmitterShape.Cylinder
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		emitter.Color = ColorSequence.new(FOUNTAIN_WATER)
		emitter.LightEmission = 0.3
		emitter.Transparency = NumberSequence.new(0.35, 1)
		emitter.Size = NumberSequence.new(0.35, 0.15)
		emitter.Lifetime = NumberRange.new(0.6, 0.9)
		emitter.Speed = NumberRange.new(1, 2)
		emitter.Acceleration = Vector3.new(0, -35, 0)
		emitter.Rate = rate
		emitter.Parent = emitterPart
	end
	local function statue(userId: number, x: number, z: number, footY: number, height: number)
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromUserId(userId)
		end)
		if not ok or not model then
			print(`[Gala]      fountain statue: could not load avatar {userId} ({model}); a plain figure stands in`)
			local plain = part(
				propsFolder,
				"Statue",
				Vector3.new(2.5, height, 1.6),
				CFrame.new(x, footY + height / 2, z),
				PORCELAIN
			)
			glaze(plain)
			return
		end
		local figure = model :: Model
		-- Accessories are only welded on once a character spawns: put each one where its attachment says.
		for _, accessory in figure:GetChildren() do
			if accessory:IsA("Accessory") then
				local handle = accessory:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					for _, attachment in handle:GetChildren() do
						if attachment:IsA("Attachment") then
							local target = figure:FindFirstChild(attachment.Name, true)
							if target and target:IsA("Attachment") and target.Parent ~= handle then
								handle.CFrame = target.WorldCFrame * attachment.CFrame:Inverse()
								break
							end
						end
					end
				end
			end
		end
		for _, item in figure:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide = false
				item.CanQuery = false
				item.CanTouch = false
				item.Color = PORCELAIN
				glaze(item)
				if item:IsA("MeshPart") then
					item.TextureID = ""
				end
			elseif item:IsA("SpecialMesh") then
				item.TextureId = ""
			end
		end
		for _, item in figure:GetDescendants() do
			if
				item:IsA("Clothing")
				or item:IsA("ShirtGraphic")
				or item:IsA("Decal")
				or item:IsA("BodyColors")
				or item:IsA("Humanoid")
				or item:IsA("LuaSourceContainer")
				or item:IsA("FaceControls")
			then
				item:Destroy()
			end
		end
		figure.Name = "Statue"
		local _, size = figure:GetBoundingBox()
		figure:ScaleTo(height / size.Y)
		-- Stand it on the plinth, facing +z (the lobby): move its bounding box, and the model with it.
		local box, scaled = figure:GetBoundingBox()
		local target = CFrame.new(x, footY + scaled.Y / 2, z) * CFrame.Angles(0, math.pi, 0)
		figure:PivotTo(target * (box:Inverse() * figure:GetPivot()))
		figure.Parent = propsFolder
	end
	local function fountain(feature: Layout.Feature)
		local x, z, y = feature.x :: number, feature.z :: number, levels[feature.level]
		local radius = feature.radius or 18
		-- Base step, outer basin, its rim and water.
		glaze(disc("FountainStep", x, z, radius + 2, y, y + 0.6, COBALT))
		glaze(disc("FountainBasin", x, z, radius, y + 0.6, y + 1.4, PORCELAIN))
		ring("FountainRim", x, z, radius, y + 0.6, y + 3.4, 1.2, PORCELAIN)
		ring("FountainRimBand", x, z, radius, y + 3.4, y + 3.8, 1.6, COBALT)
		local water = disc("FountainWater", x, z, radius - 0.7, y + 1.4, y + 2.6, FOUNTAIN_WATER)
		water.Material = Enum.Material.Glass
		water.Transparency = 0.3
		water.CanCollide = false
		-- Column, middle bowl, upper column, upper bowl, and the plinth the statue stands on.
		glaze(disc("FountainColumn", x, z, 2.5, y + 1.4, y + 8, PORCELAIN))
		glaze(disc("FountainBand", x, z, 2.7, y + 4.4, y + 5.2, COBALT))
		glaze(disc("FountainBowl", x, z, 9, y + 8, y + 9, PORCELAIN))
		ring("FountainBowlRim", x, z, 9, y + 9, y + 10, 0.8, COBALT)
		local midWater = disc("FountainWater", x, z, 8.5, y + 9, y + 9.6, FOUNTAIN_WATER)
		midWater.Material = Enum.Material.Glass
		midWater.Transparency = 0.3
		glaze(disc("FountainColumn", x, z, 1.6, y + 9, y + 13, PORCELAIN))
		glaze(disc("FountainBowl", x, z, 5, y + 13, y + 13.8, PORCELAIN))
		ring("FountainBowlRim", x, z, 5, y + 13.8, y + 14.6, 0.6, GOLD)
		glaze(disc("FountainPlinth", x, z, 2.4, y + 13.8, y + 16.5, PORCELAIN))
		glaze(disc("FountainPlinthBand", x, z, 2.6, y + 16.1, y + 16.5, GOLD))
		spill(x, z, 9.3, y + 9.8, 90)
		spill(x, z, 5.2, y + 14.4, 50)
		if feature.userId then
			statue(feature.userId, x, z, y + 16.5, FOUNTAIN_STATUE_H)
		end
		-- The plaque, on the rim facing +z (the lobby).
		local plaque = part(
			propsFolder,
			"FountainPlaque",
			Vector3.new(8, 2.2, 0.4),
			CFrame.new(x, y + 2.2, z + radius + 0.85),
			COBALT
		)
		glaze(plaque)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		gui.Parent = plaque
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = GOLD
		label.Font = Enum.Font.Garamond
		label.TextScaled = true
		label.Text = feature.text or ""
		label.Parent = gui
		table.insert(solidFeatures[feature.level], {
			x1 = x - radius - 2,
			z1 = z - radius - 2,
			x2 = x + radius + 2,
			z2 = z + radius + 2,
		})
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
		elseif feature.kind == "fountain" then
			fountain(feature)
			local radius = (feature.radius or 18) + 3
			table.insert(reserved[level], {
				x1 = (feature.x :: number) - radius,
				z1 = (feature.z :: number) - radius,
				x2 = (feature.x :: number) + radius,
				z2 = (feature.z :: number) + radius,
			})
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
		elseif feature.kind == "truss" and r then
			-- A steel Warren truss under a bridge's floor: a chord along each side at the top and bottom, posts and
			-- alternating diagonals between them, a plate across the bottom, and brackets where it meets each building.
			local top, bottom = y - SLAB, y - SLAB - TRUSS_DEPTH
			local alongX = (r.x2 - r.x1) >= (r.z2 - r.z1)
			local a1, a2 = if alongX then r.x1 else r.z1, if alongX then r.x2 else r.z2
			local function point(along: number, side: number, height: number): Vector3
				return if alongX then Vector3.new(along, height, side) else Vector3.new(side, height, along)
			end
			local function member(from: Vector3, to: Vector3, thickness: number)
				part(
					propsFolder,
					"Truss",
					Vector3.new(thickness, thickness, (to - from).Magnitude),
					CFrame.lookAt((from + to) / 2, to),
					STEEL
				)
			end
			local sides = if alongX then { r.z1 + 0.5, r.z2 - 0.5 } else { r.x1 + 0.5, r.x2 - 0.5 }
			local bays = math.max(1, math.floor((a2 - a1) / TRUSS_BAY + 0.5))
			local bay = (a2 - a1) / bays
			for _, side in sides do
				member(point(a1, side, top - 0.5), point(a2, side, top - 0.5), 1)
				member(point(a1, side, bottom), point(a2, side, bottom), 1)
				for i = 0, bays do
					local at = a1 + i * bay
					member(point(at, side, top - 0.5), point(at, side, bottom), 0.8)
					if i < bays then
						local nextAt = at + bay
						if i % 2 == 0 then
							member(point(at, side, top - 0.5), point(nextAt, side, bottom), 0.6)
						else
							member(point(at, side, bottom), point(nextAt, side, top - 0.5), 0.6)
						end
					end
				end
			end
			local width = if alongX then r.z2 - r.z1 else r.x2 - r.x1
			local mid = if alongX then (r.z1 + r.z2) / 2 else (r.x1 + r.x2) / 2
			part(
				propsFolder,
				"TrussPlate",
				if alongX then Vector3.new(a2 - a1, 0.5, width) else Vector3.new(width, 0.5, a2 - a1),
				CFrame.new(point((a1 + a2) / 2, mid, bottom - 0.25)),
				STEEL
			)
			for _, at in { a1 + 1, a2 - 1 } do
				part(
					propsFolder,
					"TrussBracket",
					if alongX
						then Vector3.new(2, TRUSS_DEPTH + 4, width + 2)
						else Vector3.new(width + 2, TRUSS_DEPTH + 4, 2),
					CFrame.new(point(at, mid, top - (TRUSS_DEPTH + 4) / 2)),
					STEEL
				)
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

	-- Ziplines (spec 4.3): a mast at the top and a post at the bottom, tagged ZiplineAnchor with ZiplineId and End, and
	-- the cable between their tops. ZiplineService runs the rides.
	for _, line in Layout.ziplines do
		local function anchor(spot: Layout.ZiplineEnd, endName: string): Vector3
			local base = Vector3.new(spot.x, levels[spot.level], spot.z)
			local mast = part(
				objects,
				"ZiplineMast",
				Vector3.new(1.2, spot.mast, 1.2),
				CFrame.new(base + Vector3.new(0, spot.mast / 2, 0)),
				STEEL_POST
			)
			tag(mast, Tag.ZiplineAnchor, { ZiplineId = line.id, End = endName })
			table.insert(reserved[spot.level], { x1 = spot.x - 4, z1 = spot.z - 4, x2 = spot.x + 4, z2 = spot.z + 4 })
			return base + Vector3.new(0, spot.mast, 0)
		end
		local top, bottom = anchor(line.top, "Top"), anchor(line.bottom, "Bottom")
		local cable = part(
			geometry,
			"ZiplineCable",
			Vector3.new(0.3, 0.3, (bottom - top).Magnitude),
			CFrame.lookAt((top + bottom) / 2, bottom),
			Color3.fromRGB(30, 30, 34)
		)
		cable.CanCollide = false
		cable.CanQuery = false
	end

	-- The gondola: a railed platform hanging from an overhead rail, docked at its start; a call button at each dock.
	-- GondolaService moves it. Tagged Gondola (on the floor, with Start and End positions) and GondolaCall (End).
	do
		local g = Layout.gondola
		local y = levels[g.level]
		local startPos = Vector3.new(g.fromX + g.length / 2, y - 0.5, g.z)
		local endPos = Vector3.new(g.toX - g.length / 2, y - 0.5, g.z)
		local railY = y + GONDOLA_RAIL_H
		part(
			geometry,
			"GondolaRail",
			Vector3.new(g.toX - g.fromX, 1, 1.5),
			CFrame.new((g.fromX + g.toX) / 2, railY, g.z),
			STEEL_POST
		)
		local model = Instance.new("Model")
		model.Name = "Gondola"
		model.Parent = objects
		local floor = part(model, "GondolaFloor", Vector3.new(g.length, 1, g.width), CFrame.new(startPos), STEEL_POST)
		for _, side in { -1, 1 } do
			part(
				model,
				"GondolaRailing",
				Vector3.new(g.length, 3, 0.3),
				CFrame.new(startPos + Vector3.new(0, 2, side * (g.width / 2 - 0.15))),
				RAIL_GREY
			)
			part(
				model,
				"GondolaHanger",
				Vector3.new(0.3, GONDOLA_RAIL_H - 0.5, 0.3),
				CFrame.new(startPos + Vector3.new(0, GONDOLA_RAIL_H / 2, side * (g.width / 2 - 0.15))),
				STEEL_POST
			)
		end
		model.PrimaryPart = floor
		tag(floor, Tag.Gondola, { Start = startPos, End = endPos })
		for endName, dock in { Start = { x = g.fromX, out = -1 }, End = { x = g.toX, out = 1 } } do
			-- the button stands on the dock's floor, beside the opening
			local button = part(
				objects,
				"GondolaCall",
				Vector3.new(1, 3.5, 1),
				CFrame.new(dock.x + dock.out * 2, y + 1.75, g.z + g.width / 2 + 1.5),
				Color3.fromRGB(240, 200, 40)
			)
			button.Material = Enum.Material.Neon
			tag(button, Tag.GondolaCall, { End = endName })
			table.insert(reserved[g.level], {
				x1 = math.min(dock.x, dock.x + dock.out * GONDOLA_DOCK_CLEAR),
				z1 = g.z - g.width / 2 - 2,
				x2 = math.max(dock.x, dock.x + dock.out * GONDOLA_DOCK_CLEAR),
				z2 = g.z + g.width / 2 + 3,
			})
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
	local currentBarrier = false -- the wall being built is the glass barrier at the open edge of a terrace or deck
	local function wallPiece(edge: Edge, a: number, b: number, height: number, color: Color3)
		if b - a < 0.5 then
			return
		end
		if currentBarrier then
			local base = levels[edge.level]
			local pane = part(
				geometry,
				"Barrier",
				alongSize(edge.axis, b - a, height, 0.8),
				CFrame.new(alongPoint(edge.axis, edge.line, (a + b) / 2, base + height / 2)),
				CITY_GLASS
			)
			pane.Material = Enum.Material.Glass
			pane.Transparency = 0.6
			part(
				geometry,
				"BarrierCap",
				alongSize(edge.axis, b - a, 0.4, 1),
				CFrame.new(alongPoint(edge.axis, edge.line, (a + b) / 2, base + height + 0.2)),
				RAIL_GREY
			)
			return
		end
		if currentGlass then
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
				CITY_GLASS
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

	-- An inner vault door filling a doorway, in one of four styles (BUILD_ORDER Step 7B): a round bank door, a glass
	-- gallery door, a frosted cold-store door, or a green counting-room door.
	local function vaultDoor(edge: Edge, center: number, baseY: number, theme: string, vaultId: string)
		local width = 8
		local styles: { [string]: { color: Color3, material: Enum.Material } } = {
			bank = { color = Color3.fromRGB(150, 152, 160), material = Enum.Material.DiamondPlate },
			gallery = { color = Color3.fromRGB(175, 205, 230), material = Enum.Material.Glass },
			cold = { color = Color3.fromRGB(205, 225, 240), material = Enum.Material.Ice },
			counting = { color = Color3.fromRGB(60, 95, 70), material = Enum.Material.Metal },
		}
		local style = styles[theme] or styles.bank
		local pos = alongPoint(edge.axis, edge.line, center, baseY + GAP_H / 2)
		local slab =
			part(objects, "VaultDoor", alongSize(edge.axis, width, GAP_H, WALL_T), CFrame.new(pos), style.color)
		slab.Material = style.material
		if theme == "gallery" then
			slab.Transparency = 0.4
		end
		tag(slab, Tag.VaultDoor, { VaultId = vaultId, Theme = theme })
		local gold = Color3.fromRGB(210, 170, 70)
		if theme == "bank" then
			-- A round door face with a hub, on the vault-room side.
			for _, sign in { -1, 1 } do
				local face = part(
					trim,
					"VaultWheel",
					Vector3.new(0.6, GAP_H - 1, GAP_H - 1),
					CFrame.new(
						pos + (if edge.axis == "x" then Vector3.new(0, 0, sign) else Vector3.new(sign, 0, 0)) * 1.2
					) * (if edge.axis == "x" then CFrame.Angles(0, math.rad(90), 0) else CFrame.new()),
					gold
				)
				face.Shape = Enum.PartType.Cylinder
			end
		else
			part(trim, "VaultHandle", alongSize(edge.axis, width * 0.6, 0.6, WALL_T + 1), CFrame.new(pos), gold)
		end
	end

	-- A floor slab whose top is at topY.
	local function slab(parent: Instance, name: string, rect: Rect, topY: number, color: Color3)
		part(
			parent,
			name,
			Vector3.new(rect.x2 - rect.x1, SLAB, rect.z2 - rect.z1),
			CFrame.new((rect.x1 + rect.x2) / 2, topY - SLAB / 2, (rect.z1 + rect.z2) / 2),
			color
		)
	end

	-- Curves (MAP_BRIEF_REPLAN stage 2) ----------------------------------------------------------------------------------
	-- A curved wall, railing or glass barrier round (cx, cz) at radius r, from angle a0 to a1 (radians, measured from +x
	-- toward +z), built from short straight pieces.
	local function arc(
		level: string,
		cx: number,
		cz: number,
		r: number,
		a0: number,
		a1: number,
		style: string,
		height: number,
		color: Color3
	)
		local base = levels[level]
		local count = math.max(4, math.ceil(r * math.abs(a1 - a0) / CURVE_SEGMENT))
		for i = 1, count do
			local t0, t1 = a0 + (a1 - a0) * (i - 1) / count, a0 + (a1 - a0) * i / count
			local p0 = Vector3.new(cx + r * math.cos(t0), 0, cz + r * math.sin(t0))
			local p1 = Vector3.new(cx + r * math.cos(t1), 0, cz + r * math.sin(t1))
			local along = (p1 - p0).Unit
			local length = (p1 - p0).Magnitude + 0.3 -- a little overlap closes the joints
			local mid = (p0 + p1) / 2
			local function piece(name: string, y: number, h: number, depth: number, pieceColor: Color3): Part
				return part(
					geometry,
					name,
					Vector3.new(length, h, depth),
					CFrame.fromMatrix(Vector3.new(mid.X, base + y, mid.Z), along, Vector3.yAxis),
					pieceColor
				)
			end
			if style == "barrier" then
				local pane = piece("Barrier", height / 2, height, 0.8, CITY_GLASS)
				pane.Material = Enum.Material.Glass
				pane.Transparency = 0.6
				piece("BarrierCap", height + 0.2, 0.4, 1, RAIL_GREY)
			else
				piece(if style == "rail" then "Railing" else "Wall", height / 2, height, WALL_T, color)
			end
		end
	end

	-- The pockets behind curved corners: no props, no NPC nodes.
	type Pocket = { cx: number, cz: number, r: number, square: Rect }
	local pockets: { [string]: { Pocket } } = {}
	for _, name in allLevels do
		pockets[name] = {}
	end
	-- The quarter circle that rounds off the corner at (px, pz), whose sides run away from it toward +x if sx is 1
	-- (-x if -1) and toward +z if sz is 1: its centre, and the angles from one tangent point to the other.
	local function cornerArc(
		px: number,
		pz: number,
		sx: number,
		sz: number,
		r: number
	): (number, number, number, number)
		local a0 = math.atan2(0, -sx)
		local a1 = math.atan2(-sz, 0)
		if a1 - a0 > math.pi then
			a1 -= 2 * math.pi
		elseif a0 - a1 > math.pi then
			a1 += 2 * math.pi
		end
		return px + sx * r, pz + sz * r, a0, a1
	end
	local function floorColor(room: Room): Color3
		return if room.kind == "outdoor" then DECK else tierColor(room.tier):Lerp(FLOOR_WARM, 0.65)
	end
	local function pieceAt(level: string, x: number, z: number): Piece?
		for _, piece in piecesByLevel[level] do
			local r = piece.rect
			if x > r.x1 and x < r.x2 and z > r.z1 and z < r.z2 then
				return piece
			end
		end
		return nil
	end

	-- Rounded voids: each corner of the shaft gets a quarter-round of floor and a curved railing, and the straight
	-- railings stop short of the corners.
	local roundedVoids = 0
	for _, void in Layout.voids do
		local r = void.round
		if not r then
			continue
		end
		roundedVoids += 1
		local v = toRect(void.rect)
		for _, corner in { { v.x1, v.z1, 1, 1 }, { v.x2, v.z1, -1, 1 }, { v.x1, v.z2, 1, -1 }, { v.x2, v.z2, -1, -1 } } do
			local px, pz, sx, sz = corner[1], corner[2], corner[3], corner[4]
			for _, edge in edges do
				if edge.kind == "void" and edge.level == void.level then
					local cornerAlong = if edge.axis == "x" then px else pz
					local cornerLine = if edge.axis == "x" then pz else px
					local inward = if edge.axis == "x" then sx else sz
					if math.abs(edge.line - cornerLine) < EPS then
						local lo = math.max(edge.a, math.min(cornerAlong, cornerAlong + inward * r))
						local hi = math.min(edge.b, math.max(cornerAlong, cornerAlong + inward * r))
						if hi - lo > EPS then
							table.insert(edge.gaps, { center = (lo + hi) / 2, width = hi - lo })
						end
					end
				end
			end
			local cx, cz, a0, a1 = cornerArc(px, pz, sx, sz, r)
			arc(void.level, cx, cz, r, a0, a1, "rail", RAIL_H, RAIL_GREY)
			-- The floor between the curve and the square corner, in strips.
			local around = pieceAt(void.level, px - sx, pz - sz)
			local color = if around then floorColor(around.room) else FLOOR_WARM
			local strips = math.max(4, math.ceil(r / 2))
			for i = 1, strips do
				local u0, u1 = (i - 1) * r / strips, i * r / strips
				local um = (u0 + u1) / 2
				local depth = r - math.sqrt(math.max(r * r - (r - um) * (r - um), 0))
				if depth > 0.05 then
					local x1, x2 = px + sx * u0, px + sx * u1
					local z1, z2 = pz, pz + sz * depth
					slab(
						geometry,
						`Floor_{void.level}_voidcorner`,
						{ x1 = math.min(x1, x2), z1 = math.min(z1, z2), x2 = math.max(x1, x2), z2 = math.max(z1, z2) },
						levels[void.level],
						color
					)
				end
			end
		end
	end

	-- Rounded rooms: each corner of the room's rectangle gets a curved wall (a glass barrier at the open edge of a terrace),
	-- unless a doorway or window is near it or a nested room fills it.
	local roundedCorners = 0
	for _, room in rooms do
		local r = room.round
		if not r then
			continue
		end
		local rect = toRect(room.rect)
		for _, corner in
			{
				{ rect.x1, rect.z1, 1, 1 },
				{ rect.x2, rect.z1, -1, 1 },
				{ rect.x1, rect.z2, 1, -1 },
				{ rect.x2, rect.z2, -1, -1 },
			}
		do
			local px, pz, sx, sz = corner[1], corner[2], corner[3], corner[4]
			local inside = pieceAt(room.level, px + sx, pz + sz)
			if not (inside and inside.room == room) then
				continue
			end
			local blocked, onFreeEdge = false, false
			for _, edge in edges do
				if edge.level == room.level and (edge.roomA == room or edge.roomB == room) then
					local cornerAlong = if edge.axis == "x" then px else pz
					local cornerLine = if edge.axis == "x" then pz else px
					if
						math.abs(edge.line - cornerLine) < EPS
						and cornerAlong >= edge.a - EPS
						and cornerAlong <= edge.b + EPS
					then
						onFreeEdge = onFreeEdge or edge.kind == "free"
						for _, gap in edge.gaps do
							if math.abs(gap.center - cornerAlong) - gap.width / 2 < r + 2 then
								blocked = true
							end
						end
					end
				end
			end
			if blocked then
				continue
			end
			roundedCorners += 1
			local style, height, color = "wall", roomHeight(room), INTERIOR_WALL
			if room.kind == "outdoor" then
				if onFreeEdge then
					style, height = "barrier", BARRIER_H
				else
					height, color = WALL_H, SHELL
				end
			elseif onFreeEdge then
				color = SHELL
			end
			local cx, cz, a0, a1 = cornerArc(px, pz, sx, sz, r)
			arc(room.level, cx, cz, r, a0, a1, style, height, color)
			local square = {
				x1 = math.min(px, px + sx * r),
				z1 = math.min(pz, pz + sz * r),
				x2 = math.max(px, px + sx * r),
				z2 = math.max(pz, pz + sz * r),
			}
			table.insert(pockets[room.level], { cx = cx, cz = cz, r = r, square = square })
			table.insert(reserved[room.level], square)
		end
	end
	print(`[Gala]      curves: {roundedCorners} rounded corners, {roundedVoids} rounded voids`)

	-- Signs (MAP_BRIEF_REPLAN stage 3): stairs, exits, extraction and restrooms only, never vaults. Rooms that hold a stair
	-- end, an extraction site, or a restroom are what doorway signs point to.
	-- Where each stair end is, by the room it stands in.
	local stairEnds: { [Room]: { Vector2 } } = {}
	for _, s in stairs do
		for _, area in { { level = s.ramp.from, rect = s.entry }, { level = s.upper, rect = s.arrival } } do
			local x, z = (area.rect.x1 + area.rect.x2) / 2, (area.rect.z1 + area.rect.z2) / 2
			local found = pieceAt(area.level, x, z)
			if found then
				stairEnds[found.room] = stairEnds[found.room] or {}
				table.insert(stairEnds[found.room], Vector2.new(x, z))
			end
		end
	end
	local extractionRooms: { [Room]: boolean } = {}
	for _, site in Layout.extraction do
		local found = pieceAt(site.level, site.x, site.z)
		if found then
			extractionRooms[found.room] = true
		end
	end
	local function isRestroom(room: Room): boolean
		return string.find(room.id, "restroom") ~= nil
			or string.find(room.id, "washroom") ~= nil
			or room.id == "g_staffwc"
	end
	local signCount = 0
	-- Writes text on one face of a sign part, lit so it reads in the dark like an LED panel.
	local function signText(p: BasePart, face: Enum.NormalId, text: string, color: Color3)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = SIGN_PIXELS
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.Parent = p
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = color
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = text
		label.Parent = gui
	end
	-- Writes each side of a sign and tags it for SignController, which floats the text toward a nearby reader. A side is
	-- the face it is printed on, the direction it looks (out of that face), its text and its colour.
	type SignSide = { face: Enum.NormalId, normal: Vector3, text: string, color: Color3 }
	local function writeSign(p: BasePart, sides: { SignSide })
		for index, side in sides do
			signText(p, side.face, side.text, side.color)
			p:SetAttribute(`Text{index}`, side.text)
			p:SetAttribute(`Color{index}`, side.color)
			p:SetAttribute(`Normal{index}`, side.normal)
		end
		tag(p, Tag.Sign)
	end
	-- The face of an axis-aligned part that looks toward `side` (+1 or -1) across a wall running along `axis`.
	local function faceToward(axis: string, side: number): Enum.NormalId
		if axis == "x" then
			return if side > 0 then Enum.NormalId.Back else Enum.NormalId.Front
		end
		return if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	end
	-- What a doorway sign says about the room beyond it, and in what colour (nil: no sign that way).
	-- EXIT means a stair close beyond the doorway, not just somewhere in a big room.
	local function signFor(room: Room, doorway: Vector2): (string?, Color3)
		local stairNear = false
		for _, stairEnd in stairEnds[room] or {} do
			stairNear = stairNear or (stairEnd - doorway).Magnitude <= EXIT_SIGN_REACH
		end
		if extractionRooms[room] then
			return "EXTRACTION", SIGN_EXTRACTION
		elseif stairNear then
			return "EXIT", SIGN_EXIT
		elseif isRestroom(room) then
			return "RESTROOMS", SIGN_PLAIN
		end
		return nil, SIGN_PLAIN
	end
	-- A small lit sign over a doorway; each face tells someone on that side what lies through it.
	local function doorwaySign(edge: Edge, gap: Gap, openingH: number, height: number, sideOfRoom: (Room) -> number)
		if height - openingH < SIGN_H + 1 then
			return
		end
		local roomB = edge.roomB :: Room
		local faces: { { side: number, text: string, color: Color3 } } = {}
		for _, pair in { { edge.roomA, roomB }, { roomB, edge.roomA } } do
			local here, beyond = pair[1], pair[2]
			local doorway = if edge.axis == "x"
				then Vector2.new(gap.center, edge.line)
				else Vector2.new(edge.line, gap.center)
			local text, color = signFor(beyond, doorway)
			if text then
				table.insert(faces, { side = sideOfRoom(here), text = text, color = color })
			end
		end
		if #faces == 0 then
			return
		end
		-- Read from both sides it goes through the wall; read from one side it sits flat on that face.
		local depth = if #faces == 2 then WALL_T + 0.3 else 0.3
		local line = if #faces == 2 then edge.line else edge.line + faces[1].side * (WALL_T / 2 + 0.15)
		local sign = part(
			trim,
			"Sign",
			alongSize(edge.axis, SIGN_W, SIGN_H, depth),
			CFrame.new(alongPoint(edge.axis, line, gap.center, levels[edge.level] + openingH + 0.4 + SIGN_H / 2)),
			SIGN_PANEL
		)
		sign.CanCollide = false
		sign.CanQuery = false
		local sides: { SignSide } = {}
		for _, f in faces do
			local normal = if edge.axis == "x" then Vector3.new(0, 0, f.side) else Vector3.new(f.side, 0, 0)
			table.insert(
				sides,
				{ face = faceToward(edge.axis, f.side), normal = normal, text = f.text, color = f.color }
			)
		end
		writeSign(sign, sides)
		signCount += 1
	end

	-- The leaves of a clearance or keycard door (MAP_BRIEF_REPLAN stage 3), under its blocker. The style follows the tier:
	-- framed glass for Public and Staff, solid wood for Security, heavy steel for Executive and the vault wings. Every
	-- leaf has a glowing handle bar on each face in the tier colour (red into a vault wing) with a pip per tier above it.
	-- Each leaf is a Model pivoting on its hinge; DoorController swings it by Swing (+1 or -1) times the swing angle,
	-- toward `side` (the higher tier's side of the wall). Leaves never collide: the blocker does.
	local function doorLeaves(
		blocker: Part,
		edge: Edge,
		gap: Gap,
		height: number,
		tier: number,
		vaultWing: boolean,
		side: number
	)
		local baseY = levels[edge.level]
		local u = if edge.axis == "x" then Vector3.xAxis else Vector3.zAxis -- along the wall
		local n = if edge.axis == "x" then Vector3.zAxis else Vector3.xAxis -- across it
		local style = if vaultWing or tier >= 3 then "heavy" elseif tier == 2 then "solid" else "glass"
		local glow = if vaultWing then GameConfig.Zones.VaultColor else tierColor(tier)
		local pips = GameConfig.Zones.TierPips[tier] or 0
		local clear = gap.width - DOOR_POST_W * 2 -- the leaves hang between the door posts
		local count = if gap.width >= 10 then 2 else 1
		local leafW = clear / count
		local leafH = height - 0.2
		local leaves = Instance.new("Folder")
		leaves.Name = "Leaves"
		leaves.Parent = blocker
		for i = 1, count do
			local dsign = if i == 1 then 1 else -1 -- the leaf runs from its hinge toward the middle of the doorway
			local hinge = alongPoint(edge.axis, edge.line, gap.center - dsign * clear / 2, baseY)
			local hingeFrame = CFrame.fromMatrix(hinge, u, Vector3.yAxis)
			local model = Instance.new("Model")
			model.Name = "Leaf"
			-- A piece of the leaf: `along` is measured from the hinge, `across` from the middle of the leaf.
			local function piece(
				name: string,
				a1: number,
				a2: number,
				y1: number,
				y2: number,
				across: number,
				depth: number,
				color: Color3
			): Part
				local p = part(
					model,
					name,
					alongSize(edge.axis, a2 - a1, y2 - y1, depth),
					CFrame.new(hinge + u * (dsign * (a1 + a2) / 2) + n * across + Vector3.new(0, (y1 + y2) / 2, 0)),
					color
				)
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				return p
			end
			if style == "glass" then
				local pane = piece("DoorGlass", 0.5, leafW - 0.5, 0.5, leafH - 0.5, 0, 0.2, CITY_GLASS)
				pane.Material = Enum.Material.Glass
				pane.Transparency = 0.5
				piece("DoorStile", 0, 0.5, 0, leafH, 0, LEAF_T, DOOR_FRAME)
				piece("DoorStile", leafW - 0.5, leafW, 0, leafH, 0, LEAF_T, DOOR_FRAME)
				piece("DoorRail", 0.5, leafW - 0.5, 0, 0.5, 0, LEAF_T, DOOR_FRAME)
				piece("DoorRail", 0.5, leafW - 0.5, leafH - 0.5, leafH, 0, LEAF_T, DOOR_FRAME)
			elseif style == "solid" then
				piece("DoorPanel", 0, leafW, 0, leafH, 0, LEAF_T, DOOR_WOOD).Material = Enum.Material.Wood
			else
				piece("DoorPanel", 0, leafW, 0, leafH, 0, LEAF_T, DOOR_STEEL).Material = Enum.Material.Metal
				for _, y in { leafH / 3, leafH * 2 / 3 } do
					piece("DoorStrap", 0, leafW, y - 0.3, y + 0.3, 0, LEAF_T + 0.2, DOOR_FRAME).Material =
						Enum.Material.DiamondPlate
				end
			end
			for _, face in { -1, 1 } do
				local bar = piece(
					"DoorHandle",
					leafW - 1.1,
					leafW - 0.7,
					HANDLE_LOW,
					HANDLE_HIGH,
					face * (LEAF_T / 2 + 0.35),
					0.3,
					glow
				)
				bar.Material = Enum.Material.Neon
				for k = 1, pips do
					local y = HANDLE_HIGH + 0.4 + (k - 1) * 0.7
					piece("DoorPip", leafW - 1.1, leafW - 0.7, y, y + 0.4, face * (LEAF_T / 2 + 0.3), 0.4, glow).Material =
						Enum.Material.Neon
				end
			end
			-- Which way the leaf turns about its hinge to swing toward `side`.
			local towardSide = u:Cross(Vector3.yAxis):Dot(n * side)
			model.WorldPivot = hingeFrame
			model:SetAttribute("Closed", hingeFrame)
			model:SetAttribute("Swing", -dsign * (if towardSide > 0 then 1 else -1))
			model.Parent = leaves
		end
	end

	-- A window in a wall (Layout.Window): wall under the sill and over the head, and between them a pane or an open
	-- hatch over a counter.
	local function windowPiece(edge: Edge, gap: Gap, window: Layout.Window, height: number, color: Color3)
		local baseY = levels[edge.level]
		local sill = if window.kind == "hatch" then HATCH_SILL else GLASS_SILL
		local head = math.min(if window.kind == "hatch" then HATCH_HEAD else GLASS_HEAD, height - 1)
		local function band(name: string, y1: number, y2: number, partColor: Color3, depth: number): Part
			return part(
				geometry,
				name,
				alongSize(edge.axis, gap.width, y2 - y1, depth),
				CFrame.new(alongPoint(edge.axis, edge.line, gap.center, baseY + (y1 + y2) / 2)),
				partColor
			)
		end
		band("Sill", 0, sill, color, WALL_T)
		band("Lintel", head, height, color, WALL_T)
		if window.kind == "hatch" then
			band("Counter", sill - 0.4, sill, COUNTER, WALL_T + 2)
			return
		end
		local pane =
			band(if window.kind == "oneWay" then "OneWayGlass" else "Glass", sill, head, CITY_GLASS, WALL_T - 0.6)
		pane.Material = Enum.Material.Glass
		pane.Transparency = 0.55
		if window.kind == "oneWay" then
			-- Mirrored as built, which is how everyone outside sees it; OneWayGlassController clears it for a camera
			-- on the inside. It blocks movement, shots and sight checks both ways, like any wall.
			pane.Material = Enum.Material.SmoothPlastic
			pane.Color = MIRROR
			pane.Reflectance = GameConfig.Map.OneWayGlass.OutsideReflectance
			pane.Transparency = 0
			-- Which way is in: toward the middle of the inside room, across the wall.
			local inside = toRect(roomById[window.inside :: string].rect)
			local middle = if edge.axis == "x" then (inside.z1 + inside.z2) / 2 else (inside.x1 + inside.x2) / 2
			local sign = if middle > edge.line then 1 else -1
			local normal = if edge.axis == "x" then Vector3.new(0, 0, sign) else Vector3.new(sign, 0, 0)
			tag(pane, Tag.OneWayGlass, { Inside = normal })
		end
	end

	local wallCount, gateCount, keycardCount = 0, 0, 0
	for _, edge in edges do
		local height = 0
		local color = INTERIOR_WALL
		if edge.kind == "shared" then
			local roomB = edge.roomB :: Room
			if edge.roomA.kind ~= roomB.kind then
				color = SHELL -- the outside of the building, facing a terrace or deck
			end
			if edge.roomA.kind == "indoor" or roomB.kind == "indoor" then
				height = math.max(
					if edge.roomA.kind == "indoor" then roomHeight(edge.roomA) else 0,
					if roomB.kind == "indoor" then roomHeight(roomB) else 0
				)
				-- A low room nested in another (a vent duct) is a box inside it: its walls stop at its own ceiling.
				for _, pair in { { edge.roomA, roomB }, { roomB, edge.roomA } } do
					if pair[1].parent == pair[2].id and pair[1].height then
						height = (pair[1].height :: number) + SLAB
					end
				end
			end
		elseif edge.kind == "void" then
			height, color = RAIL_H, RAIL_GREY
		else
			if edge.roomA.kind == "indoor" then
				height, color = roomHeight(edge.roomA), SHELL
			elseif edge.roomA.kind == "gallery" then
				height, color = RAIL_H, RAIL_GREY
				-- Leave a gap wherever a stair arrives over this edge.
				for _, s in stairs do
					local r = s.arrival
					if s.ontoGallery and s.upper == edge.level then
						local onLine = if edge.axis == "x"
							then math.abs(r.z1 - edge.line) < 0.5 or math.abs(r.z2 - edge.line) < 0.5
							else math.abs(r.x1 - edge.line) < 0.5 or math.abs(r.x2 - edge.line) < 0.5
						local a, b = if edge.axis == "x" then r.x1 else r.z1, if edge.axis == "x" then r.x2 else r.z2
						if onLine and a >= edge.a - EPS and b <= edge.b + EPS then
							table.insert(edge.gaps, { center = (a + b) / 2, width = b - a })
						end
					end
				end
			else
				height = BARRIER_H
				-- Open the barrier where the gondola docks.
				local g = Layout.gondola
				if edge.level == g.level and edge.axis == "z" then
					for _, dockX in { g.fromX, g.toX } do
						local a, b = g.z - g.width / 2, g.z + g.width / 2
						if math.abs(edge.line - dockX) < 0.5 and a >= edge.a - EPS and b <= edge.b + EPS then
							table.insert(edge.gaps, { center = g.z, width = g.width })
						end
					end
				end
			end
		end
		if height == 0 then
			continue
		end
		wallCount += 1
		currentGlass = false
		currentBarrier = edge.kind == "free" and edge.roomA.kind == "outdoor"
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
			if gap.window then
				windowPiece(edge, gap, gap.window, height, color)
				continue
			end
			local gapDoor = gap.door
			local ventRoom = if gapDoor
				then (if roomById[gapDoor.a].duct
					then roomById[gapDoor.a]
					else if roomById[gapDoor.b].duct then roomById[gapDoor.b] else nil)
				else nil
			local openingH = if ventRoom
				then VENT_OPENING_H
				elseif gapDoor and (gapDoor.gate or gapDoor.keycard) then DOOR_H
				else GAP_H
			if height <= openingH then
				continue -- a gap in a railing has nothing over it
			end
			local baseY = levels[edge.level]
			local radius = gap.width / 2
			if gapDoor and gapDoor.arch and height >= openingH + radius + 1 then
				-- An arched doorway: the lintel starts at the crown, and the corners under it are filled in slices that
				-- follow the curve.
				local crown = openingH + radius
				part(
					geometry,
					"Lintel",
					alongSize(edge.axis, gap.width, height - crown, WALL_T),
					CFrame.new(alongPoint(edge.axis, edge.line, gap.center, baseY + crown + (height - crown) / 2)),
					color
				)
				local slices = math.max(4, math.ceil(gap.width / ARCH_SLICE))
				local step = gap.width / slices
				for i = 1, slices do
					local u = -radius + (i - 0.5) * step
					local fill = radius - math.sqrt(math.max(radius * radius - u * u, 0))
					if fill > 0.05 then
						part(
							geometry,
							"Arch",
							alongSize(edge.axis, step + 0.05, fill, WALL_T),
							CFrame.new(alongPoint(edge.axis, edge.line, gap.center + u, baseY + crown - fill / 2)),
							color
						)
					end
				end
			else
				-- Lintel above the doorway.
				part(
					geometry,
					"Lintel",
					alongSize(edge.axis, gap.width, height - openingH, WALL_T),
					CFrame.new(alongPoint(edge.axis, edge.line, gap.center, baseY + openingH + (height - openingH) / 2)),
					color
				)
			end
			if ventRoom then
				-- A vent grate (spec 4.3): see-through, walk-through for a player, and the way in or out of a duct.
				local grate = part(
					objects,
					"VentGrate",
					alongSize(edge.axis, gap.width, VENT_OPENING_H, 0.3),
					CFrame.new(alongPoint(edge.axis, edge.line, gap.center, baseY + VENT_OPENING_H / 2)),
					RAIL_GREY
				)
				grate.Material = Enum.Material.DiamondPlate
				grate.Transparency = 0.5
				grate.CanCollide = false
				tag(grate, Tag.Vent, { VentId = ventRoom.id })
				continue
			end
			local roomB = edge.roomB :: Room
			local high = math.max(edge.roomA.tier, roomB.tier)
			local door = gap.door :: Layout.Door
			-- A clearance door or keycard door fills the doorway until it is opened (DoorService).
			-- Which side of this wall a room is on: -1 for the low side, 1 for the high side (judged from the middle of
			-- the room's rectangle, since either room of an edge can be on either side).
			local function sideOf(room: Room): number
				local r = toRect(room.rect)
				local middle = if edge.axis == "x" then (r.z1 + r.z2) / 2 else (r.x1 + r.x2) / 2
				return if middle > edge.line then 1 else -1
			end
			-- A clearance door or keycard door: an invisible blocker that DoorService opens and shuts, and real door
			-- leaves in front of it that each client swings (DoorController).
			if door.gate or door.keycard then
				local doorTier = if door.gate then door.gate :: number else high
				local blocker = part(
					objects,
					if door.gate then "ClearanceDoor" else "KeycardDoor",
					alongSize(edge.axis, gap.width, openingH, WALL_T - 0.4),
					CFrame.new(alongPoint(edge.axis, edge.line, gap.center, baseY + openingH / 2)),
					DOOR_FRAME
				)
				blocker.Transparency = 1
				if door.gate then
					gateCount += 1
					tag(blocker, Tag.ClearanceDoor, { Tier = door.gate })
				else
					keycardCount += 1
					tag(blocker, Tag.KeycardDoor, { Tier = high })
				end
				local vaultWing = string.find(edge.roomA.id, "vault") ~= nil or string.find(roomB.id, "vault") ~= nil
				local higher = if edge.roomA.tier > roomB.tier then edge.roomA else roomB
				doorLeaves(blocker, edge, gap, openingH, doorTier, vaultWing, sideOf(higher))
			end
			if door.vault then
				-- The inner vault door (spec 10), in its vault's style, with the hack zone in front of it and the Package
				-- pedestal in the strongroom behind it.
				local vaultRoom, core = roomById[door.a], roomById[door.b]
				vaultDoor(edge, gap.center, baseY, vaultRoom.theme or "bank", door.vault)
				local out = -sideOf(core) -- from the door toward the vault room
				local size = GameConfig.Vault.HackZoneSize
				local zone = part(
					objects,
					"VaultHackZone",
					alongSize(edge.axis, size, 0.2, size),
					CFrame.new(alongPoint(edge.axis, edge.line + out * (size / 2 + WALL_T), gap.center, baseY + 0.1)),
					Color3.fromRGB(255, 70, 60)
				)
				zone.Transparency = 0.6
				zone.CanCollide = false
				zone.Material = Enum.Material.Neon
				tag(zone, Tag.VaultHackZone, { VaultId = door.vault })
				local c = toRect(core.rect)
				local pedestal = part(
					objects,
					"PackagePedestal",
					Vector3.new(3, 3.5, 3),
					CFrame.new((c.x1 + c.x2) / 2, baseY + 1.75, (c.z1 + c.z2) / 2),
					Color3.fromRGB(60, 62, 70)
				)
				tag(pedestal, Tag.PackagePedestal, { VaultId = door.vault })
			end
			if door.laser then
				-- A laser grid across the doorway, on the antechamber's side (spec 18.2).
				local grid = part(
					objects,
					"LaserGrid",
					alongSize(edge.axis, gap.width, openingH, 0.2),
					CFrame.new(
						alongPoint(
							edge.axis,
							edge.line + sideOf(roomById[door.a]) * (WALL_T / 2 + 3),
							gap.center,
							baseY + openingH / 2
						)
					),
					Color3.fromRGB(255, 40, 40)
				)
				grid.Material = Enum.Material.Neon
				grid.Transparency = 0.7
				grid.CanCollide = false
				grid.CanQuery = false
				tag(grid, Tag.LaserGrid)
			end
			-- Posts and floor inlays show which tiers a doorway joins. A real door has a plain dark frame (its handles
			-- carry the colour); an open doorway between tiers keeps coloured posts.
			local hasDoor = door.gate ~= nil or door.keycard == true
			if edge.roomA.tier ~= roomB.tier or hasDoor then
				local postColor = if hasDoor then DOOR_FRAME else tierColor(high)
				for _, offset in { -gap.width / 2 + DOOR_POST_W / 2, gap.width / 2 - DOOR_POST_W / 2 } do
					part(
						trim,
						"DoorPost",
						alongSize(edge.axis, DOOR_POST_W, openingH, WALL_T + 0.6),
						CFrame.new(alongPoint(edge.axis, edge.line, gap.center + offset, baseY + openingH / 2)),
						postColor
					)
				end
				for _, room in { edge.roomA, roomB } do
					local decal = part(
						trim,
						"FloorDecal",
						alongSize(edge.axis, gap.width, 0.2, 4),
						CFrame.new(
							alongPoint(edge.axis, edge.line + sideOf(room) * (WALL_T / 2 + 2), gap.center, baseY + 0.1)
						),
						tierColor(room.tier)
					)
					decal.CanCollide = false
				end
			end
			if not door.vault then
				local top = if door.arch then openingH + gap.width / 2 else openingH
				doorwaySign(edge, gap, top, height, sideOf)
			end
		end
		wallPiece(edge, cursor, edge.b, height, color)
	end

	-- A sign hanging over each end of every stair, naming where it goes.
	local LEVEL_NAMES =
		{ B = "BASEMENT", G = "GROUND", GH = "GALLERY", M = "MEZZANINE", T = "TOP FLOOR", R = "ROOF", X = "SKY DECK" }
	for _, s in stairs do
		local dx = dirVector(s.ramp.dir)
		local alongX = dx ~= 0
		for _, stairEnd in
			{
				{ level = s.ramp.from, rect = s.entry, text = `UP TO {LEVEL_NAMES[s.upper]}` },
				{ level = s.upper, rect = s.arrival, text = `DOWN TO {LEVEL_NAMES[s.ramp.from]}` },
			}
		do
			local r = stairEnd.rect
			local sign = part(
				trim,
				"StairSign",
				if alongX
					then Vector3.new(0.3, STAIR_SIGN_H, STAIR_SIGN_W)
					else Vector3.new(STAIR_SIGN_W, STAIR_SIGN_H, 0.3),
				CFrame.new((r.x1 + r.x2) / 2, levels[stairEnd.level] + STAIR_SIGN_Y, (r.z1 + r.z2) / 2),
				SIGN_PANEL
			)
			sign.CanCollide = false
			sign.CanQuery = false
			writeSign(
				sign,
				if alongX
					then {
						{ face = Enum.NormalId.Left, normal = -Vector3.xAxis, text = stairEnd.text, color = SIGN_EXIT },
						{ face = Enum.NormalId.Right, normal = Vector3.xAxis, text = stairEnd.text, color = SIGN_EXIT },
					}
					else {
						{
							face = Enum.NormalId.Front,
							normal = -Vector3.zAxis,
							text = stairEnd.text,
							color = SIGN_EXIT,
						},
						{ face = Enum.NormalId.Back, normal = Vector3.zAxis, text = stairEnd.text, color = SIGN_EXIT },
					}
			)
			signCount += 1
		end
	end
	print(`[Gala]      signs: {signCount}`)

	-- Floors and ceilings --------------------------------------------------------------------------------------------------------
	for levelName, list in piecesByLevel do
		for _, piece in list do
			local pieces = { piece.rect }
			for _, hole in rampHoles[levelName] do
				pieces = subtract(pieces, hole)
			end
			local color
			if piece.room.kind ~= "outdoor" then
				color = tierColor(piece.room.tier):Lerp(FLOOR_WARM, 0.65)
			else
				color = DECK
			end
			for _, rect in pieces do
				slab(geometry, `Floor_{levelName}_{piece.room.id}`, rect, levels[levelName], color)
			end
			-- An indoor room is roofed wherever no room sits above it; a shaft stays open where the void is.
			if piece.room.duct then
				slab(
					geometry,
					`Roof_{levelName}_{piece.room.id}`,
					piece.rect,
					levels[levelName] + roomHeight(piece.room) + SLAB,
					SHELL
				)
				local r = piece.rect
				local volume = part(
					objects,
					"VentDuct",
					Vector3.new(r.x2 - r.x1, roomHeight(piece.room), r.z2 - r.z1),
					CFrame.new((r.x1 + r.x2) / 2, levels[levelName] + roomHeight(piece.room) / 2, (r.z1 + r.z2) / 2),
					RAIL_GREY
				)
				ghost(volume)
				tag(volume, Tag.VentDuct, { VentId = piece.room.id })
			elseif piece.room.kind == "indoor" then
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
					slab(
						geometry,
						`Roof_{levelName}_{piece.room.id}`,
						rect,
						levels[levelName] + roomHeight(piece.room) + SLAB,
						SHELL
					)
				end
			end
		end
	end

	-- Stairs (the flights, landings, handrails and the railings round their openings) --------------------------------------
	local STAIR_GREY = Color3.fromRGB(104, 106, 118)
	-- One flight from (sx, sz) at baseY, climbing `rise` over `run` the way (dx, dz) points. It gets a handrail at each
	-- offset in `rails`, measured sideways along (px, pz) from its centre line.
	local function flight(
		sx: number,
		sz: number,
		dx: number,
		dz: number,
		baseY: number,
		run: number,
		rise: number,
		px: number,
		pz: number,
		rails: { number }
	)
		-- the part's thickness lifts its top surface, so shift it back toward the climb
		local angle = math.atan2(rise, run)
		local shift = run / 2 + math.sin(angle)
		local center = Vector3.new(sx + dx * shift, baseY + rise / 2 - math.cos(angle), sz + dz * shift)
		local cframe = CFrame.lookAt(center, center + Vector3.new(dx * run, rise, dz * run))
		local length = math.sqrt(rise ^ 2 + run ^ 2)
		part(geometry, "StairFlight", Vector3.new(RAMP_W, 2, length), cframe, STAIR_GREY)
		for _, offset in rails do
			part(
				geometry,
				"StairHandrail",
				Vector3.new(0.4, STAIR_RAIL_H, length),
				cframe + Vector3.new(px * offset, 0, pz * offset) + cframe.UpVector * (1 + STAIR_RAIL_H / 2),
				RAIL_GREY
			)
		end
	end
	local edge = RAMP_W / 2 - 0.2 -- a handrail's offset from the middle of its flight
	for _, s in stairs do
		local ramp = s.ramp
		local dx, dz = dirVector(ramp.dir)
		local px, pz = dz, -dx -- sideways across the stair
		local baseY = levels[ramp.from]
		local width, length = rampSize(ramp)
		-- A railing at height y, centred `along` studs up the stair and `across` studs from its centre line.
		local function rail(
			y: number,
			height: number,
			along: number,
			across: number,
			alongLen: number,
			acrossLen: number
		)
			part(
				geometry,
				"StairRail",
				Vector3.new(if dx == 0 then acrossLen else alongLen, height, if dx == 0 then alongLen else acrossLen),
				CFrame.new(ramp.x + dx * along + px * across, y + height / 2, ramp.z + dz * along + pz * across),
				RAIL_GREY
			)
		end
		-- The opening in the floor above: railed along both sides and across the end nobody arrives from. (A stair
		-- onto a gallery has no opening; the gallery's railing leaves a gap where it arrives.)
		local d = s.dims
		local upperY = baseY + d.rise
		local h1, h2, c1, c2 = holeSpan(ramp)
		if s.hole then
			rail(upperY, RAIL_H, (h1 + h2) / 2, c1 - 0.5, h2 - h1, 1)
			rail(upperY, RAIL_H, (h1 + h2) / 2, c2 + 0.5, h2 - h1, 1)
			if ramp.turn then
				rail(upperY, RAIL_H, h2 + 0.5, (c1 + c2) / 2, 1, c2 - c1 + 2) -- a switchback arrives at the start end
			else
				rail(upperY, RAIL_H, h1 - 0.5, 0, 1, c2 - c1 + 2) -- a plain stair arrives at its top end
			end
		end
		if ramp.turn then
			-- Leg one climbs away from the start; leg two climbs back, from the landing to the upper floor.
			-- A solid wall fills the gap between the two legs, up to the floor above, so there is no gap to see or fall
			-- through; each leg keeps a handrail on its open outer side.
			part(
				geometry,
				"StairCore",
				Vector3.new(if dx == 0 then LANE_GAP else d.legRun, d.rise, if dx == 0 then d.legRun else LANE_GAP),
				CFrame.new(ramp.x + dx * d.legRun / 2, baseY + d.rise / 2, ramp.z + dz * d.legRun / 2),
				STAIR_GREY
			)
			flight(ramp.x - px * lane, ramp.z - pz * lane, dx, dz, baseY, d.legRun, d.legRise, px, pz, { -edge })
			flight(
				ramp.x + px * lane + dx * d.legRun,
				ramp.z + pz * lane + dz * d.legRun,
				-dx,
				-dz,
				baseY + d.legRise,
				d.legRun,
				d.legRise,
				px,
				pz,
				{ edge }
			)
			local landingY = baseY + d.legRise
			part(
				geometry,
				"StairLanding",
				Vector3.new(if dx == 0 then width else LANDING, SLAB, if dx == 0 then LANDING else width),
				CFrame.new(
					ramp.x + dx * (d.legRun + LANDING / 2),
					landingY - SLAB / 2,
					ramp.z + dz * (d.legRun + LANDING / 2)
				),
				STAIR_GREY
			)
			-- The landing is railed round its three open sides.
			rail(landingY, STAIR_RAIL_H, length - 0.2, 0, 0.4, width)
			for _, side in { -1, 1 } do
				rail(landingY, STAIR_RAIL_H, d.legRun + LANDING / 2, side * (width / 2 - 0.2), LANDING, 0.4)
			end
		else
			flight(ramp.x, ramp.z, dx, dz, baseY, d.run, d.rise, px, pz, { -edge, edge })
		end
	end

	-- Zone volumes (spec 4.2) ------------------------------------------------------------------------------------------------------
	local zoneCount = 0
	for levelName, list in piecesByLevel do
		for _, piece in list do
			local r = piece.rect
			-- A zone reaches up to the next storey, so a gallery's zone stops under the floor above it.
			local y = levels[levelName]
			local height = (storeyAbove(y) or y + ZONE_H) - y
			local volume = part(
				zonesFolder,
				`Zone_{levelName}_T{piece.room.tier}_{piece.room.id}`,
				Vector3.new(r.x2 - r.x1 + ZONE_PAD * 2, height, r.z2 - r.z1 + ZONE_PAD * 2),
				CFrame.new((r.x1 + r.x2) / 2, y + height / 2 - 1, (r.z1 + r.z2) / 2),
				tierColor(piece.room.tier)
			)
			ghost(volume)
			tag(volume, Tag.ZoneVolume, { Tier = piece.room.tier })
			zoneCount += 1
		end
	end

	-- Props --------------------------------------------------------------------------------------------------------------------------
	local propRects: { [string]: { Rect } } = {}
	for _, name in allLevels do
		propRects[name] = {}
	end
	-- Posts under every gallery, round its edge, standing on the storey below.
	for levelName, list in piecesByLevel do
		if not isGalleryLevel[levelName] then
			continue
		end
		local top = levels[levelName] - SLAB
		local base = storeyBelow(levels[levelName])
		local bottom = levels[base]
		for _, piece in list do
			local r = piece.rect
			local function post(x: number, z: number)
				part(
					propsFolder,
					"GalleryPost",
					Vector3.new(1.2, top - bottom, 1.2),
					CFrame.new(x, (top + bottom) / 2, z),
					STEEL_POST
				)
				table.insert(propRects[base], { x1 = x - 0.6, z1 = z - 0.6, x2 = x + 0.6, z2 = z + 0.6 })
			end
			local nx = math.max(1, math.floor((r.x2 - r.x1) / GALLERY_POST_SPACING + 0.5))
			local nz = math.max(1, math.floor((r.z2 - r.z1) / GALLERY_POST_SPACING + 0.5))
			for i = 0, nx do
				local x = r.x1 + 0.6 + (r.x2 - r.x1 - 1.2) * i / nx
				post(x, r.z1 + 0.6)
				post(x, r.z2 - 0.6)
			end
			for i = 1, nz - 1 do
				local z = r.z1 + 0.6 + (r.z2 - r.z1 - 1.2) * i / nz
				post(r.x1 + 0.6, z)
				post(r.x2 - 0.6, z)
			end
		end
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
			for _ = 1, CRATES_PER_ROOM do
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
		vitrines = function(room)
			-- Glass display cases on plinths, in rows (the art vault's display hall).
			local b = bounds(room)
			local x = b.x1 + 12
			while x < b.x2 - 8 do
				for _, z in { b.z1 + 8, b.z2 - 8 } do
					if addProp(room, "Plinth", x, z, 3, 3, 3, STONE) then
						local case = part(
							propsFolder,
							"Vitrine",
							Vector3.new(3, 3, 3),
							CFrame.new(x, levels[room.level] + 4.5, z),
							Color3.fromRGB(190, 220, 240)
						)
						case.Material = Enum.Material.Glass
						case.Transparency = 0.5
					end
				end
				x += 12
			end
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

	-- Crates and stacked boxes can be climbed (climbing breaks Cover, spec 7.2).
	for _, item in propsFolder:GetChildren() do
		if item.Name == "Crate" then
			tag(item, Tag.ClimbSurface)
		end
	end

	-- Placed objects (Layout.placements): each goes to a free spot along a wall of its room, as far as possible from the
	-- other things placed in that room, clear of doorways, stairs and props. Wall-mounted ones sit against the wall.
	type Spot = { x: number, z: number, nx: number, nz: number }
	local placedIn: { [string]: { Spot } } = {}
	local function wallSpot(room: Room, width: number, depth: number): Spot?
		local best: Spot? = nil
		local bestScore = -math.huge
		for _, piece in piecesOfRoom[room.id] do
			local r = piece.rect
			-- each side: the inward normal, the wall line, and its extent
			for _, side in
				{
					{ nx = 0, nz = 1, line = r.z1, a = r.x1, b = r.x2 },
					{ nx = 0, nz = -1, line = r.z2, a = r.x1, b = r.x2 },
					{ nx = 1, nz = 0, line = r.x1, a = r.z1, b = r.z2 },
					{ nx = -1, nz = 0, line = r.x2, a = r.z1, b = r.z2 },
				}
			do
				-- Not along an atrium railing: that is no wall.
				local facesVoid = false
				for _, void in voidRects[room.level] or {} do
					local onLine = if side.nz ~= 0
						then math.abs(void.z1 - side.line) < EPS or math.abs(void.z2 - side.line) < EPS
						else math.abs(void.x1 - side.line) < EPS or math.abs(void.x2 - side.line) < EPS
					if onLine then
						facesVoid = true
					end
				end
				if facesVoid then
					continue
				end
				local t = side.a + width / 2 + 3
				while t <= side.b - width / 2 - 3 do
					local across = side.line + (side.nx + side.nz) * (2 + depth / 2) -- 2 studs in from the wall
					local cx = if side.nz ~= 0 then t else across
					local cz = if side.nz ~= 0 then across else t
					local hw, hd =
						if side.nz ~= 0 then width / 2 else depth / 2, if side.nz ~= 0 then depth / 2 else width / 2
					local rect: Rect = { x1 = cx - hw, z1 = cz - hd, x2 = cx + hw, z2 = cz + hd }
					if freeFor(room, rect) then
						local nearest = PLACE_SPREAD
						for _, other in placedIn[room.id] or {} do
							nearest = math.min(nearest, math.sqrt((other.x - cx) ^ 2 + (other.z - cz) ^ 2))
						end
						-- prefer spots far from the others, then nearer the middle of the wall
						local score = nearest - math.abs(t - (side.a + side.b) / 2) * 0.01
						if score > bestScore then
							bestScore = score
							best = { x = cx, z = cz, nx = side.nx, nz = side.nz }
						end
					end
					t += PLACE_STEP
				end
			end
		end
		return best
	end

	local intelByTier: { [number]: number } = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }
	local unplaced: { string } = {}
	local PLACE_SIZES: { [string]: Vector2 } = { -- width along the wall, depth into the room
		intel = Vector2.new(4, 3),
		health = Vector2.new(4, 2),
		ammo = Vector2.new(4, 2),
		food = Vector2.new(7, 4),
		safe = Vector2.new(4, 4),
		cache = Vector2.new(5, 4),
		camera = Vector2.new(3, 2),
	}
	for _, placement in Layout.placements do
		local room = roomById[placement.room]
		assert(room, `Placement names an unknown room: {placement.room}`)
		local size = PLACE_SIZES[placement.kind]
		assert(size, `Unknown placement kind {placement.kind}`)
		local spot = wallSpot(room, size.X, size.Y)
		if not spot then
			table.insert(unplaced, `{placement.kind} in {room.name}`)
			continue
		end
		placedIn[room.id] = placedIn[room.id] or {}
		table.insert(placedIn[room.id], spot)
		local half = Vector2.new(size.X / 2, size.Y / 2)
		local hw, hd = if spot.nz ~= 0 then half.X else half.Y, if spot.nz ~= 0 then half.Y else half.X
		table.insert(propRects[room.level], { x1 = spot.x - hw, z1 = spot.z - hd, x2 = spot.x + hw, z2 = spot.z + hd })

		local floorY = levels[room.level]
		local facing = Vector3.new(spot.nx, 0, spot.nz) -- into the room
		local wall = Vector3.new(spot.x, floorY, spot.z) - facing * (2 + size.Y / 2) -- the foot of the wall behind it
		local function at(out: number, up: number): CFrame
			-- a frame facing into the room, `out` studs from the wall and `up` studs above the floor
			local p = wall + facing * out + Vector3.new(0, up, 0)
			return CFrame.lookAt(p, p + facing)
		end
		local kind = placement.kind
		if kind == "intel" then
			local tier = room.tier
			local station = GameConfig.Intel.Stations[tier]
			intelByTier[tier] += 1
			local trimColor = tierColor(tier)
			local stationPart: Part
			if tier == 0 then
				-- a guest-book tablet on a stand
				part(propsFolder, "Stand", Vector3.new(0.5, 3.4, 0.5), at(3, 1.7), STEEL)
				stationPart = part(
					propsFolder,
					"IntelStation",
					Vector3.new(2, 1.4, 0.3),
					at(3, 3.6) * CFrame.Angles(math.rad(-30), 0, 0),
					trimColor
				)
			elseif tier == 1 then
				-- a laptop on a staff cart
				part(propsFolder, "Cart", Vector3.new(3.5, 3, 2.2), at(3, 1.5), STEEL)
				stationPart =
					part(propsFolder, "IntelStation", Vector3.new(2, 0.2, 1.4), at(3, 3.1), Color3.fromRGB(40, 40, 46))
				part(
					propsFolder,
					"Screen",
					Vector3.new(2, 1.3, 0.1),
					at(2.4, 3.8) * CFrame.Angles(math.rad(15), 0, 0),
					trimColor
				)
			elseif tier == 2 then
				-- a server rack with a screen
				stationPart =
					part(propsFolder, "IntelStation", Vector3.new(3, 7, 2.2), at(1.2, 3.5), Color3.fromRGB(35, 36, 42))
				local screen = part(propsFolder, "Screen", Vector3.new(2, 1.2, 0.1), at(2.35, 5), trimColor)
				screen.Material = Enum.Material.Neon
			else
				-- a wall safe with a keypad
				stationPart =
					part(propsFolder, "IntelStation", Vector3.new(3, 3, 0.8), at(0.5, 4), Color3.fromRGB(50, 50, 56))
				local keypad = part(propsFolder, "Keypad", Vector3.new(0.8, 1, 0.2), at(1, 4), trimColor)
				keypad.Material = Enum.Material.Neon
			end
			tag(stationPart, Tag.IntelSpawn, {
				Tier = tier,
				Points = station.Points,
				HackSeconds = station.HackSeconds,
				Station = station.Name,
			})
		elseif kind == "health" then
			local box =
				part(propsFolder, "HealthStation", Vector3.new(2.5, 3, 0.8), at(0.4, 4), Color3.fromRGB(235, 235, 240))
			tag(box, Tag.HealthStation)
			for _, bar in { Vector3.new(1.4, 0.4, 0.1), Vector3.new(0.4, 1.4, 0.1) } do
				local cross = part(propsFolder, "Cross", bar, at(0.85, 4), Color3.fromRGB(230, 50, 50))
				cross.Material = Enum.Material.Neon
			end
		elseif kind == "ammo" then
			local box = part(propsFolder, "AmmoCache", Vector3.new(3, 2, 1), at(0.5, 3.5), Color3.fromRGB(75, 85, 55))
			tag(box, Tag.AmmoCache)
			local stripe =
				part(propsFolder, "Stripe", Vector3.new(3, 0.3, 0.1), at(1.05, 3.5), Color3.fromRGB(240, 200, 40))
			stripe.Material = Enum.Material.Neon
		elseif kind == "food" then
			part(propsFolder, "Buffet", Vector3.new(6, 3.2, 3), at(2, 1.6), Color3.fromRGB(235, 230, 220))
			local plate =
				part(propsFolder, "Food", Vector3.new(1.4, 0.4, 1.4), at(2, 3.4), Color3.fromRGB(215, 140, 70))
			plate.Shape = Enum.PartType.Cylinder
			plate.CFrame = at(2, 3.4) * CFrame.Angles(0, 0, math.rad(90))
			plate.Size = Vector3.new(0.4, 1.4, 1.4)
			tag(plate, Tag.FoodSpot)
		elseif kind == "safe" then
			local safe =
				part(propsFolder, "AssetSafe", Vector3.new(3, 3.2, 3), at(1.6, 1.6), Color3.fromRGB(45, 46, 52))
			tag(safe, Tag.AssetSafe, { Tier = room.tier })
			local dial = part(
				propsFolder,
				"Dial",
				Vector3.new(0.3, 1, 1),
				at(3.15, 1.8) * CFrame.Angles(0, math.rad(90), 0),
				tierColor(room.tier)
			)
			dial.Shape = Enum.PartType.Cylinder
		elseif kind == "cache" then
			local crate =
				part(propsFolder, "SupplyCache", Vector3.new(4.5, 3, 3), at(1.6, 1.5), Color3.fromRGB(60, 70, 85))
			tag(crate, Tag.SupplyCache)
			local band =
				part(propsFolder, "Band", Vector3.new(4.6, 0.4, 3.1), at(1.6, 2.4), Color3.fromRGB(240, 200, 40))
			band.Material = Enum.Material.Neon
		elseif kind == "camera" then
			local high = roomHeight(room) - 2
			part(propsFolder, "CameraMount", Vector3.new(0.4, 0.4, 1.2), at(0.6, high), STEEL)
			local body = part(
				propsFolder,
				"SecurityCamera",
				Vector3.new(1, 1, 2),
				at(1.6, high) * CFrame.Angles(math.rad(-25), 0, 0),
				Color3.fromRGB(230, 230, 235)
			)
			tag(body, Tag.SecurityCamera, { Tier = room.tier })
		end
	end
	check(#unplaced == 0, `Every placement found a spot ({#Layout.placements - #unplaced}/{#Layout.placements})`)
	for _, missing in unplaced do
		print(`[Gala]      no room for {missing}`)
	end
	check(
		intelByTier[0] == 8 and intelByTier[1] == 8 and intelByTier[2] == 8 and intelByTier[3] == 8,
		`Intel stations by tier: {intelByTier[0]}, {intelByTier[1]}, {intelByTier[2]}, {intelByTier[3]} (want 8 each)`
	)

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
								CFrame.new(x, levels[room.level] + roomHeight(room) - 0.4, z),
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
							lamp:SetAttribute("LightIndex", lightCount) -- GraphicsController keeps every Nth on lower quality
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
	type NodeSpec = { level: string, x: number, z: number, tier: number, activity: string, stairLink: string? }
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
		for _, r in solidFeatures[level] do
			if x > r.x1 and x < r.x2 and z > r.z1 and z < r.z2 then
				return true
			end
		end
		for _, pocket in pockets[level] do
			local r = pocket.square
			local outside = Vector2.new(x - pocket.cx, z - pocket.cz).Magnitude > pocket.r - NODE_PROP_CLEAR
			if outside and x > r.x1 and x < r.x2 and z > r.z1 and z < r.z2 then
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
			if room.noNodes then
				continue
			end
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
						-- A spot taken by a prop slides to the nearest free one close by, so a row of planters down a
						-- terrace does not leave the strip without nodes (and its corners cut off).
						for _, offset in NODE_NUDGES do
							local nx = math.clamp(x + offset[1], r.x1 + marginX, r.x2 - marginX)
							local nz = math.clamp(z + offset[2], r.z1 + marginZ, r.z2 - marginZ)
							if not blockedForNode(room.level, nx, nz) then
								table.insert(list, {
									level = room.level,
									x = nx,
									z = nz,
									tier = room.tier,
									activity = pool[nodeRng:NextInteger(1, #pool)],
								})
								break
							end
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
		-- Both ends of every stair: the middle of the floor at its foot and at its head.
		for stairIndex, s in stairs do
			for _, stairEnd in { { level = s.ramp.from, rect = s.entry }, { level = s.upper, rect = s.arrival } } do
				local x, z = (stairEnd.rect.x1 + stairEnd.rect.x2) / 2, (stairEnd.rect.z1 + stairEnd.rect.z2) / 2
				table.insert(list, {
					level = stairEnd.level,
					x = x,
					z = z,
					tier = tierAtPoint(stairEnd.level, x, z),
					activity = "Walk",
					stairLink = `stair{stairIndex}`, -- NavGraph always links a stair's two ends
				})
			end
		end
		return list
	end
	local scale = 1
	local specs = buildNodes(scale)
	for _ = 1, 12 do
		if #specs <= GameConfig.Map.NPCNodeCount.Max then
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
		tag(node, Tag.NPCNode, { Tier = spec.tier, Activity = spec.activity, StairLink = spec.stairLink })
	end

	-- The city round the Gala (City.luau): each tower stands on its own skyscraper.
	local towers: { Rect } = {}
	for _, outline in Layout.towers do
		table.insert(towers, toRect(outline))
	end
	made += City.build(root, towers, levels.B - SLAB)

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
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 104, 145)
	Lighting.Brightness = 1.2
	Lighting.ExposureCompensation = 0.35
	-- Bloom so neon and lit windows glow; thin air and haze, as the Gala is high above the city, whose glow lights the
	-- horizon orange. Lighting.Technology cannot be set from a script: set it to Future in Studio (Lighting properties).
	for _, name in { "GalaAtmosphere", "GalaBloom", "GalaGrade" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	-- Only one Atmosphere can apply, so any other (a new place comes with a default one) is removed.
	for _, other in Lighting:GetChildren() do
		if other:IsA("Atmosphere") then
			other:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "GalaAtmosphere"
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.3
	atmosphere.Color = Color3.fromRGB(150, 90, 85)
	atmosphere.Decay = Color3.fromRGB(22, 26, 62)
	atmosphere.Glare = 0
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GalaBloom"
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "GalaGrade"
	grade.Contrast = 0.08
	grade.Saturation = 0.05
	grade.Parent = Lighting

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
	for _, name in
		{
			"IntelSpawn",
			"SupplyCache",
			"SecurityCamera",
			"LaserGrid",
			"HealthStation",
			"AmmoCache",
			"FoodSpot",
			"AssetSafe",
		}
	do
		check(count(Tag[name]) == counts[name], `{name} {count(Tag[name])}/{counts[name]}`)
	end
	check(count(Tag.Vent) == counts.VentPairs * 2, `Vent grates {count(Tag.Vent)}/{counts.VentPairs * 2}`)
	check(count(Tag.VentDuct) == counts.VentPairs, `Vent ducts {count(Tag.VentDuct)}/{counts.VentPairs}`)
	check(
		count(Tag.ZiplineAnchor) == counts.ZiplineAnchorPairs * 2,
		`ZiplineAnchor {count(Tag.ZiplineAnchor)}/{counts.ZiplineAnchorPairs * 2}`
	)
	check(count(Tag.Gondola) == 1 and count(Tag.GondolaCall) == 2, "Gondola with two call buttons")
	for _, name in { "VaultDoor", "VaultHackZone", "PackagePedestal" } do
		check(count(Tag[name]) == counts.VaultSpawn, `{name} {count(Tag[name])}/{counts.VaultSpawn} (one per vault)`)
	end
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
	-- through a single guarded door on purpose (SPEC-QUESTION), and a gallery by stairs from the room it stands in, so
	-- they are listed apart.
	local entrancesOk = true
	local nestedSingles: { string } = {}
	for _, room in rooms do
		if room.tier >= 1 and (doorsPerRoom[room.id] or 0) < GameConfig.Map.MinEntrancesPerRestrictedZone then
			if room.parent or string.find(room.id, "vault") or room.kind == "gallery" then
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
	print(`[Gala]      single-door guarded rooms and galleries: {table.concat(nestedSingles, ", ")}`)

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
