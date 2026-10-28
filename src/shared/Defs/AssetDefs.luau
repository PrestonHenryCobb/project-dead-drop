--!strict
-- The six Assets (docs/ASSETS_DESIGN.md, BUILD_ORDER Step 7B): per-match perks an agent finds in safes. Each has one value per
-- rarity, a fraction: Light Feet's -0.15 is 15 percent less, Quick Hands' 0.1 is 10 percent faster. A player brings four
-- different Assets, one for each rarity slot, and a safe of a rarity gives them the Asset in that slot at that rarity's value.
--
--   AssetDefs.get(id) -> AssetDef?
--   AssetDefs.order -> { string } in menu order
--   AssetDefs.rarities -> { AssetRarity } lowest first (the slot order of a loadout)
--   AssetDefs.valueOf(id, rarity) -> number

local Shared = script.Parent.Parent
local DeepFreeze = require(Shared.Util.DeepFreeze)
local Types = require(Shared.Types)

type AssetDef = Types.AssetDef
type AssetRarity = Types.AssetRarity

local rarities: { AssetRarity } = { "FieldAgent", "Infiltrator", "BlackOps", "Ghost" }

local function values(a: number, b: number, c: number, d: number): { [AssetRarity]: number }
	return { FieldAgent = a, Infiltrator = b, BlackOps = c, Ghost = d }
end

local defs: { AssetDef } = {
	{
		Id = "LightFeet",
		Name = "Light Feet",
		Description = "Sprinting and jumping raise suspicion slower.",
		Values = values(-0.15, -0.25, -0.35, -0.5),
	},
	{
		Id = "QuickHands",
		Name = "Quick Hands",
		Description = "Intel stations, doors and other hacks go faster.",
		Values = values(0.1, 0.2, 0.3, 0.4),
	},
	{
		Id = "SteadyNerves",
		Name = "Steady Nerves",
		Description = "Suspicion drains faster once nobody is watching.",
		Values = values(0.25, 0.5, 1, 1.5),
	},
	{
		Id = "DeepPockets",
		Name = "Deep Pockets",
		Description = "Intel purchases cost less.",
		Values = values(-0.1, -0.15, -0.25, -0.35),
	},
	{
		Id = "FieldMedic",
		Name = "Field Medic",
		Description = "Food heals more; Health Stations heal faster.",
		Values = values(0.15, 0.3, 0.5, 0.75),
	},
	{
		Id = "DuctRat",
		Name = "Duct Rat",
		Description = "Crawl through vents faster; from Black Ops, vents do not break your Cover.",
		Values = values(0.2, 0.35, 0.5, 0.75),
	},
}

local byId: { [string]: AssetDef } = {}
local order: { string } = {}
for _, def in defs do
	assert(not byId[def.Id], `Duplicate Asset {def.Id}`)
	byId[def.Id] = def
	table.insert(order, def.Id)
end

local AssetDefs = {
	byId = byId,
	order = order,
	rarities = rarities,
}

function AssetDefs.get(id: string): AssetDef?
	return byId[id]
end

function AssetDefs.valueOf(id: string, rarity: AssetRarity): number
	local def = byId[id]
	return if def then def.Values[rarity] else 0
end

return DeepFreeze(AssetDefs)
