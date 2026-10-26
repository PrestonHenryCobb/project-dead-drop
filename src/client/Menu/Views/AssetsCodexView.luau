--!strict
-- Approved BUILD_ORDER Step 7B descriptions; a reference codex, not a pre-match purchase/loadout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Janitor = require(ReplicatedStorage.Shared.Util.Janitor)
local Art = require(script.Parent.Parent.Components.DecoArt)
local cleanup = Janitor.new()
local entries = {
	{ "Light Feet", "Sprinting and jumping raise suspicion slower.", "−15% / −25% / −35% / −50%" },
	{ "Quick Hands", "Intel stations, doors and the vault hack faster.", "+10% / +20% / +30% / +40%" },
	{ "Steady Nerves", "Suspicion drains faster once unwatched.", "+25% / +50% / +100% / +150%" },
	{ "Deep Pockets", "Intel purchases cost less.", "−10% / −15% / −25% / −35%" },
	{ "Field Medic", "Health stations and food heal more.", "+15% / +30% / +50% / +75%" },
	{ "Duct Rat", "Crawl through vents faster; quiet from Black Ops.", "+20% / +35% / +50% / +75%" },
}
local rarities = { "Field Agent", "Infiltrator", "Black Ops", "Ghost" }
local view = { Tab = "Assets" } :: Types.MenuView
function view.Unmount()
	cleanup:Cleanup()
end
function view.Mount(stage)
	view.Unmount()
	local session = Kit.session(stage, "ASSETS / FIELD INTELLIGENCE")
	cleanup:Add(session.destroy)
	session.status("REFERENCE CODEX · SCROLL to browse six Assets. Find them during matches.")
	local selected = 1
	local rarity = 1
	local cards = Kit.scrollRegion(
		session.Body,
		"AssetCards",
		UDim2.new(),
		UDim2.fromScale(0.62, 1),
		"SCROLL / ALL SIX FIELD ASSETS"
	)
	local inspector = Kit.scroll(session.Body, "AssetInspector", UDim2.fromScale(0.65, 0), UDim2.fromScale(0.35, 1))
	local inspect = Kit.panel(inspector, "AssetBriefing", UDim2.new(), UDim2.new(1, -14, 0, 570))
	local title = Kit.text(inspect, "", 0, 70, true)
	local detail = Kit.text(inspect, "", 90, 160)
	local chip = Kit.text(inspect, "", 260, 110)
	Kit.text(
		inspect,
		"EQUAL FOOTING\nAssets are found in supply caches and tier-room safes during the match. They cannot be bought with Stocks or Credits.",
		390,
		160
	)
	local rarityButtons = {}
	local assetButtons = {}
	local function refresh()
		for index, button in rarityButtons do
			button.SetSelected(index == rarity)
		end
		for index, button in assetButtons do
			button.SetSelected(index == selected)
		end
		local entry = entries[selected]
		title.Text = string.upper(entry[1])
		detail.Text = entry[2]
		local values = string.split(entry[3], " / ")
		chip.Text = rarities[rarity] .. "\n" .. values[rarity] .. "\nAPPROVED DESIGN · Match integration pending"
	end
	for index, name in rarities do
		rarityButtons[index] = Kit.Theme.secondaryButton({
			Name = "Rarity" .. index,
			Text = name,
			Parent = cards,
			Size = UDim2.new(0.5, -8, 0, 46),
			Position = UDim2.new(((index - 1) % 2) * 0.5, 0, 0, math.floor((index - 1) / 2) * 58),
			OnActivated = function()
				rarity = index
				refresh()
			end,
		})
	end
	for index, entry in entries do
		local card = Kit.panel(
			cards,
			"Asset" .. index,
			UDim2.new(((index - 1) % 2) * 0.5, 0, 0, 136 + math.floor((index - 1) / 2) * 142),
			UDim2.new(0.5, -12, 0, 130)
		)
		local emblem = Kit.frame(card, "CredentialArtwork", UDim2.fromOffset(0, 0), UDim2.fromOffset(48, 48))
		Art.insignia(emblem, "Asset")
		local kicker = Kit.text(card, string.format("%02d / FIELD ASSET", index), 0, 24)
		kicker.Position = UDim2.fromOffset(58, 8)
		kicker.Size = UDim2.new(1, -58, 0, 32)
		assetButtons[index] = Kit.button(card, entry[1] .. "  >", 58, function()
			selected = index
			refresh()
		end)
	end
	refresh()
end
return view
