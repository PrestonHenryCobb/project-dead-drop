--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Agents = require(Shared.Defs.AgentDefs)
local Weapons = require(Shared.Defs.WeaponDefs)
local Janitor = require(Shared.Util.Janitor)
local config = require(Shared.GameConfig).Menu
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
	local session = Kit.session(stage, "HARDWARE / THE ARMORY", navigator)
	cleanup:Add(session.destroy)
	local function draw()
		local restoreFocus = Kit.rememberFocus(session.Body)
		content:Cleanup()
		local root = Kit.frame(session.Body, "Armory", UDim2.new(), UDim2.fromScale(1, 1))
		content:Add(root)
		local data: Types.MetaSnapshot? = session.snapshot()
		local filters = Kit.scroll(root, "OperativeFilters", UDim2.new(), UDim2.new(0.64, 0, 0, 116))
		local options = { "All" }
		for _, id in Agents.order do
			table.insert(options, id)
		end
		for index, id in options do
			local button = Kit.Theme.secondaryButton({
				Name = "Filter" .. id,
				Text = if id == "All" then "ALL 18 HARDWARE" else string.upper(id),
				Parent = filters,
				Size = UDim2.new(0.25, -8, 0, 46),
				Position = UDim2.new(((index - 1) % 4) * 0.25, 0, 0, math.floor((index - 1) / 4) * 58),
				OnActivated = function()
					filter = id
					draw()
				end,
			})
			button.SetSelected(filter == id)
		end
		local grid = Kit.scroll(root, "HardwareGrid", UDim2.fromOffset(0, 126), UDim2.new(0.64, 0, 1, -126))
		local index = 0
		for _, id in Agents.order do
			if filter ~= "All" and filter ~= id then
				continue
			end
			for _, item in Weapons.getForAgent(id) do
				local card = Kit.panel(
					grid,
					item.Id,
					UDim2.new((index % 3) / 3, 0, 0, math.floor(index / 3) * 218),
					UDim2.new(1 / 3, -12, 0, 206)
				)
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
					selected = item
					draw()
				end)
				button.SetSelected(selected.Id == item.Id)
			end
		end
		local inspector = Kit.frame(root, "HardwareInspector", UDim2.fromScale(0.67, 0), UDim2.fromScale(0.33, 1))
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
			local stats = Kit.text(
				side,
				`{def.Damage} DMG · {def.HeadshotMult}x HEAD · {def.RPM} RPM\n{def.MagSize}/{def.ReserveAmmo} AMMO · {def.ReloadSeconds}s RELOAD\n{def.AimZoom}x FOV · {if def.Quiet
					then "SUPPRESSED"
					else "UNSUPPRESSED"}`,
				276,
				60
			)
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
				session.request("RequestEquipLoadout", { AgentId = selected.Agent, HardwareId = selected.Id })
			end,
			allowed == true and not equipped,
			true
		)
		Kit.button(actions, "BACK TO AGENT OVERVIEW", config.PrimaryHeightPixels + config.GapPixels, function()
			navigator.navigateTo("Agents", { AgentId = selected.Agent })
		end)
		Kit.text(side, "Earn Hardware through Agent Mastery. Weapon finishes are not yet published.", 412, 70)
		restoreFocus(root)
	end
	draw()
	session.watch(function()
		draw()
	end)
end
return view
