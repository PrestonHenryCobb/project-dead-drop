--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local AssetDefs = require(Shared.Defs.AssetDefs)
local Types = require(Shared.Types)
local AssetStyle = {}
local names = { FieldAgent = "Field Agent", Infiltrator = "Infiltrator", BlackOps = "Black Ops", Ghost = "Ghost" }
function AssetStyle.name(rarity: Types.AssetRarity): string
	return names[rarity]
end
function AssetStyle.color(rarity: string): Color3?
	for tier, candidate in GameConfig.Assets.RarityByTier do
		if candidate == rarity then
			return GameConfig.Zones.TierColors[tier]
		end
	end
	return nil
end
function AssetStyle.value(id: string, rarity: Types.AssetRarity): string
	return string.format("%+.0f%%", AssetDefs.valueOf(id, rarity) * 100)
end
return AssetStyle
