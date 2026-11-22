--!strict
local WeaponSummary = require(script.Parent.Parent.Parent.Combat.WeaponSummary)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Agents = require(Shared.Defs.AgentDefs)
local Weapons = require(Shared.Defs.WeaponDefs)
local Janitor = require(Shared.Util.Janitor)
local GameConfig = require(Shared.GameConfig)
local config = GameConfig.Menu
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Preview = require(script.Parent.Parent.Components.WeaponPreview)
local cleanup = Janitor.new()
local content = Janitor.new()
local view = { Tab = "Hardware" } :: Types.MenuView

function view.Unmount()
	content:Cleanup()
	cleanup:Cleanup()
end
function view.Mount(stage, navigator, context)
	view.Unmount()
	local filter = if context and Agents.get(context.AgentId) then context.AgentId else "All"
	local selected = Weapons.getForAgent(if filter == "All" then "Guise" else filter)[1]
	local selectedByUser = false
	local drawnFilter = filter
	local initial = navigator.snapshot()
	if initial and initial.Loadout and (filter == "All" or filter == initial.Loadout.AgentId) then
		for _, item in Weapons.getForAgent(initial.Loadout.AgentId) do
			if item.Id == initial.Loadout.HardwareId then
				selected = item
				break
			end
		end
	end
	local session = Kit.session(stage, "HARDWARE / THE ARMORY", navigator)
	cleanup:Add(session.destroy)
	local function draw()
		local restoreFocus = Kit.rememberFocus(session.Body)
		local previous = session.Body:FindFirstChild("Armory")
		local oldFilters = previous and previous:FindFirstChild("OperativeFilters")
		local oldGrid = previous and previous:FindFirstChild("HardwareGrid")
		local filterScroll = if oldFilters and oldFilters:IsA("ScrollingFrame")
			then oldFilters.CanvasPosition
			else Vector2.zero
		local gridScroll = if drawnFilter == filter
				and oldGrid
				and oldGrid:IsA("ScrollingFrame")
			then oldGrid.CanvasPosition
			else Vector2.zero
		drawnFilter = filter
		content:Cleanup()
		local root = Kit.frame(session.Body, "Armory", UDim2.new(), UDim2.fromScale(1, 1))
		content:Add(root)
		local data: Types.MetaSnapshot? = session.snapshot()
		if not selectedByUser and data and data.Loadout and (filter == "All" or filter == data.Loadout.AgentId) then
			for _, item in Weapons.getForAgent(data.Loadout.AgentId) do
				if item.Id == data.Loadout.HardwareId then
					selected = item
					break
				end
			end
		end
		navigator.focusAgent(selected.Agent, selected.Id)
		local filters = Kit.scroll(root, "OperativeFilters", UDim2.new(), UDim2.new(0.26, 0, 0, 116))
		local options = { "All" }
		for _, id in Agents.order do
			table.insert(options, id)
		end
		for index, id in options do
			local button = Kit.Theme.secondaryButton({
				Name = "Filter" .. id,
				Text = if id == "All" then "ALL 18 HARDWARE" else string.upper(id),
				Parent = filters,
				Size = UDim2.new(0.5, -8, 0, 46),
				Position = UDim2.new(((index - 1) % 2) * 0.5, 0, 0, math.floor((index - 1) / 2) * 58),
				OnActivated = function()
					filter = id
					if id ~= "All" and selected.Agent ~= id then
						selected = Weapons.getForAgent(id)[1]
						selectedByUser = true
					end
					draw()
				end,
			})
			button.SetSelected(filter == id)
		end
		local grid = Kit.scroll(root, "HardwareGrid", UDim2.fromOffset(0, 126), UDim2.new(0.26, 0, 1, -126))
		local index = 0
		for _, id in Agents.order do
			if filter ~= "All" and filter ~= id then
				continue
			end
			for _, item in Weapons.getForAgent(id) do
				local card = Kit.panel(grid, item.Id, UDim2.fromOffset(0, index * 218), UDim2.new(1, -12, 0, 206))
				index += 1
				local mastery = if data then data.Profile.Mastery[id] else nil
				local unlocked = data
					and data.Profile.OwnedAgents[id]
					and mastery
					and mastery.Level >= item.UnlockMasteryLevel
				local state = if not item.Def
					then "IN DEVELOPMENT"
					elseif not unlocked then `LOCKED · LVL {item.UnlockMasteryLevel}`
					elseif data and data.Loadout and data.Loadout.HardwareId == item.Id then "EQUIPPED"
					else "AVAILABLE"
				Kit.text(card, string.upper(id) .. ` / W{item.Slot}`, 0, 24)
				local art = Kit.frame(card, "Silhouette", UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 88))
				if item.Def then
					Preview.mount(art, item.Def, content)
				else
					Kit.text(art, item.Category .. "\nIN DEVELOPMENT", 0, 80, true)
				end
				local button = Kit.button(card, item.Name .. "\n" .. state, 126, function()
					selectedByUser = true
					selected = item
					draw()
				end)
				button.SetSelected(selected.Id == item.Id)
			end
		end
		local inspector = Kit.frame(root, "HardwareInspector", UDim2.fromScale(0.72, 0), UDim2.fromScale(0.28, 1))
		local actionHeight = config.PrimaryHeightPixels + config.GapPixels + config.SecondaryHeightPixels
		local side =
			Kit.scroll(inspector, "Details", UDim2.new(), UDim2.new(1, 0, 1, -(actionHeight + config.GapPixels)))
		local actions =
			Kit.frame(inspector, "Actions", UDim2.new(0, 0, 1, -actionHeight), UDim2.new(1, 0, 0, actionHeight))
		Kit.text(side, selected.Name, 0, 44, true)
		Kit.text(side, string.upper(selected.Agent) .. ` / W{selected.Slot} · {selected.Category}`, 50, 30)
		local art = Kit.frame(side, "Turntable", UDim2.fromOffset(0, 84), UDim2.new(1, -14, 0, 132))
		if selected.Def then
			local turntable = Preview.mount(art, selected.Def, content, true)
			for i, label in { "LEFT", "ZOOM", "RIGHT" } do
				Kit.Theme.secondaryButton({
					Name = "Inspect" .. i,
					Text = label,
					Parent = side,
					Size = UDim2.new(1 / 3, -6, 0, 46),
					Position = UDim2.new((i - 1) / 3, 0, 0, 224),
					OnActivated = function()
						if i == 2 then
							turntable.zoom()
						else
							turntable.rotate(if i == 1 then -0.3 else 0.3)
						end
					end,
				})
			end
			local def = selected.Def
			local stats = Kit.text(side, WeaponSummary.detail(def), 276, 60)
			stats.Name = "HardwareStats"
		else
			Kit.documentArt(art, "IN\nDEVELOPMENT", UDim2.new(), UDim2.fromScale(1, 1))
			Kit.text(side, "This weapon is not playable yet. No invented stats or unlock grants.", 282, 100)
		end
		local mastery = if data then data.Profile.Mastery[selected.Agent] else nil
		local allowed = data
			and data.Profile.OwnedAgents[selected.Agent]
			and mastery
			and mastery.Level >= selected.UnlockMasteryLevel
			and selected.Def ~= nil
		local equipped = data and data.Loadout and data.Loadout.HardwareId == selected.Id
		Kit.button(
			actions,
			if equipped
				then "EQUIPPED"
				elseif allowed then "EQUIP TO " .. string.upper(selected.Agent)
				else "LOCKED / UNAVAILABLE",
			0,
			function()
				local agent = assert(Agents.get(selected.Agent))
				local saved = data and data.Loadout
				local sameAgent = saved and saved.AgentId == selected.Agent
				session.request("RequestEquipLoadout", {
					AgentId = selected.Agent,
					HardwareId = selected.Id,
					GadgetIds = if saved then saved.GadgetIds else GameConfig.Gadgets.DefaultPicks,
					AssetIds = if saved then saved.AssetIds else GameConfig.Assets.DefaultPicks,
					TalentId = (if sameAgent and saved then saved.TalentId else nil) or agent.Talents[1].Id,
					InstinctId = (if sameAgent and saved then saved.InstinctId else nil) or agent.Instincts[1].Id,
				})
			end,
			allowed == true and not equipped,
			true
		)
		Kit.button(actions, "BACK TO AGENT OVERVIEW", config.PrimaryHeightPixels + config.GapPixels, function()
			navigator.navigateTo("Agents", { AgentId = selected.Agent })
		end)
		Kit.text(side, "Earn Hardware through Agent Mastery. Weapon finishes are not yet published.", 412, 70)
		filters.CanvasPosition, grid.CanvasPosition = filterScroll, gridScroll
		restoreFocus(root)
	end
	draw()
	session.watch(function()
		draw()
	end)
end
return view
