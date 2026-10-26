--!strict
-- Ticket menu-shell: agent select, the 30 seconds before deploying. Left: the countdown, the team's picks and the
-- objective. Centre: the operative on the stage and the six agents to choose from. Right: the chosen agent's Hardware
-- (W1 to W3), their Talent and Instinct, and Lock in. The server decides everything: a pick is only a request, the
-- countdown runs to the server's cutoff, and picks can be changed until then. MenuController mounts this screen
-- whenever agent select is running, in place of the section tabs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AgentDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AgentDefs"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Menu = script.Parent.Parent
local LobbyState = require(Menu:WaitForChild("LobbyState"))
local MenuTheme = require(Menu:WaitForChild("MenuTheme"))
local RemoteController = require(Menu.Parent:WaitForChild("Controllers"):WaitForChild("RemoteController"))

local config = GameConfig.Menu
local colors = MenuTheme.Colors

local PreDeployView = {}
PreDeployView.Tab = "Play" :: Types.MenuTab -- not a tab: MenuController mounts this module by name during agent select

local janitor = Janitor.new() -- lives while the screen is mounted
local content = Janitor.new() -- rebuilt whenever the state or the draft changes
local stageFrame: Frame? = nil
local nav: Types.MenuNavigator? = nil
local timerText: TextLabel? = nil
-- The player's draft: what they are looking at, which becomes their pick when they lock in.
local draftAgent: string? = nil
local draftHardware: string? = nil

local function me(state: Types.PreDeployState?): Types.PreDeployMember?
	if not state then
		return nil
	end
	for _, member in state.Members do
		if member.UserId == Players.LocalPlayer.UserId then
			return member
		end
	end
	return nil
end

-- The agent a teammate has locked in, which nobody else on the team can take.
local function takenByTeammate(state: Types.PreDeployState?, agentId: string): boolean
	if not state then
		return false
	end
	for _, member in state.Members do
		if member.UserId ~= Players.LocalPlayer.UserId and member.LockedIn and member.AgentId == agentId then
			return true
		end
	end
	return false
end

local function masteryOf(snapshot: Types.MetaSnapshot?, agentId: string): number
	local mastery = snapshot and snapshot.Profile.Mastery[agentId]
	return if mastery then mastery.Level else 0
end

-- The draft's Hardware, kept if it is usable for the draft agent, else that agent's W1.
local function usableHardware(snapshot: Types.MetaSnapshot?, agentId: string, wanted: string?): string
	local items = WeaponDefs.getForAgent(agentId)
	for _, item in items do
		if item.Id == wanted and item.Def and masteryOf(snapshot, agentId) >= item.UnlockMasteryLevel then
			return item.Id
		end
	end
	return items[1].Id
end

local function panel(parent: Instance, name: string, order: number, accent: MenuTheme.Accent?): Frame
	local frame = MenuTheme.infoPanel({ Name = name, Accent = accent, Parent = parent, LayoutOrder = order })
	MenuTheme.stack(frame).Padding = UDim.new(0, config.GapPixels / 2)
	return frame
end

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", whole // 60, whole % 60)
end

