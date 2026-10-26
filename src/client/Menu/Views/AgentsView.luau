--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Agents = require(Shared.Defs.AgentDefs)
local Weapons = require(Shared.Defs.WeaponDefs)
local GameConfig = require(Shared.GameConfig)
local Janitor = require(Shared.Util.Janitor)
local Kit = require(script.Parent.Parent.Components.ViewKit)
local Preview = require(script.Parent.Parent.Components.WeaponPreview)
local cleanup = Janitor.new()
local content = Janitor.new()
local view = { Tab = "Agents" } :: Types.MenuView
function view.Unmount()
	content:Cleanup()
	cleanup:Cleanup()
end
function view.Mount(stage, navigator, context)
	view.Unmount()
	local initial = navigator.snapshot()
	local agentId = if context and Agents.get(context.AgentId)
		then context.AgentId
		elseif initial and initial.Loadout then initial.Loadout.AgentId
		else "Guise"
	local weaponId = if initial
			and initial.Loadout
			and initial.Loadout.AgentId == agentId
		then initial.Loadout.HardwareId
		else ""
	local session = Kit.session(stage, "AGENTS / CHOOSE YOUR COVER", navigator)
	cleanup:Add(session.destroy)
	local function draw()
		local restoreFocus = Kit.rememberFocus(session.Body)
		content:Cleanup()
		local area = Kit.frame(session.Body, "Collection", UDim2.new(), UDim2.fromScale(1, 1))
		content:Add(area)
		local data: Types.MetaSnapshot? = session.snapshot()
		local agent = assert(Agents.get(agentId))
		local hardware = Weapons.getForAgent(agentId)
		local selected = hardware[1]
		for _, item in hardware do
			if item.Id == weaponId then
				selected = item
			end
		end
		weaponId = selected.Id
		navigator.focusAgent(agent.Id, selected.Id)
		local owned = data and data.Profile.OwnedAgents[agentId] == true
		local mastery = if data then data.Profile.Mastery[agentId] else nil
		local level = if mastery then mastery.Level else 0
		local equipped = data
			and data.Loadout
			and data.Loadout.AgentId == agentId
			and data.Loadout.HardwareId == selected.Id
		local allowed = owned and selected.Def ~= nil and level >= selected.UnlockMasteryLevel
		local left = Kit.scroll(area, "Roster", UDim2.new(), UDim2.new(0.24, -12, 1, 0))
		Kit.text(left, string.upper(agentId), 0, 42, true)
		Kit.text(left, agent.Epithet .. "\n" .. agent.Class .. " / " .. agent.Role, 50, 76)
		for index, id in Agents.order do
			local entry = assert(Agents.get(id))
			local button = Kit.button(
				left,
				string.upper(id)
					.. " / "
					.. entry.Class
					.. (if data and data.Profile.OwnedAgents[id] then " · OWNED" else " · LOCKED"),
				142 + (index - 1) * 58,
				function()
					agentId = id
					weaponId = ""
					draw()
				end
			)
			button.SetSelected(id == agentId)
		end
		if data and data.Profile.StarterPicksLeft[agent.Class] and not owned then
			Kit.button(left, "CLAIM FREE " .. string.upper(agent.Class), 506, function()
				session.request("RequestClaimStarterAgent", agentId)
			end, true, true)
		end
		Kit.text(left, "One free operative per class. Claims are confirmed by the server.", 586, 80)
		-- Transparent centre preserves the shell's large native rig and sculpted stage artwork.
		local center = Kit.frame(area, "OperativeStage", UDim2.fromScale(0.25, 0), UDim2.new(0.41, -12, 1, 0))
		local caption = Kit.panel(center, "Mastery", UDim2.new(0, 0, 1, -180), UDim2.new(1, 0, 0, 180))
		Kit.text(caption, `MASTERY {level} / {GameConfig.Mastery.MaxLevel}`, 0, 36, true)
		Kit.text(
			caption,
			`W2 / LEVEL {hardware[2].UnlockMasteryLevel}    W3 / LEVEL {hardware[3].UnlockMasteryLevel}`,
			42,
			44
		)
		Kit.button(caption, "OPEN ARMORY BAY  >", 92, function()
			navigator.navigateTo("Hardware", { AgentId = agentId })
		end)
		local side = Kit.scroll(area, "Inspector", UDim2.fromScale(0.67, 0), UDim2.fromScale(0.33, 1))
		Kit.text(side, "EXCLUSIVE HARDWARE", 0, 36, true)
		for index, item in hardware do
			local state = if not item.Def
				then "IN DEVELOPMENT"
				elseif level < item.UnlockMasteryLevel or not owned then `LOCKED · LVL {item.UnlockMasteryLevel}`
				else "AVAILABLE"
			if data and data.Loadout and data.Loadout.HardwareId == item.Id then
				state = "EQUIPPED"
			end
			local button = Kit.button(side, `W{item.Slot} · {item.Name}\n{state}`, 40 + (index - 1) * 58, function()
				weaponId = item.Id
				draw()
			end)
			button.SetSelected(item.Id == weaponId)
		end
		local art = Kit.frame(side, "SelectedHardware", UDim2.fromOffset(0, 222), UDim2.new(1, 0, 0, 120))
		if selected.Def then
			Preview.mount(art, selected.Def, content)
		else
			Kit.text(art, "HARDWARE IN DEVELOPMENT", 0, 80, true)
		end
		if selected.Def then
			local def = selected.Def
			Kit.text(
				side,
				`{def.Damage} DMG · {def.RPM} RPM · {def.MagSize}/{def.ReserveAmmo} AMMO\n{def.ReloadSeconds}s RELOAD · {def.AimZoom}x FOV`,
				356,
				60
			)
		end
		Kit.button(
			side,
			if equipped then "EQUIPPED" elseif allowed then "EQUIP OPERATIVE + HARDWARE" else "LOCKED / UNAVAILABLE",
			426,
			function()
				session.request("RequestEquipLoadout", { AgentId = agentId, HardwareId = weaponId })
			end,
			allowed == true and not equipped,
			true
		)
		local y = 510
		Kit.text(side, "DESIGNED KIT / ABILITIES IN DEVELOPMENT", y, 44)
		for _, talent in agent.Talents do
			Kit.text(side, talent.Name .. ` · {talent.CooldownSeconds or 0}s\n` .. talent.Description, y + 48, 130)
			y += 140
		end
		for _, instinct in agent.Instincts do
			Kit.text(side, instinct.Name .. " · PASSIVE\n" .. instinct.Description, y + 48, 130)
			y += 140
		end
		restoreFocus(area)
	end
	draw()
	session.watch(function()
		draw()
	end)
end
return view
