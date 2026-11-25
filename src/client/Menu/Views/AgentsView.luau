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
local Art = require(script.Parent.Parent.Components.DecoArt)
local MenuIcons = require(script.Parent.Parent.Components.MenuIcons)
local MenuArtDefs = require(Shared.Defs.MenuArtDefs)
local KitPicker = require(script.Parent.Parent.Components.KitPicker)
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
	local talentId: string? = nil
	local instinctId: string? = nil
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
		local loadout = data and data.Loadout
		local sameAgent = loadout and loadout.AgentId == agentId
		talentId = KitPicker.resolve(
			agent.Talents,
			GameConfig.Mastery.TalentUnlockLevels,
			level,
			talentId or (if sameAgent and loadout then loadout.TalentId else nil)
		)
		instinctId = KitPicker.resolve(
			agent.Instincts,
			GameConfig.Mastery.InstinctUnlockLevels,
			level,
			instinctId or (if sameAgent and loadout then loadout.InstinctId else nil)
		)
		local equipped = data
			and data.Loadout
			and data.Loadout.AgentId == agentId
			and data.Loadout.HardwareId == selected.Id
			and (data.Loadout.TalentId or agent.Talents[1].Id) == talentId
			and (data.Loadout.InstinctId or agent.Instincts[1].Id) == instinctId
		local allowed = owned and selected.Def ~= nil and level >= selected.UnlockMasteryLevel
		local left = Kit.scroll(area, "Roster", UDim2.new(), UDim2.new(0.24, -12, 1, 0))
		Kit.text(left, string.upper(agentId), 0, 42, true)
		local insignia = Kit.frame(left, "OperativeCredential", UDim2.new(1, -64, 0, 0), UDim2.fromOffset(56, 56))
		Art.insignia(insignia, "Asset")
		local card = GameConfig.Menu.Icons.CardPixels
		MenuIcons.portrait(left, agent.Id, card, UDim2.fromOffset(0, 50))
		local epithet = Kit.text(left, agent.Epithet .. "\n" .. agent.Class .. " / " .. agent.Role, 50, 76)
		epithet.Position = UDim2.fromOffset(card + 12, 50)
		epithet.Size = UDim2.new(1, -(card + 12), 0, 76)
		for index, id in Agents.order do
			local entry = assert(Agents.get(id))
			local button = Kit.button(left, string.upper(id), 142 + (index - 1) * 58, function()
				agentId = id
				weaponId = ""
				talentId, instinctId = nil, nil
				draw()
			end)
			local thumb = GameConfig.Menu.Icons.ThumbPixels
			MenuIcons.portrait(button.Instance, id, thumb, UDim2.new(0, 4, 0.5, -thumb / 2))
			MenuIcons.icon(
				button.Instance,
				MenuIcons.classIcon(entry.Class),
				UDim2.new(0, thumb + 12, 0.5, -8),
				16,
				Kit.Theme.Colors.TextDim
			)
			if data and data.Profile.OwnedAgents[id] then
				MenuIcons.badge(button.Instance, "Check", "OWNED", Kit.Theme.Colors.EmeraldBright)
			else
				MenuIcons.badge(button.Instance, "Lock", "LOCKED")
			end
			button.SetSelected(id == agentId)
		end
		if data and data.Profile.StarterPicksLeft[agent.Class] and not owned then
			Kit.button(left, "CLAIM FREE " .. string.upper(agent.Class), 506, function()
				session.request("RequestClaimStarterAgent", agentId)
			end, true, true)
		end
		if data and not owned then
			Kit.button(left, `BUY AGENT · {GameConfig.Shop.AgentCredits} CREDITS`, 566, function()
				session.request("RequestBuyAgent", agentId)
			end, true, true)
		end
		Kit.text(left, "One free agent per class.", 636, 80)
		-- Transparent centre preserves the shell's large native rig and sculpted stage artwork.
		local center = Kit.frame(area, "OperativeStage", UDim2.fromScale(0.25, 0), UDim2.new(0.41, -12, 1, 0))
		local caption = Kit.panel(center, "Mastery", UDim2.new(0, 0, 1, -180), UDim2.new(1, 0, 0, 180))
		Kit.text(caption, `MASTERY {level} / {GameConfig.Mastery.MaxLevel}`, 0, 36, true)
		MenuIcons.pips(
			caption,
			42,
			level,
			GameConfig.Mastery.MaxLevel,
			{ [hardware[2].UnlockMasteryLevel] = "W2", [hardware[3].UnlockMasteryLevel] = "W3" }
		)
		Kit.button(caption, "OPEN ARMORY BAY  >", 92, function()
			navigator.navigateTo("Hardware", { AgentId = agentId })
		end)
		local side = Kit.scroll(area, "Inspector", UDim2.fromScale(0.67, 0), UDim2.fromScale(0.33, 1))
		Kit.text(side, "EXCLUSIVE HARDWARE", 0, 36, true)
		for index, item in hardware do
			local button = Kit.button(side, `W{item.Slot} · {item.Name}`, 40 + (index - 1) * 58, function()
				weaponId = item.Id
				draw()
			end)
			MenuIcons.leadArt(button.Instance, MenuArtDefs.hardware(item.Id), MenuIcons.weaponIcon(item.Category))
			if data and data.Loadout and data.Loadout.HardwareId == item.Id then
				MenuIcons.badge(button.Instance, "Check", "EQUIPPED", Kit.Theme.Colors.EmeraldBright)
			elseif not item.Def then
				MenuIcons.badge(button.Instance, "Soon", "SOON")
			elseif level < item.UnlockMasteryLevel or not owned then
				MenuIcons.badge(button.Instance, "Lock", `LVL {item.UnlockMasteryLevel}`)
			end
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
			MenuIcons.chips(side, MenuIcons.weaponStats(def), 356)
		end
		Kit.button(
			side,
			if equipped then "EQUIPPED" elseif allowed then "EQUIP OPERATIVE + HARDWARE" else "LOCKED / UNAVAILABLE",
			426,
			function()
				session.request("RequestEquipLoadout", {
					AgentId = agentId,
					HardwareId = weaponId,
					TalentId = talentId,
					InstinctId = instinctId,
					GadgetIds = if loadout then loadout.GadgetIds else GameConfig.Gadgets.DefaultPicks,
					AssetIds = if loadout then loadout.AssetIds else GameConfig.Assets.DefaultPicks,
				})
			end,
			allowed == true and not equipped,
			true
		)
		local picker = Kit.frame(side, "KitChoices", UDim2.fromOffset(0, 510), UDim2.new(1, 0, 0, 0))
		picker.AutomaticSize = Enum.AutomaticSize.Y
		Kit.stack(picker)
		KitPicker.mount(picker, agent, level, talentId, instinctId, function(kind, id)
			if kind == "Talent" then
				talentId = id
			else
				instinctId = id
			end
			draw()
		end, owned == true)
		restoreFocus(area)
	end
	draw()
	session.watch(function()
		draw()
	end)
end
return view
