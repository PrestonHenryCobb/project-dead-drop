--!strict
-- Cinematic gala landing: mission essentials on the left, center-stage operative, compact squad at top-right and
-- Play at bottom-right. Free agent picks and briefing details expand on demand. All actions keep server authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AgentDefs = require(Shared:WaitForChild("Defs"):WaitForChild("AgentDefs"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Janitor = require(Shared:WaitForChild("Util"):WaitForChild("Janitor"))
local Types = require(Shared:WaitForChild("Types"))
local WeaponDefs = require(Shared:WaitForChild("Defs"):WaitForChild("WeaponDefs"))
local Menu = script.Parent.Parent
local LobbyState = require(Menu:WaitForChild("LobbyState"))
local MenuTheme = require(Menu:WaitForChild("MenuTheme"))
local AssetDraft = require(Menu.AssetDraft)
local Kit = require(Menu.Components.ViewKit)
local RequestFeedback = require(Menu.RequestFeedback)
local RemoteController = require(Menu.Parent:WaitForChild("Controllers"):WaitForChild("RemoteController"))
local Matchmaking = require(Menu.Parent.Controllers.MatchmakingController)

local config = GameConfig.Menu
local colors = MenuTheme.Colors

local QUEUE_MODES: { Types.QueueMode } = { "Solos", "Duos" }

local PlayLobbyView = {}
PlayLobbyView.Tab = "Play" :: Types.MenuTab

local janitor = Janitor.new() -- lives while the screen is mounted
local content = Janitor.new() -- the rails' contents, rebuilt whenever the data changes
local stageFrame: Frame? = nil
local nav: Types.MenuNavigator? = nil
local deploying = false
local retryThread: thread? = nil
local claiming: string? = nil
local claimNotice: string? = nil
local claimGeneration = 0
local queueMode: Types.QueueMode? = nil
local picksExpanded = false
local detailsExpanded = false

local function hardwareName(agentId: string, hardwareId: string): (string, number)
	for _, item in WeaponDefs.getForAgent(agentId) do
		if item.Id == hardwareId then
			return item.Name, item.Slot
		end
	end
	return hardwareId, 0
end

local function panel(parent: Instance, name: string, order: number, accent: MenuTheme.Accent?): Frame
	local frame = MenuTheme.infoPanel({ Name = name, Accent = accent, Parent = parent, LayoutOrder = order })
	MenuTheme.stack(frame).Padding = UDim.new(0, config.GapPixels / 2)
	frame.BackgroundTransparency = 1
	local border = frame:FindFirstChildOfClass("UIStroke")
	if border then
		border.Transparency = 1
	end
	return frame
end

local function claim(agentId: string, redraw: () -> ())
	if claiming then
		return
	end
	claiming, claimNotice = agentId, nil
	local generation = claimGeneration
	redraw()
	local request = task.spawn(function()
		local connected, accepted, reason = pcall(RemoteController.invoke, "RequestClaimStarterAgent", agentId)
		if generation ~= claimGeneration or not stageFrame then
			return
		end
		claiming = nil
		claimNotice = if connected and accepted
			then "Agent added to your roster."
			elseif connected then RequestFeedback.declined(reason)
			else "Connection unavailable. Try again."
		redraw()
	end)
	janitor:Add(function()
		if coroutine.status(request) ~= "dead" and request ~= coroutine.running() then
			task.cancel(request)
		end
	end)
end

local function buildLeft(
	rail: ScrollingFrame,
	actions: Frame,
	snapshot: Types.MetaSnapshot?,
	navigator: Types.MenuNavigator,
	onRetry: () -> ()
)
	local briefing = panel(rail, "Briefing", 1, "Brass")
	MenuTheme.label({
		Name = "Kicker",
		Text = "YOUR NEXT OPERATION",
		Style = "Kicker",
		Parent = briefing,
		LayoutOrder = 1,
	})
	local title =
		MenuTheme.label({ Name = "Title", Text = "THE GALA", Style = "Display", Parent = briefing, LayoutOrder = 2 })
	title.TextSize = config.Cinematic.HeroTitlePixels

	if not snapshot then
		MenuTheme.label({
			Name = "Loading",
			Text = "Contacting the agency…",
			Style = "Small",
			Parent = rail,
			LayoutOrder = 2,
		})
		return
	end
	local profile = snapshot.Profile

	-- First launch: one free agent from each class whose pick is still open.
	local openClasses: { string } = {}
	for _, class in { "Deceiver", "Enforcer", "Specialist" } do
		if profile.StarterPicksLeft[class] then
			table.insert(openClasses, class)
		end
	end
	if #openClasses > 0 then
		local entry = MenuTheme.secondaryButton({
			Name = "ToggleFreePicks",
			Text = if picksExpanded then "CLOSE FREE AGENT PICKS" else "CLAIM YOUR FREE AGENTS",
			Parent = rail,
			LayoutOrder = 2,
			OnActivated = function()
				picksExpanded = not picksExpanded
				onRetry()
			end,
		})
		entry.Instance.TextSize = config.TextSizes.Small
	end
	if #openClasses > 0 and picksExpanded then
		local picks = panel(rail, "FreePicks", 2, "Emerald")
		MenuTheme.label({ Name = "Kicker", Text = "FIRST LAUNCH", Style = "Kicker", Parent = picks, LayoutOrder = 1 })
		MenuTheme.label({
			Name = "Title",
			Text = "CHOOSE YOUR FREE AGENTS",
			Style = "Title",
			Parent = picks,
			LayoutOrder = 2,
		})
		MenuTheme.label({
			Name = "Body",
			Text = "One from each class. The other three are earned with Credits.",
			Style = "Small",
			Parent = picks,
			LayoutOrder = 3,
		})
		if claiming or claimNotice then
			MenuTheme.label({
				Name = "ClaimStatus",
				Text = if claiming then "Confirming your free agent…" else claimNotice :: string,
				Style = "Small",
				Parent = picks,
				LayoutOrder = 4,
			})
		end
		for index, class in openClasses do
			MenuTheme.label({
				Name = `{class}Kicker`,
				Text = string.upper(class),
				Style = "Kicker",
				Parent = picks,
				LayoutOrder = 3 + index * 2,
			})
			local row = Instance.new("Frame")
			row.Name = `{class}Agents`
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, config.SecondaryHeightPixels)
			row.LayoutOrder = 4 + index * 2
			row.Parent = picks
			MenuTheme.stack(row, true).Padding = UDim.new(0, config.GapPixels / 2)
			for order, agentId in AgentDefs.order do
				local agent = AgentDefs.byId[agentId]
				if agent.Class == class then
					MenuTheme.secondaryButton({
						Name = agentId,
						Text = `{string.upper(agent.DisplayName)} · {string.lower(agent.Role)}`,
						Parent = row,
						Size = UDim2.new(0.5, -config.GapPixels / 4, 1, 0),
						LayoutOrder = order,
						Enabled = claiming == nil,
						OnActivated = function()
							claim(agentId, onRetry)
						end,
					}).Instance.TextSize =
						config.TextSizes.Small
				end
			end
		end
	end

	-- Use matchmaking modes in the lobby place, otherwise the authoritative current-server queue.
	local queue = panel(rail, "Queue", 3, "Brass")
	MenuTheme.label({ Name = "Kicker", Text = "OPERATION MODE", Style = "Kicker", Parent = queue, LayoutOrder = 1 })
	local modes = Instance.new("Frame")
	modes.Name = "Modes"
	modes.BackgroundTransparency = 1
	modes.Size = UDim2.new(1, 0, 0, config.SecondaryHeightPixels)
	modes.LayoutOrder = 2
	modes.Parent = queue
	MenuTheme.stack(modes, true).Padding = UDim.new(0, config.GapPixels / 2)
	local anyUnavailable = false
	for order, mode in QUEUE_MODES do
		local matchmaking = Matchmaking.available()
		local available = if matchmaking
			then table.find(GameConfig.Matchmaking.Modes, mode) ~= nil
			else table.find(snapshot.Queue.Available, mode) ~= nil
		anyUnavailable = anyUnavailable or not available
		local button = MenuTheme.secondaryButton({
			Name = mode,
			Text = string.upper(mode),
			Parent = modes,
			Size = UDim2.new(0.5, -config.GapPixels / 4, 1, 0),
			LayoutOrder = order,
			Enabled = available
				and (
					not matchmaking
					or (
						Matchmaking.state().State ~= "Searching"
						and Matchmaking.state().State ~= "Found"
						and not Matchmaking.busy()
					)
				),
			OnActivated = function()
				if matchmaking then
					queueMode = mode
					onRetry()
				else
					RemoteController.fire("RequestQueueMode", mode)
				end
			end,
		})
		button.SetSelected(mode == (if matchmaking then queueMode or snapshot.Queue.Mode else snapshot.Queue.Mode))
	end
	if anyUnavailable and not Matchmaking.available() and detailsExpanded then
		MenuTheme.label({
			Name = "Note",
			Text = `This session plays {snapshot.Queue.Mode}. Other modes are currently unavailable.`,
			Style = "Small",
			Parent = queue,
			LayoutOrder = 3,
		})
	end

	-- The equipped loadout, and the way to change it.
	local loadout = snapshot.Loadout
	local kit = panel(rail, "Loadout", 4, "Brass")
	MenuTheme.label({ Name = "Kicker", Text = "FIELD LOADOUT", Style = "Kicker", Parent = kit, LayoutOrder = 1 })
	if loadout then
		local agent = AgentDefs.byId[loadout.AgentId]
		local name, slot = hardwareName(loadout.AgentId, loadout.HardwareId)
		MenuTheme.label({
			Name = "Agent",
			Text = `{string.upper(agent.DisplayName)} · {string.upper(agent.Class)}`,
			Style = "Title",
			Parent = kit,
			LayoutOrder = 2,
		})
		MenuTheme.label({ Name = "Hardware", Text = `W{slot} · {name}`, Style = "Mono", Parent = kit, LayoutOrder = 3 })
		local target: Types.MenuTab = if navigator.canOpen("Hardware") then "Hardware" else "Agents"
		MenuTheme.secondaryButton({
			Name = "Customize",
			Text = "CUSTOMIZE LOADOUT",
			Parent = kit,
			LayoutOrder = 4,
			Enabled = navigator.canOpen(target),
			OnActivated = function()
				navigator.navigateTo(target, { AgentId = loadout.AgentId })
			end,
		})
	else
		MenuTheme.label({
			Name = "Empty",
			Text = "Choose a free agent to prepare your loadout.",
			Style = "Small",
			Parent = kit,
			LayoutOrder = 2,
		})
	end

	MenuTheme.navigationButton({
		Name = "MissionDetails",
		Text = if detailsExpanded then "HIDE MISSION DETAILS −" else "MISSION DETAILS +",
		Parent = rail,
		LayoutOrder = 5,
		OnActivated = function()
			detailsExpanded = not detailsExpanded
			onRetry()
		end,
	})
	if detailsExpanded then
		local details = panel(rail, "MissionDetailsText", 6, "Brass")
		MenuTheme.label({
			Name = "Brief",
			Text = "Blend into the crowd. Breach the active vaults. Take the Package. Extract.",
			Style = "Small",
			Parent = details,
		})
	end

	local assets = AssetDraft.selection(loadout and loadout.AssetIds)
	if not assets then
		MenuTheme.label({
			Name = "IncompleteAssets",
			Text = "Loadout incomplete: fill all four rarity slots in Assets before deploying.",
			Style = "Small",
			Parent = actions,
			LayoutOrder = 1,
		})
		MenuTheme.secondaryButton({
			Name = "ChooseAssets",
			Text = "CHOOSE ASSETS",
			Parent = actions,
			LayoutOrder = 2,
			Enabled = navigator.canOpen("Assets"),
			OnActivated = function()
				navigator.navigateTo("Assets")
			end,
		})
	end
	local deploy: MenuTheme.Button
	local matchmaking = Matchmaking.available()
	local search = Matchmaking.state()
	if matchmaking then
		local line = Matchmaking.notice()
		if line == "" then
			line = if search.State == "Searching"
				then `SEARCHING · {search.Mode or queueMode or snapshot.Queue.Mode}`
				elseif search.State == "Found" then "MATCH FOUND · CONNECTING…"
				elseif Matchmaking.busy() then "CONTACTING MATCHMAKING…"
				else ""
		end

		if search.State ~= "Idle" or Matchmaking.busy() or Matchmaking.notice() ~= "" then
			MenuTheme.label({
				Name = "QueueActionStatus",
				Text = line,
				Style = "Small",
				Parent = actions,
				LayoutOrder = 0,
			})
		end
	end
	deploy = MenuTheme.primaryButton({
		Name = "Deploy",
		Text = if matchmaking
			then (if search.State == "Searching"
				then (if Matchmaking.cancelling() then "CANCELLING…" else "CANCEL SEARCH")
				elseif search.State == "Found" then "MATCH FOUND"
				elseif Matchmaking.busy() then "SUBMITTING…"
				else "PLAY  →")
			elseif deploying then "DEPLOYING…"
			else "PLAY  →",
		Parent = actions,
		LayoutOrder = 3,
		Enabled = if matchmaking and search.State == "Searching"
			then not Matchmaking.busy()
			else assets ~= nil
				and loadout ~= nil
				and not deploying
				and (
					not matchmaking
					or (search.State ~= "Searching" and search.State ~= "Found" and not Matchmaking.busy())
				),
		OnActivated = function()
			if matchmaking and search.State == "Searching" then
				Matchmaking.cancel()
				return
			end
			if deploying or not AssetDraft.selection() or not loadout then
				return
			end
			if matchmaking then
				local agent = AgentDefs.byId[loadout.AgentId]
				-- The next place starts a fresh client: persist the complete local Asset draft before queueing.
				Matchmaking.find(queueMode or snapshot.Queue.Mode, {
					AgentId = loadout.AgentId,
					HardwareId = loadout.HardwareId,
					GadgetIds = table.clone(loadout.GadgetIds or GameConfig.Gadgets.DefaultPicks),
					AssetIds = AssetDraft.selection(),
					TalentId = loadout.TalentId or agent.Talents[1].Id,
					InstinctId = loadout.InstinctId or agent.Instincts[1].Id,
				})
				return
			end
			deploying = true
			deploy.SetEnabled(false)
			deploy.SetText("DEPLOYING…")
			RemoteController.fire("RequestStartPreDeploy")
			-- Agent select replaces this screen when it starts; if the server refused, offer Deploy again.
			retryThread = task.delay(config.DeployRetrySeconds, function()
				retryThread = nil
				deploying = false
				onRetry()
			end)
		end,
	})
end

local function buildRight(rail: ScrollingFrame)
	local team = panel(rail, "Team", 1, "Emerald")
	MenuTheme.label({ Name = "Kicker", Text = "SQUAD", Style = "Kicker", Parent = team, LayoutOrder = 1 })
	for order, member in LobbyState.roster() do
		local you = member == Players.LocalPlayer
		MenuTheme.label({
			Name = `Member{order}`,
			Text = if you then `{member.DisplayName}  (YOU)` else member.DisplayName,
			Style = "Small",
			Color = if you then colors.EmeraldBright else colors.Text,
			Parent = team,
			LayoutOrder = 1 + order,
		})
	end
end

local render: () -> ()
function render()
	local frame = stageFrame
	local navigator = nav
	if not frame or not navigator then
		return
	end
	local restoreFocus = Kit.rememberFocus(frame)
	local previousLeft, previousRight = frame:FindFirstChild("Left"), frame:FindFirstChild("Right")
	local leftScroll = if previousLeft and previousLeft:IsA("ScrollingFrame")
		then previousLeft.CanvasPosition
		else Vector2.zero
	local rightScroll = if previousRight and previousRight:IsA("ScrollingFrame")
		then previousRight.CanvasPosition
		else Vector2.zero
	content:Cleanup()
	local snapshot = navigator.snapshot()
	local left = content:Add(MenuTheme.rail(frame, "Left", "Left", config.Cinematic.RailWidthPixels)) :: ScrollingFrame
	local right =
		content:Add(MenuTheme.rail(frame, "Right", "Right", config.Cinematic.SquadWidthPixels)) :: ScrollingFrame
	local actionHeight = config.PrimaryHeightPixels
		+ (
			if AssetDraft.selection(snapshot and snapshot.Loadout and snapshot.Loadout.AssetIds)
				then 0
				else config.SecondaryHeightPixels + config.TextSizes.Small * 3 + config.GapPixels * 3
		)
	if
		Matchmaking.available()
		and (Matchmaking.state().State ~= "Idle" or Matchmaking.busy() or Matchmaking.notice() ~= "")
	then
		actionHeight += config.TextSizes.Small * 3 + config.GapPixels
	end
	left.Size = UDim2.new(0, config.Cinematic.RailWidthPixels, 1, -config.GapPixels * 4)
	right.Size = UDim2.new(0, config.Cinematic.SquadWidthPixels, 1, -config.GapPixels * 5 - actionHeight)
	local actions = content:Add(Instance.new("Frame"))
	actions.Name = "DeployActions"
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(1, 1)
	actions.Position = UDim2.new(1, -config.GapPixels * 2, 1, -config.GapPixels * 2)
	actions.Size = UDim2.fromOffset(config.Cinematic.ActionWidthPixels, actionHeight)
	actions.Parent = frame
	MenuTheme.stack(actions).VerticalAlignment = Enum.VerticalAlignment.Bottom
	buildLeft(left, actions, snapshot, navigator, render)
	buildRight(right)

	local loadout = snapshot and snapshot.Loadout
	if loadout then
		navigator.focusAgent(loadout.AgentId, loadout.HardwareId)
		local agent = AgentDefs.byId[loadout.AgentId]
		local plate = MenuTheme.label({
			Name = "Nameplate",
			Text = string.upper(agent.DisplayName),
			Style = "Title",
			Parent = frame,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -config.GapPixels * 2),
			Size = UDim2.fromOffset(config.LeftRailPixels, config.ChipHeightPixels),
			Alignment = Enum.TextXAlignment.Center,
		})
		plate.TextSize = config.TextSizes.Title
		-- The shared bottom veil supplies contrast without enclosing the operative name.
		plate.TextColor3 = colors.Text
		plate.BackgroundColor3 = colors.Canvas
		plate.BackgroundTransparency = 1
		content:Add(plate)
	end
	left.CanvasPosition, right.CanvasPosition = leftScroll, rightScroll
	restoreFocus(frame)
end

function PlayLobbyView.Mount(stage: Frame, navigator: Types.MenuNavigator, _context: { [string]: any }?)
	claimGeneration += 1
	claiming, claimNotice = nil, nil
	picksExpanded, detailsExpanded = false, false
	stageFrame = stage
	nav = navigator
	janitor:Add(navigator.onSnapshot(render))
	janitor:Add(LobbyState.onChanged(render))
	janitor:Add(Matchmaking.onChanged(render))
	render()
end

function PlayLobbyView.Unmount()
	claimGeneration += 1
	claiming, claimNotice = nil, nil
	local retry = retryThread
	retryThread = nil
	if retry and coroutine.status(retry) ~= "dead" then
		task.cancel(retry)
	end
	content:Cleanup()
	janitor:Cleanup()
	stageFrame, nav = nil, nil
	deploying = false
end

return PlayLobbyView
