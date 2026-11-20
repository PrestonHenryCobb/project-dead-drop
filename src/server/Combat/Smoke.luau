--!strict
-- Server record of smoke clouds (Feint's last five rounds, STEP8 answers 2026-10-27): everyone sees a cloud, it obscures sight and
-- does no damage. CombatService adds each cloud when it sends SmokeCloud; the sight checks (Agent Sense, scans, witnesses, guards,
-- cameras) ask whether a line passes through one.
--
--   Smoke.add(position, radius, expiresAt)   expiresAt is on the server clock (workspace:GetServerTimeNow())
--   Smoke.blocks(from, to) -> boolean        the straight line from one point to the other touches a live cloud
--                                            (a viewer standing inside a cloud is blocked too)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Smoke = {}

type Cloud = { position: Vector3, radius: number, expiresAt: number }

local clouds: { Cloud } = {}

local function prune(now: number)
	for index = #clouds, 1, -1 do
		if clouds[index].expiresAt <= now then
			table.remove(clouds, index)
		end
	end
end

function Smoke.add(position: Vector3, radius: number, expiresAt: number)
	prune(workspace:GetServerTimeNow())
	if #clouds >= GameConfig.Combat.SmokeMaxClouds then
		table.remove(clouds, 1)
	end
	table.insert(clouds, { position = position, radius = radius, expiresAt = expiresAt })
end

function Smoke.blocks(from: Vector3, to: Vector3): boolean
	if #clouds == 0 then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	for _, cloud in clouds do
		if cloud.expiresAt > now then
			local along = if lengthSquared > 1e-6
				then math.clamp((cloud.position - from):Dot(segment) / lengthSquared, 0, 1)
				else 0
			if (from + segment * along - cloud.position).Magnitude <= cloud.radius then
				return true
			end
		end
	end
	return false
end

return Smoke
