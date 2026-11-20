--!strict
-- User-facing explanations of existing server refusals. No optimistic profile or purchase changes.
local RequestFeedback = {}
local messages: { [string]: string } = {
	NoProfile = "Your profile is still loading. Try again shortly.",
	BadRequest = "That selection could not be submitted. Choose it again.",
	UnknownAgent = "That agent is currently unavailable.",
	AgentLocked = "Choose an agent you own.",
	AlreadyOwned = "You already own this.",
	NoFreePick = "Your free pick for that class has already been used.",
	HardwareUnavailable = "That Hardware is currently unavailable.",
	MasteryTooLow = "Earn more Agent Mastery to equip that Hardware.",
	GadgetUnavailable = "Choose available gadgets without repeats.",
	AssetUnavailable = "Fill all four slots with different Assets.",
	NoCatalogue = "This collection is not available yet.",
	RateLimited = "Please wait a moment before trying again.",
	UseFreePick = "Claim your free pick first",
	NotEnoughCredits = "Not enough Credits.",
	NotEnoughStocks = "Not enough Stocks. Visit the Mint to view packages.",
	AgentNotOwned = "Own this agent before buying their Attire.",
	UnknownOffer = "That offer is no longer available. Refresh the Black Market.",
	NotOnSale = "That offer has rotated out. Refresh the Black Market.",
	NotAvailable = "Coming soon.",
	TalentUnavailable = "Choose one of this agent's available Talents.",
	InstinctUnavailable = "Choose one of this agent's available Instincts.",
}

function RequestFeedback.declined(reason: any): string
	return if type(reason) == "string"
		then messages[reason] or "The request was declined. Try again."
		else "The request was declined. Try again."
end

return table.freeze(RequestFeedback)
