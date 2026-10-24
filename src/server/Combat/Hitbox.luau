--!strict
-- Ray tests for shots (spec 13.3). A person is a vertical cylinder from the feet up to the head, plus a sphere for the
-- head. The server tests every shot against these at the target's rewound position (History), never against the
-- animated parts, so a shot lands where the shooter saw the target.
--
--   Hitbox.test(origin, direction, maxDistance, pose) -> (distance?, isHead)
--     `direction` is a unit vector. Returns how far along the ray the nearest hit is, and whether it is the head.

local Hitbox = {}

export type Pose = {
	root: Vector3, -- the middle of the body, which the cylinder stands round
	head: Vector3, -- the centre of the head
	feetY: number,
	bodyRadius: number,
	headRadius: number,
}

local HEAD_OVERLAP = 0.7 -- the body cylinder ends this share of a head radius below the head's centre

-- Entry distance of a ray into a sphere, or nil. A ray that starts inside it hits at the way out.
local function raySphere(
	origin: Vector3,
	direction: Vector3,
	center: Vector3,
	radius: number,
	maxDistance: number
): number?
	local offset = origin - center
	local b = offset:Dot(direction)
	local discriminant = b * b - (offset:Dot(offset) - radius * radius)
	if discriminant < 0 then
		return nil
	end
	local root = math.sqrt(discriminant)
	local distance = -b - root
	if distance < 0 then
		distance = -b + root
	end
	if distance < 0 or distance > maxDistance then
		return nil
	end
	return distance
end

-- Entry distance of a ray into a vertical cylinder (sides and both caps), or nil.
local function rayCylinder(
	origin: Vector3,
	direction: Vector3,
	center: Vector3,
	bottomY: number,
	topY: number,
	radius: number,
	maxDistance: number
): number?
	local best: number? = nil
	local function consider(distance: number)
		if distance >= 0 and distance <= maxDistance and (best == nil or distance < best) then
			best = distance
		end
	end

	local ox, oz = origin.X - center.X, origin.Z - center.Z
	local dx, dz = direction.X, direction.Z
	local a = dx * dx + dz * dz
	if a > 1e-9 then
		local b = ox * dx + oz * dz
		local discriminant = b * b - a * (ox * ox + oz * oz - radius * radius)
		if discriminant >= 0 then
			local distance = (-b - math.sqrt(discriminant)) / a
			local y = origin.Y + direction.Y * distance
			if y >= bottomY and y <= topY then
				consider(distance)
			end
		end
	end
	if math.abs(direction.Y) > 1e-9 then
		for _, planeY in { bottomY, topY } do
			local distance = (planeY - origin.Y) / direction.Y
			local px, pz = ox + dx * distance, oz + dz * distance
			if px * px + pz * pz <= radius * radius then
				consider(distance)
			end
		end
	end
	return best
end

function Hitbox.test(origin: Vector3, direction: Vector3, maxDistance: number, pose: Pose): (number?, boolean)
	local headDistance = raySphere(origin, direction, pose.head, pose.headRadius, maxDistance)
	local bodyTop = pose.head.Y - pose.headRadius * HEAD_OVERLAP
	local bodyDistance = rayCylinder(origin, direction, pose.root, pose.feetY, bodyTop, pose.bodyRadius, maxDistance)
	if headDistance and (not bodyDistance or headDistance <= bodyDistance) then
		return headDistance, true
	end
	return bodyDistance, false
end

return Hitbox
