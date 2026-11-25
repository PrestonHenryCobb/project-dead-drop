--!strict
-- User-facing explanations of existing server refusals. No optimistic profile or purchase changes.
local RequestFeedback = {}
local messages: { [string]: string } = {
	NoProfile = "Profile loading. Try again soon.",
	BadRequest = "Not submitted. Choose again.",
	UnknownAgent = "That agent is currently unavailable.",
	AgentLocked = "Choose an agent you own.",
	AlreadyOwned = "You already own this.",
	NoFreePick = "Free pick already used.",
	HardwareUnavailable = "Hardware unavailable.",
	MasteryTooLow = "Needs more Mastery.",
	GadgetUnavailable = "No repeat gadgets.",
	AssetUnavailable = "Fill all 4 slots, no repeats.",
	NoCatalogue = "This collection is not available yet.",
	RateLimited = "Wait a moment.",
	UseFreePick = "Claim your free pick first",
	NotEnoughCredits = "Not enough Credits.",
	NotEnoughStocks = "Not enough Stocks.",
	AgentNotOwned = "Own the agent first.",
	UnknownOffer = "Offer gone. Refresh.",
	NotOnSale = "Offer rotated out. Refresh.",
	NotAvailable = "Coming soon.",
	TalentUnavailable = "Pick an available Talent.",
	InstinctUnavailable = "Pick an available Instinct.",
}

function RequestFeedback.declined(reason: any): string
	return if type(reason) == "string"
		then messages[reason] or "The request was declined. Try again."
		else "The request was declined. Try again."
end

return table.freeze(RequestFeedback)
