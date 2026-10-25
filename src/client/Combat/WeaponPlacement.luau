--!strict
-- Step 8B.3: camera-space gun bounds, real-FOV framing and five inexpensive wall probes. No per-frame tables.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local config = GameConfig.Combat.Presentation
local radius = config.WallRayRadiusStuds
local probes = {
	Vector3.zero,
	Vector3.new(radius, 0, 0),
	Vector3.new(-radius, 0, 0),
	Vector3.new(0, radius, 0),
	Vector3.new(0, -radius, 0),
}
local params = RaycastParams.new()
params.CollisionGroup = GameConfig.Rig.CollisionGroup
params.RespectCanCollide = true

local WeaponPlacement = {}

function WeaponPlacement.wallDistance(camera: Camera): number
	local nearest = config.WallReachStuds
	local cframe = camera.CFrame
	local ray = cframe.LookVector * config.WallReachStuds
	for _, offset in probes do
		local hit = workspace:Raycast(cframe:PointToWorldSpace(offset), ray, params)
		if hit then
			nearest = math.min(nearest, hit.Distance)
		end
	end
	return nearest
end

function WeaponPlacement.tuckFraction(distance: number): number
	return math.clamp((config.WallReachStuds - distance) / (config.WallReachStuds - config.FullTuckStuds), 0, 1)
end

-- Ticket 8.15: a reachable wall-driven tuck blocks attacks immediately; keep blocking until its visible recovery
-- also clears. The old FullTuckStuds-only gate was usually inside the character's collision clearance.
function WeaponPlacement.attackBlocked(distance: number, visibleTuck: number): boolean
	return math.max(WeaponPlacement.tuckFraction(distance), visibleTuck) > config.AttackBlockTuckFraction
end

-- Shift the entire rotated gun away from the camera until every bound corner fits the current view frustum.
function WeaponPlacement.fit(relative: CFrame, corners: { Vector3 }, fov: number, viewport: Vector2): CFrame
	local slopeY = math.tan(math.rad(fov / 2)) * (1 - config.ScreenMarginFraction)
	local slopeX = slopeY * viewport.X / math.max(viewport.Y, 1)
	local extra = 0
	for _, corner in corners do
		local point = relative:PointToWorldSpace(corner)
		local depth = -point.Z
		extra = math.max(
			extra,
			config.NearDepthStuds - depth,
			math.abs(point.X) / slopeX - depth,
			math.abs(point.Y) / slopeY - depth
		)
	end
	return CFrame.new(0, 0, -extra) * relative
end

function WeaponPlacement.depth(relative: CFrame, corners: { Vector3 }): number
	local farthest = config.NearDepthStuds
	for _, corner in corners do
		farthest = math.max(farthest, -relative:PointToWorldSpace(corner).Z)
	end
	return farthest
end

return WeaponPlacement
