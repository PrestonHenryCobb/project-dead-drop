--!strict
-- Builds the graybox version of "The Gala" (spec section 4) into Workspace.Gala.
--
-- How to run: in Roblox Studio (Edit mode, Rojo connected so ReplicatedStorage.Shared exists), open View >
-- Command Bar, paste this whole file and press Enter. Then File > Save. Running it again deletes and rebuilds
-- Workspace.Gala. It also removes the template Baseplate and the old Greybox folder, and disables other spawns.
--
-- Layout (floor tops): B -24 basement, G 0 ground, M 24 mezzanine, T 48 top floor, R 72 roof.
-- 450 x 450 studs, x and z from -225 to 225. Every zone is a ZoneVolume tagged part; walls, slabs, doorways and
-- trim are generated from the same zone rectangles so the geometry and the tiers always agree.
-- At the end the script checks every count and rule it can against GameConfig.Map and prints the result.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Enums = require(Shared:WaitForChild("Enums"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Tag = Enums.Tag

local HALF = 225
local FLOOR_Y = { -24, 0, 24, 48, 72 }
local FLOOR_NAMES = { "B", "G", "M", "T", "R" }
local ROOF = 5
local SLAB = 2
local WALL_H = 22
local ROOF_WALL_H = 4
local WALL_T = 2
local GAP_W = 12
local GAP_H = 12
local GRID = 75 -- doorways sit at multiples of this along every interior wall
local ZONE_PAD = 2 -- zone volumes grow by this much per side, so neighbours overlap by twice this
local RAMP_W, RAMP_RUN, RAMP_RISE = 12, 48, 24
local GREY = Color3.fromRGB(150, 150, 150)

type Rect = { x1: number, z1: number, x2: number, z2: number }
type Zone = { floor: number, tier: number, rect: Rect, name: string, doorways: number }
type Ramp = { from: number, x: number, z0: number }

local rng = Random.new(7)

-- Setup ---------------------------------------------------------------------

for _, name in { "Gala", "Greybox", "Baseplate" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

local root = Instance.new("Folder")
root.Name = "Gala"

local function folder(name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local geometry = folder("Geometry")
local trim = folder("Trim")
local zonesFolder = folder("Zones")
local objects = folder("Objects")
local nodes = folder("NPCNodes")

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

-- Zones ----------------------------------------------------------------------

local zones: { Zone } = {}

local function zone(floor: number, tier: number, x1: number, z1: number, x2: number, z2: number, name: string)
	table.insert(
		zones,
		{ floor = floor, tier = tier, rect = { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }, name = name, doorways = 0 }
	)
end

-- Floor 1: basement. Tier 2 security corridors between two tier 1 storage halls.
zone(1, 1, -225, -225, -100, 225, "Basement west storage")
zone(1, 1, 100, -225, 225, 225, "Basement east storage")
zone(1, 2, -100, -225, 100, 225, "Security corridors")
-- Floor 2: ground. Public lobby and ballroom, tier 1 staff wing in the east.
zone(2, 0, -225, -225, 75, 225, "Lobby and ballroom")
zone(2, 1, 75, -225, 225, -60, "Kitchens")
zone(2, 1, 75, -60, 225, 60, "Offices and coat check")
zone(2, 0, 75, 60, 225, 225, "Side garden hall")
-- Floor 3: mezzanine. Galleries, staff offices, the security hub in the middle.
zone(3, 0, -225, -225, -75, 225, "West galleries")
zone(3, 1, -75, -225, 75, -75, "North offices")
zone(3, 2, -75, -75, 75, 75, "Security hub")
zone(3, 0, -75, 75, 75, 225, "South mezzanine")
zone(3, 1, 75, -225, 225, 225, "Catering and offices")
-- Floor 4: top. Executive penthouse inside a ring of tier 2 guard halls.
zone(4, 2, -225, -225, -150, 225, "West guard hall")
zone(4, 2, 150, -225, 225, 225, "East guard hall")
zone(4, 2, -150, -225, 150, -150, "North guard hall")
zone(4, 2, -150, 150, 150, 225, "South guard hall")
zone(4, 3, -150, -150, 150, 150, "Penthouse")
-- Floor 5: roof.
zone(5, 0, -225, -225, 225, 225, "Rooftop")

local function zoneAt(floor: number, x: number, z: number): Zone?
	for _, candidate in zones do
		local r = candidate.rect
		if candidate.floor == floor and x > r.x1 and x < r.x2 and z > r.z1 and z < r.z2 then
			return candidate
		end
	end
	return nil
end

local function tierAtPoint(floor: number, x: number, z: number): number
	local found = zoneAt(floor, x, z)
	return if found then found.tier else 0
end

-- Ramps (spec 4.4 needs every floor reachable on foot). Each climbs 24 studs toward +z over 48 studs.
local ramps: { Ramp } = {
	{ from = 1, x = -180, z0 = 100 },
	{ from = 1, x = 180, z0 = 100 },
	{ from = 2, x = -120, z0 = -100 },
	{ from = 2, x = 150, z0 = -200 },
	{ from = 3, x = -190, z0 = -100 },
	{ from = 3, x = 190, z0 = -100 },
	{ from = 4, x = -190, z0 = 40 },
	{ from = 4, x = 190, z0 = 40 },
}

local vaultCenters = { Vector2.new(-110, -110), Vector2.new(110, -110), Vector2.new(0, 110) }

-- True if something solid (a ramp body, a slab hole, a vault room) occupies the point on that floor.
local function blocked(floor: number, x: number, z: number, margin: number): boolean
	for _, ramp in ramps do
		if (ramp.from == floor or ramp.from + 1 == floor) and math.abs(x - ramp.x) < RAMP_W / 2 + margin then
			if z > ramp.z0 - margin and z < ramp.z0 + RAMP_RUN + margin then
				return true
			end
		end
	end
	if floor == 4 then
		for _, center in vaultCenters do
			if math.abs(x - center.X) < 12 + margin and math.abs(z - center.Y) < 12 + margin then
				return true
			end
		end
	end
	return false
end

-- Slabs ------------------------------------------------------------------------

local function subtract(rects: { Rect }, hole: Rect): { Rect }
	local out: { Rect } = {}
	for _, r in rects do
		if hole.x2 <= r.x1 or hole.x1 >= r.x2 or hole.z2 <= r.z1 or hole.z1 >= r.z2 then
			table.insert(out, r)
		else
			if hole.x1 > r.x1 then
				table.insert(out, { x1 = r.x1, z1 = r.z1, x2 = hole.x1, z2 = r.z2 })
			end
			if hole.x2 < r.x2 then
				table.insert(out, { x1 = hole.x2, z1 = r.z1, x2 = r.x2, z2 = r.z2 })
			end
			local mx1, mx2 = math.max(r.x1, hole.x1), math.min(r.x2, hole.x2)
			if hole.z1 > r.z1 then
				table.insert(out, { x1 = mx1, z1 = r.z1, x2 = mx2, z2 = hole.z1 })
			end
			if hole.z2 < r.z2 then
				table.insert(out, { x1 = mx1, z1 = hole.z2, x2 = mx2, z2 = r.z2 })
			end
		end
	end
	return out
end

local function rectPart(parent: Instance, name: string, r: Rect, y: number, height: number, color: Color3): Part
	return part(
		parent,
		name,
		Vector3.new(r.x2 - r.x1, height, r.z2 - r.z1),
		CFrame.new((r.x1 + r.x2) / 2, y, (r.z1 + r.z2) / 2),
		color
	)
end

for _, z in zones do
	local pieces: { Rect } = { z.rect }
	for _, ramp in ramps do
		if ramp.from + 1 == z.floor then
			pieces = subtract(pieces, {
				x1 = ramp.x - RAMP_W / 2 - 1,
				z1 = ramp.z0,
				x2 = ramp.x + RAMP_W / 2 + 1,
				z2 = ramp.z0 + RAMP_RUN,
			})
		end
	end
	local color = tierColor(z.tier):Lerp(GREY, 0.6)
	for _, piece in pieces do
		rectPart(geometry, `Slab_{FLOOR_NAMES[z.floor]}_{z.name}`, piece, FLOOR_Y[z.floor] - SLAB / 2, SLAB, color)
	end
end

-- Exterior ground around the building.
for _, r in
	{
		{ x1 = -330, z1 = -330, x2 = 330, z2 = -HALF },
		{ x1 = -330, z1 = HALF, x2 = 330, z2 = 330 },
		{ x1 = -330, z1 = -HALF, x2 = -HALF, z2 = HALF },
		{ x1 = HALF, z1 = -HALF, x2 = 330, z2 = HALF },
	} :: { Rect }
do
	rectPart(geometry, "Ground", r, -SLAB / 2, SLAB, Color3.fromRGB(95, 130, 85))
end

-- Ramps
local ramp_angle = math.atan2(RAMP_RISE, RAMP_RUN)
local ramp_length = math.sqrt(RAMP_RISE ^ 2 + RAMP_RUN ^ 2)
for _, ramp in ramps do
	local baseY = FLOOR_Y[ramp.from]
	local center =
		Vector3.new(ramp.x, baseY + RAMP_RISE / 2 - math.cos(ramp_angle), ramp.z0 + RAMP_RUN / 2 + math.sin(ramp_angle))
	part(
		geometry,
		`Ramp_{FLOOR_NAMES[ramp.from]}_to_{FLOOR_NAMES[ramp.from + 1]}`,
		Vector3.new(RAMP_W, 2, ramp_length),
		CFrame.new(center) * CFrame.Angles(-ramp_angle, 0, 0),
		Color3.fromRGB(120, 120, 130)
	)
end

-- Zone volumes -----------------------------------------------------------------

for _, z in zones do
	local r = z.rect
	local volume = part(
		zonesFolder,
		`Zone_{FLOOR_NAMES[z.floor]}_T{z.tier}_{z.name}`,
		Vector3.new(r.x2 - r.x1 + ZONE_PAD * 2, 24, r.z2 - r.z1 + ZONE_PAD * 2),
		CFrame.new((r.x1 + r.x2) / 2, FLOOR_Y[z.floor] + 11, (r.z1 + r.z2) / 2),
		tierColor(z.tier)
	)
	ghost(volume)
	tag(volume, Tag.ZoneVolume, { Tier = z.tier })
end
-- Everything outside the building (grounds, loading yard, garden lawn) is Public.
local grounds = part(zonesFolder, "Zone_Grounds_T0", Vector3.new(700, 140, 700), CFrame.new(0, 40, 0), tierColor(0))
ghost(grounds)
tag(grounds, Tag.ZoneVolume, { Tier = 0 })

-- Walls and doorways -------------------------------------------------------------

-- Doorways that connect two tiers on purpose as keycard shortcuts: floor, axis, line, position along the wall.
local KEYCARD_GAPS = {
	{ 2, "z", 75, 30 },
	{ 2, "z", 75, -110 },
	{ 3, "z", 75, 30 },
	{ 3, "x", -75, 40 },
	{ 1, "z", 100, -40 },
	{ 4, "z", 150, 40 },
}
-- Doorways that get a laser grid, in tier 2 and 3 areas only.
local LASER_GAPS = { { 4, "z", -150, 0 }, { 4, "z", 150, 0 }, { 1, "z", -100, 0 }, { 1, "z", 100, 0 } }

local function isListed(list: { { any } }, floor: number, axis: string, line: number, pos: number): boolean
	for _, entry in list do
		if entry[1] == floor and entry[2] == axis and entry[3] == line and entry[4] == pos then
			return true
		end
	end
	return false
end

-- A wall segment along `axis` ("x": runs along x at z = line; "z": runs along z at x = line).
local function wallPiece(floor: number, axis: string, line: number, a: number, b: number, height: number)
	if b - a < 0.5 then
		return
	end
	local mid = (a + b) / 2
	local y = FLOOR_Y[floor] + height / 2
	local size = if axis == "x" then Vector3.new(b - a, height, WALL_T) else Vector3.new(WALL_T, height, b - a)
	local position = if axis == "x" then Vector3.new(mid, y, line) else Vector3.new(line, y, mid)
	part(geometry, "Wall", size, CFrame.new(position), GREY)
end

local function alongAxis(axis: string, line: number, pos: number, y: number): Vector3
	return if axis == "x" then Vector3.new(pos, y, line) else Vector3.new(line, y, pos)
end

local function doorway(floor: number, axis: string, line: number, pos: number, sideLo: Zone?, sideHi: Zone?)
	local baseY = FLOOR_Y[floor]
	local alongSize = function(length: number, height: number, depth: number): Vector3
		return if axis == "x" then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
	end

	part(
		geometry,
		"Lintel",
		alongSize(GAP_W, WALL_H - GAP_H, WALL_T),
		CFrame.new(alongAxis(axis, line, pos, baseY + GAP_H + (WALL_H - GAP_H) / 2)),
		GREY
	)

	if not (sideLo and sideHi) or sideLo.tier == sideHi.tier then
		return
	end
	local high = if sideLo.tier > sideHi.tier then sideLo.tier else sideHi.tier
	for _, offset in { -GAP_W / 2 + 0.6, GAP_W / 2 - 0.6 } do
		part(
			trim,
			"DoorPost",
			alongSize(1.2, GAP_H, WALL_T + 0.6),
			CFrame.new(alongAxis(axis, line, pos + offset, baseY + GAP_H / 2)),
			tierColor(high)
		)
	end
	-- Floor decals show which tier is on each side.
	for sign, side in { [-1] = sideLo, [1] = sideHi } do
		local decal = part(
			trim,
			"FloorDecal",
			alongSize(GAP_W, 0.2, 4),
			CFrame.new(alongAxis(axis, line + sign * (WALL_T / 2 + 2), pos, baseY + 0.1) + Vector3.zero),
			tierColor(side.tier)
		)
		decal.CanCollide = false
	end
end

local function mergeIntervals(list: { { number } }): { { number } }
	table.sort(list, function(p, q)
		return p[1] < q[1]
	end)
	local merged: { { number } } = {}
	for _, interval in list do
		local last = merged[#merged]
		if last and interval[1] <= last[2] then
			last[2] = math.max(last[2], interval[2])
		else
			table.insert(merged, { interval[1], interval[2] })
		end
	end
	return merged
end

local laserSites: { { any } } = {}

for floor = 1, ROOF do
	local edges: { [string]: { axis: string, line: number, intervals: { { number } } } } = {}
	local function addEdge(axis: string, line: number, a: number, b: number)
		local key = `{axis}|{line}`
		local edge = edges[key]
		if not edge then
			edge = { axis = axis, line = line, intervals = {} }
			edges[key] = edge
		end
		table.insert(edge.intervals, { a, b })
	end
	for _, z in zones do
		if z.floor == floor then
			local r = z.rect
			addEdge("x", r.z1, r.x1, r.x2)
			addEdge("x", r.z2, r.x1, r.x2)
			addEdge("z", r.x1, r.z1, r.z2)
			addEdge("z", r.x2, r.z1, r.z2)
		end
	end

	for _, edge in edges do
		local axis, line = edge.axis, edge.line
		for _, interval in mergeIntervals(edge.intervals) do
			local a, b = interval[1], interval[2]
			local height = if floor == ROOF then ROOF_WALL_H else WALL_H
			local gaps: { { pos: number, lo: Zone?, hi: Zone? } } = {}

			if floor ~= ROOF then
				local candidates: { number } = {}
				local first = math.ceil((a + GAP_W / 2 + 1) / GRID)
				for pos = first * GRID, b - GAP_W / 2 - 1, GRID do
					table.insert(candidates, pos)
				end
				for _, entry in KEYCARD_GAPS do
					if
						entry[1] == floor
						and entry[2] == axis
						and entry[3] == line
						and entry[4] > a
						and entry[4] < b
					then
						table.insert(candidates, entry[4])
					end
				end
				table.sort(candidates)

				for _, pos in candidates do
					local lo = if axis == "x" then zoneAt(floor, pos, line - 3) else zoneAt(floor, line - 3, pos)
					local hi = if axis == "x" then zoneAt(floor, pos, line + 3) else zoneAt(floor, line + 3, pos)
					local interior = lo ~= nil and hi ~= nil
					local entrance = floor == 2
						and (lo or hi) ~= nil
						and ((lo or hi) :: Zone).tier == 0
						and math.abs(line) == HALF
					if interior or entrance then
						table.insert(gaps, { pos = pos, lo = lo, hi = hi })
					end
				end
			end

			local cursor = a - WALL_T / 2
			for _, gap in gaps do
				wallPiece(floor, axis, line, cursor, gap.pos - GAP_W / 2, height)
				cursor = gap.pos + GAP_W / 2
				doorway(floor, axis, line, gap.pos, gap.lo, gap.hi)
				if gap.lo then
					gap.lo.doorways += 1
				end
				if gap.hi then
					gap.hi.doorways += 1
				end

				local maxTier = math.max(if gap.lo then gap.lo.tier else 0, if gap.hi then gap.hi.tier else 0)
				local baseY = FLOOR_Y[floor]
				if isListed(KEYCARD_GAPS, floor, axis, line, gap.pos) then
					local size = if axis == "x" then Vector3.new(GAP_W, GAP_H, 1) else Vector3.new(1, GAP_H, GAP_W)
					local door = part(
						objects,
						"KeycardDoor",
						size,
						CFrame.new(alongAxis(axis, line, gap.pos, baseY + GAP_H / 2)),
						tierColor(maxTier)
					)
					tag(door, Tag.KeycardDoor, { Tier = maxTier })
				elseif isListed(LASER_GAPS, floor, axis, line, gap.pos) then
					local size = if axis == "x"
						then Vector3.new(GAP_W, GAP_H - 2, 0.3)
						else Vector3.new(0.3, GAP_H - 2, GAP_W)
					local laser = part(
						objects,
						"LaserGrid",
						size,
						CFrame.new(alongAxis(axis, line, gap.pos, baseY + GAP_H / 2)),
						Color3.fromRGB(255, 30, 30)
					)
					laser.Material = Enum.Material.Neon
					laser.Transparency = 0.4
					laser.CanCollide = false
					tag(laser, Tag.LaserGrid, { Tier = maxTier })
					table.insert(laserSites, { maxTier })
				end
			end
			wallPiece(floor, axis, line, cursor, b + WALL_T / 2, height)
		end
	end
end

-- Vault rooms: 24 x 24 with a doorway in the middle of all four sides (4 routes out, spec 4.4).
for index, center in vaultCenters do
	local y = FLOOR_Y[4]
	local half, door = 12, 4
	local function side(axis: string, line: number, along: number)
		local lo = { along - half, along - door }
		local hi = { along + door, along + half }
		for _, span in { lo, hi } do
			local length = span[2] - span[1]
			local mid = (span[1] + span[2]) / 2
			local size = if axis == "x"
				then Vector3.new(length, WALL_H, WALL_T)
				else Vector3.new(WALL_T, WALL_H, length)
			local position = if axis == "x"
				then Vector3.new(mid, y + WALL_H / 2, line)
				else Vector3.new(line, y + WALL_H / 2, mid)
			part(geometry, `VaultWall{index}`, size, CFrame.new(position), Color3.fromRGB(90, 90, 100))
		end
	end
	side("x", center.Y - half, center.X)
	side("x", center.Y + half, center.X)
	side("z", center.X - half, center.Y)
	side("z", center.X + half, center.Y)

	local spawn = part(
		objects,
		`VaultSpawn{index}`,
		Vector3.new(4, 1.5, 4),
		CFrame.new(center.X, y + 0.75, center.Y),
		Color3.fromRGB(255, 215, 0)
	)
	tag(spawn, Tag.VaultSpawn, { VaultId = index })
end

-- Tagged objects -------------------------------------------------------------------

local function at(floor: number, x: number, z: number, lift: number): Vector3
	return Vector3.new(x, FLOOR_Y[floor] + lift, z)
end

local function marker(
	name: string,
	floor: number,
	x: number,
	z: number,
	size: Vector3,
	color: Color3,
	tagName: string,
	extra: { [string]: any }?
)
	local p = part(objects, name, size, CFrame.new(at(floor, x, z, size.Y / 2)), color)
	local attributes: { [string]: any } = { Tier = tierAtPoint(floor, x, z), Floor = FLOOR_NAMES[floor] }
	for key, value in extra or {} do
		attributes[key] = value
	end
	tag(p, tagName, attributes)
	return p
end

-- 12 insertion points in the public areas, at least 60 studs apart.
local insertion = {}
for _, z in { -190, 0, 190 } do
	for _, x in { -190, -130, -70, -10 } do
		table.insert(insertion, Vector3.new(x, 0, z))
	end
end
for index, p in insertion do
	local point = marker(
		`InsertionPoint{index}`,
		2,
		p.X,
		p.Z,
		Vector3.new(4, 0.4, 4),
		Color3.fromRGB(0, 200, 120),
		Tag.InsertionPoint
	)
	point.Transparency = 0.4
	point.CanCollide = false
end

-- Intel: x, z, floor, kind. At least two per tier.
local intel = {
	{ -200, -120, 2, "Terminal" },
	{ -40, -190, 2, "Briefcase" },
	{ -60, 180, 2, "Terminal" },
	{ -190, 100, 3, "Terminal" },
	{ -120, -190, 3, "Briefcase" },
	{ 150, -190, 2, "Terminal" },
	{ 200, 20, 2, "Briefcase" },
	{ 150, -40, 3, "Terminal" },
	{ 190, 150, 3, "Terminal" },
	{ 0, -190, 3, "Briefcase" },
	{ 0, -150, 1, "Terminal" },
	{ 30, 120, 1, "ServerRack" },
	{ -30, 200, 1, "Terminal" },
	{ 40, 40, 3, "Terminal" },
	{ -185, -170, 4, "ServerRack" },
	{ 0, -60, 4, "Terminal" },
	{ 60, 60, 4, "ServerRack" },
	{ -60, 60, 4, "Terminal" },
}
local intelShapes = {
	Terminal = { Vector3.new(3, 5, 1), Color3.fromRGB(40, 200, 255) },
	Briefcase = { Vector3.new(2, 1, 1.5), Color3.fromRGB(255, 215, 0) },
	ServerRack = { Vector3.new(3, 7, 3), Color3.fromRGB(50, 50, 60) },
}
for index, entry in intel do
	local shape = intelShapes[entry[4]]
	marker(`IntelSpawn{index}`, entry[3], entry[1], entry[2], shape[1], shape[2], Tag.IntelSpawn, { Kind = entry[4] })
end

-- Extraction sites: rooftop helipad, loading dock (west yard), garden lawn (south-east grounds).
for _, site in
	{
		{ "Helipad", 5, 170, 170 },
		{ "LoadingDock", 2, -270, 0 },
		{ "GardenLawn", 2, 230, 270 },
	}
do
	local pad = marker(
		`Extraction_{site[1]}`,
		site[2],
		site[3],
		site[4],
		Vector3.new(14, 1, 14),
		Color3.fromRGB(0, 220, 90),
		Tag.ExtractionSite,
		{ Site = site[1] }
	)
	pad.Material = Enum.Material.Neon
end

-- Supply caches: two public, two staff, one security, one executive.
for index, c in
	{
		{ -150, 60, 2 },
		{ -150, -60, 3 },
		{ 180, -120, 2 },
		{ 150, 100, 3 },
		{ -50, 0, 1 },
		{ 0, 0, 4 },
	}
do
	marker(`SupplyCache{index}`, c[3], c[1], c[2], Vector3.new(4, 4, 4), Color3.fromRGB(230, 170, 40), Tag.SupplyCache)
end

-- Security cameras near the ceiling.
for index, c in
	{
		{ 210, -200, 2 },
		{ 210, 50, 2 },
		{ 60, -200, 3 },
		{ 60, 60, 3 },
		{ -60, -60, 3 },
		{ -90, -210, 1 },
		{ 90, 210, 1 },
		{ 0, 0, 1 },
		{ -210, -210, 4 },
		{ 210, 210, 4 },
		{ -140, -140, 4 },
		{ 140, 140, 4 },
	}
do
	local camera = marker(
		`SecurityCamera{index}`,
		c[3],
		c[1],
		c[2],
		Vector3.new(2, 2, 3),
		Color3.fromRGB(40, 40, 45),
		Tag.SecurityCamera
	)
	camera.Position = at(c[3], c[1], c[2], WALL_H - 2)
end

-- Vents in pairs. Each pair shares a PairId.
for pair, v in
	{
		{ 2, -200, 200, 2, 200, -40 },
		{ 3, -200, -200, 3, 0, -150 },
		{ 3, 0, 150, 3, 0, 0 },
		{ 1, -200, -200, 1, 0, -200 },
		{ 1, 200, 200, 1, 0, 200 },
		{ 4, -200, 200, 4, 0, 0 },
	}
do
	marker(
		`Vent{pair}A`,
		v[1],
		v[2],
		v[3],
		Vector3.new(5, 1, 5),
		Color3.fromRGB(70, 70, 70),
		Tag.Vent,
		{ PairId = pair, Side = "A" }
	)
	marker(
		`Vent{pair}B`,
		v[4],
		v[5],
		v[6],
		Vector3.new(5, 1, 5),
		Color3.fromRGB(70, 70, 70),
		Tag.Vent,
		{ PairId = pair, Side = "B" }
	)
end

-- Ziplines: roof corner to the grounds, two pairs.
for pair, z in { { -200, -222, -300 }, { 200, 222, 300 } } do
	local top = marker(
		`Zipline{pair}A`,
		5,
		z[1],
		z[2],
		Vector3.new(2, 4, 2),
		Color3.fromRGB(200, 200, 60),
		Tag.ZiplineAnchor,
		{ PairId = pair, Side = "A" }
	)
	top.Position = at(5, z[1], z[2], 4)
	marker(
		`Zipline{pair}B`,
		2,
		z[1],
		z[3],
		Vector3.new(2, 8, 2),
		Color3.fromRGB(200, 200, 60),
		Tag.ZiplineAnchor,
		{ PairId = pair, Side = "B" }
	)
end

-- Climb surfaces: low ledges on the west facade.
for index = 1, 12 do
	local ledge = marker(
		`Ledge{index}`,
		2,
		-228,
		-110 + (index - 1) * 20,
		Vector3.new(2, 2, 8),
		Color3.fromRGB(180, 180, 180),
		Tag.ClimbSurface
	)
	ledge.Position = at(2, -228, -110 + (index - 1) * 20, 5)
end

-- Pickup spawns scattered across the four building floors.
local pickupFloors = { 1, 2, 2, 3, 3, 4 }
local pickupCount = 0
while pickupCount < GameConfig.Map.Counts.PickupSpawn do
	local floor = pickupFloors[rng:NextInteger(1, #pickupFloors)]
	local candidates: { Zone } = {}
	for _, z in zones do
		if z.floor == floor then
			table.insert(candidates, z)
		end
	end
	local z = candidates[rng:NextInteger(1, #candidates)]
	local x = rng:NextNumber(z.rect.x1 + 20, z.rect.x2 - 20)
	local zz = rng:NextNumber(z.rect.z1 + 20, z.rect.z2 - 20)
	if not blocked(floor, x, zz, 10) then
		pickupCount += 1
		marker(
			`PickupSpawn{pickupCount}`,
			floor,
			x,
			zz,
			Vector3.new(2, 1, 2),
			Color3.fromRGB(240, 240, 240),
			Tag.PickupSpawn
		)
	end
end

-- NPC nodes on a grid inside each zone (not on the roof). Spacing depends on the tier.
local spacing = { [0] = 70, [1] = 50, [2] = 55, [3] = 60 }
local activities: { [number]: { string } } = {
	[0] = { "Walk", "Walk", "Idle", "Talk", "Sit", "Lean", "Drink" },
	[1] = { "Walk", "Work", "Work", "Idle", "Talk", "Drink" },
	[2] = { "Guard", "Guard", "Walk", "Idle" },
	[3] = { "Walk", "Idle", "Talk", "Drink", "Sit" },
}
local nodeCount = 0
for _, z in zones do
	if z.floor ~= ROOF then
		local step = spacing[z.tier]
		local r = z.rect
		local x = r.x1 + 15
		while x <= r.x2 - 15 do
			local zz = r.z1 + 15
			while zz <= r.z2 - 15 do
				if not blocked(z.floor, x, zz, 6) then
					local pool = activities[z.tier]
					nodeCount += 1
					local node = part(
						nodes,
						`NPCNode{nodeCount}`,
						Vector3.new(1, 1, 1),
						CFrame.new(at(z.floor, x, zz, 1)),
						Color3.fromRGB(255, 255, 0)
					)
					ghost(node)
					tag(node, Tag.NPCNode, { Tier = z.tier, Activity = pool[rng:NextInteger(1, #pool)] })
				end
				zz += step
			end
			x += step
		end
	end
end

-- Test spawn: a placeholder so a Studio playtest starts inside the map. Step 10 replaces it with insertion.
for _, other in workspace:GetDescendants() do
	if other:IsA("SpawnLocation") then
		other.Enabled = false
	end
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "TestSpawn"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(-40, 0.5, 60)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = objects

root.Parent = workspace

-- Validation -----------------------------------------------------------------------

local problems = 0
local function check(ok: boolean, message: string)
	if not ok then
		problems += 1
	end
	print(`[Gala] {if ok then "ok  " else "FAIL"} {message}`)
end

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
check(count(Tag.IntelSpawn) == counts.IntelSpawn, `IntelSpawn {count(Tag.IntelSpawn)}/{counts.IntelSpawn}`)
check(count(Tag.VaultSpawn) == counts.VaultSpawn, `VaultSpawn {count(Tag.VaultSpawn)}/{counts.VaultSpawn}`)
check(
	count(Tag.ExtractionSite) == counts.ExtractionSite,
	`ExtractionSite {count(Tag.ExtractionSite)}/{counts.ExtractionSite}`
)
check(count(Tag.SupplyCache) == counts.SupplyCache, `SupplyCache {count(Tag.SupplyCache)}/{counts.SupplyCache}`)
check(
	count(Tag.SecurityCamera) == counts.SecurityCamera,
	`SecurityCamera {count(Tag.SecurityCamera)}/{counts.SecurityCamera}`
)
check(count(Tag.LaserGrid) == counts.LaserGrid, `LaserGrid {count(Tag.LaserGrid)}/{counts.LaserGrid}`)
check(count(Tag.KeycardDoor) == counts.KeycardDoor, `KeycardDoor {count(Tag.KeycardDoor)}/{counts.KeycardDoor}`)
check(count(Tag.Vent) == counts.VentPairs * 2, `Vent parts {count(Tag.Vent)}/{counts.VentPairs * 2}`)
check(
	count(Tag.ZiplineAnchor) == counts.ZiplineAnchorPairs * 2,
	`ZiplineAnchor parts {count(Tag.ZiplineAnchor)}/{counts.ZiplineAnchorPairs * 2}`
)
check(count(Tag.PickupSpawn) == counts.PickupSpawn, `PickupSpawn {count(Tag.PickupSpawn)}/{counts.PickupSpawn}`)
check(count(Tag.ClimbSurface) > 0, `ClimbSurface {count(Tag.ClimbSurface)}`)
local nodeRange = GameConfig.Map.NPCNodeCount
check(
	nodeCount >= nodeRange.Min and nodeCount <= nodeRange.Max,
	`NPCNode {nodeCount} (want {nodeRange.Min} to {nodeRange.Max})`
)

local zoneVolumes = count(Tag.ZoneVolume)
check(zoneVolumes == #zones + 1, `ZoneVolume {zoneVolumes}/{#zones + 1}`)

local perTier: { [number]: number } = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }
for _, instance in CollectionService:GetTagged(Tag.IntelSpawn) do
	if instance:IsDescendantOf(root) then
		local tier = instance:GetAttribute("Tier") :: number
		perTier[tier] += 1
	end
end
check(
	perTier[0] >= 2 and perTier[1] >= 2 and perTier[2] >= 2 and perTier[3] >= 2,
	`Intel per tier {perTier[0]}/{perTier[1]}/{perTier[2]}/{perTier[3]} (need 2+ each)`
)

local cachePerTier: { [number]: number } = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }
for _, instance in CollectionService:GetTagged(Tag.SupplyCache) do
	if instance:IsDescendantOf(root) then
		local tier = instance:GetAttribute("Tier") :: number
		cachePerTier[tier] += 1
	end
end
local want = GameConfig.Map.SupplyCachesPerTier
check(
	cachePerTier[0] == want[0]
		and cachePerTier[1] == want[1]
		and cachePerTier[2] == want[2]
		and cachePerTier[3] == want[3],
	`SupplyCache per tier {cachePerTier[0]}/{cachePerTier[1]}/{cachePerTier[2]}/{cachePerTier[3]} (want 2/2/1/1)`
)

local spacingOk = true
for i = 1, #insertion do
	for j = i + 1, #insertion do
		if (insertion[i] - insertion[j]).Magnitude < GameConfig.Map.InsertionMinSpacing then
			spacingOk = false
		end
	end
end
check(spacingOk, `InsertionPoints are at least {GameConfig.Map.InsertionMinSpacing} studs apart`)

local extractionOk = true
for _, site in CollectionService:GetTagged(Tag.ExtractionSite) do
	for _, vault in CollectionService:GetTagged(Tag.VaultSpawn) do
		if
			site:IsDescendantOf(root)
			and ((site :: Part).Position - (vault :: Part).Position).Magnitude
				< GameConfig.Map.MinExtractionPathDistanceFromVault
		then
			extractionOk = false
		end
	end
end
check(
	extractionOk,
	`Every extraction site is at least {GameConfig.Map.MinExtractionPathDistanceFromVault} studs from every vault`
)

local entrancesOk = true
for _, z in zones do
	if z.tier >= 1 and z.doorways < GameConfig.Map.MinEntrancesPerRestrictedZone then
		entrancesOk = false
		print(`[Gala]      {z.name} has {z.doorways} doorway(s)`)
	end
end
check(entrancesOk, `Every tier 1+ zone has {GameConfig.Map.MinEntrancesPerRestrictedZone}+ doorways`)

local lasersOk = true
for _, site in laserSites do
	if site[1] < 2 then
		lasersOk = false
	end
end
check(lasersOk, "Laser grids are only in tier 2 and 3")

ChangeHistoryService:SetWaypoint("Build Gala graybox")
print(`[Gala] Built {#root:GetDescendants()} instances, {problems} problem(s). Remember File > Save.`)
