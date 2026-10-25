--!strict
-- Where one ray of a shot goes (spec 13.3). The map stops it; before that, every person whose rewound pose the ray
-- crosses is a hit. Poses are rewound to the continuous moment the shooter's screen showed (History).
--
--   Ballistics.trace(shooter, origin, direction, timestamp, maxHits) -> (hits, endPoint, hitWall)
--     hits: up to maxHits people the ray passes through, nearest first (more than one only for a piercing weapon).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local History = require(script.Parent.History)
local Hitbox = require(script.Parent.Hitbox)

export type Hit = { target: History.Target, distance: number, head: boolean }

local Ballistics = {}

local config = GameConfig.Combat

-- Rays in the character group skip characters and meet only the map (and what blocks shots: glass, shut doors).
local mapParams = RaycastParams.new()
mapParams.CollisionGroup = GameConfig.Rig.CollisionGroup
mapParams.RespectCanCollide = true

function Ballistics.trace(
	shooter: Player,
	origin: Vector3,
	direction: Vector3,
	timestamp: number,
	maxHits: number
): ({ Hit }, Vector3, boolean)
	local serverNow = workspace:GetServerTimeNow()
	local wall = workspace:Raycast(origin, direction * config.MaxShotStuds, mapParams)
	local reach = if wall then wall.Distance else config.MaxShotStuds
	local cull = config.Hitbox.CullStuds
	local hits: { Hit } = {}
	for _, target in History.targets do
		if target.player ~= shooter then
			-- Ticket 8.20: smooth rendering has no artificial step; retain target delay and the rewind safety bounds.
			local when = math.clamp(timestamp - target.delay, serverNow - config.LagCompSeconds, serverNow)
			local root, head = History.poseAt(target, when)
			if root and head then
				local toRoot = root - origin
				local along = toRoot:Dot(direction)
				if along > -cull and along < reach + cull and (toRoot - direction * along).Magnitude <= cull then
					local pose: Hitbox.Pose = {
						root = root,
						head = head,
						feetY = root.Y - target.rootHeight,
						bodyRadius = target.bodyRadius,
						headRadius = target.headRadius,
					}
					local distance, isHead = Hitbox.test(origin, direction, reach, pose)
					if distance then
						table.insert(hits, { target = target, distance = distance, head = isHead })
					end
				end
			end
		end
	end
	table.sort(hits, function(a, b)
		return a.distance < b.distance
	end)
	while #hits > maxHits do
		table.remove(hits)
	end
	-- The ray ends at the last person it stops in, or at the wall.
	local last = hits[#hits]
	local stoppedInPerson = last ~= nil and #hits == maxHits
	local endDistance = if stoppedInPerson then last.distance else reach
	return hits, origin + direction * endDistance, wall ~= nil and not stoppedInPerson
end

return Ballistics
