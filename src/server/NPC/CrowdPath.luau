--!strict
-- Ticket crowd-readability: vary an ordinary trip once at departure, never the replicated body independently.
-- Every bend can return to the original route; unsupported, sloped or obstructed sections stay unchanged.
local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))
local config = GameConfig.NPC.WalkVariation
local CrowdPath = {}

function CrowdPath.vary(points: { Vector3 }, rng: Random, canStep: (Vector3, Vector3) -> Vector3?): { Vector3 }
	if #points < 3 then
		return points
	end
	local out = table.clone(points)
	local amplitude = rng:NextNumber(config.OffsetMin, config.OffsetMax)
	local wave = rng:NextNumber(config.WaveStuds.Min, config.WaveStuds.Max)
	local sign = if rng:NextInteger(0, 1) == 0 then -1 else 1
	local total = 0
	for index = 2, #points do
		total += (points[index] - points[index - 1]).Magnitude
	end
	if total == 0 then
		return points
	end
	local travelled = 0
	for index = 2, #points - 1 do
		local before, point, after = points[index - 1], points[index], points[index + 1]
		local incoming, outgoing = point - before, after - point
		travelled += incoming.Magnitude
		if
			incoming.Magnitude > 0
			and (incoming.X ~= 0 or incoming.Z ~= 0)
			and outgoing.Magnitude > 0
			and math.abs(incoming.Y) <= config.MaxRiseStuds
			and math.abs(outgoing.Y) <= config.MaxRiseStuds
			and incoming.Unit:Dot(outgoing.Unit) >= config.StraightDot
		then
			local side = Vector3.new(-incoming.Z, 0, incoming.X).Unit
			local envelope = math.sin(math.pi * travelled / total)
			local offset = math.sin(travelled * math.pi * 2 / wave) * amplitude * sign * envelope
			local candidate = canStep(point, point + side * offset)
			if candidate and math.abs(candidate.Y - point.Y) <= config.MaxRiseStuds then
				local entered = canStep(out[index - 1], candidate)
				local returned = canStep(candidate, after)
				if entered and returned then
					out[index] = candidate
				end
			end
		end
	end
	return out
end

return table.freeze(CrowdPath)
