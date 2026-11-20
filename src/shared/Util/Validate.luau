--!strict
-- Checks for values a client sends over a remote (ticket 23-audit). A handler still checks its own rules (range, state);
-- this only answers "is it the kind of value it claims to be", which `typeof` alone does not: a Vector3 can hold NaN or
-- infinity, and `.Unit` of an infinite vector is NaN, which then poisons positions on the server.
--
--   Validate.vector3(value) -> Vector3?   the value if it is a Vector3 with every component finite and within Limit
--   Validate.unit(value, tolerance) -> Vector3?   the same, and its length within tolerance of 1

local Validate = {}

-- Far beyond any map coordinate; anything larger is an exploit or a bug.
Validate.Limit = 1e6

function Validate.vector3(value: unknown): Vector3?
	if typeof(value) ~= "Vector3" then
		return nil
	end
	local v = value :: Vector3
	local limit = Validate.Limit
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then
		return nil
	end
	if math.abs(v.X) > limit or math.abs(v.Y) > limit or math.abs(v.Z) > limit then
		return nil
	end
	return v
end

function Validate.unit(value: unknown, tolerance: number): Vector3?
	local v = Validate.vector3(value)
	if v and math.abs(v.Magnitude - 1) <= tolerance then
		return v
	end
	return nil
end

return Validate
