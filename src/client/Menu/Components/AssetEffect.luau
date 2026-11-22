--!strict
-- Menu copy uses the same rarity values and quiet-vent threshold as gameplay. No invented signed-stat shorthand.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Defs.AssetDefs)
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)
local AssetEffect = {}

function AssetEffect.short(id: string, rarity: Types.AssetRarity): string
	local percent = string.format("%.0f%%", math.abs(Assets.valueOf(id, rarity)) * 100)
	if id == "LightFeet" then
		return `{percent} less movement suspicion`
	elseif id == "QuickHands" then
		return `{percent} faster hacking`
	elseif id == "SteadyNerves" then
		return `{percent} faster suspicion recovery`
	elseif id == "DeepPockets" then
		return `{percent} lower Intel prices`
	elseif id == "FieldMedic" then
		return `{percent} more food healing / faster treatment`
	elseif id == "DuctRat" then
		return `{percent} faster vent crawling`
	end
	return ""
end

function AssetEffect.detail(id: string, rarity: Types.AssetRarity): string
	local value = AssetEffect.short(id, rarity)
	if id == "DuctRat" then
		local rank = table.find(Assets.rarities, rarity) or 0
		local quietFrom = table.find(Assets.rarities, GameConfig.Assets.QuietVentFrom) or math.huge
		return value .. (if rank >= quietFrom then ". Vents preserve Cover." else ". Vents still break Cover.")
	elseif id == "LightFeet" then
		return value .. " from sprinting and jumping."
	elseif id == "SteadyNerves" then
		return value .. " once nobody is watching."
	elseif id == "FieldMedic" then
		local percent = string.format("%.0f%%", math.abs(Assets.valueOf(id, rarity)) * 100)
		return `Food heals {percent} more. Health Stations treat you {percent} faster.`
	end
	return value .. "."
end

return AssetEffect
