--!strict
-- Where something put down in front of a player goes: on the floor `ahead` studs along their facing. Used by Suture's kit and the
-- deployable gadgets.
--
--   Spot.ahead(root, ahead, probeUp, probeDown) -> (Vector3, Vector3)   the floor point and the way the player faces (flat, unit)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Spot = {}

-- Rays in the character group meet only the map.
local floorParams = RaycastParams.new()
floorParams.CollisionGroup = GameConfig.Rig.CollisionGroup
floorParams.RespectCanCollide = true

function Spot.ahead(root: BasePart, ahead: number, probeUp: number, probeDown: number): (Vector3, Vector3)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local facing = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local point = root.Position + facing * ahead
	local hit =
		workspace:Raycast(point + Vector3.new(0, probeUp, 0), Vector3.new(0, -(probeUp + probeDown), 0), floorParams)
	return if hit then hit.Position else point, facing
end

-- The surface a ray from `origin` along `aim` meets within `reach`: where, and which way it faces. Nil when it meets nothing.
function Spot.surface(origin: Vector3, aim: Vector3, reach: number): (Vector3?, Vector3?)
	local hit = workspace:Raycast(origin, aim * reach, floorParams)
	if hit then
		return hit.Position, hit.Normal
	end
	return nil, nil
end

-- The nearest wall (or other map solid) along `direction` from `origin`, at most `reach` away: the point, or the end of `reach`.
function Spot.reachAlong(origin: Vector3, direction: Vector3, reach: number): Vector3
	local hit = workspace:Raycast(origin, direction * reach, floorParams)
	return if hit then hit.Position else origin + direction * reach
end

return Spot
