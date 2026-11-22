--!strict
-- Guided rarity selection. Drafts remain local until the existing deploy/lock-in requests validate them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local AssetDefs = require(Shared.Defs.AssetDefs)
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Effect = require(script.Parent.Parent.Components.AssetEffect)
local Draft = require(script.Parent.Parent.AssetDraft)
local Style = require(script.Parent.Parent.Parent.Combat.AssetStyle)
local Icons = require(script.Parent.Parent.Parent.Combat.HudIcons)
local cleanup = Janitor.new()
local view = { Tab = "Assets" } :: Types.MenuView
local config = GameConfig.Menu

function view.Unmount()
	cleanup:Cleanup()
end

function view.Mount(stage, navigator)
	view.Unmount()
	local session = Kit.session(stage, "ASSETS / PLAN YOUR FOUR PICKS", navigator)
	cleanup:Add(session.destroy)
	local snapshot = navigator.snapshot()
	local initial = Draft.get(snapshot and snapshot.Loadout and snapshot.Loadout.AssetIds)
	local selectedSlot = table.find(initial, "") or 1
	local lastAction = ""
	local top = config.TextSizes.Small * 3 + config.GapPixels
	local contentTop = top + config.TextSizes.Title + config.GapPixels
	local bottom = config.PrimaryHeightPixels + config.GapPixels
	local instructions = Kit.text(
		session.Body,
		"Choose four different Assets, one per rarity. During a match, open a matching-rarity safe to activate that Asset.",
		0,
		config.TextSizes.Small * 3
	)
	instructions.TextSize = config.TextSizes.Small
	local slotHeading = Kit.text(session.Body, "1  SELECT A RARITY SLOT", top, config.TextSizes.Title)
	slotHeading.TextSize = config.TextSizes.Body
	local chooseHeading = Kit.text(session.Body, "", top, config.TextSizes.Title)
	chooseHeading.Position = UDim2.new(0.33, 0, 0, top)
	chooseHeading.Size = UDim2.new(0.67, 0, 0, config.TextSizes.Title)
	chooseHeading.TextSize = config.TextSizes.Body
	local slots = Kit.frame(
		session.Body,
		"AssetSlots",
		UDim2.fromOffset(0, contentTop),
		UDim2.new(0.3, 0, 1, -contentTop - bottom)
	)
	local choices = Kit.scroll(
		session.Body,
		"AssetChoices",
		UDim2.new(0.33, 0, 0, contentTop),
		UDim2.new(0.67, 0, 1, -contentTop - bottom)
	)
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(config.GapPixels, config.GapPixels)
	layout.CellSize = UDim2.new(
		0.5,
		-config.GapPixels,
		0,
		config.TextSizes.Title
			+ config.TextSizes.Small * 6
			+ config.SecondaryHeightPixels
			+ config.PaddingPixels * 2
			+ config.GapPixels * 2
	)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = choices
	local slotButtons = {}
	local choiceButtons = {}
	local refresh: () -> ()
	for index, rarity in AssetDefs.rarities do
		local button = Kit.Theme.secondaryButton({
			Name = `AssetSlot{index}`,
			Text = "",
			Parent = slots,
			Position = UDim2.new(
				0,
				0,
				(index - 1) / #AssetDefs.rarities,
				(index - 1) * config.GapPixels / #AssetDefs.rarities
			),
			Size = UDim2.new(
				1,
				0,
				1 / #AssetDefs.rarities,
				-config.GapPixels * (#AssetDefs.rarities - 1) / #AssetDefs.rarities
			),
			OnActivated = function()
				selectedSlot = index
				lastAction = ""
				refresh()
			end,
		})
		button.Instance.TextSize = config.TextSizes.Small
		local stripe = Instance.new("Frame")
		stripe.Name = "RarityStripe"
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = Style.color(rarity) or Kit.Theme.Colors.Text
		stripe.Position = UDim2.fromOffset(0, config.PaddingPixels)
		stripe.Size = UDim2.new(0, config.AccentBarPixels, 1, -config.PaddingPixels * 2)
		stripe.Parent = button.Instance
		slotButtons[index] = button
	end
	for order, id in AssetDefs.order do
		local def = assert(AssetDefs.get(id))
		local panel = Kit.panel(choices, `AssetChoice_{id}`, UDim2.new(), UDim2.new())
		panel.LayoutOrder = order
		local iconPixels = GameConfig.UI.FloatingHud.GadgetIconPixels
		Icons.draw(panel, id, UDim2.new(), iconPixels, Kit.Theme.Colors.Text)
		local title = Kit.text(panel, def.Name, 0, config.TextSizes.Title + config.GapPixels / 2, true)
		title.Position = UDim2.fromOffset(iconPixels + config.GapPixels, 0)
		title.Size = UDim2.new(1, -iconPixels - config.GapPixels, 0, config.TextSizes.Title + config.GapPixels / 2)
		title.TextSize = config.TextSizes.Title
		local value = Kit.text(panel, "", iconPixels + config.GapPixels / 2, config.TextSizes.Small * 3)
		value.TextSize = config.TextSizes.Small
		local note =
			Kit.text(panel, "", iconPixels + config.GapPixels + config.TextSizes.Small * 3, config.TextSizes.Small * 2)
		note.TextSize = config.TextSizes.Small
		note.TextColor3 = Kit.Theme.Colors.TextDim
		local button = Kit.Theme.secondaryButton({
			Name = `ChooseAsset_{id}`,
			Text = "",
			Parent = panel,
			Position = UDim2.new(0, 0, 1, -config.SecondaryHeightPixels),
			OnActivated = function()
				local picks = Draft.get()
				local previous = AssetDefs.get(picks[selectedSlot])
				local used = table.find(picks, id)
				if used == selectedSlot then
					return
				end
				if Draft.choose(selectedSlot, id) then
					local rarity = Style.name(AssetDefs.rarities[selectedSlot])
					lastAction = `{def.Name} chosen for {rarity}.`
					if used then
						local other = Style.name(AssetDefs.rarities[used])
						lastAction ..= if previous
							then ` {previous.Name} moved to {other}.`
							else ` {other} is now empty.`
					end
					refresh()
				end
			end,
		})
		button.Instance.TextSize = config.TextSizes.Small
		choiceButtons[id] = { button = button, value = value, note = note }
	end
	local clear = Kit.Theme.secondaryButton({
		Name = "ClearSelectedAsset",
		Text = "CLEAR SELECTED SLOT",
		Parent = session.Body,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.3, 0, 0, config.SecondaryHeightPixels),
		OnActivated = function()
			if Draft.clear(selectedSlot) then
				lastAction = "Slot cleared. Choose its replacement from the list."
				refresh()
			end
		end,
	})
	clear.Instance.TextSize = config.TextSizes.Small
	local progress = Kit.text(session.Body, "", 0, config.TextSizes.Title)
	progress.Position = UDim2.new(0.33, 0, 1, -config.PrimaryHeightPixels)
	progress.Size = UDim2.new(0.39, 0, 0, config.TextSizes.Title)
	progress.TextSize = config.TextSizes.Title
	local explanation = Kit.text(session.Body, "Picks apply when you deploy.", 0, config.TextSizes.Small * 2)
	explanation.Position =
		UDim2.new(0.33, 0, 1, -config.PrimaryHeightPixels + config.TextSizes.Title + config.GapPixels / 2)
	explanation.Size = UDim2.new(0.39, 0, 0, config.TextSizes.Small * 2)
	explanation.TextSize = config.TextSizes.Small
	local proceed = Kit.Theme.primaryButton({
		Name = "FinishAssetPicks",
		Text = "CONTINUE TO PLAY",
		Parent = session.Body,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.25, 0, 0, config.PrimaryHeightPixels),
		OnActivated = function()
			if Draft.selection() then
				navigator.navigateTo("Play")
			end
		end,
	})
	proceed.Instance.TextSize = config.TextSizes.Button
	function refresh()
		local picks = Draft.get()
		local rarity = AssetDefs.rarities[selectedSlot]
		local filled = 0
		chooseHeading.Text = `2  CHOOSE FOR {string.upper(Style.name(rarity))} · {#AssetDefs.order} OPTIONS`
		for index, button in slotButtons do
			local def = AssetDefs.get(picks[index])
			if def then
				filled += 1
			end
			local slotRarity = AssetDefs.rarities[index]
			button.SetText(
				`{index} · {Style.name(slotRarity)}{if index == selectedSlot then " · EDITING" else ""}\n{if def
					then def.Name
					else "EMPTY — CHOOSE AN ASSET"}\n{if def
					then Effect.short(def.Id, slotRarity)
					else "Required before deployment"}`
			)
			button.SetSelected(index == selectedSlot)
		end
		local complete = Draft.selection() ~= nil
		progress.Text = if complete
			then `{filled} / {#AssetDefs.rarities} ASSETS READY`
			else `{filled} / {#AssetDefs.rarities} — FILL EMPTY SLOTS`
		progress.TextColor3 = if complete then Kit.Theme.Colors.Text else Kit.Theme.Colors.BrassBright
		proceed.SetEnabled(complete and navigator.canOpen("Play"))
		clear.SetEnabled(AssetDefs.get(picks[selectedSlot]) ~= nil)
		for id, choice in choiceButtons do
			local used = table.find(picks, id)
			choice.value.Text = Effect.detail(id, rarity)
			choice.button.SetSelected(used == selectedSlot)
			if used == selectedSlot then
				choice.note.Text = "Chosen for this rarity slot."
				choice.button.SetText("SELECTED ✓")
			elseif used then
				local other = Style.name(AssetDefs.rarities[used])
				local previous = AssetDefs.get(picks[selectedSlot])
				choice.note.Text = if previous
					then `In {other}. Swaps {previous.Name} into that slot.`
					else `Moves from {other}, leaving that slot empty.`
				choice.button.SetText(
					if previous then `SWAP WITH {string.upper(other)}` else `MOVE FROM {string.upper(other)}`
				)
			else
				choice.note.Text = "Not yet in your four picks."
				choice.button.SetText(`CHOOSE FOR {string.upper(Style.name(rarity))}`)
			end
		end
		session.status(
			if lastAction ~= ""
				then lastAction
				else "Select a slot on the left, then choose its Asset on the right. Each Asset can appear only once."
		)
	end
	refresh()
	session.watch(function(data)
		Draft.get(data.Loadout and data.Loadout.AssetIds)
		refresh()
	end)
end
return view
