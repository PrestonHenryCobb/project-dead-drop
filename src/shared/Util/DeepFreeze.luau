--!strict
-- Recursively freezes a table so config and enums can't be changed at runtime.
-- Only plain tables are frozen; Instances, Color3s and other userdata are left alone.

local function deepFreeze<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local tbl = value :: any
	if table.isfrozen(tbl) then
		return value
	end
	table.freeze(tbl)
	for _, child in tbl do
		deepFreeze(child)
	end
	return value
end

return deepFreeze