local function buildLeft(rail: ScrollingFrame, state: Types.PreDeployState)
	local banner = Instance.new("Frame")
	banner.Name = "Countdown"
	banner.BackgroundColor3 = colors.Burgundy
	banner.Size = UDim2.fromScale(1, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.LayoutOrder = 1
	banner.Parent = rail
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.CornerPixels)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.Brass
	stroke.Thickness = config.TrimPixels
	stroke.Parent = banner
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, config.PaddingPixels)
	padding.PaddingBottom = UDim.new(0, config.PaddingPixels)
	padding.PaddingLeft = UDim.new(0, config.PaddingPixels)
	padding.Parent = banner
	MenuTheme.stack(banner).Padding = UDim.new(0, 0)
	MenuTheme.label({
		Name = "Kicker",
		Text = "AGENT SELECT · DEPLOYING IN",
		Style = "Kicker",
		Parent = banner,
		LayoutOrder = 1,
	})
	local timer = MenuTheme.label({
		Name = "Timer",
		Text = formatTime(state.EndsAt - workspace:GetServerTimeNow()),
		Style = "Mono",
		Parent = banner,
		LayoutOrder = 2,
	})
	timer.TextSize = config.TextSizes.Display * 1.5
	timerText = timer

	local team = panel(rail, "Team", 2, "Emerald")
	MenuTheme.label({ Name = "Kicker", Text = "YOUR TEAM", Style = "Kicker", Parent = team, LayoutOrder = 1 })
	for order, member in state.Members do
		local row = Instance.new("Frame")
		row.Name = `Member{order}`
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, config.ChipHeightPixels * 2)
		row.LayoutOrder = 1 + order
		row.Parent = team
		local you = member.UserId == Players.LocalPlayer.UserId
		local agent = member.AgentId and AgentDefs.byId[member.AgentId]
		MenuTheme.label({
			Name = "Name",
			Text = `{if you then "YOU" else string.upper(member.DisplayName)} · {if agent
				then string.upper(agent.DisplayName)
				else "CHOOSING"}`,
			Style = "Body",
			Color = if you then colors.EmeraldBright else colors.Text,
			Parent = row,
			Size = UDim2.new(0.6, 0, 1, 0),
		})
		local chip = MenuTheme.stateChip(
			if member.LockedIn then "Equipped" else "Select",
			if member.LockedIn then "LOCKED IN" else "SELECTING"
		)
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.Position = UDim2.fromScale(1, 0.5)
		chip.Parent = row
	end

	local objective = panel(rail, "Objective", 3, "Brass")
	MenuTheme.label({
		Name = "Kicker",
		Text = "PRIMARY OBJECTIVE",
		Style = "Kicker",
		Parent = objective,
		LayoutOrder = 1,
	})
	MenuTheme.label({ Name = "Title", Text = "THE PACKAGE", Style = "Title", Parent = objective, LayoutOrder = 2 })
	MenuTheme.label({
		Name = "Body",
		Text = "Gather intel to open the vault, take the Package and carry it to an extraction site.",
		Style = "Small",
		Parent = objective,
		LayoutOrder = 3,
	})
end

-- The six agents along the bottom of the stage: owned and free ones can be chosen; others say why not.
local function buildRoster(frame: Frame, state: Types.PreDeployState, snapshot: Types.MetaSnapshot?, redraw: () -> ())
	local strip = Instance.new("Frame")
	strip.Name = "Roster"
	strip.BackgroundTransparency = 1
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.new(0.5, 0, 1, -config.GapPixels * 2)
	strip.Size = UDim2.fromOffset(0, config.SecondaryHeightPixels + config.ChipHeightPixels)
	strip.AutomaticSize = Enum.AutomaticSize.X
	strip.Parent = frame
	MenuTheme.stack(strip, true).Padding = UDim.new(0, config.GapPixels / 2)
	for order, agentId in AgentDefs.order do
		local agent = AgentDefs.byId[agentId]
		local owned = snapshot ~= nil and snapshot.Profile.OwnedAgents[agentId] == true
		local taken = takenByTeammate(state, agentId)
		local note = if not owned then "LOCKED" elseif taken then "TAKEN" else string.upper(agent.Class)
		local button = MenuTheme.secondaryButton({
			Name = agentId,
			Text = `{string.upper(agent.DisplayName)}\n{note}`,
			Parent = strip,
			Size = UDim2.fromOffset(config.RosterCardPixels, config.SecondaryHeightPixels + config.ChipHeightPixels),
			LayoutOrder = order,
			Enabled = owned and not taken,
			OnActivated = function()
				draftAgent = agentId
				draftHardware = usableHardware(snapshot, agentId, nil)
				redraw()
			end,
		})
		button.Instance.TextSize = config.TextSizes.Small
		button.SetSelected(agentId == draftAgent)
	end
	return strip
end

