--!strict
-- Reads public generated Zone_<level>_T<tier>_<room> volumes; no character metadata or arbitrary height threshold.
local FloorBands = {}
type Band = { Name: string, Min: number, Max: number, Count: number }

function FloorBands.new()
	local volumes: { [Instance]: string } = {}
	local records: { [string]: Band } = {}
	local sorted: { Band } = {}
	local function rebuild()
		table.clear(sorted)
		for _, band in records do
			table.insert(sorted, band)
		end
		table.sort(sorted, function(a, b)
			if a.Min ~= b.Min then
				return a.Min < b.Min
			end
			return a.Name < b.Name
		end)
	end
	local function remove(instance: Instance)
		local key = volumes[instance]
		if not key then
			return
		end
		volumes[instance] = nil
		local band = records[key]
		band.Count -= 1
		if band.Count == 0 then
			records[key] = nil
			rebuild()
		end
	end
	local function at(height: number): Band?
		local found: Band? = nil
		for _, band in sorted do
			if height >= band.Min and height < band.Max then
				if found and found.Name ~= band.Name then
					return nil
				end
				found = band
			end
		end
		return found
	end
	return {
		add = function(instance: Instance)
			if not instance:IsA("BasePart") then
				return
			end
			local name = string.match(instance.Name, "^Zone_(.-)_T%d+_")
			if not name or name == "" or instance.Size.Y <= 0 then
				return
			end
			remove(instance)
			local low = instance.Position.Y - instance.Size.Y / 2
			local high = instance.Position.Y + instance.Size.Y / 2
			local key = `{name}:{low}:{high}`
			volumes[instance] = key
			local existing = records[key]
			if existing then
				existing.Count += 1
			else
				records[key] = { Name = name, Min = low, Max = high, Count = 1 }
				rebuild()
			end
		end,
		remove = remove,
		nameAt = function(height: number): string?
			local band = at(height)
			return if band then band.Name else nil
		end,
		hint = function(from: number, target: number): string
			local here, there = at(from), at(target)
			if not here or not there or here.Name == there.Name then
				return ""
			end
			return `{if there.Min > here.Min then "↑" else "↓"} {there.Name}`
		end,
		clear = function()
			table.clear(volumes)
			table.clear(records)
			table.clear(sorted)
		end,
	}
end

return FloorBands
