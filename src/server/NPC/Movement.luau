--!strict
-- How an NPC gets from place to place (spec 5.2): follow a route at the NPC's speed, turn no faster than
-- GameConfig.NPC.MaxYawRate, keep apart from other NPCs, and write the result to the anchored root.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local NpcTypes = require(script.Parent.NpcTypes)

type Npc = NpcTypes.Npc

local config = GameConfig.NPC
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

-- Walks along the NPC's path for dt seconds. Returns true when the end of the path was reached.
function Movement.follow(npc: Npc, dt: number): boolean
	local path = npc.path
	if not path then
		return true
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
		return true
	end
	return false
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

return Movement
