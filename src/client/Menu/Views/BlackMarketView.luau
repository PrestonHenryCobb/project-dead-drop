--!strict
-- Rotating server offers and confirmed cosmetic ownership; no art or equip state is fabricated.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Feedback = require(script.Parent.Parent.RequestFeedback)
local cleanup = Janitor.new()
local content = Janitor.new()
local view = { Tab = "BlackMarket" } :: Types.MenuView
function view.Unmount()
	cleanup:Cleanup()
	content:Cleanup()
end
function view.Mount(stage, navigator)
	view.Unmount()
	local session = Kit.session(stage, "BLACK MARKET / COSMETICS ONLY", navigator)
	cleanup:Add(session.destroy)
	local daily = Kit.scroll(session.Body, "DailyOffers", UDim2.new(), UDim2.fromScale(0.6, 1))
	local featured = Kit.scroll(session.Body, "FeaturedOffer", UDim2.fromScale(0.63, 0), UDim2.fromScale(0.37, 1))
	Kit.stack(daily)
	Kit.stack(featured)
	local offers: Types.BlackMarketState? = nil
	local fetching, purchasing = false, false
	local retryAt = 0
	local clocks: { { label: TextLabel, at: number, prefix: string } } = {}
	local draw: () -> ()
	local fetch: () -> ()
	local function launch(callback: () -> ())
		local thread = task.spawn(callback)
		cleanup:Add(function()
			if coroutine.status(thread) ~= "dead" and thread ~= coroutine.running() then
				task.cancel(thread)
			end
		end)
	end
	local function buy(id: string)
		if purchasing or fetching or not offers then
			return
		end
		purchasing = true
		draw()
		session.status("Awaiting purchase confirmation…")
		launch(function()
			local connected, accepted, reason = pcall(Kit.Remote.invoke, "RequestBlackMarketPurchase", id)
			if not session.alive() then
				return
			end
			purchasing = false
			draw()
			session.status(
				if connected and accepted
					then "Purchased. No art yet; this cosmetic cannot be equipped."
					elseif connected then Feedback.declined(reason)
					else "Connection unavailable. Refresh ownership before retrying."
			)
		end)
	end
	function draw()
		local restoreFocus = Kit.rememberFocus(session.Body)
		local dailyScroll, featuredScroll = daily.CanvasPosition, featured.CanvasPosition
		content:Cleanup()
		table.clear(clocks)
		local snapshot = session.snapshot()
		local profile = snapshot and snapshot.Profile
		local header = content:Add(Kit.flowPanel(daily, "MarketHeader"))
		header.LayoutOrder = 0
		Kit.flowText(header, "DailyTitle", "DAILY OFFERS", 1, true)
		Kit.flowText(
			header,
			"Balances",
			if profile then `{profile.Stocks} STOCKS · {profile.Credits} CREDITS` else "Loading balances…",
			2
		)
		if offers then
			local clock = Kit.flowText(header, "DailyReset", "", 3)
			table.insert(clocks, { label = clock, at = offers.ResetsAt, prefix = "DAILY RESETS IN" })
		end
		Kit.button(
			header,
			if fetching then "REFRESHING…" else "REFRESH OFFERS",
			0,
			fetch,
			not fetching and not purchasing
		).Instance.LayoutOrder =
			4
		Kit.button(header, "VISIT THE MINT", 0, function()
			navigator.navigateTo("Mint")
		end).Instance.LayoutOrder =
			5
		Kit.flowText(header, "ArtNotice", "Cosmetic ownership only. No art yet; purchased items cannot be equipped.", 6)
		local state = offers
		if not state then
			Kit.flowText(
				header,
				"Loading",
				if fetching then "Loading today's rotation…" else "Offers unavailable. Refresh to retry.",
				7
			)
			restoreFocus(session.Body)
			return
		end
		for index, offer in state.Daily do
			local card = content:Add(Kit.flowPanel(daily, offer.Id))
			card.LayoutOrder = index
			local owned = profile ~= nil and profile.OwnedCosmetics[offer.Id] == true
			local agentOwned = profile ~= nil and profile.OwnedAgents[offer.AgentId] == true
			local balance = if not profile
				then 0
				elseif offer.Currency == "Stocks" then profile.Stocks
				else profile.Credits
			local expired = workspace:GetServerTimeNow() >= state.ResetsAt
			Kit.flowText(card, "Name", offer.Name, 1, true)
			Kit.flowText(card, "Category", `{offer.AgentId} · {offer.Kind} · {offer.Tier}`, 2)
			Kit.flowText(card, "Price", `{offer.Price} {string.upper(offer.Currency)}`, 3)
			Kit.flowText(card, "Artwork", "NO ART YET · NOT EQUIPPABLE", 4)
			local title = if not profile
				then "LOADING PROFILE"
				elseif owned then "OWNED"
				elseif expired then "OFFER EXPIRED"
				elseif not agentOwned then "OWN THE AGENT FIRST"
				elseif balance < offer.Price then `NEED {offer.Price - balance} MORE {string.upper(offer.Currency)}`
				else "BUY COSMETIC"
			Kit.button(
				card,
				title,
				0,
				function()
					buy(offer.Id)
				end,
				profile ~= nil
					and not owned
					and agentOwned
					and balance >= offer.Price
					and not expired
					and not purchasing
					and not fetching,
				true
			).Instance.LayoutOrder =
				5
		end
		local bundle = state.Featured
		local card = content:Add(Kit.flowPanel(featured, "FeaturedBundle"))
		Kit.flowText(card, "FeaturedTitle", "FEATURED BUNDLE", 1, true)
		local clock = Kit.flowText(card, "FeaturedReset", "", 2)
		table.insert(clocks, { label = clock, at = state.FeaturedResetsAt, prefix = "FEATURED RESETS IN" })
		Kit.flowText(card, "Name", bundle.Name, 3, true)
		Kit.flowText(card, "Price", `{bundle.Price} STOCKS`, 4)
		local owned, agentsOwned = profile ~= nil, profile ~= nil
		for index, item in bundle.Items do
			local hasItem = profile ~= nil and profile.OwnedCosmetics[item.Id] == true
			owned = owned and hasItem
			agentsOwned = agentsOwned and profile ~= nil and profile.OwnedAgents[item.AgentId] == true
			Kit.flowText(card, item.Id, `{item.Name} · {item.AgentId}{if hasItem then " · OWNED" else ""}`, 4 + index)
		end
		local enough = profile ~= nil and profile.Stocks >= bundle.Price
		local expired = workspace:GetServerTimeNow() >= state.FeaturedResetsAt
		Kit.flowText(card, "ArtNotice", "NO ART YET · NOT EQUIPPABLE", 5 + #bundle.Items)
		Kit.button(
			card,
			if not profile
				then "LOADING PROFILE"
				elseif owned then "OWNED"
				elseif expired then "OFFER EXPIRED"
				elseif not agentsOwned then "OWN ALL INCLUDED AGENTS FIRST"
				elseif not enough then "NOT ENOUGH STOCKS"
				else "BUY FEATURED BUNDLE",
			0,
			function()
				buy(bundle.Id)
			end,
			not owned and agentsOwned and enough and not expired and not purchasing and not fetching,
			true
		).Instance.LayoutOrder = 6
			+ #bundle.Items
		daily.CanvasPosition, featured.CanvasPosition = dailyScroll, featuredScroll
		restoreFocus(session.Body)
	end
	function fetch()
		if fetching or purchasing or not session.alive() then
			return
		end
		fetching = true
		draw()
		launch(function()
			local ok, state = pcall(Kit.Remote.invoke, "GetBlackMarketOffers")
			if not session.alive() then
				return
			end
			fetching = false
			retryAt = workspace:GetServerTimeNow() + GameConfig.Menu.DeployRetrySeconds
			if ok and type(state) == "table" then
				offers = state :: Types.BlackMarketState
			else
				session.status("Offers unavailable. Refresh to retry.")
			end
			draw()
		end)
	end
	cleanup:Add(RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, clock in clocks do
			local seconds = math.max(0, math.ceil(clock.at - now))
			local text = string.format(
				"%s · %02d:%02d:%02d",
				clock.prefix,
				math.floor(seconds / 3600),
				math.floor(seconds / 60) % 60,
				seconds % 60
			)
			if clock.label.Text ~= text then
				clock.label.Text = text
			end
		end
		if offers and now >= math.min(offers.ResetsAt, offers.FeaturedResetsAt) and now >= retryAt then
			fetch()
		end
	end))
	session.watch(function()
		draw()
	end)
	fetch()
end
return view
