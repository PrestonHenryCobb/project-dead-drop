--!strict
-- Ticket 14: finds a clear piece of floor for an object the server makes at match start (a fuse box beside a laser grid,
-- the Camera Room terminal), since the generator does not place them.
--
--   Placement.clearSpot(origin, size, minStuds, maxStuds) -> Vector3?
--     The centre of a box of that size resting on the floor, on the nearest clear spot between minStuds and maxStuds
--     (on the floor plan) from `origin`, on the floor below origin (within FloorProbeStuds). Nil if there is none.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Placement = {}

local FLOOR_PROBE_STUDS = 20 -- how far below the origin to look for floor
local RING_STEP_STUDS = 2
local ANGLES = 12
local CLEARANCE_STUDS = 0.2 -- the box floats this far above the floor so the floor itself does not count as in the way

local floorParams = RaycastParams.new()
floorParams.CollisionGroup = GameConfig.Rig.CollisionGroup
floorParams.RespectCanCollide = true

local boxParams = OverlapParams.new()
boxParams.CollisionGroup = GameConfig.Rig.CollisionGroup
boxParams.RespectCanCollide = true

function Placement.clearSpot(origin: Vector3, size: Vector3, minStuds: number, maxStuds: number): Vector3?
	local radius = minStuds
	while radius <= maxStuds do
		local steps = if radius == 0 then 1 else ANGLES
		for index = 0, steps - 1 do
			local angle = index / steps * math.pi * 2
			local x = origin.X + math.cos(angle) * radius
			local z = origin.Z + math.sin(angle) * radius
			local hit =
				workspace:Raycast(Vector3.new(x, origin.Y, z), Vector3.new(0, -FLOOR_PROBE_STUDS, 0), floorParams)
			if hit then
				local centre = Vector3.new(x, hit.Position.Y + CLEARANCE_STUDS + size.Y / 2, z)
				if #workspace:GetPartBoundsInBox(CFrame.new(centre), size, boxParams) == 0 then
					return Vector3.new(x, hit.Position.Y + size.Y / 2, z)
				end
			end
		end
		radius += RING_STEP_STUDS
	end
	return nil
end

return Placement