local function buildRight(
	rail: ScrollingFrame,
	state: Types.PreDeployState,
	snapshot: Types.MetaSnapshot?,
	redraw: () -> ()
)
	local agentId = draftAgent
	if not agentId then
		MenuTheme.label({ Name = "Empty", Text = "Choose an agent.", Style = "Small", Parent = rail, LayoutOrder = 1 })
		return
	end
	local agent = AgentDefs.byId[agentId]
	local mastery = masteryOf(snapshot, agentId)

	local hardware = panel(rail, "Hardware", 1, "Brass")
	MenuTheme.label({
		Name = "Kicker",
		Text = `{string.upper(agent.DisplayName)} · HARDWARE · MASTERY {mastery}`,
		Style = "Kicker",
		Parent = hardware,
		LayoutOrder = 1,
	})
	for _, item in WeaponDefs.getForAgent(agentId) do
		local reason = if not item.Def
			then "IN DEVELOPMENT"
			elseif mastery < item.UnlockMasteryLevel then `MASTERY {item.UnlockMasteryLevel}`
			else nil
		local button = MenuTheme.secondaryButton({
			Name = item.Id,
			Text = `W{item.Slot} · {item.Name}{if reason then `  —  {reason}` else ""}`,
			Parent = hardware,
			LayoutOrder = 1 + item.Slot,
			Enabled = reason == nil,
			OnActivated = function()
				draftHardware = item.Id
				redraw()
			end,
		})
		button.Instance.TextSize = config.TextSizes.Small
		button.SetSelected(item.Id == draftHardware)
	end

	local kit = panel(rail, "Kit", 2, "Focus")
	for index, entry in
		{ { Kind = "TALENT", Item = agent.Talents[1] }, { Kind = "INSTINCT", Item = agent.Instincts[1] } }
	do
		local cooldown = entry.Item.CooldownSeconds
		MenuTheme.label({
			Name = `{entry.Kind}Kicker`,
			Text = if cooldown then `{entry.Kind} · {cooldown} S COOLDOWN` else `{entry.Kind} · PASSIVE`,
			Style = "Kicker",
			Parent = kit,
			LayoutOrder = index * 3,
		})
		MenuTheme.label({
			Name = `{entry.Kind}Name`,
			Text = entry.Item.Name,
			Style = "Title",
			Parent = kit,
			LayoutOrder = index * 3 + 1,
		})
		MenuTheme.label({
			Name = `{entry.Kind}Body`,
			Text = entry.Item.Description,
			Style = "Small",
			Parent = kit,
			LayoutOrder = index * 3 + 2,
		})
	end

	local mine = me(state)
	local matchesPick = mine ~= nil and mine.LockedIn and mine.AgentId == agentId and mine.HardwareId == draftHardware
	MenuTheme.primaryButton({
		Name = "LockIn",
		Text = if matchesPick then "LOCKED IN" else "LOCK IN AGENT & HARDWARE",
		Parent = rail,
		LayoutOrder = 3,
		Enabled = not matchesPick and draftHardware ~= nil,
		OnActivated = function()
			local request: Types.LoadoutRequest = { AgentId = agentId, HardwareId = draftHardware :: string }
			RemoteController.fire("RequestLockInPreDeploy", request)
		end,
	})
end

local render: () -> ()
function render()
	local frame = stageFrame
	local navigator = nav
	local state = LobbyState.preDeploy()
	if not frame or not navigator or not state or not state.Active then
		return
	end
	content:Cleanup()
	timerText = nil
	local snapshot = navigator.snapshot()

	-- Start the draft from the server's view of this player: their pick, else their equipped loadout.
	if not draftAgent then
		local mine = me(state)
		local loadout = snapshot and snapshot.Loadout
		draftAgent = (mine and mine.AgentId) or (loadout and loadout.AgentId)
		draftHardware = (mine and mine.HardwareId) or (loadout and loadout.HardwareId)
	end
	-- A teammate locking in the agent being looked at takes it: move on to the first agent still free.
	if draftAgent and takenByTeammate(state, draftAgent) then
		draftAgent, draftHardware = nil, nil
		for _, agentId in AgentDefs.order do
			if snapshot and snapshot.Profile.OwnedAgents[agentId] and not takenByTeammate(state, agentId) then
				draftAgent = agentId
				break
			end
		end
	end
	if draftAgent then
		draftHardware = usableHardware(snapshot, draftAgent, draftHardware)
		navigator.focusAgent(draftAgent :: Types.AgentId, draftHardware)
	end

	local left = content:Add(MenuTheme.rail(frame, "Left", "Left", config.LeftRailPixels)) :: ScrollingFrame
	local right = content:Add(MenuTheme.rail(frame, "Right", "Right", config.RightRailPixels)) :: ScrollingFrame
	buildLeft(left, state)
	content:Add(buildRoster(frame, state, snapshot, render))
	buildRight(right, state, snapshot, render)
end

function PreDeployView.Mount(stage: Frame, navigator: Types.MenuNavigator, _context: { [string]: any }?)
	stageFrame = stage
	nav = navigator
	draftAgent, draftHardware = nil, nil
	janitor:Add(navigator.onSnapshot(render))
	janitor:Add(LobbyState.onChanged(render))
	-- The countdown is drawn from the server's cutoff, so it never drifts from it; only the text changes.
	janitor:Add(RunService.Heartbeat:Connect(function()
		local state = LobbyState.preDeploy()
		if timerText and state then
			local text = formatTime(state.EndsAt - workspace:GetServerTimeNow())
			if timerText.Text ~= text then
				timerText.Text = text
			end
		end
	end))
	render()
end

function PreDeployView.Unmount()
	content:Cleanup()
	janitor:Cleanup()
	stageFrame, nav, timerText = nil, nil, nil
	draftAgent, draftHardware = nil, nil
end

return PreDeployView
