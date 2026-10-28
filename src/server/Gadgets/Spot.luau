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

return Spot
