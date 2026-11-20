--!strict
-- Ticket dossier (owner answers 2026-11-20, docs/DOSSIER_DRAFT.md): choosing, claiming from and unlocking Dossiers. Dossier XP is added at match end
-- by MetaProgressionService.settleAccount (all account XP goes into the active Dossier). Every request is checked here; the client only shows.
--
--   RequestSelectActiveDossier(dossierId) -> (ok, reason?)        any known Dossier, free to change
--   RequestClaimDossierTier(dossierId, tier) -> (ok, reason?)     takes the tier's free rewards, and its premium rewards once premium is unlocked
--   RequestBuyDossierPremium(dossierId) -> (ok, reason?)          GameConfig.Dossier.PremiumStocks Stocks, permanent
--
-- A tier is reached when the Dossier's XP is at least tier times XPPerTier. Claimed tiers are kept in DossierProgress.Claimed: n for the free track, n
-- plus PremiumClaimOffset for the premium track, so a premium unlock bought late can still claim the tiers already passed. A reward the player already
-- owns pays DuplicateCredits instead. Cosmetics have no art or equip step yet, so owning one only marks it in the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DossierDefs = require(Shared:WaitForChild("Defs"):WaitForChild("DossierDefs"))
local Types = require(Shared:WaitForChild("Types"))
local MetaProgressionService = require(script.Parent.MetaProgressionService)
local RemoteService = require(script.Parent.RemoteService)

local DossierService = {}

local config = GameConfig.Dossier

local function progressOf(profile: Types.MetaProfile, dossierId: string): Types.DossierProgress
	local progress = profile.Dossiers[dossierId]
	if not progress then
		progress = { XP = 0, Premium = false, Claimed = {} }
		profile.Dossiers[dossierId] = progress
	end
	return progress
end

local function hasClaimed(progress: Types.DossierProgress, key: number): boolean
	return table.find(progress.Claimed, key) ~= nil
end

local function grant(profile: Types.MetaProfile, reward: Types.DossierReward)
	if reward.Kind == "Credits" then
		profile.Credits = math.min(profile.Credits + (reward.Amount or 0), GameConfig.Data.MaxCredits)
	elseif reward.Kind == "Stocks" then
		profile.Stocks = math.min(profile.Stocks + (reward.Amount or 0), GameConfig.Data.MaxCredits)
	elseif reward.Kind == "Cosmetic" and reward.CosmeticId then
		if profile.OwnedCosmetics[reward.CosmeticId] then
			profile.Credits = math.min(profile.Credits + config.DuplicateCredits, GameConfig.Data.MaxCredits)
		else
			profile.OwnedCosmetics[reward.CosmeticId] = true
		end
	end
end

local function onSelect(player: Player, dossierId: unknown): (boolean, string?)
	if type(dossierId) ~= "string" or not DossierDefs.get(dossierId) then
		return false, "UnknownDossier"
	end
	return MetaProgressionService.transact(player, function(profile)
		profile.ActiveDossierId = dossierId
		return true, nil
	end)
end

local function onClaim(player: Player, dossierId: unknown, tier: unknown): (boolean, string?)
	local def = if type(dossierId) == "string" then DossierDefs.get(dossierId) else nil
	if not def then
		return false, "UnknownDossier"
	end
	if type(tier) ~= "number" or tier ~= tier or tier ~= math.floor(tier) or tier < 1 or tier > config.Tiers then
		return false, "UnknownTier"
	end
	local entry = def.Tiers[tier]
	return MetaProgressionService.transact(player, function(profile)
		local progress = progressOf(profile, def.Id)
		if progress.XP < tier * config.XPPerTier then
			return false, "NotReached"
		end
		local premiumKey = tier + config.PremiumClaimOffset
		local takeFree = not hasClaimed(progress, tier) and #entry.Free > 0
		local takePremium = progress.Premium and not hasClaimed(progress, premiumKey) and #entry.Premium > 0
		if not takeFree and not takePremium then
			-- Say why there is nothing: already taken, or only premium rewards sit here and premium is locked.
			if #entry.Premium > 0 and not progress.Premium and #entry.Free == 0 then
				return false, "PremiumRequired"
			end
			return false, "NothingToClaim"
		end
		if takeFree then
			table.insert(progress.Claimed, tier)
			for _, reward in entry.Free do
				grant(profile, reward)
			end
		end
		if takePremium then
			table.insert(progress.Claimed, premiumKey)
			for _, reward in entry.Premium do
				grant(profile, reward)
			end
		end
		return true, nil
	end)
end

local function onBuyPremium(player: Player, dossierId: unknown): (boolean, string?)
	local def = if type(dossierId) == "string" then DossierDefs.get(dossierId) else nil
	if not def then
		return false, "UnknownDossier"
	end
	return MetaProgressionService.transact(player, function(profile)
		local progress = progressOf(profile, def.Id)
		if progress.Premium then
			return false, "AlreadyOwned"
		end
		if profile.Stocks < config.PremiumStocks then
			return false, "NotEnoughStocks"
		end
		profile.Stocks -= config.PremiumStocks
		progress.Premium = true
		return true, nil
	end)
end

function DossierService.Init() end

function DossierService.Start()
	RemoteService.onInvoke("RequestSelectActiveDossier", onSelect)
	RemoteService.onInvoke("RequestClaimDossierTier", onClaim)
	RemoteService.onInvoke("RequestBuyDossierPremium", onBuyPremium)
end

return DossierService
