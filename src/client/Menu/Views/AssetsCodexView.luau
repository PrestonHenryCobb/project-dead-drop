--!strict
-- Four rarity slots, four different local draft picks. Lock-in submits them for server validation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local AssetDefs = require(Shared.Defs.AssetDefs)
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Draft = require(script.Parent.Parent.AssetDraft)
local Style = require(script.Parent.Parent.Parent.Combat.AssetStyle)
local cleanup = Janitor.new()
local view = { Tab = "Assets" } :: Types.MenuView
function view.Unmount()
	cleanup:Cleanup()
end
function view.Mount(stage, navigator)
	view.Unmount()
	local session = Kit.session(stage, "ASSETS / FOUR-SLOT LOADOUT", navigator)
	cleanup:Add(session.destroy)
	local snapshot = navigator.snapshot()
	Draft.get(snapshot and snapshot.Loadout and snapshot.Loadout.AssetIds)
	local slots =
		Kit.scrollRegion(session.Body, "AssetSlots", UDim2.new(), UDim2.fromScale(0.4, 1), "FOUR RARITY SLOTS")
	local choices = Kit.scrollRegion(
		session.Body,
		"AssetChoices",
		UDim2.fromScale(0.43, 0),
		UDim2.fromScale(0.57, 1),
		"SCROLL / SIX ASSETS · NO REPEATS"
	)
	Kit.stack(slots)
	Kit.stack(choices)
	local selectedSlot = 1
	local slotButtons = {}
	local choiceButtons = {}
	local refresh: () -> ()
	for index, rarity in AssetDefs.rarities do
		local button = Kit.Theme.secondaryButton({
			Name = `AssetSlot{index}`,
			Text = "",
			Parent = slots,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, GameConfig.Menu.SecondaryHeightPixels + GameConfig.Menu.TextSizes.Small),
			OnActivated = function()
				selectedSlot = index
				refresh()
			end,
		})
		button.Instance.TextColor3 = Style.color(rarity) or Kit.Theme.Colors.Text
		slotButtons[index] = button
	end
	for order, id in AssetDefs.order do
		local def = AssetDefs.get(id)
		if not def then
			continue
		end
		local panel = Kit.flowPanel(choices, `AssetChoice_{id}`)
		panel.LayoutOrder = order
		Kit.flowText(panel, "Name", def.Name, 1, true)
		Kit.flowText(panel, "Description", def.Description, 2)
		local value = Kit.flowText(panel, "AssetValue", "", 3)
		local button = Kit.Theme.secondaryButton({
			Name = `ChooseAsset_{id}`,
			Text = "ASSIGN TO SLOT",
			Parent = panel,
			LayoutOrder = 4,
			OnActivated = function()
				if Draft.choose(selectedSlot, id) then
					refresh()
				end
			end,
		})
		choiceButtons[id] = { button = button, value = value }
	end
	function refresh()
		session.status(
			"DRAFT · Lock in with your agent. Find a safe's rarity to activate that slot. Four different Assets."
		)
		local picks = Draft.get()
		local rarity = AssetDefs.rarities[selectedSlot]
		for index, button in slotButtons do
			local def = AssetDefs.get(picks[index])
			local slotRarity = AssetDefs.rarities[index]
			button.SetText(
				`{Style.name(slotRarity)} · {if def then def.Name else "?"}\n{Style.value(picks[index], slotRarity)}`
			)
			button.SetSelected(index == selectedSlot)
		end
		for id, choice in choiceButtons do
			local used = table.find(picks, id)
			choice.value.Text = `{Style.name(rarity)} · {Style.value(id, rarity)}`
			choice.button.SetEnabled(used == nil or used == selectedSlot)
			choice.button.SetSelected(used == selectedSlot)
			choice.button.SetText(
				if used and used ~= selectedSlot
					then `IN {Style.name(AssetDefs.rarities[used])} SLOT`
					else if used then "ASSIGNED" else `ASSIGN TO {string.upper(Style.name(rarity))}`
			)
		end
	end
	refresh()
	session.watch(function(data)
		Draft.get(data.Loadout and data.Loadout.AssetIds)
		refresh()
	end)
end
return view
