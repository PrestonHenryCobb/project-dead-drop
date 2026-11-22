--!strict
-- Ticket dossier (owner answers 2026-11-20, docs/DOSSIER_DRAFT.md): the Dossiers. One ships, The Gala Job, with 30 tiers; more are one
-- more entry here. Every reward is cosmetic or soft currency, and nothing changes how a match plays. Names are ideas to be tuned with the
-- art; items with no art yet are only marked as owned. Numbers (tiers, XP, prices) are GameConfig.Dossier.
--
--   DossierDefs.order -> { DossierId }
--   DossierDefs.byId[id] / DossierDefs.get(id) -> DossierDef
--   DossierDefs.cosmetics -> { CosmeticEntry }       the Dossier-only cosmetics (Attire is in ShopDefs)

local Shared = script.Parent.Parent
local GameConfig = require(Shared.GameConfig)
local Types = require(Shared.Types)

type DossierReward = Types.DossierReward
type CosmeticEntry = Types.CosmeticEntry

local config = GameConfig.Dossier

local cosmetics: { CosmeticEntry } = {
	{ Id = "TitlePlusOne", Name = "The Plus One", Kind = "Title" },
	{ Id = "TitleGalaRegular", Name = "Gala Regular", Kind = "Title" },
	{ Id = "TitleSilverTongue", Name = "Silver Tongue", Kind = "Title" },
	{ Id = "TitleQuietGuest", Name = "Quiet Guest", Kind = "Title" },
	{ Id = "TitleHeadTable", Name = "Head Table", Kind = "Title" },
	{ Id = "TitleBlackTie", Name = "Black Tie", Kind = "Title" },
	{ Id = "CardIvory", Name = "Ivory Card", Kind = "Card" },
	{ Id = "CardBrass", Name = "Brass Card", Kind = "Card" },
	{ Id = "CardVelvet", Name = "Velvet Card", Kind = "Card" },
	{ Id = "CardLedger", Name = "Ledger Card", Kind = "Card" },
	{ Id = "SprayFlute", Name = "Champagne Flute", Kind = "Spray" },
	{ Id = "SprayMask", Name = "Masked Face", Kind = "Spray" },
	{ Id = "SprayKey", Name = "Golden Key", Kind = "Spray" },
	{ Id = "SprayWine", Name = "Spilled Wine", Kind = "Spray" },
	{ Id = "SprayChandelier", Name = "Chandelier", Kind = "Spray" },
	{ Id = "SprayCufflinks", Name = "Cufflinks", Kind = "Spray" },
	{ Id = "FinishBrassInlay", Name = "Brass Inlay", Kind = "Finish" },
	{ Id = "FinishIvoryGrip", Name = "Ivory Grip", Kind = "Finish" },
	{ Id = "FinishGildedSlide", Name = "Gilded Slide", Kind = "Finish" },
	{ Id = "FinishVelvetWrap", Name = "Velvet Wrap", Kind = "Finish" },
	{ Id = "TakedownWaltzDip", Name = "Waltz Dip", Kind = "Takedown" },
	{ Id = "TakedownCoatCheck", Name = "Coat Check", Kind = "Takedown" },
	{ Id = "ExtractionChauffeur", Name = "Chauffeur", Kind = "Extraction" },
	{ Id = "WatchBrass", Name = "Brass Wristwatch", Kind = "Watch" },
	{ Id = "WatchBlackout", Name = "Blackout Watch", Kind = "Watch" },
	{ Id = "WatchCrimson", Name = "Crimson Watch", Kind = "Watch" },
}

local function credits(amount: number): DossierReward
	return { Kind = "Credits", Amount = amount }
end

local function stocks(amount: number): DossierReward
	return { Kind = "Stocks", Amount = amount }
end

local function item(id: string): DossierReward
	return { Kind = "Cosmetic", CosmeticId = id }
end

-- The Gala Job: what each tier pays, free track then premium track. A tier not listed pays nothing on that track.
local galaFree: { [number]: { DossierReward } } = {
	[1] = { item("TitlePlusOne") },
	[3] = { item("CardIvory") },
	[4] = { item("SprayFlute") },
	[5] = { credits(150) },
	[6] = { item("TitleGalaRegular") },
	[8] = { item("WatchBrass") },
	[9] = { item("CardBrass") },
	[10] = { credits(150) },
	[12] = { item("ParapetJanitorElite") },
	[15] = { credits(150) },
	[18] = { item("TitleSilverTongue") },
	[20] = { credits(150), item("SprayMask") },
	[21] = { item("CardVelvet") },
	[24] = { item("SutureOfficeDrone") },
	[25] = { credits(150), item("SprayKey") },
	[27] = { item("TitleQuietGuest") },
	[30] = { credits(150), item("TakedownWaltzDip") },
}
local galaPremium: { [number]: { DossierReward } } = {
	[2] = { item("TitleHeadTable") },
	[3] = { item("WatchBlackout") },
	[4] = { item("FinishBrassInlay") },
	[6] = { item("SprayWine") },
	[8] = { item("GuiseGalaTuxedo") },
	[10] = { stocks(100) },
	[12] = { item("CardLedger") },
	[14] = { item("FinishIvoryGrip") },
	[15] = { item("TakedownCoatCheck") },
	[16] = { item("ReticleVipEscort") },
	[18] = { item("SprayChandelier") },
	[20] = { stocks(100), item("FinishGildedSlide") },
	[22] = { item("GuiseMonochromeNoir") },
	[24] = { item("SprayCufflinks") },
	[25] = { item("ExtractionChauffeur") },
	[26] = { item("WatchCrimson") },
	[27] = { item("FinishVelvetWrap") },
	[28] = { item("TitleBlackTie") },
	[30] = { stocks(200), item("GuiseGoldenAsset") },
}

local function build(
	id: string,
	name: string,
	free: { [number]: { DossierReward } },
	premium: { [number]: { DossierReward } }
): Types.DossierDef
	for tier in free do
		assert(
			tier >= 1 and tier <= config.Tiers,
			`Dossier {id}: free reward on tier {tier}, outside 1 to {config.Tiers}`
		)
	end
	for tier in premium do
		assert(
			tier >= 1 and tier <= config.Tiers,
			`Dossier {id}: premium reward on tier {tier}, outside 1 to {config.Tiers}`
		)
	end
	local tiers: { Types.DossierTier } = {}
	for tier = 1, config.Tiers do
		tiers[tier] = { Free = free[tier] or {}, Premium = premium[tier] or {} }
	end
	return { Id = id, Name = name, Tiers = tiers }
end

local defs: { Types.DossierDef } = {
	build("GalaJob", "The Gala Job", galaFree, galaPremium),
}

local byId: { [string]: Types.DossierDef } = {}
local order: { string } = {}
for _, def in defs do
	assert(not byId[def.Id], `Duplicate Dossier {def.Id}`)
	byId[def.Id] = def
	table.insert(order, def.Id)
end

local DossierDefs = {
	order = order,
	byId = byId,
	cosmetics = cosmetics,
}

function DossierDefs.get(id: string): Types.DossierDef?
	return byId[id]
end

return DossierDefs
