--!strict
-- Ticket dossier: every cosmetic a player can own, in one lookup: the Black Market's Attire (ShopDefs) and the Dossier-only kinds
-- (DossierDefs.cosmetics). `Profile.OwnedCosmetics` holds ids from here; an id that is not here is dropped when a profile loads.
--
--   CosmeticDefs.byId[id] -> CosmeticEntry
--   CosmeticDefs.get(id) -> CosmeticEntry?

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local DossierDefs = require(script.Parent.DossierDefs)
local ShopDefs = require(script.Parent.ShopDefs)

local byId: { [string]: Types.CosmeticEntry } = {}
for _, offer in ShopDefs.pool do
	byId[offer.Id] = { Id = offer.Id, Name = offer.Name, Kind = offer.Kind, AgentId = offer.AgentId }
end
for _, entry in DossierDefs.cosmetics do
	assert(not byId[entry.Id], `Cosmetic id {entry.Id} is used twice`)
	byId[entry.Id] = entry
end

-- Every cosmetic a Dossier hands out must exist.
for _, dossierId in DossierDefs.order do
	local dossier = DossierDefs.byId[dossierId]
	for _, tier in dossier.Tiers do
		for _, list in { tier.Free, tier.Premium } do
			for _, reward in list do
				if reward.Kind == "Cosmetic" then
					assert(
						reward.CosmeticId and byId[reward.CosmeticId],
						`Dossier {dossierId} pays an unknown cosmetic {reward.CosmeticId}`
					)
				end
			end
		end
	end
end

local CosmeticDefs = { byId = byId }

function CosmeticDefs.get(id: string): Types.CosmeticEntry?
	return byId[id]
end

return CosmeticDefs
