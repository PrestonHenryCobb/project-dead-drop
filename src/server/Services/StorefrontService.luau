--!strict
-- Ticket shop-skeleton (owner answers 2026-11-20): the Black Market and the Mint. Agents are bought in MetaProgressionService
-- (RequestBuyAgent), because that is where a profile's owned agents live. Every request is checked here; the client only shows.
--
--   GetBlackMarketOffers() -> Types.BlackMarketState        today's daily items and this week's featured bundle
--   RequestBlackMarketPurchase(offerId) -> (ok, reason?)    a daily item or the featured bundle, for the price in GameConfig.Shop
--   RequestMintStrikeStocks(packageId) -> (ok, reason?)     Studio-only test grant; real Stocks need a Robux product (see below)
--
-- The Mint is not wired to Robux: a package's ProductId is 0 until the owner creates the Developer Product, so outside Studio the
-- request answers "NotAvailable". ProcessReceipt is deliberately not built before real products exist (a receipt handler that
-- loses a purchase costs a player money). Cosmetics have no art yet, so owning one only marks it in the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CosmeticDefs = require(Shared:WaitForChild("Defs"):WaitForChild("CosmeticDefs"))
local ShopDefs = require(Shared:WaitForChild("Defs"):WaitForChild("ShopDefs"))
local Types = require(Shared:WaitForChild("Types"))
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local StorefrontService = {}

local config = GameConfig.Shop

local function today(): number
	return ShopDefs.dayOf(os.time())
end

local function secondsUntil(day: number): number
	return math.max(0, day * config.SecondsPerDay - os.time())
end

local function state(): Types.BlackMarketState
	local day = today()
	local weekStart = math.floor(day / config.FeaturedDays) * config.FeaturedDays
	local now = workspace:GetServerTimeNow()
	return {
		Daily = ShopDefs.dailyOffers(day),
		Featured = ShopDefs.featuredBundle(day),
		ResetsAt = now + secondsUntil(day + 1),
		FeaturedResetsAt = now + secondsUntil(weekStart + config.FeaturedDays),
	}
end

local function charge(profile: Types.MetaProfile, currency: string, price: number): (boolean, string?)
	if currency == "Credits" then
		if profile.Credits < price then
			return false, "NotEnoughCredits"
		end
		profile.Credits -= price
	elseif currency == "Stocks" then
		if profile.Stocks < price then
			return false, "NotEnoughStocks"
		end
		profile.Stocks -= price
	else
		return false, "UnknownCurrency"
	end
	return true, nil
end

local function onPurchase(player: Player, offerId: unknown): (boolean, string?)
	if type(offerId) ~= "string" then
		return false, "UnknownOffer"
	end
	local current = state()
	local single: Types.CosmeticOffer? = nil
	for _, offer in current.Daily do
		if offer.Id == offerId then
			single = offer
		end
	end
	if single then
		local item = single :: Types.CosmeticOffer
		return MetaProgressionService.transact(player, function(profile)
			if profile.OwnedCosmetics[item.Id] then
				return false, "AlreadyOwned"
			end
			if not profile.OwnedAgents[item.AgentId] then
				return false, "AgentNotOwned" -- an agent's Attire is only sold to someone who has the agent
			end
			local ok, reason = charge(profile, item.Currency, item.Price)
			if not ok then
				return false, reason
			end
			profile.OwnedCosmetics[item.Id] = true
			return true, nil
		end)
	end
	local bundle = current.Featured
	if offerId ~= bundle.Id then
		return false, "NotOnSale"
	end
	return MetaProgressionService.transact(player, function(profile)
		local missing = 0
		for _, item in bundle.Items do
			if not profile.OwnedAgents[item.AgentId] then
				return false, "AgentNotOwned" -- the same rule as a single item: Attire is only sold to the agent's owner
			end
			if not profile.OwnedCosmetics[item.Id] then
				missing += 1
			end
		end
		if missing == 0 then
			return false, "AlreadyOwned"
		end
		local ok, reason = charge(profile, "Stocks", bundle.Price)
		if not ok then
			return false, reason
		end
		for _, item in bundle.Items do
			profile.OwnedCosmetics[item.Id] = true
		end
		return true, nil
	end)
end

local function onMint(player: Player, packageId: unknown): (boolean, string?)
	local package: Types.MintPackage? = nil
	for _, candidate in config.Mint.Packages do
		if candidate.Id == packageId then
			package = candidate
		end
	end
	if not package then
		return false, "UnknownPackage"
	end
	local chosen = package :: Types.MintPackage
	if not (RunService:IsStudio() and config.Mint.StudioGrantEnabled) then
		return false, "NotAvailable" -- real purchases need the Robux products (ProductId), which do not exist yet
	end
	return MetaProgressionService.transact(player, function(profile)
		profile.Stocks = math.min(profile.Stocks + chosen.Stocks, GameConfig.Data.MaxCredits)
		return true, nil
	end)
end

-- Ticket equip-cosmetics: wear an owned Title, Calling card or Spray (kind "Title", "Card" or "Spray"), or take it off with nil. Nothing else is equippable
-- yet (no art). The choice is saved with the profile; showing it on the kill and results screens is the client's and a later server step.
local function onEquip(player: Player, kind: unknown, cosmeticId: unknown): (boolean, string?)
	if kind ~= "Title" and kind ~= "Card" and kind ~= "Spray" and kind ~= "Watch" then
		return false, "UnknownKind"
	end
	if cosmeticId ~= nil and type(cosmeticId) ~= "string" then
		return false, "UnknownCosmetic"
	end
	local entry = if type(cosmeticId) == "string" then CosmeticDefs.get(cosmeticId) else nil
	if cosmeticId ~= nil and (not entry or entry.Kind ~= kind) then
		return false, "UnknownCosmetic"
	end
	return MetaProgressionService.transact(player, function(profile)
		if cosmeticId ~= nil and not profile.OwnedCosmetics[cosmeticId :: string] then
			return false, "NotOwned"
		end
		if kind == "Title" then
			profile.EquippedTitle = cosmeticId :: string?
		elseif kind == "Card" then
			profile.EquippedCard = cosmeticId :: string?
		elseif kind == "Watch" then
			profile.EquippedWatch = cosmeticId :: string?
		else
			profile.EquippedSpray = cosmeticId :: string?
		end
		return true, nil
	end)
end

function StorefrontService.Init() end

function StorefrontService.Start()
	RemoteService.onInvoke("GetBlackMarketOffers", function(_player: Player)
		return state()
	end)
	RemoteService.onInvoke("RequestBlackMarketPurchase", onPurchase)
	RemoteService.onInvoke("RequestMintStrikeStocks", onMint)
	RemoteService.onInvoke("RequestEquipCosmetic", onEquip)
end

return StorefrontService
