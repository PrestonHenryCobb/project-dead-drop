--!strict
-- Ticket shop-skeleton: the Black Market catalogue (META_DRAFT, "Black Market catalogue"). Every item is Attire for one agent and uses a name
-- the owner already approved in that draft. There is no art yet, so owning an item only marks it in the profile. Prices come from
-- GameConfig.Shop.TierPrices by tier; nothing here is a number.
--
--   ShopDefs.pool -> { CosmeticOffer }               every item, in a fixed order
--   ShopDefs.byId[id] -> CosmeticOffer
--   ShopDefs.bundles -> { { Id, Name, ItemIds } }    weekly featured bundles, all Stocks items
--   ShopDefs.dailyOffers(day) -> { CosmeticOffer }   the items on sale on that UTC day number
--   ShopDefs.featuredBundle(day) -> CosmeticBundle   the bundle on sale that day's week
--   ShopDefs.dayOf(unixSeconds) -> number
--
-- SPEC-QUESTION: which agent wears which look, and the tier of each, are first guesses to be tuned with the art.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)

type CosmeticOffer = Types.CosmeticOffer
type CosmeticBundle = Types.CosmeticBundle

local config = GameConfig.Shop

local function attire(id: string, name: string, agentId: string, tier: string): CosmeticOffer
	local price = (config.TierPrices :: any)[tier]
	assert(price, `ShopDefs: unknown tier {tier}`)
	return {
		Id = id,
		Name = name,
		Kind = "Attire",
		AgentId = agentId,
		Tier = tier,
		Currency = price.Currency,
		Price = price.Price,
	}
end

local pool: { CosmeticOffer } = {
	attire("GuiseGalaTuxedo", "Gala Tuxedo", "Guise", "Premium"),
	attire("GuiseMonochromeNoir", "Monochrome Noir", "Guise", "Premium"),
	attire("GuiseGoldenAsset", "Golden Asset", "Guise", "Legendary"),
	attire("ParapetJanitorElite", "Janitor Elite", "Parapet", "Everyday"),
	attire("LatticeRogueNetrunner", "Rogue Netrunner", "Lattice", "Premium"),
	attire("LatticeCyberGuerrilla", "Cyber-Guerrilla", "Lattice", "Premium"),
	attire("ReticleInfiltrationSuit", "Infiltration Suit", "Reticle", "Premium"),
	attire("ReticleVipEscort", "VIP Escort", "Reticle", "Premium"),
	attire("SutureTourist", "The Tourist", "Suture", "Everyday"),
	attire("SutureOfficeDrone", "Office Drone", "Suture", "Everyday"),
	attire("FeintCardboardInfiltrator", "Cardboard Infiltrator", "Feint", "Legendary"),
	attire("FeintInvisibleMan", "The Invisible Man", "Feint", "Legendary"),
}

local byId: { [string]: CosmeticOffer } = {}
for _, item in pool do
	assert(not byId[item.Id], `ShopDefs: duplicate item {item.Id}`)
	byId[item.Id] = item
end

local bundles = {
	{
		Id = "BundleHighSociety",
		Name = "High Society",
		ItemIds = { "GuiseGalaTuxedo", "GuiseMonochromeNoir", "ReticleVipEscort" },
	},
	{
		Id = "BundleTactical",
		Name = "Tactical",
		ItemIds = { "ReticleInfiltrationSuit", "LatticeRogueNetrunner", "LatticeCyberGuerrilla" },
	},
	{
		Id = "BundleOverTheTop",
		Name = "Over the Top",
		ItemIds = { "GuiseGoldenAsset", "FeintCardboardInfiltrator", "FeintInvisibleMan" },
	},
}
for _, bundle in bundles do
	for _, itemId in bundle.ItemIds do
		local item = byId[itemId]
		assert(item and item.Currency == "Stocks", `ShopDefs: bundle {bundle.Id} item {itemId} must be a Stocks item`)
	end
end

local ShopDefs = {
	pool = pool,
	byId = byId,
	bundles = bundles,
}

function ShopDefs.dayOf(unixSeconds: number): number
	return math.floor(unixSeconds / config.SecondsPerDay)
end

-- The same items for every server and player on a given UTC day: a shuffle seeded with the day number.
function ShopDefs.dailyOffers(day: number): { CosmeticOffer }
	local rng = Random.new(day)
	local order = table.clone(pool)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local offers: { CosmeticOffer } = {}
	for i = 1, math.min(config.DailyOffers, #order) do
		offers[i] = order[i]
	end
	return offers
end

function ShopDefs.featuredBundle(day: number): CosmeticBundle
	local week = math.floor(day / config.FeaturedDays)
	local bundle = bundles[(week % #bundles) + 1]
	local items: { CosmeticOffer } = {}
	local total = 0
	for index, itemId in bundle.ItemIds do
		items[index] = byId[itemId]
		total += byId[itemId].Price
	end
	return {
		Id = bundle.Id,
		Name = bundle.Name,
		ItemIds = bundle.ItemIds,
		Items = items,
		Price = math.floor(total * config.BundleStocksMult),
	}
end

return ShopDefs
