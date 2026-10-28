--!strict
-- Local session draft shared by Assets and agent select. Never represents confirmed/found Assets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local AssetDefs = require(Shared.Defs.AssetDefs)
local AssetDraft = {}
local picks: { string }? = nil
local dirty = false

function AssetDraft.get(initial: { string }?): { string }
	if not picks or (initial and not dirty) then
		local result = {}
		local source = initial or GameConfig.Assets.DefaultPicks
		for index = 1, #AssetDefs.rarities do
			local id = source[index]
			if not id or not AssetDefs.get(id) or table.find(result, id) then
				id = nil
				for _, candidate in AssetDefs.order do
					if not table.find(result, candidate) then
						id = candidate
						break
					end
				end
			end
			assert(id, "Not enough distinct Asset definitions")
			table.insert(result, id)
		end
		picks = result
	end
	return table.clone(picks :: { string })
end

function AssetDraft.choose(slot: number, id: string): boolean
	local current = AssetDraft.get()
	if slot % 1 ~= 0 or slot < 1 or slot > #AssetDefs.rarities or not AssetDefs.get(id) then
		return false
	end
	local used = table.find(current, id)
	if used and used ~= slot then
		return false
	end
	current[slot] = id
	picks = current
	dirty = true
	return true
end

return AssetDraft
