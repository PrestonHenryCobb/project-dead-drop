--!strict
-- Ticket 8.22: one geometric acquisition contract for the advisory hint and authoritative server.
local config = require(script.Parent.Parent.GameConfig).Combat
local melee = config.Melee
local MeleeRules = {}

function MeleeRules.damage(heldSeconds: number): number
	-- SPEC-QUESTION: intermediate charge damage was unspecified; retain 35 until the approved full-charge threshold.
	return if heldSeconds >= melee.FullChargeSeconds then melee.FullChargeDamage else melee.Damage
end

function MeleeRules.inReach(from: Vector3, look: Vector3, target: Vector3, reach: number): boolean
	local x, z = target.X - from.X, target.Z - from.Z
	local distance = math.sqrt(x * x + z * z)
	local lookLength = math.sqrt(look.X * look.X + look.Z * look.Z)
	return distance <= reach
		and math.abs(target.Y - from.Y) <= melee.HeightStuds
		and lookLength >= melee.DirectionEpsilonStuds
		and (
			distance < melee.DirectionEpsilonStuds
			or (x * look.X + z * look.Z) / (distance * lookLength) >= math.cos(math.rad(melee.SwingConeDegrees / 2))
		)
end

function MeleeRules.canTakedown(from: Vector3, look: Vector3, target: Vector3, facing: Vector3): boolean
	if not MeleeRules.inReach(from, look, target, config.Takedown.RangeStuds) then
		return false
	end
	local x, z = from.X - target.X, from.Z - target.Z
	local length = math.sqrt(x * x + z * z)
	local facingLength = math.sqrt(facing.X * facing.X + facing.Z * facing.Z)
	return length >= melee.DirectionEpsilonStuds
		and facingLength >= melee.DirectionEpsilonStuds
		and -(x * facing.X + z * facing.Z) / (length * facingLength)
			>= math.cos(math.rad(config.Takedown.ConeDegrees / 2))
end

return MeleeRules
