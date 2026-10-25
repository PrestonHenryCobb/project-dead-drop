--!strict
-- How an NPC gets from place to place (spec 5.2): follow a route at the NPC's speed, easing up from a stop and down
-- to one exactly as players do (step 8B.5), turn no faster than GameConfig.NPC.MaxYawRate, keep apart from other NPCs,
-- and write the result to the anchored root.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local Knockdown = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Knockdown"))
local NpcTypes = require(script.Parent.NpcTypes)

type Npc = NpcTypes.Npc

local config = GameConfig.NPC
local movement = GameConfig.Movement
local PLACE_TOLERANCE = 0.01 -- studs and radians; smaller changes are not worth replicating

local Movement = {}

-- Yaw such that CFrame.Angles(0, yaw, 0) looks along the direction.
local function yawToward(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function turnToward(current: number, target: number, maxStep: number): number
	local delta = (target - current + math.pi) % (2 * math.pi) - math.pi
	return current + math.clamp(delta, -maxStep, maxStep)
end

-- How far is left to walk along the path, counting no further than `limit`.
local function distanceLeft(npc: Npc, path: { Vector3 }, limit: number): number
	local total = 0
	local from = npc.ground
	for index = npc.pathIndex, #path do
		total += (path[index] - from).Magnitude
		if total >= limit then
			return limit
		end
		from = path[index]
	end
	return total
end

-- The speed for this tick (step 8B.5): it eases up from a stop over Movement.AccelSeconds and eases down to a stop over
-- DecelSeconds, braking in time to stand at the end of the path. Players ease with the same two numbers.
local function easedSpeed(npc: Npc, path: { Vector3 }, dt: number): number
	local cruise = npc.speed
	local accel = cruise / movement.AccelSeconds
	local decel = cruise / movement.DecelSeconds
	local brakeStuds = cruise * cruise / (2 * decel)
	local left = distanceLeft(npc, path, brakeStuds)
	local target = if left < brakeStuds then math.sqrt(2 * decel * left) else cruise
	local speed = npc.moveSpeed
	if speed < target then
		speed = math.min(target, speed + accel * dt)
	else
		speed = math.max(target, speed - decel * dt)
	end
	-- Never stall short of the end: the last fraction of a stud is walked at a crawl rather than not at all.
	return math.max(speed, math.min(cruise, accel * dt))
end

-- Walks along the NPC's path for dt seconds. Returns true when the end of the path was reached.
function Movement.follow(npc: Npc, dt: number): boolean
	local path = npc.path
	if not path then
		npc.moveSpeed = 0
		return true
	end

	npc.moveSpeed = easedSpeed(npc, path, dt)
	local remaining = npc.moveSpeed * dt
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
		npc.moveSpeed = 0
		return true
	end
	return false
end

-- Stops a walk part way and keeps the rest of its stored path, so the NPC finishes it before taking any new route:
-- a straight line from mid-path to the next route's start could cut through a zone its role may not enter.
function Movement.interrupt(npc: Npc)
	local path = npc.path
	if path and npc.pathIndex <= #path then
		npc.resume = table.move(path, npc.pathIndex, #path, 1, {})
	end
	npc.path = nil
end

-- A new route, preceded by whatever stored path an interruption left unfinished.
function Movement.withResume(npc: Npc, points: { Vector3 }): { Vector3 }
	local resume = npc.resume
	npc.resume = nil
	if not resume then
		return points
	end
	return table.move(points, 1, #points, #resume + 1, resume)
end

-- Pushes NPCs that are closer than SeparationStuds apart away from each other (spec 5.2).
function Movement.separate(npcs: { Npc }, dt: number, rng: Random)
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

-- Writes the NPC's position and facing to its root, if they changed.
function Movement.place(npc: Npc)
	-- A downed NPC lies on its front or back with its head the way it is crawling (Util/Knockdown, as players do).
	local lying = npc.state == "Downed" or npc.state == "Eliminated"
	local height = if lying then config.Death.RootLiftStuds else npc.rootHeight
	local position = npc.ground + npc.offset + Vector3.new(0, height, 0)
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
	npc.root.CFrame = if lying
		then Knockdown.lyingCFrame(npc.ground + npc.offset, npc.yaw, npc.posture)
		else CFrame.new(position) * CFrame.Angles(0, npc.yaw, 0)
end

return Movement
