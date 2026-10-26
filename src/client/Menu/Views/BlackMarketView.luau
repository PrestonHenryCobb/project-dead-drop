--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Janitor = require(ReplicatedStorage.Shared.Util.Janitor)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local cleanup = Janitor.new()
local view = { Tab = "BlackMarket" } :: Types.MenuView
function view.Unmount()
	cleanup:Cleanup()
end
function view.Mount(stage, navigator)
	view.Unmount()
	local session = Kit.session(stage, "BLACK MARKET / COSMETICS ONLY", navigator)
	cleanup:Add(session.destroy)
	Kit.documentArt(session.Body, "THE NEXT\nCOLLECTION", UDim2.new(), UDim2.fromScale(0.62, 0.72))
	local rail = Kit.scroll(session.Body, "MarketRail", UDim2.fromScale(0.65, 0), UDim2.fromScale(0.35, 1))
	local panel = Kit.panel(rail, "MarketStatus", UDim2.new(), UDim2.new(1, -14, 0, 500))
	Kit.text(panel, "NO OFFERS ISSUED", 0, 80, true)
	Kit.text(
		panel,
		"The server has not published a cosmetic catalogue or rotation schedule. Offers, ownership, prices and countdowns will appear when that catalogue is available.",
		96,
		180
	)
	Kit.button(panel, "VISIT THE MINT  >", 300, function()
		navigator.navigateTo("Mint")
	end, true, true)
	local balance = Kit.text(panel, "Loading balances…", 390, 70)
	Kit.text(session.Body, "HARDWARE IS EARNED THROUGH AGENT MASTERY", 0, 48, true).Position = UDim2.fromScale(0, 0.78)
	Kit.text(
		session.Body,
		"Assets are found during matches. Neither weapons nor tactical advantages are sold here.",
		0,
		70
	).Position =
		UDim2.fromScale(0, 0.9)
	session.watch(function(data: Types.MetaSnapshot)
		balance.Text = `{data.Profile.Stocks} STOCKS\n{data.Profile.Credits} CREDITS`
	end)
end
return view
