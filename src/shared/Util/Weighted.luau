--!strict
-- Picks one item at random, more often the heavier its weight.
--
--   Weighted.pick(items, weightOf, rng) -> item?   nil if the list is empty or every weight is zero

local Weighted = {}

function Weighted.pick<T>(items: { T }, weightOf: (T) -> number, rng: Random): T?
	local total = 0
	for _, item in items do
		total += math.max(0, weightOf(item))
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	for _, item in items do
		roll -= math.max(0, weightOf(item))
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

return Weighted
